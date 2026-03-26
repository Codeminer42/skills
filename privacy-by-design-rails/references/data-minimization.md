# Data Minimization

## Strong Parameters — Accept Only What's Needed

Only permit fields the action actually needs. Never permit role, internal IDs, or admin-only fields.

```ruby
class RegistrationsController < ApplicationController
  def create
    user = User.new(registration_params)
    user.role = :customer  # Defense in depth: force role even if params leak

    if user.save
      render json: { token: session.id, user: UserSerializer.new(user).as_json }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(
      :email_address, :password, :password_confirmation,
      :first_name, :last_name, :phone
    )
  end
end
```

## Serializers — Expose Only What's Needed in Responses

Plain Ruby serializers that explicitly declare which fields to expose. No internal IDs, no `password_digest`, no `role`, no `anonymized_at`.

```ruby
class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      uuid: @user.uuid,        # Public identifier, not sequential ID
      email: @user.email_address,
      first_name: @user.first_name,
      last_name: @user.last_name,
      phone: @user.phone,
      date_of_birth: @user.date_of_birth
    }
  end
end
```

## DataExportable Concern — Declare Exportable Fields Per Model

Controls what fields are included in DSAR data exports. Uses an allowlist approach — only explicitly declared fields are exported.

```ruby
module DataExportable
  extend ActiveSupport::Concern

  class_methods do
    def exportable(*fields)
      @exportable_fields = fields
    end

    def exportable_fields
      @exportable_fields || column_names.map(&:to_sym)
    end
  end

  def export_data
    self.class.exportable_fields.each_with_object({}) do |field, hash|
      hash[field] = public_send(field)
    end
  end
end
```

Usage in models:

```ruby
class User < ApplicationRecord
  include DataExportable
  exportable :uuid, :email_address, :first_name, :last_name, :phone, :date_of_birth
end

class Address < ApplicationRecord
  include DataExportable
  exportable :label, :street, :city, :state, :zip_code, :country
end

class Order < ApplicationRecord
  include DataExportable
  exportable :number, :status, :total_cents, :created_at
end
```
