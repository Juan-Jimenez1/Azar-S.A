defmodule AzarAppWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: AzarAppWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(AzarAppWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(AzarAppWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  def theme_toggle(assigns) do
  ~H"""
  <div id="theme-toggle" class="relative" x-data="{ open: false }">

    <button
      id="theme-btn"
      onclick="toggleThemePanel()"
      class="group relative w-11 h-11 rounded-2xl flex items-center justify-center transition-all duration-300 overflow-hidden"
      style="background: rgba(255,255,255,0.05); backdrop-filter: blur(20px); border: 1px solid rgba(255,255,255,0.1);"
      title="Cambiar tema"
    >
      <!-- Liquid blob -->
      <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500"
           style="background: radial-gradient(circle at 50% 50%, rgba(212,160,23,0.15), transparent 70%);">
      </div>

      <!-- Sol (light) -->
      <svg id="icon-light" class="w-5 h-5 absolute transition-all duration-500 opacity-0 scale-50 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <circle cx="12" cy="12" r="5"/>
        <path stroke-linecap="round" d="M12 2v2M12 20v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M2 12h2M20 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
      </svg>

      <!-- Luna (dark) -->
      <svg id="icon-dark" class="w-5 h-5 absolute transition-all duration-500 opacity-0 scale-50 text-indigo-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M21 12.79A9 9 0 1111.21 3a7 7 0 009.79 9.79z"/>
      </svg>

      <!-- Monitor (system) -->
      <svg id="icon-system" class="w-5 h-5 absolute transition-all duration-500 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <rect x="2" y="3" width="20" height="14" rx="2"/>
        <path stroke-linecap="round" d="M8 21h8M12 17v4"/>
      </svg>

    </button>

    <!-- Panel liquid glass -->
    <div
      id="theme-panel"
      class="absolute right-0 top-14 z-50 hidden"
      style="width: 220px;"
    >
      <!-- Liquid glass container -->
      <div class="relative overflow-hidden rounded-[24px] p-1.5"
           style="background: rgba(255,255,255,0.07); backdrop-filter: blur(40px) saturate(200%); -webkit-backdrop-filter: blur(40px) saturate(200%); border: 1px solid rgba(255,255,255,0.12); box-shadow: 0 20px 60px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.1);">

        <!-- Blob decorativo -->
        <div class="absolute -top-8 -right-8 w-24 h-24 rounded-full opacity-30 animate-liquid"
             style="background: radial-gradient(circle, rgba(212,160,23,0.4), transparent 70%);">
        </div>
        <div class="absolute -bottom-6 -left-6 w-20 h-20 rounded-full opacity-20 animate-liquid"
             style="background: radial-gradient(circle, rgba(99,102,241,0.5), transparent 70%); animation-delay: -3s;">
        </div>

        <p class="text-[10px] uppercase tracking-[0.25em] text-gray-500 px-3 pt-2 pb-1.5 font-semibold">
          Apariencia
        </p>

        <!-- Opciones -->
        <button onclick="setThemeOption('light')"
          id="opt-light"
          class="theme-option w-full flex items-center gap-3 px-3 py-3 rounded-[18px] transition-all duration-200 text-left group/opt">
          <div class="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 transition-all duration-200"
               style="background: rgba(250,204,21,0.1); border: 1px solid rgba(250,204,21,0.15);">
            <svg class="w-4 h-4 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="5"/>
              <path stroke-linecap="round" d="M12 2v2M12 20v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M2 12h2M20 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
            </svg>
          </div>
          <div>
            <p class="text-sm font-semibold text-white">Claro</p>
            <p class="text-xs text-gray-500">Fondo luminoso</p>
          </div>
          <div id="check-light" class="ml-auto w-4 h-4 rounded-full hidden"
               style="background: linear-gradient(135deg, #f6d06b, #d4a017); box-shadow: 0 0 8px rgba(212,160,23,0.6);">
          </div>
        </button>

        <button onclick="setThemeOption('dark')"
          id="opt-dark"
          class="theme-option w-full flex items-center gap-3 px-3 py-3 rounded-[18px] transition-all duration-200 text-left group/opt">
          <div class="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 transition-all duration-200"
               style="background: rgba(99,102,241,0.1); border: 1px solid rgba(99,102,241,0.15);">
            <svg class="w-4 h-4 text-indigo-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M21 12.79A9 9 0 1111.21 3a7 7 0 009.79 9.79z"/>
            </svg>
          </div>
          <div>
            <p class="text-sm font-semibold text-white">Oscuro</p>
            <p class="text-xs text-gray-500">Fondo profundo</p>
          </div>
          <div id="check-dark" class="ml-auto w-4 h-4 rounded-full hidden"
               style="background: linear-gradient(135deg, #818cf8, #6366f1); box-shadow: 0 0 8px rgba(99,102,241,0.6);">
          </div>
        </button>

        <button onclick="setThemeOption('system')"
          id="opt-system"
          class="theme-option w-full flex items-center gap-3 px-3 py-3 rounded-[18px] transition-all duration-200 text-left group/opt">
          <div class="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 transition-all duration-200"
               style="background: rgba(107,114,128,0.1); border: 1px solid rgba(107,114,128,0.15);">
            <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <rect x="2" y="3" width="20" height="14" rx="2"/>
              <path stroke-linecap="round" d="M8 21h8M12 17v4"/>
            </svg>
          </div>
          <div>
            <p class="text-sm font-semibold text-white">Sistema</p>
            <p class="text-xs text-gray-500">Según tu dispositivo</p>
          </div>
          <div id="check-system" class="ml-auto w-4 h-4 rounded-full hidden"
               style="background: linear-gradient(135deg, #9ca3af, #6b7280); box-shadow: 0 0 8px rgba(107,114,128,0.5);">
          </div>
        </button>

      </div>
    </div>

  </div>

  <script>
    (function() {
      function getCurrentTheme() {
        return localStorage.getItem("phx:theme") || "system";
      }

      function updateIcons(theme) {
        document.getElementById("icon-light").classList.toggle("opacity-100", theme === "light");
        document.getElementById("icon-light").classList.toggle("scale-100",   theme === "light");
        document.getElementById("icon-light").classList.toggle("opacity-0",   theme !== "light");
        document.getElementById("icon-light").classList.toggle("scale-50",    theme !== "light");

        document.getElementById("icon-dark").classList.toggle("opacity-100", theme === "dark");
        document.getElementById("icon-dark").classList.toggle("scale-100",   theme === "dark");
        document.getElementById("icon-dark").classList.toggle("opacity-0",   theme !== "dark");
        document.getElementById("icon-dark").classList.toggle("scale-50",    theme !== "dark");

        document.getElementById("icon-system").classList.toggle("opacity-100", theme === "system");
        document.getElementById("icon-system").classList.toggle("opacity-40",  theme !== "system");

        ["light","dark","system"].forEach(t => {
          document.getElementById("check-" + t).classList.toggle("hidden", t !== theme);
          const opt = document.getElementById("opt-" + t);
          if (t === theme) {
            opt.style.background = "rgba(255,255,255,0.06)";
          } else {
            opt.style.background = "";
          }
        });
      }

      window.setThemeOption = function(theme) {
        if (theme === "system") {
          localStorage.removeItem("phx:theme");
          document.documentElement.removeAttribute("data-theme");
        } else {
          localStorage.setItem("phx:theme", theme);
          document.documentElement.setAttribute("data-theme", theme);
        }
        updateIcons(theme);

        // Animación del botón
        const btn = document.getElementById("theme-btn");
        btn.style.transform = "scale(0.9)";
        setTimeout(() => btn.style.transform = "", 150);
      };

      window.toggleThemePanel = function() {
        const panel = document.getElementById("theme-panel");
        const isHidden = panel.classList.contains("hidden");

        if (isHidden) {
          panel.classList.remove("hidden");
          panel.style.opacity = "0";
          panel.style.transform = "translateY(-8px) scale(0.96)";
          panel.style.transition = "opacity 0.2s ease, transform 0.2s ease";
          requestAnimationFrame(() => {
            panel.style.opacity = "1";
            panel.style.transform = "translateY(0) scale(1)";
          });
        } else {
          panel.style.opacity = "0";
          panel.style.transform = "translateY(-8px) scale(0.96)";
          setTimeout(() => panel.classList.add("hidden"), 200);
        }
      };

      // Cerrar al click fuera
      document.addEventListener("click", function(e) {
        const toggle = document.getElementById("theme-toggle");
        if (toggle && !toggle.contains(e.target)) {
          const panel = document.getElementById("theme-panel");
          if (panel && !panel.classList.contains("hidden")) {
            panel.style.opacity = "0";
            panel.style.transform = "translateY(-8px) scale(0.96)";
            setTimeout(() => panel.classList.add("hidden"), 200);
          }
        }
      });

      updateIcons(getCurrentTheme());
    })();
  </script>
  """
end
end
