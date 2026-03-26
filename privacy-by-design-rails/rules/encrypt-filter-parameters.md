---
title: Declare PII in filter_parameters and filter_attributes
impact: CRITICAL
tags: encrypt, filter, logs
---

## Declare PII in filter_parameters and filter_attributes

**Impact: CRITICAL**

New PII fields must be added to both `config.filter_parameters` (global — filters logs and `#inspect`) and `self.filter_attributes` on the model (self-documenting — makes PII fields explicit when reading the model).

**Incorrect — adding a PII field without declaring it:**

```ruby
# Migration adds :national_id column
# No update to filter_parameter_logging.rb
# No update to model's filter_attributes

class User < ApplicationRecord
  encrypts :national_id
end
```

**Correct:**

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [:national_id]

# app/models/user.rb
class User < ApplicationRecord
  encrypts :national_id

  self.filter_attributes = %i[
    first_name last_name phone date_of_birth
    email_address password_digest national_id
  ]
end
```
