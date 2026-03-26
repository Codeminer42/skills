# Anonymization (Right to Erasure)

Replace PII with `[ANONYMIZED]` instead of deleting records. This preserves referential integrity and audit trails while removing personal data.

## Anonymizable Concern

Requires an `anonymized_at` datetime column on the table.

```ruby
module Anonymizable
  extend ActiveSupport::Concern

  included do
    scope :anonymized, -> { where.not(anonymized_at: nil) }
    scope :not_anonymized, -> { where(anonymized_at: nil) }
  end

  def anonymize!
    return if anonymized?

    transaction do
      self.class.anonymizable_fields.each do |field|
        public_send(:"#{field}=", "[ANONYMIZED]")
      end
      self.anonymized_at = Time.current
      save!(validate: false)
    end
  end

  def anonymized?
    anonymized_at.present?
  end

  class_methods do
    def anonymizable(*fields)
      @anonymizable_fields = fields
    end

    def anonymizable_fields
      @anonymizable_fields || []
    end
  end
end
```

## Usage

```ruby
class User < ApplicationRecord
  include Anonymizable
  anonymizable :first_name, :last_name, :phone, :date_of_birth
end

class Address < ApplicationRecord
  include Anonymizable
  anonymizable :street, :city, :state, :zip_code
end
```

## Key Properties

- **Idempotent** — calling `anonymize!` twice is safe (returns early if already anonymized)
- **Transactional** — all fields replaced atomically
- **Skips validation** — `save!(validate: false)` because `[ANONYMIZED]` may not pass format validations
- **Scoped** — `User.anonymized` / `User.not_anonymized` for querying
