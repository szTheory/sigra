defmodule Sigra.Organizations.Slug do
  @moduledoc """
  Slug generation and validation for organizations.

  Validates slug format (D-07), length (D-07), and reserved words (D-08).
  The reserved word list is hardcoded in the library with an additive
  extension point via `additional_reserved_slugs` config.
  """

  @default_reserved_slugs ~w(
    admin api app auth billing blog cdn dashboard docs help
    login logout new oauth register settings signup static
    status support system webhooks www
  )

  @default_slug_format ~r/^[a-z][a-z0-9-]*[a-z0-9]$/
  @default_slug_min 3
  @default_slug_max 63

  @doc "Returns the default reserved slug list."
  @spec default_reserved_slugs() :: [String.t()]
  def default_reserved_slugs, do: @default_reserved_slugs

  @doc """
  Validates the `:slug` field on a changeset.

  Config keys used:
  - `reserved_slugs` (default: ~25 hardcoded words)
  - `additional_reserved_slugs` (default: [])
  - `slug_format` (default: `^[a-z][a-z0-9-]*[a-z0-9]$`)
  - `slug_length` (default: {3, 63})
  """
  @spec validate_slug(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_slug(changeset, config) do
    reserved = get_reserved(config)
    format = Map.get(config, :slug_format, @default_slug_format)
    {min, max} = Map.get(config, :slug_length, {@default_slug_min, @default_slug_max})

    changeset
    |> Ecto.Changeset.validate_format(:slug, format,
      message:
        "must start with a letter, contain only lowercase letters, numbers, and hyphens, " <>
          "and end with a letter or number"
    )
    |> Ecto.Changeset.validate_length(:slug, min: min, max: max)
    |> Ecto.Changeset.validate_exclusion(:slug, reserved,
      message: "is reserved and cannot be used"
    )
  end

  @doc """
  Generates a slug from a name string.

  Downcases, replaces non-alphanumeric runs with hyphens, trims hyphens.
  Does NOT validate the result -- call `validate_slug/2` on the changeset
  after setting the generated slug.
  """
  @spec generate_slug(String.t() | nil) :: String.t() | nil
  def generate_slug(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  def generate_slug(nil), do: nil

  defp get_reserved(config) do
    base = Map.get(config, :reserved_slugs, @default_reserved_slugs)
    additional = Map.get(config, :additional_reserved_slugs, [])
    base ++ additional
  end
end
