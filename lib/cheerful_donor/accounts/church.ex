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
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :email, :string do
      allow_nil? false
    end

    attribute :phone, :string
    attribute :address, :string
    timestamps()
  end
  relationships do
    has_many :donors, CheerfulDonor.Accounts.Donor
    has_many :campaigns, CheerfulDonor.Giving.Campaign
    has_many :donations, CheerfulDonor.Giving.Donation
    has_many :payouts, CheerfulDonor.Payouts.Payout
  end
end
