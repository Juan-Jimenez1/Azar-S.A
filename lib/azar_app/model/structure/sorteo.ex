defmodule AzarApp.Model.Structure.Sorteo do
  @moduledoc """
  Estructura de datos para un sorteo (lotería).

  Campos:
  - `id` — identificador único
  - `nombre` — nombre descriptivo del sorteo
  - `fecha` — fecha de realización en formato ISO 8601 (`"YYYY-MM-DD"`)
  - `valor_billete` — precio del billete completo en pesos (entero)
  - `cantidad_fracciones` — número de fracciones en que se divide cada billete
  - `cantidad_billetes` — total de billetes generados al crear el sorteo
  - `premio` — struct `Premio` asignado, o `nil` si no hay premio
  - `numero_ganador` — número del billete ganador, o `nil` antes de ejecutar
  - `realizado` — `true` si el sorteo ya fue ejecutado
  - `billetes` — lista de mapas que representan el estado de cada billete
  """

  alias AzarApp.Model.Structure.Premio

  defstruct [
    :id,
    :nombre,
    :fecha,
    :valor_billete,
    :cantidad_fracciones,
    :cantidad_billetes,
    :premio,
    numero_ganador: nil,
    realizado: false,
    billetes: []
  ]

  @doc "Deserializa un mapa con claves string (proveniente de JSON) a una struct `Sorteo`, incluyendo el `Premio` anidado."
  def to_struct(m) do
    %__MODULE__{
      id:                  m["id"],
      nombre:              m["nombre"],
      fecha:               m["fecha"],
      valor_billete:       m["valor_billete"],
      cantidad_fracciones: m["cantidad_fracciones"],
      cantidad_billetes:   m["cantidad_billetes"],
      realizado:           m["realizado"] || false,
      numero_ganador:      m["numero_ganador"],
      premio:
        if m["premio"] do
          Premio.to_struct(m["premio"])
        else
          nil
        end,
      billetes: m["billetes"] || []
    }
  end

  @doc "Serializa una struct `Sorteo` a un mapa con claves string para persistir en JSON."
  def to_map(%__MODULE__{} = s) do
    %{
      "id"                  => s.id,
      "nombre"              => s.nombre,
      "fecha"               => s.fecha,
      "valor_billete"       => s.valor_billete,
      "cantidad_fracciones" => s.cantidad_fracciones,
      "cantidad_billetes"   => s.cantidad_billetes,
      "realizado"           => s.realizado,
      "numero_ganador"      => s.numero_ganador,
      "premio" =>
        if s.premio do
          Premio.to_map(s.premio)
        else
          nil
        end,
      "billetes" => s.billetes
    }
  end
end
