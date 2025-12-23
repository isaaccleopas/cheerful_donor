defmodule CheerfulDonorWeb.CampaignDonateLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Paystack.Client
  alias CheerfulDonor.Enums

  @impl true
  def mount(%{"id" => campaign_id}, session, socket) do
    socket =
      socket
      |> assign(
        campaign_id: campaign_id,
        amount: 1000,
        email: session["email"],
        recurring?: false,
        interval: :monthly,
        loading?: false,
        error: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_recurring", _, socket) do
    {:noreply, update(socket, :recurring?, &(!&1))}
  end

  def handle_event("set_interval", %{"interval" => interval}, socket) do
    {:noreply, assign(socket, interval: String.to_existing_atom(interval))}
  end

  def handle_event("donate", %{"email" => email}, socket) do
    socket = assign(socket, loading?: true)

    reference = Ecto.UUID.generate()
    amount = socket.assigns.amount


    with {:ok, intent} <-
           Giving.create_donation(%{
             reference: reference,
             email: email,
             amount: amount,
             currency: "NGN",
             campaign_id: socket.assigns.campaign_id,
             donor_id: socket.assigns[:current_user] && socket.assigns.current_user.donor_id,
             recurring: socket.assigns.recurring?,
             interval: socket.assigns.interval,
             status: :pending
           }),
         {:ok, %{"data" => %{"authorization_url" => url}}} <-
           Client.initialize_transaction(%{
             email: email,
             amount: amount * 100,
             reference: reference,
             callback_url: "#{CheerfulDonorWeb.Endpoint.url()}/paystack/callback",
             metadata: %{
               donation_intent_id: intent.id,
               recurring: socket.assigns.recurring?,
               interval: socket.assigns.interval
             }
           }) do
      {:noreply, push_redirect(socket, external: url)}
    else
      _ ->
        {:noreply,
         socket
         |> assign(loading?: false)
         |> put_flash(:error, "Unable to start payment")}
    end
  end
end
