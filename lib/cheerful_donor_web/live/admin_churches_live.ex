defmodule CheerfulDonorWeb.AdminChurchesLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Accounts.Church

  @impl true
  def mount(_params, _session, socket) do
    authorize_admin!(socket)

    churches =
      Church
      |> Ash.read!()

    {:ok,
     socket
     |> assign(:churches, churches)
     |> assign(:form, AshPhoenix.Form.for_create(Church, :create))}
  end

  defp authorize_admin!(socket) do
    if socket.assigns.current_user.role != :admin do
      raise Phoenix.Router.NoRouteError, message: "Not authorized"
    end
  end

  @impl true
  def handle_event("save", %{"church" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    case Ash.create(Church, params) do
      {:ok, church} ->
        {:noreply,
         socket
         |> update(:churches, &[church | &1])
         |> put_flash(:info, "Church created successfully")}

      {:error, error} ->
        {:noreply,
         assign(socket, :form,
           AshPhoenix.Form.for_create(Church, :create, errors: error)
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">Churches</h1>

      <div class="grid md:grid-cols-2 gap-8">
        <!-- Create Church -->
        <div class="bg-white p-6 rounded-xl shadow">
          <h2 class="font-semibold mb-4">Create Church</h2>

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
          <h2 class="font-semibold mb-4">Existing Churches</h2>

          <ul class="space-y-3">
            <%= for church <- @churches do %>
              <li class="border p-3 rounded">
                <p class="font-semibold"><%= church.name %></p>
                <p class="text-sm text-gray-500"><%= church.email %></p>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
