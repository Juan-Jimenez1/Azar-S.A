defmodule AzarAppWeb.Jugador.ClienteController do
  use AzarAppWeb, :controller
  alias AzarApp.Clientes


  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"cliente" => params}) do
    case Clientes.registrar(params) do
      {:ok, cliente} ->
        conn
        |> put_session(:cliente_doc, cliente.documento)
        |> put_flash(:info, "Bienvenido #{cliente.nombre}!")
        |> redirect(to: ~p"/")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/registro")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/")
  end

  # POST /login - procesa el formulario
  def login(conn, %{"cliente" => params}) do
    case Clientes.login(params["documento"], params["password"]) do
      {:ok, cliente} ->
        conn
        |> put_session(:cliente_doc, cliente.documento)
        |> put_flash(:info, "Bienvenido de nuevo #{cliente.nombre}!")
        |> redirect(to: ~p"/perfil")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/login")
    end
  end

  # GET /login - muestra el formulario
  def login(conn, _params) do
    render(conn, :login)
  end

  def recargar(conn, %{"valor" => valor}) do
    cliente_doc = get_session(conn, :cliente_doc)
    valor       = String.to_integer(valor)

    case Clientes.recargar_saldo(cliente_doc, valor) do
      {:ok, cliente} ->
        conn
        |> put_flash(:info, "Saldo recargado. Nuevo saldo: $#{cliente.saldo}")
        |> redirect(to: ~p"/perfil")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/perfil")
    end

    end

  def perfil(conn, _params) do
      cliente_doc = get_session(conn, :cliente_doc)
      {:ok, cliente} = Clientes.get_cliente(cliente_doc)
      render(conn, :perfil, cliente: cliente)
    end
end
