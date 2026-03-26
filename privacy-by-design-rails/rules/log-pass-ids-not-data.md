---
title: Pass IDs to jobs, never PII
impact: HIGH
tags: log, jobs, pii, activejob, sidekiq
---

## Pass IDs to jobs, never PII

**Impact: HIGH**

Job arguments are serialized into the queue backend (Redis, database) and appear in dashboards, logs, and monitoring tools. PII in the payload sits in plaintext outside the encrypted database. This applies to **all** background job frameworks — ActiveJob, Sidekiq, Delayed Job, Good Job, Que, Shoryuken, and others.

**Incorrect (ActiveJob):**

```ruby
ProcessOrderConfirmationJob.perform_later(
  email: "maria@example.com",
  name: "Maria Silva",
  order_total: 15000
)
```

**Incorrect (Sidekiq):**

```ruby
class ProcessOrderConfirmationWorker
  include Sidekiq::Job

  def perform(email, name, order_total)
    # email and name are stored in Redis and visible in Sidekiq Web UI
  end
end

ProcessOrderConfirmationWorker.perform_async("maria@example.com", "Maria Silva", 15000)
```

**Correct (ActiveJob):**

```ruby
ProcessOrderConfirmationJob.perform_later(order.id)

class ProcessOrderConfirmationJob < ApplicationJob
  self.log_arguments = false

  def perform(order_id)
    order = Order.find(order_id)
    user = order.user
    # PII only exists in memory, never serialized to the queue
  end
end
```

**Correct (Sidekiq):**

```ruby
ProcessOrderConfirmationWorker.perform_async(order.id)

class ProcessOrderConfirmationWorker
  include Sidekiq::Job

  def perform(order_id)
    order = Order.find(order_id)
    user = order.user
    # PII only exists in memory, never serialized to Redis
  end
end
```
