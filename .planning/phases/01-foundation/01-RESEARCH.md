# Phase 1: Foundation - Research

**Researched:** 2026-04-05
**Domain:** Elixir library architecture, Mix generators, Phoenix auth patterns, config validation, telemetry
**Confidence:** HIGH

## Summary

Phase 1 establishes the entire Sigra project from scratch -- mix project setup, module structure, configuration system, behaviour contracts, telemetry skeleton, and the `mix sigra.install` generator. The primary reference implementations are Phoenix 1.8's `phx.gen.auth` (for generator/injector patterns and Scope struct), Oban (for telemetry and testing helper patterns), and NimbleOptions (for config validation).

The core technical challenge is the hybrid lib+generator boundary: security-critical crypto and token logic must live in the library dependency, while customizable schemas, context modules, plugs, and LiveView pages are generated into the host application. The generator must produce code that feels native to Phoenix 1.8 -- plain Ecto schemas, Scope struct, `current_scope` assigns -- while calling into `Sigra.*` library functions for all security operations.

**Primary recommendation:** Model the generator closely on `phx.gen.auth`'s existing patterns (argument format, template discovery, injector module, idempotency checks), and model the library's runtime API on Oban's patterns (behaviour-based extensibility, `attach_default_logger`, `Testing` module).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Feature-grouped flat modules. Top-level modules per concern: `Sigra.Auth`, `Sigra.Token`, `Sigra.Crypto`, `Sigra.Config`, `Sigra.Telemetry`. Max 3 levels of nesting.
- **D-02:** `concept.ex` + `concept/` convention -- public module at root, internals in subdirectory.
- **D-03:** Singular behaviour name, plural implementations directory (`Sigra.Mailer` -> `Sigra.Mailers.Swoosh`).
- **D-04:** Mix tasks in `lib/mix/tasks/`. Testing helpers in `lib/sigra/testing.ex`. Errors colocated or in single `error.ex`.
- **D-05:** Config struct validated by NimbleOptions at initialization. `Sigra.Config` struct passed explicitly. Progressive disclosure -- only `repo` and `user_schema` required, defaults for everything else.
- **D-06:** Config grouped by feature domain -- `password:`, `session:`, `token_ttl:`, `rate_limiting:` as nested NimbleOptions sections.
- **D-07:** `otp_app` as optional convenience layer for `config.exs`. Primary mechanism is explicit argument passing. Runtime-first.
- **D-08:** Core-only install in Phase 1 (`mix sigra.install Accounts User users`). Generates migrations, schemas, context module, plugs, optional LiveView pages.
- **D-09:** EEx templates in `priv/templates/sigra.install/` following Phoenix conventions. Host project's `priv/templates/` checked first for user overrides.
- **D-10:** String-based injection for router/config (phx.gen.auth `Injector` pattern). Idempotency via `String.contains?` before every injection.
- **D-11:** Host app detection via `Mix.Phoenix` functions -- `otp_app()`, `base()`, `context_app()`. Ecto adapter detected at runtime via `repo.__adapter__()`.
- **D-12:** 4 behaviours in Phase 1: `Sigra.Hasher`, `Sigra.Mailer`, `Sigra.SessionStore`, `Sigra.RateLimiter`.
- **D-13:** Each behaviour has a default implementation and is Mox-friendly.
- **D-14:** TokenGenerator and AuditLogger behaviours deferred to later phases. TOTP/WebAuthn crypto is NOT a behaviour.
- **D-15:** Dedicated `Sigra.Telemetry` module with helper functions and full event catalog.
- **D-16:** `attach_default_logger/1` for instant structured logging (Oban pattern).
- **D-17:** NEVER include passwords, hashes, TOTP codes, bearer tokens, or OAuth secrets in telemetry metadata.
- **D-18:** `:telemetry.span/3` for synchronous operations. Manual start/stop for multi-step flows. One-shot events for security signals.
- **D-19:** Always `{:ok, result}` | `{:error, reason}`. Changesets for form validation. Atom-tagged errors for domain failures. Error structs with `defexception`.
- **D-20:** Rate limiting returns `{:allow, count}` | `{:deny, retry_after_ms}`.
- **D-21:** `Sigra.Error.safe_message/1` maps internal errors to enumeration-safe user-facing strings.
- **D-22:** Multi-step composition via `with` chains with tagged tuples.
- **D-23:** `users` table: id, email (citext/collate), hashed_password (nullable), confirmed_at, locked_at, timestamps. `user_tokens` table with HMAC-hashed tokens.
- **D-24:** Indexes: unique on users.email, unique on user_tokens[:context, :token], index on user_tokens.user_id. Expiry computed from inserted_at + duration.
- **D-25:** Scope struct is runtime-only. `MyApp.Auth.Scope` wraps user.id on conn.assigns.current_scope. Compatible with Phoenix 1.8.
- **D-26:** Binary ID support via `--binary-id` flag. Multi-database DDL: citext for Postgres, collate: :nocase for SQLite, size: 160 for MySQL.
- **D-27:** Feature tables added by later phase generators.
- **D-28:** Security-critical plugs in library: `Sigra.Plug.FetchSession`, `Sigra.Plug.FetchBearer`, `Sigra.Plug.RequireAuthenticated`, `Sigra.Plug.RequireSudo`.
- **D-29:** Generated `MyAppWeb.UserAuth` delegates to library plugs.
- **D-30:** `Sigra.Plug.ErrorHandler` behaviour with `@callback auth_error(conn, type, opts)`.
- **D-31:** Phoenix 1.8 Scope pattern: `conn.assigns.current_scope`. Dual-mode support.
- **D-32:** Library ships `Sigra.Testing` module with assertion helpers.
- **D-33:** Generator creates app-specific fixtures and ConnCase helpers.
- **D-34:** All 4 behaviours are Mox-friendly.
- **D-35:** Compile-time detection via `Code.ensure_loaded?/1` wrapping entire modules.
- **D-36:** Oban absent: email sends inline. Hammer absent: no-op rate limiter with logged warning.
- **D-37:** Auto-detect with explicit config override.
- **D-38:** Guide-first docs (Oban style).
- **D-39:** llms.txt enabled via default formatters.
- **D-40:** `@doc since: "1.0.0"` on all public functions.
- **D-41:** Multi-job GitHub Actions with Elixir version matrix.
- **D-42:** PLT cached in `_build/`. Actions pinned to commit SHA.
- **D-43:** Follow phx.gen.auth naming exactly.
- **D-44:** Library functions follow same naming conventions.
- **D-45:** Option keys always atoms, flat by default, positive booleans.
- **D-46:** Start at v0.1.0. MIT license. CHANGELOG.md.
- **D-47:** `source_ref: "v#{@version}"` for HexDocs links.
- **D-48:** Derive all keys from host app's `secret_key_base` via `Plug.Crypto.KeyGenerator`.
- **D-49:** Session tokens stored raw. Email/API tokens SHA-256 hashed before storage. Constant-time comparison via `Plug.Crypto.secure_compare/2`.
- **D-50:** Locked-down defaults: Argon2id, 12-char min password, signed HttpOnly SameSite=Lax Secure cookies, session renewal on login.
- **D-51:** Target `elixir: "~> 1.18"`, `phoenix: "~> 1.8"`, `ecto: "~> 3.12"`, `ecto_sql: "~> 3.12"`. OTP 27+.
- **D-52:** Use built-in `JSON` module for internal needs. `Phoenix.json_library()` for Phoenix integration.
- **D-53:** Generator produces Phoenix 1.8-compatible Scope module.

