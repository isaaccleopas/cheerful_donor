defmodule CheerfulDonorWeb.Donor.DonateLive.Show do
  use CheerfulDonorWeb, :live_view
  require Ash.Query

  alias CheerfulDonor.Giving.{Campaign, DonationIntent}
  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Accounts.Donor
  alias CheerfulDonor.Paystack.Client

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    campaign =
      Campaign
      |> Ash.Query.for_read(:by_slug, %{slug: slug})
      |> Ash.Query.load(:church)
      |> Ash.read_one!()

    user = socket.assigns.current_user
    user_id = user && user.id

    donor =
      if user_id do
        case Accounts.get_donor_by_user_id(user_id, actor: %{id: user_id}) do
          %Donor{} = donor -> donor
          nil -> Accounts.create_donor_for_user!(user_id, actor: %{id: user_id})
        end
      else
        nil
      end

    {:ok,
     socket
     |> assign(:campaign, campaign)
     |> assign(:donor, donor)
     |> assign(:amount, nil)
     |> assign(:loading, false)
     |> assign(:paid, false)}
  end

  # ========================
  # Amount Selection
  # ========================

  @impl true
  def handle_event("set_amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, :amount, amount)}
  end

  # ========================
  # Start Payment
  # ========================

  def handle_event("start_payment", _, %{assigns: %{donor: nil}} = socket) do
    {:noreply,
     socket
     |> put_flash(:error, "You must be logged in to donate.")
     |> push_navigate(to: "/sign-in")}
  end

  def handle_event("start_payment", _, %{assigns: %{amount: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "Please enter an amount")}
  end

  def handle_event(
        "start_payment",
        _,
        %{assigns: %{amount: amount, donor: donor, campaign: campaign}} = socket
      ) do
    with {int_amount, _} <- Integer.parse(amount || "") do
      reference = Ecto.UUID.generate()

      changeset =
        DonationIntent
        |> Ash.Changeset.for_create(:create, %{
          amount: int_amount,
          currency: "NGN",
          status: :pending,
          reference: reference,
          donor_id: donor.id,
          campaign_id: campaign.id   # ✅ attach campaign
        })

      case Ash.create(changeset) do
        {:ok, intent} ->
          donor_token =
            Phoenix.Token.sign(CheerfulDonorWeb.Endpoint, "donor auth", donor.id)

          callback_url =
            CheerfulDonorWeb.Endpoint.url() <>
              "/paystack/callback?donor_token=#{donor_token}"

          params = %{
            email: socket.assigns.current_user.email,
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

            {:error, _} ->
              {:noreply,
               put_flash(socket, :error, "Payment initialization failed")}
          end

        {:error, error} ->
          {:noreply,
           put_flash(socket, :error, "Failed to create donation: #{inspect(error)}")}
      end
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid amount")}
    end
  end
end
