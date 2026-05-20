defmodule AzarApp.Admins do
  alias AzarApp.JsonStore
  alias AzarApp.Model.Structure.Admin

  def get_admin(id) do
    case Enum.find(JsonStore.all(:admins), &(&1.id == id)) do
      nil   -> :error
      admin -> {:ok, admin}
    end
  end

  def get_admin_by_nombre(nombre) do
    case Enum.find(JsonStore.all(:admins), &(&1.nombre == nombre)) do
      nil   -> :error
      admin -> {:ok, admin}
    end
  end

  def listar do
    JsonStore.all(:admins)
  end

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
