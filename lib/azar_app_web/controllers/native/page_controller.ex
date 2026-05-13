defmodule AzarAppWeb.PageController do
  use AzarAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
