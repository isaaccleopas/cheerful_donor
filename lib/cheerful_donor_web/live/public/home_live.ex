defmodule CheerfulDonorWeb.Public.HomeLive do
  use CheerfulDonorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_user do
      %{role: :admin} ->
        {:ok, redirect(socket, to: "/admin/dashboard")}

      %{role: :donor} ->
        {:ok, redirect(socket, to: "/donor/dashboard")}

      _ ->
        {:ok, assign(socket, :page_title, "Cheerful Donor")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.marketing flash={@flash} current_user={@current_user}>
      <section class="relative isolate min-h-[calc(100dvh-4.5rem)] overflow-hidden">
        <img
          src={~p"/images/hero-sanctuary.jpg"}
          alt=""
          class="absolute inset-0 size-full object-cover cd-animate-fade-in"
        />
        <div class="absolute inset-0 bg-gradient-to-t from-base-100 via-base-100/75 to-base-100/30 dark:from-base-100 dark:via-base-100/80 dark:to-base-100/40" />

        <div class="relative mx-auto flex min-h-[calc(100dvh-4.5rem)] max-w-6xl flex-col justify-end px-4 pb-16 pt-28 sm:px-6 sm:pb-24 lg:px-8">
          <p class="font-display cd-animate-fade-up text-4xl font-semibold tracking-tight text-primary sm:text-5xl lg:text-6xl">
            Cheerful Donor
          </p>
          <h1 class="cd-animate-fade-up cd-animate-delay-1 mt-4 max-w-xl text-2xl font-medium leading-snug text-base-content sm:text-3xl">
            Give freely to the causes your community holds dear.
          </h1>
          <p class="cd-animate-fade-up cd-animate-delay-2 mt-3 max-w-md text-base text-base-content/75 sm:text-lg">
            Secure, simple donations for churches and the people who support them.
          </p>
          <div class="cd-animate-fade-up cd-animate-delay-3 mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
            <.link
              navigate={~p"/campaigns"}
              class="cd-cta inline-flex min-h-12 items-center justify-center rounded-lg bg-primary px-6 text-base font-semibold text-primary-content shadow-md hover:brightness-110"
            >
              Browse campaigns
            </.link>
            <%= if @current_user do %>
              <.link
                navigate={~p"/donor/dashboard"}
                class="cd-cta inline-flex min-h-12 items-center justify-center rounded-lg border border-base-300 bg-base-100/80 px-6 text-base font-semibold text-base-content backdrop-blur hover:bg-base-200"
              >
                Your dashboard
              </.link>
            <% else %>
              <.link
                navigate={~p"/sign-in"}
                class="cd-cta inline-flex min-h-12 items-center justify-center rounded-lg border border-base-300 bg-base-100/80 px-6 text-base font-semibold text-base-content backdrop-blur hover:bg-base-200"
              >
                Sign in
              </.link>
            <% end %>
          </div>
        </div>
      </section>
    </Layouts.marketing>
    """
  end
end
