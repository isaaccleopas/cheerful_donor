defmodule CheerfulDonorWeb.PaystackCallbackController do
  @moduledoc """
  Paystack redirects here after checkout.

  Donation state is finalized only by verified webhooks.
  This callback only informs the user and redirects them.
  """
  use CheerfulDonorWeb, :controller

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.Campaign

  def handle(conn, %{"reference" => reference} = params) do
    case Giving.get_donation_intent(reference) do
      {:ok, nil} ->
        conn
        |> put_flash(:error, "Donation not found")
        |> redirect(to: "/")

      {:ok, intent} ->
        flash =
          if Giving.donation_confirmed?(reference) do
            {:info, "Thank you! Your donation has been confirmed."}
          else
            {:info, "Payment received. We are waiting for secure webhook verification."}
          end

        conn
        |> put_flash(elem(flash, 0), elem(flash, 1))
        |> redirect(to: success_path(intent, params))

      {:error, _} ->
        conn
        |> put_flash(:error, "Something went wrong")
        |> redirect(to: "/")
    end
  end

  defp success_path(intent, params) do
    cond do
      params["donor_token"] -> "/donor/dashboard"
      intent.donor_id -> "/donor/dashboard"
      true -> campaign_donate_path(intent.campaign_id)
    end
  end

  defp campaign_donate_path(campaign_id) do
    case Ash.get(Campaign, campaign_id, authorize?: false) do
      {:ok, %{slug: slug}} -> "/donate/#{slug}"
      _ -> "/campaigns"
    end
  end
end
