defmodule CheerfulDonor.Billing.Subscription do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "subscriptions"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :integer do
      allow_nil? false
    end

    attribute :interval, :atom do
      allow_nil? false
      constraints one_of: CheerfulDonor.Enums.subscription_intervals()
    end

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: CheerfulDonor.Enums.subscription_statuses()
    end

    attribute :next_charge_at, :utc_datetime
    timestamps()
  end
  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor
    belongs_to :church, CheerfulDonor.Accounts.Church
    belongs_to :payment_method, CheerfulDonor.Billing.PaymentMethod

    has_many :transactions, CheerfulDonor.Payments.Transaction
  end

end
