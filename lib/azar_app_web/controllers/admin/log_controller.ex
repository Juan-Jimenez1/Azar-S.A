defmodule AzarAppWeb.Admin.LogController do
  @moduledoc "Controlador para visualizar la bitácora de peticiones HTTP."

  use AzarAppWeb, :controller

  @doc "Muestra las últimas 500 entradas del log de auditoría del sistema."
  def index(conn, _params) do
    entradas = AzarApp.Logger.all()
    render(conn, :index, entradas: entradas)
  end
end
