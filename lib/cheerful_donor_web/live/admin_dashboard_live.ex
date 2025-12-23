defmodule CheerfulDonorWeb.AdminDashboardLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Giving
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Payments

  @impl true
  def mount(_params, _session, socket) do
    authorize_admin!(socket)
    {:ok, socket}
  end

  defp authorize_admin!(socket) do
    case socket.assigns.current_user do
      %{role: :admin} -> :ok
      _ -> raise Phoenix.Router.NoRouteError, message: "Not authorized"
    end
  end
  
  @impl true
  def mount(_params, _session, socket) do
    # Assumes LiveUserAuth assigns :current_user
    current_user = socket.assigns.current_user

    if current_user.role != :admin do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      stats = %{
        donors: Accounts.count_donors!(),
        donations: Giving.count_donations!(),
        total_donated: Giving.total_donated_amount!(),
        active_subscriptions: Billing.count_active_subscriptions!(),
        transactions: Payments.count_transactions!()
      }

      {:ok,
       socket
       |> assign(:page_title, "Admin Dashboard")
       |> assign(:stats, stats)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 p-6">
      <div class="max-w-7xl mx-auto">
        <h1 class="text-3xl font-bold mb-6">Admin Dashboard</h1>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <.stat_card title="Total Donors" value={@stats.donors} />
          <.stat_card title="Total Donations" value={@stats.donations} />
          <.stat_card title="Total Donated" value={@stats.total_donated} />
          <.stat_card title="Active Subscriptions" value={@stats.active_subscriptions} />
          <.stat_card title="Transactions" value={@stats.transactions} />
        </div>

        <div class="mt-10 grid grid-cols-1 md:grid-cols-2 gap-6">
          <.link navigate={~p"/admin/donors"} class="admin-link">Manage Donors</.link>
          <.link navigate={~p"/admin/donations"} class="admin-link">View Donations</.link>
          <.link navigate={~p"/admin/subscriptions"} class="admin-link">Subscriptions</.link>
          <.link navigate={~p"/admin/transactions"} class="admin-link">Transactions</.link>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow p-6">
      <p class="text-gray-500 text-sm mb-1"><%= @title %></p>
      <p class="text-2xl font-bold text-indigo-600"><%= @value %></p>
    </div>
    """
  end
end
