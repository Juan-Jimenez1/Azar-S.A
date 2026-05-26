defmodule AzarAppWeb.Admin.PremioController do
  @moduledoc "Controlador para la gestión del premio de un sorteo."

  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  @doc "Renderiza el formulario para asignar un premio al sorteo indicado."
  def new(conn, %{"sorteo_id" => sorteo_id}) do
    case Sorteos.get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        render(conn, :new, sorteo: sorteo)

      :error ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/admin/sorteos")
    end
  end

  @doc "Crea y asigna el premio al sorteo. Solo se permite un premio por sorteo."
  def create(conn, %{"sorteo_id" => sorteo_id, "premio" => params}) do
    params = %{
      "nombre" => params["nombre"],
      "valor"  => String.to_integer(params["valor"])
    }

    case Sorteos.crear_premio(sorteo_id, params) do
      {:ok, _premio} ->
        conn
        |> put_flash(:info, "Premio creado correctamente.")
        |> redirect(to: ~p"/admin/sorteos/#{sorteo_id}")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/admin/sorteos/#{sorteo_id}")
    end
  end

  @doc "Elimina el premio del sorteo. Solo es posible si no hay billetes vendidos."
  def delete(conn, %{"sorteo_id" => sorteo_id}) do
    case Sorteos.eliminar_premio(sorteo_id) do
      :ok ->
        conn
        |> put_flash(:info, "Premio eliminado.")
        |> redirect(to: ~p"/admin/sorteos/#{sorteo_id}")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/admin/sorteos/#{sorteo_id}")
    end
  end
end
