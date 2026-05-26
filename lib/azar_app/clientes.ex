defmodule AzarApp.Clientes do
  @moduledoc """
  Contexto de gestión de jugadores (clientes) de la plataforma.

  Cubre el ciclo de vida completo de un cliente:
  - Registro y autenticación
  - Manejo de saldo (recarga, descuento, acreditación de premios)
  - Notificaciones en tiempo real (creación, lectura, eliminación)
  - Historial de compras y premios obtenidos
  - Recuperación de contraseña mediante pregunta secreta

  Las contraseñas y respuestas secretas se almacenan como hash SHA-256.
  Las notificaciones se guardan embebidas en el documento del cliente.
  """

  alias AzarApp.JsonStore
  alias AzarApp.Model.Structure.Cliente

  @doc """
  Busca un cliente por su número de documento.

  Retorna `{:ok, cliente}` si existe, o `:error` si no se encuentra.
  """
  def get_cliente(documento) do
    case Enum.find(JsonStore.all(:clientes), &(&1.documento == documento)) do
      nil -> :error
      cliente -> {:ok, cliente}
    end
  end

  @doc """
  Registra un nuevo cliente en el sistema.

  El mapa `params` debe contener: `"nombre"`, `"documento"`, `"password"`,
  `"password_confirmacion"`, `"pregunta_secreta"` y `"respuesta_secreta"`.

  Retorna `{:ok, cliente}` o `{:error, motivo}` si el documento ya existe,
  las contraseñas no coinciden, o faltan campos obligatorios.
  """
  def registrar(params) do
  case get_cliente(params["documento"]) do
    {:ok, _} ->
      {:error, "Ya existe un cliente con ese documento"}

    :error ->
      cond do
        params["password"] != params["password_confirmacion"] ->
          {:error, "Las contraseñas no coinciden"}

        is_nil(params["pregunta_secreta"]) or params["pregunta_secreta"] == "" ->
          {:error, "La pregunta secreta es requerida"}

        is_nil(params["respuesta_secreta"]) or params["respuesta_secreta"] == "" ->
          {:error, "La respuesta secreta es requerida"}

        true ->
          cliente = %Cliente{
            id:               JsonStore.generar_id("cliente"),
            nombre:           params["nombre"],
            documento:        params["documento"],
            password_hash:    hashear(params["password"]),
            pregunta_secreta: params["pregunta_secreta"],
            respuesta_hash:   hashear(String.downcase(String.trim(params["respuesta_secreta"]))),
            saldo:            0,
            notificaciones:   []
          }

          JsonStore.upsert(:clientes, cliente)
          {:ok, cliente}
      end
  end
