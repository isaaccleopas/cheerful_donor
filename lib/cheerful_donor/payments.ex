defmodule CheerfulDonor.Payments do
  use Ash.Domain,
    otp_app: :cheerful_donor

  require Ash.Query
  alias CheerfulDonor.Payments.Transaction

  resources do
    resource Transaction
  end

  def get_transactions_for_donor(donor_id) do
    Transaction
    |> Ash.Query.filter(donor_id == ^donor_id)
    |> Ash.Query.load([:donation, :subscription])
    |> read!()
  end

  def create_transaction(attrs),
    do: Ash.create(Transaction, attrs)
end
