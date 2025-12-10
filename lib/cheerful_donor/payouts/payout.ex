defmodule CheerfulDonor.Payouts.Payout do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Payouts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payouts"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read, :destroy,
    create: [
      :amount,
      :status,
      :paid_at,
      :reference
    ],
    update: [
      :amount,
      :status,
      :paid_at,
      :reference
    ]
  ]
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :integer do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: CheerfulDonor.Enums.payout_statuses()
    end

    attribute :paid_at, :utc_datetime, public?: true
    attribute :reference, :string, public?: true
    timestamps()
  end

  relationships do
    belongs_to :church, CheerfulDonor.Accounts.Church
    belongs_to :bank_account, CheerfulDonor.Payouts.BankAccount
  end

end
