defmodule AzarAppWeb.Admin.SorteoController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  # GET /admin/sorteos
  def index(conn, _params) do
    sorteos = Sorteos.listar_sorteos()
    render(conn, :index, sorteos: sorteos)
  end

  # GET /admin/sorteos/nuevo
  def new(conn, _params) do
    render(conn, :new)
  end

  # POST /admin/sorteos
  def create(conn, %{"sorteo" => params}) do
    # Convertimos los valores numéricos que vienen como string del form
    params = %{
      "nombre"               => params["nombre"],
      "fecha"                => params["fecha"],
      "valor_billete"        => String.to_integer(params["valor_billete"]),
      "cantidad_fracciones"  => String.to_integer(params["cantidad_fracciones"]),
      "cantidad_billetes"    => String.to_integer(params["cantidad_billetes"])
    }

    {:ok, sorteo} = Sorteos.crear_sorteo(params)
    conn
    |> put_flash(:info, "Sorteo '#{sorteo["nombre"]}' creado correctamente.")
    |> redirect(to: ~p"/admin/sorteos")
  end

  # GET /admin/sorteos/:id
  def show(conn, %{"id" => id}) do
    case Sorteos.get_sorteo(id) do
      {:ok, sorteo} ->
        {:ok, ingresos} = Sorteos.ingresos_por_sorteo(id)
        clientes        = Sorteos.clientes_por_sorteo(id)
        render(conn, :show, sorteo: sorteo, ingresos: ingresos, clientes: clientes)

      :error ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/admin/sorteos")
    end
  end

  # DELETE /admin/sorteos/:id
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
end
