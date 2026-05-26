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
    case get_session(conn, :pse_pendiente) do
      nil ->
        conn
        |> put_flash(:error, "No hay una transacción PSE pendiente.")
        |> redirect(to: ~p"/perfil")

      pendiente ->
        cliente_doc = get_session(conn, :cliente_doc)
        valor_int   = String.to_integer(pendiente.valor)

        case Clientes.recargar_saldo(cliente_doc, valor_int) do
          {:ok, cliente} ->
            conn
            |> delete_session(:pse_pendiente)
            |> render(:exito, info: %{
              valor:  valor_int,
              banco:  pendiente.banco,
              cuenta: pendiente.cuenta,
              saldo:  cliente.saldo
            })

          {:error, motivo} ->
            conn
            |> put_flash(:error, motivo)
            |> redirect(to: ~p"/perfil")
        end
    end
  end
end
