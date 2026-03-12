defmodule CheerfulDonor.Payments.HandlePaystackEvent do
  @moduledoc """
  Maps Paystack webhook events to internal flows.
  """

  require Logger
  require Ash.Query

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Billing.Subscription
  alias CheerfulDonor.Payments
  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Paystack.Client
  alias CheerfulDonor.Paystack.Plans

  # ------------------------------------------------------------
  # Entry Point
  # ------------------------------------------------------------

  def process(payload, webhook_event \\ nil) do
    result =
      case payload["event"] do
        "charge.success" -> handle_charge_success(payload)
        "subscription.create" -> handle_subscription_create(payload)
        "invoice.payment_succeeded" -> handle_subscription_payment(payload)
        "invoice.payment_failed" -> handle_payment_failed(payload)
        event ->
          Logger.info("Ignoring unknown Paystack event: #{event}")
          :ignored
      end

    if webhook_event && result in [:ok, :already_processed] do
      Ash.update!(webhook_event, %{processed: true})
    end

    result
  end

  # ------------------------------------------------------------
  # charge.success
  # ------------------------------------------------------------

  defp handle_charge_success(%{
         "data" => %{
           "reference" => reference,
           "amount" => amount_kobo,
           "authorization" => %{"authorization_code" => auth_code} = auth_data,
           "customer" => %{"customer_code" => customer_code},
           "status" => "success"
         }
       }) do
    amount = div(amount_kobo, 100)

    with {:ok, %DonationIntent{} = intent} <- get_intent(reference),
         {:ok, donor} <- get_donor(intent),
         :ok <- ensure_customer_id(donor, customer_code),
         :ok <- ensure_not_processed(reference),
         {:ok, _intent} <- mark_intent_success(intent),
         {:ok, donation} <- create_donation(intent, amount),
         {:ok, _txn} <- create_transaction(donation, intent, amount, auth_data),
         :ok <- maybe_create_subscription(intent, donor, customer_code, auth_code, amount),
         :ok <- broadcast_success(intent, donation) do
      :ok
    else
      {:error, :intent_missing} ->
        Logger.warning("DonationIntent not found for #{reference}")
        :missing_intent

      {:error, :already_processed} ->
        :already_processed

      {:error, error} ->
        Logger.error("charge.success failed #{inspect(error)}")
        {:error, error}
    end
  end

  # ------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------

  defp get_intent(reference) do
    case DonationIntent
         |> Ash.Query.filter(reference == ^reference)
         |> Ash.read_one() do
      {:ok, nil} -> {:error, :intent_missing}
      {:ok, intent} -> {:ok, intent}
      {:error, err} -> {:error, err}
    end
  end

  defp get_donor(intent) do
    {:ok, Accounts.get_donor_by_id!(intent.donor_id)}
  end

  defp ensure_customer_id(donor, customer_code) do
    if is_nil(donor.paystack_customer_id) do
      donor
      |> Ash.Changeset.for_update(:update, %{paystack_customer_id: customer_code})
      |> Ash.update()
    end

    :ok
  end

  defp ensure_not_processed(reference) do
    case Giving.Donation
         |> Ash.Query.filter(reference == ^reference)
         |> Ash.read_one() do
      {:ok, nil} -> :ok
      {:ok, _} -> {:error, :already_processed}
      {:error, err} -> {:error, err}
    end
  end

  defp mark_intent_success(intent) do
    intent
    |> Ash.Changeset.for_update(:mark_successful, %{})
    |> Ash.update(context: %{system: true})
  end

  defp create_donation(intent, amount) do
    Giving.Donation
    |> Ash.Changeset.for_create(:create, %{
      donor_id: intent.donor_id,
      campaign_id: intent.campaign_id,
      church_id: intent.church_id,
      amount: amount,
      amount_paid: amount,
      currency: intent.currency,
      status: :successful,
      reference: intent.reference,
      donation_intent_id: intent.id,
      type: intent.type
    })
    |> Ash.create(context: %{system: true})
  end

  defp create_transaction(donation, intent, amount, auth_data) do
    Payments.create_transaction(
      %{
        donation_id: donation.id,
        donor_id: intent.donor_id,
        amount: amount,
        currency: intent.currency,
        status: :success,
        payment_provider: :paystack,
        reference: intent.reference,
        channel: Map.get(auth_data, "channel"),
        paid_at: DateTime.utc_now()
      },
      context: %{system: true}
    )
  end

  defp broadcast_success(intent, donation) do
    Phoenix.PubSub.broadcast(
      CheerfulDonor.PubSub,
      "donor:#{intent.donor_id}",
      {:donation_confirmed, donation.id}
    )

    :ok
  end

  # ------------------------------------------------------------
  # Create Subscription
  # ------------------------------------------------------------

  defp maybe_create_subscription(intent, donor, customer_code, auth_code, amount) do
    if intent.type != :recurring do
      :ok
    else
      interval = intent.interval || :monthly

      with {:ok, plan_code} <- Plans.get_or_create(interval, intent.amount),
           {:ok, %{"data" => sub_data}} <-
             Client.create_subscription(%{
               customer_code: customer_code,
               plan_code: plan_code,
               authorization: auth_code
             }),
           {:ok, next_charge_at, _} <- DateTime.from_iso8601(sub_data["next_payment_date"]),
           {:ok, _sub} <-
             Billing.create_subscription(%{
               donor_id: donor.id,
               campaign_id: intent.campaign_id,
               church_id: intent.church_id,
               amount: amount,
               interval: interval,
               status: :active,
               subscription_code: sub_data["subscription_code"],
               next_charge_at: next_charge_at
             }) do
        :ok
      else
        error ->
          Logger.error("Subscription creation failed #{inspect(error)}")
          :ok
      end
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
end
