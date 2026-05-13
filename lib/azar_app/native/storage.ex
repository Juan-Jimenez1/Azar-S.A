defmodule AzarApp.Storage do
  @file_path "sorteos.json"

  def save_sorteo(data) do
    sorteos = read_sorteos()

    nuevos = [data | sorteos]

    File.write!(@file_path, Jason.encode!(nuevos, pretty: true))
  end

  def read_sorteos do
    case File.read(@file_path) do
      {:ok, content} ->
        Jason.decode!(content)

      _ ->
        []
    end
  end
end
