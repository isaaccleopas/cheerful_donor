defmodule CheerfulDonor.Giving.DonationIntent do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Giving,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "donation_intents"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read, :destroy,
    update: [:status, :meta]
  ]
    create :create do
      accept [:guest_email, :guest_name, :reference, :amount, :currency, :status, :meta, :donor_id, :campaign_id, :church_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :guest_email, :string, public?: true
    attribute :guest_name, :string, public?: true
    attribute :reference, :string do
      allow_nil? false
      public? true
    end

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
    attribute :meta, :map, public?: true
    timestamps()
  end

  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor do
      attribute_writable? true
      allow_nil? true
    end
    belongs_to :church, CheerfulDonor.Accounts.Church
    belongs_to :campaign, CheerfulDonor.Giving.Campaign, allow_nil?: true

    belongs_to :payment_method, CheerfulDonor.Billing.PaymentMethod, allow_nil?: true

    has_one :donation, CheerfulDonor.Giving.Donation do
      source_attribute :id                 # primary key in DonationIntent
      destination_attribute :donation_intent_id  # foreign key in Donation
    end
  end

  policies do
    policy action(:create) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(
        donor_id == ^actor(:donor_id) or is_nil(donor_id)
      )
    end
  end

end
