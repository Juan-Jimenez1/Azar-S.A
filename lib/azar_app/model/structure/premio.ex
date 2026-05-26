defmodule AzarApp.Model.Structure.Premio do
  @moduledoc """
  Estructura de datos para el premio de un sorteo.

  Campos:
  - `id` — identificador único generado por `JsonStore.generar_id/1`
  - `nombre` — descripción del premio (p. ej. "Casa en la playa")
  - `valor` — valor monetario del premio en pesos (entero)

  Se almacena embebido dentro del documento del sorteo en `sorteos.json`.
  """

  defstruct [
    :id,
    :nombre,
    :valor
  ]

  @doc "Deserializa un mapa con claves string a una struct `Premio`."
  def to_struct(m) do
    %__MODULE__{
      id: m["id"],
      nombre: m["nombre"],
      valor: m["valor"]
    }
  end

  @doc "Serializa una struct `Premio` a un mapa con claves string para persistir en JSON."
  def to_map(%__MODULE__{} = p) do
    %{
      "id" => p.id,
      "nombre" => p.nombre,
      "valor" => p.valor
    }
  end
end
