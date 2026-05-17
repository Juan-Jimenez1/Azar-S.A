defmodule AzarAppWeb.Jugador.SorteoController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos
  alias AzarApp.Clientes

  def index(conn, _params) do
  sorteos = Sorteos.listar_sorteos_disponibles()
  cliente_doc = get_session(conn, :cliente_doc)
  cliente =
    if cliente_doc do
      case Clientes.get_cliente(cliente_doc) do
        {:ok, c} -> c
        _ -> nil
      end
    end
  render(conn, :index, sorteos: sorteos, cliente: cliente)
  end


  def show(conn, %{"id" => id}) do
  case Sorteos.get_sorteo(id) do
    {:ok, sorteo} ->
      {:ok, billetes} = Sorteos.billetes_disponibles(id)
      cliente_doc = get_session(conn, :cliente_doc)
      render(conn, :show, sorteo: sorteo, billetes: billetes, cliente_doc: cliente_doc)

    :error ->
      conn
      |> put_flash(:error, "Sorteo no encontrado.")
      |> redirect(to: ~p"/")
  end
end
end
