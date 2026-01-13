defmodule CheerfulDonor.Giving.Donation do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Giving,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "donations"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:amount, :currency, :status, :reference, :message, :type, :donor_id, :church_id, :campaign_id, :donation_intent_id],
      update: [:amount, :amount_paid, :status, :message, :paystack_id]
    ]

    read :get_by_reference do
      argument :reference, :string, allow_nil?: false
      filter expr(reference == ^arg(:reference))
    end

    update :mark_as_paid do
      accept [:amount_paid, :paystack_id]
      change set_attribute(:status, :successful)
    end

    read :for_donor do
      argument :donor_id, :uuid, allow_nil?: false
      filter expr(donor_id == ^arg(:donor_id))

      prepare build(load: [:campaign])
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

    attribute :type, :atom do
      allow_nil? false
      default :one_time
      constraints one_of: [:one_time, :recurring]
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

  policies do
    policy action_type(:read) do
      authorize_if expr(donor_id == ^actor(:donor_id))
    end

    policy action(:create) do
      authorize_if context_equals(:system, true)
    end

    policy action(:update) do
      authorize_if context_equals(:system, true)
    end
  end

  identities do
    identity :unique_intent, [:donation_intent_id]
  end

end
