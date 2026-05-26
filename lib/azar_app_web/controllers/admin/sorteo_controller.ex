defmodule AzarAppWeb.Admin.SorteoController do
  @moduledoc "Controlador de sorteos para el panel de administración."

  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  @doc "Lista todos los sorteos del sistema (realizados y pendientes)."
  def index(conn, _params) do
  sorteos = Sorteos.listar_sorteos()
  render(conn, :index, sorteos: sorteos)
end

  @doc "Renderiza el formulario de creación de un nuevo sorteo."
  def new(conn, _params) do
    render(conn, :new)
  end

  @doc "Procesa el formulario y crea el sorteo con los billetes iniciales."
  def create(conn, %{"sorteo" => params}) do
    params = %{
      "nombre"              => params["nombre"],
      "fecha"               => params["fecha"],
      "valor_billete"       => String.to_integer(params["valor_billete"]),
      "cantidad_fracciones" => String.to_integer(params["cantidad_fracciones"]),
      "cantidad_billetes"   => String.to_integer(params["cantidad_billetes"])
    }

    {:ok, sorteo} = Sorteos.crear_sorteo(params)

    conn
    |> put_flash(:info, "Sorteo '#{sorteo.nombre}' creado correctamente.")
    |> redirect(to: ~p"/admin/sorteos")
  end

  @doc "Muestra el detalle del sorteo: ingresos, compradores, ganador y estado."
  def show(conn, %{"id" => id}) do
    case Sorteos.get_sorteo(id) do
      {:ok, sorteo} ->
        {:ok, ingresos} = Sorteos.ingresos_por_sorteo(id)
        {:ok, clientes} = Sorteos.clientes_por_sorteo(id)

        ganador_nombre =
          if sorteo.realizado and sorteo.numero_ganador do
            billete = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))
            clientes_todos = AzarApp.JsonStore.all(:clientes)

            case billete["tipo"] do
              "completo" ->
                c = Enum.find(clientes_todos, &(&1.documento == billete["propietario_doc"]))
                if c, do: c.nombre, else: billete["propietario_doc"]

              "fraccion" ->
                docs = billete |> Map.get("fracciones_tomadas", []) |> Enum.map(& &1["propietario_doc"]) |> Enum.uniq()
                docs
                |> Enum.map(fn doc ->
                  c = Enum.find(clientes_todos, &(&1.documento == doc))
                  if c, do: c.nombre, else: doc
                end)
                |> Enum.join(", ")

              _ -> "—"
            end
          end

        render(conn, :show,
          sorteo:         sorteo,
          ingresos:       ingresos,
          clientes:       clientes,
          ganador_nombre: ganador_nombre
        )

      :error ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/admin/sorteos")
    end
  end

  @doc "Elimina el sorteo. Solo es posible si no tiene premio asignado."
  def delete(conn, %{"id" => id}) do
    case Sorteos.eliminar_sorteo(id) do
      :ok ->
        conn
        |> put_flash(:info, "Sorteo eliminado correctamente.")
        |> redirect(to: ~p"/admin/sorteos")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/admin/sorteos/#{id}")
    end
  end

  @doc "Reporte de premios entregados en sorteos pasados. Acepta parámetro `orden` (`\"asc\"` o `\"desc\"`)."
  def premios_entregados(conn, params) do
    orden = Map.get(params, "orden", "asc")
    premios = Sorteos.premios_entregados(orden)
    render(conn, :premios_entregados, premios: premios)
  end

  @doc "Muestra el balance financiero global: ingresos, premios y ganancia neta de todos los sorteos realizados."
  def balance(conn, _params) do
  balance        = Sorteos.balance_sorteos_pasados()
  total_ingresos = Enum.reduce(balance, 0, &(&1.ingresos + &2))
  total_premios  = Enum.reduce(balance, 0, &(&1.valor_premio + &2))
  total_ganancia = total_ingresos - total_premios

  render(conn, :balance,
    balance:        balance,
    total_ingresos: total_ingresos,
    total_premios:  total_premios,
    total_ganancia: total_ganancia
  )
end
end
