defmodule CheerfulDonor.Accounts.Church do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "churches"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read, :destroy,
      create: [:name, :email, :phone, :address, :user_id],
      update: [:name, :email, :phone, :address]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :phone, :string, public?: true
    attribute :address, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :user, CheerfulDonor.Accounts.User,
      allow_nil?: true,
      public?: true

    has_many :campaigns, CheerfulDonor.Giving.Campaign
    has_many :donations, CheerfulDonor.Giving.Donation
    has_many :bank_accounts, CheerfulDonor.Payouts.BankAccount
    has_many :payouts, CheerfulDonor.Payouts.Payout
  end

  policies do
    policy action_type(:create) do
      authorize_if expr(actor(:role) == :admin)
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end
end
