defmodule CheerfulDonorWeb.DonorLiveAuth do
  import Phoenix.LiveView
  import Phoenix.LiveView.Helpers

  @behaviour Phoenix.LiveView.OnMount

  @impl true
  def on_mount(:default, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %{role: :donor} ->
        {:cont, socket}

      %{role: _other} ->
        {:halt, redirect(socket, to: "/admin/dashboard")}

      nil ->
        {:halt, redirect(socket, to: "/sign-in")}
    end
  end
end
