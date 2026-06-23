defmodule Sigra.Account.PasswordChange do
  @moduledoc """
  Password change lifecycle: change, set for OAuth users, force change.

  Handles password changes with current password verification, session
  invalidation, and lifecycle hooks. Also supports OAuth-only users
  setting an initial password (without current password check).

  ## Security Properties

  - Current password verification before change (D-35)
  - Session invalidation configurable (D-34, D-42)
  - Password change notification (D-37, D-42)
  - Force password change flag for admin use (D-38)
  - Telemetry spans for all operations (D-43)
  """

  alias Ecto.Multi
  alias Sigra.{Hooks, Telemetry}

  @doc """
  Change password with current password verification.

  Validates the current password, then updates the password hash,
  sets `password_changed_at`, clears `must_change_password`, and
  invalidates other sessions (configurable).

  ## Options

  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for password update
  - `:validate_password_fn` - `(user, password -> boolean())` to verify current password
  - `:session_store` - SessionStore for session invalidation
  - `:config` - Optional config for hooks and password settings
  - `:except_token` - Current session token to preserve

  ## Returns

  - `{:ok, user}` on success
  - `{:error, :invalid_password}` if current password is wrong
  - `{:error, changeset}` on validation failure
  """
  @doc since: "0.8.0"
  @spec change(module(), map(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, :invalid_password | Ecto.Changeset.t()}
  def change(repo, user, current_password, attrs, opts) do
    validate_password_fn = Keyword.fetch!(opts, :validate_password_fn)

    unless validate_password_fn.(user, current_password) do
      {:error, :invalid_password}
    else
      do_change(repo, user, attrs, opts)
    end
  end

  @doc """
  Set password for OAuth-only user (no current password verification).

  Used when an OAuth-only user wants to add a password to enable
  hybrid authentication. Requires sudo mode upstream.

  ## Options

  - `:changeset_fn` - `(user, attrs -> Ecto.Changeset.t())` for password set
  - `:session_store` - Optional SessionStore
  - `:config` - Optional config for hooks

  ## Returns

  - `{:ok, user}` on success
  - `{:error, changeset}` on validation failure
  """
  @doc since: "0.8.0"
  @spec set_for_oauth_user(module(), map(), map(), keyword()) ::
          {:ok, map()} | {:error, Ecto.Changeset.t()}
  def set_for_oauth_user(repo, user, attrs, opts) do
    Telemetry.span([:sigra, :password, :set], %{user_id: user.id}, fn ->
      changeset_fn = Keyword.fetch!(opts, :changeset_fn)

      multi =
        Multi.new()
        |> Multi.update(:user, changeset_fn.(user, attrs))

      case repo.transaction(multi) do
        {:ok, %{user: updated_user}} -> {:ok, updated_user}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    end)
  end

  @doc """
  Check if a user must change their password.

  Returns `true` if the `must_change_password` flag is set on the user.
  Used by `Sigra.Plug.RequirePasswordChange` to redirect users.
  """
  @doc since: "0.8.0"
  @spec force_change_required?(map()) :: boolean()
  def force_change_required?(user) do
    Map.get(user, :must_change_password, false) == true
  end

  @doc """
  Admin API: require user to change password on next login.

  Sets the `must_change_password` flag to `true`. The user will be
  redirected to the password change form until they comply.
  """
  @doc since: "0.8.0"
  @spec require_force_change(module(), map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def require_force_change(repo, user) do
    Telemetry.span([:sigra, :password, :force_change], %{user_id: user.id}, fn ->
      changeset = Ecto.Changeset.change(user, %{must_change_password: true})
      repo.update(changeset)
    end)
  end

  @doc """
  Clear the force password change flag.

  Called after the user successfully changes their password.
  """
  @doc since: "0.8.0"
  @spec clear_force_change(module(), map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def clear_force_change(repo, user) do
    Telemetry.span([:sigra, :password, :force_change_completed], %{user_id: user.id}, fn ->
      changeset = Ecto.Changeset.change(user, %{must_change_password: false})
      repo.update(changeset)
    end)
  end

  # --- Private ---

  defp do_change(repo, user, attrs, opts) do
    Telemetry.span([:sigra, :password, :change], %{user_id: user.id}, fn ->
      changeset_fn = Keyword.fetch!(opts, :changeset_fn)
      config = Keyword.get(opts, :config, [])

      # Merge password_changed_at and clear must_change_password
      enhanced_attrs =
        Map.merge(attrs, %{
          password_changed_at: DateTime.utc_now() |> DateTime.truncate(:second),
          must_change_password: false
        })

      multi =
        Multi.new()
        |> Multi.update(:user, changeset_fn.(user, enhanced_attrs))
        |> Hooks.maybe_run_hook(:password_change, %{user: user}, config)

      case repo.transaction(multi) do
        {:ok, %{user: updated_user}} ->
          maybe_invalidate_sessions(user, opts)
          {:ok, updated_user}

        {:error, :user, changeset, _} ->
          {:error, changeset}
      end
    end)
  end

  defp maybe_invalidate_sessions(user, opts) do
    config = Keyword.get(opts, :config, [])

    invalidate? =
      get_in(access_config(config), [:password, :invalidate_sessions_on_change]) != false

    if invalidate? do
      session_store = Keyword.get(opts, :session_store)

      if session_store do
        # The Ecto session store needs `:repo` + `:session_schema` to run the
        # delete; the caller threads them through `:session_store_opts`. Carry
        # the current-session token through so it survives (sign out OTHER
        # sessions, preserve the one confirming the change).
        store_opts = Keyword.get(opts, :session_store_opts, [])
        except_token = Keyword.get(opts, :except_token)

        delete_opts =
          if except_token,
            do: Keyword.put(store_opts, :except_token, except_token),
            else: store_opts

        session_store.delete_all_for_user(user.id, delete_opts)
      end
    end
  end

  # `config` may arrive as a `Sigra.Config` struct (the public `Sigra.Auth`
  # path), a plain map, or a keyword list (unit tests). Only the latter two are
  # Access-compatible; a struct must be turned into a map before `get_in/2`.
  defp access_config(%_{} = config), do: Map.from_struct(config)
  defp access_config(config), do: config
end
