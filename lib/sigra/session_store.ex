defmodule Sigra.SessionStore do
  @moduledoc """
  Behaviour for session persistence implementations.

  Sigra uses database-backed sessions by default (not JWTs for session
  state). This behaviour abstracts the storage mechanism with 7 required callbacks
  covering the full session lifecycle: creation, retrieval, deletion,
  user listing, bulk deletion, activity tracking, and sudo mode.

  The optional `create_session_multi/3` and `delete_session_multi/3` callbacks
  let orchestration code compose session writes into a caller-owned
  `Ecto.Multi` when the adapter can participate in one transaction.

  ## Default Implementation

  `Sigra.SessionStores.Ecto` -- stores sessions in the generated
  `UserSessions` table using the host app's Ecto repo.

  ## Mox Usage

      Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)
  """

  @doc """
  Creates a new session for the given user.

  The metadata map includes `:type`, `:ip`, `:user_agent`, `:geo_city`,
  and `:geo_country_code`. The implementation generates the token internally
  using `Sigra.Token.generate_hashed_token/0` and returns the Session
  struct with the raw token populated (shown once, then discarded).
  """
  @doc since: "0.1.0"
  @callback create(user_id :: term(), metadata :: map(), opts :: keyword()) ::
              {:ok, Sigra.Session.t()} | {:error, term()}

  @doc "Builds a session-creation multi suitable for composition in a transaction."
  @doc since: "0.2.0"
  @callback create_session_multi(user_id :: term(), metadata :: map(), opts :: keyword()) ::
              Ecto.Multi.t()

  @doc "Fetches a session by its hashed token. Returns the Session struct without the raw token."
  @doc since: "0.1.0"
  @callback fetch(hashed_token :: binary(), opts :: keyword()) ::
              {:ok, Sigra.Session.t()} | {:error, :not_found | :expired}

  @doc "Deletes a session by its hashed token."
  @doc since: "0.1.0"
  @callback delete(hashed_token :: binary(), opts :: keyword()) :: :ok

  @doc "Builds a session-deletion multi suitable for composition in a transaction."
  @doc since: "0.2.0"
  @callback delete_session_multi(
              hashed_token :: binary(),
              context :: term(),
              opts :: keyword()
            ) :: Ecto.Multi.t()

  @doc "Lists all sessions for a user, ordered by most recent first."
  @doc since: "0.1.0"
  @callback list_by_user(user_id :: term(), opts :: keyword()) :: [Sigra.Session.t()]

  @doc """
  Deletes all sessions for a user.

  Accepts optional `:except_token` in opts to exclude the current session.
  Returns `{count, nil}` where count is the number of deleted sessions.
  """
  @doc since: "0.1.0"
  @callback delete_all_for_user(user_id :: term(), opts :: keyword()) :: {non_neg_integer(), nil}

  @doc "Updates the last activity timestamp and optionally IP/user agent for a session."
  @doc since: "0.1.0"
  @callback update_activity(hashed_token :: binary(), metadata :: map(), opts :: keyword()) ::
              :ok | {:error, :not_found}

  @doc "Sets the sudo mode timestamp for a session."
  @doc since: "0.1.0"
  @callback update_sudo(hashed_token :: binary(), sudo_at :: DateTime.t(), opts :: keyword()) ::
              :ok | {:error, :not_found}

  @doc """
  Updates the `:active_organization_id` column on the given session row.

  Returns the refreshed `%Sigra.Session{}`. Implementations SHOULD short-circuit
  when `org_id` equals the session's current value (no-op-safe write) so that
  hot request paths do not incur an UPDATE on every hit. Returns `{:error, :not_found}`
  when the underlying row has been deleted.

  This callback is a trusted internal write; callers (e.g. the Phase 14
  `put_active_organization` orchestrator) are responsible for verifying
  membership authz BEFORE invoking. The callback itself does not enforce
  authz — see Phase 14 threat register (T-14-04).

  Added in Phase 14 (Plan 14-01, D-20).
  """
  @doc since: "0.1.0"
  @callback update_active_organization(
              session :: Sigra.Session.t(),
              org_id :: binary() | nil,
              opts :: keyword()
              ) ::
              {:ok, Sigra.Session.t()} | {:error, term()}

  @optional_callbacks create_session_multi: 3, delete_session_multi: 3
end
