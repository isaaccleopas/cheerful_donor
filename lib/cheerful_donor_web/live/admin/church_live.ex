defmodule CheerfulDonorWeb.Admin.ChurchLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Accounts

  @impl true
  def mount(_params, _session, socket) do
    authorize_admin!(socket)

    {:ok,
     assign(socket,
       form: %{},
       loading: false
     )}
  end

  @impl true
  def handle_event("save", %{"church" => params}, socket) do
    user = socket.assigns.current_user

    params =
      params
      |> Map.put("user_id", user.id)

    case CheerfulDonor.Accounts.Church
        |> Ash.Changeset.for_create(:create, params, actor: user)
        |> Ash.create() do
      {:ok, church} ->
        {:noreply,
        socket
        |> put_flash(:info, "Church created successfully")
        |> push_navigate(to: ~p"/admin/dashboard")}

      {:error, error} ->
        IO.inspect(error, label: "Church create error")
        {:noreply, socket}
    end
  end

  defp authorize_admin!(socket) do
    if socket.assigns.current_user.role != :admin do
      raise Phoenix.Router.NoRouteError
    end
  end
end
