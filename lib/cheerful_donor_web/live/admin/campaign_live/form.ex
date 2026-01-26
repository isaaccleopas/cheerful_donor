defmodule CheerfulDonorWeb.Admin.CampaignLive.Form do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.Campaign
  alias CheerfulDonor.Accounts
  alias AshPhoenix.Form

  on_mount {CheerfulDonorWeb.LiveUserAuth, :current_user}
  on_mount CheerfulDonorWeb.AdminLiveAuth

  @impl true
  def mount(_params, _session, socket) do
    # Preload the church for the current user
    user = Accounts.get_user_with_church!(socket.assigns.current_user.id, socket.assigns.current_user)

    {:ok, assign(socket, current_user: user)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :edit ->
        id = params["id"]

        if id do
          campaign = Giving.get_campaign!(id, socket.assigns.current_user)

          form =
            campaign
            |> AshPhoenix.Form.for_update(:update, domain: Giving, actor: socket.assigns.current_user)
            |> to_form()

          {:noreply,
           assign(socket,
             page_title: "Edit Campaign",
             campaign: campaign,
             form: form
           )}
        else
          {:noreply, socket |> put_flash(:error, "Campaign ID missing")}
        end

      :new ->
        form =
          Campaign
          |> AshPhoenix.Form.for_create(:create, domain: Giving, actor: socket.assigns.current_user)
          |> to_form()

        {:noreply, assign(socket, page_title: "New Campaign", form: form)}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form
      |> Form.validate(params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    # Now safe: current_user.church is preloaded
    church_id = socket.assigns.current_user.church.id

    params =
      params
      |> Map.update("is_active", false, &(&1 in ["true", true]))
      |> Map.update("goal_amount", nil, fn
        "" -> nil
        val -> String.to_integer(val)
      end)
      |> Map.put("church_id", church_id)

    case Form.submit(socket.assigns.form, actor: socket.assigns.current_user, params: params) do
      {:ok, campaign} ->
        {:noreply,
        socket
        |> put_flash(:info, "Campaign saved successfully")
        |> push_navigate(to: ~p"/admin/campaigns/#{campaign.id}")}

      {:error, form} ->
        IO.inspect(form.errors, label: "Campaign form errors")
        {:noreply, assign(socket, :form, form)}
    end
  end
end
