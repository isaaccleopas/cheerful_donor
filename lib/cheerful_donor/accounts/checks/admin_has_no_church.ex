defmodule CheerfulDonor.Accounts.Checks.AdminHasNoChurch do
  use Ash.Policy.SimpleCheck

  alias CheerfulDonor.Accounts.Church

  @impl true
  def describe(_opts), do: "admin does not already have a church"

  @impl true
  def match?(_actor, _record, %{actor: actor}) do
    case Church.by_user_id(actor.id) do
      {:ok, []} -> true
      _ -> false
    end
  end
end
