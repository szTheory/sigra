defmodule <%= context_module %> do
  @moduledoc """
  The authentication context.

  This module provides the primary API for user authentication,
  registration, and account management. All security-critical operations
  delegate to Sigra library functions.
  """

  import Ecto.Query, warn: false
  alias <%= repo_module %>, as: Repo
  alias <%= context_module %>.<%= schema_alias %>
  alias <%= context_module %>.UserToken

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %<%= schema_alias %>{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(<%= schema_alias %>, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %<%= schema_alias %>{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(<%= schema_alias %>, email: email)

    if <%= schema_alias %>.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %<%= schema_alias %>{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(<%= schema_alias %>, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %<%= schema_alias %>{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %<%= schema_alias %>{}
    |> <%= schema_alias %>.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %<%= schema_alias %>{}}

  """
  def change_user_registration(%<%= schema_alias %>{} = user, attrs \\ %{}) do
    <%= schema_alias %>.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %<%= schema_alias %>{}}

  """
  def change_user_email(%<%= schema_alias %>{} = user, attrs \\ %{}) do
    <%= schema_alias %>.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_email_token_query(token, context),
         %<%= schema_alias %>{} = user_from_token <- Repo.one(query),
         true <- user.id == user_from_token.id || :token_user_mismatch do
      user_changeset = user |> <%= schema_alias %>.email_changeset(%{email: user_from_token.email}) |> <%= schema_alias %>.confirm_changeset()
      Ecto.Multi.new()
      |> Ecto.Multi.update(:user, user_changeset)
      |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
      |> Repo.transaction()
      |> case do
        {:ok, %{user: user}} -> {:ok, user}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    else
      _ -> :error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %<%= schema_alias %>{}}

  """
  def change_user_password(%<%= schema_alias %>{} = user, attrs \\ %{}) do
    <%= schema_alias %>.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %<%= schema_alias %>{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(%<%= schema_alias %>{} = user, password, attrs) do
    changeset =
      user
      |> <%= schema_alias %>.password_changeset(attrs)
      |> <%= schema_alias %>.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(%<%= schema_alias %>{} = user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  NOTE: Actual email delivery will be implemented in Phase 3.
  For now this builds the token and calls the provided function.
  """
  def deliver_user_confirmation_instructions(%<%= schema_alias %>{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      # Phase 3 will deliver via Swoosh/Oban
      {:ok, confirmation_url_fun.(encoded_token)}
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %<%= schema_alias %>{} = user <- Repo.one(query),
         {:ok, %{user: user}} <-
           user
           |> <%= schema_alias %>.confirm_changeset()
           |> confirm_user_multi(user)
           |> Repo.transaction() do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(changeset, user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email instructions to the given user.

  NOTE: Actual email delivery will be implemented in Phase 3.
  For now this builds the token and calls the provided function.
  """
  def deliver_user_reset_password_instructions(%<%= schema_alias %>{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    # Phase 3 will deliver via Swoosh/Oban
    {:ok, reset_password_url_fun.(encoded_token)}
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %<%= schema_alias %>{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %<%= schema_alias %>{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %<%= schema_alias %>{}}

  """
  def reset_user_password(%<%= schema_alias %>{} = user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, <%= schema_alias %>.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end
end
