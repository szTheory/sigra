defmodule Sigra.Session do
  @moduledoc """
  Struct representing an authenticated user session.

  ## Audit integration (Plan 09-03)

  The audit events for session lifecycle operations are emitted from
  `Sigra.Auth` (which owns session orchestration in this codebase):

    * `session.create` — via `Sigra.Audit.log_safe/3` in `Sigra.Auth.create_session/4`
    * `session.delete` — via `Sigra.Audit` in `Sigra.Auth.delete_session/3`
    * `session.revoke_all` — via `Sigra.Audit` in `Sigra.Auth.delete_all_sessions/3`
    * `session.sudo_enter` / `session.sudo_expire` — split by result
      in `Sigra.Auth.confirm_sudo/3` via `Sigra.Audit.log_safe/3`

  See `Sigra.Audit` and `Sigra.Audit.__log_internal__/3` for the
  library-internal write path.


  Each session tracks the user, authentication metadata (IP, user agent,
  geolocation), and temporal data (last activity, sudo mode, creation time).

  The raw `:token` field is populated only on session creation (returned to
  the caller once) and is `nil` when fetched from storage. The `:hashed_token`
  is the SHA-256 hash stored in the database and used for all lookups.

  ## Fields

  - `:id` - Database primary key
  - `:user_id` - The owning user's ID
  - `:token` - Raw token (ephemeral, populated only on create)
  - `:hashed_token` - SHA-256 hash of the raw token (stored in DB)
  - `:type` - Session type: `:standard`, `:remember_me`, or `:mfa_pending`
  - `:ip` - Client IP address at session creation or last activity
  - `:user_agent` - Raw User-Agent header string
  - `:parsed_ua` - Parsed user agent map from `Sigra.UAParser`
  - `:geo_city` - City name from GeoIP lookup (nil if disabled)
  - `:geo_country_code` - ISO 3166-1 alpha-2 country code (nil if disabled)
  - `:last_active_at` - Last activity timestamp (throttled updates)
  - `:sudo_at` - When sudo mode was last activated
  - `:inserted_at` - Session creation timestamp
  """

  @doc since: "0.1.0"

  @type session_type :: :standard | :remember_me | :mfa_pending

  @type t :: %__MODULE__{
          id: term(),
          user_id: term(),
          token: binary() | nil,
          hashed_token: binary(),
          type: session_type(),
          ip: String.t() | nil,
          user_agent: String.t() | nil,
          parsed_ua: map() | nil,
          geo_city: String.t() | nil,
          geo_country_code: String.t() | nil,
          last_active_at: DateTime.t() | nil,
          sudo_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :user_id,
    :token,
    :hashed_token,
    type: :standard,
    ip: nil,
    user_agent: nil,
    parsed_ua: nil,
    geo_city: nil,
    geo_country_code: nil,
    last_active_at: nil,
    sudo_at: nil,
    inserted_at: nil
  ]
end
