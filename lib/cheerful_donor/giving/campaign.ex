defmodule CheerfulDonor.Giving.Campaign do
  require Ash.Expr
  import Ash.Expr

  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Giving,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "campaigns"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:title, :description, :goal_amount, :is_active, :church_id, :slug],
      update: [:title, :description, :goal_amount, :is_active]
    ]
    read :list_for_church do
      argument :church_id, :uuid

      filter expr(church_id == ^arg(:church_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :goal_amount, :integer do
      allow_nil? true
      public? true
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    attribute :type, :atom do
      allow_nil? false
      default :campaign
      constraints one_of: [:campaign, :offering, :tithe]
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    belongs_to :church, CheerfulDonor.Accounts.Church

    has_many :donations, CheerfulDonor.Giving.Donation
    has_many :donation_intents, CheerfulDonor.Giving.DonationIntent
  end

  policies do
    policy action_type(:create) do
      authorize_if expr(^actor(:role) == :admin)
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end

end
