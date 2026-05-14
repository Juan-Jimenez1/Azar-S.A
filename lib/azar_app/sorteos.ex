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
      id:                  id,
      nombre:              params["nombre"],
      fecha:               params["fecha"],
      valor_billete:       params["valor_billete"],
      cantidad_fracciones: params["cantidad_fracciones"],
      cantidad_billetes:   params["cantidad_billetes"],
      realizado:           false,
      numero_ganador:      nil,
      premio:              nil,
      billetes:            generar_billetes(params["cantidad_billetes"])
    }

    JsonStore.upsert(:sorteos, sorteo)
    SorteoSupervisor.start_sorteo(id)
    {:ok, sorteo}
  end

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

  # ── Gestión de premio ──────────────────────────────────────────────────────

  def crear_premio(sorteo_id, params) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        if sorteo.premio != nil do
          {:error, "El sorteo ya tiene un premio asignado"}
        else
          premio = %Premio{
            id:     JsonStore.generar_id("premio"),
            nombre: params["nombre"],
            valor:  params["valor"]
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
        billetes_vendidos = Enum.reject(sorteo.billetes, & &1["disponible"])

        completos =
          billetes_vendidos
          |> Enum.filter(&(&1["tipo"] == "completo"))
          |> Enum.map(fn b -> %{doc: b["propietario_doc"], billete: b["numero"]} end)
          |> Enum.sort_by(& &1.doc)

        fracciones =
          billetes_vendidos
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
    |> Enum.map(fn s ->
      {:ok, ganador} = SorteoServer.ejecutar(s.id)
      {s.id, ganador}
    end)
  end

  # ── Consultas financieras ──────────────────────────────────────────────────

  def ingresos_por_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        vendidos = Enum.count(sorteo.billetes, &(!&1["disponible"]))
        {:ok, vendidos * sorteo.valor_billete}

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
        valor_premio    = if sorteo.premio, do: sorteo.premio.valor, else: 0
        balance         = ingresos - valor_premio

        {:ok, %{
          ingresos:     ingresos,
          valor_premio: valor_premio,
          balance:      balance,
          resultado:    if(balance >= 0, do: "ganancia", else: "pérdida")
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
      Map.put(balance, :sorteo, s.nombre)
    end)
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp generar_billetes(cantidad) do
    Enum.map(1..cantidad, fn i ->
      %{"numero" => 1000 + i, "disponible" => true}
    end)
  end
end
