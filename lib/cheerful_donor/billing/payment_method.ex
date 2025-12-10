defmodule CheerfulDonor.Billing.PaymentMethod do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payment_methods"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :paystack_authorization_code,
        :card_type,
        :last4,
        :exp_month,
        :exp_year,
        :bank,
        :reusable
      ],
      update: [
        :paystack_authorization_code,
        :card_type,
        :last4,
        :exp_month,
        :exp_year,
        :bank,
        :reusable
      ]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :paystack_authorization_code, :string do
      allow_nil? false
      public? true
    end

    attribute :card_type, :string do
      public? true
    end

    attribute :last4, :string do
      public? true
    end

    attribute :exp_month, :integer do
      public? true
    end

    attribute :exp_year, :integer do
      public? true
    end

    attribute :bank, :string do
      public? true
    end

    attribute :reusable, :boolean do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor

    has_many :subscriptions, CheerfulDonor.Billing.Subscription
    has_many :transactions, CheerfulDonor.Payments.Transaction
  end

end
