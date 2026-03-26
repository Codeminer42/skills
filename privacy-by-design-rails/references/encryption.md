# Encryption Spectrum

> **Source:** https://guides.rubyonrails.org/active_record_encryption.html

Rails 8 supports three levels of data protection. Choose based on the field's usage pattern.

## Setup

```bash
# Generate encryption keys
bin/rails db:encryption:init

# Store in credentials
bin/rails credentials:edit
```

Add to credentials:

```yaml
active_record_encryption:
  primary_key: <generated>
  deterministic_key: <generated>
  key_derivation_salt: <generated>
```

Enable reading unencrypted data during migration:

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = true
```

## Deterministic Encryption — Searchable

Same plaintext always produces same ciphertext. Enables `find_by` queries.

```ruby
class User < ApplicationRecord
  encrypts :email_address, deterministic: true, downcase: true
end

# This works:
User.find_by(email_address: "alice@example.com")
```

**Use for:** email (login lookups), any field you need to query by exact match.

## Non-Deterministic Encryption — Maximum Security

Same plaintext produces different ciphertext each time. Cannot be queried.

```ruby
class User < ApplicationRecord
  encrypts :first_name
  encrypts :last_name
  encrypts :phone
  encrypts :date_of_birth
end

class Address < ApplicationRecord
  encrypts :street
  encrypts :city
  encrypts :state
  encrypts :zip_code
end

class Consent < ApplicationRecord
  encrypts :ip_address
end

class Session < ApplicationRecord
  encrypts :ip_address
end
```

**Use for:** names, phone, addresses, IP addresses — anything you don't need to search by.

## Bcrypt Hashing — One-Way (Passwords)

```ruby
class User < ApplicationRecord
  has_secure_password
end
```

**Use for:** passwords. Cannot be decrypted, only verified via `authenticate`.

## Decision Guide

| Need to search by this field? | Need to read it back? | Use |
|---|----|---|
| Yes | Yes | `encrypts :field, deterministic: true` |
| No | Yes | `encrypts :field` |
| No | No (verify only) | `has_secure_password` |

## Adding Encryption to Existing Data (Brownfield)

Adding encryption to a model with existing unencrypted data requires a phased approach. Rushing this breaks reads, queries, and can cause data loss.

### Phase 1: Prepare — Enable unencrypted data support

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = true
config.active_record.encryption.extend_queries = true
```

- `support_unencrypted_data` lets Rails read both encrypted and unencrypted values from the same column. **Do not skip this** — without it, reading existing rows will raise decryption errors.
- `extend_queries` makes `find_by` on deterministic fields match both encrypted and unencrypted rows. **Without this, queries will miss unencrypted rows during the migration period.**

Generate encryption keys if not already configured:

```bash
bin/rails db:encryption:init
# Add the output to bin/rails credentials:edit
```

### Phase 2: Declare — Add `encrypts` to the model

```ruby
class User < ApplicationRecord
  encrypts :email_address, deterministic: true, downcase: true
  encrypts :first_name
  encrypts :phone
end
```

At this point:
- **New records** are written encrypted
- **Existing records** are read as unencrypted (transparent fallback)
- **Queries** work on both encrypted and unencrypted rows for deterministic fields

Deploy this and verify the app works normally before proceeding.

### Phase 3: Migrate — Re-encrypt existing data

Create a rake task (not a migration — data encryption is an operational task that may need to be re-run, monitored, or resumed). Use `encrypt` which reads the plaintext and writes it back encrypted via `update_columns` (bypasses validations and callbacks):

```ruby
# lib/tasks/encryption.rake
namespace :encryption do
  desc "Encrypt existing PII fields for a given model (e.g. rake encryption:backfill MODEL=User)"
  task backfill: :environment do
    model = ENV.fetch("MODEL").constantize
    total = model.count
    encrypted = 0
    skipped = 0

    model.find_each do |record|
      record.encrypt
      encrypted += 1
    rescue ActiveRecord::Encryption::Errors::Decryption
      skipped += 1
    end

    puts "Done. Encrypted: #{encrypted}, Already encrypted: #{skipped}, Total: #{total}"
  end
end
```

Usage:

```bash
bin/rails encryption:backfill MODEL=User
bin/rails encryption:backfill MODEL=Address
```

**Important:** Run this during low-traffic periods. Each `encrypt` call reads and writes the row.

### Phase 4: Verify — Confirm all data is encrypted

**Note:** `encrypted_attribute?` checks whether the model **declares** the attribute as encrypted — it does not check whether a specific row's value is actually encrypted. To verify actual data, use `ActiveRecord::Encryption::Encryptor#encrypted?` which tries to deserialize the raw value as an encrypted message ([API docs](https://api.rubyonrails.org/classes/ActiveRecord/Encryption/Encryptor.html)):

```ruby
# In a Rails console, check for remaining unencrypted rows:
encryptor = ActiveRecord::Encryption::Encryptor.new

unencrypted_count = User.find_each.count do |user|
  raw = user.ciphertext_for(:email_address)
  raw.present? && !encryptor.encrypted?(raw)
end
puts "Unencrypted rows remaining: #{unencrypted_count}"
```

### Phase 5: Lock down — Disable unencrypted data support

Only after confirming all rows are encrypted:

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = false
config.active_record.encryption.extend_queries = false
```

Now any unencrypted value will raise an error instead of silently being read as plaintext, and queries no longer need to check both forms.

### Brownfield Pitfalls

| Pitfall | What happens | Fix |
|---------|-------------|-----|
| Skipping `support_unencrypted_data` | Existing rows raise `Decryption` errors on read | Enable it before adding `encrypts` |
| Skipping `extend_queries` | `find_by` on deterministic fields misses unencrypted rows | Enable it alongside `support_unencrypted_data` |
| Disabling support before full migration | Remaining unencrypted rows become unreadable | Verify all rows first (Phase 4) |
| Running backfill during peak traffic | Row locks and high DB load | Run off-peak with `find_each` (batches internally) |
| Forgetting `deterministic: true` on searchable fields | `find_by` queries return nil for encrypted rows | Check the Decision Guide above |
| Using `downcase: true` when original case matters | Original casing is permanently lost | Use `ignore_case: true` instead — requires adding an `original_<column_name>` column to store the preserved-case value ([docs](https://guides.rubyonrails.org/active_record_encryption.html)) |
| Adding unique index on deterministic field before migration | Duplicate ciphertext/plaintext values violate uniqueness | Add index after all data is encrypted |
| Not testing rollback | If backfill fails mid-way, mixed state | `support_unencrypted_data` handles mixed state gracefully |

## Key Rotation

Plan for key rotation from the start — encryption keys may need to change when personnel leave or vulnerabilities are discovered. AR Encryption supports this via the `previous:` option for **non-deterministic** fields, which lets you read data encrypted with an old scheme while writing with the new one:

```ruby
class User < ApplicationRecord
  encrypts :first_name, previous: { key_provider: OldKeyProvider.new }
end
```

After rotating, re-encrypt existing records:

```ruby
User.find_each do |user|
  user.encrypt
end
```

**Important:** Key rotation is **not supported** for deterministic encryption. Deterministic fields (like `email_address`) always produce the same ciphertext for a given key — rotating the key would break all existing lookups. If you need to rotate a deterministic field's key, you must re-encrypt all existing records in a migration.
