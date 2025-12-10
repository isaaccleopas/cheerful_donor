defmodule CheerfulDonor.Accounts.Church do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "churches"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read, :destroy,
    create: [
      :name,
      :email,
      :phone,
      :address
    ],
    update: [
      :name,
      :email,
      :phone,
      :address
    ]
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
    has_many :donors, CheerfulDonor.Accounts.Donor
    has_many :campaigns, CheerfulDonor.Giving.Campaign
    has_many :donations, CheerfulDonor.Giving.Donation
    has_many :payouts, CheerfulDonor.Payouts.Payout
  end
end
