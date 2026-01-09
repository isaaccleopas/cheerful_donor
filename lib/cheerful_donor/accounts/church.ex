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

  identities do
    identity :unique_user_church, [:user_id]
  end

  policies do
    # Must be logged in
    policy always() do
      authorize_if actor_present()
    end

    policies do
      policy action(:create) do
        authorize_if expr(^actor(:role) == :admin)
        authorize_if CheerfulDonor.Accounts.Checks.AdminHasNoChurch
      end
    end

    # Only the owning admin can read/update/delete
    policy action([:read, :update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end
