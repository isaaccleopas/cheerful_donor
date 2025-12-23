defmodule CheerfulDonorWeb.AuthLive.AuthForm do
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
  def handle_event("validate", %{"form" => params}, socket) do
    IO.inspect(params, label: "Validating params")
    form = socket.assigns.form |> Form.validate(params, errors: false)
    IO.inspect(form, label: "Validating form")

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        IO.inspect(user, label: "Submitted user")
        {:noreply, assign(socket, trigger_action: true)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if match?(%Phoenix.HTML.Form{}, @form) and @form.errors != [] do %>
        <ul class="error-messages">
          <%= for {field, {msg, _}} <- @form.errors do %>
            <li>
              <%= Phoenix.Naming.humanize(to_string(field)) %>: <%= msg %>
            </li>
          <% end %>
        </ul>
      <% end %>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={@action}
        method="POST"
      >
        <%= if @is_register? do %>
          <fieldset class="mb-4">
            <legend>Register as</legend>

            <label>
              <input type="radio" name={@form[:role].name} value="donor" />
              Donor
            </label>

            <label>
              <input type="radio" name={@form[:role].name} value="admin" />
              Admin
            </label>
          </fieldset>

          <.input field={@form[:password_confirmation]} type="password" label="Confirm Password" />
        <% end %>

        <.input field={@form[:email]} type="email" label="Email" name="form[email]" />
        <.input field={@form[:password]} type="password" label="Password" name="form[password]" />

        <.button class="mt-4 w-full"><%= @cta %></.button>
      </.form>
    </div>
    """
  end
end
