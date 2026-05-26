defmodule AzarApp.Estadisticas do
  @moduledoc """
  Módulo de cálculo de estadísticas y rankings de jugadores.

  Lee en tiempo real los datos de `JsonStore` para calcular métricas
  agregadas: total gastado, total ganado y número de sorteos ganados
  por cliente. Expone rankings y el jackpot del día para la pantalla
  principal del jugador.
  """

  alias AzarApp.JsonStore

  @doc """
  Calcula las métricas de todos los clientes.

  Retorna una lista de mapas con:
  `nombre`, `documento`, `total_gastado`, `total_ganado`, `sorteos_ganados`.
  """
  def ranking do
    clientes  = JsonStore.all(:clientes)
    sorteos   = JsonStore.all(:sorteos)

    Enum.map(clientes, fn cliente ->
      doc = cliente.documento

      # Total gastado
      compras =
        Enum.flat_map(sorteos, fn sorteo ->
          Enum.flat_map(sorteo.billetes, fn billete ->
            cond do
              billete["tipo"] == "completo" and billete["propietario_doc"] == doc ->
                [sorteo.valor_billete]

              billete["tipo"] == "fraccion" ->
                valor_fraccion = div(sorteo.valor_billete, sorteo.cantidad_fracciones)
                billete
                |> Map.get("fracciones_tomadas", [])
                |> Enum.filter(&(&1["propietario_doc"] == doc))
                |> Enum.map(fn _ -> valor_fraccion end)

              true -> []
            end
          end)
        end)

      total_gastado = Enum.sum(compras)

      # Total ganado y sorteos ganados
      {total_ganado, sorteos_ganados} =
        Enum.reduce(sorteos, {0, 0}, fn sorteo, {ganado, ganados} ->
          if sorteo.realizado && sorteo.premio && sorteo.numero_ganador do
            billete = Enum.find(sorteo.billetes, &(&1["numero"] == sorteo.numero_ganador))

            case billete do
              nil -> {ganado, ganados}

              b ->
                cond do
                  b["tipo"] == "completo" and b["propietario_doc"] == doc ->
                    {ganado + sorteo.premio.valor, ganados + 1}

                  b["tipo"] == "fraccion" ->
                    valor_fraccion = div(sorteo.premio.valor, sorteo.cantidad_fracciones)
                    mis_fracciones =
                      b
                      |> Map.get("fracciones_tomadas", [])
                      |> Enum.count(&(&1["propietario_doc"] == doc))

                    if mis_fracciones > 0 do
                      {ganado + mis_fracciones * valor_fraccion, ganados + 1}
                    else
                      {ganado, ganados}
                    end

                  true -> {ganado, ganados}
                end
            end
          else
            {ganado, ganados}
          end
        end)

      %{
        nombre:         cliente.nombre,
        documento:      doc,
        total_gastado:  total_gastado,
        total_ganado:   total_ganado,
        sorteos_ganados: sorteos_ganados
      }
    end)
  end

  @doc "Retorna los `n` clientes con mayor `total_ganado` en premios. Por defecto `n = 3`."
  def top_ganadores(n \\ 3) do
    ranking()
    |> Enum.sort_by(& &1.total_ganado, :desc)
    |> Enum.take(n)
  end

  @doc "Retorna los `n` clientes que más han gastado en total. Por defecto `n = 3`."
  def top_compradores(n \\ 3) do
    ranking()
    |> Enum.sort_by(& &1.total_gastado, :desc)
    |> Enum.take(n)
  end

  @doc "Retorna los `n` clientes con mayor cantidad de sorteos ganados. Por defecto `n = 3`."
  def top_suertudos(n \\ 3) do
    ranking()
    |> Enum.sort_by(& &1.sorteos_ganados, :desc)
    |> Enum.take(n)
  end

  @doc """
  Retorna el sorteo con mayor valor de premio entre los disponibles (no ejecutados).

  Recibe la lista de `sorteos` ya filtrada. Retorna el sorteo o `nil` si no hay
  ninguno con premio asignado.
  """
  def jackpot_del_dia(sorteos) do
    sorteos
    |> Enum.filter(&(!&1.realizado && &1.premio))
    |> Enum.sort_by(fn s -> s.premio.valor end, :desc)
    |> List.first()
  end
end
