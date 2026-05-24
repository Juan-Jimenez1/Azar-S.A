defmodule AzarApp.Plugs.FetchCliente do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    cliente_doc = get_session(conn, :cliente_doc)

    cliente =
      if cliente_doc do
        case AzarApp.Clientes.get_cliente(cliente_doc) do
          {:ok, c} -> c
          _        -> nil
        end
      end

    assign(conn, :cliente_actual, cliente)
  end
end
