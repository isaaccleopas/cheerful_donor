defmodule CheerfulDonor.Accounts.Donor do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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
    belongs_to :user, CheerfulDonor.Accounts.User do
      public? true
      allow_nil? false
    end

    has_many :payment_methods, CheerfulDonor.Billing.PaymentMethod
    has_many :donations, CheerfulDonor.Giving.Donation
    has_many :subscriptions, CheerfulDonor.Billing.Subscription
    has_many :transactions, CheerfulDonor.Payments.Transaction
  end

  policies do
    # allow create
    policy action_type(:create) do
      authorize_if always()
    end

    # user can read their own donor record
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end

    # user can update their own donor record
    policy action_type(:update) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  identities do
    identity :unique_user, [:user_id]
  end
end
