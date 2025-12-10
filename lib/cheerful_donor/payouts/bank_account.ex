defmodule CheerfulDonor.Payouts.BankAccount do
  use Ash.Resource,
    otp_app: :cheerful_donor,
    domain: CheerfulDonor.Payouts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "bank_accounts"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read, :destroy, create: [
      :bank_name,
      :account_number,
      :account_name
    ], update: [
      :bank_name,
      :account_number,
      :account_name
    ]]
  end

  attributes do
    uuid_primary_key :id

    attribute :bank_name, :string do
      allow_nil? false
      public? true
    end

    attribute :account_number, :string do
      allow_nil? false
      public? true
    end

    attribute :account_name, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :church, CheerfulDonor.Accounts.Church
    has_many :payouts, CheerfulDonor.Payouts.Payout
  end

end
