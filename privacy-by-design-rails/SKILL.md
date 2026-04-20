---
name: privacy-by-design-rails
description: "Implements privacy and data protection features in Rails applications, including encryption, consent management, DSAR handling, anonymization, and pseudonymization. Use when building Rails features that handle personal data, adding encryption to models, implementing consent flows, building DSAR endpoints, or adding anonymization/pseudonymization. Also use when reviewing code for compliance with privacy laws like GDPR and LGPD, or when asked about privacy-by-design patterns in Rails."
license: MIT
metadata:
  author: talyssonoc
  version: "1.0.1"
---

# Privacy by Design with Rails 8

When generating or reviewing code that handles personal data, run the scanner first:
`ruby .claude/skills/privacy-by-design-rails/scripts/scanner.rb --files <relevant files>`

If findings are reported, fix each one using the patterns in the corresponding rule from `rules/`, then re-run the scanner to confirm they resolve. For deeper context on any topic, read the relevant reference file from `references/`.

**What counts as PII?** Any data that can identify a person **directly or indirectly** (GDPR Art. 4, LGPD Art. 5, NIST SP 800-122). This includes data that isn't identifying alone but becomes PII when **linked** to a person — farm names, animal names with known owners, license plates, vehicle VINs, student IDs, property addresses, social media handles, company names of sole proprietors, device IDs linked to accounts, IP addresses. See `references/pii-definition.md` for the full definition and linkability test. **When in doubt, treat it as PII.**

## Quick Reference

| Principle | Rails Feature | File |
|-----------|--------------|------|
| Log + inspect filtering | `config.filter_parameters` (covers both) | references/log-and-output-protection.md |
| Per-model PII declaration | `self.filter_attributes` (self-documenting) | references/log-and-output-protection.md |
| Job arg protection (ActiveJob) | `self.log_arguments = false` (set in ApplicationJob) | references/log-and-output-protection.md |
| Job arg protection (Sidekiq) | Server middleware + pass IDs only | references/log-and-output-protection.md |
| PII redaction in logs | `logstop` gem | references/log-and-output-protection.md |
| IP anonymization | `ip_anonymizer` middleware | references/log-and-output-protection.md |
| Error reporter scrubbing | Scrub PII from Sentry/Rollbar/etc. | references/log-and-output-protection.md |
| APM/monitoring scrubbing | Scrub PII from AppSignal/NewRelic/etc. | references/log-and-output-protection.md |
| Data minimization | Strong parameters + serializers | references/data-minimization.md |
| Searchable encryption | `encrypts :field, deterministic: true` | references/encryption.md |
| Non-searchable encryption | `encrypts :field` | references/encryption.md |
| Password hashing | `has_secure_password` | references/encryption.md |
| Key rotation | `encrypts :field, previous: [...]` | references/encryption.md |
| Secrets management | `bin/rails credentials:edit` | references/secrets-management.md |
| Security auditing | bundler-audit, Brakeman, pdscan | references/secrets-management.md |
| HTTPS enforcement | `config.force_ssl = true` + HSTS | references/session-security.md |
| Session security | Signed cookies / Bearer tokens | references/session-security.md |
| Consent management | Immutable append-only audit trail | references/consent-management.md |
| Consent enforcement | Controller concern gating actions | references/consent-management.md |
| Consent-gated exports | `ConsentGatedExportSerializer` for processing | references/consent-management.md |
| Anonymization | Replace PII with `[ANONYMIZED]` | references/anonymization.md |
| Pseudonymization | HMAC hash preserving analytics links | references/pseudonymization.md |
| DSAR workflow | Access / Rectification / Erasure | references/dsar.md |
| Data retention | Solid Queue scheduled jobs | references/data-retention.md |

## Putting It All Together — The User Model

```ruby
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :consents, dependent: :destroy
  has_many :data_subject_requests, dependent: :destroy

  include Anonymizable
  include Pseudonymizable
  include DataExportable
  include HasConsent

  encrypts :email_address, deterministic: true, downcase: true
  encrypts :first_name
  encrypts :last_name
  encrypts :phone
  encrypts :date_of_birth

  self.filter_attributes = %i[
    first_name last_name phone date_of_birth
    email_address password_digest
  ]

  enum :role, { customer: 0, admin: 1 }

  anonymizable :first_name, :last_name, :phone, :date_of_birth
  exportable :uuid, :email_address, :first_name, :last_name, :phone, :date_of_birth

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
```

## Common Mistakes (not caught by scanner)

| Mistake | Fix |
|---------|-----|
| Deleting records with dependents for right to erasure | Prefer anonymization when the record has dependents — preserves referential integrity. Some authorities prefer true deletion, so check local requirements |
| Storing consents as a boolean flag | Use immutable append-only records for audit trail |
| Exposing sequential IDs in APIs | Use UUIDs as public identifiers |
| Manual data retention | Automate with Solid Queue scheduled jobs |

## External References

Consult these when you need the latest guidance or to verify patterns against official sources. Use WebFetch when needed — don't fetch all of them upfront.

### Rails

- Active Record Encryption: https://guides.rubyonrails.org/active_record_encryption.html
- Active Record Encryption API: https://api.rubyonrails.org/classes/ActiveRecord/Encryption.html
- Securing Rails Applications: https://guides.rubyonrails.org/security.html
- Active Job Basics (logging): https://guides.rubyonrails.org/active_job_basics.html
- Rails Credentials: https://guides.rubyonrails.org/security.html#custom-credentials

### GDPR

- Art. 5 — Principles (data minimization, purpose limitation): https://gdpr-info.eu/art-5-gdpr/
- Art. 6 — Lawfulness of processing: https://gdpr-info.eu/art-6-gdpr/
- Art. 7 — Conditions for consent: https://gdpr-info.eu/art-7-gdpr/
- Art. 15 — Right of access: https://gdpr-info.eu/art-15-gdpr/
- Art. 16 — Right to rectification: https://gdpr-info.eu/art-16-gdpr/
- Art. 17 — Right to erasure: https://gdpr-info.eu/art-17-gdpr/
- Art. 25 — Data protection by design and by default: https://gdpr-info.eu/art-25-gdpr/
- Art. 32 — Security of processing: https://gdpr-info.eu/art-32-gdpr/

### LGPD (Brazil)

- Full text (English): https://lgpd-brazil.info
- Art. 18 — Rights of the data subject: https://lgpd-brazil.info/chapter_03/article_18
- Art. 46 — Security measures: https://lgpd-brazil.info/chapter_07/article_46
