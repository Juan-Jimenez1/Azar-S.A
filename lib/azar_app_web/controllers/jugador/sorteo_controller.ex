defmodule AzarAppWeb.Jugador.SorteoController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos
  

  def index(conn, _params) do
    sorteos = Sorteos.listar_sorteos_disponibles()
    cliente_doc = get_session(conn, :cliente_doc)

    cliente =
      if cliente_doc do
        case AzarApp.Clientes.get_cliente(cliente_doc) do
          {:ok, c} -> c
          _ -> nil
        end
      end

    jackpot = AzarApp.Estadisticas.jackpot_del_dia(sorteos)
    top_ganadores = AzarApp.Estadisticas.top_ganadores()
    top_compradores = AzarApp.Estadisticas.top_compradores()
    top_suertudos = AzarApp.Estadisticas.top_suertudos()

    render(conn, :index,
      sorteos: sorteos,
      cliente: cliente,
      jackpot: jackpot,
      top_ganadores: top_ganadores,
      top_compradores: top_compradores,
      top_suertudos: top_suertudos
    )
  end

  def show(conn, %{"id" => id}) do
    case Sorteos.get_sorteo(id) do
      {:ok, sorteo} ->
        {:ok, billetes} = Sorteos.billetes_disponibles(id)
        cliente_doc = get_session(conn, :cliente_doc)
        billetes_del_cliente = Sorteos.billetes_del_cliente(id, cliente_doc)

        render(conn, :show,
          sorteo: sorteo,
          billetes: billetes,
          cliente_doc: cliente_doc,
          billetes_del_cliente: billetes_del_cliente
        )

      :error ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/index")
    end
  end
end
