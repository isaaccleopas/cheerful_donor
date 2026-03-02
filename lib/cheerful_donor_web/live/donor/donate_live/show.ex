defmodule CheerfulDonorWeb.Donor.DonateLive.Show do
  use CheerfulDonorWeb, :live_view
  require Ash.Query

  alias CheerfulDonor.Giving.{Campaign, DonationIntent}
  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Accounts.Donor
  alias CheerfulDonor.Paystack.Client
  alias CheerfulDonor.Billing

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    campaign =
      Campaign
      |> Ash.Query.for_read(:by_slug, %{slug: slug})
      |> Ash.Query.load(:church)
      |> Ash.read_one!()

    user = socket.assigns.current_user
    user_id = user.id

    donor =
      if user_id do
        case Accounts.get_donor_by_user_id(user_id, actor: %{id: user_id}) do
          %Donor{} = donor -> donor
          nil -> Accounts.create_donor_for_user!(user_id, actor: %{id: user_id})
        end
      else
        nil
      end

    socket =
      socket
      |> assign(:campaign, campaign)
      |> assign(:user_id, user_id)
      |> assign(:donor, donor)
      |> assign(:donation_type, :one_time)
      |> assign(:amount, nil)
      |> assign(:paid, false)
      |> assign(:loading, false)

    # Subscribe to donor events for real-time update
    if connected?(socket) and donor do
      Phoenix.PubSub.subscribe(CheerfulDonor.PubSub, "donor:#{donor.id}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("set_donation_type", %{"donation_type" => type}, socket) do
    {:noreply, assign(socket, :donation_type, type)}
  end

  @impl true
  def handle_event("set_interval", %{"interval" => interval}, socket) do
    allowed =
      CheerfulDonor.Enums.subscription_intervals()
      |> Enum.map(&to_string/1)

    if interval in allowed do
      {:noreply, assign(socket, :interval, String.to_atom(interval))}
    else
      {:noreply,
      socket
      |> put_flash(:error, "Invalid interval selected")}
    end
  end

  @impl true
  def handle_event("set_amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, :amount, amount)}
  end

  def handle_event("start_payment", _, %{assigns: %{donor: nil}} = socket) do
    {:noreply,
    socket
    |> put_flash(:error, "You must be logged in to donate.")
    |> push_navigate(to: "/")}
  end

  def handle_event("start_payment", _, %{assigns: %{amount: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "Please enter an amount")}
  end

  def handle_event("start_payment", _, socket) do
    user = socket.assigns.current_user
    donor = socket.assigns.donor
    campaign = socket.assigns.campaign
    amount = socket.assigns.amount
    donation_type = String.to_atom(to_string(socket.assigns.donation_type || "one_time"))

    cond do
      is_nil(donor) ->
        {:noreply,
        socket
        |> put_flash(:error, "You must be logged in to donate.")
        |> push_navigate(to: "/")}

      is_nil(amount) or amount == "" ->
        {:noreply, put_flash(socket, :error, "Please enter an amount")}

      true ->
        case Integer.parse(amount) do
          {int_amount, _} when int_amount > 0 ->
            reference = Ecto.UUID.generate()

            interval =
              if donation_type == :recurring do
                socket.assigns.interval || :monthly
              else
                nil
              end

            # Validate interval for recurring
            allowed_intervals =
              CheerfulDonor.Enums.subscription_intervals()
              |> Enum.map(&to_string/1)

            if donation_type == :recurring and to_string(interval) not in allowed_intervals do
              {:noreply,
              put_flash(socket, :error, "Invalid interval selected")}
            else
              # Create DonationIntent
              case DonationIntent
                  |> Ash.Changeset.for_create(:create, %{
                        donor_id: donor.id,
                        campaign_id: campaign.id,
                        church_id: campaign.church_id,
                        amount: int_amount,
                        currency: "NGN",
                        status: :pending,
                        reference: reference,
                        type: donation_type,
                        interval: interval
                      })
                  |> Ash.create() do

                {:ok, intent} ->
                  # Generate donor token for Paystack callback
                  donor_token = Phoenix.Token.sign(CheerfulDonorWeb.Endpoint, "donor auth", donor.id)

                  callback_url =
                    CheerfulDonorWeb.Endpoint.url() <> "/paystack/callback?donor_token=#{donor_token}"

                  # Initialize Paystack transaction
                  case Client.initialize_transaction(%{
                        email: donor.user && to_string(donor.user.email) || "no-email@unknown.com",
                        amount: int_amount * 100,
                        reference: intent.reference,
                        callback_url: callback_url
                      }) do
                    {:ok, %{"status" => true, "data" => %{"authorization_url" => url}}} ->
                      {:noreply,
                      socket
                      |> assign(:loading, true)
                      |> redirect(external: url)}

                    {:ok, %{"status" => false, "message" => message}} ->
                      {:noreply,
                      put_flash(socket, :error, "Paystack error: #{message}")}

                    {:error, reason} ->
                      Logger.error("Paystack initialization error: #{inspect(reason)}")
                      {:noreply, put_flash(socket, :error, "Payment initialization failed")}
                  end

                {:error, errors} ->
                  Logger.error("Failed to create DonationIntent: #{inspect(errors)}")
                  {:noreply, put_flash(socket, :error, "Failed to create donation.")}
              end
            end

          _ ->
            {:noreply, put_flash(socket, :error, "Invalid amount")}
        end
    end
  end

  @impl true
  def handle_info({:donation_confirmed, _donation_id}, socket) do
    {:noreply,
    socket
    |> put_flash(:info, "Donation successful! Thank you.")
    |> assign(:paid, true)
    |> assign(:loading, false)}
  end
end
