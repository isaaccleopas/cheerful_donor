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
      create: [:amount, :currency, :status, :reference, :message, :donor_id, :church_id, :campaign_id, :donation_intent_id],
      update: [:amount, :amount_paid, :status, :message, :paystack_id]
    ]

    read :get_by_reference do
      argument :reference, :string, allow_nil?: false
      filter expr(reference == ^arg(:reference))
    end

    update :mark_as_paid do
      accept [:status, :amount_paid, :paystack_id]
      change set_attribute(:status, :success)
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
      constraints one_of: CheerfulDonor.Enums.donation_statuses()
    end

    attribute :reference, :string do
      allow_nil? false
      public? true
    end

    attribute :message, :string do
      public? true
    end

    attribute :amount_paid, :integer, allow_nil?: true
    attribute :paystack_id, :string, allow_nil?: true

    timestamps()
  end

  relationships do
    belongs_to :donor, CheerfulDonor.Accounts.Donor, allow_nil?: true
    belongs_to :church, CheerfulDonor.Accounts.Church
    belongs_to :campaign, CheerfulDonor.Giving.Campaign, allow_nil?: true
    belongs_to :donation_intent, CheerfulDonor.Giving.DonationIntent do
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :transaction, CheerfulDonor.Payments.Transaction, allow_nil?: true
  end

end
