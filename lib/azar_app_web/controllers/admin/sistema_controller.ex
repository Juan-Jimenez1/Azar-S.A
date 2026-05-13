defmodule AzarAppWeb.Admin.SistemaController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  # POST /admin/sistema/actualizar-fecha
  # Ejecuta todos los sorteos cuya fecha ya pasó
  def actualizar_fecha(conn, _params) do
    resultados = Sorteos.ejecutar_sorteos_pendientes()

    mensaje =
      if resultados == [] do
        "No hay sorteos pendientes por ejecutar."
      else
        nombres = Enum.map(resultados, fn {id, _} -> id end) |> Enum.join(", ")
        "Sorteos ejecutados: #{nombres}"
      end

    conn
    |> put_flash(:info, mensaje)
    |> redirect(to: ~p"/admin/sorteos")
  end
end
