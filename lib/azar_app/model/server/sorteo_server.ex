defmodule AzarApp.SorteoServer do
  use GenServer
  alias AzarApp.{JsonStore, Clientes}

  def start_link(sorteo_id) do
    GenServer.start_link(__MODULE__, sorteo_id, name: via(sorteo_id))
  end

  def get(sorteo_id),
    do: GenServer.call(via(sorteo_id), :get)

  def update(sorteo_id, campos),
    do: GenServer.call(via(sorteo_id), {:update, campos})

  def comprar_billete(sorteo_id, numero_billete, cliente_doc),
    do: GenServer.call(via(sorteo_id), {:comprar_billete, numero_billete, cliente_doc})

  def comprar_fracciones_restantes(sorteo_id, numero_billete, cliente_doc),
    do: GenServer.call(via(sorteo_id), {:comprar_fracciones_restantes, numero_billete, cliente_doc})

  def comprar_fraccion(sorteo_id, numero_billete, fraccion, cliente_doc),
    do: GenServer.call(via(sorteo_id), {:comprar_fraccion, numero_billete, fraccion, cliente_doc})

  def devolver_compra(sorteo_id, numero_billete, cliente_doc),
    do: GenServer.call(via(sorteo_id), {:devolver_compra, numero_billete, cliente_doc})

  def ejecutar(sorteo_id),
    do: GenServer.call(via(sorteo_id), :ejecutar)

  def billetes_disponibles(sorteo_id),
    do: GenServer.call(via(sorteo_id), :billetes_disponibles)

  # ── Init ───────────────────────────────────────────────────────────────────

  @impl true
  def init(sorteo_id) do
    case JsonStore.get(:sorteos, sorteo_id) do
      {:ok, sorteo} -> {:ok, sorteo}
      :error        -> {:stop, {:sorteo_no_encontrado, sorteo_id}}
    end
  end

  # ── Callbacks ──────────────────────────────────────────────────────────────

  @impl true
  def handle_call(:get, _from, sorteo) do
    {:reply, {:ok, sorteo}, sorteo}
  end

  @impl true
  def handle_call({:update, campos}, _from, sorteo) do
    nuevo = struct(sorteo, campos)
    JsonStore.upsert(:sorteos, nuevo)
    {:reply, {:ok, nuevo}, nuevo}
  end

  @impl true
  def handle_call({:comprar_billete, numero, cliente_doc}, _from, sorteo) do
    if sorteo.realizado do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      case encontrar_billete(sorteo.billetes, numero) do
        nil ->
          {:reply, {:error, "Billete #{numero} no existe"}, sorteo}

        %{"tipo" => "completo"} ->
          {:reply, {:error, "Billete #{numero} ya fue vendido completo"}, sorteo}

        billete ->
          fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])

          if fracciones_tomadas != [] do
            {:reply,
             {:error, "Billete #{numero} tiene fracciones vendidas. Usa 'comprar fracciones restantes'."},
             sorteo}
          else
            nuevo_billete =
              billete
              |> Map.put("disponible", false)
              |> Map.put("propietario_doc", cliente_doc)
              |> Map.put("tipo", "completo")

            nuevo_sorteo = %{sorteo | billetes: reemplazar_billete(sorteo.billetes, nuevo_billete)}
            JsonStore.upsert(:sorteos, nuevo_sorteo)
            {:reply, {:ok, nuevo_billete}, nuevo_sorteo}
          end
      end
    end
  end

  @impl true
  def handle_call({:comprar_fracciones_restantes, numero, cliente_doc}, _from, sorteo) do
    if sorteo.realizado do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      case encontrar_billete(sorteo.billetes, numero) do
        nil ->
          {:reply, {:error, "Billete #{numero} no existe"}, sorteo}

        %{"tipo" => "completo"} ->
          {:reply, {:error, "Billete #{numero} ya fue vendido completo"}, sorteo}

        billete ->
          fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])
          nums_tomados       = Enum.map(fracciones_tomadas, & &1["fraccion"])
          todas              = Enum.to_list(1..sorteo.cantidad_fracciones)
          fracciones_libres  = Enum.reject(todas, &(&1 in nums_tomados))

          if fracciones_libres == [] do
            {:reply, {:error, "No hay fracciones disponibles en el billete #{numero}"}, sorteo}
          else
            nuevas = Enum.map(fracciones_libres, fn f ->
              %{"fraccion" => f, "propietario_doc" => cliente_doc}
            end)

            todas_fracciones = fracciones_tomadas ++ nuevas

            nuevo_billete =
              billete
              |> Map.put("disponible", false)
              |> Map.put("tipo", "fraccion")
              |> Map.put("fracciones_tomadas", todas_fracciones)

            nuevo_sorteo = %{sorteo | billetes: reemplazar_billete(sorteo.billetes, nuevo_billete)}
            JsonStore.upsert(:sorteos, nuevo_sorteo)
            # Retorna {billete, cantidad} para que el controlador pueda mostrar cuántas se compraron
            {:reply, {:ok, nuevo_billete, length(fracciones_libres)}, nuevo_sorteo}
          end
      end
    end
  end

  @impl true
  def handle_call({:comprar_fraccion, numero, fraccion, cliente_doc}, _from, sorteo) do
    if sorteo.realizado do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      case encontrar_billete(sorteo.billetes, numero) do
        nil ->
          {:reply, {:error, "Billete #{numero} no existe"}, sorteo}

        %{"tipo" => "completo"} ->
          {:reply, {:error, "Billete #{numero} ya fue vendido completo"}, sorteo}

        billete ->
          fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])
          nums_tomados       = Enum.map(fracciones_tomadas, & &1["fraccion"])

          cond do
            fraccion < 1 or fraccion > sorteo.cantidad_fracciones ->
              {:reply,
               {:error, "Fracción inválida. Debe estar entre 1 y #{sorteo.cantidad_fracciones}"},
               sorteo}

            fraccion in nums_tomados ->
              {:reply, {:error, "Fracción #{fraccion} ya está vendida"}, sorteo}

            true ->
              nuevas_fracciones =
                fracciones_tomadas ++ [%{"fraccion" => fraccion, "propietario_doc" => cliente_doc}]

              todas_tomadas = length(nuevas_fracciones) == sorteo.cantidad_fracciones

              nuevo_billete =
                billete
                |> Map.put("disponible", !todas_tomadas)
                |> Map.put("tipo", "fraccion")
                |> Map.put("fracciones_tomadas", nuevas_fracciones)

              nuevo_sorteo = %{sorteo | billetes: reemplazar_billete(sorteo.billetes, nuevo_billete)}
              JsonStore.upsert(:sorteos, nuevo_sorteo)
              {:reply, {:ok, nuevo_billete}, nuevo_sorteo}
          end
      end
    end
  end

  @impl true
  def handle_call({:devolver_compra, numero, cliente_doc}, _from, sorteo) do
    if sorteo.realizado do
      {:reply, {:error, "No se puede devolver: el sorteo ya fue realizado"}, sorteo}
    else
      case encontrar_billete(sorteo.billetes, numero) do
        nil ->
          {:reply, {:error, "Billete #{numero} no existe"}, sorteo}

        billete ->
          fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])
          es_propietario     = billete["propietario_doc"] == cliente_doc
          tiene_fraccion     = Enum.any?(fracciones_tomadas, &(&1["propietario_doc"] == cliente_doc))

          cond do
            billete["tipo"] == "completo" and es_propietario ->
              nuevo_billete =
                billete
                |> Map.put("disponible", true)
                |> Map.delete("propietario_doc")
                |> Map.delete("tipo")
                |> Map.delete("fracciones_tomadas")

              nuevo_sorteo = %{sorteo | billetes: reemplazar_billete(sorteo.billetes, nuevo_billete)}
              JsonStore.upsert(:sorteos, nuevo_sorteo)
              {:reply, :ok, nuevo_sorteo}

            billete["tipo"] == "fraccion" and tiene_fraccion ->
              nuevas_fracciones =
                Enum.reject(fracciones_tomadas, &(&1["propietario_doc"] == cliente_doc))

              nuevo_billete =
                if nuevas_fracciones == [] do
                  billete
                  |> Map.put("disponible", true)
                  |> Map.delete("tipo")
                  |> Map.delete("propietario_doc")
                  |> Map.put("fracciones_tomadas", [])
                else
                  billete
                  |> Map.put("disponible", true)
                  |> Map.put("fracciones_tomadas", nuevas_fracciones)
                end

              nuevo_sorteo = %{sorteo | billetes: reemplazar_billete(sorteo.billetes, nuevo_billete)}
              JsonStore.upsert(:sorteos, nuevo_sorteo)
              {:reply, :ok, nuevo_sorteo}

            true ->
              {:reply, {:error, "Este billete no pertenece al cliente"}, sorteo}
          end
      end
    end
  end

  @impl true
  def handle_call(:ejecutar, _from, sorteo) do
    if sorteo.realizado do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      billetes_vendidos = Enum.filter(sorteo.billetes, &(!&1["disponible"]))

      case billetes_vendidos do
        [] ->
          {:reply, {:error, "No hay billetes vendidos"}, sorteo}

        _ ->
          ganador      = billetes_vendidos |> Enum.random() |> Map.get("numero")
          nuevo_sorteo = %{sorteo | realizado: true, numero_ganador: ganador}
          JsonStore.upsert(:sorteos, nuevo_sorteo)

          notificar_a_participantes(nuevo_sorteo, ganador)
          notificar_ganador(nuevo_sorteo, ganador)

          {:reply, {:ok, ganador}, nuevo_sorteo}
      end
    end
  end

  @impl true
  def handle_call(:billetes_disponibles, _from, sorteo) do
    disponibles =
      Enum.filter(sorteo.billetes, fn billete ->
        case billete["tipo"] do
          "completo" ->
            false

          _ ->
            fracciones_tomadas = Map.get(billete, "fracciones_tomadas", [])
            length(fracciones_tomadas) < sorteo.cantidad_fracciones
        end
      end)

    {:reply, {:ok, disponibles}, sorteo}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp via(sorteo_id),
    do: {:via, Registry, {AzarApp.SorteoRegistry, sorteo_id}}

  defp encontrar_billete(billetes, numero),
    do: Enum.find(billetes, &(&1["numero"] == numero))

  defp reemplazar_billete(billetes, billete_nuevo) do
    Enum.map(billetes, fn b ->
      if b["numero"] == billete_nuevo["numero"], do: billete_nuevo, else: b
    end)
  end

  defp notificar_a_participantes(sorteo, numero_ganador) do
    docs =
      sorteo.billetes
      |> Enum.flat_map(fn b ->
        case b["tipo"] do
          "completo" -> [b["propietario_doc"]]
          "fraccion" -> Enum.map(b["fracciones_tomadas"] || [], & &1["propietario_doc"])
          _          -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    premio_txt =
      if sorteo.premio,
        do: "Premio: #{sorteo.premio.nombre} ($#{sorteo.premio.valor}).",
        else: ""

    Enum.each(docs, fn doc ->
      Clientes.agregar_notificacion(doc, %{
        tipo:   "sorteo_realizado",
        titulo: "Sorteo \"#{sorteo.nombre}\" finalizado",
        cuerpo: "El billete ganador fue el ##{numero_ganador}. #{premio_txt} Entra a ver tus resultados."
      })
    end)
  end

  defp notificar_ganador(sorteo, numero_ganador) do
    billete = Enum.find(sorteo.billetes, &(&1["numero"] == numero_ganador))

    if billete && sorteo.premio do
      case billete["tipo"] do
        "completo" ->
          acreditar_y_notificar(
            billete["propietario_doc"], sorteo, sorteo.premio.valor, numero_ganador
          )

        "fraccion" ->
          valor_fraccion = div(sorteo.premio.valor, sorteo.cantidad_fracciones)

          Enum.each(billete["fracciones_tomadas"], fn f ->
            acreditar_y_notificar(
              f["propietario_doc"], sorteo, valor_fraccion, numero_ganador, f["fraccion"]
            )
          end)
      end
    end
  end

  defp acreditar_y_notificar(cliente_doc, sorteo, valor, numero_billete, fraccion \\ nil) do
    Clientes.acreditar_saldo(cliente_doc, valor)

    cuerpo =
      if fraccion do
        "Billete ##{numero_billete} - Fraccion #{fraccion}: Ganaste $#{valor} en \"#{sorteo.nombre}\". Premio: #{sorteo.premio.nombre}."
      else
        "Billete ##{numero_billete} completo: Ganaste $#{valor} en \"#{sorteo.nombre}\". Premio: #{sorteo.premio.nombre}."
      end

    Clientes.agregar_notificacion(cliente_doc, %{
      tipo:   "premio",
      titulo: "Ganaste $#{valor} en #{sorteo.nombre}!",
      cuerpo: cuerpo
    })

    Phoenix.PubSub.broadcast(
      AzarApp.PubSub,
      "jugador:#{cliente_doc}",
      {:premio_ganado, %{sorteo: sorteo.nombre, premio: sorteo.premio.nombre, valor: valor}}
    )
  end
end
