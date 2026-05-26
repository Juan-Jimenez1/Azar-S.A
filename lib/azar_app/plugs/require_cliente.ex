defmodule AzarApp.Plugs.RequireCliente do
  @moduledoc """
  Plug de autenticación para rutas de jugador.

  Verifica que exista una sesión activa con la clave `:cliente_doc`.
  Si no la hay, redirige a `/` con un mensaje de error y detiene el pipeline.
  Se aplica en el router a todas las rutas protegidas del scope de jugador.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  @doc "Verifica la sesión de cliente. Redirige y detiene si no hay sesión activa."
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
