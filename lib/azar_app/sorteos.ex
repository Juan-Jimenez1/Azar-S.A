defmodule AzarApp.Sorteos do
  alias AzarApp.{JsonStore, SorteoServer, SorteoSupervisor}
  alias AzarApp.Model.Structure.{Sorteo, Premio}

  # ── Gestión de sorteos ─────────────────────────────────────────────────────

  def listar_sorteos do
    JsonStore.all(:sorteos)
    |> Enum.sort_by(& &1.fecha)
  end

  def listar_sorteos_disponibles do
    listar_sorteos()
    |> Enum.reject(& &1.realizado)
  end

  def get_sorteo(id) do
    JsonStore.get(:sorteos, id)
  end

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

  def eliminar_sorteo(id) do
    case get_sorteo(id) do
      {:ok, sorteo} ->
        if sorteo.premio != nil do
          {:error, "No se puede eliminar el sorteo tiene un premio asociado"}
        else
          JsonStore.delete(:sorteos, id)
        end

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  # ── Gestión de premio ──────────────────────────────────────────────────────

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

  def eliminar_premio(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        tiene_clientes = Enum.any?(sorteo.billetes, &(!&1["disponible"]))

        if tiene_clientes do
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

  def comprar_billete(sorteo_id, numero, cliente_doc) do
    SorteoServer.comprar_billete(sorteo_id, numero, cliente_doc)
  end

  def comprar_fraccion(sorteo_id, numero, fraccion, cliente_doc) do
    SorteoServer.comprar_fraccion(sorteo_id, numero, fraccion, cliente_doc)
  end

  def devolver_compra(sorteo_id, numero, cliente_doc) do
    SorteoServer.devolver_compra(sorteo_id, numero, cliente_doc)
  end

  def billetes_disponibles(sorteo_id) do
    SorteoServer.billetes_disponibles(sorteo_id)
  end

  # ── Clientes ───────────────────────────────────────────────────────────────

  def clientes_por_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        completos =
          sorteo.billetes
          |> Enum.filter(&(&1["tipo"] == "completo"))
          |> Enum.map(fn b -> %{doc: b["propietario_doc"], billete: b["numero"]} end)
          |> Enum.sort_by(& &1.doc)

        fracciones =
          sorteo.billetes
          |> Enum.filter(&(&1["tipo"] == "fraccion"))
          |> Enum.flat_map(fn b ->
            Enum.map(b["fracciones_tomadas"], fn f ->
              %{doc: f["propietario_doc"], billete: b["numero"], fraccion: f["fraccion"]}
            end)
          end)
          |> Enum.sort_by(& &1.doc)

        {:ok, %{completos: completos, fracciones: fracciones}}

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  # ── Ejecución ──────────────────────────────────────────────────────────────

  def ejecutar_sorteos_pendientes do
    hoy = Date.utc_today() |> Date.to_string()

    listar_sorteos()
    |> Enum.filter(fn s -> !s.realizado and s.fecha <= hoy end)
    |> Enum.flat_map(fn s ->
      # flat_map evita crash si el sorteo no tiene billetes vendidos
      case SorteoServer.ejecutar(s.id) do
        {:ok, ganador} -> [{s.id, ganador}]
        {:error, _} -> []
      end
    end)
  end

  # ── Consultas financieras ──────────────────────────────────────────────────

  def ingresos_por_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        # Calcula correctamente para billetes completos Y fracciones parciales
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

  def balance_total do
    listar_sorteos()
    |> Enum.filter(& &1.realizado)
    |> Enum.map(fn s ->
      {:ok, balance} = balance_sorteo(s.id)
      Map.merge(balance, %{sorteo: s.nombre, sorteo_id: s.id, fecha: s.fecha})
    end)
  end

  # ── Reportes ───────────────────────────────────────────────────────────────

  @doc """
  Premios entregados en sorteos pasados: sorteo, premio, ganadores (con nombre),
  ingresos y balance financiero. Ordenado por fecha.
  """
  def premios_entregados do
    clientes = JsonStore.all(:clientes)

    listar_sorteos()
    |> Enum.filter(fn s -> s.realizado and s.premio != nil end)
    |> Enum.sort_by(& &1.fecha)
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

  @doc "Todas las compras realizadas por un cliente en todos los sorteos."
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

  def ejecutar_sorteo(sorteo_id) do
    SorteoServer.ejecutar(sorteo_id)
  end

  def comprar_fracciones_restantes(sorteo_id, numero, cliente_doc) do
    SorteoServer.comprar_fracciones_restantes(sorteo_id, numero, cliente_doc)
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp generar_billetes(cantidad) do
    Enum.map(1..cantidad, fn i ->
      %{"numero" => 1000 + i, "disponible" => true}
    end)
  end

  # Encuentra los ganadores de un sorteo buscando nombres en la lista de clientes
  defp encontrar_ganadores(sorteo, clientes) do
    billete = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))

    if billete && sorteo.premio do
      valor_fraccion =
        if sorteo.cantidad_fracciones > 0,
          do: div(sorteo.premio.valor, sorteo.cantidad_fracciones),
          else: 0

      case billete["tipo"] do
        "completo" ->
          doc = billete["propietario_doc"]
          nombre = buscar_nombre(doc, clientes)

          [
            %{
              nombre: nombre,
              documento: doc,
              billete: billete["numero"],
              fraccion: nil,
              valor: sorteo.premio.valor
            }
          ]

        "fraccion" ->
          (billete["fracciones_tomadas"] || [])
          |> Enum.map(fn f ->
            nombre = buscar_nombre(f["propietario_doc"], clientes)

            %{
              nombre: nombre,
              documento: f["propietario_doc"],
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
  end

  defp buscar_nombre(doc, clientes) do
    case Enum.find(clientes, &(&1.documento == doc)) do
      nil -> "Desconocido (#{doc})"
      cliente -> cliente.nombre
    end
  end
end