end
  @doc """
  Autentica a un cliente por documento y contraseña.

  Retorna `{:ok, cliente}` si las credenciales son válidas, o
  `{:error, motivo}` si el cliente no existe o la contraseña es incorrecta.
  """
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

  @doc """
  Suma `valor` al saldo del cliente identificado por `documento`.

  Usado internamente para acreditar premios. Retorna `{:ok, cliente}` o
  `{:error, motivo}`.
  """
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

  @doc """
  Recarga el saldo del cliente con el `valor` indicado (debe ser mayor a 0).

  Retorna `{:ok, cliente}` o `{:error, motivo}`.
  """
  def recargar_saldo(documento, valor) when valor > 0 do
    acreditar_saldo(documento, valor)
  end

  def recargar_saldo(_documento, _valor) do
    {:error, "El valor debe ser mayor a 0"}
  end

  @doc """
  Descuenta `valor` del saldo del cliente.

  Falla con `{:error, "Saldo insuficiente"}` si el saldo actual es menor al valor
  solicitado. Retorna `{:ok, cliente}` si la operación es exitosa.
  """
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

  @doc """
  Agrega una nueva notificación al cliente identificado por `documento`.

  `attrs` debe ser un mapa con claves `:tipo`, `:titulo` y `:cuerpo`.
  La notificación se registra con fecha/hora de Colombia y marcada como no leída.
  Retorna `{:ok, notificacion}`.
  """
  def agregar_notificacion(documento, attrs) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        notif = %{
          "id" => JsonStore.generar_id("notif"),
          "tipo" => attrs.tipo,
          "titulo" => attrs.titulo,
          "cuerpo" => attrs.cuerpo,
          "fecha" => DateTime.now!("America/Bogota") |> DateTime.to_string(),
          "leida" => false
        }

        actualizado = %{cliente | notificaciones: [notif | cliente.notificaciones]}
        JsonStore.upsert(:clientes, actualizado)
        {:ok, notif}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  @doc "Marca todas las notificaciones del cliente como leídas. Retorna `{:ok, cliente}`."
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

  @doc "Retorna `{:ok, count}` con la cantidad de notificaciones no leídas del cliente."
  def notificaciones_no_leidas(documento) do
    case get_cliente(documento) do
      {:ok, cliente} ->
        count = Enum.count(cliente.notificaciones, &(!&1["leida"]))
        {:ok, count}

      :error ->
        {:error, "Cliente no encontrado"}
    end
  end

  @doc "Elimina la notificación con `notif_id` de la lista del cliente. Retorna `{:ok, cliente}`."
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

  @doc """
  Retorna el historial de compras del cliente en todos los sorteos.

  Recorre todos los sorteos buscando billetes completos o fracciones asociadas
  al documento del cliente. Retorna:

      {:ok, %{compras: [%{sorteo_id, sorteo_nombre, numero, tipo, valor, realizado, ...}],
              total_gastado: integer}}
  """
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
    compras_ordenadas = Enum.sort_by(compras, & &1.numero, :desc)
    {:ok, %{compras: compras_ordenadas, total_gastado: total_gastado}}
  end

  @doc """
  Retorna los premios ganados por el cliente en sorteos ya realizados.

  Para billetes fraccionados, calcula el valor proporcional
  (`premio.valor / cantidad_fracciones`). Retorna:

      {:ok, %{premios: [%{sorteo_nombre, numero, tipo, premio_nombre, valor, ...}],
              total_ganado: integer}}
  """
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
    premios_ordenados = Enum.sort_by(premios, & &1.numero, :desc)
    {:ok, %{premios: premios_ordenados, total_ganado: total_ganado}}
  end

  @doc """
  Calcula el balance financiero personal del cliente.

  Retorna:

      {:ok, %{gastado: integer, ganado: integer,
              diferencia: integer, resultado: "positivo" | "negativo"}}
  """
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



  @doc """
  Cambia la contraseña del cliente tras verificar su respuesta secreta.

  El flujo es: busca el cliente por documento → valida que las contraseñas
  coincidan → compara el hash de `respuesta` con el almacenado.
  Retorna `{:ok, cliente}` o `{:error, motivo}`.
  """
  def recuperar_password(documento, respuesta, nueva_password, confirmacion) do
  cond do
    nueva_password != confirmacion ->
      {:error, "Las contraseñas no coinciden"}

    true ->
      case get_cliente(documento) do
        {:ok, cliente} ->
          respuesta_hash = hashear(String.downcase(String.trim(respuesta)))

          if cliente.respuesta_hash == respuesta_hash do
            actualizado = %{cliente | password_hash: hashear(nueva_password)}
            JsonStore.upsert(:clientes, actualizado)
            {:ok, actualizado}
          else
            {:error, "Respuesta incorrecta"}
          end

        :error ->
          {:error, "No existe un cliente con ese documento"}
      end
  end
end

  @doc "Retorna `{:ok, pregunta_secreta}` del cliente o `{:error, motivo}` si no existe."
  def get_pregunta(documento) do
  case get_cliente(documento) do
    {:ok, cliente} -> {:ok, cliente.pregunta_secreta}
    :error         -> {:error, "No existe un cliente con ese documento"}
  end
end


  # ── Privado ────────────────────────────────────────────────────────────────

  defp hashear(password) do
    :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
  end
end
