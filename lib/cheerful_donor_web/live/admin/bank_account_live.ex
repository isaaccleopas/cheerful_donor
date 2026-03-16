# defmodule CheerfulDonorWeb.Admin.BankAccountLive do
#   use CheerfulDonorWeb, :live_view

#   require Ash.Query
#   alias CheerfulDonor.Payouts
#   alias CheerfulDonor.Accounts
#   alias CheerfulDonor.Paystack.Client

#   @impl true
#   def mount(_params, _session, socket) do
#     actor = socket.assigns.current_user
#     {:ok, church} = Payouts.get_church(actor)

#     ash_form =
#       AshPhoenix.Form.for_create(
#         Payouts.BankAccount,
#         :create,
#         actor: actor
#       )

#     phoenix_form =
#       Phoenix.Component.to_form(
#         ash_form,
#         as: "bank_account"
#       )

#     {:ok,
#      socket
#      |> assign(:church, church)
#      |> assign(:ash_form, ash_form)
#      |> assign(:form, phoenix_form)}
#   end

#   @impl true
#   def handle_event("save", %{"form" => params}, socket) do
#     actor = socket.assigns.current_user
#     church = socket.assigns.church

#     params = Map.put(params, "church_id", church.id)

#     with {:ok, response} <- Client.create_transfer_recipient(params),
#         recipient_code <- response["data"]["recipient_code"],
#         params <- Map.put(params, "recipient_code", recipient_code),
#         {:ok, _bank_account} <-
#           AshPhoenix.Form.submit(socket.assigns.ash_form,
#             params: params,
#             actor: actor
#           ) do
#       {:noreply,
#       socket
#       |> put_flash(:info, "Bank account added successfully")
#       |> push_navigate(to: ~p"/admin/dashboard")}
#     else
#       {:error, ash_form} ->
#         {:noreply,
#         socket
#         |> assign(:ash_form, ash_form)
#         |> assign(:form, Phoenix.Component.to_form(ash_form))}

#       {:error, reason} ->
#         {:noreply,
#         socket
#         |> put_flash(:error, "Failed to create Paystack recipient")
#         |> IO.inspect(reason)}
#     end
#   end
# end
