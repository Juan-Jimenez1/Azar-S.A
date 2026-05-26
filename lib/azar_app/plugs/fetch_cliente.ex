defmodule AzarApp.Plugs.FetchCliente do
  @moduledoc """
  Plug que carga el cliente actual en `conn.assigns`.

  Lee el documento del cliente desde la sesión (`:cliente_doc`) y lo busca
  en `Clientes`. El resultado queda disponible en `conn.assigns.cliente_actual`
  para todas las vistas y controladores aguas abajo.

  Si no hay sesión activa o el cliente no se encuentra, asigna `nil`.
  """

  import Plug.Conn

  def init(opts), do: opts

  @doc "Carga el cliente desde la sesión en `conn.assigns.cliente_actual` (puede ser `nil`)."
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
