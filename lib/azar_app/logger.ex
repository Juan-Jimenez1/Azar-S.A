defmodule AzarApp.Logger do
  @moduledoc """
  GenServer de auditoría que registra todas las peticiones HTTP del sistema.

  Escribe cada entrada en `priv/logs/bitacora.log` y mantiene en memoria las
  últimas `@max_mem` (500) entradas para consulta rápida desde el panel admin.

  Formato de cada línea:
  `[fecha] METODO /ruta → RESULTADO | ip: x.x.x.x | usuario: id_o_anónimo`

  La escritura al disco es síncrona pero no bloquea el request, porque se
  invoca como `cast` desde el plug `RequestLogger` en el callback `before_send`.
  """

  @log_dir  "priv/logs"
  @log_file "priv/logs/bitacora.log"
  @max_mem  500

  use GenServer

  @doc "Inicia el GenServer del logger con nombre `AzarApp.Logger`."
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Registra una entrada de log de forma asíncrona.

  `entrada` es un mapa con: `fecha`, `metodo`, `ruta`, `resultado`, `ip`, `usuario`.
  Persiste en disco y agrega al buffer en memoria.
  """
  def registrar(entrada) do
    GenServer.cast(__MODULE__, {:registrar, entrada})
  end

  @doc "Retorna las últimas 500 entradas del log ordenadas de más reciente a más antigua."
  def all do
    GenServer.call(__MODULE__, :all)
  end

  # ── Init ──────────────────────────────────────────────────────────────────

  @impl true
  def init(_) do
    File.mkdir_p!(@log_dir)
    {:ok, []}
  end

  # ── Callbacks ─────────────────────────────────────────────────────────────

  @impl true
  def handle_cast({:registrar, entrada}, state) do
    linea = formatear(entrada)
    File.write!(@log_file, linea <> "\n", [:append])
    nuevos = Enum.take([entrada | state], @max_mem)
    {:noreply, nuevos}
  end

  @impl true
  def handle_call(:all, _from, state) do
    {:reply, state, state}
  end

  # ── Privado ───────────────────────────────────────────────────────────────

  defp formatear(e) do
    "[#{e.fecha}] #{e.metodo} #{e.ruta} → #{e.resultado} | ip: #{e.ip} | usuario: #{e.usuario}"
  end
end
