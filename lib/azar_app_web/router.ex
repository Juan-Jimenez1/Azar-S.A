defmodule AzarAppWeb.Router do
  use AzarAppWeb, :router

  # ── Pipelines ───────────────────────────────────────────────────────────────

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AzarAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Registra cada solicitud en la bitácora (pantalla + archivo de log)
    plug AzarAppWeb.Plugs.LoggerBitacora
  end

  # Requiere sesión de administrador activa
  pipeline :admin_auth do
    plug AzarAppWeb.Plugs.AdminAuth
  end

  # Requiere sesión de jugador activa
  pipeline :jugador_auth do
    plug AzarAppWeb.Plugs.JugadorAuth
  end

  # ── Admin: rutas públicas (login / logout) ──────────────────────────────────

  scope "/admin", AzarAppWeb.Admin, as: :admin do
    pipe_through :browser

    get "/login", AuthController, :login
    post "/login", AuthController, :login_post
    delete "/logout", AuthController, :logout
  end

  # ── Admin: rutas protegidas ──────────────────────────────────────────────────

  scope "/admin", AzarAppWeb.Admin, as: :admin do
    pipe_through [:browser, :admin_auth]

    # Sorteos
    get "/sorteos", SorteoController, :index
    get "/sorteos/nuevo", SorteoController, :new
    post "/sorteos", SorteoController, :create
    get "/sorteos/:id", SorteoController, :show
    delete "/sorteos/:id", SorteoController, :delete

    # Premios de un sorteo
    get "/sorteos/:sorteo_id/premios/nuevo", PremioController, :new
    post "/sorteos/:sorteo_id/premios", PremioController, :create
    delete "/sorteos/:sorteo_id/premios", PremioController, :delete

    # Ejecución de sorteos
    post "/sistema/actualizar-fecha", SistemaController, :ejecutar_sorteos_pendientes
    post "/sorteos/:id/ejecutar", SistemaController, :ejecutar_sorteo

    # Reportes
    get "/balance", ReporteController, :balance
    get "/premios-entregados", ReporteController, :premios_entregados
  end

  # ── Jugador: rutas públicas (login / registro / ver sorteos) ────────────────

  scope "/", AzarAppWeb.Jugador, as: :jugador do
    pipe_through :browser

    # Autenticación
    get "/", ClienteController, :login
    post "/", ClienteController, :login
    get "/registro", ClienteController, :new
    post "/registro", ClienteController, :create
    delete "/logout", ClienteController, :logout

    # Listado de sorteos (visible sin login, pero muestra info del cliente si está logueado)
    get "/index", SorteoController, :index
    get "/sorteos/:id", SorteoController, :show
  end

  # ── Jugador: rutas protegidas (requieren sesión) ─────────────────────────────

  scope "/", AzarAppWeb.Jugador, as: :jugador do
    pipe_through [:browser, :jugador_auth]

    # Perfil y saldo
    get "/perfil", ClienteController, :perfil
    post "/perfil/recargar", ClienteController, :recargar

    # Historial y balance personal
    get "/historial", ClienteController, :historial
    get "/balance", ClienteController, :balance_personal

    # Notificaciones
    get "/notificaciones", ClienteController, :notificaciones
    post "/notificaciones/leer", ClienteController, :marcar_leidas
    delete "/notificaciones/:id", ClienteController, :eliminar_notificacion

    # Compras de billetes
    post "/sorteos/:id/comprar-billete", CompraController, :comprar_billete
    post "/sorteos/:id/comprar-fraccion", CompraController, :comprar_fraccion
    post "/sorteos/:id/comprar-fracciones-restantes", CompraController, :comprar_fracciones_restantes
    delete "/sorteos/:sorteo_id/devolver/:numero", CompraController, :devolver

    # Pasarelas de pago (PSE)
    get "/pse", PseController, :index
    post "/pse/procesar", PseController, :procesar
    get "/pse/cargando", PseController, :cargando
    get "/pse/exito", PseController, :exito

    # Pasarelas de pago (Tarjeta)
    get "/tarjeta", TarjetaController, :index
    post "/tarjeta/procesar", TarjetaController, :procesar
    get "/tarjeta/cargando", TarjetaController, :cargando
    get "/tarjeta/exito", TarjetaController, :exito
  end
end
