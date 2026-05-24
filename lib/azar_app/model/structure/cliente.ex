defmodule AzarApp.Model.Structure.Cliente do

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
