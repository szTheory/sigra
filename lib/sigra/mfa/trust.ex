defmodule Sigra.MFA.Trust do
  @moduledoc """
  Trust cookie HMAC signing, verification, and mass revocation.

  "Trust this browser" allows users to skip MFA on recognized browsers.
  The trust cookie is an HMAC-signed payload containing the user_id,
  trust_epoch, and issued timestamp. Verification checks the HMAC
  signature, user_id match, epoch match, and TTL.

  ## Security Properties

  - HMAC-signed via `Plug.Crypto.sign/4` using the app's `secret_key_base` (D-46)
  - Cookie payload: `{user_id, trust_epoch, issued_at}` (D-52)
  - Mass revocation via `mfa_trust_epoch` increment on user record (D-48)
  - HttpOnly, Secure, SameSite=Lax cookie options (D-54)
  - Verified against current user_id to prevent cross-user cookie reuse (Pitfall 6)
  """

  @salt "sigra-mfa-trust"
  @cookie_name "_sigra_mfa_trust"
  @cookie_opts [http_only: true, secure: true, same_site: "Lax"]

  @doc """
  Returns the trust cookie name.
  """
  @doc since: "0.6.0"
  @spec cookie_name() :: String.t()
  def cookie_name, do: @cookie_name

  @doc """
  Removed: use `cookie_opts/1` with a `%Sigra.Config{}` so `:cookie_domain`
  is honored.

  Previously this arity-0 form returned domain-unaware cookie options as a
  backwards-compatibility shim. It was removed because silently dropping
  `:cookie_domain` reopens the subdomain-auth bug Phase 10 fixed: any
  caller still using this form would write cookies without the configured
  domain and break subdomain sign-in without a single compile error.

  Call `cookie_opts/1` with your `%Sigra.Config{}` instead.
  """
  @doc since: "0.6.0"
  @doc deprecated: "Use cookie_opts/1 with a %Sigra.Config{} so cookie_domain is honored. Scheduled for removal in 0.4.0."
  @deprecated "Use cookie_opts/1 with a %Sigra.Config{} so cookie_domain is honored. Scheduled for removal in 0.4.0."
  @spec cookie_opts() :: no_return()
  def cookie_opts do
    raise """
    Sigra.MFA.Trust.cookie_opts/0 was removed to guarantee :cookie_domain is honored.

    Call Sigra.MFA.Trust.cookie_opts/1 with your %Sigra.Config{} instead:

        config = MyApp.Auth.sigra_config()
        Sigra.MFA.Trust.cookie_opts(config)

    See CHANGELOG and guides/recipes/subdomain-auth.md for migration notes.
    """
  end

  @doc """
  Returns remember-me cookie options honoring `:cookie_domain` from the given config.

  When `config.cookie_domain` is `nil`, returns the base host-only options.
  When it is a binary (e.g., `".example.com"`), appends `domain: <value>`.
  """
  @doc since: "0.10.0"
  @spec cookie_opts(Sigra.Config.t()) :: keyword()
  def cookie_opts(%Sigra.Config{cookie_domain: nil}), do: @cookie_opts

  def cookie_opts(%Sigra.Config{cookie_domain: domain}) when is_binary(domain) do
    Keyword.put(@cookie_opts, :domain, domain)
  end

  @doc """
  Signs a trust cookie for the given user and epoch.

  Returns a binary cookie value signed with HMAC via `Plug.Crypto.sign/4`.

  ## Parameters

  - `secret_key_base` - The host app's secret key base
  - `user_id` - The authenticated user's ID
  - `trust_epoch` - The user's current `mfa_trust_epoch` value
  - `trust_ttl` - Trust cookie TTL in seconds
  """
  @doc since: "0.6.0"
  @spec sign(String.t(), term(), non_neg_integer(), pos_integer()) :: binary()
  def sign(secret_key_base, user_id, trust_epoch, trust_ttl) do
    result =
      Plug.Crypto.sign(
        secret_key_base,
        @salt,
        {user_id, trust_epoch, System.system_time(:second)},
        max_age: trust_ttl
      )

    Sigra.Telemetry.event([:sigra, :mfa, :trust, :granted], %{}, %{user_id: user_id})
    result
  end

  @doc """
  Verifies a trust cookie against the current user and epoch.

  Returns `{:ok, user_id}` if valid, `{:error, :invalid}` otherwise.
  Checks: HMAC signature, TTL, user_id match, and trust_epoch match.

  ## Parameters

  - `secret_key_base` - The host app's secret key base
  - `cookie` - The trust cookie value to verify
  - `current_user_id` - The currently authenticated user's ID
  - `current_trust_epoch` - The user's current `mfa_trust_epoch` value
  - `trust_ttl` - Trust cookie TTL in seconds
  """
  @doc since: "0.6.0"
  @spec verify(String.t(), binary(), term(), non_neg_integer(), pos_integer()) ::
          {:ok, term()} | {:error, :invalid}
  def verify(secret_key_base, cookie, current_user_id, current_trust_epoch, trust_ttl) do
    case Plug.Crypto.verify(secret_key_base, @salt, cookie, max_age: trust_ttl) do
      {:ok, {uid, epoch, _issued_at}}
      when uid == current_user_id and epoch == current_trust_epoch ->
        {:ok, uid}

      _ ->
        {:error, :invalid}
    end
  end

  @doc """
  Revokes all trusted browsers for a user by incrementing `mfa_trust_epoch`.

  Uses `update_all` for atomic increment. All existing trust cookies
  become invalid because their epoch no longer matches.

  ## Parameters

  - `repo` - The Ecto repo module
  - `user_schema` - The generated user Ecto schema module
  - `user_id` - The user's ID
  """
  @doc since: "0.6.0"
  @spec revoke_all(module(), module(), term()) :: {non_neg_integer(), nil}
  def revoke_all(repo, user_schema, user_id) do
    import Ecto.Query

    result =
      from(u in user_schema,
        where: u.id == ^user_id,
        update: [inc: [mfa_trust_epoch: 1]]
      )
      |> repo.update_all([])

    Sigra.Telemetry.event([:sigra, :mfa, :trust, :revoked_all], %{}, %{user_id: user_id})
    result
  end
end
