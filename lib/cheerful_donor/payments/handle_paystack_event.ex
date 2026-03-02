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
  require Ash.Query

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Billing.Subscription
  alias CheerfulDonor.Payments
  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Paystack.Client

  # ------------------------------------------------------------
  # Entry Point
  # ------------------------------------------------------------
  def process(payload, webhook_event \\ nil) do
    result =
      case payload["event"] do
        "charge.success"            -> handle_charge_success(payload)
        # "subscription.create"       -> handle_subscription_create(payload)
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
          "authorization" => %{"authorization_code" => auth_code} = auth_data,
          "customer" => %{"customer_code" => customer_code},
          "status" => "success"
        }
      }) do
    amount = div(amount_kobo, 100)

    case DonationIntent |> Ash.Query.filter(reference == ^reference) |> Ash.read_one() do
      %DonationIntent{} = intent ->
        donor = Accounts.get_donor_by_id!(intent.donor_id)

        # Update donor Paystack customer ID if missing
        if is_nil(donor.paystack_customer_id) do
          donor
          |> Ash.Changeset.for_update(:update, %{paystack_customer_id: customer_code})
          |> Ash.update()
        end

        # Idempotency check
        case CheerfulDonor.Giving.Donation |> Ash.Query.filter(reference == ^reference) |> Ash.read_one() do
          %CheerfulDonor.Giving.Donation{} ->
            :already_processed

          nil ->
            # Mark intent successful
            {:ok, _intent} =
              intent
              |> Ash.Changeset.for_update(:mark_successful, %{})
              |> Ash.update(context: %{system: true})

            # Create Donation
            {:ok, donation} =
              CheerfulDonor.Giving.Donation
              |> Ash.Changeset.for_create(:create, %{
                donor_id: intent.donor_id,
                campaign_id: intent.campaign_id,
                church_id: intent.church_id,
                amount: amount,
                amount_paid: amount,
                currency: intent.currency,
                status: :successful,
                reference: reference,
                donation_intent_id: intent.id,
                type: :one_time
              })
              |> Ash.create(context: %{system: true})

            # Save transaction
            {:ok, _txn} =
              Payments.create_transaction(
                %{
                  donation_id: donation.id,
                  donor_id: intent.donor_id,
                  amount: amount,
                  currency: intent.currency,
                  status: :success,
                  payment_provider: :paystack,
                  reference: reference,
                  channel: Map.get(auth_data, "channel"),
                  paid_at: DateTime.utc_now()
                },
                context: %{system: true}
              )

            # Recurring plan creation if needed
            if intent.type == :recurring do
              interval = intent.interval || :monthly

              plan_code =
                case interval do
                  :daily -> System.get_env("PAYSTACK_DAILY_PLAN")
                  :weekly -> System.get_env("PAYSTACK_WEEKLY_PLAN")
                  :monthly -> System.get_env("PAYSTACK_MONTHLY_PLAN")
                  :quarterly -> System.get_env("PAYSTACK_QUARTERLY_PLAN")
                  :annually -> System.get_env("PAYSTACK_ANNUAL_PLAN")
                end

              if plan_code do
                {:ok, %{"data" => sub_data}} =
                  Client.create_subscription(%{
                    customer_code: customer_code,
                    plan_code: plan_code,
                    authorization: auth_code
                  })

                Billing.create_subscription(%{
                  donor_id: donor.id,
                  campaign_id: intent.campaign_id,
                  church_id: intent.church_id,
                  amount: amount,
                  interval: interval,
                  status: :active,
                  subscription_code: sub_data["subscription_code"]
                })
              else
                Logger.error("Missing Paystack plan code for interval #{interval}")
              end
            end

            Phoenix.PubSub.broadcast(
              CheerfulDonor.PubSub,
              "donor:#{intent.donor_id}",
              {:donation_confirmed, donation.id}
            )

            :ok
        end

      nil ->
        Logger.warning("DonationIntent not found for #{reference}")
        :missing_intent
    end
  end

  defp finalize_one_time_payment(%DonationIntent{status: :successful}, _amount, _channel), do: :ok

  defp finalize_one_time_payment(%DonationIntent{} = intent, amount, channel) do
    with {:ok, _intent} <-
          intent
          |> Ash.Changeset.for_update(:mark_successful, %{})
          |> Ash.update(context: %{system: true}),
        {:ok, donation} <-
          CheerfulDonor.Giving.Donation
          |> Ash.Changeset.for_create(:create, %{
                donor_id: intent.donor_id,
                campaign_id: intent.campaign_id,
                church_id: intent.church_id,
                amount: amount,
                amount_paid: amount,
                currency: intent.currency,
                reference: intent.reference,
                donation_intent_id: intent.id,
                type: :one_time,
                status: :successful
              })
          |> Ash.create(context: %{system: true}),
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

  # # ------------------------------------------------------------
  # # SUBSCRIPTION CREATED (subscription.create)
  # # ------------------------------------------------------------
  # defp handle_subscription_create(%{
  #       "data" => %{
  #         "subscription_code" => subscription_code,
  #         "customer" => %{"customer_code" => customer_code}
  #       }
  #     }) do

  #   case Accounts.get_donor_by_paystack_customer_id(customer_code) do
  #     nil ->
  #       Logger.warning("Donor not found for subscription.create customer_code=#{customer_code}")

  #     donor ->
  #       # Check if subscription already exists
  #       case Billing.get_subscription_by_code(subscription_code) do
  #         {:ok, _sub} ->
  #           :already_exists

  #         _ ->
  #           # Create subscription in your DB using Paystack's subscription_code
  #           Billing.create_subscription(%{
  #             donor_id: donor.id,
  #             subscription_code: subscription_code,
  #             status: :active
  #           })
  #       end
  #   end

  #   :ok
  # end

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
    unique_ref = "sub-#{subscription_code}-#{System.system_time(:second)}"

    # Idempotency check
    case CheerfulDonor.Giving.Donation |> Ash.Query.filter(reference == ^unique_ref) |> Ash.read_one() do
      %CheerfulDonor.Giving.Donation{} ->
        :already_processed

      nil ->
        with %Subscription{} = sub <- Billing.get_subscription_by_code!(subscription_code),
            donor <- Billing.get_donor_by_subscription!(subscription_code),
            {:ok, _sub} <-
              sub
              |> Ash.Changeset.for_update(:update, %{last_paid_at: DateTime.utc_now(), status: :active})
              |> Ash.update(context: %{system: true}),
            {:ok, donation} <-
              CheerfulDonor.Giving.Donation
              |> Ash.Changeset.for_create(:create, %{
                    donor_id: donor.id,
                    church_id: sub.church_id,
                    campaign_id: sub.campaign_id,
                    amount: amount,
                    amount_paid: amount,
                    currency: "NGN",
                    status: :successful,
                    reference: unique_ref,
                    type: :recurring
                  })
              |> Ash.create(context: %{system: true}),
            {:ok, _txn} <-
              Payments.create_transaction(
                %{
                  donation_id: donation.id,
                  donor_id: donor.id,
                  amount: amount,
                  currency: "NGN",
                  status: :success,
                  payment_provider: :paystack,
                  reference: unique_ref
                },
                context: %{system: true}
              ) do

          Phoenix.PubSub.broadcast(
            CheerfulDonor.PubSub,
            "donor:#{donor.id}",
            {:recurring_payment, donation.id}
          )
        else
          {:error, error} -> Logger.error("Recurring payment failed: #{inspect(error)}")
        end
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

    with %Subscription{} = sub <- Billing.get_subscription_by_code!(subscription_code),
        donor <- Billing.get_donor_by_subscription!(subscription_code),
        {:ok, _} <-
          sub
          |> Ash.Changeset.for_update(:update, %{status: :past_due})
          |> Ash.update(),
        {:ok, _txn} <-
          Payments.create_transaction(%{
            donation_id: nil,
            intent_id: nil,
            donor_id: donor.id,
            amount: amount,
            status: :failed,
            payment_provider: :paystack,
            reference: "sub-failed-#{subscription_code}"
          }) do

      Phoenix.PubSub.broadcast(
        CheerfulDonor.PubSub,
        "donor:#{donor.id}",
        {:recurring_payment_failed, sub.id}
      )
    else
      _ -> Logger.warning("Failed subscription payment_failed for #{subscription_code}")
    end

    :ok
  end
end
