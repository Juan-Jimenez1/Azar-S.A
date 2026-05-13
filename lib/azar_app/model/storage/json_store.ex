defmodule AzarApp.JsonStore do
  @moduledoc """
  Persistencia genérica en JSON. Cada entidad tiene su propio archivo.
  Uso:
    JsonStore.all(:sorteos)
    JsonStore.get(:clientes, "doc_123")
    JsonStore.upsert(:apuestas, apuesta)
    JsonStore.delete(:sorteos, "sorteo_001")
  """

  @data_dir Application.app_dir(:azar_app, "priv/data")

  # Mapea átomo -> nombre de archivo y clave raíz del JSON
  @entidades %{
    sorteos:  %{archivo: "sorteos.json",  clave: "sorteos"},
    clientes: %{archivo: "clientes.json", clave: "clientes"},
    usuarios: %{archivo: "usuarios.json", clave: "usuarios"}
  }

  # ── Lectura ────────────────────────────────────────────────────────────────

  @doc "Devuelve todos los registros de una entidad."
  @spec all(atom()) :: list(map())
  def all(entidad) do
    %{archivo: archivo, clave: clave} = config!(entidad)
    path = Path.join(@data_dir, archivo)

    case File.read(path) do
      {:ok, raw}        -> raw |> Jason.decode!() |> Map.get(clave, [])
      {:error, :enoent} -> []
      {:error, reason}  -> raise "Error leyendo #{path}: #{inspect(reason)}"
    end
  end

  @doc "Busca un registro por id. Devuelve {:ok, registro} | :error."
  @spec get(atom(), String.t()) :: {:ok, map()} | :error
  def get(entidad, id) do
    case Enum.find(all(entidad), &(&1["id"] == id)) do
      nil      -> :error
      registro -> {:ok, registro}
    end
  end

  @doc "Filtra registros por una clave y valor."
  @spec filter(atom(), String.t(), any()) :: list(map())
  def filter(entidad, clave, valor) do
    Enum.filter(all(entidad), &(&1[clave] == valor))
  end

  # ── Escritura ──────────────────────────────────────────────────────────────

  @doc "Inserta o reemplaza un registro (match por 'id'). Persiste en disco."
  @spec upsert(atom(), map()) :: :ok
  def upsert(entidad, registro) do
    registros = all(entidad)

    nuevos =
      case Enum.find_index(registros, &(&1["id"] == registro["id"])) do
        nil   -> registros ++ [registro]
        index -> List.replace_at(registros, index, registro)
      end

    save(entidad, nuevos)
  end

  @doc "Elimina un registro por id."
  @spec delete(atom(), String.t()) :: :ok | {:error, String.t()}
  def delete(entidad, id) do
    registros = all(entidad)

    case Enum.find(registros, &(&1["id"] == id)) do
      nil -> {:error, "Registro no encontrado"}
      _   -> save(entidad, Enum.reject(registros, &(&1["id"] == id)))
    end
  end

  # ── Utilidades ─────────────────────────────────────────────────────────────

  @doc "Genera un id único con prefijo. Ej: generar_id('sorteo') => 'sorteo_1714000000123456'"
  @spec generar_id(String.t()) :: String.t()
  def generar_id(prefijo) do
    "#{prefijo}_#{System.system_time(:microsecond)}"
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp save(entidad, registros) do
    %{archivo: archivo, clave: clave} = config!(entidad)
    path     = Path.join(@data_dir, archivo)
    tmp_path = path <> ".tmp"

    File.mkdir_p!(@data_dir)
    File.write!(tmp_path, Jason.encode!(%{clave => registros}, pretty: true))
    File.rename!(tmp_path, path)
    :ok
  end

  defp config!(entidad) do
    Map.get(@entidades, entidad) ||
      raise "Entidad desconocida: #{inspect(entidad)}. Válidas: #{inspect(Map.keys(@entidades))}"
  end
end
