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
    <div class="cd-form-panel">
      <.form
        for={@form}
        as={:user}
        id={@id}
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={@action}
        method="POST"
        class="cd-form"
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
            label="Confirm password"
            value={Phoenix.HTML.Form.input_value(@form, :password_confirmation)}
          />
          <fieldset class="space-y-3 rounded-xl border-2 border-base-300 p-4">
            <legend class="cd-field-label px-1">Register as</legend>
            <div class="flex flex-wrap gap-4">
              <label class="flex min-h-11 items-center gap-2 text-sm font-semibold">
                <input
                  type="radio"
                  name={@form[:role].name}
                  value="donor"
                  checked={Phoenix.HTML.Form.input_value(@form, :role) in [:donor, "donor", nil]}
                  class="radio radio-primary border-2"
                /> Donor
              </label>
              <label class="flex min-h-11 items-center gap-2 text-sm font-semibold">
                <input
                  type="radio"
                  name={@form[:role].name}
                  value="admin"
                  checked={Phoenix.HTML.Form.input_value(@form, :role) in [:admin, "admin"]}
                  class="radio radio-primary border-2"
                /> Church admin
              </label>
            </div>
          </fieldset>
        <% end %>

        <.button
          class="cd-cta mt-2 w-full min-h-12 rounded-lg bg-primary font-semibold text-primary-content hover:brightness-110"
          phx-disable-with="Please wait..."
        >
          {@cta}
        </.button>
      </.form>
    </div>
    """
  end
end
