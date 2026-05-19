defmodule AzarApp.Bitacora do
  @moduledoc """
  GenServer que serializa todas las escrituras al archivo de log.
  Al ser un proceso único, evita condiciones de carrera al escribir
  en el archivo desde múltiples procesos concurrentes.
  """
  use GenServer

  @log_dir  "priv/logs"
  @log_file "bitacora.log"

  # ── API pública ──────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Envía una línea al log de forma asíncrona (no bloquea al llamador)."
  def escribir(linea) when is_binary(linea) do
    GenServer.cast(__MODULE__, {:escribir, linea})
  end

  # ── Callbacks ────────────────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    File.mkdir_p!(@log_dir)
    {:ok, Path.join(@log_dir, @log_file)}
  end

  @impl true
  def handle_cast({:escribir, linea}, path) do
    IO.write(:stderr, linea)
    File.write!(path, linea, [:append])
    {:noreply, path}
  end
end
