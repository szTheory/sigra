defmodule Sigra.SessionStore do
  @moduledoc """
  Behaviour for session persistence implementations.

  Sigra uses database-backed sessions by default (not JWTs for session
  state). This behaviour abstracts the storage mechanism.

  ## Default Implementation

  `Sigra.SessionStores.Ecto` -- stores sessions in the `user_tokens` table.

  ## Mox Usage

      Mox.defmock(MockSessionStore, for: Sigra.SessionStore)
  """

  @doc "Fetches a session by its token."
  @doc since: "0.1.0"
  @callback fetch(token :: binary(), opts :: keyword()) :: {:ok, term()} | {:error, :not_found}

  @doc "Creates a new session for the given user, returning the session token."
  @doc since: "0.1.0"
  @callback create(user_id :: term(), metadata :: map(), opts :: keyword()) :: {:ok, binary()}

  @doc "Deletes a session by its token."
  @doc since: "0.1.0"
  @callback delete(token :: binary(), opts :: keyword()) :: :ok
end
