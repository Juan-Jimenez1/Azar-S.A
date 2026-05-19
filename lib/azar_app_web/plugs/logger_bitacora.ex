defmodule AzarAppWeb.Plugs.LoggerBitacora do
  @moduledoc """
  Plug que registra cada solicitud HTTP en la bitácora.
  Usa register_before_send/2 para capturar el status code real
  después de que el controlador haya terminado de procesar la petición.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      metodo  = conn.method
      ruta    = conn.request_path
      usuario = get_session(conn, :cliente_doc) || get_session(conn, :admin_doc) || "anónimo"
      estado  = if conn.status in 200..399, do: "OK", else: "NEGADO"
      ahora   = DateTime.utc_now() |> DateTime.to_string()
      linea   = "[#{ahora}] USUARIO: #{usuario} | #{metodo} #{ruta} | #{estado}\n"
      AzarApp.Bitacora.escribir(linea)
      conn
    end)
  end
end
