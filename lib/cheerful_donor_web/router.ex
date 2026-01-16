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

  scope "/", CheerfulDonorWeb.Public do
    pipe_through :browser

    live_session :public,
      on_mount: [
        {CheerfulDonorWeb.LiveUserAuth, :current_user}
      ] do

      live "/", HomeLive, :index
      live "/donate/:slug", DonateLive.Show
      live "/donate/:slug/checkout", DonateLive.Checkout
      live "/donate/success/:reference", DonateLive.Success
      live "/register", AuthLive.Index, :register
      live "/sign-in", AuthLive.Index, :sign_in
    end
  end

  scope "/donor", CheerfulDonorWeb.Donor do
    pipe_through :browser

    live_session :donor,
      on_mount: [
        {CheerfulDonorWeb.LiveUserAuth, :current_user},
        {CheerfulDonorWeb.LiveUserAuth, :live_user_required},
        {CheerfulDonorWeb.DonorLiveAuth, :default}
      ] do

      live "/dashboard", DashboardLive, :index
      live "/donations", DonationsLive, :index
      live "/subscriptions", SubscriptionsLive, :index
      live "/transactions", TransactionsLive, :index
      live "/payment-methods", PaymentMethodsLive, :index
      # live "/donate", DonateLive
    end
  end

  scope "/admin", CheerfulDonorWeb.Admin do
    pipe_through :browser

    live_session :admin,
      on_mount: [
        {CheerfulDonorWeb.LiveUserAuth, :current_user},
        {CheerfulDonorWeb.LiveUserAuth, :live_user_required},
        {CheerfulDonorWeb.AdminLiveAuth, :default}
      ] do

      live "/dashboard", DashboardLive, :index

      live "/church/new", ChurchLive.New
      live "/church/edit", ChurchLive.Edit

      live "/bank-accounts", BankAccountLive.Index

      live "/campaigns", CampaignLive.Index
      live "/campaigns/new", CampaignLive.New
      live "/campaigns/:id/edit", CampaignLive.Edit

      live "/donations", DonationsLive.Index
      live "/payouts", PayoutsLive.Index
      
      # live "/admin/dashbord", AdminDashboardLive, :index
      # live "/admin/church/new", AdminChurchLive, :new
      # live "/admin/campaigns", AdminCampaignsLive, :index
      # live "/admin/campaigns/new", AdminCampaignLive, :new
      # live "/admin/payout/setup", AdminPayoutSetupLive, :new
    end
  end

  scope "/", CheerfulDonorWeb do
    pipe_through :browser

    get "/paystack/callback", PaystackCallbackController, :handle
    get "/paystack/verify", VerifyController, :handle

    auth_routes AuthController, CheerfulDonor.Accounts.User, path: "/auth"
    sign_out_route AuthController

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

    scope "/system" do
      pipe_through :browser

      ash_admin "/admin"
    end
  end
end
