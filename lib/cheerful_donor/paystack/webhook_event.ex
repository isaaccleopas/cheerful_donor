defmodule CheerfulDonor.Paystack.WebhookEvent do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Paystack,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "webhook_events"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:event_type, :payload]
    end

    update :mark_processed do
      primary? true
      accept []
      change set_attribute(:processed, true)
      validate attribute_equals(:processed, false)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :event_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: CheerfulDonor.Enums.paystack_event_types()
    end

    attribute :payload, :map, public?: true
    attribute :processed, :boolean, default: false, public?: true
    timestamps()
  end
end
