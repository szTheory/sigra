defmodule <%= context_module %>.UserToken do
  use Ecto.Schema
  import Ecto.Query
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
<% end %>
  @session_validity_in_days 60
  @confirm_validity_in_days 2
  @reset_password_validity_in_days 1
  @change_email_validity_in_days 2
  @magic_link_validity_in_seconds 600

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :authenticated_at, :utc_datetime

    belongs_to :user, <%= context_module %>.<%= schema_alias %>

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user sessions to be
  expired. The token system can also be extended to store
  additional data, such as the device used for logging in.
  You could then use this information to display all valid
  sessions and devices in the UI and allow users to
  explicitly expire any session they deem invalid.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(32)
    authenticated_at = DateTime.utc_now() |> DateTime.truncate(:second)

    {token,
     %__MODULE__{
       token: token,
       context: "session",
       authenticated_at: authenticated_at,
       user_id: user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be
  reconstructed, which means anyone with read-only access to the
  database cannot directly use the token in the application to gain
  access. Furthermore, if the user changes their email in the system,
  the tokens sent to the previous email are no longer valid.

  Users can easily adapt the existing code to provide other types
  of delivery methods, for example, by phone numbers.
  """
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    {raw_token, hashed_token} = Sigra.Token.generate_hashed_token()

    {Base.url_encode64(raw_token, padding: false),
     %__MODULE__{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The given token is valid if it matches its hashed counterpart in the
  database and the user email has not changed. This function also checks
  if the token is being used within a certain period, depending on the
  context. The default contexts supported by this function are either
  "confirm" or "reset_password".
  """
  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = Sigra.Token.hash_token(decoded_token)
        days = days_for_context(context)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^days, "day"),
            where: token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days
  defp days_for_context("change:" <> _), do: @change_email_validity_in_days

  @doc """
  Builds a magic link token for the given user.

  The non-hashed token is returned for inclusion in the magic link URL,
  while the hashed part is stored in the database with a "magic_link" context.
  """
  def build_magic_link_token(user) do
    build_hashed_token(user, "magic_link", user.email)
  end

  @doc """
  Checks if a magic link token is valid and returns its underlying lookup query.

  Magic link tokens expire after @magic_link_validity_in_seconds (10 minutes)
  and are verified against the user's current email.
  """
  def verify_magic_link_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = Sigra.Token.hash_token(decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "magic_link"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(@magic_link_validity_in_seconds, "second"),
            where: token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def by_token_and_context_query(token, context) do
    from __MODULE__, where: [token: ^token, context: ^context]
  end

  @doc """
  Gets all tokens for the given user for the given contexts.
  """
  def by_user_and_contexts_query(user, :all) do
    from t in __MODULE__, where: t.user_id == ^user.id
  end

  def by_user_and_contexts_query(user, [_ | _] = contexts) do
    from t in __MODULE__, where: t.user_id == ^user.id and t.context in ^contexts
  end
end
