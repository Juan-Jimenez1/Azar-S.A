defmodule AzarApp.SorteoServer do
  @moduledoc """
  GenServer responsable de un sorteo específico.
  Carga su estado desde JsonStore al arrancar y persiste
  cada cambio en disco inmediatamente.

  Se registra en el Registry bajo su propio id:
    {:via, Registry, {AzarApp.SorteoRegistry, sorteo_id}}
  """

  use GenServer
  alias AzarApp.JsonStore

  # ── API pública ────────────────────────────────────────────────────────────

  @doc "Arranca un SorteoServer para el sorteo dado."
  def start_link(sorteo_id) do
    GenServer.start_link(__MODULE__, sorteo_id, name: via(sorteo_id))
  end

  @doc "Devuelve el estado completo del sorteo."
  def get(sorteo_id),
    do: GenServer.call(via(sorteo_id), :get)

  @doc "Actualiza campos del sorteo. Recibe un mapa con los campos a mergear."
  def update(sorteo_id, campos),
    do: GenServer.call(via(sorteo_id), {:update, campos})

  @doc "Compra un billete completo para un cliente."
  def comprar_billete(sorteo_id, numero_billete, cliente_doc),
    do: GenServer.call(via(sorteo_id), {:comprar_billete, numero_billete, cliente_doc})

  @doc "Compra una fracción de un billete."
  def comprar_fraccion(sorteo_id, numero_billete, fraccion, cliente_doc),
    do: GenServer.call(via(sorteo_id), {:comprar_fraccion, numero_billete, fraccion, cliente_doc})

  @doc "Devuelve una compra (solo si el sorteo no se ha realizado)."
  def devolver_compra(sorteo_id, numero_billete, cliente_doc),
    do: GenServer.call(via(sorteo_id), {:devolver_compra, numero_billete, cliente_doc})

  @doc "Ejecuta el sorteo: asigna números ganadores al azar."
  def ejecutar(sorteo_id),
    do: GenServer.call(via(sorteo_id), :ejecutar)

  @doc "Devuelve los billetes disponibles (completos y fracciones)."
  def billetes_disponibles(sorteo_id),
    do: GenServer.call(via(sorteo_id), :billetes_disponibles)

  # ── Callbacks GenServer ────────────────────────────────────────────────────

  @impl true
  def init(sorteo_id) do
    case JsonStore.get(:sorteos, sorteo_id) do
      {:ok, sorteo} ->
        {:ok, sorteo}

      :error ->
        {:stop, {:sorteo_no_encontrado, sorteo_id}}
    end
  end

  @impl true
  def handle_call(:get, _from, sorteo) do
    {:reply, {:ok, sorteo}, sorteo}
  end

  @impl true
  def handle_call({:update, campos}, _from, sorteo) do
    nuevo = Map.merge(sorteo, campos)
    JsonStore.upsert(:sorteos, nuevo)
    {:reply, {:ok, nuevo}, nuevo}
  end

  @impl true
  def handle_call({:comprar_billete, numero, cliente_doc}, _from, sorteo) do
    if sorteo["realizado"] do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      billetes = sorteo["billetes"]

      case encontrar_billete(billetes, numero) do
        nil ->
          {:reply, {:error, "Billete #{numero} no existe"}, sorteo}

        %{"disponible" => false} ->
          {:reply, {:error, "Billete #{numero} no está disponible"}, sorteo}

        billete ->
          nuevo_billete = billete
            |> Map.put("disponible", false)
            |> Map.put("propietario_doc", cliente_doc)
            |> Map.put("tipo", "completo")

          nuevos_billetes = reemplazar_billete(billetes, nuevo_billete)
          nuevo_sorteo    = Map.put(sorteo, "billetes", nuevos_billetes)

          JsonStore.upsert(:sorteos, nuevo_sorteo)
          {:reply, {:ok, nuevo_billete}, nuevo_sorteo}
      end
    end
  end

  @impl true
  def handle_call({:comprar_fraccion, numero, fraccion, cliente_doc}, _from, sorteo) do
    if sorteo["realizado"] do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      billetes           = sorteo["billetes"]
      max_fracciones     = sorteo["cantidad_fracciones"]

      case encontrar_billete(billetes, numero) do
        nil ->
          {:reply, {:error, "Billete #{numero} no existe"}, sorteo}

        %{"tipo" => "completo"} ->
          {:reply, {:error, "Billete #{numero} ya fue vendido completo"}, sorteo}

        billete ->
          fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])

          cond do
            fraccion < 1 or fraccion > max_fracciones ->
              {:reply, {:error, "Fracción inválida. Debe estar entre 1 y #{max_fracciones}"}, sorteo}

            fraccion in fracciones_tomadas ->
              {:reply, {:error, "Fracción #{fraccion} ya está vendida"}, sorteo}

            true ->
              nuevas_fracciones = fracciones_tomadas ++ [%{
                "fraccion"        => fraccion,
                "propietario_doc" => cliente_doc
              }]

              disponible = length(nuevas_fracciones) < max_fracciones

              nuevo_billete = billete
                |> Map.put("disponible", disponible)
                |> Map.put("tipo", "fraccion")
                |> Map.put("fracciones_tomadas", nuevas_fracciones)

              nuevos_billetes = reemplazar_billete(billetes, nuevo_billete)
              nuevo_sorteo    = Map.put(sorteo, "billetes", nuevos_billetes)

              JsonStore.upsert(:sorteos, nuevo_sorteo)
              {:reply, {:ok, nuevo_billete}, nuevo_sorteo}
          end
      end
    end
  end

  @impl true
  def handle_call({:devolver_compra, numero, cliente_doc}, _from, sorteo) do
    if sorteo["realizado"] do
      {:reply, {:error, "No se puede devolver: el sorteo ya fue realizado"}, sorteo}
    else
      billetes = sorteo["billetes"]

      case encontrar_billete(billetes, numero) do
        nil ->
          {:reply, {:error, "Billete #{numero} no existe"}, sorteo}

        %{"propietario_doc" => doc} when doc != cliente_doc ->
          {:reply, {:error, "Este billete no pertenece al cliente"}, sorteo}

        billete ->
          nuevo_billete = billete
            |> Map.put("disponible", true)
            |> Map.delete("propietario_doc")
            |> Map.delete("tipo")
            |> Map.delete("fracciones_tomadas")

          nuevos_billetes = reemplazar_billete(billetes, nuevo_billete)
          nuevo_sorteo    = Map.put(sorteo, "billetes", nuevos_billetes)

          JsonStore.upsert(:sorteos, nuevo_sorteo)
          {:reply, :ok, nuevo_sorteo}
      end
    end
  end

  @impl true
  def handle_call(:ejecutar, _from, sorteo) do
    if sorteo["realizado"] do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      billetes_vendidos = Enum.filter(sorteo["billetes"], &(!&1["disponible"]))
      numeros           = Enum.map(billetes_vendidos, & &1["numero"])
      cantidad_premios  = length(sorteo["premios"])

      ganadores =
        numeros
        |> Enum.shuffle()
        |> Enum.take(cantidad_premios)

      nuevo_sorteo = sorteo
        |> Map.put("realizado", true)
        |> Map.put("numeros_ganadores", ganadores)

      JsonStore.upsert(:sorteos, nuevo_sorteo)
      {:reply, {:ok, ganadores}, nuevo_sorteo}
    end
  end

  @impl true
  def handle_call(:billetes_disponibles, _from, sorteo) do
    disponibles = Enum.filter(sorteo["billetes"], & &1["disponible"])
    {:reply, {:ok, disponibles}, sorteo}
  end

  # ── Helpers privados ───────────────────────────────────────────────────────

  defp via(sorteo_id),
    do: {:via, Registry, {AzarApp.SorteoRegistry, sorteo_id}}

  defp encontrar_billete(billetes, numero),
    do: Enum.find(billetes, &(&1["numero"] == numero))

  defp reemplazar_billete(billetes, billete_nuevo) do
    Enum.map(billetes, fn b ->
      if b["numero"] == billete_nuevo["numero"], do: billete_nuevo, else: b
    end)
  end
end
