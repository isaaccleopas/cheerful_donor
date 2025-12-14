defmodule CheerfulDonorWeb.DonateLive do
  use CheerfulDonorWeb, :live_view
  require Ash.Query

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Accounts.Donor
  alias CheerfulDonor.Paystack.Client

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    user_id = user.id

    donor =
      if user_id do
        case Accounts.get_donor_by_user_id!(user_id, actor: %{id: user_id}) do
          %Donor{} = donor -> donor
          nil -> Accounts.create_donor_for_user!(user_id, actor: %{id: user_id})
        end
      else
        nil
      end

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:donor, donor)
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
  def handle_event("set_amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, :amount, amount)}
  end

  @impl true
  def handle_event("start_payment", _params, %{assigns: %{donor: nil}} = socket) do
    {:noreply,
     socket
     |> put_flash(:error, "You must be logged in as a donor to donate.")
     |> push_navigate(to: "/sign-in")}
  end

  def handle_event("start_payment", _params, %{assigns: %{amount: amount, donor: donor}} = socket) do
    with {int_amount, _} <- Integer.parse(amount || "") do
      # Generate donation reference
      reference = Ecto.UUID.generate()

      # Create DonationIntent
      changeset =
        DonationIntent
        |> Ash.Changeset.for_create(:create, %{
          amount: int_amount,
          currency: "NGN",
          status: :pending,
          reference: reference,
          donor_id: donor.id
        })

      case Ash.create(changeset) do
        {:ok, intent} ->
          # Sign donor ID for callback
          donor_token = Phoenix.Token.sign(CheerfulDonorWeb.Endpoint, "donor auth", donor.id)

          callback_url =
            CheerfulDonorWeb.Endpoint.url() <>
              "/paystack/callback?donor_token=#{donor_token}"

          params = %{
            email: donor.user.email,
            amount: int_amount * 100,
            reference: intent.reference,
            callback_url: callback_url
          }

          case Client.initialize_transaction(params) do
            {:ok, %{"data" => %{"authorization_url" => url}}} ->
              {:noreply,
              socket
              |> assign(:loading, true)
              |> redirect(external: url)}

            {:error, reason} ->
              IO.inspect(reason, label: "Paystack init failed")

              {:noreply,
              socket |> put_flash(:error, "Payment initialization failed")}
          end

        {:error, errors} ->
          {:noreply,
          socket |> put_flash(:error, "Failed to create donation intent: #{inspect(errors)}")}
      end
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid donation amount")}
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
