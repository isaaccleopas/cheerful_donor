defmodule CheerfulDonor.Accounts do
  use Ash.Domain, otp_app: :cheerful_donor, extensions: [AshAdmin.Domain]

  require Ash.Query
  admin do
    show? true
  end

  resources do
    resource CheerfulDonor.Accounts.Token
    resource CheerfulDonor.Accounts.User
    resource CheerfulDonor.Accounts.Church
    resource CheerfulDonor.Accounts.Donor
  end

  alias CheerfulDonor.Accounts.Donor

  def get_donor_by_email(email) do
    Donor
    |> Ash.Query.for_read(:read, load: [:user])
    |> Ash.Query.filter(Ash.Query.ref(:user, :email) == ^email)
    |> Ash.read_one()
  end

  def get_donor_by_id!(id, opts \\ []) do
    Donor
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(:user)
    |> Ash.read_one!(opts)
  end

  def get_donor_by_user_id(user_id, opts \\ []) do
    Donor
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.load(:user)
    |> Ash.read_one!(opts)
  end

  def create_donor_for_user!(user_id, opts \\ []) do
    changeset =
      Donor
      |> Ash.Changeset.for_create(:create, %{user_id: user_id})

    {:ok, donor} = Ash.create(changeset)

    # Reload with user preloaded and actor passed
    Donor
    |> Ash.Query.filter(id == ^donor.id)
    |> Ash.Query.load(:user)
    |> Ash.read_one!(opts)
  end

  def get_church_by_user_id(user_id) do
    CheerfulDonor.Accounts.Church
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read_one()
  end

end
