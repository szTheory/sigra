# Phase 1: Foundation - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish hybrid lib+generator architecture, data layer, config, telemetry skeleton, and install generator scaffold. A developer can run `mix sigra.install` to get a working project scaffold with plain Ecto schemas calling library functions.

</domain>

<decisions>
## Implementation Decisions

### Project Structure
- **D-01:** Feature-grouped flat modules. Top-level modules per concern: `Sigra.Auth`, `Sigra.Token`, `Sigra.Crypto`, `Sigra.Config`, `Sigra.Telemetry`. Max 3 levels of nesting. Follows Ecto/Phoenix/Oban convention.
- **D-02:** `concept.ex` + `concept/` convention throughout — public module at root, internals in subdirectory.
- **D-03:** Singular behaviour name, plural implementations directory (`Sigra.Mailer` -> `Sigra.Mailers.Swoosh`).
- **D-04:** Mix tasks in `lib/mix/tasks/`. Testing helpers in `lib/sigra/testing.ex`. Errors colocated or in single `error.ex`.

### Configuration Approach
- **D-05:** Config struct validated by NimbleOptions at initialization. `Sigra.Config` struct passed explicitly through the system. Progressive disclosure — only `repo` and `user_schema` required, everything else has OWASP-grade defaults.
- **D-06:** Config grouped by feature domain — `password:`, `session:`, `token_ttl:`, `rate_limiting:` as nested NimbleOptions sections.
- **D-07:** `otp_app` as optional convenience layer for `config.exs` usage. Primary mechanism is explicit argument passing. Runtime-first — no compile-time config.

### Generator Scope
- **D-08:** Core-only install in Phase 1 (`mix sigra.install Accounts User users`). Generates migrations, schemas, context module, plugs, optional LiveView pages. Later phases add incremental generators (`mix sigra.gen.oauth`, `mix sigra.gen.mfa`, `mix sigra.gen.api_tokens`).
- **D-09:** EEx templates in `priv/templates/sigra.install/` following Phoenix conventions. Host project's `priv/templates/` checked first for user overrides.
- **D-10:** String-based injection for router/config (phx.gen.auth `Injector` pattern). Idempotency via `String.contains?` before every injection. Graceful failure with manual instructions when injection fails.
- **D-11:** Host app detection via `Mix.Phoenix` functions — `otp_app()`, `base()`, `context_app()`. Ecto adapter detected at runtime via `repo.__adapter__()` for database-specific migration generation.

### Behaviour Design
- **D-12:** 4 behaviours in Phase 1: `Sigra.Hasher` (3 callbacks: hash_password, verify_password, no_user_verify), `Sigra.Mailer` (1 callback: deliver), `Sigra.SessionStore` (3 callbacks: fetch, create, delete), `Sigra.RateLimiter` (1 callback: check_rate).
- **D-13:** Each behaviour has a default implementation and is Mox-friendly. `Sigra.Hashers.Argon2`, `Sigra.Mailers.Swoosh`, `Sigra.SessionStores.Ecto`, `Sigra.RateLimiters.Hammer` (with `Sigra.RateLimiters.Noop` fallback).
- **D-14:** TokenGenerator and AuditLogger behaviours deferred to Phases 7 and 9 respectively. TOTP/WebAuthn crypto is NOT a behaviour (security-critical, not swappable). OAuth strategies use Assent's existing behaviour. User loader is MFA config, not a behaviour.

### Telemetry Design
- **D-15:** Dedicated `Sigra.Telemetry` module with helper functions (`span/3`, `event/3`) and full event catalog in `@moduledoc`. Event naming: `[:sigra, :subsystem, :operation, :start | :stop | :exception]`.
- **D-16:** `attach_default_logger/1` for instant structured logging (Oban pattern). Filterable by category (`:auth`, `:session`, `:token`, `:security`).
- **D-17:** Sensitive data policy: NEVER include passwords, hashes, TOTP codes, bearer tokens, or OAuth secrets in telemetry metadata. User IDs (not emails) and boolean outcomes only.
- **D-18:** `:telemetry.span/3` for synchronous operations (password verification, token verification). Manual start/stop for multi-step flows. One-shot events for security signals (rate limit hits, lockouts).

