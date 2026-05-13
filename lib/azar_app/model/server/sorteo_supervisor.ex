defmodule AzarApp.SorteoSupervisor do
  @moduledoc """
  Supervisor dinámico. Arranca un SorteoServer por cada sorteo
  existente en disco al iniciar, y permite agregar nuevos en runtime.
  """

  use DynamicSupervisor
  alias AzarApp.{JsonStore, SorteoServer}

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Arranca un SorteoServer para un sorteo dado."
  def start_sorteo(sorteo_id) do
    DynamicSupervisor.start_child(__MODULE__, {SorteoServer, sorteo_id})
  end

  @doc "Arranca un SorteoServer por cada sorteo en disco. Llamado al iniciar la app."
  def cargar_sorteos do
    JsonStore.all(:sorteos)
    |> Enum.each(fn %{"id" => id} -> start_sorteo(id) end)
  end
end
