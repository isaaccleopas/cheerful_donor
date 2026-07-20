defmodule CheerfulDonorWeb.CampaignComponents do
  @moduledoc """
  GoFundMe-inspired campaign UI: cards, progress, amount chips.
  """
  use Phoenix.Component
  import CheerfulDonorWeb.CoreComponents

  attr :amount, :integer, required: true
  attr :class, :string, default: nil

  def format_ngn(assigns) do
    ~H"""
    <span class={@class}>₦{format_number(@amount)}</span>
    """
  end

  attr :raised, :integer, required: true
  attr :goal, :integer, default: nil
  attr :donor_count, :integer, default: 0
  attr :compact, :boolean, default: false

  def campaign_progress(assigns) do
    assigns =
      assign(assigns, :percent, progress_percent(assigns.raised, assigns.goal))

    ~H"""
    <div class="space-y-2">
      <div class={[
        "cd-progress-track overflow-hidden rounded-full bg-base-300",
        @compact && "h-2",
        !@compact && "h-3"
      ]}>
        <div
          class="cd-progress-fill h-full rounded-full bg-primary transition-all duration-500"
          style={"width: #{@percent}%"}
        />
      </div>
      <div class={[
        "flex flex-wrap items-center justify-between gap-2 text-base-content/70",
        @compact && "text-xs",
        !@compact && "text-sm"
      ]}>
        <p>
          <span class="font-semibold text-base-content">
            <.format_ngn amount={@raised} />
          </span>
          <%= if @goal do %>
            <span> raised of <.format_ngn amount={@goal} class="font-medium" /></span>
          <% else %>
            <span> raised</span>
          <% end %>
        </p>
        <%= if @donor_count > 0 do %>
          <p>{@donor_count} {if @donor_count == 1, do: "donor", else: "donors"}</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :campaign, :map, required: true
  attr :raised, :integer, default: 0
  attr :donor_count, :integer, default: 0
  attr :href, :string, required: true

  def campaign_card(assigns) do
    assigns =
      assign(assigns, :accent, card_accent(assigns.campaign))

    ~H"""
    <article class="cd-campaign-card group flex h-full flex-col overflow-hidden rounded-2xl border-2 border-base-300 bg-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
      <div class={"relative h-40 bg-gradient-to-br #{@accent} p-5"}>
        <p class="text-xs font-bold uppercase tracking-wider text-white/85">
          {@campaign.church && @campaign.church.name}
        </p>
        <h3 class="font-display mt-2 line-clamp-2 text-xl font-bold leading-snug text-white">
          {@campaign.title}
        </h3>
      </div>
      <div class="flex flex-1 flex-col p-5">
        <p class="cd-muted line-clamp-3 flex-1 text-sm font-medium leading-relaxed">
          {@campaign.description || "Support this campaign and make a difference."}
        </p>
        <div class="mt-4 border-t-2 border-base-300 pt-4">
          <.campaign_progress
            raised={@raised}
            goal={@campaign.goal_amount}
            donor_count={@donor_count}
            compact
          />
        </div>
        <.link
          navigate={@href}
          class="cd-cta mt-5 inline-flex min-h-11 w-full items-center justify-center rounded-xl bg-primary text-sm font-semibold text-primary-content hover:brightness-110"
        >
          Donate now
        </.link>
      </div>
    </article>
    """
  end

  attr :amounts, :list, default: [1000, 2500, 5000, 10000, 25000]
  attr :selected, :any, default: nil
  attr :target, :any, default: nil

  def amount_picker(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-2 sm:grid-cols-5">
      <%= for amount <- @amounts do %>
        <button
          type="button"
          phx-click="pick_amount"
          phx-value-amount={amount}
          phx-target={@target}
          class={[
            "cd-amount-chip min-h-11 rounded-xl border-2 px-2 text-sm font-bold transition",
            to_string(@selected) == to_string(amount) &&
              "border-primary bg-primary/10 text-primary",
            to_string(@selected) != to_string(amount) &&
              "border-base-300 bg-base-100 text-base-content hover:border-primary/50 hover:bg-base-200"
          ]}
        >
          ₦{format_number(amount)}
        </button>
      <% end %>
    </div>
    """
  end

  def trust_strip(assigns) do
    ~H"""
    <ul class="flex flex-col gap-3 text-sm text-base-content/70 sm:flex-row sm:flex-wrap sm:gap-6">
      <li class="flex items-center gap-2">
        <.icon name="hero-lock-closed" class="size-4 text-primary" /> Secure Paystack checkout
      </li>
      <li class="flex items-center gap-2">
        <.icon name="hero-shield-check" class="size-4 text-primary" /> Verified church campaigns
      </li>
      <li class="flex items-center gap-2">
        <.icon name="hero-heart" class="size-4 text-primary" /> One-time or recurring gifts
      </li>
    </ul>
    """
  end

  defp format_number(amount) when is_integer(amount) do
    amount
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(_), do: "0"

  defp progress_percent(_raised, nil), do: 0

  defp progress_percent(raised, goal) when goal > 0 do
    raised
    |> Kernel./(goal)
    |> Kernel.*(100)
    |> min(100)
    |> round()
  end

  defp progress_percent(_, _), do: 0

  defp card_accent(campaign) do
    palette = [
      "from-primary/90 to-emerald-800",
      "from-teal-600 to-primary",
      "from-emerald-700 to-lime-900",
      "from-green-800 to-teal-900"
    ]

    index =
      campaign.id
      |> to_string()
      |> :erlang.phash2()
      |> rem(length(palette))

    Enum.at(palette, index)
  end
end
