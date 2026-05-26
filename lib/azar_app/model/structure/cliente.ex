defmodule AzarApp.Model.Structure.Cliente do
  @moduledoc """
  Estructura de datos para un jugador (cliente) de la plataforma.

  Campos:
  - `id` — identificador único generado por `JsonStore.generar_id/1`
  - `nombre` — nombre completo del jugador
  - `documento` — número de documento (cédula), clave única de acceso
  - `password_hash` — hash SHA-256 de la contraseña
  - `pregunta_secreta` — texto de la pregunta para recuperación de contraseña
  - `respuesta_hash` — hash SHA-256 de la respuesta (normalizada a minúsculas sin espacios)
  - `saldo` — saldo disponible en pesos (entero, por defecto 0)
  - `notificaciones` — lista de mapas con las notificaciones del jugador
  """

  defstruct [
    :id,
    :nombre,
    :documento,
    :password_hash,
    :pregunta_secreta,
    :respuesta_hash,
    saldo: 0,
    notificaciones: []
  ]

  @doc "Deserializa un mapa con claves string (proveniente de JSON) a una struct `Cliente`."
  def to_struct(m) do
    %__MODULE__{
      id:               m["id"],
      nombre:           m["nombre"],
      documento:        m["documento"],
      password_hash:    m["password_hash"],
      pregunta_secreta: m["pregunta_secreta"],
      respuesta_hash:   m["respuesta_hash"],
      saldo:            m["saldo"] || 0,
      notificaciones:   m["notificaciones"] || []
    }
  end

  @doc "Serializa una struct `Cliente` a un mapa con claves string para persistir en JSON."
  def to_map(%__MODULE__{} = c) do
    %{
      "id"               => c.id,
      "nombre"           => c.nombre,
      "documento"        => c.documento,
      "password_hash"    => c.password_hash,
      "pregunta_secreta" => c.pregunta_secreta,
      "respuesta_hash"   => c.respuesta_hash,
      "saldo"            => c.saldo,
      "notificaciones"   => c.notificaciones
    }
  end
end