### Claude's Discretion
- Exact Argon2id time/memory cost parameters (within OWASP range)
- Loading skeleton and progress indicator design in generated LiveView pages
- Internal module organization within `Sigra.Crypto` (single module vs submodules)
- Exact EEx template structure within `priv/templates/`
- Specific Credo rules beyond the established baseline
- Default telemetry log format and filtering implementation

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | Library initializes via `mix sigra.install` generating migrations, schemas, context module, plugs, and optional LiveView pages | Generator architecture patterns from phx.gen.auth, EEx templates in priv/templates/, Injector module pattern |
| FOUND-02 | Generated code follows Phoenix context pattern (`MyApp.Auth`) with clean DDD boundaries | Phoenix 1.8 Scope struct pattern, phx.gen.auth context module structure |
| FOUND-03 | Security-critical code lives in Sigra library dep; customizable code is generated into user's project | Hybrid lib+generator boundary defined; Plug.Crypto for token/HMAC ops, argon2_elixir for hashing |
| FOUND-04 | No macro-based schema injection -- generated schemas are plain Ecto schemas calling library functions | EEx template generation of schema files with explicit fields |
| FOUND-05 | Configuration via explicit options with smart defaults | NimbleOptions nested schema validation, struct-based config pattern |
| FOUND-06 | Behaviour + callback architecture for extensibility (mailer, rate limiter, session store) | 4 behaviours with default implementations, Mox-friendly design |
| FOUND-07 | Telemetry events emitted for all auth operations | :telemetry.span/3 pattern, Oban.Telemetry event catalog pattern, attach_default_logger |
| FOUND-08 | Works with standard controllers/Plug without requiring LiveView | Library plugs as proper `@behaviour Plug` modules, generated UserAuth module |
| FOUND-09 | Optional LiveView components for login, registration, MFA, settings | --live/--no-live flag on generator, conditional template generation |
| FOUND-10 | Headless mode -- all logic works without any UI components | Library modules (Sigra.Auth, Sigra.Token, Sigra.Crypto) have zero UI deps |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path. Plug compatibility where DX is not compromised.
- **Database:** PostgreSQL as primary (citext, JSONB). MySQL/SQLite support via conditional migrations.
- **Security:** OWASP standards throughout. Argon2id default. All tokens HMAC-protected. Enumeration prevention by default.
- **Dependencies:** Minimal transitive deps. Copy-paste over deps when code is small and stable.
- **LiveView:** Supported but optional. Core works with standard controllers. Login/logout via HTTP POST.
- **Testing:** Comprehensive spec coverage -- happy path, main error cases, boundary conditions. AAA style, flat, self-contained.
- **GSD Workflow:** All changes through GSD commands. No direct edits outside workflow.

## Standard Stack

