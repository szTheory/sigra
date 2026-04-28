defmodule ExampleWeb.TestOAuthIssuerController do
  @moduledoc """
  Test-only HTTP endpoint that proxies issuer setup/reset into
  Sigra.Testing.OAuthIssuer and request-time provider overrides.
  Mounted only when `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1`. Never ship to
  production. Citation: 87-CONTEXT.md D-87-02 / D-87-05; threat model
  T-87-02 / T-87-07.
  """

  use ExampleWeb, :controller

  @issuer_key {__MODULE__, :issuer}
  @allowed_claim_keys ~w(sub email email_verified name picture)

  def setup(conn, %{"provider" => "google", "user" => user_claims}) when is_map(user_claims) do
    reset_current_issuer()

    with {:ok, issuer} <- issuer_module().start_link(provider: :google, user: atomize_claims(user_claims)) do
      :persistent_term.put(@issuer_key, issuer)

      Application.put_env(:sigra, :oauth_provider_overrides,
        google: [
          base_url: issuer_module().url(issuer),
          openid_configuration: issuer_module().openid_config(issuer)
        ]
      )

      json(conn, %{ok: true, base_url: issuer_module().url(issuer)})
    end
  end

  def setup(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "provider must be google"})
  end

  def reset(conn, _params) do
    reset_current_issuer()
    Application.delete_env(:sigra, :oauth_provider_overrides)
    json(conn, %{ok: true})
  end

  defp reset_current_issuer do
    case :persistent_term.get(@issuer_key, nil) do
      nil ->
        :ok

      issuer ->
        issuer_module().stop(issuer)
        :persistent_term.erase(@issuer_key)
    end
  end

  defp atomize_claims(map) do
    for {key, value} <- map, key in @allowed_claim_keys, into: %{} do
      {String.to_atom(key), value}
    end
  end

  defp issuer_module, do: Module.concat([Sigra, Testing, OAuthIssuer])
end
