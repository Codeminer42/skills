# Consent Management

> **Legal basis:** [GDPR Art. 7 — Conditions for consent](https://gdpr-info.eu/art-7-gdpr/), [LGPD Art. 8 — Consent](https://lgpd-brazil.info/chapter_02/article_08)

## Immutable Append-Only Audit Trail

Consents are never updated or deleted. Granting and revoking both create new records. The latest record for a purpose determines current status.

```ruby
class Consent < ApplicationRecord
  PURPOSES = %w[order_processing marketing analytics third_party_sharing].freeze

  belongs_to :user

  include DataExportable

  encrypts :ip_address

  enum :status, { granted: 0, revoked: 1 }

  exportable :purpose, :status, :granted_at, :revoked_at, :created_at

  validates :purpose, presence: true, inclusion: { in: PURPOSES }
  validates :status, presence: true
end
```

## HasConsent Concern — User API

```ruby
module HasConsent
  extend ActiveSupport::Concern

  def consent_granted?(purpose)
    latest = consents.where(purpose: purpose).order(created_at: :desc).first
    latest&.granted?
  end

  def grant_consent!(purpose, ip_address:)
    consents.create!(
      purpose: purpose,
      status: :granted,
      granted_at: Time.current,
      ip_address: ip_address
    )
  end

  def revoke_consent!(purpose)
    consents.create!(
      purpose: purpose,
      status: :revoked,
      revoked_at: Time.current
    )
  end
end
```

## RequiresConsent — Controller Enforcement

Consents must gate actual business logic, not just be stored and displayed.

```ruby
module RequiresConsent
  extend ActiveSupport::Concern

  private

  def require_consent!(purpose)
    return if current_user.consent_granted?(purpose)

    render json: {
      error: "consent_required",
      purpose: purpose,
      message: "You must grant '#{purpose}' consent before performing this action."
    }, status: :forbidden
  end
end
```

Usage:

```ruby
class OrdersController < BaseController
  include RequiresConsent

  before_action -> { require_consent!("order_processing") }, only: :create
end
```

## Consent-Gated vs. Unconditional Exports

**Important distinction:** Consent gates what you *process*, not what you *disclose back to the data subject*. DSAR access requests must return all personal data regardless of consent. Processing use cases (sharing with partners, marketing, analytics) must respect consent.

**DSAR export** (`DataExportSerializer`) — always returns everything:

```ruby
class DataExportSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      profile: @user.export_data,
      addresses: @user.addresses.map(&:export_data),
      orders: @user.orders.includes(:order_items).map(&:export_data),
      consents: @user.consents.map(&:export_data),
      analytics: {
        account_created_at: @user.created_at,
        total_orders: @user.orders.count,
        total_spent_cents: @user.orders.sum(:total_cents)
      }
    }
  end
end
```

**Processing export** (`ConsentGatedExportSerializer`) — only includes data the user consented to:

```ruby
class ConsentGatedExportSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    export = {
      profile: profile_data,
      addresses: @user.addresses.map(&:export_data),
      consents: @user.consents.map(&:export_data)
    }

    if @user.consent_granted?("order_processing")
      export[:orders] = @user.orders.includes(:order_items).map(&:export_data)
    end

    if @user.consent_granted?("analytics")
      export[:analytics] = {
        account_created_at: @user.created_at,
        total_orders: @user.orders.count,
        total_spent_cents: @user.orders.sum(:total_cents)
      }
    end

    export
  end

  private

  def profile_data
    data = @user.export_data

    unless @user.consent_granted?("marketing")
      data = data.except(:email_address)
    end

    data
  end
end
```
