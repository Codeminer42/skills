---
title: Use Consent::PURPOSES for consent purposes
impact: MEDIUM
tags: consent, validation
---

## Use Consent::PURPOSES for consent purposes

**Impact: MEDIUM**

Free-form purpose strings invite typos and inconsistencies. All valid purposes are defined in `Consent::PURPOSES` and enforced by an inclusion validation.

**Incorrect:**

```ruby
user.grant_consent!("mktg", ip_address: request.remote_ip)
# "mktg" is not a valid purpose — silently wrong
```

**Correct:**

```ruby
# Consent::PURPOSES = %w[order_processing marketing analytics third_party_sharing]
user.grant_consent!("marketing", ip_address: request.remote_ip)
# Validated at the model level — invalid purposes raise ActiveRecord::RecordInvalid
```
