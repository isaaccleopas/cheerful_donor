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

  def readable_reference(nil), do: "-"

  def readable_reference(reference) when is_binary(reference) do
    ref = String.upcase(reference)

    if String.length(ref) <= 12 do
      ref
    else
      "#{String.slice(ref, 0, 8)}...#{String.slice(ref, -4, 4)}"
    end
  end

  def status_badge_class(status) do
    case to_string(status) do
      "success" -> "rounded-full bg-success/15 px-2.5 py-1 font-semibold text-success"
      "failed" -> "rounded-full bg-error/15 px-2.5 py-1 font-semibold text-error"
      "pending" -> "rounded-full bg-warning/20 px-2.5 py-1 font-semibold text-warning"
      "processing" -> "rounded-full bg-info/20 px-2.5 py-1 font-semibold text-info"
      _ -> "rounded-full bg-base-300 px-2.5 py-1 font-semibold text-base-content/70"
    end
  end
end
