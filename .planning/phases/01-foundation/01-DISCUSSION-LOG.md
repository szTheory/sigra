# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 01-Foundation
**Areas discussed:** Project structure, Config approach, Generator scope, Behaviour design, Telemetry design, Error handling pattern, Schema design, Plug architecture, Testing architecture, Optional dependency handling, Documentation strategy, CI/CD and quality, API naming conventions, Hex publishing, Security defaults, Version compatibility

---

## Project Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Feature-grouped flat | Top-level modules per concern, max 3 levels, Ecto/Phoenix/Oban pattern | ✓ |
| Rodauth-style per-feature | Self-contained feature directories, deeper nesting | |
| Domain-layered (DDD) | Explicit domain/application/infrastructure layers | |

**User's choice:** Feature-grouped flat
**Notes:** Research showed every major Elixir library uses this pattern. Pow's 5-level nesting was widely criticized.

---

## Config Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Struct + NimbleOptions | Config struct validated at init, passed explicitly, otp_app convenience | ✓ |
| Callback module (Ecto/Guardian style) | use Sigra, otp_app: :my_app with Application env | |
| Hybrid: struct internally, otp_app externally | NimbleOptions inside, generated context resolves from config | |

**User's choice:** Struct + NimbleOptions
**Notes:** Auto-generates docs, catches typos, multi-instance capable. Broadway and Finch use this as primary config mechanism.

---

## Generator Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Core-only, features add later | Phase 1 generates foundation only, later phases add generators | ✓ |
| Full scaffold with stubs | All tables/schemas upfront, features stubbed | |
| Progressive with feature flags | Single install with --features flag | |

**User's choice:** Core-only, features add later
**Notes:** Avoids unused tables. Later phases add incrementally via mix sigra.gen.oauth, mix sigra.gen.mfa, etc.

---

## Behaviour Design

| Option | Description | Selected |
|--------|-------------|----------|
| 4 core behaviours | Hasher, Mailer, SessionStore, RateLimiter. 1-3 callbacks each. | ✓ |
| 6 behaviours upfront | All 6 including TokenGenerator, AuditLogger | |
| 2 behaviours + MFA config for rest | Only Hasher and Mailer as behaviours | |

**User's choice:** 4 core behaviours
**Notes:** Sweet spot matches ecosystem (Plug: 1 behaviour/2 callbacks, Comeonin: 1/3, Swoosh: 1/2). TokenGenerator and AuditLogger added when features are built.

---

## Telemetry Design

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated module + default logger | Sigra.Telemetry with helpers and attach_default_logger/1 | ✓ |
| Inline events, no module | Call :telemetry.execute directly from library modules | |
| Minimal stubs, fill later | Skeleton only, events added as features built | |

**User's choice:** Dedicated module + default logger
**Notes:** Finch + Oban hybrid pattern. Helper functions centralize event prefix. Default logger gives instant observability.

---

## Error Handling Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Tagged tuples + error structs | Always {:ok, result} or {:error, reason}. Changesets for forms, atoms for domain, structs for rich context. | ✓ |
| Ecto-style changesets everywhere | All operations return changesets | |
| Simple atoms only | All errors are atoms, no structs | |

