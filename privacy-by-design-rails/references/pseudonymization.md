# Pseudonymization

Replace direct identifiers with irreversible tokens that still allow analytics. Data remains linked for statistical purposes but can't be traced back to individuals.

## UUID as Public Identifier

Never expose sequential database IDs in APIs. Use UUIDs instead.

```ruby
module Pseudonymizable
  extend ActiveSupport::Concern

  included do
    before_create :generate_pseudonym
  end

  private

  def generate_pseudonym
    self.uuid ||= SecureRandom.uuid
  end
end
```

## Pseudonymized Customer ID on Orders

A stable hash that survives user anonymization — analytics links preserved after erasure.

```ruby
class Order < ApplicationRecord
  belongs_to :user

  before_create :set_pseudonymized_customer_id

  private

  def set_pseudonymized_customer_id
    self.pseudonymized_customer_id ||= OpenSSL::HMAC.hexdigest(
      "SHA256", Rails.application.secret_key_base, user_id.to_s
    )
  end
end
```

After a user is anonymized, their orders still share the same `pseudonymized_customer_id`, enabling aggregate analytics without revealing who the customer was.
