defmodule AzarApp.Logger do
  @log_dir  "priv/logs"
  @log_file "priv/logs/bitacora.log"
  @max_mem  500

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def registrar(entrada) do
    GenServer.cast(__MODULE__, {:registrar, entrada})
  end

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
