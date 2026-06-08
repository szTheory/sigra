defmodule Sigra.Branding.Profile do
  @moduledoc """
  Validated brand tokens shared by generated Sigra auth screens and emails.

  A profile is intentionally small: it carries safe design tokens and common
  product metadata, not arbitrary HTML or CSS. Host apps that need full control
  should edit the generated components/templates directly.
  """

  @type theme_mode :: :system | :light | :dark

  @type t :: %__MODULE__{
          product_name: String.t(),
          logo_url: String.t() | nil,
          logo_alt: String.t(),
          accent_color: String.t(),
          accent_foreground: String.t(),
          background_color: String.t(),
          surface_color: String.t(),
          text_color: String.t(),
          muted_color: String.t(),
          border_color: String.t(),
          dark_accent_color: String.t() | nil,
          dark_accent_foreground: String.t() | nil,
          dark_background_color: String.t() | nil,
          dark_surface_color: String.t() | nil,
          dark_text_color: String.t() | nil,
          dark_muted_color: String.t() | nil,
          dark_border_color: String.t() | nil,
          support_url: String.t() | nil,
          privacy_url: String.t() | nil,
          terms_url: String.t() | nil,
          email_from_name: String.t(),
          email_from_address: String.t() | nil,
          email_reply_to: String.t() | nil,
          theme: theme_mode()
        }

  @hex ~r/^#[0-9a-fA-F]{6}$/

  @defaults %{
    product_name: "Your app",
    logo_url: nil,
    logo_alt: "Application logo",
    accent_color: "#c2410c",
    accent_foreground: "#ffffff",
    background_color: "#f7f4ee",
    surface_color: "#ffffff",
    text_color: "#171717",
    muted_color: "#6b6258",
    border_color: "#ded8cf",
    dark_accent_color: nil,
    dark_accent_foreground: nil,
    dark_background_color: nil,
    dark_surface_color: nil,
    dark_text_color: nil,
    dark_muted_color: nil,
    dark_border_color: nil,
    support_url: nil,
    privacy_url: nil,
    terms_url: nil,
    email_from_name: "Your app",
    email_from_address: nil,
    email_reply_to: nil,
    theme: :system
  }

  @enforce_keys Map.keys(@defaults)
  defstruct Map.to_list(@defaults)

  @doc "Returns a validated profile with Sigra's restrained default tokens."
  @spec default(keyword() | map()) :: t()
  def default(overrides \\ []) do
    new!(overrides)
  end

  @doc "Builds a profile and raises on invalid token values."
  @spec new!(keyword() | map()) :: t()
  def new!(attrs \\ []) do
    case new(attrs) do
      {:ok, profile} -> profile
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc "Builds a profile and returns `{:error, reason}` for invalid token values."
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs \\ []) do
    attrs = normalize_attrs(attrs)
    merged = Map.merge(@defaults, attrs)

    with :ok <- validate_required_string(merged, :product_name),
         :ok <- validate_required_string(merged, :logo_alt),
         :ok <- validate_required_string(merged, :email_from_name),
         :ok <- validate_optional_string(merged, :logo_url),
         :ok <- validate_optional_string(merged, :support_url),
         :ok <- validate_optional_string(merged, :privacy_url),
         :ok <- validate_optional_string(merged, :terms_url),
         :ok <- validate_optional_string(merged, :email_from_address),
         :ok <- validate_optional_string(merged, :email_reply_to),
         :ok <- validate_theme(merged.theme),
         :ok <- validate_hexes(merged) do
      {:ok, struct!(__MODULE__, merged)}
    end
  end

  @doc "Converts a profile to a string-keyed map suitable for persistence."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = profile) do
    profile
    |> Map.from_struct()
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), persist_value(key, value)} end)
  end

  @doc "Returns the default token map."
  @spec defaults() :: map()
  def defaults, do: @defaults

  defp normalize_attrs(%__MODULE__{} = profile), do: Map.from_struct(profile)

  defp normalize_attrs(attrs) when is_list(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      normalized_key = normalize_key(key)
      {normalized_key, normalize_value(normalized_key, value)}
    end)
    |> Enum.reject(fn {key, _value} -> is_nil(key) end)
    |> Enum.into(%{})
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      normalized_key = normalize_key(key)
      {normalized_key, normalize_value(normalized_key, value)}
    end)
    |> Enum.reject(fn {key, _value} -> is_nil(key) end)
    |> Enum.into(%{})
  end

  defp normalize_attrs(_), do: %{}

  defp normalize_key(key) when is_atom(key) do
    if Map.has_key?(@defaults, key), do: key, else: nil
  end

  defp normalize_key(key) when is_binary(key) do
    atom =
      key
      |> String.trim()
      |> String.replace("-", "_")
      |> String.to_existing_atom()

    if Map.has_key?(@defaults, atom), do: atom, else: nil
  rescue
    ArgumentError -> nil
  end

  defp normalize_key(_), do: nil

  defp normalize_value(:theme, value) when value in ["system", "light", "dark"] do
    String.to_existing_atom(value)
  end

  defp normalize_value(_key, value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_value(_key, value), do: value

  defp validate_required_string(attrs, key) do
    case Map.fetch!(attrs, key) do
      value when is_binary(value) and value != "" -> :ok
      _ -> {:error, "#{key} must be a non-empty string"}
    end
  end

  defp validate_optional_string(attrs, key) do
    case Map.fetch!(attrs, key) do
      nil -> :ok
      value when is_binary(value) -> :ok
      _ -> {:error, "#{key} must be a string or nil"}
    end
  end

  defp validate_theme(theme) when theme in [:system, :light, :dark], do: :ok
  defp validate_theme(theme) when theme in ["system", "light", "dark"], do: :ok
  defp validate_theme(_), do: {:error, "theme must be :system, :light, or :dark"}

  defp validate_hexes(attrs) do
    required_hex_keys = [
      :accent_color,
      :accent_foreground,
      :background_color,
      :surface_color,
      :text_color,
      :muted_color,
      :border_color
    ]

    optional_hex_keys = [
      :dark_accent_color,
      :dark_accent_foreground,
      :dark_background_color,
      :dark_surface_color,
      :dark_text_color,
      :dark_muted_color,
      :dark_border_color
    ]

    with :ok <- validate_required_hexes(attrs, required_hex_keys) do
      validate_optional_hexes(attrs, optional_hex_keys)
    end
  end

  defp validate_required_hexes(attrs, keys) do
    Enum.reduce_while(keys, :ok, fn key, :ok ->
      case Map.fetch!(attrs, key) do
        value when is_binary(value) ->
          if Regex.match?(@hex, value) do
            {:cont, :ok}
          else
            {:halt, {:error, "#{key} must be a 6-digit hex color like #c2410c"}}
          end

        _ ->
          {:halt, {:error, "#{key} must be a 6-digit hex color like #c2410c"}}
      end
    end)
  end

  defp validate_optional_hexes(attrs, keys) do
    Enum.reduce_while(keys, :ok, fn key, :ok ->
      case Map.fetch!(attrs, key) do
        nil ->
          {:cont, :ok}

        value when is_binary(value) ->
          if Regex.match?(@hex, value) do
            {:cont, :ok}
          else
            {:halt, {:error, "#{key} must be a 6-digit hex color like #c2410c"}}
          end

        _ ->
          {:halt, {:error, "#{key} must be a 6-digit hex color like #c2410c"}}
      end
    end)
  end

  defp persist_value(:theme, value) when is_atom(value), do: Atom.to_string(value)
  defp persist_value(_key, value), do: value
end
