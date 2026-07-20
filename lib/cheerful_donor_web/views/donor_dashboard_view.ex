defmodule CheerfulDonorWeb.DonorDashboardView do
  def format_datetime(nil), do: "-"
  def format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y, %I:%M %p")
  def format_datetime(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%d %b %Y, %I:%M %p")

  def format_money(nil), do: "₦0"

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

  def readable_reference(nil), do: "-"

  def readable_reference(reference) when is_binary(reference) do
    ref = String.upcase(reference)

    if String.length(ref) <= 12 do
      ref
    else
      "#{String.slice(ref, 0, 8)}...#{String.slice(ref, -4, 4)}"
    end
  end

  def status_label_class(status) when is_binary(status) or is_atom(status) do
    case to_string(status) do
      "paid" -> "rounded-full border border-success/40 bg-success/15 px-2.5 py-1 font-bold text-success"
      "successful" -> "rounded-full border border-success/40 bg-success/15 px-2.5 py-1 font-bold text-success"
      "pending" -> "rounded-full border border-warning/40 bg-warning/20 px-2.5 py-1 font-bold text-warning"
      "processing" -> "rounded-full border border-info/40 bg-info/20 px-2.5 py-1 font-bold text-info"
      "failed" -> "rounded-full border border-error/40 bg-error/15 px-2.5 py-1 font-bold text-error"
      "past_due" -> "rounded-full border border-error/40 bg-error/15 px-2.5 py-1 font-bold text-error"
      "cancelled" -> "rounded-full border border-base-300 bg-base-200 px-2.5 py-1 font-bold text-base-content/70"
      _ -> "rounded-full border border-base-300 bg-base-200 px-2.5 py-1 font-bold text-base-content/70"
    end
  end
end
