---
title: Use the correct serializer for DSAR vs processing exports
impact: MEDIUM
tags: export, dsar, consent
---

## Use the correct serializer for DSAR vs processing exports

**Impact: MEDIUM**

Consent gates what you *process*, not what you *disclose back to the data subject*. DSAR access requests must return all personal data. Processing use cases (partner sharing, analytics) must respect consent.

**Incorrect — consent-gating a DSAR export:**

```ruby
# User asks for their data but you hide their orders
# because they revoked order_processing consent
render json: ConsentGatedExportSerializer.new(user).as_json
```

**Correct:**

```ruby
# DSAR access — always return everything
render json: DataExportSerializer.new(user).as_json

# Partner sharing — respect consent
render json: ConsentGatedExportSerializer.new(user).as_json
```
