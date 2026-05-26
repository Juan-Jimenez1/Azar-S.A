defmodule AzarAppWeb.Admin.AdminController do
  @moduledoc "Controlador para la gestión de cuentas de administrador."

  use AzarAppWeb, :controller
  alias AzarApp.Admins

  @doc "Lista todos los administradores registrados en el sistema."
  def index(conn, _params) do
    render(conn, :index, admins: Admins.listar())
  end

  @doc "Crea un nuevo administrador con los datos del formulario."
  def create(conn, %{"admin" => params}) do
    case Admins.crear(params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Admin creado correctamente.")
        |> redirect(to: ~p"/admin/admins")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/admin/admins")
    end
  end

  @doc "Elimina el administrador indicado. Previene eliminar el último admin existente."
  def delete(conn, %{"id" => id}) do
    case Admins.eliminar(id) do
      :ok ->
        conn
        |> put_flash(:info, "Admin eliminado.")
        |> redirect(to: ~p"/admin/admins")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/admin/admins")
    end
  end
end
