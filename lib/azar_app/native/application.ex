defmodule AzarApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AzarAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:azar_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AzarApp.PubSub},
      {Registry, keys: :unique, name: AzarApp.Registry},
      # Start a worker by calling: AzarApp.Worker.start_link(arg)
      # {AzarApp.Worker, arg},
      # Start to serve requests, typically the last entry
      AzarApp.Sorteo.Scheduler,
      AzarAppWeb.Endpoint,
      {Registry, keys: :unique, name: AzarApp.SorteoRegistry},
      AzarApp.SorteoSupervisor,
      AzarApp.Logger
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AzarApp.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      AzarApp.SorteoSupervisor.cargar_sorteos()
      {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AzarAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
