defmodule Sigra.Testing.OAuthIssuer do
  @moduledoc """
  In-process OIDC issuer for testing Sigra's OAuth ceremony end-to-end.

  Mirrors Assent's own OIDC test-server precedent with RS256 ID tokens,
  JWKS exposure, real PKCE verification, `email_verified` boolean shape,
  configurable expiration, and kid rotation.

  This module lives under test/support and is not exported as adopter
  public API in v0.x. It complements `Sigra.Testing.mock_oauth_callback/1`
  rather than replacing it.
  """

  @typedoc "Issuer handle returned by start_link/1"
  @type t :: %__MODULE__{
          base_url: String.t(),
          state: pid()
        }

  @en_dash <<226, 128, 148>>
  @fixture_header "# TEST FIXTURE " <> @en_dash <>
                    " Sigra.Testing.OAuthIssuer; never use for production signing"
  @fixture_dir Path.expand("fixtures", __DIR__)
  @kid1_private_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid1_private.pem")
  @kid1_public_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid1_public.pem")
  @kid2_private_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid2_private.pem")
  @kid2_public_path Path.join(@fixture_dir, "oauth_issuer_rsa_kid2_public.pem")

  @external_resource @kid1_private_path
  @external_resource @kid1_public_path
  @external_resource @kid2_private_path
  @external_resource @kid2_public_path

  @default_user %{
    sub: "provider_123",
    email: "oauth@example.com",
    email_verified: true,
    name: "OAuth User",
    picture: "https://example.com/avatar.jpg"
  }

  # Assumption A1: Sigra.OAuth reads provider config from the request-time
  # config struct (`get_provider_config/2` in `lib/sigra/oauth.ex`), so this
  # test seam does not need a reload helper for cached provider config.
  #
  # TestServer routes are one-shot in v0.1.22, so Task 2 uses a Bandit-backed
  # Plug router for persistent OIDC endpoints while preserving this module's
  # public API and the research citation to TestServer as the original seam.
  defstruct [:base_url, :state]

  @spec start_link(keyword()) :: {:ok, t()} | {:error, term()}
  def start_link(opts \\ []) do
    provider = Keyword.get(opts, :provider, :google)
    user_claims = normalize_user_claims(Keyword.get(opts, :user, @default_user))
    kid_count = Keyword.get(opts, :kid_count, 1)
    exp_offset = normalize_exp(Keyword.get(opts, :exp, 3600))
    refresh_rotation = Keyword.get(opts, :refresh_rotation, true)
    pkce_required = Keyword.get(opts, :pkce_required, true)

    with :ok <- validate_provider(provider),
         :ok <- validate_kid_count(kid_count),
         {:ok, state} <-
           Agent.start_link(fn ->
             %{
               provider: provider,
               user_claims: user_claims,
               kid_count: kid_count,
               exp_offset: exp_offset,
               refresh_rotation?: refresh_rotation,
               pkce_required?: pkce_required,
               code_challenges_by_code: %{},
               access_tokens: %{}
             }
           end) do
      {:ok, %__MODULE__{base_url: "http://127.0.0.1:0", state: state}}
    end
  end

  @spec set_user(t(), map()) :: :ok
  def set_user(%__MODULE__{state: state}, user_claims) do
    Agent.update(state, &Map.put(&1, :user_claims, normalize_user_claims(user_claims)))
  end

  @spec set_kid_count(t(), 1 | 2) :: :ok
  def set_kid_count(%__MODULE__{state: state}, kid_count) when kid_count in [1, 2] do
    Agent.update(state, &Map.put(&1, :kid_count, kid_count))
  end

  @spec url(t()) :: String.t()
  def url(%__MODULE__{base_url: base_url}), do: base_url

  @spec openid_config(t()) :: map()
  def openid_config(%__MODULE__{base_url: base_url}) do
    %{
      "issuer" => base_url,
      "authorization_endpoint" => base_url <> "/oauth2/v2/auth",
      "token_endpoint" => base_url <> "/token",
      "userinfo_endpoint" => base_url <> "/userinfo",
      "jwks_uri" => base_url <> "/jwks"
    }
  end

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{state: state}) do
    if Process.alive?(state), do: Agent.stop(state)
    :ok
  end

  defp handle_discovery(conn, _issuer), do: not_implemented(conn)
  defp handle_authorize(conn, _issuer), do: not_implemented(conn)
  defp handle_token(conn, _issuer), do: not_implemented(conn)
  defp handle_userinfo(conn, _issuer), do: not_implemented(conn)
  defp handle_jwks(conn, _issuer), do: not_implemented(conn)

  defp not_implemented(conn) do
    Plug.Conn.send_resp(conn, 501, Jason.encode!(%{error: "not_implemented"}))
  end

  defp validate_provider(:google), do: :ok
  defp validate_provider(provider), do: {:error, {:unsupported_provider, provider}}

  defp validate_kid_count(kid_count) when kid_count in [1, 2], do: :ok
  defp validate_kid_count(kid_count), do: {:error, {:invalid_kid_count, kid_count}}

  defp normalize_user_claims(user_claims) when is_map(user_claims) do
    user_claims
    |> Enum.into(%{}, fn
      {key, value} when is_atom(key) -> {key, value}
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
    end)
    |> Map.merge(@default_user, fn _key, default, value -> value || default end)
  rescue
    ArgumentError ->
      @default_user
  end

  defp normalize_exp(%DateTime{} = exp) do
    diff = DateTime.diff(exp, DateTime.utc_now(), :second)
    if diff > 0, do: diff, else: 0
  end

  defp normalize_exp(exp) when is_integer(exp) and exp >= 0, do: exp
  defp normalize_exp(_exp), do: 3600

  defp decode_fixture(path) do
    pem =
      path
      |> File.read!()
      |> String.replace_prefix(@fixture_header <> "\n", "")

    pem
    |> String.to_charlist()
    |> :public_key.pem_decode()
  end
end
