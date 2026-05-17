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
          saldo:         0
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

  # ── Privado ────────────────────────────────────────────────────────────────

  defp hashear(password) do
    :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
  end
end
