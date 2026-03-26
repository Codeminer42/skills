---
title: Never cache objects containing PII
impact: HIGH
tags: log, cache, pii
---

## Never cache objects containing PII

**Impact: HIGH**

Cache stores (Redis, Memcached) hold data unencrypted. Caching a full ActiveRecord object puts decrypted PII in plaintext outside the encrypted database.

**Incorrect:**

```ruby
Rails.cache.fetch("user:#{id}") { user }
```

**Correct:**

```ruby
# Cache only non-sensitive data
Rails.cache.fetch("user:#{id}:order_count") { user.orders.count }
```
