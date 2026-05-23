defmodule AzarAppWeb.Helpers.NumeroHelper do
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