**User's choice:** Tagged tuples + error structs
**Notes:** Never bare nil (Pow's mistake). Sigra.Error.safe_message/1 for enumeration-safe user-facing strings.

---

## Schema Design

| Option | Description | Selected |
|--------|-------------|----------|
| phx.gen.auth-aligned + lockout | Follow Phoenix 1.8 schema, add locked_at, nullable hashed_password | ✓ |
| Better Auth-style identity split | Password on separate credentials table | |
| Rodauth-style per-feature tables | Separate table for each feature | |

**User's choice:** phx.gen.auth-aligned + lockout
**Notes:** Proven pattern, familiar to Phoenix devs. Feature tables added incrementally by later generators.

---

## Plug Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Phoenix 1.8 Scope + composable plugs | Library-side security plugs, generated user_auth.ex delegates, error handler behaviour | ✓ |
| All-in-library (Guardian style) | Pipeline builder macro, user creates pipeline module | |
| Minimal: only session plug | Library provides one plug, everything else generated | |

**User's choice:** Phoenix 1.8 Scope + composable plugs
**Notes:** Follows Phoenix 1.8 Scope pattern. Dual-mode (session + bearer). Error handler behaviour for clean error handling.

---

## Testing Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Library helpers + generated fixtures | Sigra.Testing module + generated ConnCase helpers + Mox-friendly behaviours | ✓ |
| Generated-only (phx.gen.auth style) | No library testing module, all generated | |

**User's choice:** Library helpers + generated fixtures
**Notes:** Both layers. Argon2 test config injected. All 4 behaviours Mox-friendly.

---

## Optional Dependency Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Compile-time detection + graceful fallback | Code.ensure_loaded? wrapping, auto-detect, inline/noop fallbacks | ✓ |
| Runtime-only detection | Always-defined modules with runtime checks, xref exclude | |

**User's choice:** Compile-time detection + graceful fallback
**Notes:** Tesla pattern. No xref exclusions needed. Log warning once at startup.

---

## Documentation Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Guide-first + module groups | Guides as primary navigation, core modules ungrouped, llms.txt enabled | ✓ |
| API-reference-first (Ecto style) | Main module @moduledoc as landing, fewer guides | |

**User's choice:** Guide-first + module groups
**Notes:** Oban/Phoenix pattern. Security docs in own section. Cheatsheets for config/routes.

---

## CI/CD and Quality

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-job with per-DB testing | Separate jobs per database, lint on latest only, PLT in _build | ✓ |
| Single job, all databases | One job runs all DBs in sequence | |

**User's choice:** Multi-job with per-DB testing
**Notes:** ecto_sql pattern. Actions pinned to SHA. Concurrency control for PRs.

---

## API Naming Conventions

| Option | Description | Selected |
|--------|-------------|----------|
| Follow phx.gen.auth conventions | register_user, log_in_user, verify_* for crypto, validate_* for changesets | ✓ |
| Sigra-native naming | Shorter names: authenticate, register, login | |

**User's choice:** Follow phx.gen.auth conventions
**Notes:** Familiarity for Phoenix developers. Exact naming from Phoenix 1.8 templates.

---

## Hex Publishing

| Option | Description | Selected |
|--------|-------------|----------|
| Standard Hex patterns | 0.1.0 start, MIT, CHANGELOG with [Module] prefix, explicit files list | ✓ |
| Apache-2.0 + conservative versioning | Apache license, start at 1.0.0 | |

**User's choice:** Standard Hex patterns
**Notes:** 0.x signals API stabilizing. Move to 1.0.0 when public API is stable with production users.

---

## Security Defaults

| Option | Description | Selected |
|--------|-------------|----------|
| Derive from secret_key_base + locked defaults | Per-purpose salts, OWASP defaults, two token strategies | ✓ |
| Separate Sigra secret | Independent secret from host app | |

**User's choice:** Derive from secret_key_base + locked defaults
**Notes:** Standard Phoenix pattern. Session tokens raw (signed transport), email tokens hashed (plaintext transport).

---

## Version Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| Elixir ~> 1.18, Phoenix ~> 1.8 | Built-in JSON, type checking, parameterized tests | ✓ |
| Broader compat: Elixir ~> 1.15 | Jason dep required, no type checking benefits | |

**User's choice:** Elixir ~> 1.18, Phoenix ~> 1.8
**Notes:** New library, no legacy users. Gets built-in JSON and free type checking for consumers.

---

## Claude's Discretion

- Argon2id parameters, loading skeleton design, internal Crypto organization, EEx template structure, specific Credo rules, telemetry log format

## Deferred Ideas

None — discussion stayed within phase scope.
