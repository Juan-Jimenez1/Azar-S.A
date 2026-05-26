defmodule AzarApp.Sorteos do
  @moduledoc """
  Contexto principal de gestión de sorteos (loterías).

  Centraliza todas las operaciones del dominio de sorteos:
  - CRUD de sorteos y sus premios asociados
  - Compra y devolución de billetes (completos o fraccionados)
  - Ejecución de sorteos (manual o automática)
  - Consultas financieras: ingresos, balance por sorteo y global
  - Reportes para administrador y para el jugador

  Las operaciones de compra/devolución/ejecución se delegan a `SorteoServer`,
  un GenServer que mantiene el estado del sorteo en memoria y garantiza
  atomicidad en operaciones concurrentes.
  """

  alias AzarApp.{JsonStore, SorteoServer, SorteoSupervisor}
  alias AzarApp.Model.Structure.{Sorteo, Premio}

  # ── Gestión de sorteos ─────────────────────────────────────────────────────

  @doc "Retorna todos los sorteos ordenados por fecha ascendente."
  def listar_sorteos do
    JsonStore.all(:sorteos)
    |> Enum.sort_by(& &1.fecha)
  end

  @doc "Retorna los sorteos que aún no han sido ejecutados, ordenados por fecha."
  def listar_sorteos_disponibles do
    listar_sorteos()
    |> Enum.reject(& &1.realizado)
  end

  @doc "Busca un sorteo por su `id`. Retorna `{:ok, sorteo}` o `:error`."
  def get_sorteo(id) do
    JsonStore.get(:sorteos, id)
  end

  @doc """
  Crea un nuevo sorteo y lanza su proceso `SorteoServer`.

  `params` debe contener: `"nombre"`, `"fecha"` (ISO 8601), `"valor_billete"`,
  `"cantidad_fracciones"` y `"cantidad_billetes"` (como enteros).
  Genera los billetes numerados desde 1001. Retorna `{:ok, sorteo}`.
  """
  def crear_sorteo(params) do
    id = JsonStore.generar_id("sorteo")

    sorteo = %Sorteo{
      id: id,
      nombre: params["nombre"],
      fecha: params["fecha"],
      valor_billete: params["valor_billete"],
      cantidad_fracciones: params["cantidad_fracciones"],
      cantidad_billetes: params["cantidad_billetes"],
      realizado: false,
      numero_ganador: nil,
      premio: nil,
      billetes: generar_billetes(params["cantidad_billetes"])
    }

    JsonStore.upsert(:sorteos, sorteo)
    SorteoSupervisor.start_sorteo(id)
    {:ok, sorteo}
  end

  @doc """
  Elimina el sorteo con el `id` dado.

  No se puede eliminar si el sorteo ya tiene un premio asignado.
  Retorna `:ok` o `{:error, motivo}`.
  """
  def eliminar_sorteo(id) do
    case get_sorteo(id) do
      {:ok, sorteo} ->
        if sorteo.premio != nil do
          {:error, "No se puede eliminar: el sorteo tiene un premio asociado"}
        else
          JsonStore.delete(:sorteos, id)
        end

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  # ── Gestión de premios ─────────────────────────────────────────────────────

  @doc """
  Asigna un premio al sorteo indicado.

  Solo se permite un premio por sorteo. `params` debe incluir `"nombre"` y
  `"valor"` (entero). Retorna `{:ok, premio}` o `{:error, motivo}`.
  """
  def crear_premio(sorteo_id, params) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        if sorteo.premio != nil do
          {:error, "El sorteo ya tiene un premio asignado"}
        else
          premio = %Premio{
            id: JsonStore.generar_id("premio"),
            nombre: params["nombre"],
            valor: params["valor"]
          }

          SorteoServer.update(sorteo_id, %{premio: premio})
          {:ok, premio}
        end

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  @doc """
  Elimina el premio del sorteo indicado.

  No está permitido si ya hay billetes vendidos. Retorna `:ok` o `{:error, motivo}`.
  """
  def eliminar_premio(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        if Enum.any?(sorteo.billetes, &(!&1["disponible"])) do
          {:error, "No se puede eliminar: el sorteo ya tiene compradores"}
        else
          SorteoServer.update(sorteo_id, %{premio: nil})
          :ok
        end

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  # ── Compras ────────────────────────────────────────────────────────────────

  @doc "Compra el billete completo `numero` del sorteo para el cliente. Delega a `SorteoServer`."
  def comprar_billete(sorteo_id, numero, cliente_doc) do
    SorteoServer.comprar_billete(sorteo_id, numero, cliente_doc)
  end

  @doc "Compra la `fraccion` indicada del billete `numero`. Delega a `SorteoServer`."
  def comprar_fraccion(sorteo_id, numero, fraccion, cliente_doc) do
    SorteoServer.comprar_fraccion(sorteo_id, numero, fraccion, cliente_doc)
  end

  @doc """
  Compra todas las fracciones disponibles del billete `numero` para el cliente.

  Retorna `{:ok, billete, cantidad_comprada}` o `{:error, motivo}`.
  """
  def comprar_fracciones_restantes(sorteo_id, numero, cliente_doc) do
    SorteoServer.comprar_fracciones_restantes(sorteo_id, numero, cliente_doc)
  end

  @doc """
  Devuelve una compra del cliente en el billete `numero`.

  `fracciones` puede ser `:todas` (devuelve todas las fracciones del cliente)
  o una lista de enteros con los números de fracción a devolver.
  No se puede devolver si el sorteo ya fue ejecutado.
  Retorna `:ok` o `{:error, motivo}`.
  """
  def devolver_compra(sorteo_id, numero, cliente_doc, fracciones \\ :todas) do
    SorteoServer.devolver_compra(sorteo_id, numero, cliente_doc, fracciones)
  end

  @doc "Retorna `{:ok, billetes}` con los billetes que aún tienen fracciones disponibles para comprar."
  def billetes_disponibles(sorteo_id) do
    SorteoServer.billetes_disponibles(sorteo_id)
  end

  # ── Clientes de un sorteo ──────────────────────────────────────────────────

  @doc """
  Retorna los compradores del sorteo separados en dos grupos.

  Retorna:

      {:ok, %{
        completos: [%{doc, nombre, billete}],
        fracciones: [%{doc, nombre, billete, fraccion}]
      }}
  """
  def clientes_por_sorteo(sorteo_id) do
  case get_sorteo(sorteo_id) do
    {:ok, sorteo} ->
      clientes = AzarApp.JsonStore.all(:clientes)

      resolver = fn doc ->
        c = Enum.find(clientes, &(&1.documento == doc))
        if c, do: c.nombre, else: doc
      end

      # ← Ya no filtra por disponible, filtra por tipo
      billetes_con_ventas =
        Enum.filter(sorteo.billetes, fn b ->
          b["tipo"] == "completo" or b["tipo"] == "fraccion"
        end)

      completos =
        billetes_con_ventas
        |> Enum.filter(&(&1["tipo"] == "completo"))
        |> Enum.map(fn b ->
          %{
            doc:     b["propietario_doc"],
            nombre:  resolver.(b["propietario_doc"]),
            billete: b["numero"]
          }
        end)
        |> Enum.sort_by(& &1.nombre)

      fracciones =
        billetes_con_ventas
        |> Enum.filter(&(&1["tipo"] == "fraccion"))
        |> Enum.flat_map(fn b ->
          Map.get(b, "fracciones_tomadas", [])
          |> Enum.map(fn f ->
            %{
              doc:      f["propietario_doc"],
              nombre:   resolver.(f["propietario_doc"]),
              billete:  b["numero"],
              fraccion: f["fraccion"]
            }
          end)
        end)
        |> Enum.sort_by(& &1.nombre)

      {:ok, %{completos: completos, fracciones: fracciones}}

    :error ->
      {:error, "Sorteo no encontrado"}
  end
end

  # ── Ejecución ──────────────────────────────────────────────────────────────

  @doc """
  Ejecuta el sorteo: selecciona un billete ganador al azar y notifica a los participantes.

  Retorna `{:ok, numero_ganador}` o `{:error, motivo}` si ya fue realizado
  o no hay billetes vendidos.
  """
  def ejecutar_sorteo(sorteo_id) do
    SorteoServer.ejecutar(sorteo_id)
  end

  @doc """
  Ejecuta todos los sorteos cuya fecha ya pasó y que aún no han sido realizados.

  Retorna una lista de `{sorteo_id, numero_ganador}` por cada sorteo ejecutado.
  Los sorteos sin billetes vendidos se omiten silenciosamente.
  """
  def ejecutar_sorteos_pendientes do
    hoy = Date.utc_today() |> Date.to_string()

    listar_sorteos()
    |> Enum.filter(fn s -> !s.realizado and s.fecha <= hoy end)
    |> Enum.flat_map(fn s ->
      # flat_map: si un sorteo no tiene billetes vendidos retorna []
      # en lugar de crashear con un pattern-match fallido
      case SorteoServer.ejecutar(s.id) do
        {:ok, ganador} -> [{s.id, ganador}]
        {:error, _} -> []
      end
    end)
  end

  # ── Consultas financieras ──────────────────────────────────────────────────

  @doc """
  Calcula los ingresos reales de un sorteo considerando billetes completos
  y fracciones vendidas individualmente (no solo billetes marcados disponible: false).
  """
  def ingresos_por_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        valor_fraccion =
          if sorteo.cantidad_fracciones > 0,
            do: div(sorteo.valor_billete, sorteo.cantidad_fracciones),
            else: 0

        ingresos =
          Enum.reduce(sorteo.billetes, 0, fn billete, acc ->
            fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])

            cond do
              billete["tipo"] == "completo" ->
                acc + sorteo.valor_billete

              billete["tipo"] == "fraccion" and fracciones_tomadas != [] ->
                acc + length(fracciones_tomadas) * valor_fraccion

              true ->
                acc
            end
          end)

        {:ok, ingresos}

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  @doc """
  Calcula el balance financiero de un sorteo ya realizado.

  Retorna:

      {:ok, %{ingresos: integer, valor_premio: integer,
              balance: integer, resultado: "ganancia" | "pérdida"}}

  Falla con `{:error, motivo}` si el sorteo no ha sido ejecutado.
  """
  def balance_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, %Sorteo{realizado: false}} ->
        {:error, "El sorteo aún no se ha realizado"}

      {:ok, sorteo} ->
        {:ok, ingresos} = ingresos_por_sorteo(sorteo_id)
        valor_premio = if sorteo.premio, do: sorteo.premio.valor, else: 0
        balance = ingresos - valor_premio

        {:ok,
         %{
           ingresos: ingresos,
           valor_premio: valor_premio,
           balance: balance,
           resultado: if(balance >= 0, do: "ganancia", else: "pérdida")
         }}

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  @doc "Balance de todos los sorteos realizados. Cada entrada incluye nombre, fecha e ingresos."
  def balance_total do
    listar_sorteos()
    |> Enum.filter(& &1.realizado)
    |> Enum.map(fn s ->
      {:ok, balance} = balance_sorteo(s.id)

      balance
      |> Map.put(:sorteo, s.nombre)
      |> Map.put(:fecha, s.fecha)
      |> Map.put(:sorteo_id, s.id)
    end)
  end

  # ── Reportes admin ─────────────────────────────────────────────────────────

  @doc """
  Premios entregados en sorteos pasados.
  Retorna lista de mapas con: sorteo, premio, ganadores (nombre + fracción),
  ingresos, balance y resultado (ganancia/pérdida).
  """
  def premios_entregados(orden \\ "asc") do
    clientes = JsonStore.all(:clientes)

    listar_sorteos()
    |> Enum.filter(fn s -> s.realizado and s.premio != nil end)
    |> Enum.sort_by(& &1.fecha, if(orden == "desc", do: :desc, else: :asc))
    |> Enum.map(fn sorteo ->
      {:ok, ingresos} = ingresos_por_sorteo(sorteo.id)
      ganadores = encontrar_ganadores(sorteo, clientes)
      balance = ingresos - sorteo.premio.valor

      %{
        sorteo: sorteo,
        premio: sorteo.premio,
        ganadores: ganadores,
        ingresos: ingresos,
        balance: balance,
        resultado: if(balance >= 0, do: "ganancia", else: "pérdida")
      }
    end)
  end


  # ── Reportes jugador ───────────────────────────────────────────────────────

  @doc "Todas las compras de un cliente en todos los sorteos."
  def compras_por_cliente(cliente_doc) do
    listar_sorteos()
    |> Enum.flat_map(fn sorteo ->
      valor_fraccion =
        if sorteo.cantidad_fracciones > 0,
          do: div(sorteo.valor_billete, sorteo.cantidad_fracciones),
          else: 0

      Enum.flat_map(sorteo.billetes, fn billete ->
        fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])

        cond do
          billete["tipo"] == "completo" and billete["propietario_doc"] == cliente_doc ->
            [
              %{
                sorteo_id: sorteo.id,
                sorteo_nombre: sorteo.nombre,
                sorteo_fecha: sorteo.fecha,
                sorteo_realizado: sorteo.realizado,
                billete: billete["numero"],
                tipo: "completo",
                fraccion: nil,
                valor: sorteo.valor_billete
              }
            ]

          billete["tipo"] == "fraccion" ->
            fracciones_tomadas
            |> Enum.filter(&(&1["propietario_doc"] == cliente_doc))
            |> Enum.map(fn f ->
              %{
                sorteo_id: sorteo.id,
                sorteo_nombre: sorteo.nombre,
                sorteo_fecha: sorteo.fecha,
                sorteo_realizado: sorteo.realizado,
                billete: billete["numero"],
                tipo: "fraccion",
                fraccion: f["fraccion"],
                valor: valor_fraccion
              }
            end)

          true ->
            []
        end
      end)
    end)
  end

  @doc "Premios ganados por un cliente en todos los sorteos realizados."
  def premios_por_cliente(cliente_doc) do
    listar_sorteos()
    |> Enum.filter(fn s -> s.realizado and s.premio != nil end)
    |> Enum.flat_map(fn sorteo ->
      billete = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))

      valor_fraccion =
        if sorteo.cantidad_fracciones > 0,
          do: div(sorteo.premio.valor, sorteo.cantidad_fracciones),
          else: 0

      if billete do
        case billete["tipo"] do
          "completo" ->
            if billete["propietario_doc"] == cliente_doc do
              [
                %{
                  sorteo_nombre: sorteo.nombre,
                  billete: billete["numero"],
                  fraccion: nil,
                  valor: sorteo.premio.valor
                }
              ]
            else
              []
            end

          "fraccion" ->
            (billete["fracciones_tomadas"] || [])
            |> Enum.filter(&(&1["propietario_doc"] == cliente_doc))
            |> Enum.map(fn f ->
              %{
                sorteo_nombre: sorteo.nombre,
                billete: billete["numero"],
                fraccion: f["fraccion"],
                valor: valor_fraccion
              }
            end)

          _ ->
            []
        end
      else
        []
      end
    end)
  end

  @doc "Retorna los billetes (completos o fraccionados) que posee el cliente en el sorteo."
  def billetes_del_cliente(sorteo_id, cliente_doc) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        Enum.filter(sorteo.billetes, fn billete ->
          case billete["tipo"] do
            "completo" ->
              billete["propietario_doc"] == cliente_doc

            "fraccion" ->
              Enum.any?(
                Map.get(billete, "fracciones_tomadas", []),
                &(&1["propietario_doc"] == cliente_doc)
              )

            _ ->
              false
          end
        end)

      :error ->
        []
    end
  end

  @doc """
  Retorna el resumen financiero de todos los sorteos ya realizados.

  Cada entrada incluye: nombre, fecha, ingresos, premio entregado,
  ganancia neta, resultado y nombre del ganador.
  """
  def balance_sorteos_pasados do
    listar_sorteos()
    |> Enum.filter(& &1.realizado)
    |> Enum.map(fn sorteo ->
      {:ok, ingresos} = ingresos_por_sorteo(sorteo.id)
      valor_premio =
        if sorteo.premio && sorteo.numero_ganador do
          billete = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))
          case billete["tipo"] do
            "completo" ->
              sorteo.premio.valor
            "fraccion" ->
              fracciones_tomadas = length(billete["fracciones_tomadas"] || [])
              div(sorteo.premio.valor, sorteo.cantidad_fracciones) * fracciones_tomadas
            _ -> 0
          end
        else
          0
        end

      ganancia = ingresos - valor_premio

      ganador_nombre =
        if sorteo.numero_ganador do
          billete = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))
          resolver_nombre_ganador(billete)
        end

      %{
        sorteo: sorteo.nombre,
        fecha: sorteo.fecha,
        ingresos: ingresos,
        premio: if(sorteo.premio, do: sorteo.premio.nombre, else: "—"),
        valor_premio: valor_premio,
        ganancia: ganancia,
        resultado: if(ganancia >= 0, do: "ganancia", else: "pérdida"),
        numero_ganador: sorteo.numero_ganador,
        ganador_nombre: ganador_nombre
      }
    end)
  end

  defp resolver_nombre_ganador(nil), do: "—"

  defp resolver_nombre_ganador(billete) do
    clientes = AzarApp.JsonStore.all(:clientes)

    case billete["tipo"] do
      "completo" ->
        doc = billete["propietario_doc"]
        cliente = Enum.find(clientes, &(&1.documento == doc))
        if cliente, do: cliente.nombre, else: doc

      "fraccion" ->
        docs =
          billete
          |> Map.get("fracciones_tomadas", [])
          |> Enum.map(& &1["propietario_doc"])
          |> Enum.uniq()

        nombres =
          Enum.map(docs, fn doc ->
            cliente = Enum.find(clientes, &(&1.documento == doc))
            if cliente, do: cliente.nombre, else: doc
          end)

        Enum.join(nombres, ", ")

      _ ->
        "—"
    end
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp generar_billetes(cantidad) do
    Enum.map(1..cantidad, fn i ->
      %{"numero" => 1000 + i, "disponible" => true}
    end)
  end

  defp encontrar_ganadores(sorteo, clientes) do
    billete = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))

    if billete do
      case billete["tipo"] do
        "completo" ->
          nombre = buscar_nombre(billete["propietario_doc"], clientes)
          [%{nombre: nombre, fraccion: nil}]

        "fraccion" ->
          (billete["fracciones_tomadas"] || [])
          |> Enum.map(fn f ->
            nombre = buscar_nombre(f["propietario_doc"], clientes)
            %{nombre: nombre, fraccion: f["fraccion"]}
          end)

        _ ->
          []
      end
    else
      []
    end
  end

  defp buscar_nombre(doc, clientes) do
    case Enum.find(clientes, &(&1.documento == doc)) do
      nil -> "Desconocido (#{doc})"
      cliente -> cliente.nombre
    end
  end
end
