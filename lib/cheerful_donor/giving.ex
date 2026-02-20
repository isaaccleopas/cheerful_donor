defmodule CheerfulDonor.Giving do
  use Ash.Domain, otp_app: :cheerful_donor

  require Ash.Query
  alias CheerfulDonor.Giving.{Campaign, DonationIntent, Donation}
  alias CheerfulDonor.Accounts.Donor

  resources do
    resource Campaign
    resource DonationIntent
    resource Donation
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
end
