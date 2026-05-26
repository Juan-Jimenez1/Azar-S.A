defmodule AzarAppWeb.Helpers.NumeroHelper do
  @moduledoc "Helpers de formato numérico para las vistas."

  @doc """
  Formatea un entero con separadores de miles usando punto (`.`).

  Ejemplos:
  - `1000` → `"1.000"`
  - `1500000` → `"1.500.000"`

  Si el argumento no es un entero, lo convierte a string sin formato.
  """
  def formatear(numero) when is_integer(numero) do
    numero
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  def formatear(numero), do: to_string(numero)
end
