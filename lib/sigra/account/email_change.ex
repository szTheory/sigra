defmodule Sigra.Account.EmailChange do
  @moduledoc """
  Email change lifecycle: request, confirm, cancel.

  Implements the confirm-then-switch pattern (D-01): a verification email
  is sent to the new address while the old email stays active. The email
  only switches when the user confirms via the token link.

  ## Security Properties

  - One pending change at a time (D-04): new request cancels existing pending
  - New email reserved via `pending_email` field (D-05): blocks registration races
  - Token TTL: 24h configurable (D-03)
  - Session invalidation on confirm (D-07): all sessions except current
  - Hook integration: `:on_email_change` fires at confirmation (D-52)
  """

  alias Ecto.Multi
  alias Sigra.{Email, Hooks, Telemetry}

  @doc """
  Request an email change.

  Validates the new email is not the current email and not already taken,
  then creates a pending email change token.

  ## Options

  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for updating pending_email
  - `:build_email_token_fn` - `(user, context -> {encoded_token, token_struct})` to create token
  - `:token_query_fn` - `(user, contexts -> Ecto.Queryable.t())` for token cleanup queries
  - `:email_taken_fn` - `(repo, email -> boolean())` to check email uniqueness
  - `:config` - Optional config for hooks

  ## Returns

  - `{:ok, user, encoded_token}` on success
  - `{:error, :same_email}` if new email matches current
  - `{:error, :email_taken}` if email is already in use
  - `{:error, changeset}` on validation failure
  """
  @doc since: "0.8.0"
  @spec request(module(), map(), String.t(), keyword()) ::
          {:ok, map(), String.t()} | {:error, :same_email | :email_taken | Ecto.Changeset.t()}
  def request(repo, user, new_email, opts) do
    new_email = Email.normalize(new_email)

    cond do
      new_email == user.email ->
        {:error, :same_email}

      email_taken?(repo, new_email, opts) ->
        {:error, :email_taken}

      true ->
        do_request(repo, user, new_email, opts)
    end
  end

  @doc """
  Confirm an email change via token.

  Verifies the token, switches the user's email to pending_email,
  clears pending_email, invalidates sessions except current, and
  runs the `:on_email_change` hook.

  ## Options

  - `:find_user_by_token_fn` - `(repo, encoded_token -> user | nil)` to look up user by change token
  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for updating user
  - `:token_query_fn` - `(user, contexts -> Ecto.Queryable.t())` for token cleanup queries
  - `:session_store` - SessionStore for session invalidation
  - `:config` - Optional config for hooks
  - `:except_token` - Current session token to preserve

  ## Returns

  - `{:ok, user}` on success
  - `:error` for invalid or expired token
  """
  @doc since: "0.8.0"
  @spec confirm(module(), String.t(), keyword()) :: {:ok, map()} | :error
  def confirm(repo, encoded_token, opts) do
    Telemetry.span([:sigra, :email_change, :confirm], %{}, fn ->
      find_fn = Keyword.fetch!(opts, :find_user_by_token_fn)

      case find_fn.(repo, encoded_token) do
        nil ->
          :error

        user ->
          do_confirm(repo, user, opts)
      end
    end)
  end

  @doc """
  Cancel a pending email change.

  Clears the `pending_email` field and deletes any pending change tokens.

  ## Options

  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for clearing pending_email
  - `:token_query_fn` - `(user, contexts -> Ecto.Queryable.t())` for token cleanup queries

  ## Returns

  - `{:ok, user}` on success
  - `{:error, changeset}` on failure
  """
  @doc since: "0.8.0"
  @spec cancel(module(), map(), keyword()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def cancel(repo, user, opts) do
    Telemetry.span([:sigra, :email_change, :cancel], %{user_id: user.id}, fn ->
      changeset_fn = Keyword.fetch!(opts, :changeset_fn)
      token_query_fn = Keyword.fetch!(opts, :token_query_fn)

      multi =
        Multi.new()
        |> Multi.update(:user, changeset_fn.(user, %{pending_email: nil}))
        |> Multi.delete_all(:tokens, token_query_fn.(user, ["change:#{user.email}"]))

      case repo.transaction(multi) do
        {:ok, %{user: user}} -> {:ok, user}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    end)
  end

  # --- Private ---

  defp email_taken?(repo, new_email, opts) do
    case Keyword.get(opts, :email_taken_fn) do
      nil -> false
      fun when is_function(fun, 2) -> fun.(repo, new_email)
    end
  end

  defp do_request(repo, user, new_email, opts) do
    Telemetry.span([:sigra, :email_change, :request], %{user_id: user.id}, fn ->
      changeset_fn = Keyword.fetch!(opts, :changeset_fn)
      build_token_fn = Keyword.fetch!(opts, :build_email_token_fn)
      token_query_fn = Keyword.fetch!(opts, :token_query_fn)

      context = "change:#{user.email}"
      {encoded_token, token_struct} = build_token_fn.(user, context)

      # Override sent_to to new_email (build_email_token defaults to user.email)
      token_struct = %{token_struct | sent_to: new_email}

      multi =
        Multi.new()
        |> Multi.update(:user, changeset_fn.(user, %{pending_email: new_email}))
        |> Multi.delete_all(:old_tokens, token_query_fn.(user, [context]))
        |> Multi.insert(:token, token_struct)

      case repo.transaction(multi) do
        {:ok, %{user: user}} -> {:ok, user, encoded_token}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    end)
  end

  defp do_confirm(repo, user, opts) do
    changeset_fn = Keyword.fetch!(opts, :changeset_fn)
    token_query_fn = Keyword.fetch!(opts, :token_query_fn)
    config = Keyword.get(opts, :config, [])

    pending_email = user.pending_email

    update_changeset =
      changeset_fn.(user, %{
        email: pending_email,
        pending_email: nil,
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    multi =
      Multi.new()
      |> Multi.update(:user, update_changeset)
      |> Multi.delete_all(:tokens, token_query_fn.(user, ["change:#{user.email}"]))
      |> Hooks.maybe_run_hook(:email_change, %{user: user, new_email: pending_email}, config)

    case repo.transaction(multi) do
      {:ok, %{user: updated_user}} ->
        # Invalidate sessions after transaction commit
        maybe_invalidate_sessions(user, opts)
        {:ok, updated_user}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  defp maybe_invalidate_sessions(user, opts) do
    session_store = Keyword.get(opts, :session_store)
    except_token = Keyword.get(opts, :except_token)

    if session_store do
      session_store.delete_all_for_user(user.id, except_token: except_token)
    end
  end
end
