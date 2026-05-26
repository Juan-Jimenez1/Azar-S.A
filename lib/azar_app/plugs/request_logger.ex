defmodule AzarApp.Plugs.RequestLogger do
  @moduledoc """
  Plug que registra cada petición HTTP en `AzarApp.Logger`.

  Usa el callback `register_before_send/2` para capturar el resultado
  de la respuesta (código de estado) antes de enviarla al cliente.
  Extrae: fecha, método, ruta, clasificación del status, IP remota y
  el identificador del usuario activo (cliente o admin).
  """

  import Plug.Conn

  def init(opts), do: opts

  @doc "Registra el request en el logger de auditoría al finalizar la respuesta."
  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      entrada = %{
        fecha:     DateTime.utc_now() |> DateTime.to_string() |> String.slice(0, 19),
        metodo:    conn.method,
        ruta:      conn.request_path,
        resultado: resultado(conn.status),
        ip:        conn.remote_ip |> Tuple.to_list() |> Enum.join("."),
        usuario:   get_session(conn, :cliente_doc) || get_session(conn, :admin_id) || "anónimo"
      }

      AzarApp.Logger.registrar(entrada)
      conn
    end)
  end

  defp resultado(status) when status in 200..299, do: "OK (#{status})"
  defp resultado(status) when status in 300..399, do: "REDIRECT (#{status})"
  defp resultado(status) when status in 400..499, do: "NEGADO (#{status})"
  defp resultado(status) when status in 500..599, do: "ERROR (#{status})"
  defp resultado(status),                         do: "#{status}"
end
