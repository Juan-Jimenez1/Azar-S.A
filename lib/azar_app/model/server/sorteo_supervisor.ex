defmodule AzarApp.SorteoSupervisor do
  use DynamicSupervisor
  alias AzarApp.{JsonStore, SorteoServer}

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_sorteo(sorteo_id) do
    DynamicSupervisor.start_child(__MODULE__, {SorteoServer, sorteo_id})
  end

  def cargar_sorteos do
    JsonStore.all(:sorteos)
    |> Enum.each(fn sorteo -> start_sorteo(sorteo.id) end)  # .id en vez de ["id"]
  end
end
