defmodule AzarApp.Clientes do
  alias AzarApp.JsonStore
  alias AzarApp.Model.Structure.Cliente

  def get_cliente(documento) do
    case Enum.find(JsonStore.all(:clientes), &(&1.documento == documento)) do
      nil -> :error
      cliente -> {:ok, cliente}
    end
  end

  def registrar(params) do
    case get_cliente(params["documento"]) do
      {:ok, _} ->
        {:error, "Ya existe un cliente con ese documento"}

      :error ->
        cliente = %Cliente{
          id: JsonStore.generar_id("cliente"),
          nombre: params["nombre"],
          documento: params["documento"],
          password_hash: hashear(params["password"]),
          saldo: 0,
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
          "id" => JsonStore.generar_id("notif"),
          "tipo" => attrs.tipo,
          "titulo" => attrs.titulo,
          "cuerpo" => attrs.cuerpo,
          "fecha" => DateTime.utc_now() |> DateTime.to_string(),
          "leida" => false
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
        nuevas = Enum.map(cliente.notificaciones, &Map.put(&1, "leida", true))
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
        nuevas = Enum.reject(cliente.notificaciones, &(&1["id"] == notif_id))
        actualizado = %{cliente | notificaciones: nuevas}
        JsonStore.upsert(:clientes, actualizado)
        {:ok, actualizado}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  # ── Historial y balance ────────────────────────────────────────────────────

  def historial_compras(documento) do
    todos_los_sorteos = JsonStore.all(:sorteos)

    compras =
      Enum.flat_map(todos_los_sorteos, fn sorteo ->
        Enum.flat_map(sorteo.billetes, fn billete ->
          cond do
            # Billete completo del cliente
            billete["tipo"] == "completo" and billete["propietario_doc"] == documento ->
              [
                %{
                  sorteo_id: sorteo.id,
                  sorteo_nombre: sorteo.nombre,
                  numero: billete["numero"],
                  tipo: :completo,
                  valor: sorteo.valor_billete,
                  realizado: sorteo.realizado
                }
              ]

            # Fracciones del cliente
            billete["tipo"] == "fraccion" ->
              valor_fraccion = div(sorteo.valor_billete, sorteo.cantidad_fracciones)

              billete
              |> Map.get("fracciones_tomadas", [])
              |> Enum.filter(&(&1["propietario_doc"] == documento))
              |> Enum.map(fn f ->
                %{
                  sorteo_id: sorteo.id,
                  sorteo_nombre: sorteo.nombre,
                  numero: billete["numero"],
                  tipo: :fraccion,
                  fraccion: f["fraccion"],
                  valor: valor_fraccion,
                  realizado: sorteo.realizado
                }
              end)

            true ->
              []
          end
        end)
      end)

    total_gastado = Enum.reduce(compras, 0, &(&1.valor + &2))

    {:ok, %{compras: compras, total_gastado: total_gastado}}
  end

  def premios_obtenidos(documento) do
    todos_los_sorteos = JsonStore.all(:sorteos)

    premios =
      Enum.flat_map(todos_los_sorteos, fn sorteo ->
        if sorteo.realizado && sorteo.premio && sorteo.numero_ganador do
          billete_ganador = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))

          case billete_ganador do
            nil ->
              []

            billete ->
              cond do
                # Ganó billete completo
                billete["tipo"] == "completo" and billete["propietario_doc"] == documento ->
                  [
                    %{
                      sorteo_nombre: sorteo.nombre,
                      numero: billete["numero"],
                      tipo: :completo,
                      premio_nombre: sorteo.premio.nombre,
                      valor: sorteo.premio.valor
                    }
                  ]

                # Ganó por fracción
                billete["tipo"] == "fraccion" ->
                  valor_fraccion = div(sorteo.premio.valor, sorteo.cantidad_fracciones)

                  billete
                  |> Map.get("fracciones_tomadas", [])
                  |> Enum.filter(&(&1["propietario_doc"] == documento))
                  |> Enum.map(fn f ->
                    %{
                      sorteo_nombre: sorteo.nombre,
                      numero: billete["numero"],
                      tipo: :fraccion,
                      fraccion: f["fraccion"],
                      premio_nombre: sorteo.premio.nombre,
                      valor: valor_fraccion
                    }
                  end)

                true ->
                  []
              end
          end
        else
          []
        end
      end)

    total_ganado = Enum.reduce(premios, 0, &(&1.valor + &2))

    {:ok, %{premios: premios, total_ganado: total_ganado}}
  end

  def balance_personal(documento) do
    with {:ok, %{total_gastado: gastado}} <- historial_compras(documento),
         {:ok, %{total_ganado: ganado}} <- premios_obtenidos(documento) do
      {:ok,
       %{
         gastado: gastado,
         ganado: ganado,
         diferencia: ganado - gastado,
         resultado: if(ganado >= gastado, do: "positivo", else: "negativo")
       }}
    end
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp hashear(password) do
    :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
  end
end
