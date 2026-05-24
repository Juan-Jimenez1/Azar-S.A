defmodule AzarAppWeb.Jugador.CuentaController do
  use AzarAppWeb, :controller
  alias AzarApp.{Clientes, Sorteos}

  def historial(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    {:ok, data} = Clientes.historial_compras(cliente_doc)
    render(conn, :historial, compras: data.compras, total_gastado: data.total_gastado)
  end

  def premios(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    {:ok, data} = Clientes.premios_obtenidos(cliente_doc)
    render(conn, :premios, premios: data.premios, total_ganado: data.total_ganado)
  end

  def balance(conn, _params) do
    cliente_doc = get_session(conn, :cliente_doc)
    {:ok, data} = Clientes.balance_personal(cliente_doc)
    render(conn, :balance, balance: data)
  end

  def devolver(conn, %{"sorteo_id" => sorteo_id, "numero" => numero}) do
    cliente_doc = get_session(conn, :cliente_doc)
    numero      = String.to_integer(numero)

    with {:ok, sorteo}  <- Sorteos.get_sorteo(sorteo_id),
         billete        =  Enum.find(sorteo.billetes, &(&1["numero"] == numero)),
         valor          =  calcular_devolucion(billete, sorteo, cliente_doc),
         :ok            <- Sorteos.devolver_compra(sorteo_id, numero, cliente_doc),
         {:ok, _}       <- Clientes.acreditar_saldo(cliente_doc, valor) do

      Clientes.agregar_notificacion(cliente_doc, %{
        tipo:   "devolucion",
        titulo: "Compra devuelta",
        cuerpo: "Se revirtió tu compra del billete ##{numero} del sorteo '#{sorteo.nombre}'. Se acreditaron $#{valor} a tu saldo."
      })

      conn
      |> put_flash(:info, "Compra devuelta. Se acreditaron $#{valor} a tu saldo.")
      |> redirect(to: ~p"/cuenta/historial")
    else
      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/cuenta/historial")
    end
  end

  defp calcular_devolucion(billete, sorteo, cliente_doc) do
    valor_fraccion = div(sorteo.valor_billete, sorteo.cantidad_fracciones)

    case billete["tipo"] do
      "completo" -> sorteo.valor_billete
      "fraccion" ->
        billete
        |> Map.get("fracciones_tomadas", [])
        |> Enum.count(&(&1["propietario_doc"] == cliente_doc))
        |> Kernel.*(valor_fraccion)
      _ -> 0
    end
  end
end
