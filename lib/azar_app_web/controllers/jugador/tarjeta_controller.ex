defmodule AzarAppWeb.Jugador.TarjetaController do
  use AzarAppWeb, :controller
  alias AzarApp.Clientes

  def index(conn, %{"valor" => valor}) do
    render(conn, :index, valor: valor)
  end

  def procesar(conn, params) do
    conn
    |> put_session(:tarjeta_pendiente, %{
      valor:  params["valor"],
      nombre: params["nombre"],
      numero: params["numero"] |> String.slice(-4, 4),
      tipo:   params["tipo"] || "Crédito"
    })
    |> redirect(to: ~p"/tarjeta/cargando")
  end

  def cargando(conn, _params) do
    render(conn, :cargando)
  end

  def exito(conn, _params) do
    case get_session(conn, :tarjeta_pendiente) do
      nil ->
        conn
        |> put_flash(:error, "No hay una transacción de tarjeta pendiente.")
        |> redirect(to: ~p"/perfil")

      pendiente ->
        cliente_doc = get_session(conn, :cliente_doc)
        valor_int   = String.to_integer(pendiente.valor)

        case Clientes.recargar_saldo(cliente_doc, valor_int) do
          {:ok, cliente} ->
            conn
            |> delete_session(:tarjeta_pendiente)
            |> render(:exito, info: %{
              valor:  valor_int,
              nombre: pendiente.nombre,
              numero: pendiente.numero,
              tipo:   pendiente.tipo,
              saldo:  cliente.saldo
            })

          {:error, motivo} ->
            conn
            |> put_flash(:error, motivo)
            |> redirect(to: ~p"/perfil")
        end
    end
  end
end
