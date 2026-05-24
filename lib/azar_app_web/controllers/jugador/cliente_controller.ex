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
        |> configure_session(renew: true)
        |> put_session(:cliente_doc, cliente.documento)
        |> put_flash(:info, "Bienvenido #{cliente.nombre}!")
        |> redirect(to: ~p"/")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/registro")
    end
  end

  def do_login(conn, %{"cliente" => params}) do
    case Clientes.login(params["documento"], params["password"]) do
      {:ok, cliente} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:cliente_doc, cliente.documento)
        |> put_flash(:info, "Bienvenido de nuevo #{cliente.nombre}!")
        |> redirect(to: ~p"/")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/")
    end
  end

  def login(conn, _params) do
    if get_session(conn, :cliente_doc) do
      redirect(conn, to: ~p"/index")
    else
      render(conn, :login)
    end
  end


  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  def perfil(conn, _params) do
    cliente = conn.assigns.cliente_actual
    render(conn, :perfil, cliente: cliente)
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

  def notificaciones(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.marcar_notificaciones_leidas(cliente_doc)
    {:ok, cliente} = Clientes.get_cliente(cliente_doc)
    render(conn, :notificaciones, notificaciones: cliente.notificaciones)
  end

  def marcar_leidas(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.marcar_notificaciones_leidas(cliente_doc)
    redirect(conn, to: ~p"/notificaciones")
  end

  def eliminar_notificacion(conn, %{"id" => notif_id}) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.eliminar_notificacion(cliente_doc, notif_id)
    redirect(conn, to: ~p"/notificaciones")
  end

  def recuperar(conn, _params) do
    render(conn, :recuperar)
  end

  def buscar_pregunta(conn, %{"documento" => documento}) do
    case Clientes.get_pregunta(documento) do
      {:ok, pregunta} ->
        render(conn, :responder_pregunta, documento: documento, pregunta: pregunta)

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/recuperar")
    end
  end

  def cambiar_password(conn, %{
    "documento"            => documento,
    "respuesta"            => respuesta,
    "password"             => password,
    "password_confirmacion" => confirmacion
  }) do
    case Clientes.recuperar_password(documento, respuesta, password, confirmacion) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Contraseña actualizada. Ya puedes iniciar sesión.")
        |> redirect(to: ~p"/")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/recuperar")
    end
  end
end
