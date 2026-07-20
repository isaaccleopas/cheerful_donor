defmodule CheerfulDonorWeb.AdminLiveAuth do
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %{role: :admin} ->
        {:cont, socket}

      %{role: _other} ->
        {:halt, redirect(socket, to: "/donor/dashboard")}

      nil ->
        {:halt, redirect(socket, to: "/sign-in")}
    end
  end
end
