defmodule CheerfulDonor.Giving do
  use Ash.Domain, otp_app: :cheerful_donor
  use Supervisor

  require Ash.Query
  alias CheerfulDonor.Giving.{Campaign, DonationIntent, Donation}
  alias CheerfulDonor.Giving.Lookups
  alias CheerfulDonor.Accounts.Donor

  resources do
    resource Campaign
    resource DonationIntent
    resource Donation

    resource CheerfulDonor.Giving.InitiateDonation do
      define :initiate_donation_cmd, action: :create
    end

    resource CheerfulDonor.Giving.ConfirmDonation do
      define :confirm_donation_cmd, action: :create
    end

    resource CheerfulDonor.Giving.FailDonation do
      define :fail_donation_cmd, action: :create
    end

    resource Lookups.Donation
  end

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl Supervisor
  def init(_arg) do
    children =
      if Application.get_env(:cheerful_donor, :start_projections, true) do
        [Lookups.Donation]
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Dispatch InitiateDonation and return the donation lookup projection.
  """
  def initiate_donation(attrs) when is_map(attrs) do
    reference = attrs[:reference] || attrs["reference"] || Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    cmd_attrs = %{
      reference: reference,
      amount: attrs[:amount] || attrs["amount"],
      currency: attrs[:currency] || attrs["currency"] || "NGN",
      donor_id: uuid_string(attrs[:donor_id] || attrs["donor_id"]),
      campaign_id: uuid_string(attrs[:campaign_id] || attrs["campaign_id"]),
      church_id: uuid_string(attrs[:church_id] || attrs["church_id"]),
      guest_email: attrs[:guest_email] || attrs["guest_email"],
      guest_name: attrs[:guest_name] || attrs["guest_name"],
      type: to_string(attrs[:type] || attrs["type"] || :one_time),
      interval: interval_string(attrs[:interval] || attrs["interval"]),
      initiated_at: now
    }

    case initiate_donation_cmd(cmd_attrs) do
      {:ok, _} ->
        Ash.get(Lookups.Donation, reference, authorize?: false)

      error ->
        error
    end
  end

  def confirm_donation(attrs) when is_map(attrs) do
    cmd_attrs = %{
      reference: attrs[:reference] || attrs["reference"],
      amount: attrs[:amount] || attrs["amount"],
      paid_at: attrs[:paid_at] || attrs["paid_at"] || DateTime.utc_now() |> DateTime.to_iso8601(),
      channel: attrs[:channel] || attrs["channel"],
      customer_code: attrs[:customer_code] || attrs["customer_code"],
      authorization_code: attrs[:authorization_code] || attrs["authorization_code"],
      raw: attrs[:raw] || attrs["raw"] || %{}
    }

    case confirm_donation_cmd(cmd_attrs) do
      {:ok, _} -> Ash.get(Lookups.Donation, cmd_attrs.reference, authorize?: false)
      error -> error
    end
  end

  @doc """
  Confirm a donation from Paystack verify/webhook payload data.
  """
  def confirm_donation_from_paystack(reference, %{"amount" => amount_kobo} = data) do
    amount = div(amount_kobo, 100)
    auth = data["authorization"] || %{}
    customer = data["customer"] || %{}

    confirm_donation(%{
      reference: reference,
      amount: amount,
      channel: Map.get(auth, "channel"),
      customer_code: Map.get(customer, "customer_code"),
      authorization_code: Map.get(auth, "authorization_code"),
      raw: data
    })
  end

  @doc """
  Returns true when a donation reference is already confirmed locally.
  """
  def donation_confirmed?(reference) do
    lookup_confirmed?(reference) or legacy_donation_confirmed?(reference)
  end

  @doc """
  Pending donation lookups eligible for Paystack verify retry.

  Options:
    * `:grace_minutes` - skip very recent rows (default 2)
    * `:limit` - max rows per run (default 50)
  """
  def list_pending_donations_for_verification(opts \\ []) do
    grace_minutes = Keyword.get(opts, :grace_minutes, 2)
    limit = Keyword.get(opts, :limit, 50)

    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-grace_minutes * 60, :second)
      |> DateTime.truncate(:second)

    Lookups.Donation
    |> Ash.Query.filter(status == "pending" and inserted_at < ^cutoff)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.limit(limit)
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Verify a single pending donation with Paystack and confirm if paid.

  Returns `:confirmed`, `:already_confirmed`, `:still_pending`, `:failed`,
  `:verification_failed`, or `{:error, reason}`.
  """
  def verify_pending_donation(reference) do
    if donation_confirmed?(reference) do
      :already_confirmed
    else
      case CheerfulDonor.Paystack.Client.verify_transaction(reference) do
        {:ok, %{"status" => true, "data" => %{"status" => "success"} = data}} ->
          case confirm_donation_from_paystack(reference, data) do
            {:ok, _} -> :confirmed
            {:error, _} = error -> error
          end

        {:ok, %{"data" => %{"status" => status}}}
        when status in ["pending", "processing", "ongoing"] ->
          :still_pending

        {:ok, %{"data" => %{"status" => "failed"}}} ->
          fail_donation(%{
            reference: reference,
            reason: "paystack_verify_failed"
          })

          :failed

        {:error, _} ->
          :verification_failed

        _ ->
          :verification_failed
      end
    end
  end

  defp lookup_confirmed?(reference) do
    case Ash.get(Lookups.Donation, reference, authorize?: false) do
      {:ok, %{status: "successful"}} -> true
      _ -> false
    end
  end

  defp legacy_donation_confirmed?(reference) do
    case Donation
         |> Ash.Query.for_read(:get_by_reference, %{reference: reference})
         |> Ash.read_one(authorize?: false) do
      {:ok, %Donation{status: :successful}} -> true
      _ -> false
    end
  end

  def fail_donation(attrs) when is_map(attrs) do
    cmd_attrs = %{
      reference: attrs[:reference] || attrs["reference"],
      reason: attrs[:reason] || attrs["reason"],
      failed_at:
        attrs[:failed_at] || attrs["failed_at"] || DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case fail_donation_cmd(cmd_attrs) do
      {:ok, _} -> Ash.get(Lookups.Donation, cmd_attrs.reference, authorize?: false)
      error -> error
    end
  end

  @doc """
  Stats for a single campaign: raised total and donor count.

  Merges legacy `donations` rows with event-sourced lookup projections,
  deduplicated by payment reference.
  """
  def campaign_stats(campaign_id) do
    successful_donation_entries(campaign_id)
    |> entries_to_stats()
  end

  @doc """
  Active campaigns enriched with raised totals for discovery UI.
  """
  def list_active_campaigns_with_stats(opts \\ []) do
    limit = Keyword.get(opts, :limit)

    campaigns =
      Campaign
      |> Ash.Query.for_read(:list_active)
      |> Ash.Query.load(:church)
      |> Ash.read!(authorize?: false)

    campaign_ids = Enum.map(campaigns, & &1.id)

    raised_by_campaign =
      if campaign_ids == [] do
        %{}
      else
        campaign_ids
        |> Enum.map(fn id -> {id, successful_donation_entries(id)} end)
        |> Map.new(fn {id, entries} -> {id, entries_to_stats(entries)} end)
      end

    campaigns
    |> Enum.map(fn campaign ->
      stats = Map.get(raised_by_campaign, campaign.id, %{raised: 0, donor_count: 0})

      %{
        campaign: campaign,
        raised: stats.raised,
        donor_count: stats.donor_count
      }
    end)
    |> then(fn list ->
      if limit, do: Enum.take(list, limit), else: list
    end)
  end

  defp successful_donation_entries(campaign_id) do
    donations =
      Donation
      |> Ash.Query.filter(campaign_id == ^campaign_id and status == :successful)
      |> Ash.read!(authorize?: false)

    lookups =
      Lookups.Donation
      |> Ash.Query.filter(campaign_id == ^campaign_id and status == "successful")
      |> Ash.read!(authorize?: false)

    (Enum.map(donations, &{&1.reference, &1.amount_paid || &1.amount || 0}) ++
       Enum.map(lookups, &{&1.reference, &1.amount || 0}))
    |> Enum.uniq_by(fn {reference, _} -> reference end)
  end

  defp entries_to_stats(entries) do
    %{
      raised: entries |> Enum.map(&elem(&1, 1)) |> Enum.sum(),
      donor_count: length(entries)
    }
  end

  @doc """
  Lookup donor by email.
  """
  def get_donor_by_email(email) do
    Donor
    |> Ash.Query.for_read(:read, load: [:user])
    |> Ash.Query.filter(Ash.Query.ref(:user, :email) == ^email)
    |> Ash.read_one()
  end

  def get_donor_by_id(id) do
    Donor
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one()
  end

  @doc """
  Lookup DonationIntent by reference
  """
  def get_donation_intent(reference) do
    DonationIntent
    |> Ash.Query.for_read(:read_by_reference, %{reference: reference})
    |> Ash.read_one()
  end

  def get_donations_for_donor(donor_id) do
    Donation
    |> Ash.Query.for_read(:for_donor, %{donor_id: donor_id})
    |> Ash.read!(actor: %{donor_id: donor_id})
  end

  def update_donation(%Donation{} = donation, attrs) do
    Donation
    |> Ash.Changeset.for_update(:update, donation, attrs)
    |> Ash.update()
  end

  @doc """
  Update a donation intent
  """
  def update_donation_intent(%DonationIntent{} = intent, attrs, opts \\ []) do
    action = Keyword.get(opts, :action, :update)
    context = Keyword.get(opts, :context, %{})

    intent
    |> Ash.Changeset.for_update(action, attrs, context: context)
    |> Ash.update()
  end

  @doc """
  List campaigns for a specific church.
  """
  def list_campaigns_for_church(church_id, actor \\ nil) do
    Campaign
    |> Ash.Query.for_read(:list_for_church, %{church_id: church_id})
    |> Ash.read!(actor: actor)
  end

  @doc """
  Fetch a single campaign by id, ensuring the current user has access.
  Raises if not found.
  """
  def get_campaign!(id, actor) do
    Campaign
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(actor: actor)
  end

  @doc """
  Fetch a single campaign by id, returns {:ok, campaign} or {:error, reason}.
  """
  def get_campaign(id, actor) do
    Campaign
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(actor: actor)
  end

  @doc """
  Create a donation record
  """
  def create_donation(attrs, opts \\ []) do
    context = Keyword.get(opts, :context, %{})

    Donation
    |> Ash.Changeset.for_create(:create, attrs, context: context)
    |> Ash.create()
  end

  defp uuid_string(nil), do: nil
  defp uuid_string(id) when is_binary(id), do: id

  defp interval_string(nil), do: nil
  defp interval_string(interval), do: to_string(interval)
end
