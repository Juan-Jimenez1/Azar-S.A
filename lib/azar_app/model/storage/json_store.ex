defmodule AzarApp.JsonStore do

  alias AzarApp.Model.Structure.{Sorteo, Cliente, Admin}

  @data_dir "priv/data"

  @entidades %{
    sorteos: %{
      archivo: "sorteos.json",
      clave: "sorteos",
      modulo: Sorteo
    },
    clientes: %{
      archivo: "clientes.json",
      clave: "clientes",
      modulo: Cliente
    },
    admins: %{
      archivo: "admins.json",
      clave: "admins",
      modulo: Admin
    }
  }

  # ── Lectura ─────────────────────────────────────────────

  def all(entidad) do
    %{archivo: archivo, clave: clave, modulo: modulo} = config!(entidad)

    path = Path.join(@data_dir, archivo)

    case File.read(path) do
      {:ok, raw} ->
        # Usamos decode/1 (sin bang) para no explotar si el archivo está corrupto.
        # Puede ocurrir si el proceso muere justo durante una escritura.
        case Jason.decode(raw) do
          {:ok, decoded} ->
            decoded
            |> Map.get(clave, [])
            |> Enum.map(&apply(modulo, :to_struct, [&1]))

          {:error, _} ->
            raise "Archivo #{path} contiene JSON inválido. Restaura el backup en #{path}.tmp si existe."
        end

      {:error, :enoent} ->
        []

      {:error, reason} ->
        raise "Error leyendo #{path}: #{inspect(reason)}"
    end
  end

  def get(entidad, id) do
    case Enum.find(all(entidad), &(&1.id == id)) do
      nil      -> :error
      registro -> {:ok, registro}
    end
  end

  # ── Escritura ───────────────────────────────────────────

  def upsert(entidad, registro) do
    registros = all(entidad)

    nuevos =
      case Enum.find_index(registros, &(&1.id == registro.id)) do
        nil   -> registros ++ [registro]
        index -> List.replace_at(registros, index, registro)
      end

    maps = Enum.map(nuevos, fn r -> apply(r.__struct__, :to_map, [r]) end)
    save(entidad, maps)
  end

  def delete(entidad, id) do
    registros = all(entidad)

    case Enum.find(registros, &(&1.id == id)) do
      nil ->
        {:error, "Registro no encontrado"}

      _ ->
        maps =
          registros
          |> Enum.reject(&(&1.id == id))
          |> Enum.map(fn r -> apply(r.__struct__, :to_map, [r]) end)

        save(entidad, maps)
    end
  end

  # Genera un ID único dentro del VM de Erlang (monotónico, nunca se repite).
  # Reemplaza System.system_time/1 que podía colisionar en llamadas concurrentes.
 def generar_id(prefijo) do
  sufijo = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  "#{prefijo}_#{sufijo}"
end

  # ── Privado ─────────────────────────────────────────────

  defp save(entidad, registros) do
    %{archivo: archivo, clave: clave} = config!(entidad)

    path     = Path.join(@data_dir, archivo)
    tmp_path = path <> ".tmp"
    File.mkdir_p!(@data_dir)

    File.write!(tmp_path, Jason.encode!(%{clave => registros}, pretty: true))

    # En Unix, rename es atómico. En Windows puede fallar con :eexist si el
    # destino ya existe; en ese caso copiamos y borramos el temporal.
    case File.rename(tmp_path, path) do
      :ok ->
        :ok

      {:error, _} ->
        File.copy!(tmp_path, path)
        File.rm(tmp_path)
        :ok
    end
  end

  defp config!(entidad) do
    Map.get(@entidades, entidad) ||
      raise """
      Entidad desconocida: #{inspect(entidad)}.
      Válidas: #{inspect(Map.keys(@entidades))}
      """
  end
end
