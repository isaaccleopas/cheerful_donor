defmodule CheerfulDonorWeb.Public.AuthLive.Index do
  use CheerfulDonorWeb, :live_view

  alias CheerfulDonor.Accounts
  alias CheerfulDonor.Accounts.User
  alias AshPhoenix.Form

  @impl true
  def mount(_, _, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :register, _params) do
    socket
    |> assign(:page_title, "Create account")
    |> assign(:form_id, "sign-up-form")
    |> assign(:cta, "Create account")
    |> assign(:alternative_path, ~p"/sign-in")
    |> assign(:alternative, "Already have an account? Sign in")
    |> assign(:action, ~p"/auth/user/password/register")
    |> assign(
      :form,
      Form.for_create(User, :register_with_password, api: Accounts, as: "user")
      |> to_form()
    )
  end

  defp apply_action(socket, :sign_in, _params) do
    socket
    |> assign(:page_title, "Sign in")
    |> assign(:form_id, "sign-in-form")
    |> assign(:cta, "Sign in")
    |> assign(:alternative_path, ~p"/register")
    |> assign(:alternative, "Need an account? Register")
    |> assign(:action, ~p"/auth/user/password/sign_in")
    |> assign(
      :form,
      Form.for_action(User, :sign_in_with_password, api: Accounts, as: "user")
      |> to_form()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.marketing flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-md px-4 py-14 sm:px-6">
        <div class="mb-8 border-b-2 border-base-300 pb-5 text-center">
          <h1 class="cd-page-title text-3xl">
            {@cta}
          </h1>
          <p class="cd-muted mt-2 text-sm font-semibold">
            <.link
              navigate={@alternative_path}
              class="cd-nav-link font-bold text-primary hover:underline"
            >
              {@alternative}
            </.link>
          </p>
        </div>

        <.live_component
          module={CheerfulDonorWeb.Public.AuthLive.AuthForm}
          id={@form_id}
          form={@form}
          is_register?={@live_action == :register}
          action={@action}
          cta={@cta}
        />
      </div>
    </Layouts.marketing>
    """
  end
end
