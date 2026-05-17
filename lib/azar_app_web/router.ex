defmodule AzarAppWeb.Router do
  use AzarAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AzarAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # ── Admin ──────────────────────────────────────────────────────────────────
  scope "/admin", AzarAppWeb.Admin, as: :admin do
    pipe_through :browser

    get "/sorteos", SorteoController, :index
    get "/sorteos/nuevo", SorteoController, :new
    post "/sorteos", SorteoController, :create
    get "/sorteos/:id", SorteoController, :show
    delete "/sorteos/:id", SorteoController, :delete

    get "/sorteos/:sorteo_id/premios/nuevo", PremioController, :new
    post "/sorteos/:sorteo_id/premios", PremioController, :create
    delete "/sorteos/:sorteo_id/premios", PremioController, :delete

    post "/sistema/actualizar-fecha", SistemaController, :ejecutar_sorteos_pendientes
    post "/sorteos/:id/ejecutar", SistemaController, :ejecutar_sorteo
  end

  # ── Jugador ────────────────────────────────────────────────────────────────
  scope "/", AzarAppWeb.Jugador, as: :jugador do
    pipe_through :browser

    get "/", SorteoController, :index
    get "/sorteos/:id", SorteoController, :show

    post "/sorteos/:id/comprar-billete", CompraController, :comprar_billete
    post "/sorteos/:id/comprar-fraccion", CompraController, :comprar_fraccion
    delete "/sorteos/:sorteo_id/devolver/:numero", CompraController, :devolver

    get "/registro", ClienteController, :new
    post "/registro", ClienteController, :create
    get "/login", ClienteController, :login
    post "/login", ClienteController, :login
    get "/perfil", ClienteController, :perfil
    post "/perfil/recargar", ClienteController, :recargar

    get "/pse", PseController, :index
    post "/pse/procesar", PseController, :procesar
    get "/pse/cargando", PseController, :cargando
    get "/pse/exito", PseController, :exito

    get "/tarjeta", TarjetaController, :index
    post "/tarjeta/procesar", TarjetaController, :procesar
    get "/tarjeta/cargando", TarjetaController, :cargando
    get "/tarjeta/exito", TarjetaController, :exito
  end
end
