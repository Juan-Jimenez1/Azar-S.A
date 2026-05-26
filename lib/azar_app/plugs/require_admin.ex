defmodule AzarApp.Plugs.RequireAdmin do
  @moduledoc """
  Plug de autenticación para rutas de administrador.

  Verifica que exista una sesión activa con la clave `:admin_id`.
  Si no la hay, redirige a `/admin/` con un mensaje de error y detiene el pipeline.
  Se aplica en el router a todas las rutas del scope `/admin` protegido.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  @doc "Verifica la sesión de administrador. Redirige y detiene si no hay sesión activa."
  def call(conn, _opts) do
    if get_session(conn, :admin_id) do
      conn
    else
      conn
      |> put_flash(:error, "Debes iniciar sesión como administrador.")
      |> redirect(to: "/admin/")
      |> halt()
    end
  end
end
