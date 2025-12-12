defmodule CheerfulDonorWeb.DonorDashboardView do

  def format_datetime(nil), do: "-"
  def format_datetime(%DateTime{} = dt), do: DateTime.to_string(dt)
  def format_datetime(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_string(ndt)

  def status_label_class(status) when is_binary(status) or is_atom(status) do
    case to_string(status) do
      "paid" -> "bg-green-100 text-green-800"
      "successful" -> "bg-green-100 text-green-800"
      "pending" -> "bg-yellow-100 text-yellow-800"
      "failed" -> "bg-red-100 text-red-800"
      "past_due" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
