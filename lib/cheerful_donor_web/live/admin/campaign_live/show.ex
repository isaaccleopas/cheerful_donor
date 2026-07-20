defmodule CheerfulDonorWeb.Admin.CampaignLive.Show do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving

  on_mount {CheerfulDonorWeb.LiveUserAuth, :current_user}
  on_mount CheerfulDonorWeb.AdminLiveAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :copied?, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    campaign = Giving.get_campaign!(id, socket.assigns.current_user)
    share_url = url(~p"/donate/#{campaign.slug}")
    share_text = "Support #{campaign.title} on Cheerful Donor"

    {:noreply,
     assign(socket,
       campaign: campaign,
       share_url: share_url,
       share_text: share_text,
       share_links: share_links(share_url, share_text),
       copied?: false
     )}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    actor = socket.assigns.current_user
    campaign = socket.assigns.campaign

    new_state = !campaign.is_active

    campaign
    |> Ash.Changeset.for_update(:update, %{is_active: new_state})
    |> Ash.update(actor: actor)

    {:noreply,
     socket
     |> assign(:campaign, %{campaign | is_active: new_state})
     |> put_flash(:info, if(new_state, do: "Campaign activated", else: "Campaign deactivated"))}
  end

  @impl true
  def handle_event("copied", _params, socket) do
    {:noreply,
     socket
     |> assign(:copied?, true)
     |> put_flash(:info, "Campaign link copied")}
  end

  defp share_links(share_url, share_text) do
    encoded_url = URI.encode_www_form(share_url)
    encoded_text = URI.encode_www_form(share_text)

    [
      %{
        id: "whatsapp",
        label: "WhatsApp",
        href: "https://wa.me/?text=#{encoded_text}%20#{encoded_url}",
        icon: "hero-chat-bubble-left-right"
      },
      %{
        id: "facebook",
        label: "Facebook",
        href: "https://www.facebook.com/sharer/sharer.php?u=#{encoded_url}",
        icon: "hero-globe-alt"
      },
      %{
        id: "x",
        label: "X",
        href: "https://twitter.com/intent/tweet?text=#{encoded_text}&url=#{encoded_url}",
        icon: "hero-hashtag"
      },
      %{
        id: "linkedin",
        label: "LinkedIn",
        href: "https://www.linkedin.com/sharing/share-offsite/?url=#{encoded_url}",
        icon: "hero-briefcase"
      },
      %{
        id: "email",
        label: "Email",
        href: "mailto:?subject=#{encoded_text}&body=#{encoded_text}%0A%0A#{encoded_url}",
        icon: "hero-envelope"
      }
    ]
  end
end
