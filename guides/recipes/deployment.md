# Deployment

This recipe covers what changes when you move Sigra from `dev` to `prod`: required environment variables, cookie and session configuration, Oban setup for background jobs, rate limit tuning, and platform-specific notes for Fly.io and Gigalixir.

## Required environment variables

Sigra and Phoenix together need these in `:prod`. Set them in your platform's secret store — **never** commit them to the repo.

| Variable | Required by | Description |
|----------|-------------|-------------|
| `DATABASE_URL` | Ecto | PostgreSQL connection URL. Example: `postgres://user:pass@host:5432/my_app_prod` |
| `SECRET_KEY_BASE` | Phoenix | 64-byte random key for session signing and token HMACs. Generate with `mix phx.gen.secret`. |
| `COOKIE_DOMAIN` | Sigra | Leading-dot domain like `.myapp.com`. See [Subdomain Authentication](subdomain-auth.html). Omit for single-domain deployments. |
| `PHX_HOST` | Phoenix | Canonical hostname — `myapp.com`. Used in URL generation and email templates. |
| `PORT` | Phoenix | HTTP port. Platform usually injects this. |
| `CLOAK_KEY` | Sigra + cloak_ecto | Base64-encoded 32-byte key for encrypting OAuth tokens, TOTP secrets, WebAuthn blobs. Generate with `:crypto.strong_rand_bytes(32) \|> Base.encode64()`. |
| `JWT_SECRET_KEY` | Sigra.JWT (only if enabled) | Signing key for JWT access and refresh tokens. |
| Provider keys | Sigra.OAuth (only if enabled) | `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`, `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`, etc. |
| Mailer creds | Swoosh adapter | `POSTMARK_API_KEY`, `MAILGUN_API_KEY`, or equivalent for your adapter. |

### Reading env vars in `config/runtime.exs`

Phoenix 1.8+ reads env at runtime (not compile time) via `config/runtime.exs`. This is where you wire up Sigra:

    # config/runtime.exs
    import Config

    if config_env() == :prod do
      database_url =
        System.get_env("DATABASE_URL") ||
          raise "environment variable DATABASE_URL is missing"

      secret_key_base =
        System.get_env("SECRET_KEY_BASE") ||
          raise "environment variable SECRET_KEY_BASE is missing"

      config :my_app, MyApp.Repo,
        url: database_url,
        pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
        ssl: true

      config :my_app, MyAppWeb.Endpoint,
        url: [host: System.get_env("PHX_HOST"), port: 443, scheme: "https"],
        http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
        secret_key_base: secret_key_base

      config :my_app, MyApp.Auth.Config,
        repo: MyApp.Repo,
        user_schema: MyApp.Accounts.User,
        cookie_domain: System.get_env("COOKIE_DOMAIN"),
        secret_key_base: secret_key_base,
        oauth: [
          enabled: true,
          providers: [
            google: [
              client_id: System.get_env("GOOGLE_CLIENT_ID"),
              client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
              redirect_uri: "https://" <> System.get_env("PHX_HOST") <> "/auth/google/callback"
            ]
          ]
        ]

      config :my_app, MyApp.Vault,
        ciphers: [
          default:
            {Cloak.Ciphers.AES.GCM,
             tag: "AES.GCM.V1",
             key: System.get_env("CLOAK_KEY") |> Base.decode64!()}
        ]
    end

## Cookie configuration in prod

Sigra cookies — remember-me, MFA trust — are automatically `secure: true` in `:prod` (the generated `UserAuth` template reads `Mix.env()` at runtime). You only need to set `cookie_domain` if you want the cookie to apply across subdomains. See [Subdomain Authentication](subdomain-auth.html) for the full story.

At boot time, if `cookie_domain` is unset in `:prod`, Sigra emits a `Logger.warning` pointing to the subdomain-auth guide. The warning is safe to ignore for single-domain deployments; to silence it, explicitly set `cookie_domain: nil` in `runtime.exs`.

### Phoenix session cookie

The Phoenix session cookie itself is configured in `endpoint.ex`, not by Sigra. For subdomain deployments, set it to match:

    # lib/my_app_web/endpoint.ex
    @session_options [
      store: :cookie,
      key: "_my_app_key",
      signing_salt: System.get_env("SESSION_SIGNING_SALT"),
      same_site: "Lax"
    ]

Then in `runtime.exs` append the domain:

    config :my_app, MyAppWeb.Endpoint,
      session_options: [
        store: :cookie,
        key: "_my_app_key",
        signing_salt: System.get_env("SESSION_SIGNING_SALT"),
        same_site: "Lax",
        domain: System.get_env("COOKIE_DOMAIN")
      ]

