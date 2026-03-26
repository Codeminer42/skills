---
title: Encrypt all PII fields
impact: CRITICAL
tags: encrypt, pii, activerecord
---

## Encrypt all PII fields

**Impact: CRITICAL**

Every column that stores personal data must use Active Record Encryption. Unencrypted PII means a database breach exposes plaintext names, emails, and phone numbers.

**Incorrect:**

```ruby
class User < ApplicationRecord
  # phone is stored as plaintext in the database
end
```

**Correct:**

```ruby
class User < ApplicationRecord
  encrypts :phone
end
```

Use `deterministic: true` only for fields that need exact-match queries (e.g., email for login). Use non-deterministic (the default) for everything else.
