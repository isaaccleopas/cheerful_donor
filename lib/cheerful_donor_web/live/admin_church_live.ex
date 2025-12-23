defmodule CheerfulDonorWeb.AdminChurchLive do
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

    case Accounts.create_church(Map.put(params, "user_id", user.id)) do
      {:ok, _church} ->
        {:noreply,
         socket
         |> put_flash(:info, "Church created successfully")
         |> push_navigate(to: "/admin")}

      {:error, err} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(err)}")}
    end
  end

  defp authorize_admin!(socket) do
    if socket.assigns.current_user.role != :admin do
      raise Phoenix.Router.NoRouteError
    end
  end
end
