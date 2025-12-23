defmodule CheerfulDonorWeb.AdminCampaignLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Accounts

  @impl true
  def mount(_params, _session, socket) do
    authorize_admin!(socket)

    churches = Accounts.list_churches!()

    {:ok,
     assign(socket,
       churches: churches,
       loading: false
     )}
  end

  @impl true
  def handle_event("save", %{"campaign" => params}, socket) do
    case Giving.create_campaign(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Campaign created")
         |> push_navigate(to: "/admin")}

      {:error, err} ->
        {:noreply, put_flash(socket, :error, inspect(err))}
    end
  end

  defp authorize_admin!(socket) do
    if socket.assigns.current_user.role != :admin do
      raise Phoenix.Router.NoRouteError
    end
  end
end
