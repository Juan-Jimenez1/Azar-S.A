defmodule AzarAppWeb.Admin.PremioController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  def new(conn, %{"sorteo_id" => sorteo_id}) do
    {:ok, sorteo} = Sorteos.get_sorteo(sorteo_id)
    render(conn, :new, sorteo: sorteo)
  end

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
