---
title: Generate exports on-demand, never store decrypted PII
impact: MEDIUM
tags: export, pii, storage
---

## Generate exports on-demand, never store decrypted PII

**Impact: MEDIUM**

Storing a data export in a JSON metadata column defeats encryption at rest. The decrypted PII survives user anonymization and has no TTL.

**Incorrect:**

```ruby
def process_access(request)
  export = DataExportSerializer.new(request.user).as_json
  request.update!(metadata: { export: export })
end
```

**Correct:**

```ruby
# Job just marks the request as completed
def process_access(request)
end

# Controller generates on-demand when viewed
def serialize_request(request)
  {
    export: request.completed? && request.access? ?
      DataExportSerializer.new(request.user).as_json : nil
  }
end
```
