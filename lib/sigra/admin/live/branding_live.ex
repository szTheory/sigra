defmodule Sigra.Admin.Live.BrandingLive do
  @moduledoc """
  Global auth and email branding customizer for generated Sigra installs.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Branding
  alias Sigra.Branding.Profile

  @impl true
  def mount(_params, _session, socket) do
    config = Sigra.Admin.runtime_config!("Sigra auth branding")
    {profile, source} = load_profile(config)

    {:ok,
     socket
     |> assign(:sigra_config, config)
     |> assign(:profile, profile)
     |> assign(:source, source)
     |> assign(:error, nil)
     |> assign(:page_title, "Auth branding")}
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

      <div class="sg-grid sg-grid--2">
        <section class="sg-card sg-stack sg-stack--4">
          <div class="sg-toolbar">
            <div class="sg-stack sg-stack--1">
              <h2 class="sg-section-heading">Brand tokens</h2>
              <p class="sg-section-copy">Current source: {@source}</p>
            </div>
            <button class="sg-btn sg-btn--ghost sg-btn--sm" phx-click="reset_to_config">
              Reset
            </button>
          </div>

          <form
            id="auth-branding-form"
            class="sg-form-grid"
            phx-change="validate"
            phx-submit="save"
            data-testid="admin-auth-branding-form"
          >
            <label class="sg-field">
              <span class="sg-field-label">Product name</span>
              <input class="sg-input" name="branding[product_name]" value={@profile.product_name} required />
            </label>

            <label class="sg-field">
              <span class="sg-field-label">Logo URL</span>
              <input class="sg-input" name="branding[logo_url]" value={@profile.logo_url} />
            </label>

            <label class="sg-field">
              <span class="sg-field-label">Logo alt text</span>
              <input class="sg-input" name="branding[logo_alt]" value={@profile.logo_alt} required />
            </label>

            <label class="sg-field">
              <span class="sg-field-label">Theme</span>
              <select class="sg-select" name="branding[theme]">
                <option value="system" selected={@profile.theme == :system}>System</option>
                <option value="light" selected={@profile.theme == :light}>Light</option>
                <option value="dark" selected={@profile.theme == :dark}>Dark</option>
              </select>
            </label>

            <div class="sg-stack sg-stack--2">
              <div class="sg-stack sg-stack--1">
                <h3 class="sg-section-heading">Light palette</h3>
                <p class="sg-section-copy">Used when the generated auth theme is Light.</p>
              </div>
              <div class="sg-form-grid sg-form-grid--cols">
                <.color_field name="accent_color" label="Accent" value={@profile.accent_color} />
                <.color_field name="accent_foreground" label="On accent" value={@profile.accent_foreground} />
                <.color_field name="background_color" label="Background" value={@profile.background_color} />
                <.color_field name="surface_color" label="Surface" value={@profile.surface_color} />
                <.color_field name="text_color" label="Text" value={@profile.text_color} />
                <.color_field name="muted_color" label="Muted" value={@profile.muted_color} />
                <.color_field name="border_color" label="Border" value={@profile.border_color} />
              </div>
            </div>

            <div class="sg-stack sg-stack--2">
              <div class="sg-stack sg-stack--1">
                <h3 class="sg-section-heading">Dark palette</h3>
                <p class="sg-section-copy">Used when the generated auth theme is Dark or System resolves dark.</p>
              </div>
              <div class="sg-form-grid sg-form-grid--cols">
                <.color_field name="dark_accent_color" label="Accent" value={color_token(@profile, :dark, :accent_color)} />
                <.color_field name="dark_accent_foreground" label="On accent" value={color_token(@profile, :dark, :accent_foreground)} />
                <.color_field name="dark_background_color" label="Background" value={color_token(@profile, :dark, :background_color)} />
                <.color_field name="dark_surface_color" label="Surface" value={color_token(@profile, :dark, :surface_color)} />
                <.color_field name="dark_text_color" label="Text" value={color_token(@profile, :dark, :text_color)} />
                <.color_field name="dark_muted_color" label="Muted" value={color_token(@profile, :dark, :muted_color)} />
                <.color_field name="dark_border_color" label="Border" value={color_token(@profile, :dark, :border_color)} />
              </div>
            </div>

            <div class="sg-form-grid sg-form-grid--cols">
              <label class="sg-field">
                <span class="sg-field-label">Support URL</span>
                <input class="sg-input" name="branding[support_url]" value={@profile.support_url} />
              </label>
              <label class="sg-field">
                <span class="sg-field-label">Privacy URL</span>
                <input class="sg-input" name="branding[privacy_url]" value={@profile.privacy_url} />
              </label>
              <label class="sg-field">
                <span class="sg-field-label">Terms URL</span>
                <input class="sg-input" name="branding[terms_url]" value={@profile.terms_url} />
              </label>
            </div>

            <div class="sg-form-grid sg-form-grid--cols">
              <label class="sg-field">
                <span class="sg-field-label">Email from name</span>
                <input class="sg-input" name="branding[email_from_name]" value={@profile.email_from_name} required />
              </label>
              <label class="sg-field">
                <span class="sg-field-label">Email from address</span>
                <input class="sg-input" name="branding[email_from_address]" value={@profile.email_from_address} />
              </label>
              <label class="sg-field">
                <span class="sg-field-label">Reply-to</span>
                <input class="sg-input" name="branding[email_reply_to]" value={@profile.email_reply_to} />
              </label>
            </div>

            <div class="sg-action-row">
              <button type="submit" class="sg-btn sg-btn--primary">Save profile</button>
              <button type="button" class="sg-btn sg-btn--secondary" phx-click="reset_to_config">
                Use config defaults
              </button>
            </div>
          </form>
        </section>

        <section class="sg-stack sg-stack--4" data-testid="admin-auth-preview">
          <div class="sg-card sg-stack sg-stack--3">
            <h2 class="sg-section-heading">Login preview</h2>
            <div class="sigra-auth sigra-auth--preview" data-theme={theme_attr(@profile)} style={Branding.css_variables(@profile)}>
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
                    <form>
                      <label>Email<input type="email" value="alex@example.com" /></label>
                      <button type="button" class="btn btn-primary w-full">Send magic link</button>
                    </form>
                  </div>
                </div>
              </section>
            </div>
          </div>

          <div class="sg-card sg-stack sg-stack--3" data-testid="admin-email-preview">
            <h2 class="sg-section-heading">Email preview</h2>
            <div
              class="sigra-auth-email-preview"
              data-theme={theme_attr(@profile)}
              data-testid="admin-email-preview-surface"
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
      </div>
    </section>
    """
  end

  @impl true
  def handle_event("validate", %{"branding" => params}, socket) do
    case Profile.new(params) do
      {:ok, profile} ->
        {:noreply, assign(socket, profile: profile, error: nil)}

      {:error, message} ->
        {:noreply, assign(socket, error: message)}
    end
  end

  def handle_event("save", %{"branding" => params}, socket) do
    case Branding.save_global(socket.assigns.sigra_config, params, actor_id: actor_id(socket)) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> assign(:profile, profile)
         |> assign(:source, "Admin profile")
         |> assign(:error, nil)
         |> put_flash(:info, "Auth branding profile saved.")}

      {:error, reason} ->
        {:noreply, assign(socket, error: error_message(reason))}
    end
  end

  def handle_event("reset_to_config", _params, socket) do
    config = socket.assigns.sigra_config
    profile = Branding.from_config(config)

    case Branding.delete_global(config) do
      :ok ->
        {:noreply,
         socket
         |> assign(:profile, profile)
         |> assign(:source, "Config defaults")
         |> assign(:error, nil)
         |> put_flash(:info, "Auth branding reset to config defaults.")}

      {:error, reason} ->
        {:noreply, assign(socket, error: error_message(reason))}
    end
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp color_field(assigns) do
    ~H"""
    <label class="sg-field">
      <span class="sg-field-label">{@label}</span>
      <span class="sg-cluster sg-cluster--2">
        <input type="color" name={"branding[#{@name}]"} value={@value} aria-label={@label} />
        <span class="sg-muted sg-text-sm">{@value}</span>
      </span>
    </label>
    """
  end

  defp load_profile(config) do
    base = Branding.from_config(config)

    case Branding.load_global(config, base: base) do
      {:ok, profile} -> {profile, "Admin profile"}
      _ -> {base, "Config defaults"}
    end
  end

  defp color_token(%Profile{} = profile, theme, key) do
    profile
    |> Branding.color_tokens(theme)
    |> Map.fetch!(key)
  end

  defp theme_attr(%Profile{theme: theme}), do: to_string(theme)

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
