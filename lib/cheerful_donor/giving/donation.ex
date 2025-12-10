defmodule CheerfulDonor.Giving.Donation do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Giving,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "donations"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:amount, :currency, :status, :reference, :message],
      update: [:amount, :currency, :status, :reference, :message]
    ]
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
      constraints one_of: CheerfulDonor.Enums.donation_statuses()
    end

    attribute :reference, :string do
      allow_nil? false
      public? true
    end

    attribute :message, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor
    belongs_to :church, CheerfulDonor.Accounts.Church
    belongs_to :campaign, CheerfulDonor.Giving.Campaign, allow_nil?: true
    belongs_to :donation_intent, CheerfulDonor.Giving.DonationIntent do
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :transaction, CheerfulDonor.Payments.Transaction, allow_nil?: true
  end

end
