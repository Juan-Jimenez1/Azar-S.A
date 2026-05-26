defmodule AzarAppWeb.Jugador.ClienteController do
  @moduledoc "Controlador de registro, sesión, perfil y notificaciones del jugador."

  use AzarAppWeb, :controller
  alias AzarApp.Clientes

  @doc "Renderiza el formulario de registro de nuevo cliente."
  def new(conn, _params) do
    render(conn, :new)
  end

  @doc "Registra un nuevo cliente e inicia sesión automáticamente si el registro es exitoso."
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

  @doc "Procesa el formulario de login del cliente. Renueva la sesión e inicia con `:cliente_doc`."
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

  @doc "Renderiza el formulario de login. Redirige al índice si ya hay una sesión activa."
  def login(conn, _params) do
    if get_session(conn, :cliente_doc) do
      redirect(conn, to: ~p"/index")
    else
      render(conn, :login)
    end
  end


  @doc "Cierra la sesión del cliente descartando la sesión completa."
  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  @doc "Muestra el perfil del cliente con su saldo y datos personales."
  def perfil(conn, _params) do
    cliente = conn.assigns.cliente_actual
    render(conn, :perfil, cliente: cliente)
  end

  @doc "Recarga el saldo del cliente con el valor indicado (debe ser positivo)."
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

  @doc "Muestra todas las notificaciones del cliente y las marca como leídas automáticamente."
  def notificaciones(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.marcar_notificaciones_leidas(cliente_doc)
    {:ok, cliente} = Clientes.get_cliente(cliente_doc)
    render(conn, :notificaciones, notificaciones: cliente.notificaciones)
  end

  @doc "Marca todas las notificaciones del cliente como leídas y redirige a la lista."
  def marcar_leidas(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.marcar_notificaciones_leidas(cliente_doc)
    redirect(conn, to: ~p"/notificaciones")
  end

  @doc "Elimina una notificación específica del cliente por su `id`."
  def eliminar_notificacion(conn, %{"id" => notif_id}) do
    cliente_doc = get_session(conn, :cliente_doc)
    Clientes.eliminar_notificacion(cliente_doc, notif_id)
    redirect(conn, to: ~p"/notificaciones")
  end

  @doc "Renderiza el formulario inicial de recuperación de contraseña (solicita el documento)."
  def recuperar(conn, _params) do
    render(conn, :recuperar)
  end

  @doc "Busca la pregunta secreta del cliente por documento y renderiza el formulario de respuesta."
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

  @doc "Valida la respuesta secreta y cambia la contraseña del cliente si es correcta."
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
