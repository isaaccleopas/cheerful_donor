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
    {:noreply, assign(socket, :interval, String.to_existing_atom(interval))}
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

  def handle_event("start_payment", _, %{assigns: %{amount: amount, donor: donor, campaign: campaign}} = socket) do
    case Integer.parse(amount || "") do
      {int_amount, _} ->

        if socket.assigns.donation_type == "recurring" do
          # --- RECURRING DONATION FLOW ---
          subscription_code = Ecto.UUID.generate()

          {:ok, paystack_customer} =
            if donor.paystack_customer_id do
              {:ok, donor.paystack_customer_id}
            else
              {:ok, customer} =
                Client.create_customer(%{
                  email: to_string(donor.user.email),
                  first_name: donor.user.email |> to_string() |> String.split("@") |> hd(),
                  last_name: "",
                  phone: donor.phone
                })

              # <-- Now calls Ash-safe update
              {:ok, _donor} =
                Accounts.update_donor(donor, %{paystack_customer_id: customer["data"]["customer_code"]}, actor: %{id: donor.user_id})

              {:ok, customer["data"]["customer_code"]}
            end

          # 2. Create subscription record in DB
          {:ok, _subscription} =
            Billing.create_subscription(%{
              donor_id: donor.id,
              campaign_id: campaign.id,
              church_id: campaign.church_id,
              amount: int_amount,
              interval: socket.assigns.interval || :monthly,
              status: :active,
              subscription_code: subscription_code
            })

          # 3. Prepare Paystack plan (must exist on Paystack dashboard)
          {:ok, plan} =
            Client.create_plan(
              "#{campaign.title}-#{int_amount}",
              int_amount,
              socket.assigns.interval
            )

          plan_code = plan["data"]["plan_code"]

          # 4. Create Paystack subscription
          case Client.create_subscription(%{customer_code: paystack_customer, plan_code: plan_code}) do
            {:ok, %{"data" => data}} ->

              case data["authorization_url"] do
                nil ->
                  # Subscription activated instantly
                  {:noreply,
                  socket
                  |> put_flash(:info, "Subscription activated successfully!")
                  |> assign(:loading, false)}

                url ->
                  {:noreply,
                  socket
                  |> assign(:loading, true)
                  |> redirect(external: url)}
              end

            {:error, reason} ->
              IO.inspect(reason, label: "SUBSCRIPTION ERROR")

              {:noreply,
              socket
              |> put_flash(:error, "Subscription setup failed")
              |> assign(:loading, false)}
          end

        else
          # --- ONE-TIME DONATION FLOW ---
          reference = Ecto.UUID.generate()

          changeset =
            DonationIntent
            |> Ash.Changeset.for_create(:create, %{
              amount: int_amount,
              currency: "NGN",
              status: :pending,
              reference: reference,
              donor_id: donor.id,
              campaign_id: campaign.id,
              church_id: campaign.church_id
            })

          case Ash.create(changeset) do
            {:ok, intent} ->
              donor_token = Phoenix.Token.sign(CheerfulDonorWeb.Endpoint, "donor auth", donor.id)

              callback_url =
                CheerfulDonorWeb.Endpoint.url() <>
                  "/paystack/callback?donor_token=#{donor_token}"

              params = %{
                email: to_string(donor.user.email),
                amount: int_amount * 100,
                reference: intent.reference,
                callback_url: callback_url
              }

              case Client.initialize_transaction(params) do
                {:ok, %{"status" => true, "data" => %{"authorization_url" => url}}} ->
                  {:noreply,
                  socket
                  |> assign(:loading, true)
                  |> redirect(external: url)}

                {:ok, %{"status" => false, "message" => message}} ->
                  {:noreply,
                  put_flash(socket, :error, "Paystack error: #{message}")}

                {:error, reason} ->
                  IO.inspect(reason, label: "PAYSTACK ERROR")
                  {:noreply, put_flash(socket, :error, "Payment initialization failed")}
              end

            {:error, error} ->
              {:noreply,
              put_flash(socket, :error, "Failed to create donation: #{inspect(error)}")}
          end
        end

      :error ->
        {:noreply, put_flash(socket, :error, "Invalid amount")}
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
