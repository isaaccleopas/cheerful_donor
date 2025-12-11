defmodule CheerfulDonorWeb.DonateLive do
  use CheerfulDonorWeb, :live_view
  import Ash.Query
  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.DonationIntent
  alias CheerfulDonor.Accounts.Donor
  alias CheerfulDonor.Paystack.Client

  @impl true
  def mount(_params, session, socket) do
    user = session["user"]

    user_id =
      case user do
        "user?id=" <> id -> id
        _ -> nil
      end

    IO.puts("Mounted DonateLive with user_id: #{inspect(user_id)}")

    donor =
      if user_id do
        Donor
        |> Ash.Query.new()
        |> Ash.Query.filter(user_id: user_id)
        |> CheerfulDonor.Accounts.read_one()
      else
        {:ok, nil}
      end

    donor =
      case donor do
        {:ok, %Donor{} = donor} ->
          donor

        {:ok, nil} ->
          {:ok, new_donor} =
            Donor
            |> Ash.Changeset.for_create(:create, %{user_id: user_id})
            |> CheerfulDonor.Accounts.create()

          new_donor

        {:error, err} ->
          raise err
      end

    {:ok,
     socket
     |> assign(:user_id, user_id)
     |> assign(:donor, donor)
     |> assign(:amount, nil)
     |> assign(:paid, false)
     |> assign(:loading, false)}
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
      # 1. Create donation intent
      reference = Ecto.UUID.generate()

      changeset =
        DonationIntent
        |> Ash.Changeset.for_create(:create, %{
          amount: int_amount,
          currency: "NGN",
          status: :pending,
          reference: reference,
          donor_id: donor.id
        })

      case Giving.create(changeset) do
        {:ok, intent} ->
          # 2. Initialize Paystack from backend
          params = %{
            email: donor.user.email,
            amount: int_amount * 100,
            reference: intent.reference,
            callback_url: "https://yourapp.com/paystack/verify"
          }

          case Client.initialize_transaction(params) do
            {:ok, %{"data" => %{"authorization_url" => url}}} ->
              {:noreply,
               socket
               |> assign(:loading, true)
               |> push_navigate(to: url)}

            {:error, reason} ->
              IO.inspect(reason, label: "Paystack init failed")

              {:noreply,
               socket
               |> put_flash(:error, "Payment initialization failed")}
          end

        {:error, errors} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to create donation intent: #{inspect(errors)}")}
      end
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid donation amount")}
    end
  end

  @impl true
  def handle_info(%{event: "donation_paid", payload: %{reference: _ref}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Payment confirmed!")
     |> assign(:paid, true)}
  end
end
