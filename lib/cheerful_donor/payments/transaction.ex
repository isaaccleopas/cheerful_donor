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
    defaults [:read, :destroy,
    create: [
      :amount,
      :currency,
      :status,
      :reference,
      :payment_provider,
      :channel,
      :fees,
      :paid_at,
      :donor_id,
      :church_id,
      :subscription_id,
      :donation_id,
      :payment_method_id
    ],
    update: [
      :status,
      :fees,
      :paid_at
    ]
  ]
    read :for_donor do
      argument :donor_id, :uuid, allow_nil?: false
      filter expr(donor_id == ^arg(:donor_id))

      prepare build(load: [:donation, :subscription])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :integer do
      allow_nil? false
      public? true
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      default "NGN"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: CheerfulDonor.Enums.transaction_statuses()
    end

    attribute :reference, :string do
      allow_nil? false
      public? true
    end

    attribute :payment_provider, :atom do
      allow_nil? false
      default :paystack
      constraints one_of: [:paystack]
    end

    attribute :channel, :string, public?: true
    attribute :fees, :integer, public?: true
    attribute :paid_at, :utc_datetime, public?: true
    timestamps()
  end

  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor, allow_nil?: true
    belongs_to :church, CheerfulDonor.Accounts.Church, allow_nil?: true
    belongs_to :subscription, CheerfulDonor.Billing.Subscription, allow_nil?: true
    belongs_to :donation, CheerfulDonor.Giving.Donation, allow_nil?: true
    belongs_to :payment_method, CheerfulDonor.Billing.PaymentMethod, allow_nil?: true
  end

end
