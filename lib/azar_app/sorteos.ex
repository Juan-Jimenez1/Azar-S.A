defmodule AzarApp.Sorteos do
  @moduledoc """
  Context principal de sorteos.
  Única puerta de entrada para toda la lógica de sorteos.
  Los controllers solo hablan con este módulo.
  """

  alias AzarApp.{JsonStore, SorteoServer, SorteoSupervisor}

  # ── Gestión de sorteos ─────────────────────────────────────────────────────

  @doc "Devuelve todos los sorteos ordenados por fecha."
  def listar_sorteos do
    JsonStore.all(:sorteos)
    |> Enum.sort_by(& &1["fecha"])
  end

  @doc "Devuelve solo los sorteos que aún no se han realizado."
  def listar_sorteos_disponibles do
    listar_sorteos()
    |> Enum.reject(& &1["realizado"])
  end

  @doc "Devuelve un sorteo por id."
  def get_sorteo(id) do
    JsonStore.get(:sorteos, id)
  end

  @doc """
  Crea un nuevo sorteo y levanta su GenServer.
  Genera los billetes automáticamente según cantidad_billetes.
  """
  def crear_sorteo(params) do
    id      = JsonStore.generar_id("sorteo")
    billetes = generar_billetes(params["cantidad_billetes"])

    sorteo = %{
      "id"                  => id,
      "nombre"              => params["nombre"],
      "fecha"               => params["fecha"],
      "valor_billete"       => params["valor_billete"],
      "cantidad_fracciones" => params["cantidad_fracciones"],
      "cantidad_billetes"   => params["cantidad_billetes"],
      "realizado"           => false,
      "numeros_ganadores"   => [],
      "billetes"            => billetes,
      "premios"             => []
    }

    JsonStore.upsert(:sorteos, sorteo)
    SorteoSupervisor.start_sorteo(id)

    {:ok, sorteo}
  end

  @doc """
  Elimina un sorteo. Solo si no tiene premios asociados.
  """
  def eliminar_sorteo(id) do
    case get_sorteo(id) do
      {:ok, sorteo} ->
        premios = Map.get(sorteo, "premios", [])

        if premios != [] do
          {:error, "No se puede eliminar: el sorteo tiene premios asociados"}
        else
          JsonStore.delete(:sorteos, id)
        end

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  # ── Gestión de premios ─────────────────────────────────────────────────────

  @doc "Agrega un premio a un sorteo."
  def crear_premio(sorteo_id, params) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        premio = %{
          "id"     => JsonStore.generar_id("premio"),
          "nombre" => params["nombre"],
          "valor"  => params["valor"]
        }

        premios_actualizados = sorteo["premios"] ++ [premio]
        SorteoServer.update(sorteo_id, %{"premios" => premios_actualizados})
        {:ok, premio}

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  @doc "Elimina un premio. Solo si el sorteo no tiene clientes."
  def eliminar_premio(sorteo_id, premio_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        tiene_clientes = Enum.any?(sorteo["billetes"], &(!&1["disponible"]))

        if tiene_clientes do
          {:error, "No se puede eliminar: el sorteo ya tiene compradores"}
        else
          premios = Enum.reject(sorteo["premios"], &(&1["id"] == premio_id))
          SorteoServer.update(sorteo_id, %{"premios" => premios})
          :ok
        end

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  # ── Compras ────────────────────────────────────────────────────────────────

  @doc "Compra un billete completo para un jugador."
  def comprar_billete(sorteo_id, numero, cliente_doc) do
    SorteoServer.comprar_billete(sorteo_id, numero, cliente_doc)
  end

  @doc "Compra una fracción de billete para un jugador."
  def comprar_fraccion(sorteo_id, numero, fraccion, cliente_doc) do
    SorteoServer.comprar_fraccion(sorteo_id, numero, fraccion, cliente_doc)
  end

  @doc "Devuelve una compra. Solo si el sorteo no se ha realizado."
  def devolver_compra(sorteo_id, numero, cliente_doc) do
    SorteoServer.devolver_compra(sorteo_id, numero, cliente_doc)
  end

  @doc "Devuelve los billetes disponibles de un sorteo."
  def billetes_disponibles(sorteo_id) do
    SorteoServer.billetes_disponibles(sorteo_id)
  end

  # ── Clientes ───────────────────────────────────────────────────────────────

  @doc """
  Devuelve los clientes de un sorteo agrupados en:
    - compradores_completo: compraron el billete entero
    - compradores_fraccion: compraron fracciones

  Ordenados alfabéticamente por documento dentro de cada grupo.
  """
  def clientes_por_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        billetes_vendidos = Enum.reject(sorteo["billetes"], & &1["disponible"])

        # Compradores de billete completo
        completos =
          billetes_vendidos
          |> Enum.filter(&(&1["tipo"] == "completo"))
          |> Enum.map(fn b ->
            %{
              "doc"     => b["propietario_doc"],
              "billete" => b["numero"]
            }
          end)
          |> Enum.sort_by(& &1["doc"])

        # Compradores por fracción — puede haber varios por billete
        fracciones =
          billetes_vendidos
          |> Enum.filter(&(&1["tipo"] == "fraccion"))
          |> Enum.flat_map(fn b ->
            Enum.map(b["fracciones_tomadas"], fn f ->
              %{
                "doc"      => f["propietario_doc"],
                "billete"  => b["numero"],
                "fraccion" => f["fraccion"]
              }
            end)
          end)
          |> Enum.sort_by(& &1["doc"])

        {:ok, %{
          "compradores_completo" => completos,
          "compradores_fraccion" => fracciones
        }}

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  # ── Ejecución del sorteo ───────────────────────────────────────────────────

  @doc """
  Ejecuta todos los sorteos cuya fecha ya pasó y no se han realizado.
  Notifica a los ganadores via PubSub.
  """
  def ejecutar_sorteos_pendientes do
    hoy = Date.utc_today() |> Date.to_string()

    listar_sorteos()
    |> Enum.filter(fn s ->
      !s["realizado"] and s["fecha"] <= hoy
    end)
    |> Enum.map(fn s ->
      {:ok, ganadores} = SorteoServer.ejecutar(s["id"])
      notificar_ganadores(s, ganadores)
      {s["id"], ganadores}
    end)
  end

  # ── Consultas financieras ──────────────────────────────────────────────────

  @doc "Total recaudado por un sorteo."
  def ingresos_por_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        vendidos = Enum.count(sorteo["billetes"], &(!&1["disponible"]))
        total    = vendidos * sorteo["valor_billete"]
        {:ok, total}

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  @doc "Ganancias o pérdidas de un sorteo ya realizado."
  def balance_sorteo(sorteo_id) do
    case get_sorteo(sorteo_id) do
      {:ok, %{"realizado" => false}} ->
        {:error, "El sorteo aún no se ha realizado"}

      {:ok, sorteo} ->
        {:ok, ingresos} = ingresos_por_sorteo(sorteo_id)
        total_premios   = sorteo["premios"] |> Enum.map(& &1["valor"]) |> Enum.sum()
        balance         = ingresos - total_premios

        {:ok, %{
          "ingresos"      => ingresos,
          "total_premios" => total_premios,
          "balance"       => balance,
          "resultado"     => if(balance >= 0, do: "ganancia", else: "pérdida")
        }}

      :error ->
        {:error, "Sorteo no encontrado"}
    end
  end

  @doc "Balance acumulado de todos los sorteos realizados."
  def balance_total do
    listar_sorteos()
    |> Enum.filter(& &1["realizado"])
    |> Enum.map(fn s ->
      {:ok, balance} = balance_sorteo(s["id"])
      Map.put(balance, "sorteo", s["nombre"])
    end)
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp generar_billetes(cantidad) do
    Enum.map(1..cantidad, fn i ->
      %{"numero" => 1000 + i, "disponible" => true}
    end)
  end

  defp notificar_ganadores(sorteo, numeros_ganadores) do
    numeros_ganadores
    |> Enum.with_index()
    |> Enum.each(fn {numero, idx} ->
      billete = Enum.find(sorteo["billetes"], &(&1["numero"] == numero))
      premio  = Enum.at(sorteo["premios"], idx)

      if billete && premio do
        Phoenix.PubSub.broadcast(
          AzarApp.PubSub,
          "jugador:#{billete["propietario_doc"]}",
          {:premio_ganado, %{
            "sorteo"  => sorteo["nombre"],
            "billete" => numero,
            "premio"  => premio["nombre"],
            "valor"   => premio["valor"]
          }}
        )
      end
    end)
  end
end
