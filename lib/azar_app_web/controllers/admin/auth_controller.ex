defmodule AzarAppWeb.Admin.AuthController do
  use AzarAppWeb, :controller
  alias AzarApp.Admins

  def login(conn, _params) do
    render(conn, :login)
  end

  def do_login(conn, %{"admin" => params}) do
    case Admins.login(params["nombre"], params["password"]) do
      {:ok, admin} ->
        conn
        |> put_session(:admin_id, admin.id)
        |> put_flash(:info, "Bienvenido #{admin.nombre}")
        |> redirect(to: ~p"/admin/sorteos")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/admin/login")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/admin/login")
  end
end
