defmodule AzarApp.Model.Structure.Admin do

  defstruct [
    :id,
    :nombre,
    :password_hash
  ]

  def to_struct(m) do
    %__MODULE__{
      id: m["id"],
      nombre: m["nombre"],
      password_hash: m["password_hash"]
    }
  end

  
  def to_struct_list(list) when is_list(list) do
    Enum.map(list, &to_struct/1)
  end

  def to_map(%__MODULE__{} = a) do
    %{
      "id" => a.id,
      "nombre" => a.nombre,
      "password_hash" => a.password_hash
    }
  end
end
