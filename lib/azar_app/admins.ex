defmodule AzarApp.Admins do
  @moduledoc """
  Contexto de gestión de administradores del sistema.

  Proporciona operaciones CRUD para cuentas de administrador, autenticación
  y protección para evitar dejar el sistema sin ningún administrador activo.

  Las contraseñas se almacenan como hash SHA-256 (hex en minúsculas).
  """

  alias AzarApp.JsonStore
  alias AzarApp.Model.Structure.Admin

  @doc "Busca un administrador por su `id`. Retorna `{:ok, admin}` o `:error`."
  def get_admin(id) do
    case Enum.find(JsonStore.all(:admins), &(&1.id == id)) do
      nil   -> :error
      admin -> {:ok, admin}
    end
  end

  @doc "Busca un administrador por su nombre de usuario. Retorna `{:ok, admin}` o `:error`."
  def get_admin_by_nombre(nombre) do
    case Enum.find(JsonStore.all(:admins), &(&1.nombre == nombre)) do
      nil   -> :error
      admin -> {:ok, admin}
    end
  end

  @doc "Retorna la lista de todos los administradores registrados."
  def listar do
    JsonStore.all(:admins)
  end

  @doc """
  Autentica a un administrador por nombre y contraseña.

  Retorna `{:ok, admin}` si las credenciales son válidas, o
  `{:error, motivo}` si el administrador no existe o la contraseña es incorrecta.
  """
  def login(nombre, password) do
    case get_admin_by_nombre(nombre) do
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

  @doc """
  Crea un nuevo administrador con los parámetros dados.

  Espera un mapa con las claves `"nombre"` y `"password"`.
  Retorna `{:ok, admin}` si se creó con éxito, o `{:error, motivo}` si
  ya existe un administrador con ese nombre.
  """
  def crear(params) do
    case get_admin_by_nombre(params["nombre"]) do
      {:ok, _} ->
        {:error, "Ya existe un admin con ese nombre"}

      :error ->
        admin = %Admin{
          id:            JsonStore.generar_id("admin"),
          nombre:        params["nombre"],
          password_hash: hashear(params["password"])
        }

        JsonStore.upsert(:admins, admin)
        {:ok, admin}
    end
  end

  @doc """
  Elimina el administrador con el `id` dado.

  No permite eliminar al último administrador del sistema.
  Retorna `:ok` o `{:error, motivo}`.
  """
  def eliminar(id) do
    if length(listar()) <= 1 do
      {:error, "No puedes eliminar el único administrador"}
    else
      JsonStore.delete(:admins, id)
    end
  end

  defp hashear(password) do
    :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
  end
end
