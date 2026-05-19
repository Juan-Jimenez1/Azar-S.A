defmodule AzarAppWeb.Admin.ReporteController do
  use AzarAppWeb, :controller
  alias AzarApp.Sorteos

  @doc "Balance general de todos los sorteos realizados."
  def balance(conn, _params) do
    balances = Sorteos.balance_total()
    total    = Enum.sum(Enum.map(balances, & &1.balance))
    resultado = if total >= 0, do: "ganancia", else: "pérdida"
    render(conn, :balance, balances: balances, total: total, resultado: resultado)
  end

  @doc "Premios entregados en sorteos pasados con detalle de ganadores e ingresos."
  def premios_entregados(conn, _params) do
    datos = Sorteos.premios_entregados()
    render(conn, :premios_entregados, datos: datos)
  end
end
