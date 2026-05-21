defmodule AzarApp.Estadisticas do
  alias AzarApp.JsonStore

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

  def top_ganadores(n \\ 3) do
    ranking()
    |> Enum.sort_by(& &1.total_ganado, :desc)
    |> Enum.take(n)
  end

  def top_compradores(n \\ 3) do
    ranking()
    |> Enum.sort_by(& &1.total_gastado, :desc)
    |> Enum.take(n)
  end

  def top_suertudos(n \\ 3) do
    ranking()
    |> Enum.sort_by(& &1.sorteos_ganados, :desc)
    |> Enum.take(n)
  end

  def jackpot_del_dia(sorteos) do
    sorteos
    |> Enum.filter(&(!&1.realizado && &1.premio))
    |> Enum.sort_by(fn s -> s.premio.valor end, :desc)
    |> List.first()
  end
end