Keep `COOKIE_DOMAIN` in sync across Sigra, Phoenix, and any other stacks that read cookies.

## Oban for background jobs

Sigra's background jobs (email delivery, session cleanup, audit retention, scheduled deletion) run on Oban. If your app already uses Oban, add Sigra's workers to your Oban config:

    config :my_app, Oban,
      repo: MyApp.Repo,
      queues: [
        default: 10,
        mailers: 5,
        sigra_auth: 5,
        sigra_audit: 2
      ],
      plugins: [
        {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
        {Oban.Plugins.Cron,
         crontab: [
           {"0 3 * * *", Sigra.Workers.CleanupExpiredTokens},
           {"0 4 * * *", Sigra.Workers.AuditCleanup},
           {"*/15 * * * *", Sigra.Workers.ProcessScheduledDeletions}
         ]}
      ]

If you don't use Oban, Sigra's email delivery falls back to inline `Task` supervision. Token cleanup still runs via a minimal built-in scheduler, but with weaker delivery guarantees. **Strongly prefer Oban in production.**

## Rate limit tuning

The default Hammer rate limits are conservative for small apps. Review them for your traffic:

    config :my_app, MyApp.Auth.Config,
      rate_limiting: [
        login: [scale_ms: 60_000, limit: 10],            # 10 login attempts per minute per IP
        register: [scale_ms: 3_600_000, limit: 5],       # 5 registrations per hour per IP
        reset_password: [scale_ms: 60_000, limit: 3],    # 3 reset requests per minute per email
        mfa_challenge: [scale_ms: 300_000, limit: 10],   # 10 attempts per 5 minutes per user
        api_token_create: [scale_ms: 3_600_000, limit: 20]
      ]

Use an ETS backend in single-node deployments (the default). For multi-node, switch to the Redis backend:

    config :my_app, MyApp.RateLimiter,
      backend: Hammer.Backend.Redis,
      redis_url: System.get_env("REDIS_URL")

## Health check endpoint

Add a health check that verifies the DB and the Sigra config:

    scope "/", MyAppWeb do
      pipe_through [:api]
      get "/health", HealthController, :index
    end

    defmodule MyAppWeb.HealthController do
      use MyAppWeb, :controller

      def index(conn, _params) do
        checks = %{
          db: Ecto.Adapters.SQL.query!(MyApp.Repo, "SELECT 1") && :ok,
          sigra_config: MyApp.Auth.sigra_config() && :ok
        }

        json(conn, %{status: "ok", checks: checks})
      end
    end

## Fly.io specifics

    fly secrets set \
      SECRET_KEY_BASE="$(mix phx.gen.secret)" \
      COOKIE_DOMAIN=".myapp.com" \
      CLOAK_KEY="$(elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))')" \
      GOOGLE_CLIENT_ID=... \
      GOOGLE_CLIENT_SECRET=...

For Oban, bump your `fly.toml` `min_machines_running = 1` so the scheduler has something to wake up. For a multi-region deploy, pin Oban to a single region to avoid duplicate job execution.

## Gigalixir specifics

    gigalixir config:set \
      SECRET_KEY_BASE=$(mix phx.gen.secret) \
      COOKIE_DOMAIN=.myapp.com \
      CLOAK_KEY=$(elixir -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))')

Gigalixir provisions Postgres automatically; `DATABASE_URL` is set for you.

## Secret rotation

Rotate `SECRET_KEY_BASE` if you suspect a leak. Rotation:

1. Generate the new value.
2. Deploy with **both** old and new keys (Phoenix supports `secret_key_base_old` via a custom `Plug.Session` config).
3. Wait for all existing sessions to naturally expire (up to `session_ttl` — default 60 days).
4. Remove the old key.

For `CLOAK_KEY`, use `Cloak.Vault` key rotation: add the new key as the default, keep the old key in the cipher list until all encrypted rows are re-encrypted via a migration task.

## Monitoring

Sigra emits telemetry events for every auth operation:

- `[:sigra, :auth, :login, :stop]` — login latency and outcome
- `[:sigra, :auth, :register, :stop]` — registration
- `[:sigra, :mfa, :challenge, :stop]` — MFA verification
- `[:sigra, :api_token, :create, :stop]` — API token creation

Subscribe with `:telemetry.attach/4` and forward to Datadog, Honeycomb, or Prometheus. See [Testing Auth Flows](testing.html) for a list of emitted events.

## Related

- [Subdomain Authentication](subdomain-auth.html) — `cookie_domain` deep dive.
- [API Authentication](api-authentication.html) — JWT keys and scopes.
- [Audit Logging](audit-logging.html) — retention policy for compliance.
- [Getting Started](getting-started.html) — the dev loop before you deploy.
