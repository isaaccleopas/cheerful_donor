defmodule CheerfulDonor.Giving.Lookups.Donation do
  use Ash.Resource,
    domain: CheerfulDonor.Giving,
    data_layer: AshPostgres.DataLayer

  use Commanded.Event.Handler,
    application: CheerfulDonor.CommandedApp,
    name: "#{__MODULE__}-V1",
    consistency: :strong

  require Logger
  require Ash.Query

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Giving.InitiateDonation.DonationInitiatedV1
  alias CheerfulDonor.Giving.ConfirmDonation.DonationConfirmedV1
  alias CheerfulDonor.Giving.FailDonation.DonationFailedV1
  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Payments
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Paystack.Client
  alias CheerfulDonor.Paystack.Plans

  postgres do
    table "giving__lookups__donation"
    repo CheerfulDonor.Repo
  end

  actions do
    defaults [:read]

    create :upsert do
      accept [
        :reference,
        :amount,
        :currency,
        :status,
        :donor_id,
        :campaign_id,
        :church_id,
        :guest_email,
        :guest_name,
        :type,
        :interval,
        :paid_at,
        :raw,
        :inserted_at
      ]

      upsert? true
      upsert_identity :unique_reference
    end

    update :set_status do
      accept [:status, :paid_at, :raw, :amount]
    end
  end

  attributes do
    attribute :reference, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :amount, :integer, public?: true
    attribute :currency, :string, default: "NGN", public?: true
    attribute :status, :string, allow_nil?: false, default: "pending", public?: true
    attribute :donor_id, :uuid, public?: true
    attribute :campaign_id, :uuid, public?: true
    attribute :church_id, :uuid, public?: true
    attribute :guest_email, :string, public?: true
    attribute :guest_name, :string, public?: true
    attribute :type, :string, default: "one_time", public?: true
    attribute :interval, :string, public?: true
    attribute :paid_at, :utc_datetime, public?: true
    attribute :raw, :map, public?: true
    attribute :inserted_at, :utc_datetime, public?: true
  end

  identities do
    identity :unique_reference, [:reference]
  end

  def handle(%DonationInitiatedV1{} = e, _meta) do
    with :ok <-
           upsert(%{
             reference: e.reference,
             amount: e.amount,
             currency: e.currency,
             status: "pending",
             donor_id: parse_uuid(e.donor_id),
             campaign_id: parse_uuid(e.campaign_id),
             church_id: parse_uuid(e.church_id),
             guest_email: e.guest_email,
             guest_name: e.guest_name,
             type: e.type,
             interval: e.interval,
             inserted_at: parse_dt(e.initiated_at)
           }),
         :ok <- ensure_donation_intent(e) do
      :ok
    end
  end

  def handle(%DonationConfirmedV1{} = e, _meta) do
    case Ash.get(__MODULE__, e.reference, authorize?: false) do
      {:ok, %{status: "successful"}} ->
        :ok

      {:ok, _record} ->
        confirm_donation(e)

      {:error, _} ->
        confirm_donation(e)
    end
  end

  def handle(%DonationFailedV1{} = e, _meta) do
    upsert(%{
      reference: e.reference,
      status: "failed",
      paid_at: parse_dt(e.failed_at),
      raw: %{reason: e.reason}
    })
  end

  def handle(_event, _meta), do: :ok

  defp confirm_donation(e) do
    with {:ok, intent} <- get_intent(e.reference),
         :ok <-
           upsert(%{
             reference: e.reference,
             amount: e.amount,
             status: "successful",
             paid_at: parse_dt(e.paid_at),
             raw: e.raw
           }),
         {:ok, _intent} <- mark_intent_success(intent),
         donor <- maybe_get_donor(intent),
         :ok <- maybe_ensure_customer(donor, e.customer_code),
         {:ok, donation} <- create_donation(intent, e.amount),
         {:ok, _txn} <- create_transaction(donation, intent, e.amount, e.channel),
         :ok <- maybe_create_subscription(intent, donor, e),
         :ok <- broadcast_success(intent, donation) do
      :ok
    else
      {:error, :already_processed} ->
        upsert(%{
          reference: e.reference,
          status: "successful",
          paid_at: parse_dt(e.paid_at),
          raw: e.raw
        })

      {:error, :intent_missing} ->
        Logger.warning("DonationIntent missing for confirm #{e.reference}")

        upsert(%{
          reference: e.reference,
          amount: e.amount,
          status: "successful",
          paid_at: parse_dt(e.paid_at),
          raw: e.raw
        })

      {:error, error} ->
        Logger.error("ConfirmDonation projection failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp ensure_donation_intent(e) do
    case DonationIntent
         |> Ash.Query.filter(reference == ^e.reference)
         |> Ash.read_one(authorize?: false) do
      {:ok, %DonationIntent{}} ->
        :ok

      {:ok, nil} ->
        attrs = %{
          amount: e.amount,
          currency: e.currency,
          status: :pending,
          reference: e.reference,
          campaign_id: parse_uuid(e.campaign_id),
          church_id: parse_uuid(e.church_id),
          donor_id: parse_uuid(e.donor_id),
          guest_email: e.guest_email,
          guest_name: e.guest_name,
          type: donation_type(e.type),
          interval: interval_atom(e.interval)
        }

        case DonationIntent
             |> Ash.Changeset.for_create(:create, attrs)
             |> Ash.create(authorize?: false) do
          {:ok, _} -> :ok
          {:error, err} -> {:error, err}
        end

      {:error, err} ->
        {:error, err}
    end
  end

  defp donation_type("recurring"), do: :recurring
  defp donation_type(_), do: :one_time

  defp get_intent(reference) do
    case DonationIntent
         |> Ash.Query.filter(reference == ^reference)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :intent_missing}
      {:ok, intent} -> {:ok, intent}
      {:error, err} -> {:error, err}
    end
  end

  defp mark_intent_success(intent) do
    intent
    |> Ash.Changeset.for_update(:mark_successful, %{})
    |> Ash.update(context: %{system: true}, authorize?: false)
  end

  defp maybe_get_donor(%DonationIntent{donor_id: nil}), do: nil

  defp maybe_get_donor(%DonationIntent{donor_id: donor_id}) do
    case Accounts.get_donor_by_id(donor_id) do
      {:ok, donor} -> donor
      _ -> nil
    end
  end

  defp maybe_ensure_customer(nil, _), do: :ok
  defp maybe_ensure_customer(_donor, nil), do: :ok

  defp maybe_ensure_customer(donor, customer_code) do
    if is_nil(donor.paystack_customer_id) do
      donor
      |> Ash.Changeset.for_update(:update, %{paystack_customer_id: customer_code})
      |> Ash.update(authorize?: false)
    end

    :ok
  end

  defp create_donation(intent, amount) do
    case Giving.Donation
         |> Ash.Query.filter(reference == ^intent.reference)
         |> Ash.read_one(authorize?: false) do
      {:ok, %Giving.Donation{} = donation} ->
        {:ok, donation}

      {:ok, nil} ->
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
        |> Ash.create(context: %{system: true}, authorize?: false)

      {:error, err} ->
        {:error, err}
    end
  end

  defp create_transaction(donation, intent, amount, channel) do
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
    )
  end

  defp maybe_create_subscription(_intent, nil, _e), do: :ok

  defp maybe_create_subscription(intent, donor, e) do
    if intent.type != :recurring do
      :ok
    else
      interval = intent.interval || :monthly

      with {:ok, plan_code} <- Plans.get_or_create(interval, intent.amount),
           {:ok, %{"data" => sub_data}} <-
             Client.create_subscription(%{
               customer_code: e.customer_code,
               plan_code: plan_code,
               authorization: e.authorization_code
             }),
           {:ok, next_charge_at, _} <- DateTime.from_iso8601(sub_data["next_payment_date"]),
           {:ok, _sub} <-
             Billing.create_subscription(%{
               donor_id: donor.id,
               campaign_id: intent.campaign_id,
               church_id: intent.church_id,
               amount: e.amount,
               interval: interval,
               status: :active,
               subscription_code: sub_data["subscription_code"],
               email_token: sub_data["email_token"],
               next_charge_at: next_charge_at
             }) do
        :ok
      else
        error ->
          Logger.error("Subscription create after confirm failed: #{inspect(error)}")
          :ok
      end
    end
  end

  defp broadcast_success(%DonationIntent{donor_id: nil}, _donation), do: :ok

  defp broadcast_success(intent, donation) do
    Phoenix.PubSub.broadcast(
      CheerfulDonor.PubSub,
      "donor:#{intent.donor_id}",
      {:donation_confirmed, donation.id}
    )

    :ok
  end

  defp upsert(attrs) do
    __MODULE__
    |> Ash.Changeset.for_create(:upsert, attrs)
    |> Ash.create!(authorize?: false)

    :ok
  end

  defp parse_uuid(nil), do: nil
  defp parse_uuid(id) when is_binary(id), do: id

  defp parse_dt(nil), do: nil

  defp parse_dt(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp interval_atom(nil), do: nil

  defp interval_atom(interval) when is_binary(interval) do
    String.to_existing_atom(interval)
  rescue
    ArgumentError -> nil
  end
end
