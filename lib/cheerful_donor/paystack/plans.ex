defmodule CheerfulDonor.Paystack.Plans do
  @moduledoc """
  Handles mapping subscription intervals to Paystack plans,
  creating them dynamically if needed.
  """

  alias CheerfulDonor.Paystack.Client

  @intervals [:daily, :weekly, :monthly, :quarterly, :annually]

  @doc """
  Get or create a Paystack plan for the given interval and amount.
  Returns {:ok, plan_code} or {:error, reason}.
  """
  def get_or_create(interval, amount) when interval in @intervals do
    # Generate a unique plan name (optional: include amount)
    name = "Donation #{interval} ₦#{amount}"
    plan_key = "#{interval}-#{amount}"

    # Here you could cache plan_codes in ETS or DB if needed
    case Client.create_plan(name, amount, interval) do
      {:ok, %{"data" => %{"plan_code" => plan_code}}} ->
        {:ok, plan_code}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_or_create(_, _) do
    {:error, :invalid_interval}
  end
end
