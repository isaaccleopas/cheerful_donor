defmodule CheerfulDonor.Giving.DonationIntent do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Giving,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "donation_intents"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read, :destroy, create: [], update: []]
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      allow_nil? false
    end

    attribute :amount, :integer do
      allow_nil? false
    end

    attribute :currency, :string do
      allow_nil? false
      default "NGN"
    end

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: CheerfulDonor.Enums.donation_statuses()
    end
    attribute :meta, :map
    timestamps()
  end

  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor
    belongs_to :church, CheerfulDonor.Accounts.Church
    belongs_to :campaign, CheerfulDonor.Giving.Campaign, allow_nil?: true

    belongs_to :payment_method, CheerfulDonor.Billing.PaymentMethod, allow_nil?: true

    has_one :donation, CheerfulDonor.Giving.Donation do
      source_attribute :id                 # primary key in DonationIntent
      destination_attribute :donation_intent_id  # foreign key in Donation
    end
  end

end
