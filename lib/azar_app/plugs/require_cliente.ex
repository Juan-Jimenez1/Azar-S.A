defmodule AzarApp.Plugs.RequireCliente do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :cliente_doc) do
      conn
    else
      conn
      |> put_flash(:error, "Debes iniciar sesión para acceder.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
