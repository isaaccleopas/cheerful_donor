defmodule CheerfulDonor.Accounts.Checks.AdminHasNoChurch do
  use Ash.Policy.SimpleCheck

  require Ash.Query
  alias CheerfulDonor.Accounts.Church

  @impl true
  def describe(_opts), do: "admin does not already have a church"

  @impl true
  def match?(_actor, _record, %{actor: actor}) do
    case Church
         |> Ash.Query.filter(user_id == ^actor.id)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> true
      {:ok, _} -> false
      _ -> false
    end
  end
end
