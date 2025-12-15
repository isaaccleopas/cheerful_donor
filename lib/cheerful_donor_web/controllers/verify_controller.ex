defmodule CheerfulDonorWeb.VerifyController do
  use CheerfulDonorWeb, :controller

  def handle(conn, _params) do
    conn
    |> put_flash(:info, "Verification handled through webhook")
    |> redirect(to: "/donor/dashboard")
  end
end

# defmodule CheerfulDonorWeb.VerifyController do
#   use CheerfulDonorWeb, :controller

#   alias CheerfulDonor.Giving
#   alias CheerfulDonor.Billing
#   alias CheerfulDonor.Payments
#   alias CheerfulDonor.Giving.DonationIntent
#   alias CheerfulDonor.Billing.Subscription

#   @doc """
#   Handles one-time verification links for donations or subscriptions.
#   Example URL: /verify?type=donation&reference=abc123
#   """
#   def handle(conn, %{"type" => type, "reference" => reference}) do
#     case type do
#       "donation" ->
#         handle_donation_verification(conn, reference)

#       "subscription" ->
#         handle_subscription_verification(conn, reference)

#       _ ->
#         conn
#         |> put_flash(:error, "Invalid verification type")
#         |> redirect(to: "/")
#     end
#   end

#   # --------------------------
#   # Donation verification
#   # --------------------------
#   defp handle_donation_verification(conn, reference) do
#     case Giving.get_donation_intent(reference) do
#       {:ok, %DonationIntent{} = intent} ->
#         Giving.update_donation_intent(intent, %{status: :paid})

#         {:ok, donation} =
#           Giving.create_donation(%{
#             donor_id: intent.donor_id,
#             campaign_id: intent.campaign_id,
#             amount: intent.amount,
#             currency: intent.currency,
#             type: :one_time
#           })

#         Payments.create_transaction(%{
#           donation_id: donation.id,
#           intent_id: intent.id,
#           amount: donation.amount,
#           status: :successful,
#           reference: intent.reference,
#           payment_provider: :manual
#         })

#         Phoenix.PubSub.broadcast(
#           CheerfulDonor.PubSub,
#           "donor:#{intent.donor_id}",
#           {:donation_confirmed, donation.id}
#         )

#         conn
#         |> put_flash(:info, "Donation verified successfully!")
#         |> redirect(to: "/donor/dashboard")

#       _ ->
#         conn
#         |> put_flash(:error, "Donation not found or already verified")
#         |> redirect(to: "/")
#     end
#   end

#   # --------------------------
#   # Subscription verification
#   # --------------------------
#   defp handle_subscription_verification(conn, reference) do
#     case Billing.get_subscription_by_code(reference) do
#       {:ok, %Subscription{} = sub} ->
#         Billing.update_subscription(sub, %{status: :active})

#         Phoenix.PubSub.broadcast(
#           CheerfulDonor.PubSub,
#           "donor:#{sub.donor_id}",
#           {:subscription_activated, sub.id}
#         )

#         conn
#         |> put_flash(:info, "Subscription verified successfully!")
#         |> redirect(to: "/donor/dashboard")

#       _ ->
#         conn
#         |> put_flash(:error, "Subscription not found or already verified")
#         |> redirect(to: "/")
#     end
#   end
# end
