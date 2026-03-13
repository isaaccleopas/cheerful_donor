defmodule CheerfulDonor.Payouts do
  use Ash.Domain,
    otp_app: :cheerful_donor

  require Ash.Query

  alias CheerfulDonor.Payouts.BankAccount
  alias CheerfulDonor.Accounts

  resources do
    resource BankAccount
    resource CheerfulDonor.Payouts.Payout
  end

  # -----------------------------
  # Get Bank Account
  # -----------------------------

  def get_bank_account!(id, actor) do
    BankAccount
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(actor: actor)
  end

  def create_payout(attrs, actor) do
    Ash.create(CheerfulDonor.Payouts.Payout, attrs, actor: actor)
  end

  def update_payout(payout, attrs, actor) do
    Ash.update(payout, attrs, actor: actor)
  end

  def get_church(actor) do
    Accounts.Church
    |> Ash.Query.filter(user_id == ^actor.id)
    |> Ash.read_one(actor: actor)
  end
end