### Core (Phase 1 Dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elixir | ~> 1.18 | Language runtime | 1.18+ adds built-in JSON, type-checking. 1.19.5 current stable. |
| phoenix | ~> 1.8 | Web framework integration (generator + plugs) | 1.8.5 current. Scope pattern, magic links, sudo mode plug. |
| ecto | ~> 3.12 | Schema definitions, changesets | 3.13.5 current. `Repo.transact/2`, `:writable` field option. |
| ecto_sql | ~> 3.12 | Migration DSL, SQL sandbox | 3.13.x current. citext support. |
| nimble_options | ~> 1.1 | Config schema validation + docs generation | 1.1.1 current. Dashbit standard for keyword-list validation. |
| argon2_elixir | ~> 4.1 | Argon2id password hashing | 4.1.3 current. OWASP gold standard. Requires native compilation. |
| comeonin | ~> 5.3 | Password hashing behaviour | Required by argon2_elixir. Provides swappable backend interface. |
| plug_crypto | ~> 2.1 | Token signing, HMAC, constant-time compare | Ships with Phoenix. `Plug.Crypto.secure_compare/2`, `KeyGenerator`. |

### Supporting (Optional / Dev / Test)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| hammer | ~> 7.3 | Rate limiting (ETS backend) | Optional dep. Noop fallback when absent. |
| swoosh | ~> 1.5 | Email delivery | Optional dep. Used by generated mailer. |
| oban | ~> 2.17 | Async email delivery, cleanup jobs | Optional dep. Inline fallback when absent. |
| ex_doc | ~> 0.40 | Documentation generation | Dev only. 0.40.x generates llms.txt. |
| credo | ~> 1.7 | Linting | Dev only. Run with --strict. |
| dialyxir | ~> 1.4 | Type checking via Dialyzer | Dev only. PLT cached in _build/. |
| mox | ~> 1.1 | Mock definitions for behaviours in tests | Test only. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| nimble_options | Raw keyword validation | NimbleOptions auto-generates docs and validates nested schemas. No reason to hand-roll. |
| argon2_elixir | bcrypt_elixir | bcrypt acceptable only for migration path, never as default. |
| Plug.Crypto | :crypto directly | Plug.Crypto wraps :crypto with higher-level APIs (sign/verify/encrypt). Ships with Phoenix. |
| Hammer 7.x | ex_rated | Hammer has cleaner API and active maintenance. |

**Installation (mix.exs):**
```elixir
defp deps do
  [
    {:phoenix, "~> 1.8"},
    {:ecto, "~> 3.12"},
    {:ecto_sql, "~> 3.12"},
    {:nimble_options, "~> 1.1"},
    {:argon2_elixir, "~> 4.1"},
    {:comeonin, "~> 5.3"},
    # Optional deps
    {:hammer, "~> 7.3", optional: true},
    {:swoosh, "~> 1.5", optional: true},
    {:oban, "~> 2.17", optional: true},
    # Dev/test
    {:ex_doc, "~> 0.40", only: :dev, runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:mox, "~> 1.1", only: :test}
  ]
end
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
  mix/
    tasks/
      sigra.install.ex              # Generator mix task
  sigra.ex                          # Top-level module (entry point, docs)
  sigra/
    auth.ex                         # Public auth API (verify_password, confirmed?, locked?)
    config.ex                       # Config struct + NimbleOptions schema
    config/
      schema.ex                     # NimbleOptions schema definition (if complex)
    crypto.ex                       # Password hashing, token generation, HMAC
    crypto/
      password_hasher.ex            # Internal: wraps argon2/bcrypt behind behaviour
    error.ex                        # Error structs (defexception) + safe_message/1
    plug.ex                         # Re-exports / docs for all plugs (optional)
    plug/
      fetch_session.ex              # Fetch user from session token
      fetch_bearer.ex               # Fetch user from Authorization header
      require_authenticated.ex      # Gate: must be logged in
      require_sudo.ex               # Gate: must have recent re-auth
      error_handler.ex              # ErrorHandler behaviour definition
    telemetry.ex                    # Event catalog, span/3 helper, attach_default_logger
    testing.ex                      # Test assertion helpers (like Oban.Testing)
    token.ex                        # Public token API (generate, verify)
    token/
      hmac.ex                       # HMAC token internals
    # Behaviours (singular name)
    hasher.ex                       # @behaviour definition + @callback specs
    mailer.ex                       # @behaviour definition
    session_store.ex                # @behaviour definition
    rate_limiter.ex                 # @behaviour definition
    # Default implementations (plural directory)
    hashers/
      argon2.ex                     # Sigra.Hashers.Argon2 (default)
    mailers/
      swoosh.ex                     # Sigra.Mailers.Swoosh (default, optional)
    session_stores/
      ecto.ex                       # Sigra.SessionStores.Ecto (default)
    rate_limiters/
      hammer.ex                     # Sigra.RateLimiters.Hammer (optional)
      noop.ex                       # Sigra.RateLimiters.Noop (fallback)
priv/
  templates/
    sigra.install/
      migration.exs                 # Users + user_tokens migration
      schema.ex                     # User schema template
      user_token_schema.ex          # UserToken schema template
      scope.ex                      # Scope struct template
      auth_context.ex               # MyApp.Auth context module
      user_auth.ex                  # MyAppWeb.UserAuth plug module
      error_handler.ex              # MyAppWeb.AuthErrorHandler
      # LiveView templates (conditional)
      login_live.ex                 # LoginLive
      registration_live.ex          # RegistrationLive
      settings_live.ex              # SettingsLive
      # Controller templates (conditional)
      session_controller.ex         # SessionController
      registration_controller.ex    # RegistrationController
      session_html.ex               # SessionHTML
      # Test templates
      auth_fixtures.ex              # user_fixture/1, extract_user_token/1
      conn_case_helpers.ex          # log_in_user/2
test/
  sigra/
    auth_test.exs
    config_test.exs
    crypto_test.exs
    telemetry_test.exs
    token_test.exs
    plug/
      fetch_session_test.exs
      require_authenticated_test.exs
    hashers/
      argon2_test.exs
    rate_limiters/
      noop_test.exs
  support/
    data_case.ex                    # Ecto sandbox setup for tests
    fixtures/
      user_fixtures.ex
```

