defmodule Speccy.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SpeccyWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:speccy, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Speccy.PubSub},
      {Registry, keys: :unique, name: Speccy.Workspace.Registry},
      {DynamicSupervisor, name: Speccy.Workspace.Supervisor},
      # Start a worker by calling: Speccy.Worker.start_link(arg)
      # {Speccy.Worker, arg},
      # Start to serve requests, typically the last entry
      SpeccyWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Speccy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SpeccyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
