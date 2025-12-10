defmodule CheerfulDonor.Payments.Transaction do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Payments,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "transactions"
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

    attribute :currency, :string do
      allow_nil? false
    end

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: CheerfulDonor.Enums.transaction_statuses()
    end

    attribute :reference, :string do
      allow_nil? false
    end

    attribute :channel, :string
    attribute :fees, :integer
    attribute :paid_at, :utc_datetime
    timestamps()
  end

  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor
    belongs_to :church, CheerfulDonor.Accounts.Church
    belongs_to :subscription, CheerfulDonor.Billing.Subscription, allow_nil?: true
    belongs_to :donation, CheerfulDonor.Giving.Donation, allow_nil?: true
    belongs_to :payment_method, CheerfulDonor.Billing.PaymentMethod, allow_nil?: true
  end

end