### Pattern 1: Hybrid Lib+Generator Boundary

**What:** Security-critical logic in library modules (updated via `mix deps.update`), customizable code generated into host project (owned by developer).

**When to use:** Always -- this is the core architectural pattern.

**Library side (Sigra dep):**
```elixir
defmodule Sigra.Crypto do
  @doc "Hash a password using the configured hasher (default: Argon2id)"
  @doc since: "0.1.0"
  @spec hash_password(String.t(), keyword()) :: String.t()
  def hash_password(password, opts \\ []) do
    hasher = Keyword.get(opts, :hasher, Sigra.Hashers.Argon2)
    hasher.hash_password(password)
  end

  @doc "Verify a password against a hash with constant-time comparison"
  @doc since: "0.1.0"
  @spec verify_password(String.t(), String.t(), keyword()) :: boolean()
  def verify_password(password, hashed_password, opts \\ []) do
    hasher = Keyword.get(opts, :hasher, Sigra.Hashers.Argon2)
    hasher.verify_password(password, hashed_password)
  end

  @doc "Run a dummy hash to prevent timing-based user enumeration"
  @doc since: "0.1.0"
  @spec no_user_verify(keyword()) :: false
  def no_user_verify(opts \\ []) do
    hasher = Keyword.get(opts, :hasher, Sigra.Hashers.Argon2)
    hasher.no_user_verify()
    false
  end
end
```

**Generated side (host app):**
```elixir
# Generated into lib/my_app/accounts/user.ex
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :confirmed_at, :utc_datetime
    field :locked_at, :utc_datetime

    timestamps()
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)

    if hash_password? && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Sigra.Crypto.hash_password(get_change(changeset, :password)))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
```

### Pattern 2: NimbleOptions Config Struct

**What:** Runtime config struct validated at initialization with progressive disclosure.

**When to use:** All Sigra configuration.

```elixir
defmodule Sigra.Config do
  @moduledoc """
  Configuration for Sigra authentication.

  ## Required Options

  #{NimbleOptions.docs(@required_schema)}

  ## All Options

  #{NimbleOptions.docs(@schema)}
  """

  @schema NimbleOptions.new!([
    repo: [
      type: :atom,
      required: true,
      doc: "The Ecto Repo module for database operations."
    ],
    user_schema: [
      type: :atom,
      required: true,
      doc: "The User schema module (e.g., MyApp.Accounts.User)."
    ],
    otp_app: [
      type: :atom,
      doc: "OTP application name. Used to read config from Application env."
    ],
    password: [
      type: :keyword_list,
      default: [],
      doc: "Password hashing configuration.",
      keys: [
        min_length: [type: :pos_integer, default: 12],
        max_length: [type: :pos_integer, default: 72],
        hasher: [type: :atom, default: Sigra.Hashers.Argon2]
      ]
    ],
    session: [
      type: :keyword_list,
      default: [],
      doc: "Session configuration.",
      keys: [
        remember_me_max_age: [type: :pos_integer, default: 14 * 24 * 60 * 60],
        reissue_age: [type: :pos_integer, default: 7 * 24 * 60 * 60],
        store: [type: :atom, default: Sigra.SessionStores.Ecto]
      ]
    ],
    token_ttl: [
      type: :keyword_list,
      default: [],
      doc: "Token time-to-live configuration.",
      keys: [
        confirm: [type: :pos_integer, default: 48 * 60 * 60],
        reset_password: [type: :pos_integer, default: 60 * 60],
        magic_link: [type: :pos_integer, default: 15 * 60]
      ]
    ],
    rate_limiting: [
      type: :keyword_list,
      default: [],
      doc: "Rate limiting configuration.",
      keys: [
        limiter: [type: :atom, default: nil],
        ip_limit: [type: :pos_integer, default: 10],
        ip_window_ms: [type: :pos_integer, default: 60_000],
        account_limit: [type: :pos_integer, default: 5]
      ]
    ],
    mailer: [
      type: :atom,
      default: nil,
      doc: "The mailer module implementing Sigra.Mailer behaviour."
    ]
  ])

  defstruct [
    :repo, :user_schema, :otp_app, :mailer,
    password: [], session: [], token_ttl: [], rate_limiting: []
  ]

  @doc "Create a new config from keyword options, validated by NimbleOptions."
  @spec new!(keyword()) :: t()
  def new!(opts) do
    validated = NimbleOptions.validate!(opts, @schema)
    struct!(__MODULE__, validated)
  end
end
```

### Pattern 3: Behaviour + Default Implementation

**What:** Each extensibility point is a behaviour with callbacks. Default implementation provided. Mox-friendly.

**When to use:** All 4 Phase 1 behaviours.

```elixir
# Behaviour definition (singular)
defmodule Sigra.Hasher do
  @moduledoc "Behaviour for password hashing implementations."

  @callback hash_password(password :: String.t()) :: String.t()
  @callback verify_password(password :: String.t(), hash :: String.t()) :: boolean()
  @callback no_user_verify() :: :ok
end

# Default implementation (plural directory)
defmodule Sigra.Hashers.Argon2 do
  @moduledoc "Argon2id password hashing implementation (OWASP recommended)."
  @behaviour Sigra.Hasher

  @impl true
  def hash_password(password) do
    Argon2.hash_pwd_salt(password)
  end

  @impl true
  def verify_password(password, hashed_password) do
    Argon2.verify_pass(password, hashed_password)
  end

  @impl true
  def no_user_verify do
    Argon2.no_user_verify()
    :ok
  end
end
```

