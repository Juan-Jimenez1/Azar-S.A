defmodule AzarAppWeb.Jugador.SorteoController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  # GET /
  # Lista solo los sorteos disponibles (no realizados)
  def index(conn, _params) do
    sorteos = Sorteos.listar_sorteos_disponibles()
    render(conn, :index, sorteos: sorteos)
  end

  # GET /sorteos/:id
  # Detalle del sorteo con billetes disponibles
  def show(conn, %{"id" => id}) do
    case Sorteos.get_sorteo(id) do
      {:ok, sorteo} ->
        {:ok, billetes} = Sorteos.billetes_disponibles(id)
        render(conn, :show, sorteo: sorteo, billetes: billetes)

      :error ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/")
    end
  end
end
