defmodule CheerfulDonor.Accounts.Donor do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "donors"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:paystack_customer_id, :phone, :address, :is_active, :user_id],
      update: [:paystack_customer_id, :phone, :address, :is_active]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :paystack_customer_id, :string, public?: true
    attribute :phone, :string, public?: true
    attribute :address, :string, public?: true

    attribute :is_active, :boolean,
      default: true,
      public?: true

    timestamps()
  end

  relationships do
    belongs_to :user, CheerfulDonor.Accounts.User,
      allow_nil?: false,
      public?: true

    has_many :payment_methods, CheerfulDonor.Billing.PaymentMethod
    has_many :donations, CheerfulDonor.Giving.Donation
    has_many :subscriptions, CheerfulDonor.Billing.Subscription
    has_many :transactions, CheerfulDonor.Payments.Transaction
  end

  identities do
    identity :unique_user, [:user_id]
  end
end
