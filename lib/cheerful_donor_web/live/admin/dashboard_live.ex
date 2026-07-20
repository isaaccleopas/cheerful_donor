defmodule CheerfulDonorWeb.Admin.DashboardLive do
  use CheerfulDonorWeb, :live_view
  require Ash.Query

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Giving
  alias CheerfulDonor.Payouts

  attr :label, :string, required: true
  attr :value, :string, required: true

  def stat(assigns) do
    ~H"""
    <div class="cd-panel p-5">
      <div class="cd-label">{@label}</div>
      <div class="cd-stat-value mt-2 text-2xl text-base-content sm:text-3xl">
        {@value}
      </div>
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    actor = socket.assigns.current_user

    show_all_donations? = params["show_donations"] == "all"

    with {:ok, church} <- get_church(actor),
         {:ok, bank_accounts} <- get_bank_accounts(church, actor) do
      cond do
        church == nil ->
          {:ok,
           socket
           |> assign(:needs_onboarding, true)
           |> push_navigate(to: ~p"/admin/church/new")}

        bank_accounts == [] ->
          {:ok,
           socket
           |> assign(:needs_onboarding, true)
           |> push_navigate(to: ~p"/admin/payouts/bank-accounts/new")}

        true ->
          {:ok,
           socket
           |> assign(:needs_onboarding, false)
           |> assign(:page_title, "Admin Dashboard")
           |> assign(:actor, actor)
           |> assign(:church, church)
           |> assign(:bank_accounts, bank_accounts)
           |> assign(:campaigns, get_campaigns(church, actor))
           |> assign(:stats, get_stats(church, actor))
           |> assign(:show_all_donations?, show_all_donations?)
           |> assign(:recent_donations, get_recent_donations(church, actor, show_all_donations?))}
      end
    else
      _ ->
        {:ok,
         socket
         |> assign(:needs_onboarding, false)
         |> put_flash(:error, "Unable to load admin dashboard")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    show_all_donations? = params["show_donations"] == "all"

    if socket.assigns.church && socket.assigns.actor do
      {:noreply,
       socket
       |> assign(:show_all_donations?, show_all_donations?)
       |> assign(
         :recent_donations,
         get_recent_donations(socket.assigns.church, socket.assigns.actor, show_all_donations?)
       )}
    else
      {:noreply, assign(socket, :show_all_donations?, show_all_donations?)}
    end
  end

  defp get_church(actor) do
    Accounts.Church
    |> Ash.Query.filter(user_id == ^actor.id)
    |> Ash.read_one(actor: actor)
  end

  defp get_bank_accounts(nil, _actor), do: {:ok, []}

  defp get_bank_accounts(church, actor) do
    accounts =
      Payouts.BankAccount
      |> Ash.Query.filter(church_id == ^church.id)
      |> Ash.read!(actor: actor)

    {:ok, accounts}
  end

  defp get_campaigns(church, actor) do
    Giving.Campaign
    |> Ash.Query.for_read(:list_for_church, %{church_id: church.id})
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: actor)
  end

  defp get_recent_donations(church, actor, show_all?) do
    query =
      Giving.Donation
      |> Ash.Query.filter(church_id == ^church.id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load(:campaign)

    query =
      if show_all? do
        query
      else
        Ash.Query.limit(query, 10)
      end

    Ash.read!(query, actor: actor)
  end

  defp get_stats(church, actor) do
    donations =
      Giving.Donation
      |> Ash.Query.filter(church_id == ^church.id and status == :successful)
      |> Ash.read!(actor: actor)

    active_campaigns =
      Giving.Campaign
      |> Ash.Query.for_read(:list_for_church, %{church_id: church.id})
      |> Ash.Query.filter(is_active == true)
      |> Ash.read!(actor: actor)
      |> length()

    %{
      total_amount: Enum.sum(Enum.map(donations, &(&1.amount_paid || 0))),
      donation_count: length(donations),
      active_campaigns: active_campaigns
    }
  end

  def format_datetime(nil), do: "-"
  def format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y, %I:%M %p")
  def format_datetime(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%d %b %Y, %I:%M %p")

  def format_money(amount) when is_integer(amount) do
    "₦" <>
      (amount
       |> Integer.to_string()
       |> String.reverse()
       |> String.graphemes()
       |> Enum.chunk_every(3)
       |> Enum.map(&Enum.join/1)
       |> Enum.join(",")
       |> String.reverse())
  end

  def format_money(_), do: "₦0"

  def status_badge_class(status) when is_atom(status), do: status_badge_class(to_string(status))

  def status_badge_class(status) do
    case status do
      "successful" -> "rounded-full border border-success/40 bg-success/15 px-2.5 py-1 font-bold text-success"
      "success" -> "rounded-full border border-success/40 bg-success/15 px-2.5 py-1 font-bold text-success"
      "pending" -> "rounded-full border border-warning/40 bg-warning/20 px-2.5 py-1 font-bold text-warning"
      "processing" -> "rounded-full border border-info/40 bg-info/20 px-2.5 py-1 font-bold text-info"
      "failed" -> "rounded-full border border-error/40 bg-error/15 px-2.5 py-1 font-bold text-error"
      _ -> "rounded-full border border-base-300 bg-base-200 px-2.5 py-1 font-bold text-base-content/70"
    end
  end

  def readable_reference(nil), do: "-"

  def readable_reference(reference) when is_binary(reference) do
    ref = String.upcase(reference)

    if String.length(ref) <= 12 do
      ref
    else
      "#{String.slice(ref, 0, 8)}...#{String.slice(ref, -4, 4)}"
    end
  end
end
