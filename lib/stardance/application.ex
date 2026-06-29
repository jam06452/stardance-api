defmodule Stardance.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StardanceWeb.Telemetry,
      Stardance.Repo,
      {DNSCluster, query: Application.get_env(:stardance, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Stardance.PubSub},
      # Start a worker by calling: Stardance.Worker.start_link(arg)
      # {Stardance.Worker, arg},
      # Start to serve requests, typically the last entry
      StardanceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Stardance.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StardanceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
