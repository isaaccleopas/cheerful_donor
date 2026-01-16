defmodule CheerfulDonorWeb.Public.AuthLive.AuthForm do
  use CheerfulDonorWeb, :live_component
  import CheerfulDonorWeb.CoreComponents
  alias AshPhoenix.Form

  @impl true
  def update(assigns, socket) do
    {:ok,
    socket
    |> assign(assigns)
    |> assign_new(:trigger_action, fn -> false end)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form = socket.assigns.form |> Form.validate(params, errors: false)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    form = socket.assigns.form |> Form.validate(params)
    {:noreply, assign(socket, form: form, trigger_action: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        as="user"
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={@action}
        method="POST"
      >
        <.input field={@form[:email]} type="email" label="Email" />
        <.input
          field={@form[:password]}
          type="password"
          label="Password"
          value={Phoenix.HTML.Form.input_value(@form, :password)}
        />
        <%= if @is_register? do %>
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm Password"
            value={Phoenix.HTML.Form.input_value(@form, :password_confirmation)}
          />
          <fieldset class="mb-4">
            <legend class="text-sm font-semibold text-zinc-800">Register as</legend>
            <div class="flex gap-4 mt-2">
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  name={@form[:role].name}
                  value="donor"
                  checked={Phoenix.HTML.Form.input_value(@form, :role) == :donor}
                /> Donor
              </label>
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  name={@form[:role].name}
                  value="admin"
                  checked={Phoenix.HTML.Form.input_value(@form, :role) == :admin}
                /> Admin
              </label>
            </div>
          </fieldset>

        <% end %>

        <.button class="mt-4 w-full" phx-disable-with="Signing in..."><%= @cta %></.button>
      </.form>
    </div>
    """
  end
end
