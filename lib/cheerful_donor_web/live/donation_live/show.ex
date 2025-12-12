# defmodule CheerfulDonorWeb.DonationLive.Show do
#   use CheerfulDonorWeb, :live_view
#   alias CheerfulDonor.Giving

#   def mount(_params, _session, socket), do: {:ok, socket}

#   def handle_params(%{"id" => id}, _, socket) do
#     donation = Giving.get_donation!(id)

#     {:noreply,
#      socket
#      |> assign(:donation, donation)
#      |> assign(:page_title, "Donation Details")}
#   end

#   def render(assigns) do
#     ~H"""
#     <div class="space-y-4">
#       <h1 class="text-2xl font-bold">Donation</h1>

#       <div class="bg-white p-4 shadow rounded">
#         <p><b>Amount:</b> <%= @donation.amount %> <%= @donation.currency %></p>
#         <p><b>Status:</b> <%= @donation.status %></p>
#         <p><b>Reference:</b> <%= @donation.reference %></p>
#         <p><b>Message:</b> <%= @donation.message %></p>
#       </div>

#       <.link patch={~p"/donations/#{@donation.id}/show/edit"} class="btn btn-primary">
#         Edit Donation
#       </.link>
#     </div>
#     """
#   end
# end
