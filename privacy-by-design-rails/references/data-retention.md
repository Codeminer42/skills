# Data Retention

Automate anonymization of inactive users and cleanup of stale sessions using Solid Queue scheduled jobs.

## Data Retention Job

```ruby
class DataRetentionJob < ApplicationJob
  self.log_arguments = false
  queue_as :maintenance

  RETENTION_PERIOD = 3.years

  def perform
    cutoff = RETENTION_PERIOD.ago

    User.customer
        .not_anonymized
        .where(updated_at: ...cutoff)
        .find_each do |user|
      next if user.orders.where(status: [:pending, :confirmed, :shipped]).exists?

      user.addresses.not_anonymized.find_each(&:anonymize!)
      user.anonymize!
    end
  end
end
```

## Session Cleanup Job

```ruby
class SessionCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    Session.where(updated_at: ...30.days.ago).delete_all
  end
end
```

## Solid Queue Schedule

```yaml
# config/recurring.yml
production:
  data_retention:
    class: DataRetentionJob
    queue: maintenance
    schedule: every Sunday at 3am

  session_cleanup:
    class: SessionCleanupJob
    queue: maintenance
    schedule: every day at 4am
```