### Pattern 4: Telemetry Event Catalog (Oban Style)

**What:** Single `Sigra.Telemetry` module with complete event catalog, helper functions, and default logger.

```elixir
defmodule Sigra.Telemetry do
  @moduledoc """
  Telemetry integration for Sigra authentication events.

  ## Event Catalog

  ### Authentication
  - `[:sigra, :auth, :login, :start | :stop | :exception]`
  - `[:sigra, :auth, :logout, :start | :stop | :exception]`
  - `[:sigra, :auth, :register, :start | :stop | :exception]`

  ### Token Operations
  - `[:sigra, :token, :generate, :start | :stop | :exception]`
  - `[:sigra, :token, :verify, :start | :stop | :exception]`

  ### Security Signals (one-shot events)
  - `[:sigra, :security, :rate_limited]`
  - `[:sigra, :security, :lockout]`
  - `[:sigra, :security, :invalid_credentials]`

  ## Metadata Policy

  NEVER included: passwords, hashes, TOTP codes, bearer tokens, OAuth secrets.
  ALWAYS included: user_id (not email), boolean outcome, operation context.
  """

  @doc "Execute a telemetry span for a synchronous operation."
  @spec span(event_prefix :: [atom()], metadata :: map(), (-> result)) :: result
        when result: term()
  def span(event_prefix, metadata, fun) do
    :telemetry.span(event_prefix, metadata, fn ->
      result = fun.()
      {result, metadata}
    end)
  end

  @doc "Emit a one-shot telemetry event (security signals, etc.)."
  @spec event(event_name :: [atom()], measurements :: map(), metadata :: map()) :: :ok
  def event(event_name, measurements \\ %{}, metadata \\ %{}) do
    :telemetry.execute(event_name, measurements, metadata)
  end

  @doc "Attach a default structured logger for all Sigra events."
  @spec attach_default_logger(keyword()) :: :ok | {:error, :already_exists}
  def attach_default_logger(opts \\ []) do
    events = [
      [:sigra, :auth, :login, :stop],
      [:sigra, :auth, :logout, :stop],
      [:sigra, :auth, :register, :stop],
      [:sigra, :token, :verify, :stop],
      [:sigra, :security, :rate_limited],
      [:sigra, :security, :lockout],
      [:sigra, :security, :invalid_credentials]
    ]

    :telemetry.attach_many(
      "sigra-default-logger",
      events,
      &__MODULE__.handle_event/4,
      opts
    )
  end

  @doc false
  def handle_event(event, measurements, metadata, opts) do
    level = Keyword.get(opts, :level, :info)
    Logger.log(level, fn -> format_event(event, measurements, metadata) end)
  end
end
```

### Pattern 5: Generator Mix Task (phx.gen.auth style)

**What:** Mix task that accepts `mix sigra.install Accounts User users` and generates files.

```elixir
defmodule Mix.Tasks.Sigra.Install do
  @shortdoc "Generates Sigra authentication scaffold"
  @moduledoc """
  Generates authentication modules into your Phoenix application.

      $ mix sigra.install Accounts User users

  The first argument is the context module, the second is the schema
  module, and the third is the table name.

  ## Options

    * `--live` - Generate LiveView components (default)
    * `--no-live` - Generate controller-only components
    * `--binary-id` - Use binary IDs for schemas and migrations
    * `--table` - Override the table name prefix

  ## Generated Files

  This generator creates the following files in your application:
  (list)
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # 1. Parse and validate args
    # 2. Detect host app settings (otp_app, repo, adapter)
    # 3. Generate files from EEx templates
    # 4. Inject into router.ex, config.exs, test configs
    # 5. Print post-install instructions
  end
end
```

### Pattern 6: Injector Module (idempotent code injection)

**What:** Separate module handling code injection into existing files with `String.contains?` idempotency.

```elixir
defmodule Sigra.Install.Injector do
  @doc "Inject auth pipeline into router.ex"
  def inject_router_plugs(file_contents, plug_code) do
    if String.contains?(file_contents, "Sigra") do
      {:already_injected, file_contents}
    else
      # Find anchor line, inject before it
      {:ok, injected_contents}
    end
  end
end
```

### Anti-Patterns to Avoid

- **Macro-based schema injection (`use Sigra.Schema`):** Hides fields from developer. Fights "own your code." Use generated plain Ecto schemas instead.
- **Application.get_env as primary config:** Global mutable config. Cannot run multiple configs. Use struct-based config passed explicitly.
- **`xref: exclude` for optional deps:** Use `Code.ensure_loaded?/1` wrapping entire module definitions instead.
- **Tesla middleware macros:** Creates compile-time deps. Not needed since Assent handles OAuth HTTP.
- **JWT for session state:** Database-backed tokens are the correct default for browser auth.
- **Bare nil returns:** Always use `{:ok, result}` | `{:error, reason}` tuples.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom Argon2 wrapper | argon2_elixir + comeonin | NIF-backed, OWASP-tuned defaults, timing-safe |
| Token signing/verification | Custom HMAC | Plug.Crypto.sign/verify | Battle-tested, handles expiry, serialization |
| Constant-time comparison | `==` operator | Plug.Crypto.secure_compare/2 | Prevents timing attacks on token comparison |
| Key derivation | Raw :crypto calls | Plug.Crypto.KeyGenerator | PBKDF2 with proper salt handling |
| Config validation | Manual keyword checks | NimbleOptions | Auto-generates docs, validates nested schemas, type checking |
| Option documentation | Hand-written docs | NimbleOptions.docs/1 | Generates formatted docs from schema definition |
| Telemetry spans | Manual start/stop timing | :telemetry.span/3 | Handles exceptions, monotonic time, proper measurement structure |

