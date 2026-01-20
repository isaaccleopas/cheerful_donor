defmodule CheerfulDonorWeb.Admin.BankAccountLive do
  use CheerfulDonorWeb, :live_view

  require Ash.Query
  alias CheerfulDonor.Payouts
  alias CheerfulDonor.Accounts

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user
    {:ok, church} = get_church(actor)

    ash_form =
      AshPhoenix.Form.for_create(
        Payouts.BankAccount,
        :create,
        actor: actor
      )

    phoenix_form =
      Phoenix.Component.to_form(
        ash_form,
        as: "bank_account"
      )

    {:ok,
    socket
    |> assign(:church, church)
    |> assign(:ash_form, ash_form)
    |> assign(:form, phoenix_form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    params = Map.put(params, "church_id", socket.assigns.church.id)

    case AshPhoenix.Form.submit(socket.assigns.ash_form, params: params) do
      {:ok, _bank_account} ->
        {:noreply,
        socket
        |> put_flash(:info, "Bank account added")
        |> push_navigate(to: ~p"/admin/dashboard")}

      {:error, ash_form} ->
        {:noreply,
        socket
        |> assign(:ash_form, ash_form)
        |> assign(
          :form,
          Phoenix.Component.to_form(ash_form)
        )}
    end
  end

  defp get_church(actor) do
    Accounts.Church
    |> Ash.Query.filter(user_id == ^actor.id)
    |> Ash.read_one(actor: actor)
  end
end
