defmodule CheerfulDonor.Donations.HandlePaystackEvent do
  alias CheerfulDonor.Donations
  alias CheerfulDonor.Donations.{Donation}
  require Logger

  def run(%{"event" => "charge.success", "data" => data}) do
    donation_code = data["reference"]
    amount = data["amount"] / 100

    donation =
      Donation
      |> Ash.Query.for_read(:get_by_reference, %{reference: donation_code})
      |> Ash.read_one()

    case donation do
      {:ok, nil} ->
        Logger.error("Donation reference #{donation_code} not found")

      {:ok, donation} ->
        Donations.update_donation(donation, %{
          status: :success,
          amount_paid: amount,
          paystack_id: data["id"]
        })

        CheerfulDonorWeb.Endpoint.broadcast(
          "donation:#{donation.user_id}",
          "donation_paid",
          %{amount: amount, reference: donation_code}
        )
    end
  end

  def run(other) do
    Logger.info("Unhandled Paystack Event: #{inspect(other)}")
    :ok
  end
end
