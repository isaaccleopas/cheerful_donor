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

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", CheerfulDonorWeb do
    pipe_through :browser

    live_session :donor_auth,
      on_mount: [
        {CheerfulDonorWeb.LiveUserAuth, :current_user},
        {CheerfulDonorWeb.LiveUserAuth, :live_user_required}
      ] do

      # Donor Dashboard & Donation Pages
      live "/donor/dashboard", DonorDashboardLive
      live "/donate", DonateLive

      # Admin Dashboard
      live "/admin", AdminDashboardLive
    end

  end

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

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{CheerfulDonorWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    CheerfulDonorWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  CheerfulDonorWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route CheerfulDonor.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [
        CheerfulDonorWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(CheerfulDonor.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [
        CheerfulDonorWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", CheerfulDonorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:cheerful_donor, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
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

  if Application.compile_env(:cheerful_donor, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
