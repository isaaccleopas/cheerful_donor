defmodule CheerfulDonorWeb.Admin.DashboardLive do
  use CheerfulDonorWeb, :live_view
  require Ash.Query

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Giving

  attr :label, :string, required: true
  attr :value, :string, required: true

  def stat(assigns) do
    ~H"""
    <div class="rounded-lg border p-4 bg-white shadow-sm">
      <div class="text-sm text-gray-500"><%= @label %></div>
      <div class="mt-1 text-2xl font-semibold text-gray-900">
        <%= @value %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:actor, actor)
     |> load_dashboard_data()}
  end

  # --------------------
  # Data Loading
  # --------------------

  defp load_dashboard_data(socket) do
    actor = socket.assigns.actor

    case get_church(actor) do
      {:ok, nil} ->
        socket
        |> assign(:church, nil)
        |> assign(:campaigns, [])
        |> assign(:stats, empty_stats())
        |> assign(:recent_donations, [])
        |> assign(:needs_onboarding, true)

      {:ok, church} ->
        socket
        |> assign(:church, church)
        |> assign(:campaigns, get_campaigns(church, actor))
        |> assign(:stats, get_stats(church, actor))
        |> assign(:recent_donations, get_recent_donations(church, actor))
        |> assign(:needs_onboarding, false)

      {:error, _} ->
        socket
        |> put_flash(:error, "Unable to load dashboard")
    end
  end

  defp empty_stats do
    %{
      total_amount: 0,
      donation_count: 0,
      active_campaigns: 0
    }
  end

  defp get_church(actor) do
    Accounts.Church
    |> Ash.Query.filter(user_id == ^actor.id)
    |> Ash.read_one(actor: actor)
  end

  defp get_campaigns(church, actor) do
    Giving.Campaign
    |> Ash.Query.filter(church_id == ^church.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: actor)
  end

  defp get_recent_donations(church, actor) do
    Giving.Donation
    |> Ash.Query.filter(church_id == ^church.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(10)
    |> Ash.read!(actor: actor)
  end

  defp get_stats(church, actor) do
    donations =
      Giving.Donation
      |> Ash.Query.filter(church_id == ^church.id and status == :successful)
      |> Ash.read!(actor: actor)

    %{
      total_amount: Enum.sum(Enum.map(donations, &(&1.amount_paid || 0))),
      donation_count: length(donations),
      active_campaigns:
        Giving.Campaign
        |> Ash.Query.filter(church_id == ^church.id and is_active == true)
        |> Ash.read!(actor: actor)
        |> length()
    }
  end
end
