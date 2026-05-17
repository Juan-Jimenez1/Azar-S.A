defmodule AzarAppWeb.Admin.SistemaController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  def ejecutar_sorteos_pendientes(conn, _params) do
    resultados = Sorteos.ejecutar_sorteos_pendientes()

    mensaje =
      if resultados == [] do
        "No hay sorteos pendientes por ejecutar."
      else
        ids = Enum.map(resultados, fn {id, _} -> id end) |> Enum.join(", ")
        "Sorteos ejecutados: #{ids}"
      end

    conn
    |> put_flash(:info, mensaje)
    |> redirect(to: ~p"/admin/sorteos")
  end

  def ejecutar_sorteo(conn, %{"id" => sorteo_id}) do
  case AzarApp.Sorteos.ejecutar_sorteo(sorteo_id) do
    {:ok, ganador} ->
      conn
      |> put_flash(:info, "Sorteo ejecutado. Número ganador: #{ganador}")
      |> redirect(to: ~p"/admin/sorteos/#{sorteo_id}")

    {:error, motivo} ->
      conn
      |> put_flash(:error, motivo)
      |> redirect(to: ~p"/admin/sorteos/#{sorteo_id}")
  end
end
end
