defmodule AzarApp.Clientes do
  alias AzarApp.JsonStore
  alias AzarApp.Model.Structure.Cliente

  def get_cliente(documento) do
    case Enum.find(JsonStore.all(:clientes), &(&1.documento == documento)) do
      nil     -> :error
      cliente -> {:ok, cliente}
    end
  end

  def registrar(params) do
    case get_cliente(params["documento"]) do
      {:ok, _} ->
        {:error, "Ya existe un cliente con ese documento"}

      :error ->
        cliente = %Cliente{
          id:            JsonStore.generar_id("cliente"),
          nombre:        params["nombre"],
          documento:     params["documento"],
          password_hash: hashear(params["password"]),
          saldo:         0,
          notificaciones: []
        }

        JsonStore.upsert(:clientes, cliente)
        {:ok, cliente}
    end
  end

  def login(documento, password) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        if cliente.password_hash == hashear(password) do
          {:ok, cliente}
        else
          {:error, "Contraseña incorrecta"}
        end

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  def acreditar_saldo(documento, valor) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        actualizado = %{cliente | saldo: cliente.saldo + valor}
        JsonStore.upsert(:clientes, actualizado)
        {:ok, actualizado}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  def recargar_saldo(documento, valor) when valor > 0 do
    acreditar_saldo(documento, valor)
  end

  def recargar_saldo(_documento, _valor) do
    {:error, "El valor debe ser mayor a 0"}
  end

  def descontar_saldo(documento, valor) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        if cliente.saldo >= valor do
          actualizado = %{cliente | saldo: cliente.saldo - valor}
          JsonStore.upsert(:clientes, actualizado)
          {:ok, actualizado}
        else
          {:error, "Saldo insuficiente"}
        end

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  # ── Notificaciones ─────────────────────────────────────────────────────────

  def agregar_notificacion(documento, attrs) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        notif = %{
          "id"     => JsonStore.generar_id("notif"),
          "tipo"   => attrs.tipo,
          "titulo" => attrs.titulo,
          "cuerpo" => attrs.cuerpo,
          "fecha"  => DateTime.utc_now() |> DateTime.to_string(),
          "leida"  => false
        }

        actualizado = %{cliente | notificaciones: [notif | cliente.notificaciones]}
        JsonStore.upsert(:clientes, actualizado)
        {:ok, notif}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  def marcar_notificaciones_leidas(documento) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        nuevas      = Enum.map(cliente.notificaciones, &Map.put(&1, "leida", true))
        actualizado = %{cliente | notificaciones: nuevas}
        JsonStore.upsert(:clientes, actualizado)
        {:ok, actualizado}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  def notificaciones_no_leidas(documento) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        count = Enum.count(cliente.notificaciones, &(!&1["leida"]))
        {:ok, count}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  def eliminar_notificacion(documento, notif_id) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        nuevas      = Enum.reject(cliente.notificaciones, &(&1["id"] == notif_id))
        actualizado = %{cliente | notificaciones: nuevas}
        JsonStore.upsert(:clientes, actualizado)
        {:ok, actualizado}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp hashear(password) do
    :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
  end
end
