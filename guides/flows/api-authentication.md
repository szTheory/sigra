# API Authentication

Sigra supports two API authentication strategies: **bearer tokens** (database-backed, human-readable prefix, revocable) and **JWT** (stateless, scoped, refreshable). Both work with the same `fetch_current_scope/2` plug — Sigra detects the `Authorization: Bearer` header and routes through the API path automatically.

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

## Bearer tokens

Bearer tokens are the recommended default. They're stored as SHA-256 hashes in the DB, so you can revoke them instantly; the raw token has a human-readable `sigra_sk_` prefix so leaks in logs or Slack messages are easy to spot.

### Creating a token

On the settings page, a user clicks "Create API token," names it, and picks scopes:

    def handle_event("create_token", %{"token" => %{"name" => name, "scopes" => scopes}}, socket) do
      user = socket.assigns.current_scope.user
      config = MyApp.Auth.sigra_config()

      case Sigra.Auth.create_api_token(config, user, %{name: name, scopes: scopes}) do
        {:ok, %{raw_token: raw, token: token}} ->
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

In your router, the API pipeline uses the same `UserAuth` plug:

    pipeline :api do
      plug :accepts, ["json"]
      plug MyAppWeb.UserAuth, :fetch_api_user
      plug MyAppWeb.UserAuth, :require_authenticated_api_user
    end

    scope "/api", MyAppWeb do
      pipe_through :api

      get "/me", UserController, :me
      resources "/projects", ProjectController
    end

`fetch_api_user` reads the `Authorization` header, hashes the token, looks it up in `user_api_tokens` (rejecting revoked or expired rows), and assigns `:current_scope` to the conn. If no header or an invalid token, `require_authenticated_api_user` returns 401.

### Scopes

Tokens can be limited to specific scopes (e.g. `read:projects`, `write:projects`). Define the allowed scope list in config:

    config :my_app, MyApp.Auth.Config,
      api_token: [
        scopes: ["read:projects", "write:projects", "admin"]
      ]

Enforce scopes per-route:

    def create(conn, params) do
      with :ok <- Sigra.APIToken.require_scope(conn, "write:projects") do
        # ... do the thing
      end
    end

`require_scope/2` returns `:ok` or halts the conn with a 403 + `assert_scope_denied/1`-compatible body.

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
        # Revoke the whole family and force re-login
        Sigra.Auth.revoke_all_api_tokens(config, user)
        send_resp(conn, 401, "Reuse detected")

      {:error, reason} ->
        send_resp(conn, 401, inspect(reason))
    end

**Reuse detection** is critical: if someone steals a refresh token and the legitimate user rotates it, the next attempted use of the stolen token triggers `:reuse_detected` and the whole family is revoked.

## Dual-mode auth

`UserAuth` detects whether a request is session-based (browser) or bearer-based (API) and dispatches accordingly. This means the same controller can serve both:

    pipeline :maybe_auth do
      plug MyAppWeb.UserAuth, :fetch_current_scope  # reads either session or bearer
    end

    scope "/api", MyAppWeb do
      pipe_through [:api, :maybe_auth]
      # Handlers can check conn.assigns.current_scope regardless of origin
    end

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
