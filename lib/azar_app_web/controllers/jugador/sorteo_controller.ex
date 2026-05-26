defmodule AzarAppWeb.Jugador.SorteoController do
  @moduledoc "Controlador de navegación de sorteos para el jugador."

  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  @doc """
  Muestra el catálogo de sorteos disponibles junto con estadísticas del sistema:
  jackpot del día, top 3 ganadores, compradores y suertudos.
  """
  def index(conn, _params) do
    sorteos     = Sorteos.listar_sorteos_disponibles()
    cliente     = conn.assigns.cliente_actual
    jackpot     = AzarApp.Estadisticas.jackpot_del_dia(sorteos)
    top_ganadores   = AzarApp.Estadisticas.top_ganadores()
    top_compradores = AzarApp.Estadisticas.top_compradores()
    top_suertudos   = AzarApp.Estadisticas.top_suertudos()

    render(conn, :index,
      sorteos:          sorteos,
      cliente:          cliente,
      jackpot:          jackpot,
      top_ganadores:    top_ganadores,
      top_compradores:  top_compradores,
      top_suertudos:    top_suertudos
    )
  end

  @doc "Muestra el detalle de un sorteo con los billetes disponibles y los del cliente."
  def show(conn, %{"id" => id}) do
    case Sorteos.get_sorteo(id) do
      {:ok, sorteo} ->
        {:ok, billetes}       = Sorteos.billetes_disponibles(id)
        cliente_doc           = get_session(conn, :cliente_doc)
        billetes_del_cliente  = Sorteos.billetes_del_cliente(id, cliente_doc)

        render(conn, :show,
          sorteo:              sorteo,
          billetes:            billetes,
          cliente_doc:         cliente_doc,
          billetes_del_cliente: billetes_del_cliente
        )

      :error ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/")
    end
  end
end
