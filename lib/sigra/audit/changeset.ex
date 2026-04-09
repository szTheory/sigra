defmodule Sigra.Audit.Changeset do
  @moduledoc """
  Changeset validators for audit events.

  Enforces D-17..D-23 security rules:
  - Action namespace regex (D-19): `^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$`
  - Reserved prefix guardrail (D-17, D-18): `auth.`, `session.`, `mfa.`,
    `oauth.`, `api.`, `account.`, `sigra.` rejected unless `allow_reserved: true`
  - Metadata size cap (D-20): JSON-encoded metadata must fit within
    `:max_metadata_bytes` (default 8_192)
  - Forbidden metadata keys (D-23): passwords, tokens, and other secret
    material rejected in both atom and string form
  """
  import Ecto.Changeset

  @action_regex ~r/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/

  @forbidden_keys ~w(
    password password_hash password_confirmation
    totp_code totp_secret backup_code
    session_token bearer_token api_key token
    access_token refresh_token oauth_secret
    client_secret secret
  )a

  @default_reserved ~w(auth. session. mfa. oauth. api. account. sigra.)
  @default_max_bytes 8_192
  @outcomes ~w(success failure error)

  @cast_fields [
    :action,
    :outcome,
    :actor_id,
    :actor_type,
    :target_id,
    :target_type,
    :ip_address,
    :user_agent,
    :metadata,
    :occurred_at
  ]

  @doc """
  Returns the canonical list of metadata keys that are forbidden from ever
  being logged. Enforced by `changeset/3` for both atom and string forms.
  """
  @spec forbidden_keys() :: [atom()]
  def forbidden_keys, do: @forbidden_keys

  @doc """
  Builds a validated changeset for an audit event.

  Options:

    * `:allow_reserved` — when `true`, skips the reserved-prefix check (used
      by `Sigra.Audit.__log_internal__/3` only). Default: `false`.
    * `:max_metadata_bytes` — cap on JSON-encoded metadata byte size.
      Default: `8_192`.
    * `:reserved_prefixes` — override the default reserved prefix list.
  """
  @spec changeset(struct(), map(), keyword()) :: Ecto.Changeset.t()
  def changeset(event, attrs, opts \\ []) do
    max_bytes = Keyword.get(opts, :max_metadata_bytes, @default_max_bytes)
    reserved = Keyword.get(opts, :reserved_prefixes, @default_reserved)
    allow_reserved? = Keyword.get(opts, :allow_reserved, false)

    event
    |> cast(attrs, @cast_fields)
    |> validate_required([:action, :outcome, :occurred_at])
    |> validate_format(:action, @action_regex, message: "must be namespaced snake_case")
    |> validate_inclusion(:outcome, @outcomes)
    |> validate_reserved_prefix(reserved, allow_reserved?)
    |> validate_metadata_size(max_bytes)
    |> validate_metadata_keys()
  end

  defp validate_reserved_prefix(cs, _reserved, true), do: cs

  defp validate_reserved_prefix(cs, reserved, false) do
    validate_change(cs, :action, fn :action, action ->
      if is_binary(action) and Enum.any?(reserved, &String.starts_with?(action, &1)) do
        [{:action, {"uses reserved Sigra prefix", [validation: :reserved_prefix]}}]
      else
        []
      end
    end)
  end

  defp validate_metadata_size(cs, max_bytes) do
    validate_change(cs, :metadata, fn :metadata, map ->
      case map do
        nil ->
          []

        m when is_map(m) ->
          encoded = Jason.encode!(m)

          case byte_size(encoded) do
            n when n <= max_bytes ->
              []

            n ->
              [
                {:metadata,
                 {"serialized size #{n}B exceeds cap #{max_bytes}B",
                  [validation: :max_metadata_bytes]}}
              ]
          end
      end
    end)
  end

  defp validate_metadata_keys(cs) do
    validate_change(cs, :metadata, fn :metadata, map ->
      case find_forbidden(map) do
        [] ->
          []

        keys ->
          [
            {:metadata,
             {"contains forbidden keys: #{inspect(keys)}",
              [validation: :forbidden_metadata_keys]}}
          ]
      end
    end)
  end

  defp find_forbidden(map) when is_map(map) do
    Enum.filter(@forbidden_keys, fn fk ->
      Map.has_key?(map, fk) or Map.has_key?(map, Atom.to_string(fk))
    end)
  end

  defp find_forbidden(_), do: []
end
