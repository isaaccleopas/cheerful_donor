defmodule CheerfulDonorWeb.Public.HomeLive do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_user do
      %{role: :admin} ->
        {:ok, redirect(socket, to: "/admin/dashboard")}

      %{role: :donor} ->
        {:ok, redirect(socket, to: "/donor/dashboard")}

      _ ->
        campaigns = Giving.list_active_campaigns_with_stats(limit: 6)

        {:ok,
         socket
         |> assign(:page_title, "Cheerful Donor")
         |> assign(:campaigns, campaigns)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.marketing flash={@flash} current_user={@current_user}>
      <%!-- Hero --%>
      <section class="relative overflow-hidden bg-base-200/60">
        <div class="mx-auto grid max-w-6xl gap-10 px-4 py-16 sm:px-6 lg:grid-cols-2 lg:items-center lg:py-24 lg:px-8">
          <div class="cd-animate-fade-up">
            <p class="text-sm font-semibold uppercase tracking-widest text-primary">
              Church fundraising made simple
            </p>
            <h1 class="font-display mt-3 text-4xl font-semibold leading-tight tracking-tight text-base-content sm:text-5xl">
              Where meaningful campaigns find generous hearts
            </h1>
            <p class="mt-4 max-w-lg text-lg text-base-content/70">
              Discover causes you care about, give in minutes, and track the impact — trusted crowdfunding for churches and communities.
            </p>
            <div class="mt-8 flex flex-col gap-3 sm:flex-row">
              <.link
                navigate={~p"/campaigns"}
                class="cd-cta inline-flex min-h-12 items-center justify-center rounded-xl bg-primary px-6 text-base font-semibold text-primary-content shadow-md hover:brightness-110"
              >
                Explore campaigns
              </.link>
              <.link
                navigate={~p"/register"}
                class="cd-cta inline-flex min-h-12 items-center justify-center rounded-xl border border-base-300 bg-base-100 px-6 text-base font-semibold text-base-content hover:bg-base-200"
              >
                Start a campaign
              </.link>
            </div>
            <div class="mt-8">
              <.trust_strip />
            </div>
          </div>

          <div class="cd-animate-fade-up cd-animate-delay-1 relative hidden lg:block">
            <img
              src={~p"/images/hero-sanctuary.jpg"}
              alt=""
              class="aspect-[4/3] w-full rounded-2xl object-cover shadow-xl"
            />
            <div class="absolute -bottom-4 -left-4 rounded-xl border border-base-300 bg-base-100 p-4 shadow-lg">
              <p class="text-xs uppercase tracking-wide text-base-content/50">Trusted giving</p>
              <p class="font-display text-lg font-semibold text-primary">
                Secure · Simple · Transparent
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- Featured campaigns --%>
      <section class="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:px-8">
        <div class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 class="font-display text-2xl font-semibold text-base-content sm:text-3xl">
              Discover campaigns
            </h2>
            <p class="mt-2 text-base-content/65">
              Support active fundraisers in your community
            </p>
          </div>
          <.link
            navigate={~p"/campaigns"}
            class="text-sm font-semibold text-primary hover:underline"
          >
            View all →
          </.link>
        </div>

        <%= if Enum.empty?(@campaigns) do %>
          <div class="rounded-2xl border border-dashed border-base-300 bg-base-200/40 px-6 py-16 text-center">
            <p class="font-display text-xl font-semibold text-base-content">No campaigns yet</p>
            <p class="mt-2 text-base-content/60">
              Be the first to start fundraising for your church.
            </p>
            <.link
              navigate={~p"/register"}
              class="cd-cta mt-6 inline-flex min-h-11 items-center rounded-xl bg-primary px-5 text-sm font-semibold text-primary-content"
            >
              Start a campaign
            </.link>
          </div>
        <% else %>
          <ul class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <%= for item <- @campaigns do %>
              <li>
                <.campaign_card
                  campaign={item.campaign}
                  raised={item.raised}
                  donor_count={item.donor_count}
                  href={~p"/donate/#{item.campaign.slug}"}
                />
              </li>
            <% end %>
          </ul>
        <% end %>
      </section>

      <%!-- How it works --%>
      <section class="border-t border-base-300/60 bg-base-200/40">
        <div class="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:px-8">
          <h2 class="font-display text-center text-2xl font-semibold sm:text-3xl">How it works</h2>
          <ol class="mt-10 grid grid-cols-1 gap-8 md:grid-cols-3">
            <li class="text-center">
              <span class="mx-auto flex size-10 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-content">
                1
              </span>
              <h3 class="mt-4 font-semibold">Find a cause</h3>
              <p class="mt-2 text-sm text-base-content/65">
                Browse campaigns and read the story behind each need.
              </p>
            </li>
            <li class="text-center">
              <span class="mx-auto flex size-10 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-content">
                2
              </span>
              <h3 class="mt-4 font-semibold">Choose your gift</h3>
              <p class="mt-2 text-sm text-base-content/65">
                Pick an amount or enter your own — one-time or recurring.
              </p>
            </li>
            <li class="text-center">
              <span class="mx-auto flex size-10 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-content">
                3
              </span>
              <h3 class="mt-4 font-semibold">Give securely</h3>
              <p class="mt-2 text-sm text-base-content/65">
                Complete checkout with Paystack and see your impact grow.
              </p>
            </li>
          </ol>
        </div>
      </section>
    </Layouts.marketing>
    """
  end
end
