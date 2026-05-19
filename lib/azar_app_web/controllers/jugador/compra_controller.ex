defmodule AzarAppWeb.Jugador.CompraController do
  use AzarAppWeb, :controller
  alias AzarApp.{Sorteos, Clientes}

  def comprar_billete(conn, %{"id" => sorteo_id, "numero" => numero}) do
    cliente_doc = get_session(conn, :cliente_doc)
    numero = String.to_integer(numero)

    with {:ok, sorteo} <- AzarApp.Sorteos.get_sorteo(sorteo_id),
         {:ok, _cliente} <- AzarApp.Clientes.descontar_saldo(cliente_doc, sorteo.valor_billete),
         {:ok, _billete} <- AzarApp.Sorteos.comprar_billete(sorteo_id, numero, cliente_doc) do
      conn
      |> put_flash(:info, "Billete #{numero} comprado exitosamente.")
      |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    else
      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  def comprar_fracciones_restantes(conn, %{"id" => sorteo_id, "numero" => numero}) do
    cliente_doc = get_session(conn, :cliente_doc)
    numero = String.to_integer(numero)

    with {:ok, sorteo} <- AzarApp.Sorteos.get_sorteo(sorteo_id),
         billete = Enum.find(sorteo.billetes, &(&1["numero"] == numero)),
         fracciones_tomadas = Map.get(billete, "fracciones_tomadas", []),
         nums_tomados = Enum.map(fracciones_tomadas, & &1["fraccion"]),
         fracciones_libres =
           Enum.reject(1..sorteo.cantidad_fracciones |> Enum.to_list(), &(&1 in nums_tomados)),
         valor_fraccion = div(sorteo.valor_billete, sorteo.cantidad_fracciones),
         valor_total = length(fracciones_libres) * valor_fraccion,
         {:ok, _cliente} <- AzarApp.Clientes.descontar_saldo(cliente_doc, valor_total),
         {:ok, _, cantidad} <-
           AzarApp.Sorteos.comprar_fracciones_restantes(sorteo_id, numero, cliente_doc) do
      conn
      |> put_flash(:info, "Compraste #{cantidad} fracciones restantes del billete #{numero}.")
      |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    else
      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  def comprar_fraccion(conn, %{"id" => sorteo_id, "numero" => numero, "fraccion" => fraccion}) do
    cliente_doc = get_session(conn, :cliente_doc)
    numero = String.to_integer(numero)
    fraccion = String.to_integer(fraccion)

    with {:ok, sorteo} <- AzarApp.Sorteos.get_sorteo(sorteo_id),
         valor_fraccion = div(sorteo.valor_billete, sorteo.cantidad_fracciones),
         {:ok, _cliente} <- AzarApp.Clientes.descontar_saldo(cliente_doc, valor_fraccion),
         {:ok, _billete} <-
           AzarApp.Sorteos.comprar_fraccion(sorteo_id, numero, fraccion, cliente_doc) do
      conn
      |> put_flash(:info, "Fracción #{fraccion} del billete #{numero} comprada exitosamente.")
      |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    else
      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  def devolver(conn, %{"sorteo_id" => sorteo_id, "numero" => numero}) do
    # Siempre tomamos el doc de la sesión (nunca de params → seguridad)
    cliente_doc = get_session(conn, :cliente_doc)
    numero = String.to_integer(numero)

    case Sorteos.get_sorteo(sorteo_id) do
      {:ok, sorteo} ->
        reembolso = calcular_reembolso(sorteo, numero, cliente_doc)

        case Sorteos.devolver_compra(sorteo_id, numero, cliente_doc) do
          :ok ->
            Clientes.acreditar_saldo(cliente_doc, reembolso)

            conn
            |> put_flash(:info, "Compra devuelta. Se reembolsaron $#{reembolso} a tu saldo.")
            |> redirect(to: ~p"/historial")

          {:error, motivo} ->
            conn
            |> put_flash(:error, motivo)
            |> redirect(to: ~p"/historial")
        end

      :error ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/historial")
    end
  end

  # ── Privado ──────────────────────────────────────────────────────────────────

  # Calcula cuánto dinero reembolsar según el tipo de compra del cliente
  defp calcular_reembolso(sorteo, numero_billete, cliente_doc) do
    billete = Enum.find(sorteo.billetes, &(&1["numero"] == numero_billete))

    valor_fraccion =
      if sorteo.cantidad_fracciones > 0,
        do: div(sorteo.valor_billete, sorteo.cantidad_fracciones),
        else: 0

    cond do
      is_nil(billete) ->
        0

      billete["tipo"] == "completo" and billete["propietario_doc"] == cliente_doc ->
        sorteo.valor_billete

      billete["tipo"] == "fraccion" ->
        fracciones_del_cliente =
          (billete["fracciones_tomadas"] || [])
          |> Enum.count(&(&1["propietario_doc"] == cliente_doc))

        fracciones_del_cliente * valor_fraccion

      true ->
        0
    end
  end
end
