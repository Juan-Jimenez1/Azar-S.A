defmodule AzarAppWeb.Jugador.TarjetaController do
  use AzarAppWeb, :controller
  alias AzarApp.Clientes

  def index(conn, %{"valor" => valor}) do
    render(conn, :index, valor: valor)
  end

  def procesar(conn, params) do
    conn
    |> put_session(:tarjeta_pendiente, %{
      valor:    params["valor"],
      nombre:   params["nombre"],
      numero:   params["numero"] |> String.slice(-4, 4),
      tipo:     params["tipo"] || "Crédito"
    })
    |> redirect(to: ~p"/tarjeta/cargando")
  end

  def cargando(conn, _params) do
    render(conn, :cargando)
  end

  def exito(conn, _params) do
    pendiente   = get_session(conn, :tarjeta_pendiente)
    cliente_doc = get_session(conn, :cliente_doc)
    valor_int   = String.to_integer(pendiente.valor)

    {:ok, cliente} = Clientes.recargar_saldo(cliente_doc, valor_int)

    conn
    |> delete_session(:tarjeta_pendiente)
    |> render(:exito, info: %{
      valor:  valor_int,
      nombre: pendiente.nombre,
      numero: pendiente.numero,
      tipo:   pendiente.tipo,
      saldo:  cliente.saldo
    })
  end
end
