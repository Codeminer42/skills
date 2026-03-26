# Log & Output Protection

> **Source:** https://guides.rubyonrails.org/configuring.html#config-filter-parameters

## filter_parameters — Sanitize Logs and #inspect

`config.filter_parameters` is the single global setting that filters PII from both request logs **and** `#inspect` output on all ActiveRecord models. One config, two protections.

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key,
  :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,

  # App-specific PII:
  :first_name, :last_name, :phone, :date_of_birth,
  :street, :city, :state, :zip_code, :ip_address
]
```

**Result:** Log shows `"first_name"=>"[FILTERED]"` and `User.first.inspect` shows `first_name: [FILTERED]`.

## filter_attributes — Per-Model PII Declaration

`self.filter_attributes` is **not** a separate protection layer — `filter_parameters` already covers `#inspect`. Its value is as self-documenting code: anyone reading the model can immediately see which fields contain PII without checking the global initializer.

```ruby
class User < ApplicationRecord
  self.filter_attributes = %i[
    first_name last_name phone date_of_birth
    email_address password_digest
  ]
end
```

Use it as a convention to make PII fields explicit at the model level, not because `filter_parameters` doesn't cover it.

## log_arguments — Suppress Job Arguments

### ActiveJob

Job arguments appear in logs by default. For jobs that process sensitive data (DSAR requests, user IDs), disable this. **Best practice:** set it in `ApplicationJob` so all jobs inherit the protection.

```ruby
class ApplicationJob < ActiveJob::Base
  self.log_arguments = false  # All child jobs inherit this
end
```

If you need argument logging for a specific job that handles no PII, you can re-enable it per-job with `self.log_arguments = true`.

**Result:** Job logs show the job class and queue but not the arguments.

### Sidekiq (pure workers)

When using Sidekiq directly (not via ActiveJob adapter), workers don't have a per-worker `log_arguments` setting ([source](https://github.com/sidekiq/sidekiq/wiki/Logging)). Arguments always appear in:
- Sidekiq server logs
- Sidekiq Web UI dashboard
- Redis (where jobs are stored)

**Mitigations:**

1. **Pass only IDs** in `perform` arguments — never PII data (primary mitigation)
2. **Use ActiveJob with Sidekiq adapter** — gives you `self.log_arguments = false`:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
# Now jobs in app/jobs/ get self.log_arguments = false support
```

**Note:** Sidekiq server middleware runs *after* the built-in `JobLogger` prints job arguments, so middleware alone cannot filter arguments from Sidekiq's default log output. The most effective approach is to never pass PII in arguments in the first place, or to switch to ActiveJob with the Sidekiq adapter.

## Logstop — Catch-All PII Redaction in Logs

The layers above filter by **parameter name** — they can't catch PII that appears in free-form log messages (e.g., `Rails.logger.info("Processing order for #{user.email_address}")`). Logstop is a safety net that redacts **value patterns** (emails, credit card numbers, phone numbers, SSNs) from all log output. IP and MAC address filtering is available but off by default.

```ruby
# Gemfile
gem "logstop"

# config/initializers/logstop.rb
Logstop.guard(Rails.logger, ip: true)
```

**Result:** Any log line containing a PII pattern gets redacted automatically — `Processing order for maria@example.com` becomes `Processing order for [FILTERED]`.

**Important:** Logstop is complementary to `filter_parameters` and `filter_attributes`, not a replacement. `filter_parameters` works by param name (catches `:first_name` even though "Maria" doesn't look like PII). Logstop works by value pattern (catches an email even if logged in a raw string). Use both.

## IpAnonymizer — Anonymize IP Addresses at the Middleware Level

IP addresses are personal data under privacy laws like GDPR and LGPD. `ip_anonymizer` anonymizes IPs via Rack middleware before the request reaches your application, so no controller, log, or database ever sees the full IP.

```ruby
# Gemfile
gem "ip_anonymizer"

# config/application.rb — insert right after RemoteIp resolves the address
config.middleware.insert_after ActionDispatch::RemoteIp, IpAnonymizer::MaskIp
```

Masking zeroes the last octet of IPv4 (and last 80 bits of IPv6), following the Google Analytics approach. A hashing strategy is also available for cases where you need distinct anonymized IPs:

```ruby
config.middleware.insert_after ActionDispatch::RemoteIp, IpAnonymizer::HashIp, key: Rails.application.credentials.ip_hash_key
```

**Result:** A request from `192.168.1.42` is seen as `192.168.1.0` by the entire Rails stack — controllers, logs, and any `request.remote_ip` calls.

## Error Reporters — Scrub PII Before It Leaves Your App

Services like Sentry, Rollbar, and Bugsnag capture exceptions with full context — including request params, user data, and environment variables. Without scrubbing, a single unhandled exception can send PII to a third party.

```ruby
# Example: Rollbar
Rollbar.configure do |config|
  config.anonymize_user_ip = true
  config.scrub_fields |= [:email, :phone, :first_name, :last_name, :date_of_birth]
end
```

Sentry and Bugsnag have similar configuration. Audit what your error reporter captures — check its dashboard for leaked PII.

## APM / Monitoring Tools — Scrub PII Before It Reaches External Dashboards

APM tools like AppSignal, NewRelic, Datadog, Scout APM, and Skylight collect performance data, custom metadata, and job arguments. Without scrubbing, PII can reach external dashboards via:

- **Custom data/attributes:** `Appsignal.add_custom_data(params: arguments)`, `NewRelic::Agent.add_custom_attributes(user: current_user)`
- **Job instrumentation:** APM tools often instrument ActiveJob or Sidekiq and capture job arguments automatically
- **Request parameters:** Some tools capture full request params unless configured otherwise

**This has the same severity as error reporter leaks — PII is sent to a third-party service.**

```ruby
# BAD — sends all job arguments to AppSignal (docs: https://docs.appsignal.com/guides/custom-data/custom-data.html)
def appsignal_instrument
  Appsignal.add_custom_data(params: arguments)
end

# GOOD — sends only safe identifiers
def appsignal_instrument
  Appsignal.add_custom_data(
    params: arguments.map { |arg| arg.is_a?(ActiveRecord::Base) ? "#{arg.class.name}##{arg.id}" : arg.to_s.truncate(50) },
    id: job_id
  )
end
```

```ruby
# BAD — sends user PII to NewRelic (docs: https://docs.newrelic.com/docs/data-apis/custom-data/custom-events/collect-custom-attributes/)
NewRelic::Agent.add_custom_attributes(user_email: current_user.email)

# GOOD — sends only safe identifiers
NewRelic::Agent.add_custom_attributes(user_id: current_user.id)
```

Audit your APM configuration: check initializers, base job classes, and any custom instrumentation for PII leaks.

## Other Leak Vectors

**Cache stores:** Never cache objects containing PII. A `Rails.cache.fetch("user:#{id}")` that stores a full User record puts decrypted PII in Redis/Memcached in plaintext.

**Emails:** Don't include sensitive data in emails — it sits in inboxes indefinitely. Send a link back to your app instead of the data itself. This applies to admin notifications too (e.g., "a new DSAR was submitted" is fine, but don't include the user's name or email in the notification body).
