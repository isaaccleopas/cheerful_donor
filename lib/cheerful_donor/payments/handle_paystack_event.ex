defmodule CheerfulDonor.Payments.HandlePaystackEvent do
  alias CheerfulDonor.Giving
  alias CheerfulDonor.Payments
  alias CheerfulDonor.Giving.{DonationIntent, Donation}
  alias CheerfulDonor.Payments.Transaction

  @moduledoc """
  Maps Paystack events into internal DonationIntent → Donation → Transaction flows.
  """

  # Entry point
  def process(%{"event" => event} = payload) do
    case event do
      "charge.success" ->
        handle_charge_success(payload)

      "subscription.create" ->
        handle_subscription_create(payload)

      "invoice.payment_failed" ->
        handle_payment_failed(payload)

      "invoice.payment_succeeded" ->
        handle_subscription_payment(payload)

      _ ->
        :ignored
    end
  end

  # -------------------------------------------------------------------
  # ONE-TIME PAYMENT SUCCESS
  # -------------------------------------------------------------------
  defp handle_charge_success(%{
         "data" => %{
           "reference" => reference,
           "amount" => amount_kobo,
           "status" => "success",
           "customer" => %{"email" => email}
         }
       }) do
    amount = amount_kobo / 100

    case Giving.get_donation_intent(reference) do
      {:ok, %DonationIntent{} = intent} ->
        finalize_one_time_payment(intent, amount, email)

      _ ->
        :missing_intent
    end
  end

  defp finalize_one_time_payment(intent, amount, _email) do
    Giving.update_donation_intent(intent, %{status: :paid})

    {:ok, donation} =
      Giving.create_donation(%{
        donor_id: intent.donor_id,
        campaign_id: intent.campaign_id,
        amount: amount,
        currency: intent.currency,
        type: :one_time
      })

    Payments.create_transaction(%{
      donation_id: donation.id,
      intent_id: intent.id,
      amount: amount,
      status: :successful,
      reference: intent.reference,
      payment_provider: :paystack
    })

    # optional real-time update
    Phoenix.PubSub.broadcast(
      CheerfulDonor.PubSub,
      "donor:#{intent.donor_id}",
      {:donation_confirmed, donation.id}
    )

    :ok
  end

  # -------------------------------------------------------------------
  # SUBSCRIPTION CREATED
  # -------------------------------------------------------------------
  defp handle_subscription_create(%{
         "data" => %{
           "subscription_code" => subscription_code,
           "email_token"       => email_token,
           "customer"          => %{"email" => email}
         }
       }) do
    # TODO: Save subscription to donor record if needed.
    :ok
  end

  # -------------------------------------------------------------------
  # SUBSCRIPTION PAYMENT SUCCESS
  # -------------------------------------------------------------------
  defp handle_subscription_payment(%{
         "data" => %{
           "subscription" => subscription_code,
           "amount" => amount_kobo,
           "status" => "success"
         }
       }) do
    amount = amount_kobo / 100

    # Look up donor by subscription_code
    with {:ok, donor} <- Giving.get_donor_by_subscription(subscription_code) do
      create_recurring_payment(donor, amount)
    end
  end

  defp create_recurring_payment(donor, amount) do
    {:ok, donation} =
      Giving.create_donation(%{
        donor_id: donor.id,
        type: :recurring,
        amount: amount,
        currency: "NGN"
      })

    Payments.create_transaction(%{
      donation_id: donation.id,
      amount: amount,
      status: :successful,
      payment_provider: :paystack,
      reference: "sub-" <> Ecto.UUID.generate()
    })

    Phoenix.PubSub.broadcast(
      CheerfulDonor.PubSub,
      "donor:#{donor.id}",
      {:recurring_payment, donation.id}
    )

    :ok
  end

  # -------------------------------------------------------------------
  # SUBSCRIPTION PAYMENT FAILURE
  # -------------------------------------------------------------------
  defp handle_payment_failed(payload) do
    # Create a failed transaction + notify donor/admin
    :ok
  end
end
