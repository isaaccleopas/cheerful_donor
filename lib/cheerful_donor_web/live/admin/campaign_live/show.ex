defmodule CheerfulDonorWeb.Admin.CampaignLive.Show do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving

  on_mount {CheerfulDonorWeb.LiveUserAuth, :current_user}
  on_mount CheerfulDonorWeb.AdminLiveAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    campaign =
      Giving.get_campaign!(id, socket.assigns.current_user)

    {:noreply,
    assign(socket,
      campaign: campaign,
      share_url: url(~p"/donate/#{campaign.slug}")
    )}
  end
end
