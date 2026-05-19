defmodule AzarApp.Admins do
  @moduledoc "Lógica de negocio para administradores del sistema."

  alias AzarApp.JsonStore

  # ── Consultas ────────────────────────────────────────────────────────────────

  def get_admin(documento) do
    case Enum.find(JsonStore.all(:admins), &(&1.documento == documento)) do
      nil  -> :error
      admin -> {:ok, admin}
    end
  end

  # ── Autenticación ────────────────────────────────────────────────────────────

  def login(documento, password) do
    case get_admin(documento) do
      {:ok, admin} ->
        if admin.password_hash == hashear(password) do
          {:ok, admin}
        else
          {:error, "Contraseña incorrecta"}
        end

      :error ->
        {:error, "Administrador no encontrado"}
    end
  end

  # ── Privado ──────────────────────────────────────────────────────────────────

  defp hashear(password) do
    :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
  end
end
