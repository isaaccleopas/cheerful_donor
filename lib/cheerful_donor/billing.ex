defmodule CheerfulDonor.Billing do
  use Ash.Domain, otp_app: :cheerful_donor

  require Ash.Query
  alias CheerfulDonor.Billing.Subscription
  alias CheerfulDonor.Accounts.Donor

  resources do
    resource Subscription
    resource CheerfulDonor.Billing.PaymentMethod
  end

  @doc """
  Lookup a subscription by its Paystack subscription_code.
  """
  def get_subscription_by_code(code) do
    Subscription
    |> Ash.Query.filter(subscription_code: code)
    |> Ash.read_one()
  end

  @doc """
  Lookup a donor by their subscription code.
  """
  def get_donor_by_subscription(subscription_code) do
    with {:ok, %Subscription{} = sub} <- get_subscription_by_code(subscription_code),
         {:ok, %Donor{} = donor} <- get_donor_by_id(sub.donor_id) do
      {:ok, donor}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Update a subscription record.
  """
  def update_subscription(%Subscription{} = sub, attrs) do
    Ash.update(sub, attrs)
  end

  @doc """
  Create a subscription record.
  """
  def create_subscription(attrs) do
    Ash.create(Subscription, attrs)
  end

  def get_donor_by_id(id) do
    Donor
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one()
  end

  def get_subscriptions_for_donor(donor_id) do
    Subscription
    |> Ash.Query.for_read(:for_donor, %{donor_id: donor_id})
    |> Ash.read!()
  end
end
