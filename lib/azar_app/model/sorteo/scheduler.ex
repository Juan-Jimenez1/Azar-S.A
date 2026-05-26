defmodule AzarApp.Sorteo.Scheduler do
  @moduledoc """
  GenServer que ejecuta automáticamente los sorteos con fecha vencida.

  Se activa cada minuto (configurable vía `@intervalo`) y busca sorteos cuya
  `fecha` (en formato ISO 8601) sea anterior a la fecha actual en Colombia
  (`America/Bogota`) y que aún no hayan sido realizados. Por cada uno invoca
  `SorteoServer.ejecutar/1` y registra el resultado en el log de Elixir.
  """

  use GenServer
  require Logger

  @intervalo :timer.minutes(1)

  @doc "Inicia el GenServer del scheduler con nombre `AzarApp.Sorteo.Scheduler`."
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.info("[Scheduler] Iniciado — revisando sorteos cada minuto")
    schedule()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:revisar, estado) do
    revisar_sorteos_pendientes()
    schedule()
    {:noreply, estado}
  end

  defp revisar_sorteos_pendientes do
    hoy =
      DateTime.now!("America/Bogota")
      |> DateTime.to_date()

    AzarApp.JsonStore.all(:sorteos)
    |> Enum.filter(fn sorteo ->
      case Date.from_iso8601(sorteo.fecha) do
        {:ok, fecha} ->
          !sorteo.realizado and Date.compare(fecha, hoy) == :lt

        _ ->
          false
      end
    end)
    |> Enum.each(fn sorteo ->
      Logger.info("[Scheduler] Ejecutando sorteo automático: #{sorteo.nombre}")

      case AzarApp.SorteoServer.ejecutar(sorteo.id) do
        {:ok, ganador} ->
          Logger.info(
            "[Scheduler] Sorteo #{sorteo.nombre} ejecutado — ganador: ##{ganador}"
          )

        {:error, motivo} ->
          Logger.warning(
            "[Scheduler] Error ejecutando #{sorteo.nombre}: #{motivo}"
          )
      end
    end)
  end

  defp schedule do
    Process.send_after(self(), :revisar, @intervalo)
  end
end
