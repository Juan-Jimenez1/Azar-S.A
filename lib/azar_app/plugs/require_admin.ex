defmodule AzarApp.Plugs.RequireAdmin do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_id) do
      conn
    else
      conn
      |> put_flash(:error, "Debes iniciar sesión como administrador.")
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end
end
