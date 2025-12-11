# defmodule CheerfulDonorWeb.DonationLive.Index do
#   use CheerfulDonorWeb, :live_view
#   alias CheerfulDonor.Giving
#   alias CheerfulDonor.Giving.Donation

#   def mount(_params, _session, socket) do
#     {:ok, stream(socket, :donations, Giving.list_donations!())}
#   end

#   def handle_params(params, _url, socket) do
#     {:noreply, apply_action(socket, socket.assigns.live_action, params)}
#   end

#   defp apply_action(socket, :index, _params) do
#     socket |> assign(:page_title, "Donations") |> assign(:donation, nil)
#   end

#   defp apply_action(socket, :new, _params) do
#     socket
#     |> assign(:page_title, "New Donation")
#     |> assign(:donation, Giving.new_donation())
#   end

#   defp apply_action(socket, :edit, %{"id" => id}) do
#     socket
#     |> assign(:page_title, "Edit Donation")
#     |> assign(:donation, Giving.get_donation!(id))
#   end

#   def render(assigns) do
#     ~H"""
#     <div class="space-y-6">
#       <div class="flex justify-between items-center">
#         <h1 class="text-2xl font-bold">Donations</h1>

#         <.link patch={~p"/donations/new"} class="btn btn-primary">
#           + Create Donation
#         </.link>
#       </div>

#       <div class="bg-white p-4 shadow rounded">
#         <table class="w-full text-left">
#           <thead>
#             <tr>
#               <th>Amount</th>
#               <th>Status</th>
#               <th>Reference</th>
#               <th></th>
#             </tr>
#           </thead>

#           <tbody>
#             <%= for donation <- @streams.donations do %>
#               <tr id={donation.id}>
#                 <td><%= donation.amount %> <%= donation.currency %></td>
#                 <td><%= donation.status %></td>
#                 <td><%= donation.reference %></td>

#                 <td class="text-right space-x-4">
#                   <.link navigate={~p"/donations/#{donation.id}"} class="btn btn-sm">View</.link>
#                   <.link patch={~p"/donations/#{donation.id}/edit"} class="btn btn-sm">Edit</.link>
#                 </td>
#               </tr>
#             <% end %>
#           </tbody>
#         </table>
#       </div>

#       <%= if @live_action in [:new, :edit] do %>
#         <.live_component
#           module={CheerfulDonorWeb.DonationLive.FormComponent}
#           id="donation-form"
#           donation={@donation}
#           return_to={~p"/donations"}
#         />
#       <% end %>
#     </div>
#     """
#   end
# end
