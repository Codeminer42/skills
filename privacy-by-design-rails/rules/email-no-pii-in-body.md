---
title: Never include PII in email bodies, from, or subjects
impact: HIGH
tags: email, pii
---

## Never include PII in email bodies, from, or subjects

**Impact: HIGH**

Email sits in inboxes indefinitely. PII in the body, `from:` address, or subject line persists outside your control — you can't encrypt, rotate, or delete it. Subject lines are especially visible: they appear in inbox previews, notification banners, and lock screen alerts.

### PII in email body (template interpolation)

**Incorrect:**

```ruby
class DataExportMailer < ApplicationMailer
  def export_ready(user)
    @user = user
    # Template uses: "Hi <%= @user.first_name %>, here's your data..."
    mail to: user.email_address
  end
end
```

**Correct:**

```ruby
class DataExportMailer < ApplicationMailer
  def export_ready(user)
    @download_url = data_export_download_url(
      token: Rails.application.message_verifier("data_export")
               .generate(user.id, expires_in: 30.minutes)
    )
    # Template uses only the link — no name, no data preview
    mail subject: "Your data export is ready", to: user.email_address
  end
end
```

### PII in `from:` address

**Incorrect:**

```ruby
class NotificationsMailer < ApplicationMailer
  def new_comment(note, recipients)
    mail to: recipients, from: note.user.email,
         subject: "New comment on your story"
  end
end
```

**Correct:**

```ruby
class NotificationsMailer < ApplicationMailer
  def new_comment(note, recipients)
    mail to: recipients, from: ENV["MAILER_SENDER"],
         subject: "New comment on your story"
  end
end
```

### PII in subject line

**Incorrect:**

```ruby
mail subject: "#{actor.name} accepted your story '#{story.title}'"
```

**Correct:**

```ruby
mail subject: "Your story '#{story.title}' has been accepted"
```
