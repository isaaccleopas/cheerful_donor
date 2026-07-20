defmodule CheerfulDonor.Changes.DispatchCommand do
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, Keyword.put_new(opts, :consistency, :eventual)}

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, command ->
      with :ok <- CheerfulDonor.CommandedApp.dispatch(command, consistency: opts[:consistency]) do
        {:ok, command}
      end
    end)
  end
end
