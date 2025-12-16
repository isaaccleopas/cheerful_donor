defmodule CheerfulDonorWeb.Router do
  use CheerfulDonorWeb, :router

  import Oban.Web.Router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CheerfulDonorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :paystack_webhook do
    plug :accepts, ["json"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  # ------------------------------
  # 🔹 AUTHENTICATED LIVEVIEW AREA
  # ------------------------------
  scope "/", CheerfulDonorWeb do
    pipe_through :browser

    live_session :donor_auth,
      on_mount: [
        {CheerfulDonorWeb.LiveUserAuth, :current_user},
        {CheerfulDonorWeb.LiveUserAuth, :live_user_required}
      ] do

      # donor routes
      live "/donor/dashboard", DonorDashboardLive
      live "/donate", DonateLive

      # admin routes
      live "/admin/dashboard", AdminDashboardLive
    end

    # ash_authentication_live_session :authenticated_routes do
    #   # Require logged-in user unless otherwise configured in LV
    #   live "/donor/dashboard", DonorDashboardLive, :show
    #   live "/donate", DonateLive, :index
    # end
  end

  # ------------------------------
  # 🔹 MAIN SITE ROUTES
  # ------------------------------
  scope "/", CheerfulDonorWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{CheerfulDonorWeb.LiveUserAuth, :current_user}] do

      live "/", HomeLive, :index
    end
    
    get "/paystack/callback", PaystackCallbackController, :handle
    get "/paystack/verify", VerifyController, :handle

    auth_routes AuthController, CheerfulDonor.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{CheerfulDonorWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    CheerfulDonorWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  CheerfulDonorWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    confirm_route CheerfulDonor.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [
        CheerfulDonorWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]

    magic_sign_in_route(CheerfulDonor.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [
        CheerfulDonorWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]
    )
  end

  # -----------------------------------------
  # 🔹 PAYSTACK WEBHOOK (PRODUCTION ENABLED!)
  # -----------------------------------------

  scope "/paystack", CheerfulDonorWeb do
    pipe_through :paystack_webhook
    post "/webhook", PaystackWebhookController, :handle
  end

  # ------------------------------
  # 🔹 DEV-ONLY ROUTES
  # ------------------------------
  if Application.compile_env(:cheerful_donor, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CheerfulDonorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end

  # Admin (AshAdmin)
  if Application.compile_env(:cheerful_donor, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
