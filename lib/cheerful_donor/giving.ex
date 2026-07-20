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
