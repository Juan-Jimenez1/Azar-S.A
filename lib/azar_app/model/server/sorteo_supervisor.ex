defmodule AzarApp.SorteoSupervisor do
  @moduledoc """
  Supervisor dinámico que administra los procesos `SorteoServer`.

  Se crea un hijo `SorteoServer` por cada sorteo existente o recién creado.
  La estrategia `:one_for_one` garantiza que un crash en un sorteo no afecta
  a los demás. Al arrancar la aplicación, `cargar_sorteos/0` inicia un proceso
  para cada sorteo persistido en `JsonStore`.
  """

  use DynamicSupervisor
  alias AzarApp.{JsonStore, SorteoServer}

  @doc "Inicia el supervisor dinámico con nombre `AzarApp.SorteoSupervisor`."
  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Lanza un nuevo proceso `SorteoServer` para el `sorteo_id` dado."
  def start_sorteo(sorteo_id) do
    DynamicSupervisor.start_child(__MODULE__, {SorteoServer, sorteo_id})
  end

  @doc "Carga todos los sorteos desde `JsonStore` e inicia un `SorteoServer` por cada uno. Llamado al iniciar la aplicación."
  def cargar_sorteos do
    JsonStore.all(:sorteos)
    |> Enum.each(fn sorteo -> start_sorteo(sorteo.id) end)  # .id en vez de ["id"]
  end
end
