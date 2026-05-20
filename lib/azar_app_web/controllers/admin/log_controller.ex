defmodule AzarAppWeb.Admin.LogController do
  use AzarAppWeb, :controller

  def index(conn, _params) do
    entradas = AzarApp.Logger.all()
    render(conn, :index, entradas: entradas)
  end
end
