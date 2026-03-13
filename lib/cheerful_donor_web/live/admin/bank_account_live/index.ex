defmodule CheerfulDonorWeb.Admin.BankAccountLive.Index do
  use CheerfulDonorWeb, :live_view

  require Ash.Query
  alias CheerfulDonor.Payouts
  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Paystack.Client

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user
    {:ok, church} = Payouts.get_church(actor)

    bank_accounts =
      Payouts.BankAccount
      |> Ash.Query.filter(church_id == ^church.id)
      |> Ash.read!(actor: actor)

    ash_form =
      AshPhoenix.Form.for_create(
        Payouts.BankAccount,
        :create,
        actor: actor
      )

    {:ok,
    socket
    |> assign(:church, church)
    |> assign(:bank_accounts, bank_accounts)
    |> assign(:editing_account, nil)
    |> assign(:ash_form, ash_form)
    |> assign(:form, Phoenix.Component.to_form(ash_form))}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    bank_account =
      Payouts.get_bank_account!(id, actor)

    ash_form =
      AshPhoenix.Form.for_update(
        bank_account,
        :update,
        actor: actor
      )

    {:noreply,
    socket
    |> assign(:editing_account, bank_account)
    |> assign(:ash_form, ash_form)
    |> assign(:form, Phoenix.Component.to_form(ash_form))}
  end

  def handle_event("save", %{"bank_account" => params}, socket) do
    actor = socket.assigns.current_user
    church = socket.assigns.church
    editing_account = socket.assigns.editing_account

    params = Map.put(params, "church_id", church.id)

    result =
      if editing_account do
        # UPDATE (no Paystack call)
        AshPhoenix.Form.submit(socket.assigns.ash_form,
          params: params,
          actor: actor
        )
      else
        # CREATE (call Paystack)
        with {:ok, response} <- Client.create_transfer_recipient(params),
            recipient_code <- get_in(response, ["data", "recipient_code"]) do
          params = Map.put(params, "recipient_code", recipient_code)

          AshPhoenix.Form.submit(socket.assigns.ash_form,
            params: params,
            actor: actor
          )
        end
      end

    case result do
      {:ok, _account} ->
        bank_accounts =
          Payouts.BankAccount
          |> Ash.Query.filter(church_id == ^church.id)
          |> Ash.read!(actor: actor)

        {:noreply,
        socket
        |> put_flash(:info, "Bank account saved")
        |> assign(:bank_accounts, bank_accounts)
        |> assign(:editing_account, nil)
        |> reset_form(actor)}

      {:error, ash_form} ->
        {:noreply,
        socket
        |> assign(:ash_form, ash_form)
        |> assign(:form, Phoenix.Component.to_form(ash_form))}
    end
  end

  defp reset_form(socket, actor) do
    ash_form =
      AshPhoenix.Form.for_create(
        Payouts.BankAccount,
        :create,
        actor: actor
      )

    socket
    |> assign(:ash_form, ash_form)
    |> assign(:form, Phoenix.Component.to_form(ash_form))
  end

  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    church = socket.assigns.church

    bank_account =
      Payouts.get_bank_account!(id, actor)

    case Payouts.destroy_bank_account(bank_account, actor) do
      :ok ->
        bank_accounts =
          Payouts.BankAccount
          |> Ash.Query.filter(church_id == ^church.id)
          |> Ash.read!(actor: actor)

        {:noreply,
        socket
        |> put_flash(:info, "Bank account deleted")
        |> assign(:bank_accounts, bank_accounts)}

      {:error, _} ->
        {:noreply,
        socket
        |> put_flash(:error, "Unable to delete bank account")}
    end
  end
end
