defmodule CheerfulDonorWeb.Admin.BankAccountLive.Index do
  use CheerfulDonorWeb, :live_view

  require Ash.Query
  alias CheerfulDonor.Payouts
  alias CheerfulDonor.Paystack.Client

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
     |> assign(:form, Phoenix.Component.to_form(ash_form, as: "bank_account"))}
  end

  # EDIT
  def handle_params(%{"id" => id}, _url, socket) do
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
     |> assign(:form, Phoenix.Component.to_form(ash_form, as: "bank_account"))}
  end

  # NEW / INDEX
  def handle_params(_params, _url, socket) do
    actor = socket.assigns.current_user

    ash_form =
      AshPhoenix.Form.for_create(
        Payouts.BankAccount,
        :create,
        actor: actor
      )

    {:noreply,
     socket
     |> assign(:editing_account, nil)
     |> assign(:ash_form, ash_form)
     |> assign(:form, Phoenix.Component.to_form(ash_form, as: "bank_account"))}
  end

  # SAVE (CREATE / UPDATE)
  def handle_event("save", %{"form" => params}, socket) do
    actor = socket.assigns.current_user
    church = socket.assigns.church
    editing_account = socket.assigns.editing_account

    params = Map.put(params, "church_id", church.id)

    result =
      if editing_account do
        AshPhoenix.Form.submit(
          socket.assigns.ash_form,
          params: params,
          actor: actor
        )
      else
        with {:ok, response} <- Client.create_transfer_recipient(params),
             recipient_code when not is_nil(recipient_code) <-
               get_in(response, ["data", "recipient_code"]) do

          params = Map.put(params, "recipient_code", recipient_code)

          AshPhoenix.Form.submit(
            socket.assigns.ash_form,
            params: params,
            actor: actor
          )
        else
          error ->
            {:error, error}
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
         |> push_patch(to: ~p"/admin/payouts/bank-accounts")}

      {:error, ash_form} ->
        {:noreply,
         socket
         |> assign(:ash_form, ash_form)
         |> assign(:form, Phoenix.Component.to_form(ash_form, as: "bank_account"))}

      {:error, error} ->
        IO.inspect(error, label: "SAVE ERROR")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to save bank account")}
    end
  end

  # DELETE
  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    church = socket.assigns.church

    bank_account =
      Payouts.get_bank_account!(id, actor)

    case Payouts.destroy_bank_account(bank_account, actor) do
      {:ok, _} ->
        bank_accounts =
          Payouts.BankAccount
          |> Ash.Query.filter(church_id == ^church.id)
          |> Ash.read!(actor: actor)

        {:noreply,
         socket
         |> put_flash(:info, "Bank account deleted")
         |> assign(:bank_accounts, bank_accounts)}

      {:error, error} ->
        IO.inspect(error, label: "DELETE ERROR")

        {:noreply,
         socket
         |> put_flash(:error, "Unable to delete bank account")}
    end
  end
end
