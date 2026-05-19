defmodule AzarApp.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Telemetría (métricas y LiveDashboard)
      AzarAppWeb.Telemetry,

      # 2. Bitácora: se inicia primero para que esté disponible tan pronto
      #    como sea posible y loguear el arranque del resto de componentes.
      AzarApp.Bitacora,

      # 3. Cluster DNS (útil en deploy distribuido; :ignore en desarrollo)
      {DNSCluster, query: Application.get_env(:azar_app, :dns_cluster_query) || :ignore},

      # 4. PubSub para notificaciones en tiempo real (LiveView y SorteoServer)
      {Phoenix.PubSub, name: AzarApp.PubSub},

      # 5. Registry de sorteos: debe iniciar ANTES que el supervisor de sorteos
      {Registry, keys: :unique, name: AzarApp.SorteoRegistry},

      # 6. Supervisor dinámico de sorteos: cada sorteo tiene su propio GenServer
      AzarApp.SorteoSupervisor,

      # 7. Endpoint HTTP de Phoenix (última en arrancar, cuando todo está listo)
      AzarAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AzarApp.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Carga todos los sorteos existentes en JSON como procesos GenServer
      AzarApp.SorteoSupervisor.cargar_sorteos()
      {:ok, pid}
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    AzarAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
