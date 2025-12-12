# defmodule CheerfulDonorWeb.DonationLive.FormComponent do
#   use CheerfulDonorWeb, :live_component
#   alias CheerfulDonor.Giving

#   def update(assigns, socket) do
#     changeset = Giving.change_donation(assigns.donation)

#     {:ok,
#      socket
#      |> assign(assigns)
#      |> assign(:changeset, changeset)}
#   end

#   def handle_event("validate", %{"donation" => params}, socket) do
#     changeset =
#       socket.assigns.donation
#       |> Giving.change_donation(params)
#       |> Map.put(:action, :validate)

#     {:noreply, assign(socket, :changeset, changeset)}
#   end

#   def handle_event("save", %{"donation" => params}, socket) do
#     save(socket, socket.assigns.live_action, params)
#   end

#   defp save(socket, :new, params) do
#     case Giving.create_donation(params) do
#       {:ok, donation} ->
#         notify_parent({:saved, donation})
#         {:noreply, push_navigate(socket, to: socket.assigns.return_to)}

#       {:error, changeset} ->
#         {:noreply, assign(socket, :changeset, changeset)}
#     end
#   end

#   defp save(socket, :edit, params) do
#     case Giving.update_donation(socket.assigns.donation, params) do
#       {:ok, donation} ->
#         notify_parent({:saved, donation})
#         {:noreply, push_navigate(socket, to: socket.assigns.return_to)}

#       {:error, changeset} ->
#         {:noreply, assign(socket, :changeset, changeset)}
#     end
#   end

#   def render(assigns) do
#     ~H"""
#     <div>
#       <.modal show id="donation-modal">
#         <.simple_form
#           for={@changeset}
#           phx-change="validate"
#           phx-submit="save"
#         >
#           <.input field={@changeset[:amount]} label="Amount" type="number" />
#           <.input field={@changeset[:currency]} label="Currency" />
#           <.input field={@changeset[:message]} label="Message" />

#           <.input
#             field={@changeset[:status]}
#             type="select"
#             label="Status"
#             options={CheerfulDonor.Enums.donation_statuses()}
#           />

#           <.input field={@changeset[:reference]} label="Reference" />

#           <.button class="btn btn-primary w-full mt-4">Save Donation</.button>
#         </.simple_form>
#       </.modal>
#     </div>
#     """
#   end
# end
