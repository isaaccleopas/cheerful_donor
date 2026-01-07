defmodule CheerfulDonorWeb.AdminChurchesLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Accounts.Church

  @impl true
  def mount(_params, _session, socket) do
    authorize_admin!(socket)

    churches =
      Church
      |> Ash.read!(actor: socket.assigns.current_user)

    form =
      Church
      |> AshPhoenix.Form.for_create(:create,
          actor: socket.assigns.current_user
        )
      |> to_form()

    {:ok,
    socket
    |> assign(:churches, churches)
    |> assign(:form, form)}
  end

  defp authorize_admin!(socket) do
    if socket.assigns.current_user.role != :admin do
      raise Phoenix.Router.NoRouteError, message: "Not authorized"
    end
  end

  @impl true
  def handle_event("save", %{"church" => params}, socket) do
    user = socket.assigns.current_user
    params = Map.put(params, "user_id", user.id)

    case Church
        |> AshPhoenix.Form.for_create(:create,
              params: params,
              actor: user
            )
        |> AshPhoenix.Form.submit() do
      {:ok, church} ->
        {:noreply,
        socket
        |> update(:churches, &[church | &1])
        |> put_flash(:info, "Church created successfully")
        |> assign(:form,
          Church
          |> AshPhoenix.Form.for_create(:create, actor: user)
          |> to_form()
        )}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">Churches</h1>

      <div class="grid md:grid-cols-2 gap-8">
        <!-- Create Church -->
        <div class="bg-white p-6 rounded-xl shadow text-gray-800">
          <h2 class="font-semibold mb-4 text-gray-800">Create Church</h2>

          <.form for={@form} phx-submit="save">
            <.input field={@form[:name]} label="Name" />
            <.input field={@form[:email]} label="Email" />
            <.input field={@form[:phone]} label="Phone" />
            <.input field={@form[:address]} label="Address" />
            <.button class="mt-4">Save</.button>
          </.form>
        </div>

        <!-- List -->
        <div class="bg-white p-6 rounded-xl shadow">
          <h2 class="font-semibold mb-4 text-gray-800">Existing Churches</h2>

          <ul class="space-y-3">
            <%= for church <- @churches do %>
              <li class="border p-3 rounded">
                <p class="font-semibold text-gray-800"><%= church.name %></p>
                <p class="text-sm text-gray-800"><%= church.email %></p>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
