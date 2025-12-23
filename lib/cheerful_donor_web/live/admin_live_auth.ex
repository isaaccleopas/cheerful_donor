defmodule CheerfulDonorWeb.AdminLiveAuth do
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    case socket.assigns.current_user do
      %{role: :admin} ->
        {:cont, socket}

      _ ->
        {:halt, redirect(socket, to: "/")}
    end
  end
end
