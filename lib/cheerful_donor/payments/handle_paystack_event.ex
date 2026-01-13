defmodule CheerfulDonor.Payments.HandlePaystackEvent do
  @moduledoc """
  Maps Paystack webhook events to internal flows.

  Handles:
    - One-time donations (`charge.success`)
    - Subscription created (`subscription.create`)
    - Recurring payments (`invoice.payment_succeeded`)
    - Failed recurring payments (`invoice.payment_failed`)
  """

  require Logger

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Billing.Subscription
  alias CheerfulDonor.Payments
  alias CheerfulDonor.Accounts

  # ------------------------------------------------------------
  # Entry Point
  # ------------------------------------------------------------
  def process(payload, webhook_event \\ nil) do
    result =
      case payload["event"] do
        "charge.success"            -> handle_charge_success(payload)
        "subscription.create"       -> handle_subscription_create(payload)
        "invoice.payment_succeeded" -> handle_subscription_payment(payload)
        "invoice.payment_failed"    -> handle_payment_failed(payload)
        _ ->
          Logger.info("Ignoring unknown Paystack event: #{payload["event"]}")
          :ignored
      end

    if webhook_event do
      case result do
        :ok -> Ash.update!(webhook_event, %{processed: true})
        :already_processed -> Ash.update!(webhook_event, %{processed: true})
        _ -> :noop
      end
    end

  end

  # ------------------------------------------------------------
  # ONE-TIME PAYMENT (charge.success)
  # ------------------------------------------------------------
  defp handle_charge_success(%{
        "data" => %{
          "reference" => reference,
          "amount" => amount_kobo,
          "status" => "success"
        } = data
      }) do
    amount = div(amount_kobo, 100)
    channel = Map.get(data, "channel", "unknown")

    case Giving.get_donation_intent(reference) do
      {:ok, %DonationIntent{} = intent} ->
        finalize_one_time_payment(intent, amount, channel)

      _ ->
        Logger.warning("DonationIntent not found for reference #{reference}")
        :missing_intent
    end
  end

  defp finalize_one_time_payment(%DonationIntent{status: :successful}, _amount, _channel) do
    :ok
  end

  defp finalize_one_time_payment(%DonationIntent{} = intent, amount, channel) do
    with {:ok, _intent} <-
          Giving.update_donation_intent(
            intent,
            %{},
            action: :mark_successful,
            context: %{system: true}
          ),
        {:ok, donation} <-
          Giving.create_donation(
            %{
              donor_id: intent.donor_id,
              campaign_id: intent.campaign_id,
              amount: amount,
              currency: intent.currency,
              reference: intent.reference,
              donation_intent_id: intent.id,
              type: :one_time,
              status: :successful
            },
            context: %{system: true}
          ),
        {:ok, _txn} <-
          Payments.create_transaction(
            %{
              donation_id: donation.id,
              donor_id: intent.donor_id,
              amount: amount,
              currency: intent.currency,
              status: :success,
              payment_provider: :paystack,
              reference: intent.reference,
              channel: channel,
              paid_at: DateTime.utc_now()
            },
            context: %{system: true}
          ) do

      Phoenix.PubSub.broadcast(
        CheerfulDonor.PubSub,
        "donor:#{intent.donor_id}",
        {:donation_confirmed, donation.id}
      )

      :ok
    else
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidAttribute{field: :donation_intent_id}]}} ->
        Logger.info("Donation already exists for intent #{intent.id}")
        :ok
    end
  end

  # ------------------------------------------------------------
  # SUBSCRIPTION CREATED (subscription.create)
  # ------------------------------------------------------------
  defp handle_subscription_create(%{
         "data" => %{
           "subscription_code" => subscription_code,
           "customer" => %{"email" => email}
         }
       }) do

    with {:ok, donor} <- Accounts.get_donor_by_email(email) do
      Billing.get_subscription_by_code(subscription_code)
      |> case do
        {:ok, _sub} ->
          :already_exists

        _ ->
          Billing.create_subscription(%{
            donor_id: donor.id,
            subscription_code: subscription_code,
            status: :active
          })
      end
    else
      _ ->
        Logger.warning("Donor not found for subscription.create email=#{email}")
    end

    :ok
  end

  # ------------------------------------------------------------
  # RECURRING PAYMENT SUCCESS (invoice.payment_succeeded)
  # ------------------------------------------------------------
  defp handle_subscription_payment(%{
        "data" => %{
          "subscription" => subscription_code,
          "amount" => amount_kobo,
          "status" => "success"
        }
      }) do

    amount = div(amount_kobo, 100)

    with {:ok, %Subscription{} = sub} <- Billing.get_subscription_by_code(subscription_code),
        {:ok, donor} <- Billing.get_donor_by_subscription(subscription_code),
        {:ok, _sub} <-
          Billing.update_subscription(
            sub,
            %{last_paid_at: DateTime.utc_now(), status: :active},
            context: %{system: true}
          ),
        {:ok, donation} <-
          Giving.create_donation(
            %{
              donor_id: donor.id,
              type: :recurring,
              amount: amount,
              currency: "NGN",
              status: :successful,
              reference: "sub-" <> subscription_code
            },
            context: %{system: true}
          ),
        {:ok, _txn} <-
          Payments.create_transaction(
            %{
              donation_id: donation.id,
              donor_id: donor.id,
              amount: amount,
              currency: "NGN",
              status: :success,
              payment_provider: :paystack,
              reference: "sub-" <> subscription_code
            },
            context: %{system: true}
          ) do

      Phoenix.PubSub.broadcast(
        CheerfulDonor.PubSub,
        "donor:#{donor.id}",
        {:recurring_payment, donation.id}
      )
    else
      {:error, error} ->
        Logger.error("Recurring payment failed: #{inspect(error)}")
    end

    :ok
  end

  # ------------------------------------------------------------
  # RECURRING PAYMENT FAILED (invoice.payment_failed)
  # ------------------------------------------------------------
  defp handle_payment_failed(%{
         "data" => %{
           "subscription" => subscription_code,
           "amount" => amount_kobo,
           "status" => "failed"
         }
       }) do

      amount = div(amount_kobo, 100)

    with {:ok, %Subscription{} = sub} <- Billing.get_subscription_by_code(subscription_code),
         {:ok, donor} <- Billing.get_donor_by_subscription(subscription_code) do

      Billing.update_subscription(sub, %{status: :past_due})

      {:ok, _txn} =
        Payments.create_transaction(%{
          donation_id: nil,
          intent_id: nil,
          donor_id: donor.id,
          amount: amount,
          status: :failed,
          payment_provider: :paystack,
          reference: "sub-failed-" <> subscription_code
        })

      Phoenix.PubSub.broadcast(
        CheerfulDonor.PubSub,
        "donor:#{donor.id}",
        {:recurring_payment_failed, sub.id}
      )
    else
      _ ->
        Logger.warning("Failed subscription payment_failed for #{subscription_code}")
    end

    :ok
  end
end
