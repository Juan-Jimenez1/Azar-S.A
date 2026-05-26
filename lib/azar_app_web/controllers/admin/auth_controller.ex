defmodule AzarAppWeb.Admin.AuthController do
  @moduledoc "Controlador de autenticación para administradores."

  use AzarAppWeb, :controller
  alias AzarApp.Admins

  @doc "Renderiza el formulario de inicio de sesión de administrador."
  def login(conn, _params) do
    render(conn, :login)
  end

    @doc "Procesa el formulario de login. Renueva la sesión e inicia con `:admin_id` si las credenciales son válidas."
  def do_login(conn, %{"admin" => params}) do
  case Admins.login(params["nombre"], params["password"]) do
    {:ok, admin} ->
      conn
      |> configure_session(renew: true)
      |> put_session(:admin_id, admin.id)
      |> put_flash(:info, "Bienvenido #{admin.nombre}")
      |> redirect(to: ~p"/admin/sorteos")

    {:error, motivo} ->
      conn
      |> put_flash(:error, motivo)
      |> redirect(to: ~p"/admin/")
  end
end

  @doc "Cierra la sesión del administrador descartando la sesión completa."
  def logout(conn, _params) do
  conn
  |> configure_session(drop: true)
  |> redirect(to: ~p"/admin/")
end
end
