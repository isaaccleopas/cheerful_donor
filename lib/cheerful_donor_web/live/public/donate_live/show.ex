defmodule CheerfulDonorWeb.Public.DonateLive.Show do
  use CheerfulDonorWeb, :live_view
  require Ash.Query

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.Campaign
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

    user = socket.assigns[:current_user]
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
     |> assign(:page_title, campaign.title)
     |> assign(:campaign, campaign)
     |> assign(:user_id, user_id)
     |> assign(:donor, donor)
     |> assign(:amount, nil)
     |> assign(:guest_email, "")
     |> assign(:guest_name, "")
     |> assign(:paid, false)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("update_form", params, socket) do
    {:noreply,
     socket
     |> assign(:amount, params["amount"])
     |> assign(:guest_email, params["guest_email"])
     |> assign(:guest_name, params["guest_name"])}
  end

  @impl true
  def handle_event("start_payment", _, %{assigns: assigns} = socket) do
    amount = assigns.amount
    donor = assigns.donor
    campaign = assigns.campaign
    guest_email = assigns.guest_email
    guest_name = assigns.guest_name

    cond do
      is_nil(amount) or amount == "" ->
        {:noreply, put_flash(socket, :error, "Please enter an amount")}

      is_nil(donor) and (is_nil(guest_email) or guest_email == "") ->
        {:noreply, put_flash(socket, :error, "Email is required")}

      true ->
        with {int_amount, _} <- Integer.parse(amount) do
          attrs =
            %{
              amount: int_amount,
              currency: "NGN",
              campaign_id: campaign.id,
              church_id: campaign.church_id,
              type: :one_time
            }
            |> maybe_put_donor(donor)
            |> maybe_put_guest(guest_email, guest_name)

          case Giving.initiate_donation(attrs) do
            {:ok, lookup} ->
              email =
                if donor do
                  to_string(socket.assigns.current_user.email)
                else
                  guest_email
                end

              params = %{
                email: email,
                amount: int_amount * 100,
                reference: lookup.reference,
                callback_url: CheerfulDonorWeb.Endpoint.url() <> "/paystack/callback"
              }

              case Client.initialize_transaction(params) do
                {:ok, %{"status" => true, "data" => %{"authorization_url" => url}}} ->
                  {:noreply, redirect(socket, external: url)}

                {:ok, %{"message" => message}} ->
                  {:noreply, put_flash(socket, :error, message)}

                {:error, _reason} ->
                  {:noreply, put_flash(socket, :error, "Payment failed")}
              end

            {:error, error} ->
              {:noreply,
               put_flash(socket, :error, "Failed to create donation: #{inspect(error)}")}
          end
        else
          _ ->
            {:noreply, put_flash(socket, :error, "Invalid amount")}
        end
    end
  end

  defp maybe_put_donor(attrs, nil), do: attrs
  defp maybe_put_donor(attrs, donor), do: Map.put(attrs, :donor_id, donor.id)

  defp maybe_put_guest(attrs, email, name) do
    attrs
    |> Map.put(:guest_email, email)
    |> Map.put(:guest_name, name)
  end
end
