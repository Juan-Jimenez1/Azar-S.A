defmodule AzarApp.Model.Structure.Sorteo do

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
