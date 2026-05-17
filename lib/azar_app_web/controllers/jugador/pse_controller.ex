defmodule AzarAppWeb.Jugador.PseController do
  use AzarAppWeb, :controller
  alias AzarApp.Clientes

  @bancos [
    "Bancolombia", "Banco de Bogotá", "Davivienda",
    "BBVA Colombia", "Banco Popular", "Colpatria",
    "Banco de Occidente", "Nequi", "Daviplata",
    "Banco Falabella", "Scotiabank Colpatria"
  ]

  def index(conn, %{"valor" => valor}) do
    render(conn, :index, valor: valor, bancos: @bancos)
  end

  def procesar(conn, %{"valor" => valor, "banco" => banco, "cuenta" => cuenta} = params) do
    conn
    |> put_session(:pse_pendiente, %{
      valor:  valor,
      banco:  banco,
      cuenta: cuenta,
      email:  params["email"] || ""
    })
    |> redirect(to: ~p"/pse/cargando")
  end

  def cargando(conn, _params) do
    render(conn, :cargando)
  end

  def exito(conn, _params) do
    pendiente   = get_session(conn, :pse_pendiente)
    cliente_doc = get_session(conn, :cliente_doc)
    valor_int   = String.to_integer(pendiente.valor)

    {:ok, cliente} = Clientes.recargar_saldo(cliente_doc, valor_int)

    conn
    |> delete_session(:pse_pendiente)
    |> put_session(:pse_info, %{
      valor:  valor_int,
      banco:  pendiente.banco,
      cuenta: pendiente.cuenta,
      saldo:  cliente.saldo
    })
    |> render(:exito, info: %{
      valor:  valor_int,
      banco:  pendiente.banco,
      cuenta: pendiente.cuenta,
      saldo:  cliente.saldo
    })
  end
end
