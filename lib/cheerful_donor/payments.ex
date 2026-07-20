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
    |> Ash.Query.for_read(:for_donor, %{donor_id: donor_id})
    |> Ash.read!()
  end

  def create_transaction(attrs, opts \\ []) do
    context = Keyword.get(opts, :context, %{})

    Transaction
    |> Ash.Changeset.for_create(:create, attrs, context: context)
    |> Ash.create()
  end
end
