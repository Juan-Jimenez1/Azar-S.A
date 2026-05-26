defmodule AzarAppWeb.Jugador.CompraController do
  @moduledoc """
  Controlador de compras y devoluciones de billetes para el jugador.

  Gestiona tres modalidades de compra:
  1. Billete completo — el cliente adquiere el billete entero
  2. Fracción individual — el cliente elige qué fracción(es) comprar
  3. Fracciones restantes — compra todas las fracciones libres del billete

  Todas las compras siguen el patrón: descontar saldo → registrar billete → notificar.
  Las devoluciones revierten ese proceso: liberar billete → acreditar saldo → notificar.
  """

  use AzarAppWeb, :controller

  # ── Comprar billete completo ───────────────────────────────────────────────

  @doc "Compra el billete completo para el cliente. Descuenta el valor del saldo antes de registrar."
  def comprar_billete(conn, %{"id" => sorteo_id, "numero" => numero}) do
    cliente_doc = get_session(conn, :cliente_doc)
    numero      = String.to_integer(numero)

    with {:ok, sorteo}   <- AzarApp.Sorteos.get_sorteo(sorteo_id),
         {:ok, _cliente} <- AzarApp.Clientes.descontar_saldo(cliente_doc, sorteo.valor_billete),
         {:ok, _billete} <- AzarApp.Sorteos.comprar_billete(sorteo_id, numero, cliente_doc) do

      AzarApp.Clientes.agregar_notificacion(cliente_doc, %{
        tipo:   "compra",
        titulo: "Billete comprado",
        cuerpo: "Compraste el billete ##{numero} del sorteo '#{sorteo.nombre}' por $#{sorteo.valor_billete}."
      })

      conn
      |> put_flash(:info, "Billete ##{numero} comprado exitosamente.")
      |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    else
      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  # ── Comprar fracciones restantes ───────────────────────────────────────────

  @doc "Compra todas las fracciones libres del billete. Calcula el valor total antes de descontar el saldo."
  def comprar_fracciones_restantes(conn, %{"id" => sorteo_id, "numero" => numero}) do
    cliente_doc = get_session(conn, :cliente_doc)
    numero      = String.to_integer(numero)

    with {:ok, sorteo}      <- AzarApp.Sorteos.get_sorteo(sorteo_id),
         billete            =  Enum.find(sorteo.billetes, &(&1["numero"] == numero)),
         fracciones_tomadas =  Map.get(billete, "fracciones_tomadas", []),
         nums_tomados       =  Enum.map(fracciones_tomadas, & &1["fraccion"]),
         fracciones_libres  =  Enum.reject(1..sorteo.cantidad_fracciones |> Enum.to_list(), &(&1 in nums_tomados)),
         valor_fraccion     =  div(sorteo.valor_billete, sorteo.cantidad_fracciones),
         valor_total        =  length(fracciones_libres) * valor_fraccion,
         {:ok, _cliente}    <- AzarApp.Clientes.descontar_saldo(cliente_doc, valor_total),
         {:ok, _, cantidad} <- AzarApp.Sorteos.comprar_fracciones_restantes(sorteo_id, numero, cliente_doc) do

      AzarApp.Clientes.agregar_notificacion(cliente_doc, %{
        tipo:   "compra",
        titulo: "Fracciones compradas",
        cuerpo: "Compraste #{cantidad} fracciones del billete ##{numero} del sorteo '#{sorteo.nombre}' por $#{valor_total}."
      })

      conn
      |> put_flash(:info, "Compraste #{cantidad} fracciones restantes del billete ##{numero}.")
      |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    else
      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  # ── Comprar fracciones individuales (lista desde checkboxes) ───────────────

  @doc """
  Compra las fracciones seleccionadas del billete.

  Recibe `fracciones` como lista de strings desde checkboxes del formulario.
  Si alguna fracción falla al comprarse, revierte el descuento del saldo.
  Si el formulario se envía vacío (sin fracciones), redirige con mensaje de error.
  """
  def comprar_fraccion(conn, %{"id" => sorteo_id, "numero" => numero, "fracciones" => fracciones}) do
    cliente_doc = get_session(conn, :cliente_doc)
    numero      = String.to_integer(numero)
    fracciones  = fracciones |> List.wrap() |> Enum.map(&String.to_integer/1)

    if fracciones == [] do
      conn
      |> put_flash(:error, "Selecciona al menos una fracción.")
      |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    else
      with {:ok, sorteo}  <- AzarApp.Sorteos.get_sorteo(sorteo_id),
           valor_fraccion =  div(sorteo.valor_billete, sorteo.cantidad_fracciones),
           valor_total    =  length(fracciones) * valor_fraccion,
           {:ok, _}       <- AzarApp.Clientes.descontar_saldo(cliente_doc, valor_total) do

        resultados =
          Enum.reduce_while(fracciones, {:ok, []}, fn f, {:ok, acc} ->
            case AzarApp.Sorteos.comprar_fraccion(sorteo_id, numero, f, cliente_doc) do
              {:ok, billete} -> {:cont, {:ok, [billete | acc]}}
              {:error, msg}  -> {:halt, {:error, msg}}
            end
          end)

        case resultados do
          {:ok, _} ->
            AzarApp.Clientes.agregar_notificacion(cliente_doc, %{
              tipo:   "compra",
              titulo: "Fracciones compradas",
              cuerpo: "Compraste #{length(fracciones)} fracción(es) del billete ##{numero} del sorteo '#{sorteo.nombre}' por $#{valor_total}."
            })

            conn
            |> put_flash(:info, "Compraste #{length(fracciones)} fracción(es) del billete ##{numero} por $#{valor_total}.")
            |> redirect(to: ~p"/sorteos/#{sorteo_id}")

          {:error, motivo} ->
            AzarApp.Clientes.acreditar_saldo(cliente_doc, valor_total)
            conn
            |> put_flash(:error, motivo)
            |> redirect(to: ~p"/sorteos/#{sorteo_id}")
        end
      else
        {:error, motivo} ->
          conn
          |> put_flash(:error, motivo)
          |> redirect(to: ~p"/sorteos/#{sorteo_id}")
      end
    end
  end

  def comprar_fraccion(conn, %{"id" => sorteo_id}) do
    conn
    |> put_flash(:error, "Selecciona al menos una fracción.")
    |> redirect(to: ~p"/sorteos/#{sorteo_id}")
  end

  # ── Devolver compra ────────────────────────────────────────────────────────

  @doc """
  Devuelve una compra del cliente y acredita el monto correspondiente.

  Si no se envía `fracciones`, devuelve todas las fracciones del cliente.
  Si se envía una lista, devuelve solo las fracciones indicadas.
  """
  def devolver(conn, %{"sorteo_id" => sorteo_id, "numero" => numero} = params) do
    cliente_doc        = get_session(conn, :cliente_doc)
    numero             = String.to_integer(numero)
    fracciones_params  = Map.get(params, "fracciones", [])

    fracciones_a_devolver =
      case fracciones_params do
        []    -> :todas
        lista -> Enum.map(lista, &String.to_integer/1)
      end

    with {:ok, sorteo}  <- AzarApp.Sorteos.get_sorteo(sorteo_id),
         billete        =  Enum.find(sorteo.billetes, &(&1["numero"] == numero)),
         valor          =  calcular_devolucion(billete, sorteo, cliente_doc, fracciones_a_devolver),
         :ok            <- AzarApp.Sorteos.devolver_compra(sorteo_id, numero, cliente_doc, fracciones_a_devolver),
         {:ok, _}       <- AzarApp.Clientes.acreditar_saldo(cliente_doc, valor) do

      AzarApp.Clientes.agregar_notificacion(cliente_doc, %{
        tipo:   "devolucion",
        titulo: "Compra devuelta",
        cuerpo: "Se revirtió tu compra del billete ##{numero} del sorteo '#{sorteo.nombre}'. Se acreditaron $#{valor} a tu saldo."
      })

      conn
      |> put_flash(:info, "Compra devuelta. Se acreditaron $#{valor} a tu saldo.")
      |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    else
      {:error, motivo} ->
        conn
        |> put_flash(:error, motivo)
        |> redirect(to: ~p"/sorteos/#{sorteo_id}")
    end
  end

  # ── Privado ────────────────────────────────────────────────────────────────

  defp calcular_devolucion(billete, sorteo, cliente_doc, fracciones_a_devolver) do
    valor_fraccion = div(sorteo.valor_billete, sorteo.cantidad_fracciones)

    case billete["tipo"] do
      "completo" ->
        sorteo.valor_billete

      "fraccion" ->
        case fracciones_a_devolver do
          :todas ->
            billete
            |> Map.get("fracciones_tomadas", [])
            |> Enum.count(&(&1["propietario_doc"] == cliente_doc))
            |> Kernel.*(valor_fraccion)

          lista ->
            length(lista) * valor_fraccion
        end

      _ -> 0
    end
  end
end
