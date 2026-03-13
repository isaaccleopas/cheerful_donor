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
            |> assign(:recent_donations, get_recent_donations(church, actor))}
      end
    else
      _ ->
        {:ok,
        socket
        |> assign(:needs_onboarding, false)
        |> put_flash(:error, "Unable to load admin dashboard")}
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

  defp get_recent_donations(church, actor) do
    Giving.Donation
    |> Ash.Query.filter(church_id == ^church.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(10)
    |> Ash.Query.load(:campaign)
    |> Ash.read!(actor: actor)
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

  @impl true
  def handle_event("payout", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    church = socket.assigns.church

    bank_account = Payouts.get_bank_account!(id, actor)
    IO.inspect(bank_account, label: "Selected bank account for payout")

    amount = calculate_payout_amount(church, actor)
    IO.inspect(amount, label: "Calculated payout amount for church #{church.id}")

    if amount <= 0 do
      {:noreply,
        socket
        |> put_flash(:error, "No funds available for payout")}
    else
      reference = Ecto.UUID.generate()

      # Create payout record first
      {:ok, payout} =
        Payouts.create_payout(%{
          church_id: church.id,
          bank_account_id: bank_account.id,
          amount: amount,
          reference: reference,
          status: :processing
        }, actor)

      case CheerfulDonor.Paystack.Client.initiate_transfer(
            bank_account.recipient_code,
            amount,
            reference
          ) do

        {:ok, response} ->
          transfer_code = get_in(response, ["data", "transfer_code"])

          Payouts.update_payout(
            payout,
            %{
              transfer_code: transfer_code
            },
            actor
          )

          {:noreply,
            put_flash(socket, :info, "Payout is processing")}

        {:error, reason} ->
          IO.inspect(reason, label: "Paystack transfer error")

          Payouts.update_payout(payout, %{status: :failed}, actor)

          {:noreply,
            put_flash(socket, :error, "Payout failed")}
      end
    end
  end

  defp calculate_payout_amount(church, actor) do
    donations =
      Giving.Donation
      |> Ash.Query.filter(church_id == ^church.id and status == :successful)
      |> Ash.read!(actor: actor)
      |> Enum.map(&(&1.amount_paid || 0))
      |> Enum.sum()

    payouts =
      Payouts.Payout
      |> Ash.Query.filter(church_id == ^church.id and status == :success)
      |> Ash.read!(actor: actor)
      |> Enum.map(& &1.amount)
      |> Enum.sum()

    available = donations - payouts

    IO.inspect(available, label: "Available balance for church #{church.id}")

    available
  end
end
