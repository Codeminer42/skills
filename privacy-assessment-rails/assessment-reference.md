# Assessment Reference

Read this file during Step 2. Process every item in the checklist sequentially. Do not skip any.

## Severity Classification

Every finding **must** use a severity from this table. Do not improvise.

| Category | Severity |
|----------|----------|
| PII leaking to external third-party services (error reporters, APM, webhooks) | CRITICAL |
| Unencrypted PII at rest in database (any table, including denormalized columns) | CRITICAL |
| Incomplete filter_parameters (PII leaks to logs, console, error reporters) | CRITICAL |
| PII in local logs, queue backends, or cache (job args in Redis, cache keys) | HIGH |
| Missing filter_attributes on PII models (#inspect leaks) | HIGH |
| PII in email from/subject/body sent to OTHER users | HIGH |
| PII in emails sent to the data subject themselves (e.g., Devise greeting) | Dismiss with justification |
| PII serialized into unencrypted audit/log columns | HIGH |
| Missing structural safeguards (consent, DSAR, retention, anonymization) | MEDIUM |
| Missing security tooling (brakeman, bundler-audit, logstop, ip_anonymizer) | MEDIUM |

## Deep-Dive Checklist

Process every item below **in order**. For each item:
- Read the specified files
- Record the outcome: **FINDING** (with severity), **PASS**, or **N/A** (feature doesn't exist in this app)
- Do not move to the next item until the current one is resolved

After completing all items, every concept will have been checked.

---

### A. Preparation

**A1. Rails version**
- Read: `Gemfile.lock`
- Check: What Rails version is this app running?
- Impact: Rails 7.0+ → recommend native `encrypts`. Rails 6.x or earlier → recommend `lockbox` + `blind_index`. Include version in report header.

**A2. Schema cross-reference**
- Read: `db/schema.rb`
- Check: Build a mental map of which tables and columns actually exist. Use this throughout the checklist to dismiss scanner findings for columns that were removed or never applied.

**A2b. Market-specific PII document lookup**

The scanner includes built-in PII patterns for common markets (Brazil, EU, US) via the `--markets` flag. These built-in patterns provide a baseline, but you **must always perform a web search** to discover patterns the built-in list may miss.

**Search query pattern:** For each market, search: `"[country/region] privacy law personal data government document types column names database"`

**What to look for:**
- National ID document names and abbreviations (these often appear as column names)
- Tax identification numbers specific to the country
- Social security or social insurance numbers
- Healthcare identifiers
- Financial identifiers (payment systems, bank account formats)
- Any special category data definitions under that country's privacy law

**Record the results** as a "market-specific PII patterns" list. These patterns supplement both the scanner's built-in patterns and Rule 1 (universal PII identifiers) from `references/pii-definition.md` when classifying columns in A3.

**If markets are unknown or "global":** Search for the top 5 most common privacy frameworks (GDPR/EU, LGPD/Brazil, CCPA/US, PIPEDA/Canada, POPIA/South Africa) and compile a combined list.

**A3. Codebase inventory (MANDATORY)**

The scanner's JSON output includes an `inventory` object that enumerates models, mailers, mailer templates, jobs, controllers, services, initializers, PII tables, ransackable models, audit declarations, external API calls, and JSON endpoints.

**Start from the scanner inventory.** Then supplement with these verification steps:

1. **Read every model file** listed in `inventory.models`. No exceptions — you need the full content for PII classification.

2. **Schema cross-reference:** Read `db/schema.rb`. For EVERY table: verify PII classification by applying the Mandatory Classification Rules from `references/pii-definition.md` (Rules 1-4). The scanner's `schema_tables_with_pii` uses pattern matching and may miss domain-specific fields with non-standard names. Check for fields the scanner missed (e.g., `protheus_code`, `farm_name`, `other_disability`).

3. **Spot-check external calls:** The scanner finds `Net::HTTP`, `HTTParty`, `Faraday`, `RestClient`, `URI.open`. Also check for gem-specific client classes (e.g., `ActiveGenie::Scoring`, `Slack::Web::Client`, `Twilio::REST::Client`) by scanning `app/services/` and `Gemfile` for third-party integration gems.

4. **If any category is empty** in the scanner inventory but you expect files to exist (e.g., `services` is empty but the app has `app/services/`), run a manual glob to verify.

**Outcome:** A complete inventory of every model, mailer, job, controller, service, external call, initializer, and audit declaration. This inventory drives ALL subsequent checklist items.

**A4. Build verification matrix**

Using the inventory from A3, build this table covering EVERY model that has PII columns. This table is an internal working document — it does not appear in the final report, but it MUST be completed before proceeding to section B.

| Model | PII Columns | encrypts? | filter_attributes? | ransackable_attributes? | ransackable reviewed? |
|-------|------------|-----------|-------------------|------------------------|----------------------|
| User  | email, name | NO        | NO                | YES (file:line)        | pending              |
| Owner | name, farm_name | NO   | NO                | NO                     | N/A                  |
| ...   | ...        | ...       | ...               | ...                    | ...                  |

Rules:
- **Every** model from the A3 enumeration with at least one PII column MUST have a row.
- `encrypts?` = does the model file contain `encrypts :field` for ALL its PII columns?
- `filter_attributes?` = does the model declare `self.filter_attributes` listing its PII columns?
- `ransackable_attributes?` = does the model define `ransackable_attributes`? If yes, record the file:line.
- `ransackable reviewed?` = initially "pending" — updated to "FINDING" or "PASS" during section F.

As you process checklist items B1, B3, and F1, update the corresponding columns. By the end of the checklist, every cell must be filled — no "pending" values should remain.

---

### B. Encryption at Rest

**B1. PII columns without encryption**
- Read: Scanner `encrypt-pii-fields` findings + the PII inventory from A3
- Check: Does every PII column have `encrypts` (or `lockbox` equivalent for Rails <7)? Dismiss scanner findings for non-PII columns (e.g., `Project.name` is a project title, not a person). Dismiss findings for columns not in `db/schema.rb`.
- Severity: CRITICAL for confirmed PII columns without encryption.

**B2. filter_parameters completeness**
- Read: `config/initializers/filter_parameter_logging.rb`
- Check: Are ALL PII field names from inventory A3 included in `filter_parameters`? Check for partial coverage (e.g., only `:password`).
- Severity: CRITICAL if PII fields are missing.

**B3. filter_attributes on PII models**
- Read: Every model file that has PII columns (from A3)
- Check: Does each model declare `self.filter_attributes` listing its PII fields?
- Severity: HIGH if missing.

---

### C. External Service Leaks

**C1. Error reporter scrubbing**
- Read: `config/initializers/*.rb` — look for Rollbar, Sentry, Bugsnag, Honeybadger, Airbrake initializers
- Check: For each error reporter found: Are `scrub_fields` configured? Is `before_send`/`before_process` set up? Are `person_*_method` settings restricted to ID only (not email/username)? Is IP anonymization enabled?
- Severity: CRITICAL if any reporter sends PII without scrubbing.

**C2. APM / monitoring tool scrubbing**
- Read: `config/initializers/*.rb`, `Gemfile`, `config/newrelic.yml`, `config/appsignal.yml`, or any other APM config
- Check: For each APM tool found (NewRelic, AppSignal, Datadog, Scout, Skylight): Are `attributes.exclude` or equivalent configured? Is custom data/instrumentation sending PII (e.g., `add_custom_data`, `add_custom_attributes`)? Check base job/worker classes for APM callbacks that forward arguments.
- Severity: CRITICAL if any APM tool receives PII.

**C3. PII sent to ANY external service (webhooks, APIs, AI providers, etc.)**
- Read: `app/services/**/*.rb`, `app/workers/**/*.rb`, `config/initializers/*.rb`, `Gemfile`
- Check: Does the app send data to **any** external service? This includes but is not limited to: webhook integrations (Slack, Discord, Mattermost), AI/LLM APIs (OpenAI, Anthropic, Google AI), payment processors, analytics services, CRM integrations, email marketing platforms, or any HTTP client calling an external URL. For each external call found: does the payload include PII (user names, emails, personal data)? Grep for `Net::HTTP`, `HTTParty`, `Faraday`, `RestClient`, `URI.open`, and gem-specific client classes.
- Severity: CRITICAL if PII is sent to external services — even if the user confirmed the integration is authorized. Authorization does not change the severity; it changes the recommended fix (focus on data minimization, DPA, and audit logging instead of removal). Always create a numbered finding, never a separate "Accepted Trade-Offs" section.

---

### D. Logs, Queue, and Cache

**D1. Job argument logging (ActiveJob)**
- Read: `app/jobs/application_job.rb`, then scanner `log-no-job-arguments` findings
- Check: Does the base class (`ApplicationJob`) set `self.log_arguments = false`? If yes, dismiss child job findings (they inherit it). If no, flag the base class. Also check: does any child explicitly re-enable with `self.log_arguments = true`?
- Severity: HIGH.

**D2. Job argument logging (Sidekiq / other frameworks)**
- Read: `Gemfile`, `app/workers/**/*.rb`, `app/sidekiq/**/*.rb`
- Check: Are there Sidekiq workers or other non-ActiveJob background processors? Sidekiq has no per-worker `log_arguments` — arguments always appear in logs and Redis. Are only IDs passed to `perform`, never PII data?
- Severity: HIGH for PII in arguments.

**D3. PII in job perform parameters**
- Read: Scanner `log-pass-ids-not-data` findings
- Check: Do any job/worker `perform` methods accept PII-named parameters (email, name, phone, etc.) instead of record IDs?
- Severity: HIGH.

**D4. PII in cache keys or values**
- Read: Grep for `Rails.cache` across the codebase
- Check: Are PII values used as cache keys (e.g., `"user/#{user.email}/avatar"`)? Are full ActiveRecord objects with PII cached?
- Severity: HIGH.

**D5. PII in session storage**
- Read: `app/controllers/**/*.rb`
- Check: Is `session[...]` ever assigned a full ActiveRecord object (not just an ID)?
- Severity: HIGH.

**D6. PII in serialized audit/log columns**
- Read: Models with `serialize` or `store` declarations, activity/audit log models
- Check: Do any models serialize full attribute hashes (including PII) into text/JSON columns? E.g., `subject_changes = subject.saved_changes` capturing name changes.
- Severity: HIGH.

---

### E. Email

**E1. PII in mailer `from:` addresses**
- Read: ALL files in `app/mailers/**/*.rb`
- Check: Does any mailer use a user's personal email as the `from:` address? This exposes one user's email to other recipients.
- Severity: HIGH.

**E2. PII in email subject lines**
- Read: ALL files in `app/mailers/**/*.rb`
- Check: Do any email subjects contain person names, emails, or other PII? Subjects appear in inbox previews, notification banners, and lock screen alerts.
- Severity: HIGH.

**E3. PII in email template bodies**
- Read: Scanner `email-no-pii-in-body` findings + `app/views/*mailer*/**/*.{erb,haml,slim}`
- Check: Do templates interpolate PII fields (name, email, phone, etc.) into the email body? Distinguish: emails sent to OTHER users (HIGH) vs emails sent to the data subject themselves about their own data (dismiss with justification).
- Severity: HIGH for PII sent to others. Dismiss for self-addressed.

---

### F. Data Minimization

**F1. Sensitive fields in API/search exposure**
- Read: Models with `ransackable_attributes` or `ransortable_attributes`; controllers with `params.permit`
- Check: Are sensitive fields (encrypted_password, reset_password_token, etc.) exposed through search or strong parameters?
- Severity: HIGH.

---

### G. Structural Safeguards

**G1. Consent management**
- Read: `app/models/consent.rb` (if it exists), scanner `consent-use-purposes-constant` findings
- Check: Does the app have a consent model with `PURPOSES` constant and immutable audit trail? Is consent enforced in controllers (`RequiresConsent`)?
- Severity: MEDIUM if absent and the app processes PII.

**G2. DSAR workflow**
- Read: `app/models/data_subject_request.rb` (if it exists), related jobs and controllers
- Check: Can users request access to, rectification of, or erasure of their data? Is there a processing job? Is the export generated on-demand (not stored)?
- Severity: MEDIUM if absent.

**G3. Data retention**
- Read: `config/recurring.yml`, scheduled job configs, rake tasks
- Check: Are there automated jobs to anonymize inactive accounts, clean up old sessions, or purge stale data? Check alternative scheduling mechanisms (whenever gem, Kubernetes CronJobs, custom rake tasks).
- Severity: MEDIUM if absent.

**G4. DSAR vs processing export separation**
- Read: `app/serializers/**/*.rb` (if they exist)
- Check: If exports exist, is there a distinction between DSAR exports (return everything) and processing exports (respect consent)?
- Severity: MEDIUM if confused.

---

### H. Transport and Infrastructure

**H1. HTTPS enforcement**
- Read: `config/environments/production.rb`
- Check: Is `config.force_ssl = true` set (uncommented)?
- Outcome: PASS or FAIL (for checklist).

**H2. IP anonymization**
- Read: `Gemfile`, `config/application.rb`, middleware configs
- Check: Is `ip_anonymizer` or equivalent middleware configured? Is there a custom solution?
- Severity: MEDIUM if absent. Check for alternatives.

**H3. Log PII redaction (logstop or equivalent)**
- Read: `Gemfile`, `config/initializers/*.rb`
- Check: Is `logstop` or an alternative PII log redaction mechanism configured? Check for custom log subscribers, lograge with PII formatters, rails_semantic_logger.
- Severity: MEDIUM if absent with no alternative.

---

### I. Security Tooling

**I1. Static security analysis (brakeman or equivalent)**
- Read: `Gemfile`, then grep: `grep -ri 'brakeman\|snyk\|sonar\|rubocop-security' . --include='*.yml' --include='*.yaml' --include='*.json' --include='Makefile' --include='Dockerfile' --include='*.rb'`
- Check: Is brakeman or an equivalent static analysis tool present in Gemfile or CI config? Check `.codeclimate.yml`, `.github/workflows/`, `.circleci/`, `.gitlab-ci.yml`, Docker images.
- Severity: MEDIUM if absent.

**I2. Dependency vulnerability scanning (bundler-audit or equivalent)**
- Read: `Gemfile`, then grep: `grep -ri 'bundler.audit\|dependabot\|snyk' . --include='*.yml' --include='*.yaml' --include='*.json' --include='Makefile' --include='Dockerfile' --include='*.rb'`
- Check: Is bundler-audit or an equivalent present? Check `.codeclimate.yml`, Dependabot config (`.github/dependabot.yml`), Snyk, GitHub Security Alerts.
- Severity: MEDIUM if absent.

---

### J. Sanity Checks (run after all items above)

Before writing the final report, verify these count assertions. If any fails, you have a gap — go back and fix it.

**J1. Encryption finding count**
- Count the models in your verification matrix where `encrypts?` = NO and the model has PII columns.
- This count MUST equal the number of "unencrypted PII at rest" CRITICAL findings you are about to write.
- If they don't match, you missed a model or wrote a duplicate.

**J2. filter_attributes finding count**
- Count the models in your verification matrix where `filter_attributes?` = NO and the model has PII columns.
- This count MUST equal the number of "missing filter_attributes" HIGH findings.

**J3. ransackable_attributes coverage**
- Count the models in your verification matrix where `ransackable_attributes?` = YES and `ransackable reviewed?` = FINDING.
- Verify that each one has a corresponding data minimization finding.
- Also verify: every model where `ransackable_attributes?` = YES and `ransackable reviewed?` = PASS was genuinely reviewed and found to be safe.

**J4. Mailer coverage**
- Count the mailers from the A3 enumeration.
- Verify each one has been mentioned in the findings (as a finding or as checked-and-clean).

**J5. External service coverage**
- Count the external API calls from the A3 enumeration.
- Verify each one has been mentioned in the findings (as a finding or as checked-and-clean).

**J6. Scanner false positive reconciliation**
- Every scanner finding must appear EITHER as a verified finding in the report OR in the Dismissed Findings table with a reason. No scanner finding should silently vanish.