**Key insight:** Phase 1 is foundation -- use proven libraries for infrastructure so later phases can focus on domain logic. Hand-rolling config validation or token signing would create maintenance burden without adding value.

## Common Pitfalls

### Pitfall 1: Generator Template Path Resolution
**What goes wrong:** Templates not found when library is installed as a dep (vs running from source).
**Why it happens:** `priv/` path resolution differs between deps and local development.
**How to avoid:** Use `Application.app_dir(:sigra, "priv/templates/sigra.install")` for absolute path resolution. Test with both `mix deps.get` install and local path dependency.
**Warning signs:** `** (File.Error) could not read file` errors when running generator from a dep.

### Pitfall 2: Mix.Phoenix Dependency at Compile Time
**What goes wrong:** `Mix.Phoenix` functions unavailable outside Mix environment (production, releases).
**Why it happens:** Mix modules are only available during compilation and development.
**How to avoid:** Only call `Mix.Phoenix.*` inside Mix task modules (`lib/mix/tasks/`). Never reference Mix modules from library runtime code (`lib/sigra/`).
**Warning signs:** `(UndefinedFunctionError) function Mix.Phoenix.otp_app/0 is undefined` in production.

### Pitfall 3: Optional Dependency Module Loading
**What goes wrong:** Compile warnings or runtime errors when optional deps are absent.
**Why it happens:** `Code.ensure_loaded?/1` must wrap the ENTIRE module that references the optional dep, not just the call site.
**How to avoid:** Wrap entire modules that reference optional deps:
```elixir
if Code.ensure_loaded?(Hammer) do
  defmodule Sigra.RateLimiters.Hammer do
    @behaviour Sigra.RateLimiter
    # ... uses Hammer functions
  end
end
```
**Warning signs:** Compiler warnings about undefined modules. `mix compile --no-optional-deps --warnings-as-errors` fails.

### Pitfall 4: Multi-Database Migration DDL
**What goes wrong:** Migrations fail on MySQL/SQLite because of PostgreSQL-specific DDL (citext extension, JSONB).
**Why it happens:** Generator emits PostgreSQL DDL by default without adapter detection.
**How to avoid:** Detect adapter via `repo.__adapter__()` in generator and emit conditional DDL:
- PostgreSQL: `execute "CREATE EXTENSION IF NOT EXISTS citext"`, field type `:citext`
- SQLite: field type `:string` with `collate: :nocase`
- MySQL: field type `:string` with `size: 160`
**Warning signs:** Migration errors on non-PostgreSQL databases.

### Pitfall 5: NimbleOptions Struct vs Keyword List Confusion
**What goes wrong:** Config struct fields are keyword lists but code treats them as structs or maps.
**Why it happens:** NimbleOptions validates keyword lists, but `struct!` creates a struct with keyword list values for nested sections.
**How to avoid:** Access nested config consistently: `config.password[:min_length]` (keyword access) vs `config.repo` (struct field access). Consider converting nested keyword lists to structs in `new!/1`.
**Warning signs:** `KeyError` or pattern match failures on config values.

### Pitfall 6: Idempotent Injection Race Condition
**What goes wrong:** Running `mix sigra.install` twice injects duplicate code.
**Why it happens:** `String.contains?` check uses wrong anchor string, or code changes between runs.
**How to avoid:** Use a unique, stable marker comment (e.g., `# Sigra authentication`) in injected code. Check for the marker, not the full code block.
**Warning signs:** Duplicate route blocks, duplicate config entries after re-running generator.

### Pitfall 7: Telemetry Metadata Leaking Sensitive Data
**What goes wrong:** Passwords, tokens, or email addresses appear in telemetry events / logs.
**Why it happens:** Passing full request params or user structs as metadata without filtering.
**How to avoid:** Whitelist metadata fields explicitly. Only include `user_id`, boolean `success`, and operation `context`. Never pass raw params or full user structs.
**Warning signs:** Secrets appearing in structured logs or monitoring dashboards.

### Pitfall 8: OTP 28 Compatibility
**What goes wrong:** CI targets OTP 27 but local dev uses OTP 28. Subtle behavior differences.
**Why it happens:** Local machine has OTP 28 (current install), but CLAUDE.md specifies OTP 27+ minimum.
**How to avoid:** Test CI matrix includes both OTP 27 and OTP 28. Use `otp_release: "27"` and `"28"` in GitHub Actions matrix. Document minimum as OTP 27.
**Warning signs:** Tests pass locally but fail in CI, or vice versa.

## Code Examples

### Token Generation and Verification (Plug.Crypto)

