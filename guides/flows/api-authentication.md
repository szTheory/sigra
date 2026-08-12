# API Authentication

Sigra uses explicit credential-kind pipelines. Select the pipeline that matches
the route's credential contract instead of asking one plug to infer a credential
type from a header. Cookie sessions establish browser identity; personal access
tokens (PATs) and JWTs can also carry delegated scopes.

## What Sigra gives you

- **`Sigra.Auth.create_api_token/3`** — creates a bearer token. Returns the raw token **once** (show it to the user; it's never retrievable again) and the persisted struct.
- **`Sigra.Auth.revoke_api_token/2`** — revokes a single token by ID.
- **`Sigra.Auth.revoke_all_api_tokens/2`** — revokes every token for a user.
- **`Sigra.Auth.list_api_tokens/3`** — lists non-revoked tokens for display on a settings page.
- **`Sigra.Auth.list_api_scopes/1`** — returns the configured scope list.
- **`Sigra.Auth.generate_jwt_tokens/3`** — generates an access + refresh JWT pair.
- **`Sigra.Auth.refresh_jwt/2`** — rotates a refresh token (reuse detection).
- **`Sigra.Auth.revoke_jwt_refresh/2`** — revokes a refresh token.
- **`MyAppWeb.APITokenController`** — generated controller for create/revoke/list.
- **`MyAppWeb.UserAuth`** — dual-mode plug that handles both session and bearer auth.

## Select an explicit pipeline

Every successful pipeline assigns the host's normal current-user Scope. The
first successful normal Scope wins, so a later pipeline must leave an existing
authenticated Scope unchanged. Credential metadata is separate from the Scope
in `conn.private[:sigra_auth]`; it contains bounded verifier-produced facts and
never the raw credential. Only PAT and JWT carry delegated scopes. Browser and
app sessions identify a user but do not authorize scoped routes.

| Route contract | Public plug | Notes |
|----------------|-------------|-------|
| Browser cookie session | `Sigra.Plug.FetchSession` | Uses the configured session store and reloads the current user. |
| Opaque first-party app session | `Sigra.Plug.FetchAppSession` | Public selection seam; it is fail closed until Phase 245 supplies verifier and storage. |
| Personal access token | `Sigra.Plug.FetchAPIToken` | Verifies one Bearer PAT and records trusted, bounded PAT facts. |
| JWT access token | `Sigra.Plug.FetchJWT` | Verifies one Bearer JWT and records trusted, bounded JWT facts. |

All explicit plugs use the same host-selected options:

```elixir
config = MyApp.Auth.sigra_config()

plug Sigra.Plug.FetchAPIToken,
  config: config,
  scope_module: MyApp.Auth.Scope
```

### Cookie-session pipeline

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug Sigra.Plug.FetchSession,
    config: MyApp.Auth.sigra_config(),
    scope_module: MyApp.Auth.Scope
end
```

### App-session pipeline

```elixir
pipeline :first_party_app do
  plug :accepts, ["json"]
  plug Sigra.Plug.FetchAppSession,
    config: MyApp.Auth.sigra_config(),
    scope_module: MyApp.Auth.Scope
end
```

Do not treat the app-session selection seam as storage, an endpoint, or a
fallback to another credential kind. It authenticates nothing until Phase 245.

### PAT and JWT pipelines

```elixir
pipeline :api_pat do
  plug :accepts, ["json"]
  plug Sigra.Plug.FetchAPIToken,
    config: MyApp.Auth.sigra_config(),
    scope_module: MyApp.Auth.Scope
end

pipeline :api_jwt do
  plug :accepts, ["json"]
  plug Sigra.Plug.FetchJWT,
    config: MyApp.Auth.sigra_config(),
    scope_module: MyApp.Auth.Scope
end
```

Use `Sigra.Plug.RequireScopes` after a PAT or JWT pipeline when a route needs
delegated authorization. It reads only trusted server-produced
`conn.private[:sigra_auth]` facts, never Scope-shaped host fields or
client-derived scope data.

### Mixed ordered pipeline

If a host intentionally supports several credential kinds on one route, order
the explicit plugs in host policy order. The first successful normal Scope wins;
the route still owns which credential kinds it accepts.

```elixir
pipeline :mixed_first_party do
  plug Sigra.Plug.FetchSession,
    config: MyApp.Auth.sigra_config(),
    scope_module: MyApp.Auth.Scope

  plug Sigra.Plug.FetchAPIToken,
    config: MyApp.Auth.sigra_config(),
    scope_module: MyApp.Auth.Scope

  plug Sigra.Plug.FetchJWT,
    config: MyApp.Auth.sigra_config(),
    scope_module: MyApp.Auth.Scope
end
```

## Bearer tokens

Bearer tokens are the recommended default. They're stored as SHA-256 hashes in the DB, so you can revoke them instantly; the raw token has a human-readable `sigra_sk_` prefix so leaks in logs or Slack messages are easy to spot.

### Creating a token

On the settings page, a user clicks "Create API token," names it, and picks scopes:

    def handle_event("create_token", %{"token" => %{"name" => name, "scopes" => scopes}}, socket) do
      user = socket.assigns.current_scope.user
      config = MyApp.Auth.sigra_config()

      case Sigra.Auth.create_api_token(config, user, %{name: name, scopes: scopes}) do
        {:ok, raw, token} ->
          {:noreply, assign(socket, raw_token: raw, token: token, step: :show_raw)}

        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end

The `raw_token` looks like `sigra_sk_abcd1234efgh5678...`. Show it to the user in a copy-to-clipboard UI with a warning: "This is the only time you'll see this token. Copy it now."

### Using a token

Clients send the token in the `Authorization` header:

    curl https://myapp.com/api/me \
      -H "Authorization: Bearer sigra_sk_abcd1234efgh5678..."

In your router, choose the PAT pipeline explicitly:

    pipeline :api do
      plug :accepts, ["json"]
      plug Sigra.Plug.FetchAPIToken,
        config: MyApp.Auth.sigra_config(),
        scope_module: MyApp.Auth.Scope
      plug MyAppWeb.UserAuth, :require_authenticated_api_user
    end

    scope "/api", MyAppWeb do
      pipe_through :api

      get "/me", UserController, :me
      resources "/projects", ProjectController
    end

`FetchAPIToken` reads one `Authorization: Bearer` PAT, verifies it against
`user_api_tokens` (rejecting revoked or expired rows), reloads the current user,
and assigns the normal current-user Scope. If no header or an invalid token,
`require_authenticated_api_user` returns 401.

### Scopes

Tokens can be limited to specific scopes (e.g. `read:projects`, `write:projects`). Define the allowed scope list in config:

    config :my_app, MyApp.Auth.Config,
      api_token: [
        custom_scopes: ["read:projects", "write:projects", "admin"]
      ]

Enforce scopes per-route:

    pipeline :api_write_projects do
      plug Sigra.Plug.RequireScopes,
        scopes: ["write:projects"],
        error_handler: MyAppWeb.AuthErrorHandler
    end

    scope "/api", MyAppWeb do
      pipe_through [:api, :api_write_projects]

      post "/projects", ProjectController, :create
    end

`RequireScopes` reads only Sigra's verified `conn.private[:sigra_auth]` facts and
halts with the host error handler's 403 response when a credential lacks the
required scope.

### Revocation

From the settings page:

    def handle_event("revoke", %{"id" => id}, socket) do
      Sigra.Auth.revoke_api_token(config(), id)
      {:noreply, put_flash(socket, :info, "Token revoked.")}
    end

Revocation is instant — the next request using that token returns 401. The row remains in the DB with `revoked_at` set so you can audit which tokens were revoked and when.

### Expiry

Tokens can have an optional `expires_at`:

    Sigra.Auth.create_api_token(config, user, %{
      name: "CI token",
      expires_at: DateTime.add(DateTime.utc_now(), 90, :day)
    })

A nightly Oban job (`Sigra.Workers.TokenCleanup`) deletes expired rows — see `cleanup_expired_tokens/2` in that module if you need to run it inline.

## JWT

JWT is opt-in for stateless scenarios (cross-service auth, mobile apps that want refresh rotation). Enable it in config:

    config :my_app, MyApp.Auth.Config,
      jwt: [
        enabled: true,
        issuer: "https://myapp.com",
        access_ttl: 900,      # 15 minutes
        refresh_ttl: 2_592_000, # 30 days
        secret_key: System.get_env("JWT_SECRET_KEY")
      ]

### Generating a pair

    {:ok, %{access_token: access, refresh_token: refresh}} =
      Sigra.Auth.generate_jwt_tokens(config, user, ["read:projects"])

### Refreshing

    case Sigra.Auth.refresh_jwt(config, refresh_token) do
      {:ok, %{access_token: new_access, refresh_token: new_refresh}} ->
        # Rotation: old refresh is invalidated, new pair issued
        json(conn, %{access_token: new_access, refresh_token: new_refresh})

      {:error, :reuse_detected} ->
        # Attempted reuse of an already-rotated refresh token → possible theft
        # Sigra.Auth.refresh_jwt/2 has already revoked the reused token family.
        send_resp(conn, 401, "Reuse detected")

      {:error, reason} ->
        send_resp(conn, 401, inspect(reason))
    end

**Reuse detection** is critical: if someone steals a refresh token and the legitimate user rotates it, the next attempted use of the stolen token triggers `:reuse_detected`. `Sigra.Auth.refresh_jwt/2` has already revoked the whole token family before returning that error. Resolve the user explicitly before taking any additional, application-specific action.

## Compatibility migration

`Sigra.Plug.FetchBearer` is a deprecated compatibility dispatcher for installed
routers that relied on legacy token-shape detection. Do not use it in new
pipelines. Migrate each route to `Sigra.Plug.FetchAPIToken` or
`Sigra.Plug.FetchJWT` (and `Sigra.Plug.FetchSession` where browser identity is
intended), so the host owns credential selection explicitly.

## Testing

    test "create_api_token returns a raw token and persisted struct" do
      user = Sigra.Testing.user_fixture()
      config = MyApp.Auth.sigra_config()

      {raw, token} = Sigra.Testing.create_api_token(config, user, name: "test")

      assert String.starts_with?(raw, "sigra_sk_")
      assert token.name == "test"
    end

    test "authenticated API request with bearer token" do
      user = Sigra.Testing.user_fixture()
      {raw, _} = Sigra.Testing.create_api_token(MyApp.Auth.sigra_config(), user, name: "test")

      conn = build_conn() |> Sigra.Testing.put_bearer_token(raw) |> get(~p"/api/me")

      assert json_response(conn, 200)["email"] == user.email
    end

## Related

- [Login and Logout](login-and-logout.html) — session auth for the browser path.
- [Deployment](deployment.html) — `JWT_SECRET_KEY` and `CLOAK_KEY` management.
- `Sigra.APIToken` — token primitives
- `Sigra.JWT` — JWT primitives
