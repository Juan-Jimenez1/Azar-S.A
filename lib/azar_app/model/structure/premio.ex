defmodule AzarApp.Model.Structure.Premio do

  defstruct [
    :id,
    :nombre,
    :valor
  ]

  def to_struct(m) do
    %__MODULE__{
      id: m["id"],
      nombre: m["nombre"],
      valor: m["valor"]
    }
  end

  def to_map(%__MODULE__{} = p) do
    %{
      "id" => p.id,
      "nombre" => p.nombre,
      "valor" => p.valor
    }
  end
end
