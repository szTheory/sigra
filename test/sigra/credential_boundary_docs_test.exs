defmodule Sigra.CredentialBoundaryDocsTest do
  use ExUnit.Case, async: true

  @contract_path "guides/introduction/contract.md"
  @api_path "guides/flows/api-authentication.md"
  @lockspire_path "guides/recipes/companion-libs/lockspire.md"

  defp root, do: Path.expand("../..", __DIR__)
  defp read(path), do: root() |> Path.join(path) |> File.read!()

  test "the normative ownership matrix assigns every credential-boundary concern" do
    contract = read(@contract_path)

    assert String.contains?(contract, "## Normative Credential-Boundary Responsibility Matrix")

    for marker <- [
          "Sigra",
          "Lockspire",
          "Crosswake",
          "Phoenix host",
          "First-party identity and credentials",
          "Browser and app sessions",
          "OAuth/OIDC delegation",
          "Route/runtime and offline-island policy",
          "Product authorization and account-to-Scope mapping",
          "Media/CDN/cache/lease policy",
          "Replay decisions"
        ] do
      assert String.contains?(contract, marker), "contract missing #{inspect(marker)}"
    end
  end

  test "primary API guidance selects explicit credential pipelines and keeps facts separate" do
    api = read(@api_path)

    for marker <- [
          "Sigra.Plug.FetchSession",
          "Sigra.Plug.FetchAppSession",
          "Sigra.Plug.FetchAPIToken",
          "Sigra.Plug.FetchJWT",
          "Sigra.Plug.RequireScopes",
          "first successful normal Scope wins",
          "conn.private[:sigra_auth]",
          "Only PAT and JWT carry delegated scopes",
          "fail closed until Phase 245"
        ] do
      assert String.contains?(api, marker), "API guide missing #{inspect(marker)}"
    end

    primary = api |> String.split("## Compatibility migration", parts: 2) |> hd()
    refute String.contains?(primary, "FetchBearer")
    refute String.contains?(primary, "detects the `Authorization: Bearer` header")
    refute String.contains?(primary, "Sigra.APIToken.require_scope")
    refute String.contains?(api, "api_token: [\n        scopes:")
    assert String.contains?(api, "api_token: [\n        custom_scopes:")
  end

  test "Lockspire receives normal Scope identity without Sigra credentials" do
    lockspire = read(@lockspire_path)

    for marker <- [
          "Sigra authenticates first-party users",
          "Lockspire owns OAuth/OIDC delegation for registered external clients",
          "Crosswake receives projected facts only",
          "Phoenix host owns product authorization and replay policy",
          "normal current-user Scope",
          "never receives Sigra credentials"
        ] do
      assert String.contains?(lockspire, marker), "Lockspire recipe missing #{inspect(marker)}"
    end
  end

  test "API-token creation example matches the public success tuple" do
    api = read(@api_path)

    assert String.contains?(api, "{:ok, raw, token} ->")
    refute String.contains?(api, "{:ok, %{raw_token: raw, token: token}} ->")
  end

  test "JWT reuse example relies on refresh-family revocation" do
    api = read(@api_path)

    assert String.contains?(api, "has already revoked the reused token family")
    refute String.contains?(api, "Sigra.Auth.revoke_all_api_tokens(config, user)")
  end

  test "API-token cleanup guidance uses the API-token retention API" do
    api = read(@api_path)

    assert String.contains?(api, "cleanup_revoked_api_tokens(config)")
    assert String.contains?(api, "api_token[:cleanup_retention]")
    refute String.contains?(api, "cleanup_expired_tokens/2")
  end

  test "first-party app ceremony guidance preserves option and ownership fences" do
    api = read(@api_path)
    contract = read(@contract_path)

    for marker <- [
          "--app-sessions",
          "--app-password-login",
          "hosted system-browser login",
          "PKCE S256",
          "exact callback allowlist",
          "one-time, 60-second",
          "five-minute MFA challenge",
          "FetchAppSession",
          "not an OAuth password grant",
          "browser_required",
          "Lockspire remains the owner",
          "Crosswake may consume projected facts",
          "native SDK, PWA/offline or media runtime, Electron runtime, or admin UI"
        ] do
      assert String.contains?(api, marker), "first-party guide missing #{inspect(marker)}"
    end

    for forbidden <- [
          "dynamic registration",
          "wildcard callbacks",
          "client secrets",
          "consent",
          "discovery",
          "JWKS",
          "delegated token exchange"
        ] do
      assert String.contains?(api, forbidden), "scope fence missing #{inspect(forbidden)}"
    end

    assert String.contains?(contract, "Hosted first-party login is system-browser PKCE")
    assert String.contains?(contract, "Neither ceremony is OAuth/OIDC delegation")
  end
end
