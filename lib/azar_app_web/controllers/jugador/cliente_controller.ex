defmodule AzarAppWeb.Jugador.ClienteController do
  use AzarAppWeb, :controller
  alias AzarApp.{Clientes, Sorteos}

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"cliente" => params}) do
    case Clientes.registrar(params) do
      {:ok, cliente} ->
        conn
        |> put_session(:cliente_doc, cliente.documento)
        |> put_flash(:info, "Bienvenido #{cliente.nombre}!")
        |> redirect(to: ~p"/index")

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
        |> redirect(to: ~p"/index")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/")
    end
  end

  # GET /login - muestra el formulario
  def login(conn, _params) do
    render(conn, :login)
  end

  def recargar(conn, %{"valor" => valor}) do
    cliente_doc = get_session(conn, :cliente_doc)
    valor = String.to_integer(valor)

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

  def notificaciones(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    {:ok, _cliente} = Clientes.get_cliente(cliente_doc)
    Clientes.marcar_notificaciones_leidas(cliente_doc)
    {:ok, cliente_actualizado} = Clientes.get_cliente(cliente_doc)
    render(conn, :notificaciones, notificaciones: cliente_actualizado.notificaciones)
  end

  def marcar_leidas(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.marcar_notificaciones_leidas(cliente_doc)
    conn |> redirect(to: ~p"/notificaciones")
  end

  def eliminar_notificacion(conn, %{"id" => notif_id}) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.eliminar_notificacion(cliente_doc, notif_id)
    redirect(conn, to: ~p"/notificaciones")
  end

  @doc """
  Historial de todas las compras realizadas por el jugador en todos los sorteos.
  Permite devolver compras de sorteos que aún no se han realizado.
  """
  def historial(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    compras = Sorteos.compras_por_cliente(cliente_doc)
    total_gastado = Enum.sum(Enum.map(compras, & &1.valor))
    render(conn, :historial, compras: compras, total_gastado: total_gastado)
  end

  @doc """
  Balance personal: diferencia entre premios ganados y dinero gastado en sorteos.
  """
  def balance_personal(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    {:ok, cliente} = Clientes.get_cliente(cliente_doc)

    compras = Sorteos.compras_por_cliente(cliente_doc)
    total_gastado = Enum.sum(Enum.map(compras, & &1.valor))

    premios = Sorteos.premios_por_cliente(cliente_doc)
    total_premios = Enum.sum(Enum.map(premios, & &1.valor))

    balance = total_premios - total_gastado
    resultado = if balance >= 0, do: "ganancia", else: "pérdida"

    render(conn, :balance_personal,
      cliente: cliente,
      total_gastado: total_gastado,
      total_premios: total_premios,
      balance: balance,
      resultado: resultado,
      premios: premios
    )
  end
end
