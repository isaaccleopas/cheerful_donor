defmodule CheerfulDonorWeb.Admin.PayoutsLive.History do
  use CheerfulDonorWeb, :live_view
  require Ash.Query
  alias CheerfulDonor.Payouts

  def mount(_, _, socket) do
    actor = socket.assigns.current_user
    {:ok, church} = Payouts.get_church(actor)

    payouts =
      Payouts.Payout
      |> Ash.Query.filter(church_id == ^church.id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load(:bank_account)
      |> Ash.read!(actor: actor)

    {:ok, assign(socket, payouts: payouts)}
  end
end