```elixir
# Source: https://hexdocs.pm/plug_crypto/Plug.Crypto.html
defmodule Sigra.Token do
  @doc "Generate a signed token for a given purpose."
  @spec generate(Plug.Conn.t() | String.t(), String.t(), term(), keyword()) :: String.t()
  def generate(secret_key_base, purpose, data, opts \\ []) do
    Plug.Crypto.sign(secret_key_base, purpose, data, opts)
  end

  @doc "Verify a signed token."
  @spec verify(Plug.Conn.t() | String.t(), String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, :expired | :invalid}
  def verify(secret_key_base, purpose, token, opts \\ []) do
    case Plug.Crypto.verify(secret_key_base, purpose, token, opts) do
      {:ok, data} -> {:ok, data}
      {:error, _} = error -> error
    end
  end

  @doc "Generate a random token and return {raw, hashed} pair."
  @spec generate_hashed_token() :: {String.t(), binary()}
  def generate_hashed_token do
    raw = :crypto.strong_rand_bytes(32)
    hashed = :crypto.hash(:sha256, raw)
    {Base.url_encode64(raw, padding: false), hashed}
  end
end
```

### Phoenix 1.8 Scope Struct (Generated Template)

```elixir
# Source: https://hexdocs.pm/phoenix/scopes.html
# Generated into lib/my_app/accounts/scope.ex
defmodule <%= inspect context.module %>.Scope do
  @moduledoc """
  Defines the scope for authenticated requests.
  """
  alias <%= inspect context.module %>.<%= inspect schema.alias %>

  defstruct user: nil

  @type t :: %__MODULE__{user: %<%= inspect schema.alias %>{} | nil}

  def for_user(%<%= inspect schema.alias %>{} = user), do: %__MODULE__{user: user}
  def for_user(nil), do: nil
end
```

### Library Plug (Security-Critical, Lives in Library)

```elixir
# Source: phx.gen.auth pattern adapted for library
defmodule Sigra.Plug.RequireAuthenticated do
  @moduledoc "Halts the connection if no authenticated user is present."
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      error_handler = Keyword.fetch!(opts, :error_handler)
      conn
      |> error_handler.auth_error(:unauthenticated, opts)
      |> halt()
    end
  end
end
```

### Error Handler Behaviour

```elixir
defmodule Sigra.Plug.ErrorHandler do
  @moduledoc "Behaviour for handling authentication errors in plugs."

  @type error_type :: :unauthenticated | :stale_sudo | :rate_limited
  @callback auth_error(Plug.Conn.t(), error_type(), keyword()) :: Plug.Conn.t()
end
```

### Error Struct Pattern (Assent-inspired)

```elixir
defmodule Sigra.Error do
  @moduledoc "Error types for Sigra authentication operations."

  defmodule TokenExpired do
    defexception [:message, :context, :token_type]

    @impl true
    def message(%{token_type: type}) do
      "#{type} token has expired"
    end
  end

  defmodule RateLimited do
    defexception [:message, :retry_after_ms]

    @impl true
    def message(%{retry_after_ms: ms}) do
      "Rate limited. Retry after #{div(ms, 1000)} seconds."
    end
  end

  @doc "Map internal error to user-safe message (enumeration prevention)."
  @spec safe_message(atom() | Exception.t()) :: String.t()
  def safe_message(:invalid_credentials), do: "Invalid email or password."
  def safe_message(:token_expired), do: "This link has expired. Please request a new one."
  def safe_message(%RateLimited{}), do: "Too many attempts. Please try again later."
  def safe_message(_), do: "Something went wrong. Please try again."
end
```

### Mox-Friendly Behaviour Testing

```elixir
# In test/support/mocks.ex (generated)
Mox.defmock(Sigra.MockHasher, for: Sigra.Hasher)
Mox.defmock(Sigra.MockMailer, for: Sigra.Mailer)
Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)
Mox.defmock(Sigra.MockRateLimiter, for: Sigra.RateLimiter)

# In test
test "verify_password delegates to configured hasher" do
  Sigra.MockHasher
  |> expect(:verify_password, fn "secret", "$argon2id$..." -> true end)

  assert Sigra.Crypto.verify_password("secret", "$argon2id$...", hasher: Sigra.MockHasher)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` | `Repo.transact/2` | Ecto 3.13 (2025) | Cleaner API, non-deprecated |
| Jason dependency | Built-in `JSON` module | Elixir 1.18 (2024) | One fewer dep for libraries targeting 1.18+ |
| phx.gen.auth current_user | Scope struct / current_scope | Phoenix 1.8 (Aug 2025) | First-class scoped data access pattern |
| Hammer 6.x API | Hammer 7.x API | 2026 | Complete API rewrite, different function signatures |
| Pow for Phoenix auth | Dead on Phoenix 1.8+ | Phoenix 1.8 (Aug 2025) | Sigra fills this gap |

**Deprecated/outdated:**
- `Repo.transaction/2`: Use `Repo.transact/2` (Ecto 3.13+)
- Hammer 6.x API patterns: 7.x is a breaking rewrite
- `current_user` assign: Phoenix 1.8 uses `current_scope` pattern

## Open Questions

1. **Argon2id Cost Parameters**
   - What we know: OWASP recommends 200-500ms hash time. argon2_elixir defaults may need tuning.
   - What's unclear: Exact t_cost/m_cost values for 200-500ms on modern hardware.
   - Recommendation: Use argon2_elixir defaults, benchmark in CI, document how to tune. Claude's discretion per CONTEXT.md.

2. **EEx Template Granularity**
   - What we know: Templates go in `priv/templates/sigra.install/`. User can override in their project's `priv/templates/`.
   - What's unclear: Exact file count and naming within the template directory. Whether LiveView templates should be in a subdirectory.
   - Recommendation: Follow phx.gen.auth flat structure within the directory. Claude's discretion per CONTEXT.md.

