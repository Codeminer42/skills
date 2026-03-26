# Session Security

> **Source:** https://guides.rubyonrails.org/security.html

## HTTPS Enforcement

All data in transit must be encrypted. Force SSL and enable HSTS (HTTP Strict Transport Security) so browsers never make a plaintext request:

```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = { hsts: { subdomains: true, preload: true, expires: 1.year } }
```

`force_ssl` redirects HTTP to HTTPS and sets the `Secure` flag on cookies. HSTS tells browsers to always use HTTPS for future requests, even if the user types `http://`.

## Cookie-Based Auth (Web UI)

```ruby
# Login
session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }

# Authenticate
def current_user
  @current_user ||= if (session = Session.find_by(id: cookies.signed[:session_id]))
    session.user
  end
end

# Logout
Session.find_by(id: cookies.signed[:session_id])&.destroy
cookies.delete(:session_id)
```

## Bearer Token Auth (API)

```ruby
# Login response
render json: { token: session.id }

# Authenticate
def find_session_by_token
  if (token = request.headers["Authorization"]&.delete_prefix("Bearer "))
    Session.find_by(id: token)
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
