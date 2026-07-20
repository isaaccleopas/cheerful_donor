defmodule CheerfulDonorWeb.Layouts do
  @moduledoc """
  Application layouts for marketing, donor, and admin surfaces.
  """
  use CheerfulDonorWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_user, :map, default: nil
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    marketing(assigns)
  end

  attr :flash, :map, required: true
  attr :current_user, :map, default: nil
  slot :inner_block, required: true

  def marketing(assigns) do
    ~H"""
    <div class="min-h-dvh flex flex-col bg-base-100 text-base-content">
      <header class="sticky top-0 z-40 border-b-2 border-base-300 bg-base-100/95 backdrop-blur-md">
        <div class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <.link
            navigate={~p"/"}
            class="font-display text-xl font-bold tracking-tight text-primary cd-nav-link"
          >
            Cheerful Donor
          </.link>

          <nav class="flex items-center gap-2 sm:gap-3">
            <.link
              navigate={~p"/campaigns"}
              class="cd-nav-link hidden text-sm font-semibold text-base-content/85 hover:text-primary md:inline"
            >
              Explore
            </.link>
            <.theme_toggle />
            <%= if @current_user do %>
              <.link
                href={~p"/sign-out"}
                class="cd-nav-link text-sm font-medium text-base-content/70 hover:text-error"
              >
                Sign out
              </.link>
            <% else %>
              <.link
                navigate={~p"/register"}
                class="cd-nav-link hidden text-sm font-medium text-base-content/80 hover:text-primary sm:inline"
              >
                Start a campaign
              </.link>
              <.link
                navigate={~p"/sign-in"}
                class="cd-nav-link hidden text-sm font-medium text-base-content/80 hover:text-primary sm:inline"
              >
                Sign in
              </.link>
              <.link
                navigate={~p"/campaigns"}
                class="cd-cta inline-flex min-h-11 items-center rounded-xl bg-primary px-4 text-sm font-semibold text-primary-content shadow-sm hover:brightness-110"
              >
                Donate
              </.link>
            <% end %>
          </nav>
        </div>
      </header>

      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t-2 border-base-300 py-8 text-center text-sm text-base-content/70">
        <p class="font-display text-base font-semibold text-base-content">Cheerful Donor</p>
        <p class="mt-1 font-medium">Give freely. Support what matters.</p>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :current_user, :map, default: nil
  slot :inner_block, required: true

  def donor(assigns) do
    ~H"""
    <div class="min-h-dvh flex flex-col bg-base-100 text-base-content">
      <header class="sticky top-0 z-40 border-b-2 border-base-300 bg-base-100/95 backdrop-blur-md">
        <div class="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:px-6 lg:px-8">
          <.link
            navigate={~p"/donor/dashboard"}
            class="font-display text-lg font-bold text-primary cd-nav-link sm:text-xl"
          >
            Cheerful Donor
          </.link>

          <nav class="flex items-center gap-2 sm:gap-4">
            <.link
              navigate={~p"/donor/campaigns"}
              class="cd-nav-link text-sm font-semibold text-base-content/85 hover:text-primary"
            >
              Campaigns
            </.link>
            <.link
              navigate={~p"/donor/dashboard"}
              class="cd-nav-link hidden text-sm font-semibold text-base-content/85 hover:text-primary sm:inline"
            >
              Dashboard
            </.link>
            <.theme_toggle />
            <.link
              href={~p"/sign-out"}
              class="cd-nav-link text-sm font-medium text-base-content/70 hover:text-error"
            >
              Sign out
            </.link>
          </nav>
        </div>
      </header>

      <main class="mx-auto w-full max-w-6xl flex-1 px-4 py-6 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :current_user, :map, default: nil
  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <div class="min-h-dvh flex flex-col bg-base-100 text-base-content">
      <header class="sticky top-0 z-40 border-b-2 border-base-300 bg-base-100/95 backdrop-blur-md">
        <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3 sm:px-6 lg:px-8">
          <.link
            navigate={~p"/admin/dashboard"}
            class="font-display text-lg font-bold text-primary cd-nav-link sm:text-xl"
          >
            Cheerful Donor
            <span class="ml-1 text-xs font-sans font-bold uppercase tracking-wider text-base-content/60">
              Admin
            </span>
          </.link>

          <nav class="flex flex-wrap items-center gap-2 sm:gap-3">
            <.link
              navigate={~p"/admin/dashboard"}
              class="cd-nav-link text-sm font-semibold text-base-content/85 hover:text-primary"
            >
              Dashboard
            </.link>
            <.link
              navigate={~p"/admin/campaigns"}
              class="cd-nav-link text-sm font-semibold text-base-content/85 hover:text-primary"
            >
              Campaigns
            </.link>
            <.link
              navigate={~p"/admin/payouts"}
              class="cd-nav-link text-sm font-semibold text-base-content/85 hover:text-primary"
            >
              Payouts
            </.link>
            <.link
              navigate={~p"/admin/payouts/bank-accounts"}
              class="cd-nav-link hidden text-sm font-semibold text-base-content/85 hover:text-primary md:inline"
            >
              Banks
            </.link>
            <.theme_toggle />
            <.link
              href={~p"/sign-out"}
              class="cd-nav-link text-sm font-medium text-base-content/70 hover:text-error"
            >
              Sign out
            </.link>
          </nav>
        </div>
      </header>

      <main class="mx-auto w-full max-w-6xl flex-1 px-4 py-6 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center rounded-full border border-base-300 bg-base-200 transition-colors duration-200">
      <div class="absolute h-full w-1/3 rounded-full border border-base-300 bg-base-100 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left] duration-200" />

      <button
        type="button"
        class="relative z-10 flex min-h-9 min-w-9 cursor-pointer items-center justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        type="button"
        class="relative z-10 flex min-h-9 min-w-9 cursor-pointer items-center justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        type="button"
        class="relative z-10 flex min-h-9 min-w-9 cursor-pointer items-center justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
