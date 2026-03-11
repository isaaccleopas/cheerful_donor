defmodule CheerfulDonor.Payouts.Workers.ProcessPayout do
  use Oban.Worker

  alias CheerfulDonor.Payouts
  alias CheerfulDonor.Paystack.Client

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"payout_id" => payout_id}}) do
    payout =
      Payouts.Payout
      |> Ash.get!(payout_id)
      |> Ash.load!(:bank_account)

    reference = Ecto.UUID.generate()

    case Client.initiate_transfer(
           payout.bank_account.recipient_code,
           payout.amount,
           reference
         ) do
      {:ok, %{"data" => data}} ->
        Ash.update(payout, %{
          status: :processing,
          transfer_code: data["transfer_code"],
          reference: reference
        })

      {:error, error} ->
        {:error, error}
    end
  end
end
