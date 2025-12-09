defmodule CheerfulDonor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CheerfulDonorWeb.Telemetry,
      CheerfulDonor.Repo,
      {DNSCluster, query: Application.get_env(:cheerful_donor, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:cheerful_donor, :ash_domains),
         Application.fetch_env!(:cheerful_donor, Oban)
       )},
      {Phoenix.PubSub, name: CheerfulDonor.PubSub},
      # Start a worker by calling: CheerfulDonor.Worker.start_link(arg)
      # {CheerfulDonor.Worker, arg},
      # Start to serve requests, typically the last entry
      CheerfulDonorWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :cheerful_donor]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CheerfulDonor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CheerfulDonorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
