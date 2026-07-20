defmodule CheerfulDonorWeb.Public.CampaignLive.Index do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving.Campaign

  @impl true
  def mount(_params, _session, socket) do
    campaigns =
      Campaign
      |> Ash.Query.for_read(:list_active)
      |> Ash.Query.load(:church)
      |> Ash.read!()

    {:ok,
     socket
     |> assign(:page_title, "Campaigns")
     |> assign(:campaigns, campaigns)}
  end
end
