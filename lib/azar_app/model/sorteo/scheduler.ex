defmodule AzarApp.Sorteo.Scheduler do
  use GenServer
  require Logger

  @intervalo :timer.minutes(1) # revisa cada minuto

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