3. **Config Initialization Lifecycle**
   - What we know: Config struct validated by NimbleOptions. Passed explicitly. `otp_app` as convenience.
   - What's unclear: When exactly config is initialized (application start? first call? each plug call?).
   - Recommendation: Lazy initialization on first use with memoization via persistent_term or process dictionary. App env read once, validated, cached.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Core | Yes | 1.19.5 | -- |
| Erlang/OTP | Core | Yes | 28 | -- (27+ supported) |
| PostgreSQL | Integration tests | Yes | accepting connections | -- |
| Mix | Generator, compilation | Yes | 1.19.5 | -- |
| gcc/clang | argon2_elixir NIF compilation | Yes | (macOS default) | Precompiled NIF |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

Note: OTP 28 is installed locally, which exceeds the minimum requirement of OTP 27. CI matrix should test both OTP 27 and OTP 28.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` (Wave 0 -- to be created) |
| Quick run command | `mix test --no-start` |
| Full suite command | `mix test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | mix sigra.install generates all expected files | integration | `mix test test/mix/tasks/sigra.install_test.exs -x` | Wave 0 |
| FOUND-02 | Generated code follows Phoenix context pattern | integration | `mix test test/mix/tasks/sigra.install_test.exs -x` | Wave 0 |
| FOUND-03 | Security functions live in library, not generated code | unit | `mix test test/sigra/crypto_test.exs test/sigra/token_test.exs -x` | Wave 0 |
| FOUND-04 | No macro injection -- schemas are plain Ecto | integration | `mix test test/mix/tasks/sigra.install_test.exs -x` (verify generated file content) | Wave 0 |
| FOUND-05 | Config validates with NimbleOptions, defaults work | unit | `mix test test/sigra/config_test.exs -x` | Wave 0 |
| FOUND-06 | 4 behaviours defined with callbacks | unit | `mix test test/sigra/hasher_test.exs test/sigra/mailer_test.exs test/sigra/session_store_test.exs test/sigra/rate_limiter_test.exs -x` | Wave 0 |
| FOUND-07 | Telemetry events emitted for operations | unit | `mix test test/sigra/telemetry_test.exs -x` | Wave 0 |
| FOUND-08 | Plugs work without LiveView | unit | `mix test test/sigra/plug/ -x` | Wave 0 |
| FOUND-09 | LiveView templates generated with --live flag | integration | `mix test test/mix/tasks/sigra.install_test.exs -x` | Wave 0 |
| FOUND-10 | Library modules have zero UI dependencies | unit | `mix compile --no-optional-deps --warnings-as-errors` | Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test --no-start` (fast unit tests)
- **Per wave merge:** `mix test` (full suite including integration)
- **Phase gate:** Full suite green + `mix credo --strict` + `mix dialyzer` before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/test_helper.exs` -- ExUnit.start() + Ecto sandbox setup
- [ ] `test/support/data_case.ex` -- Ecto sandbox checkout for DB tests
- [ ] `mix.exs` -- project definition with deps
- [ ] `.formatter.exs` -- code formatter config
- [ ] `.credo.exs` -- Credo config with strict defaults
- [ ] `config/config.exs` + `config/test.exs` -- basic config
- [ ] PostgreSQL test database setup (`mix ecto.create`, `mix ecto.migrate`)

## Sources

### Primary (HIGH confidence)
- [Phoenix 1.8.5 phx.gen.auth source](https://github.com/phoenixframework/phoenix/blob/v1.8.5/lib/mix/tasks/phx.gen.auth.ex) -- generator patterns, argument handling, template discovery
- [Phoenix 1.8.5 Injector source](https://github.com/phoenixframework/phoenix/blob/v1.8.5/lib/mix/tasks/phx.gen.auth/injector.ex) -- code injection, idempotency, router/config injection
- [Phoenix 1.8 Scopes guide](https://hexdocs.pm/phoenix/scopes.html) -- Scope struct, current_scope, for_user/1, context filtering
- [NimbleOptions 1.1.1 docs](https://hexdocs.pm/nimble_options/NimbleOptions.html) -- nested schemas, custom validation, docs generation
- [Plug.Crypto 2.1.1 docs](https://hexdocs.pm/plug_crypto/Plug.Crypto.html) -- sign/verify, secure_compare, KeyGenerator
- [Oban.Telemetry docs](https://hexdocs.pm/oban/Oban.Telemetry.html) -- event catalog pattern, attach_default_logger
- [Oban.Testing docs](https://hexdocs.pm/oban/Oban.Testing.html) -- testing helper module pattern
- [:telemetry docs](https://hexdocs.pm/telemetry/readme.html) -- span/3, execute/3, event naming
- [Elixir Library Guidelines](https://hexdocs.pm/elixir/main/library-guidelines.html) -- optional deps, version constraints
- [Ecto SQL Sandbox docs](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html) -- test isolation

### Secondary (MEDIUM confidence)
- Hex.pm version verification via `mix hex.info` -- confirmed current versions for nimble_options, argon2_elixir, phoenix

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all versions verified against hex.pm, all libs well-known in Elixir ecosystem
- Architecture: HIGH -- patterns directly from Phoenix 1.8 source code and Oban source code
- Pitfalls: HIGH -- derived from real generator patterns and documented Elixir library issues

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable ecosystem, no major releases expected)
