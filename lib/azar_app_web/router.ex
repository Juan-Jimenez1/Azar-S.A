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

    # Sorteos
    get    "/sorteos",              SorteoController, :index
    get    "/sorteos/nuevo",        SorteoController, :new
    post   "/sorteos",              SorteoController, :create
    get    "/sorteos/:id",          SorteoController, :show
    delete "/sorteos/:id",          SorteoController, :delete

    # Premios (anidados bajo sorteo)
    get    "/sorteos/:sorteo_id/premios/nuevo",      PremioController, :new
    post   "/sorteos/:sorteo_id/premios",            PremioController, :create
    delete "/sorteos/:sorteo_id/premios/:premio_id", PremioController, :delete

    # Ejecutar sorteos pendientes
    post "/sistema/actualizar-fecha", SistemaController, :actualizar_fecha
  end

  # ── Jugador ────────────────────────────────────────────────────────────────
  scope "/", AzarAppWeb.Jugador, as: :jugador do
    pipe_through :browser

    get  "/",                                         SorteoController, :index
    get  "/sorteos/:id",                              SorteoController, :show
    post "/sorteos/:id/comprar-billete",              CompraController, :comprar_billete
    post "/sorteos/:id/comprar-fraccion",             CompraController, :comprar_fraccion
    delete "/sorteos/:sorteo_id/devolver/:numero",    CompraController, :devolver
  end
end
