defmodule AzarAppWeb.Admin.SistemaController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  def actualizar_fecha(conn, _params) do
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
end
