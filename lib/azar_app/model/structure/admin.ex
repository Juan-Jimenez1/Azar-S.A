defmodule AzarApp.Model.Structure.Admin do
  @moduledoc """
  Estructura de datos para un administrador del sistema.

  Campos:
  - `id` — identificador único generado por `JsonStore.generar_id/1`
  - `nombre` — nombre de usuario único
  - `password_hash` — hash SHA-256 de la contraseña en hex minúsculas
  """

  defstruct [
    :id,
    :nombre,
    :password_hash
  ]

  @doc "Deserializa un mapa con claves string (proveniente de JSON) a una struct `Admin`."
  def to_struct(m) do
    %__MODULE__{
      id: m["id"],
      nombre: m["nombre"],
      password_hash: m["password_hash"]
    }
  end

  @doc "Deserializa una lista de mapas a una lista de structs `Admin`."
  def to_struct_list(list) when is_list(list) do
    Enum.map(list, &to_struct/1)
  end

  @doc "Serializa una struct `Admin` a un mapa con claves string para persistir en JSON."
  def to_map(%__MODULE__{} = a) do
    %{
      "id" => a.id,
      "nombre" => a.nombre,
      "password_hash" => a.password_hash
    }
  end
end
