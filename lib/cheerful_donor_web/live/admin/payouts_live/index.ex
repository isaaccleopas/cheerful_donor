defmodule CheerfulDonorWeb.Admin.PayoutsLive.Index do
  use CheerfulDonorWeb, :live_view

  require Ash.Query
  alias CheerfulDonor.{Payouts, Giving}
  alias CheerfulDonor.Payouts.Workers.ProcessPayout

  def mount(_, _, socket) do
    actor = socket.assigns.current_user
    {:ok, church} = Payouts.get_church(actor)

    bank_accounts =
      Payouts.BankAccount
      |> Ash.Query.filter(church_id == ^church.id)
      |> Ash.read!(actor: actor)

    payouts =
      Payouts.Payout
      |> Ash.Query.filter(church_id == ^church.id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load(:bank_account)
      |> Ash.read!(actor: actor)

    balance = calculate_balance(church, actor)

    socket =
      socket
      |> assign(:church, church)
      |> assign(:bank_accounts, bank_accounts)
      |> assign(:payouts, payouts)
      |> assign(:balance, balance)
      |> assign(:form, to_form(%{}, as: :payout))

    {:ok, socket}
  end

  def handle_event("payout", %{"bank_account_id" => id, "amount" => amt}, socket) do
    actor = socket.assigns.current_user
    church = socket.assigns.church

    amount = String.to_integer(amt)

    cond do
      amount <= 0 ->
        {:noreply, put_flash(socket, :error, "Invalid amount")}

      amount > socket.assigns.balance ->
        {:noreply, put_flash(socket, :error, "Insufficient balance")}

      true ->
        reference = Ecto.UUID.generate()

        {:ok, payout} =
          Payouts.create_payout(%{
            church_id: church.id,
            bank_account_id: id,
            amount: amount,
            reference: reference,
            status: :pending
          }, actor)

        # 🚀 Background job
        Oban.insert!(
          ProcessPayout.new(%{
            "payout_id" => payout.id
          })
        )

        {:noreply,
        socket
        |> put_flash(:info, "Payout started")
        |> push_navigate(to: ~p"/admin/dashboard")}
    end
  end

  defp calculate_balance(church, actor) do
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

    donations - payouts
  end
end
