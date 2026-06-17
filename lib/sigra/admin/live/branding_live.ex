defmodule Sigra.Admin.Live.BrandingLive do
  @moduledoc """
  Global auth and email branding customizer for generated Sigra installs.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Branding
  alias Sigra.Branding.Profile

  @panels [:light, :dark, :details]
  @light_color_fields [
    {"accent_color", "Accent"},
    {"accent_foreground", "On accent"},
    {"background_color", "Background"},
    {"surface_color", "Surface"},
    {"text_color", "Text"},
    {"muted_color", "Muted"},
    {"border_color", "Border"}
  ]
  @dark_color_fields [
    {"dark_accent_color", "Accent"},
    {"dark_accent_foreground", "On accent"},
    {"dark_background_color", "Background"},
    {"dark_surface_color", "Surface"},
    {"dark_text_color", "Text"},
    {"dark_muted_color", "Muted"},
    {"dark_border_color", "Border"}
  ]
  @source_labels %{
    admin_profile: "Admin profile",
    config_defaults: "Config defaults"
  }
  @form_keys ~w(
    product_name
    logo_url
    logo_alt
    theme
    accent_color
    accent_foreground
    background_color
    surface_color
    text_color
    muted_color
    border_color
    dark_accent_color
    dark_accent_foreground
    dark_background_color
    dark_surface_color
    dark_text_color
    dark_muted_color
    dark_border_color
    support_url
    privacy_url
    terms_url
    email_from_name
    email_from_address
    email_reply_to
  )

  @impl true
  def mount(_params, _session, socket) do
    config = Sigra.Admin.runtime_config!("Sigra auth branding")
    {profile, profile_source} = load_profile(config)
    draft_params = profile_to_form_params(profile)

    {:ok,
     socket
     |> assign(:sigra_config, config)
     |> assign(:light_color_fields, @light_color_fields)
     |> assign(:dark_color_fields, @dark_color_fields)
     |> assign(:persisted_profile, profile)
     |> assign(:preview_profile, profile)
     |> assign(:draft_params, draft_params)
     |> assign(:profile_source, profile_source)
     |> assign(:dirty?, false)
     |> assign(:error, nil)
     |> assign(:restore_defaults_open?, false)
     |> assign(:active_panel, default_panel(profile))
     |> assign(:page_title, "Auth branding")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    panel = panel_from_param(params["panel"], socket.assigns.persisted_profile)

    {:noreply, assign(socket, :active_panel, panel)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="sg-stack sg-stack--6">
      <link phx-track-static rel="stylesheet" href="/assets/sigra_auth.css" />

      <header class="sg-page-header">
        <p class="sg-page-kicker">Branding</p>
        <h1 class="sg-page-title">Auth forms and emails</h1>
        <p class="sg-page-copy">
          Tune the generated login, account, invitation, and transactional email defaults without replacing the host-owned templates.
        </p>
      </header>

      <.scope_ribbon copy="Global auth/email profile" />

      <.notice :if={@error} tone={:risk} role="alert">
        {@error}
      </.notice>

      <section class="sg-branding-editor sg-stack sg-stack--4" data-testid="admin-auth-branding-workbench">
        <div class="sg-toolbar">
          <div class="sg-branding-editor__status">
            <div class="sg-stack sg-stack--1">
              <h2 class="sg-section-heading">Brand tokens</h2>
              <p class="sg-section-copy">Source: {source_label(@profile_source)}</p>
            </div>
            <p :if={@dirty?} class="sg-branding-draft sg-text-sm sg-strong">Unsaved preview</p>
          </div>
        </div>

        <nav class="sg-tabs" aria-label="Branding sections">
          <.link
            id="branding-tab-light"
            class={tab_class(@active_panel, :light)}
            patch={panel_path(:light)}
            aria-current={current_panel_attr(@active_panel, :light)}
          >
            Light
          </.link>
          <.link
            id="branding-tab-dark"
            class={tab_class(@active_panel, :dark)}
            patch={panel_path(:dark)}
            aria-current={current_panel_attr(@active_panel, :dark)}
          >
            Dark
          </.link>
          <.link
            id="branding-tab-details"
            class={tab_class(@active_panel, :details)}
            patch={panel_path(:details)}
            aria-current={current_panel_attr(@active_panel, :details)}
          >
            Details
          </.link>
        </nav>

        <section class="sg-stack sg-stack--4">
          <form
            id="auth-branding-form"
            class="sg-stack sg-stack--4"
            phx-change="validate"
            phx-submit="save"
            phx-hook="AuthBrandingPreview"
            data-sg-auth-branding-preview-form="true"
            data-testid="admin-auth-branding-form"
          >
            <section
              id="branding-panel-light"
              class="sg-branding-panel"
              aria-labelledby="branding-tab-light"
              hidden={@active_panel != :light}
              data-testid="admin-auth-branding-light-panel"
            >
              <div class="sg-branding-workbench">
                <section class="sg-card sg-stack sg-stack--4 sg-branding-workbench__controls">
                  <fieldset class="sg-fieldset">
                    <legend class="sg-fieldset__legend sg-section-heading">Light palette</legend>
                    <p class="sg-section-copy">Shown on generated auth screens when Light is selected.</p>
                    <div class="sg-form-grid sg-color-grid">
                      <.color_field
                        :for={{name, label} <- @light_color_fields}
                        name={name}
                        label={label}
                        value={field_value(@draft_params, name)}
                      />
                    </div>
                  </fieldset>
                </section>

                <.preview_pair
                  profile={@preview_profile}
                  theme="light"
                  active={@active_panel == :light}
                  login_testid="admin-auth-branding-light-login-preview"
                  email_testid="admin-auth-branding-light-email-preview"
                  email_surface_testid="admin-auth-branding-light-email-preview-surface"
                />
              </div>
            </section>

            <section
              id="branding-panel-dark"
              class="sg-branding-panel"
              aria-labelledby="branding-tab-dark"
              hidden={@active_panel != :dark}
              data-testid="admin-auth-branding-dark-panel"
            >
              <div class="sg-branding-workbench">
                <section class="sg-card sg-stack sg-stack--4 sg-branding-workbench__controls">
                  <fieldset class="sg-fieldset">
                    <legend class="sg-fieldset__legend sg-section-heading">Dark palette</legend>
                    <p class="sg-section-copy">Shown when Dark is selected, or when System resolves dark.</p>
                    <div class="sg-form-grid sg-color-grid">
                      <.color_field
                        :for={{name, label} <- @dark_color_fields}
                        name={name}
                        label={label}
                        value={field_value(@draft_params, name)}
                      />
                    </div>
                  </fieldset>
                </section>

                <.preview_pair
                  profile={@preview_profile}
                  theme="dark"
                  active={@active_panel == :dark}
                  login_testid="admin-auth-branding-dark-login-preview"
                  email_testid="admin-auth-branding-dark-email-preview"
                  email_surface_testid="admin-auth-branding-dark-email-preview-surface"
                />
              </div>
            </section>

            <section
              id="branding-panel-details"
              class="sg-branding-panel"
              aria-labelledby="branding-tab-details"
              hidden={@active_panel != :details}
              data-testid="admin-auth-branding-details-panel"
            >
              <div class="sg-branding-workbench">
                <section class="sg-card sg-stack sg-stack--4 sg-branding-workbench__controls">
                  <div class="sg-stack sg-stack--1">
                    <h2 class="sg-section-heading">Profile details</h2>
                    <p class="sg-section-copy">Controls identity, links, email sender defaults, and the generated theme mode.</p>
                  </div>

                  <div class="sg-form-grid sg-branding-details-grid">
                    <.detail_input
                      name="product_name"
                      label="Product name"
                      value={field_value(@draft_params, "product_name")}
                      required
                    />
                    <.detail_input
                      name="logo_url"
                      label="Logo URL"
                      value={field_value(@draft_params, "logo_url")}
                      help="Shown on generated auth screens and email headers when set. Use an absolute URL that email clients can load."
                    />
                    <.detail_input
                      name="logo_alt"
                      label="Logo alt text"
                      value={field_value(@draft_params, "logo_alt")}
                      help={"Used when a logo is shown. Keep it short, like \"Acme logo\"."}
                      required
                    />
                    <.detail_select
                      name="theme"
                      label="Theme mode"
                      value={field_value(@draft_params, "theme")}
                      options={[{"system", "System"}, {"light", "Light"}, {"dark", "Dark"}]}
                      help="System follows the user's device setting. Light or Dark forces generated auth screens into that theme."
                    />
                  </div>

                  <div class="sg-form-grid sg-branding-details-grid">
                    <.detail_input
                      name="support_url"
                      label="Support URL"
                      value={field_value(@draft_params, "support_url")}
                      help="Adds a Support link to generated auth screen footers. Leave blank to hide it."
                    />
                    <.detail_input
                      name="privacy_url"
                      label="Privacy URL"
                      value={field_value(@draft_params, "privacy_url")}
                      help="Adds a Privacy link to generated auth screen footers. Leave blank to hide it."
                    />
                    <.detail_input
                      name="terms_url"
                      label="Terms URL"
                      value={field_value(@draft_params, "terms_url")}
                      help="Adds a Terms link to generated auth screen footers. Leave blank to hide it."
                    />
                  </div>

                  <div class="sg-form-grid sg-branding-details-grid">
                    <.detail_input
                      name="email_from_name"
                      label="Email from name"
                      value={field_value(@draft_params, "email_from_name")}
                      help="Display name recipients see on generated auth emails."
                      required
                    />
                    <.detail_input
                      name="email_from_address"
                      label="Email from address"
                      value={field_value(@draft_params, "email_from_address")}
                      help="Sender address for generated auth emails. Use an address your mailer is allowed to send from."
                    />
                    <.detail_input
                      name="email_reply_to"
                      label="Reply-to"
                      value={field_value(@draft_params, "email_reply_to")}
                      help="Replies go to this address when set. Leave blank to use the sender address."
                    />
                  </div>
                </section>

                <.preview_pair
                  profile={@preview_profile}
                  theme={theme_attr(@preview_profile)}
                  active={@active_panel == :details}
                  login_testid="admin-auth-branding-details-login-preview"
                  email_testid="admin-auth-branding-details-email-preview"
                  email_surface_testid="admin-auth-branding-details-email-preview-surface"
                />
              </div>
            </section>

            <div class="sg-action-row">
              <button type="submit" class="sg-btn sg-btn--primary">Save profile</button>
              <button
                :if={@dirty?}
                type="button"
                class="sg-btn sg-btn--secondary"
                phx-click="discard_changes"
              >
                Discard changes
              </button>
              <button
                :if={admin_profile?(@profile_source)}
                type="button"
                class="sg-btn sg-btn--danger"
                phx-click="open_restore_defaults"
              >
                Restore config defaults
              </button>
            </div>
          </form>
        </section>
      </section>

      <div :if={@restore_defaults_open?} id="restore-defaults-overlay" phx-hook="ConfirmDialog" class="sg-confirm-overlay" role="presentation">
        <section
          class="sg-confirm-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="restore-defaults-title"
        >
          <p id="restore-defaults-title" class="sg-section-heading">Restore defaults?</p>
          <p class="sg-text-sm" style="margin-top: var(--sg-space-3);">
            This removes the saved admin branding changes and uses the app's configured defaults for generated auth screens and emails. Unsaved preview changes will also be discarded.
          </p>
          <div class="sg-confirm-dialog__actions">
            <button
              type="button"
              phx-click="cancel_restore_defaults"
              class="sg-btn sg-btn--ghost sg-btn--sm"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="restore_config_defaults"
              class="sg-btn sg-btn--danger sg-btn--sm is-armed"
            >
              Restore defaults
            </button>
          </div>
        </section>
      </div>
    </section>
    """
  end

  @impl true
  def handle_event("validate", %{"branding" => params}, socket) do
    draft_params = form_params(params, socket.assigns.draft_params)

    case Profile.new(draft_params) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> assign(:preview_profile, profile)
         |> assign(:draft_params, draft_params)
         |> assign(:dirty?, true)
         |> assign(:error, nil)
         |> assign(:restore_defaults_open?, false)}

      {:error, message} ->
        {:noreply,
         socket
         |> assign(:draft_params, draft_params)
         |> assign(:dirty?, true)
         |> assign(:error, message)
         |> assign(:restore_defaults_open?, false)}
    end
  end

  def handle_event("save", %{"branding" => params}, socket) do
    draft_params = form_params(params, socket.assigns.draft_params)

    case Branding.save_global(socket.assigns.sigra_config, draft_params,
           actor_id: actor_id(socket)
         ) do
      {:ok, profile} ->
        draft_params = profile_to_form_params(profile)

        {:noreply,
         socket
         |> assign(:persisted_profile, profile)
         |> assign(:preview_profile, profile)
         |> assign(:draft_params, draft_params)
         |> assign(:profile_source, :admin_profile)
         |> assign(:dirty?, false)
         |> assign(:error, nil)
         |> assign(:restore_defaults_open?, false)
         |> put_flash(:info, "Auth branding profile saved.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:draft_params, draft_params)
         |> assign(:dirty?, true)
         |> assign(:error, error_message(reason))
         |> assign(:restore_defaults_open?, false)}
    end
  end

  def handle_event("discard_changes", _params, socket) do
    profile = socket.assigns.persisted_profile
    draft_params = profile_to_form_params(profile)

    {:noreply,
     socket
     |> assign(:preview_profile, profile)
     |> assign(:draft_params, draft_params)
     |> assign(:dirty?, false)
     |> assign(:error, nil)
     |> assign(:restore_defaults_open?, false)
     |> put_flash(:info, "Unsaved branding changes discarded.")}
  end

  def handle_event("open_restore_defaults", _params, socket) do
    {:noreply,
     assign(socket, :restore_defaults_open?, admin_profile?(socket.assigns.profile_source))}
  end

  def handle_event("cancel_restore_defaults", _params, socket) do
    {:noreply, assign(socket, :restore_defaults_open?, false)}
  end

  def handle_event("restore_config_defaults", _params, socket) do
    config = socket.assigns.sigra_config
    profile = Branding.from_config(config)

    case Branding.delete_global(config) do
      :ok ->
        draft_params = profile_to_form_params(profile)

        {:noreply,
         socket
         |> assign(:persisted_profile, profile)
         |> assign(:preview_profile, profile)
         |> assign(:draft_params, draft_params)
         |> assign(:profile_source, :config_defaults)
         |> assign(:dirty?, false)
         |> assign(:error, nil)
         |> assign(:restore_defaults_open?, false)
         |> put_flash(:info, "Auth branding restored to config defaults.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:restore_defaults_open?, false)
         |> assign(error: error_message(reason))}
    end
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :required, :boolean, default: false
  attr :help, :string, default: nil

  defp detail_input(assigns) do
    assigns =
      assigns
      |> assign(:id, detail_field_id(assigns.name))
      |> assign(:help_id, detail_help_id(assigns.name))

    ~H"""
    <div class="sg-field">
      <span class="sg-field-label-row">
        <label class="sg-field-label" for={@id}>{@label}</label>
        <.field_help :if={@help} id={@help_id} label={@label}>{@help}</.field_help>
      </span>
      <input
        id={@id}
        class="sg-input"
        name={"branding[#{@name}]"}
        value={@value}
        required={@required}
      />
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :options, :list, required: true
  attr :help, :string, default: nil

  defp detail_select(assigns) do
    assigns =
      assigns
      |> assign(:id, detail_field_id(assigns.name))
      |> assign(:help_id, detail_help_id(assigns.name))

    ~H"""
    <div class="sg-field">
      <span class="sg-field-label-row">
        <label class="sg-field-label" for={@id}>{@label}</label>
        <.field_help :if={@help} id={@help_id} label={@label}>{@help}</.field_help>
      </span>
      <select id={@id} class="sg-select" name={"branding[#{@name}]"}>
        <option :for={{value, label} <- @options} value={value} selected={@value == value}>
          {label}
        </option>
      </select>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp color_field(assigns) do
    ~H"""
    <label class="sg-field sg-color-field">
      <span class="sg-field-label">{@label}</span>
      <span class="sg-color-field__control">
        <input
          class="sg-color-field__input"
          type="color"
          name={"branding[#{@name}]"}
          value={@value}
          aria-label={@label}
          phx-throttle="120"
          data-sg-auth-branding-color={@name}
        />
        <span
          class="sg-color-field__value sg-muted sg-text-sm sg-tabular"
          data-sg-auth-branding-color-value={@name}
        >
          {@value}
        </span>
      </span>
    </label>
    """
  end

  attr :profile, :any, required: true
  attr :theme, :string, required: true
  attr :active, :boolean, required: true
  attr :login_testid, :string, required: true
  attr :email_testid, :string, required: true
  attr :email_surface_testid, :string, required: true

  defp preview_pair(assigns) do
    ~H"""
    <section class="sg-branding-preview-rail sg-stack sg-stack--4" data-testid={if @active, do: "admin-auth-preview"}>
      <div class="sg-card sg-stack sg-stack--3" data-testid={@login_testid}>
        <h2 class="sg-section-heading">Login preview</h2>
        <div
          class="sigra-auth sigra-auth--preview"
          data-theme={@theme}
          data-sg-auth-branding-preview="login"
          data-sg-auth-branding-preview-theme={@theme}
          style={Branding.css_variables(@profile)}
        >
          <section class="sigra-auth__viewport">
            <div class="sigra-auth__panel">
              <div class="sigra-auth__brand">
                <img :if={@profile.logo_url} src={@profile.logo_url} alt={@profile.logo_alt} class="sigra-auth__logo" />
                <div :if={!@profile.logo_url} class="sigra-auth__mark" aria-hidden="true">
                  <span></span><span></span><span></span>
                </div>
                <p class="sigra-auth__product">{@profile.product_name}</p>
              </div>
              <div class="mx-auto max-w-sm">
                <h1>Log in</h1>
                <p>Use a magic link, passkey, password, or enterprise SSO.</p>
                <div class="sigra-auth-preview-form">
                  <label>Email<input type="email" value="alex@example.com" /></label>
                  <button type="button" class="btn btn-primary w-full">Send magic link</button>
                </div>
              </div>
            </div>
          </section>
        </div>
      </div>

      <div class="sg-card sg-stack sg-stack--3" data-testid={if @active, do: "admin-email-preview", else: @email_testid}>
        <h2 class="sg-section-heading">Email preview</h2>
        <div
          class="sigra-auth-email-preview"
          data-theme={@theme}
          data-sg-auth-branding-preview="email"
          data-sg-auth-branding-preview-theme={@theme}
          data-testid={if @active, do: "admin-email-preview-surface", else: @email_surface_testid}
          style={Branding.css_variables(@profile)}
        >
          <div class="sigra-auth-email-preview__message">
            <strong>{@profile.product_name}</strong>
            <p>
              Confirm your email address by clicking the button below.
            </p>
            <span class="sigra-auth-email-preview__button">
              Confirm email
            </span>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp load_profile(config) do
    base = Branding.from_config(config)

    case Branding.load_global(config, base: base) do
      {:ok, profile} -> {profile, :admin_profile}
      _ -> {base, :config_defaults}
    end
  end

  defp profile_to_form_params(%Profile{} = profile) do
    dark_tokens = Branding.color_tokens(profile, :dark)

    profile
    |> Profile.to_map()
    |> Map.merge(%{
      "dark_accent_color" => Map.fetch!(dark_tokens, :accent_color),
      "dark_accent_foreground" => Map.fetch!(dark_tokens, :accent_foreground),
      "dark_background_color" => Map.fetch!(dark_tokens, :background_color),
      "dark_surface_color" => Map.fetch!(dark_tokens, :surface_color),
      "dark_text_color" => Map.fetch!(dark_tokens, :text_color),
      "dark_muted_color" => Map.fetch!(dark_tokens, :muted_color),
      "dark_border_color" => Map.fetch!(dark_tokens, :border_color)
    })
    |> form_params(%{})
  end

  defp theme_attr(%Profile{theme: theme}), do: to_string(theme)

  defp form_params(params, fallback) do
    Enum.into(@form_keys, %{}, fn key ->
      {key, Map.get(params, key, Map.get(fallback, key, "")) || ""}
    end)
  end

  defp field_value(params, key), do: Map.get(params, key, "")

  defp detail_field_id(name), do: "branding-" <> String.replace(name, "_", "-")
  defp detail_help_id(name), do: detail_field_id(name) <> "-help"

  defp default_panel(%Profile{theme: :dark}), do: :dark
  defp default_panel(%Profile{}), do: :light

  defp panel_from_param(panel, _profile) when panel in ~w(light dark details) do
    String.to_existing_atom(panel)
  end

  defp panel_from_param(_panel, %Profile{} = profile), do: default_panel(profile)

  defp panel_path(panel) when panel in @panels, do: "/admin/auth-branding?panel=#{panel}"

  defp tab_class(active_panel, panel) do
    if active_panel == panel do
      "sg-tabs__tab sg-tabs__tab--active"
    else
      "sg-tabs__tab"
    end
  end

  defp current_panel_attr(active_panel, panel) do
    if active_panel == panel, do: "page"
  end

  defp source_label(profile_source), do: Map.fetch!(@source_labels, profile_source)
  defp admin_profile?(:admin_profile), do: true
  defp admin_profile?(_profile_source), do: false

  defp actor_id(socket) do
    socket.assigns
    |> get_in([:admin_scope, :scope, :user, :id])
  rescue
    _ -> nil
  end

  defp error_message(%{message: message}) when is_binary(message), do: message
  defp error_message(%ArgumentError{} = error), do: Exception.message(error)

  defp error_message(%{__struct__: _module} = exception) do
    Exception.message(exception)
  rescue
    _ -> inspect(exception)
  end

  defp error_message(reason), do: "Could not save auth branding: #{inspect(reason)}"
end
