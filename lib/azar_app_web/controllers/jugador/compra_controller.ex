defmodule AzarAppWeb.Jugador.CompraController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  def comprar_billete(conn, %{"id" => sorteo_id, "numero" => numero, "cliente_doc" => doc}) do
    numero = String.to_integer(numero)

    case Sorteos.comprar_billete(sorteo_id, numero, doc) do
      {:ok, _billete} ->
        conn
        |> put_flash(:info, "Billete #{numero} comprado exitosamente.")
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  def comprar_fraccion(conn, %{"id" => sorteo_id, "numero" => numero, "fraccion" => fraccion, "cliente_doc" => doc}) do
    numero   = String.to_integer(numero)
    fraccion = String.to_integer(fraccion)

    case Sorteos.comprar_fraccion(sorteo_id, numero, fraccion, doc) do
      {:ok, _billete} ->
        conn
        |> put_flash(:info, "Fracción #{fraccion} del billete #{numero} comprada exitosamente.")
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  def devolver(conn, %{"sorteo_id" => sorteo_id, "numero" => numero, "cliente_doc" => doc}) do
    numero = String.to_integer(numero)

    case Sorteos.devolver_compra(sorteo_id, numero, doc) do
      :ok ->
        conn
        |> put_flash(:info, "Compra devuelta correctamente.")
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")

      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end
end
