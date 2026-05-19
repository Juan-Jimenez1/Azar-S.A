defmodule AzarAppWeb.Admin.AuthController do
  use AzarAppWeb, :controller
  alias AzarApp.Admins

  # GET /admin/login
  def login(conn, _params) do
    render(conn, :login)
  end

  # POST /admin/login
  def login_post(conn, %{"admin" => params}) do
    case Admins.login(params["documento"], params["password"]) do
      {:ok, admin} ->
        conn
        |> put_session(:admin_doc, admin.documento)
        |> put_flash(:info, "Bienvenido, #{admin.nombre}!")
        |> redirect(to: ~p"/admin/sorteos")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/admin/login")
    end
  end

  # DELETE /admin/logout
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/admin/login")
  end
end
