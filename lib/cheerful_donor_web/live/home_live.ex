defmodule CheerfulDonorWeb.HomeLive do
  use CheerfulDonorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <nav class="flex justify-end p-4 bg-white shadow">
      <%= if @current_user do %>
        <a href={~p"/sign-out"}
          class="text-red-600 font-semibold hover:underline">
          Sign Out
        </a>
      <% end %>
    </nav>
    <div class="min-h-screen bg-gray-50 flex flex-col items-center justify-center px-4">
      <div class="bg-white shadow-lg rounded-xl p-8 max-w-xl w-full text-center">
        <h1 class="text-3xl font-bold text-gray-800 mb-4">
          Welcome to Cheerful Donor 💖
        </h1>

        <p class="text-gray-600 mb-6">
          Make an impact by supporting causes you care about.
        </p>

        <%= if @current_user do %>

          <.link navigate={~p"/donate"}
            class="inline-block bg-indigo-600 hover:bg-indigo-700 text-white font-semibold px-6 py-3 rounded-lg transition">
            Donate Now
          </.link>
        <% else %>
          <div class="space-y-4">
            <a href={~p"/sign-in"}
              class="block bg-indigo-600 hover:bg-indigo-700 text-white font-semibold px-6 py-3 rounded-lg transition">
              Sign In
            </a>

            <a href={~p"/register"}
              class="block border border-indigo-600 text-indigo-600 hover:bg-indigo-50 font-semibold px-6 py-3 rounded-lg transition">
              Create Account
            </a>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
