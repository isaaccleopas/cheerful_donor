defmodule CheerfulDonorWeb.Admin.CampaignLive.Index do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Accounts

  on_mount {CheerfulDonorWeb.LiveUserAuth, :current_user}
  on_mount CheerfulDonorWeb.AdminLiveAuth

  @impl true
  def mount(_params, _session, socket) do
    user = Accounts.get_user_with_church!(socket.assigns.current_user.id, socket.assigns.current_user)

    campaigns =
      Giving.list_campaigns_for_church(
        user.church.id,
        user
      )

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:campaigns, campaigns)}
  end
end
