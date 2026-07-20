defmodule CheerfulDonor.Payments.HandlePaystackEvent do
  @moduledoc """
  Maps Paystack webhook events to internal flows.
  """

  require Logger
  require Ash.Query

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Billing.Subscription
  alias CheerfulDonor.Payments
  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Payouts.Payout

  # ------------------------------------------------------------
  # Entry Point
  # ------------------------------------------------------------

  def process(payload, webhook_event \\ nil) do
    result =
      case payload["event"] do
        "charge.success" ->
          handle_charge_success(payload)

        "subscription.create" ->
          handle_subscription_create(payload)

        "subscription.disable" ->
          handle_subscription_disabled(payload)

        "invoice.payment_succeeded" ->
          handle_subscription_payment(payload)

        "invoice.payment_failed" ->
          handle_payment_failed(payload)

        "transfer.success" ->
          handle_transfer_success(payload)

        "transfer.failed" ->
          handle_transfer_failed(payload)

        event ->
          Logger.info("Ignoring unknown Paystack event: #{event}")
          :ignored
      end

    if webhook_event && result == :ok do
      webhook_event
      |> Ash.Changeset.for_update(:mark_processed, %{})
      |> Ash.update!(context: %{system: true})
    end

    result
  end

  # ------------------------------------------------------------
  # charge.success
  # ------------------------------------------------------------

  defp handle_charge_success(%{
         "data" =>
           %{
             "reference" => reference,
             "amount" => amount_kobo,
             "authorization" => authorization,
             "customer" => customer,
             "status" => "success"
           } = data
       }) do
    amount = div(amount_kobo, 100)
    auth_code = Map.get(authorization || %{}, "authorization_code")
    customer_code = Map.get(customer || %{}, "customer_code")
    channel = Map.get(authorization || %{}, "channel")

    case Giving.confirm_donation(%{
           reference: reference,
           amount: amount,
           channel: channel,
           customer_code: customer_code,
           authorization_code: auth_code,
           raw: data
         }) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("charge.success confirm failed #{inspect(error)}")
        {:error, error}
    end
  end

  # ------------------------------------------------------------
  # Helpers (legacy paths for subscription / transfer events)
  # ------------------------------------------------------------

  defp ensure_not_processed(reference) do
    case Giving.Donation
         |> Ash.Query.filter(reference == ^reference)
         |> Ash.read_one() do
      {:ok, nil} -> :ok
      {:ok, _} -> {:error, :already_processed}
      {:error, err} -> {:error, err}
    end
  end

  # ------------------------------------------------------------
  # subscription.create
  # ------------------------------------------------------------

  defp handle_subscription_create(%{
         "data" => %{
           "subscription_code" => subscription_code,
           "customer" => %{"customer_code" => customer_code}
         }
       }) do
    case Accounts.get_donor_by_paystack_customer_id(customer_code) do
      nil ->
        Logger.warning("Donor not found for subscription.create")

      donor ->
        case Billing.get_subscription_by_code(subscription_code) do
          {:ok, _} ->
            :already_exists

          _ ->
            Billing.create_subscription(%{
              donor_id: donor.id,
              subscription_code: subscription_code,
              status: :active
            })
        end
    end

    :ok
  end

  # ------------------------------------------------------------
  # invoice.payment_succeeded
  # ------------------------------------------------------------

  defp handle_subscription_payment(%{
         "data" => %{
           "subscription" => subscription_code,
           "amount" => amount_kobo,
           "reference" => reference
         }
       }) do
    amount = div(amount_kobo, 100)

    with {:ok, %Subscription{} = sub} <- Billing.get_subscription_by_code(subscription_code),
         :ok <- ensure_not_processed(reference),
         {:ok, _donation} <-
           Giving.create_donation(%{
             donor_id: sub.donor_id,
             campaign_id: sub.campaign_id,
             church_id: sub.church_id,
             amount: amount,
             currency: "NGN",
             status: :successful,
             reference: reference,
             type: :recurring
           }),
         {:ok, _txn} <-
           Payments.create_transaction(%{
             donor_id: sub.donor_id,
             amount: amount,
             currency: "NGN",
             status: :success,
             payment_provider: :paystack,
             reference: reference,
             paid_at: DateTime.utc_now()
           }),
         {:ok, _} <-
           sub
           |> Ash.Changeset.for_update(:update, %{
             last_paid_at: DateTime.utc_now(),
             status: :active
           })
           |> Ash.update(context: %{system: true}) do
      Logger.info("Recurring payment recorded #{subscription_code}")
    else
      error ->
        Logger.error("Recurring payment failed #{inspect(error)}")
    end

    :ok
  end

  # ------------------------------------------------------------
  # invoice.payment_failed
  # ------------------------------------------------------------

  defp handle_payment_failed(%{
         "data" => %{
           "subscription" => subscription_code
         }
       }) do
    case Billing.get_subscription_by_code(subscription_code) do
      %Subscription{} = sub ->
        sub
        |> Ash.Changeset.for_update(:update, %{status: :past_due})
        |> Ash.update()

      _ ->
        Logger.warning("Subscription not found for failure event")
    end

    :ok
  end

  defp handle_subscription_disabled(%{"data" => %{"subscription_code" => code}}) do
    case Billing.get_subscription_by_code(code) do
      {:ok, sub} ->
        sub
        |> Ash.Changeset.for_update(:update, %{status: :cancelled})
        |> Ash.update(context: %{system: true})

      _ ->
        Logger.warning("Subscription not found for disable event")
    end

    :ok
  end

  defp handle_transfer_success(%{"data" => %{"reference" => reference}}) do
    case get_payout(reference) do
      {:ok, payout} ->
        if payout.status == :success do
          :already_processed
        else
          payout
          |> Ash.Changeset.for_update(:update, %{
            status: :success,
            paid_at: DateTime.utc_now()
          })
          |> Ash.update(context: %{system: true})

          Logger.info("Payout marked successful #{reference}")
        end

      {:error, :not_found} ->
        Logger.warning("Payout not found for #{reference}")
    end

    :ok
  end

  defp handle_transfer_failed(%{"data" => %{"reference" => reference}}) do
    case get_payout(reference) do
      {:ok, payout} ->
        if payout.status == :failed do
          :already_processed
        else
          payout
          |> Ash.Changeset.for_update(:update, %{status: :failed})
          |> Ash.update(context: %{system: true})

          Logger.warning("Payout failed #{reference}")
        end

      {:error, :not_found} ->
        Logger.warning("Payout not found for #{reference}")
    end

    :ok
  end

  defp get_payout(reference) do
    case Payout
         |> Ash.Query.filter(reference == ^reference)
         |> Ash.read_one() do
      {:ok, nil} -> {:error, :not_found}
      {:ok, payout} -> {:ok, payout}
      {:error, err} -> {:error, err}
    end
  end
end
