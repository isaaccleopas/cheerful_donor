defmodule CheerfulDonor.Giving do
  use Ash.Domain, otp_app: :cheerful_donor

  require Ash.Query
  alias CheerfulDonor.Accounts.Donor
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Giving.Donation

  resources do
    resource CheerfulDonor.Giving.Campaign
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
    |> Ash.Query.filter(reference: reference)
    |> Ash.read_one()
  end

  def get_donations_for_donor(donor_id) do
    Donation
    |> Ash.Query.filter(donor_id == ^donor_id)
    |> Ash.Query.load(:campaign)
    |> read!()
  end

  def update_donation(%Donation{} = donation, attrs) do
    Donation
    |> Ash.Changeset.for_update(:update, donation, attrs)
    |> Ash.update()
  end

  @doc """
  Update a donation intent
  """
  def update_donation_intent(intent, attrs),
    do: Ash.update(intent, attrs)

  @doc """
  Create a donation record
  """
  def create_donation(attrs),
    do: Ash.create(Donation, attrs)
end

# defmodule CheerfulDonor.Giving do
#   use Ash.Domain,
#     otp_app: :cheerful_donor

#   resources do
#     resource CheerfulDonor.Giving.Campaign
#     resource CheerfulDonor.Giving.Donation
#     resource CheerfulDonor.Giving.DonationIntent
#   end

#     # Lookup DonationIntent by reference
#   def get_donation_intent(reference) do
#     DonationIntent
#     |> Ash.Query.filter(reference: reference)
#     |> Ash.read_one()
#   end

#   def update_donation_intent(intent, attrs),
#     do: Ash.update(intent, attrs)

#   def create_donation(attrs),
#     do: Ash.create(Donation, attrs)

#   def get_donor_by_subscription(subscription_code) do
#     Donor
#     |> Ash.Query.filter(subscription_code: subscription_code)
#     |> Ash.read_one()
#   end
# end
