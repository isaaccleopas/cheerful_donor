defmodule CheerfulDonorWeb.PaystackCallbackController do
  use CheerfulDonorWeb, :controller
  alias CheerfulDonor.Giving

  def handle(conn, %{"reference" => reference}) do
    case Giving.get_donation_intent(reference) do
      {:ok, intent} ->
        conn
        |> put_flash(:info, "Thank you! Your payment is being verified.")
        |> redirect(to: "/donor/dashboard")

      _ ->
        conn
        |> put_flash(:error, "Donation not found")
        |> redirect(to: "/")
    end
  end
end
