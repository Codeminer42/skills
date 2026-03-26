---
title: Suppress job arguments for privacy-sensitive jobs
impact: HIGH
tags: log, jobs, activejob, sidekiq
---

## Suppress job arguments for privacy-sensitive jobs

**Impact: HIGH**

Job frameworks log arguments by default. Arguments are also serialized to queue backends (Redis, database) in plaintext. Any job that receives user IDs or handles personal data must suppress argument logging.

### ActiveJob

**Best practice:** Set `self.log_arguments = false` in `ApplicationJob` so all jobs inherit the protection. Only override in child classes if you have a specific reason to re-enable logging for a job that handles no PII.

**Incorrect:**

```ruby
class SendDataExportEmailJob < ApplicationJob
  queue_as :privacy

  def perform(user_id)
    # user_id appears in job logs and queue dashboards
  end
end
```

**Correct (base class — recommended):**

```ruby
class ApplicationJob < ActiveJob::Base
  self.log_arguments = false  # All child jobs inherit this
end
```

**Correct (per-job):**

```ruby
class SendDataExportEmailJob < ApplicationJob
  self.log_arguments = false
  queue_as :privacy

  def perform(user_id)
    # user_id is not logged
  end
end
```

### Sidekiq (pure workers, not via ActiveJob adapter)

Sidekiq workers (`Sidekiq::Worker` / `Sidekiq::Job`) don't have a per-worker `log_arguments` setting like ActiveJob. Arguments always appear in Sidekiq logs, the Web UI dashboard, and are stored in Redis.

**Mitigations:**

1. **Pass only IDs** — never pass PII data in `perform` arguments (primary mitigation)
2. **Consider using ActiveJob with Sidekiq adapter** — gives you `self.log_arguments = false`

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
# Now jobs in app/jobs/ get self.log_arguments = false support
```

**Note:** Sidekiq server middleware runs *after* the built-in `JobLogger` prints the job arguments, so middleware alone cannot filter arguments from Sidekiq's default log output. The most effective approach is to never pass PII in arguments in the first place, or to switch to ActiveJob with the Sidekiq adapter.
