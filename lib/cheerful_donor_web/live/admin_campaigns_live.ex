defmodule CheerfulDonorWeb.AdminCampaignsLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving.Campaign
  alias CheerfulDonor.Accounts.Church

  @impl true
  def mount(_params, _session, socket) do
    authorize_admin!(socket)

    {:ok,
     socket
     |> assign(:campaigns, Ash.read!(Campaign))
     |> assign(:churches, Ash.read!(Church))
     |> assign(:form, AshPhoenix.Form.for_create(Campaign, :create))}
  end

  defp authorize_admin!(socket) do
    if socket.assigns.current_user.role != :admin do
      raise Phoenix.Router.NoRouteError
    end
  end

  @impl true
  def handle_event("save", %{"campaign" => params}, socket) do
    case Ash.create(Campaign, params) do
      {:ok, campaign} ->
        {:noreply,
         socket
         |> update(:campaigns, &[campaign | &1])
         |> put_flash(:info, "Campaign created")}

      {:error, error} ->
        {:noreply,
         assign(socket, :form,
           AshPhoenix.Form.for_create(Campaign, :create, errors: error)
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">Campaigns / Offerings / Tithes</h1>

      <div class="grid md:grid-cols-2 gap-8">
        <!-- Create -->
        <div class="bg-white p-6 rounded-xl shadow">
          <h2 class="font-semibold mb-4">Create</h2>

          <.form for={@form} phx-submit="save">
            <.input field={@form[:title]} label="Title" />
            <.input field={@form[:description]} label="Description" />
            <.input field={@form[:goal_amount]} label="Goal Amount" />

            <.input
              field={@form[:type]}
              type="select"
              label="Type"
              options={[
                {"Campaign", :campaign},
                {"Offering", :offering},
                {"Tithe", :tithe}
              ]}
            />

            <.input
              field={@form[:church_id]}
              type="select"
              label="Church"
              options={@church_options}
            />

            <.button class="mt-4">Create</.button>
          </.form>
        </div>

        <!-- List -->
        <div class="bg-white p-6 rounded-xl shadow">
          <h2 class="font-semibold mb-4">Existing</h2>

          <ul class="space-y-3">
            <%= for c <- @campaigns do %>
              <li class="border p-3 rounded">
                <p class="font-semibold"><%= c.title %></p>
                <p class="text-sm text-gray-500 capitalize">
                  <%= c.type %>
                </p>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
