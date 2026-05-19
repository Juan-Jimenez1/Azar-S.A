defmodule AzarAppWeb.Plugs.JugadorAuth do
  @moduledoc "Protege rutas de jugador. Redirige al login si no hay sesión activa."
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :cliente_doc) do
      conn
    else
      conn
      |> redirect(to: "/")
      |> halt()
    end
  end
end
