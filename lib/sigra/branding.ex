defmodule Sigra.Branding do
  @moduledoc """
  Brand profile resolution for generated auth UI and transactional emails.

  Sigra keeps branding constrained to validated tokens. The generated host app
  can still take full control by editing its generated templates and CSS.
  """

  import Ecto.Query

  alias Sigra.Branding.Contrast
  alias Sigra.Branding.Profile

  @table "sigra_brand_profiles"
  @global_scope "global"
  @color_token_keys [
    {"accent", :accent_color},
    {"on-accent", :accent_foreground},
    {"bg", :background_color},
    {"surface", :surface_color},
    {"text", :text_color},
    {"muted", :muted_color},
    {"border", :border_color}
  ]
  @dark_color_defaults %{
    background_color: "#171614",
    surface_color: "#211f1c",
    text_color: "#f4f1eb",
    muted_color: "#bdb5aa",
    border_color: "#4a4035"
  }

  @doc """
  Resolves a brand profile from defaults, `Sigra.Config`/keyword config, and
  the optional generated global admin profile.

  Runtime profile lookup is best-effort. If the table is absent or unavailable,
  Sigra falls back to config/default tokens rather than breaking pre-auth pages.
  """
  @spec resolve(Sigra.Config.t() | keyword() | map() | nil, keyword()) :: Profile.t()
  def resolve(config_or_opts, opts \\ []) do
    config_profile = from_config(config_or_opts, Keyword.get(opts, :defaults, []))

    case load_global(config_or_opts, base: config_profile) do
      {:ok, %Profile{} = profile} -> profile
      _ -> config_profile
    end
  end

  @doc "Builds a profile from config and optional generated defaults."
  @spec from_config(Sigra.Config.t() | keyword() | map() | nil, keyword() | map()) :: Profile.t()
  def from_config(config_or_opts, defaults \\ []) do
    config_branding =
      config_or_opts
      |> config_branding()
      |> normalize_runtime_map()

    defaults
    |> normalize_runtime_map()
    |> Map.merge(config_branding)
    |> Profile.new!()
  end

  @doc "Returns a Swoosh-compatible `{name, address}` tuple when an address exists."
  @spec email_from(Profile.t()) :: {String.t(), String.t()} | String.t()
  def email_from(%Profile{email_from_address: address, email_from_name: name})
      when is_binary(address) do
    {name, address}
  end

  def email_from(%Profile{email_from_name: name}), do: name

  @doc "Returns resolved auth colors for a light or dark generated auth theme."
  @spec color_tokens(Profile.t(), :light | :dark) :: map()
  def color_tokens(%Profile{} = profile, :light) do
    %{
      accent_color: profile.accent_color,
      accent_foreground: profile.accent_foreground,
      background_color: profile.background_color,
      surface_color: profile.surface_color,
      text_color: profile.text_color,
      muted_color: profile.muted_color,
      border_color: profile.border_color
    }
  end

  def color_tokens(%Profile{} = profile, :dark) do
    surface = profile.dark_surface_color || Map.fetch!(@dark_color_defaults, :surface_color)
    {source, accent} = dark_accent(profile, surface)

    %{
      accent_color: accent,
      accent_foreground: dark_accent_foreground(profile, source, accent),
      background_color:
        profile.dark_background_color || Map.fetch!(@dark_color_defaults, :background_color),
      surface_color: surface,
      text_color: profile.dark_text_color || Map.fetch!(@dark_color_defaults, :text_color),
      muted_color: profile.dark_muted_color || Map.fetch!(@dark_color_defaults, :muted_color),
      border_color: profile.dark_border_color || Map.fetch!(@dark_color_defaults, :border_color)
    }
  end

  @doc """
  Reports where a profile's dark accent comes from, for display in admin UI.

  Returns `{:explicit, hex}` when the host set `dark_accent_color` themselves,
  `{:inherited, hex}` when the host's light accent already meets contrast against
  the resolved dark surface and is used unchanged, or `{:derived, hex}` when it
  did not and Sigra adjusted it.

  This exists so an operator can *see* what dark mode will actually use and pin an
  explicit value if they disagree. Automatic derivation is only safe to ship
  because this is visible — do not drop it.
  """
  @spec dark_accent_source(Profile.t()) :: {:explicit | :inherited | :derived, String.t()}
  def dark_accent_source(%Profile{} = profile) do
    surface = profile.dark_surface_color || Map.fetch!(@dark_color_defaults, :surface_color)
    dark_accent(profile, surface)
  end

  # An explicit host value is authority and is never touched. Otherwise the light
  # accent is fitted to the dark surface, keeping it byte-identical when it already
  # passes so brand fidelity survives wherever it is not actually broken.
  defp dark_accent(%Profile{dark_accent_color: explicit}, _surface) when is_binary(explicit) do
    {:explicit, explicit}
  end

  defp dark_accent(%Profile{accent_color: accent}, surface) do
    case Contrast.fit_to_surface(accent, surface, Contrast.accent_contrast_target()) do
      {value, false} -> {:inherited, value}
      {value, true} -> {:derived, value}
    end
  end

  # The foreground is only re-derived when *our own* accent adjustment broke a
  # pairing that previously worked. Two guards matter here, and both were added
  # against observed bad output rather than in the abstract:
  #
  #   * An explicit dark_accent_foreground is always authority.
  #   * A pairing the host was already running below target in light mode is their
  #     aesthetic choice, not a defect for us to fix only in dark mode. Silently
  #     flipping white button text to black because the accent shifted a fraction
  #     would be a far more visible change than the accent shift that triggered it
  #     -- and would recreate exactly the "a composite nobody chose" problem this
  #     derivation exists to remove.
  defp dark_accent_foreground(%Profile{dark_accent_foreground: explicit}, _source, _accent)
       when is_binary(explicit) do
    explicit
  end

  defp dark_accent_foreground(%Profile{} = profile, :derived, accent) do
    target = Contrast.accent_contrast_target()
    foreground = profile.accent_foreground
    legible_before? = Contrast.contrast_ratio(foreground, profile.accent_color) >= target
    legible_now? = Contrast.contrast_ratio(foreground, accent) >= target

    if legible_before? and not legible_now? do
      Contrast.readable_foreground(accent)
    else
      foreground
    end
  end

  defp dark_accent_foreground(%Profile{accent_foreground: foreground}, _source, _accent) do
    foreground
  end

  @doc """
  Returns the logo URL to use for a theme, or `nil` to fall back to the placeholder mark.

  `logo_url` is the canonical asset and `dark_logo_url` is an optional override for
  the dark theme, so the fallback is **directional, not symmetric**:

    * `:light` resolves `logo_url` only.
    * `:dark` resolves `dark_logo_url`, falling back to `logo_url`.

  Light deliberately does *not* fall back to `dark_logo_url`. A host whose only
  asset is a reversed (near-white) mark is expected to set `dark_logo_url` and
  leave `logo_url` unset — that is the intended use of the token. Falling back the
  other way would paint that near-white mark onto a light background, which reads
  as a broken image rather than as a deliberate one. The neutral placeholder is the
  honest result, and is what such a host gets in light mode until they have a
  positive variant to supply.
  """
  @spec logo(Profile.t(), :light | :dark) :: String.t() | nil
  def logo(%Profile{logo_url: logo_url}, :light), do: logo_url
  def logo(%Profile{} = profile, :dark), do: profile.dark_logo_url || profile.logo_url

  @doc """
  Returns the logo URL for transactional email, or `nil` for the placeholder/wordmark.

  Always the light slot, and never the dark one — even when `theme` is pinned to
  `:dark`. Transactional email renders on an effectively light surface regardless of
  the reader's OS theme, and `prefers-color-scheme` support across mail clients is too
  inconsistent to vary the asset on. Reaching for `dark_logo_url` here would put a
  near-white mark on a white email surface for exactly the hosts this token was added
  to serve.

  This is the same rule as `logo/2` with `:light`, not a special case: the email
  surface is a light surface, so it takes the light slot.
  """
  @spec email_logo(Profile.t()) :: String.t() | nil
  def email_logo(%Profile{} = profile), do: logo(profile, :light)

  @doc "Loads the global admin-managed profile, if the generated table exists."
  @spec load_global(Sigra.Config.t() | keyword() | map() | nil, keyword()) ::
          {:ok, Profile.t()} | {:error, term()}
  def load_global(config_or_opts, opts \\ []) do
    base = Keyword.get(opts, :base, from_config(config_or_opts))

    with {:ok, repo} <- fetch_repo(config_or_opts) do
      prefix = infer_prefix(config_or_opts)

      settings =
        @table
        |> where([p], field(p, :scope) == ^@global_scope)
        |> select([p], field(p, :settings))
        |> repo.one(repo_opts(prefix))

      case settings do
        nil -> {:error, :not_found}
        %{} = attrs -> {:ok, merge_profile(base, attrs)}
        _ -> {:error, :invalid_settings}
      end
    end
  rescue
    _ -> {:error, :unavailable}
  end

  @doc "Persists the global admin-managed profile in the generated host app table."
  @spec save_global(Sigra.Config.t() | keyword() | map(), keyword() | map(), keyword()) ::
          {:ok, Profile.t()} | {:error, term()}
  def save_global(config_or_opts, attrs, opts \\ []) do
    with {:ok, repo} <- fetch_repo(config_or_opts),
         {:ok, profile} <- Profile.new(attrs) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      prefix = infer_prefix(config_or_opts)
      actor_id = Keyword.get(opts, :actor_id)

      row = %{
        scope: @global_scope,
        settings: Profile.to_map(profile),
        updated_by_id: normalize_id(actor_id),
        inserted_at: now,
        updated_at: now
      }

      repo.insert_all(
        @table,
        [row],
        Keyword.merge(repo_opts(prefix),
          on_conflict: {:replace, [:settings, :updated_by_id, :updated_at]},
          conflict_target: [:scope]
        )
      )

      {:ok, profile}
    else
      {:error, %ArgumentError{} = error} -> {:error, Exception.message(error)}
      {:error, reason} -> {:error, reason}
    end
  rescue
    exception -> {:error, exception}
  end

  @doc "Deletes the generated global admin-managed profile so config/defaults take over."
  @spec delete_global(Sigra.Config.t() | keyword() | map()) :: :ok | {:error, term()}
  def delete_global(config_or_opts) do
    with {:ok, repo} <- fetch_repo(config_or_opts) do
      prefix = infer_prefix(config_or_opts)

      @table
      |> where([p], field(p, :scope) == ^@global_scope)
      |> repo.delete_all(repo_opts(prefix))

      :ok
    end
  rescue
    exception -> {:error, exception}
  end

  @doc "Turns a profile into inline CSS variables for generated auth previews/pages."
  @spec css_variables(Profile.t()) :: String.t()
  def css_variables(%Profile{} = profile) do
    [:light, :dark]
    |> Enum.flat_map(fn theme ->
      tokens = color_tokens(profile, theme)

      Enum.map(@color_token_keys, fn {suffix, key} ->
        {"--sigra-auth-#{theme}-#{suffix}", Map.fetch!(tokens, key)}
      end)
    end)
    |> Enum.map_join(" ", fn {property, value} -> "#{property}: #{value};" end)
  end

  @doc false
  @spec table_name() :: String.t()
  def table_name, do: @table

  defp merge_profile(%Profile{} = base, attrs) do
    base
    |> Profile.to_map()
    |> Map.merge(normalize_runtime_map(attrs))
    |> Profile.new!()
  end

  defp config_branding(%Sigra.Config{branding: branding}), do: branding

  defp config_branding(config) when is_list(config), do: Keyword.get(config, :branding, [])

  defp config_branding(config) when is_map(config),
    do: Map.get(config, :branding) || Map.get(config, "branding", %{})

  defp config_branding(_), do: %{}

  defp fetch_repo(%Sigra.Config{repo: repo}) when is_atom(repo), do: {:ok, repo}
  defp fetch_repo(config) when is_list(config), do: fetch_repo(Keyword.get(config, :repo))

  defp fetch_repo(config) when is_map(config),
    do: fetch_repo(Map.get(config, :repo) || Map.get(config, "repo"))

  defp fetch_repo(repo) when is_atom(repo) and not is_nil(repo), do: {:ok, repo}
  defp fetch_repo(_), do: {:error, :missing_repo}

  defp infer_prefix(%Sigra.Config{user_schema: schema}), do: schema_prefix(schema)

  defp infer_prefix(config) when is_list(config),
    do: schema_prefix(Keyword.get(config, :user_schema))

  defp infer_prefix(config) when is_map(config),
    do: schema_prefix(Map.get(config, :user_schema) || Map.get(config, "user_schema"))

  defp infer_prefix(_), do: nil

  defp schema_prefix(schema) when is_atom(schema) do
    if Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 1) do
      schema.__schema__(:prefix)
    end
  rescue
    _ -> nil
  end

  defp schema_prefix(_), do: nil

  defp repo_opts(nil), do: []
  defp repo_opts(prefix), do: [prefix: prefix]

  defp normalize_runtime_map(%Profile{} = profile), do: Profile.to_map(profile)

  defp normalize_runtime_map(attrs) when is_list(attrs) do
    Enum.into(attrs, %{}, fn {key, value} -> {key, value} end)
  end

  defp normalize_runtime_map(attrs) when is_map(attrs), do: attrs
  defp normalize_runtime_map(_), do: %{}

  defp normalize_id(nil), do: nil
  defp normalize_id(value) when is_binary(value), do: value
  defp normalize_id(value), do: to_string(value)
end
