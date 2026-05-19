defmodule AzarAppWeb.Plugs.AdminAuth do
  @moduledoc "Protege rutas de administrador. Redirige al login si no hay sesión activa."
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_doc) do
      conn
    else
      conn
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end
end
