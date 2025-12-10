defmodule CheerfulDonor.Giving.Campaign do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Giving,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "campaigns"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:title, :description, :goal_amount, :is_active],
      update: [:title, :description, :goal_amount, :is_active]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :goal_amount, :integer do
      public? true
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    timestamps()
  end

  relationships do
    belongs_to :church, CheerfulDonor.Accounts.Church

    has_many :donations, CheerfulDonor.Giving.Donation
  end
  
end
