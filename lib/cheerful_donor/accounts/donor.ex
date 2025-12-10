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
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    uuid_primary_key :id
    attribute :paystack_customer_id, :string
    attribute :phone, :string
    attribute :address, :string
    attribute :is_active, :boolean
    timestamps()
  end

  relationships do
    belongs_to :user, CheerfulDonor.Accounts.User, allow_nil?: true
    belongs_to :church, CheerfulDonor.Accounts.Church

    has_many :payment_methods, CheerfulDonor.Billing.PaymentMethod
    has_many :donations, CheerfulDonor.Giving.Donation
    has_many :subscriptions, CheerfulDonor.Billing.Subscription
    has_many :transactions, CheerfulDonor.Payments.Transaction
  end

end
