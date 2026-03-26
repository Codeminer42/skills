# DSAR (Data Subject Access Requests)

GDPR Articles 15-17: users have the right to access, rectify, and erase their data. ([Art. 15](https://gdpr-info.eu/art-15-gdpr/), [Art. 16](https://gdpr-info.eu/art-16-gdpr/), [Art. 17](https://gdpr-info.eu/art-17-gdpr/))
LGPD Article 18: users have the right to access, rectify, and erase their data. ([Art. 18](https://lgpd-brazil.info/chapter_03/article_18))

## Request Model

```ruby
class DataSubjectRequest < ApplicationRecord
  belongs_to :user

  enum :request_type, { access: 0, rectification: 1, erasure: 2 }
  enum :status, { pending: 0, approved: 1, processing: 2, completed: 3, rejected: 4 }

  validates :request_type, :status, presence: true

  scope :pending_review, -> { where(status: :pending) }

  def approve!
    update!(status: :approved)
    ProcessDataSubjectRequestJob.perform_later(id)
  end

  def reject!(reason:)
    update!(status: :rejected, notes: reason)
  end
end
```

## Processing Job

Handles all three DSAR types with `log_arguments = false` to prevent logging user IDs.

```ruby
class ProcessDataSubjectRequestJob < ApplicationJob
  self.log_arguments = false
  queue_as :privacy

  def perform(data_subject_request_id)
    request = DataSubjectRequest.find(data_subject_request_id)
    request.update!(status: :processing)

    case request.request_type
    when "access"        then process_access(request)
    when "rectification" then process_rectification(request)
    when "erasure"       then process_erasure(request)
    end

    request.update!(status: :completed, processed_at: Time.current)
  end

  private

  # Right of Access: no PII stored — export is generated on-demand when viewed
  def process_access(request)
  end

  # Right of Rectification: update specific fields
  def process_rectification(request)
    user = request.user
    rectification_data = request.metadata&.dig("rectification_data") || {}
    permitted_keys = %w[first_name last_name phone date_of_birth]
    safe_data = rectification_data.slice(*permitted_keys)
    user.update!(safe_data)
  end

  # Right of Erasure: anonymize all PII, revoke consents
  def process_erasure(request)
    user = request.user

    user.addresses.not_anonymized.find_each(&:anonymize!)
    user.anonymize!

    user.consents.where(status: :granted).find_each do |consent|
      user.revoke_consent!(consent.purpose)
    end
  end
end
```

## On-Demand Export (No PII at Rest)

Access request exports are generated on-the-fly when the user views the completed request, not stored in the database. This avoids storing decrypted PII in an unencrypted metadata column, which would defeat encryption at rest and survive user anonymization.

```ruby
# In the controller — generate on-demand, never store
def serialize_request(request)
  {
    id: request.id,
    request_type: request.request_type,
    status: request.status,
    created_at: request.created_at,
    processed_at: request.processed_at,
    export: request.completed? && request.access? ? DataExportSerializer.new(request.user).as_json : nil
  }
end
```

**Why not store the export?**
- The `metadata` JSON column is not encrypted — PII would sit in plaintext
- Erasure anonymizes User/Address but wouldn't clean up old export snapshots
- No TTL on `data_subject_requests` — PII would persist indefinitely
- Generating on-demand means the user always gets their current data, not a stale snapshot

## Workflow

1. **User submits** request (access/rectification/erasure)
2. **Admin reviews** and approves or rejects
3. **Job processes** asynchronously via `approve!` which enqueues `ProcessDataSubjectRequestJob`
4. **Status tracked** through: pending → approved → processing → completed
