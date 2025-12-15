defmodule CheerfulDonorWeb.DonorDashboardLive do
  use CheerfulDonorWeb, :live_view
  import CheerfulDonorWeb.DonorDashboardView

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Giving
  alias CheerfulDonor.Billing
  alias CheerfulDonor.Payments

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    user_id = user.id

    donor = Accounts.get_donor_by_user_id!(user_id, actor: %{id: user_id})
    donations = Giving.get_donations_for_donor(donor.id)
    subscriptions = Billing.get_subscriptions_for_donor(donor.id)
    transactions = Payments.get_transactions_for_donor(donor.id)

    totals = calc_totals(donations)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(CheerfulDonor.PubSub, "donor:#{donor.id}")
    end

    {:ok,
    socket
    |> assign(:donor, donor)
    |> assign(:donations, donations)
    |> assign(:subscriptions, subscriptions)
    |> assign(:transactions, transactions)
    |> assign(:totals, totals)
    |> assign(:tab, "donations")
    |> assign(:loading, false)}
  end

  # Helper
  defp calc_totals(donations) do
    total_given =
      donations
      |> Enum.map(& &1.amount_paid || &1.amount)
      |> Enum.filter(& &1)
      |> Enum.sum()

    this_month =
      donations
      |> Enum.filter(fn
        %{inserted_at: %DateTime{} = dt} ->
          dt.month == DateTime.utc_now().month and dt.year == DateTime.utc_now().year

        _ -> false
      end)
      |> Enum.map(& &1.amount_paid || &1.amount)
      |> Enum.sum()

    active_subs = 0
    %{total_given: total_given, this_month: this_month, active_subscriptions: active_subs}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
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

  # PubSub updates for donations and recurring payments
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
end
