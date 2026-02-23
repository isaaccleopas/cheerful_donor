defmodule CheerfulDonorWeb.Donor.DonateLive.Show do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving.Campaign

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    campaign =
      Campaign
      |> Ash.Query.for_read(:by_slug, %{slug: slug})
      |> Ash.Query.load(:church)
      |> Ash.read_one!()

    IO.inspect(campaign, label: "Loaded Campaign")
    {:ok, assign(socket, :campaign, campaign)}
  end
end