### Error Handling Pattern
- **D-19:** Always `{:ok, result}` | `{:error, reason}` — never bare `nil` (Pow's mistake). Changesets for form validation (registration, password change). Atom-tagged errors for domain failures (`:invalid_credentials`, `:token_expired`). Error structs with `defexception` for rich context (`Sigra.Error.TokenExpired`, `Sigra.Error.RateLimited`).
- **D-20:** Rate limiting returns domain-specific tuples: `{:allow, count}` | `{:deny, retry_after_ms}` (Hammer convention).
- **D-21:** `Sigra.Error.safe_message/1` helper maps internal errors to enumeration-safe user-facing strings. Security boundary: internal API has precise errors, external surface merges them.
- **D-22:** Multi-step composition via `with` chains with tagged tuples. Bang variants only where failure is unexpected (seeds, tests, pipelines).

### Schema Design
- **D-23:** `users` table: id, email (citext/collate), hashed_password (nullable for OAuth-only), confirmed_at, locked_at, timestamps. `user_tokens` table: id, user_id, token (binary, HMAC-hashed for email tokens), context, sent_to, authenticated_at, inserted_at (no updated_at).
- **D-24:** Indexes: unique on `users.email`, unique on `user_tokens[:context, :token]`, index on `user_tokens.user_id`. Expiry computed from `inserted_at + duration` (no `expires_at` column).
- **D-25:** Scope struct is runtime-only (no table). `MyApp.Auth.Scope` wraps `user.id`, carried on `conn.assigns.current_scope`. Compatible with Phoenix 1.8's scope system.
- **D-26:** Binary ID support via `--binary-id` flag. Timestamps use `inserted_at/updated_at` (Ecto default). Multi-database DDL: citext for Postgres, `collate: :nocase` for SQLite, `size: 160` for MySQL.
- **D-27:** Feature tables added by later phase generators: user_identities (Phase 5), user_totp (Phase 6), api_keys (Phase 7), audit_events (Phase 9).

### Plug Architecture
- **D-28:** Security-critical plugs in library: `Sigra.Plug.FetchSession`, `Sigra.Plug.FetchBearer`, `Sigra.Plug.RequireAuthenticated`, `Sigra.Plug.RequireSudo`. Each is a proper `@behaviour Plug` module.
- **D-29:** Generated `MyAppWeb.UserAuth` delegates to library plugs for security logic, handles app-specific concerns (redirects, flash messages, LiveView `on_mount` hooks, Scope construction).
- **D-30:** `Sigra.Plug.ErrorHandler` behaviour with `@callback auth_error(conn, type, opts)`. Types: `:unauthenticated`, `:stale_sudo`, `:rate_limited`. Generator produces a default implementation.
- **D-31:** Phoenix 1.8 Scope pattern: `conn.assigns.current_scope`. Dual-mode support: browser pipeline uses `FetchSession`, API pipeline uses `FetchBearer`. Both produce the same `current_scope` shape.

### Testing Architecture
- **D-32:** Library ships `Sigra.Testing` module (like Oban.Testing) with assertion helpers: `assert_session_created/1`, `assert_token_sent/2`, `assert_account_locked/1`, `with_test_mailer/1`.
- **D-33:** Generator creates app-specific fixtures (`user_fixture/1`, `extract_user_token/1`) and ConnCase helpers (`log_in_user/2`, `register_and_log_in_user/1`). Injects `config :argon2_elixir, t_cost: 1, m_cost: 8` into `config/test.exs`.
- **D-34:** All 4 behaviours are Mox-friendly. Documentation shows `Mox.defmock` examples for each.

### Optional Dependency Handling
- **D-35:** Compile-time detection via `Code.ensure_loaded?/1` wrapping entire modules (Tesla pattern). No `xref: exclude` needed.
- **D-36:** Oban absent: email sends inline (synchronous). Hammer absent: no-op rate limiter with logged warning (fail open). Warning logged once at startup, not per-request.
- **D-37:** Auto-detect with explicit config override. Recompile note in docs: "After adding `:oban` or `:hammer`, run `mix deps.clean sigra && mix deps.compile sigra`."

### Documentation Strategy
- **D-38:** Guide-first docs (Oban style). Primary API modules (`Sigra`, `Sigra.Auth`, `Sigra.Token`, `Sigra.Config`) ungrouped (appear first). Feature modules grouped by concern.
- **D-39:** llms.txt enabled via default formatters. Security documentation in its own guide section. Cheatsheets for config and routes.
- **D-40:** `@doc since: "1.0.0"` on all public functions. `{: .warning}` admonitions for security notes. Thorough `@spec` annotations for free type checking on Elixir 1.18+.

### CI/CD and Quality
- **D-41:** Multi-job GitHub Actions: unit tests (Elixir 1.18 + 1.19 matrix), Postgres integration, MySQL integration, SQLite integration. Lint/dialyzer/credo gated to latest version only.
- **D-42:** PLT cached in `_build/` (Oban pattern). Actions pinned to commit SHA. `fail-fast: false`. Concurrency control cancels superseded PR runs. Credo strict with `AliasUsage: false`.

### API Naming Conventions
- **D-43:** Follow phx.gen.auth naming exactly: `register_user` (not `create_user`), `log_in_user`/`log_out_user` (two words), `generate_*` for producing values, `verify_*` for crypto checks, `validate_*` for changeset validations, `deliver_*` for email, `?`-predicates for boolean checks.
- **D-44:** Library functions follow same conventions: `Sigra.Auth.verify_password/2`, `Sigra.Token.generate/2`, `Sigra.Token.verify/2`, `Sigra.Auth.confirmed?/1`, `Sigra.Auth.locked?/1`.
- **D-45:** Option keys always atoms, flat by default, positive booleans (`hash_password: true` not `skip_hash: false`). Nested only for subsystem delegation.

### Hex Publishing
- **D-46:** Start at v0.1.0 (API stabilizing). SemVer strict. MIT license. CHANGELOG.md with `[Module]` prefix convention (Ecto style). Explicit `files` allowlist in package config.
- **D-47:** `source_ref: "v#{@version}"` for correct HexDocs source links. `.formatter.exs` exported for `import_deps: [:sigra]`.

### Security Defaults
- **D-48:** Derive all keys from host app's `secret_key_base` via `Plug.Crypto.KeyGenerator` with per-purpose salts (`"sigra-session-token"`, `"sigra-email-token"`, etc.). No separate Sigra secret.
- **D-49:** Two token strategies: session tokens stored raw (signed transport via cookies), email/API tokens SHA-256 hashed before storage (plaintext transport). Constant-time comparison everywhere via `Plug.Crypto.secure_compare/2`.
- **D-50:** Locked-down defaults: Argon2id hashing, 12-char min password, remember-me cookie (signed, HttpOnly, SameSite=Lax, Secure in prod, 14-day max_age), session renewal on login (CSRF fixation prevention), all sessions invalidated on password change.

### Version Compatibility
- **D-51:** Target `elixir: "~> 1.18"`, `phoenix: "~> 1.8"`, `ecto: "~> 3.12"`, `ecto_sql: "~> 3.12"`. OTP 27+ (required by Phoenix 1.8).
- **D-52:** Use built-in `JSON` module for internal library needs (no Jason dep). Use `Phoenix.json_library()` for Phoenix integration points. Thorough `@spec` annotations for consumer type checking.
- **D-53:** Generator produces Phoenix 1.8-compatible Scope module. Magic links as first-class feature (matching Phoenix 1.8's passwordless-first philosophy). Parameterized tests for multi-backend testing.

### Claude's Discretion
- Exact Argon2id time/memory cost parameters (within OWASP range)
- Loading skeleton and progress indicator design in generated LiveView pages
- Internal module organization within `Sigra.Crypto` (single module vs submodules)
- Exact EEx template structure within `priv/templates/`
- Specific Credo rules beyond the established baseline
- Default telemetry log format and filtering implementation

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specifications
- `.planning/PROJECT.md` — Vision, architecture philosophy, hybrid lib+generator rationale, key decisions, target personas
- `.planning/REQUIREMENTS.md` — FOUND-01 through FOUND-10 requirements with acceptance criteria
- `.planning/ROADMAP.md` §Phase 1 — Success criteria, dependency chain, requirement mapping

### Research documents
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — Comprehensive ecosystem analysis, prior art comparison, architecture decisions
- `prompts/elixir-best-practices-deep-research.md` — Library architecture patterns
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — OSS library best practices
- `prompts/ecto-best-practices-deep-research.md` — Ecto auth patterns
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — CI/CD stack recommendations

### Stack reference
- `CLAUDE.md` §Technology Stack — Complete dependency list with versions, version compatibility matrix, stack patterns by feature area, alternatives considered, what NOT to use

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No existing code — greenfield project. Only `CLAUDE.md` and `prompts/` directory exist.

### Established Patterns
- No code patterns established yet. Phase 1 establishes all conventions for subsequent phases.

### Integration Points
- Host app's `secret_key_base` — all Sigra key derivation flows from this
- Host app's Ecto Repo — detected at generator runtime via `repo.__adapter__()`
- Host app's router — Sigra injects auth routes and pipeline plugs
- Host app's `config.exs` — Sigra config block injected by generator
- Host app's `test/support/conn_case.ex` — auth test helpers injected

</code_context>

<specifics>
## Specific Ideas

- Generated code should feel native to Phoenix 1.8 — as if phx.gen.auth produced it but with library-backed security
- Library API surface should pass the "h Module in IEx" test — running `h Sigra.Auth` should explain everything needed
- Oban's `attach_default_logger` pattern is specifically called out as a DX goal for telemetry
- Ecto.Changeset / phx.gen.auth's changeset patterns are the explicit model for form-related error returns
- Assent's error struct pattern (exception structs returned in `{:error, struct}` tuples, not raised) is the model for rich error context

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-05*
