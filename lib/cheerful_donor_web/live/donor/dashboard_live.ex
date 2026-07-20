defmodule CheerfulDonorWeb.Donor.DashboardLive do
  use CheerfulDonorWeb, :live_view
  import CheerfulDonorWeb.DonorDashboardView

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Giving
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Payments

  @recent_limit 10

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user do
      donor =
        Accounts.get_donor_by_user_id(
          user.id,
          actor: %{id: user.id}
        )

      donations =
        if donor, do: Giving.get_donations_for_donor(donor.id) || [], else: []

      subscriptions =
        if donor, do: Billing.get_subscriptions_for_donor(donor.id) || [], else: []

      transactions =
        if donor, do: Payments.get_transactions_for_donor(donor.id) || [], else: []

      totals = calc_totals(donations)

      if connected?(socket) and donor do
        Phoenix.PubSub.subscribe(CheerfulDonor.PubSub, "donor:#{donor.id}")
      end

      {:ok,
       socket
       |> assign(:user_email, user.email)
       |> assign(:donor, donor)
       |> assign(:donations, donations)
       |> assign(:subscriptions, subscriptions)
       |> assign(:transactions, transactions)
       |> assign(:totals, totals)
       |> assign(:tab, "donations")
       |> assign(:show_all_donations?, false)
       |> assign(:show_all_subscriptions?, false)
       |> assign(:show_all_transactions?, false)
       |> assign(:loading, false)}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  defp calc_totals(donations) when is_list(donations) do
    total_given =
      donations
      |> Enum.map(&(&1.amount_paid || &1.amount))
      |> Enum.filter(& &1)
      |> Enum.sum()

    this_month =
      donations
      |> Enum.filter(fn
        %{inserted_at: %DateTime{} = dt} ->
          dt.month == DateTime.utc_now().month and dt.year == DateTime.utc_now().year

        _ ->
          false
      end)
      |> Enum.map(&(&1.amount_paid || &1.amount))
      |> Enum.sum()

    %{total_given: total_given, this_month: this_month, active_subscriptions: 0}
  end

  defp calc_totals(_), do: %{total_given: 0, this_month: 0, active_subscriptions: 0}

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def handle_event("toggle_show_all", %{"section" => section}, socket) do
    socket =
      case section do
        "donations" ->
          assign(socket, :show_all_donations?, !socket.assigns.show_all_donations?)

        "subscriptions" ->
          assign(socket, :show_all_subscriptions?, !socket.assigns.show_all_subscriptions?)

        "transactions" ->
          assign(socket, :show_all_transactions?, !socket.assigns.show_all_transactions?)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    donor = socket.assigns.donor
    donations = Giving.get_donations_for_donor(donor.id)
    subscriptions = Billing.get_subscriptions_for_donor(donor.id)
    transactions = Payments.get_transactions_for_donor(donor.id)

    {:noreply,
     socket
     |> assign(:donations, donations)
     |> assign(:subscriptions, subscriptions)
     |> assign(:transactions, transactions)
     |> assign(:totals, calc_totals(donations))}
  end

  @impl true
  def handle_event("cancel_subscription", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    donor = socket.assigns.donor

    with {:ok, sub} <- Ash.get(CheerfulDonor.Billing.Subscription, id, actor: actor),
         true <- is_nil(donor) or sub.donor_id == donor.id,
         {:ok, _} <- CheerfulDonor.Billing.cancel_subscription(sub) do
      {:noreply,
       socket
       |> put_flash(:info, "Subscription cancelled")
       |> reload_subscriptions()}
    else
      false ->
        {:noreply, put_flash(socket, :error, "You can only cancel your own subscriptions")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel subscription")}
    end
  end

  @impl true
  def handle_info({:donation_confirmed, _donation_id}, socket) do
    donor = socket.assigns.donor
    donations = Giving.get_donations_for_donor(donor.id)
    transactions = Payments.get_transactions_for_donor(donor.id)

    {:noreply,
     socket
     |> assign(:donations, donations)
     |> assign(:transactions, transactions)
     |> assign(:totals, calc_totals(donations))}
  end

  @impl true
  def handle_info({:recurring_payment, _donation_id}, socket) do
    donor = socket.assigns.donor
    donations = Giving.get_donations_for_donor(donor.id)
    subscriptions = Billing.get_subscriptions_for_donor(donor.id)
    transactions = Payments.get_transactions_for_donor(donor.id)

    {:noreply,
     socket
     |> assign(:donations, donations)
     |> assign(:subscriptions, subscriptions)
     |> assign(:transactions, transactions)
     |> assign(:totals, calc_totals(donations))}
  end

  @impl true
  def handle_info({:recurring_payment_failed, _sub_id}, socket) do
    {:noreply,
     put_flash(socket, :error, "A recurring payment failed — please check your payment method.")}
  end

  defp reload_subscriptions(socket) do
    donor = socket.assigns.donor
    subs = Billing.get_subscriptions_for_donor(donor.id)
    assign(socket, :subscriptions, subs)
  end

  def visible_items(items, show_all?) when is_list(items) do
    if show_all?, do: items, else: Enum.take(items, @recent_limit)
  end

  def visible_items(_, _), do: []
end
