defmodule CheerfulDonorWeb.Donor.CampaignLive.Index do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving

  @impl true
  def mount(_params, _session, socket) do
    campaigns = Giving.list_active_campaigns_with_stats()

    {:ok,
     socket
     |> assign(:page_title, "Campaigns")
     |> assign(:campaigns, campaigns)}
  end
end
