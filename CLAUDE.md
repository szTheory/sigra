<!-- GSD:project-start source:PROJECT.md -->
## Project

**Sigra**

Sigra is a comprehensive authentication library for Elixir/Phoenix that fills the critical gap left by Pow's incompatibility with Phoenix 1.8+. It uses a hybrid lib+generator architecture: security-critical code lives in the library (updated via `mix deps.update`), while customizable application code (schemas, routes, LiveViews) is generated into the developer's project. Sigra targets Phoenix/Ecto as the blessed path, with Plug compatibility where it doesn't compromise DX.

**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence, without wiring together 4+ libraries or maintaining security-sensitive code themselves.

### Constraints

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path. Plug compatibility where DX is not compromised.
- **Database:** PostgreSQL as primary (citext, JSONB). MySQL/SQLite support via conditional migrations.
- **Security:** OWASP standards throughout. Argon2id default. All tokens HMAC-protected. Enumeration prevention by default.
- **Dependencies:** Minimal transitive deps. Copy-paste over deps when code is small and stable.
- **LiveView:** Supported but optional. Core works with standard controllers. Login/logout via HTTP POST (not LiveView events).
- **Testing:** Comprehensive spec coverage — happy path, main error cases, boundary conditions. AAA style, flat, self-contained.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Runtime
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Elixir | ~> 1.18 (1.19.5 current stable) | Language | 1.18 adds built-in JSON, type-checking of calls, LSP. 1.19 adds 4x compilation improvements and better function-capture type propagation. Target 1.18+ as minimum; 1.19 as current stable. |
| Erlang/OTP | ~> 27 (27.3.x current) | Runtime | OTP 27 is required by Phoenix 1.8; introduces tprof, improved documentation, and stable BEAM improvements. OTP 27.3.4.8 is current patch as of Feb 2026. |
| Phoenix | ~> 1.8 (1.8.5 current) | Web framework integration | 1.8 released Aug 2025; adds scopes, magic links by default, sudo mode plug, AGENTS.md, dark mode. Required target because Pow explicitly blocks 1.8+, making this the version where the gap exists. |
| Ecto | ~> 3.12 (3.13.5 current) | Database interaction layer | 3.13 adds `:writable` option on fields (`:always`, `:insert`, `:never`), refined `load_in_query: false`, `Repo.transact/2` (replaces deprecated `Repo.transaction/2`). These features are directly useful for auth invariants. |
| Ecto SQL | ~> 3.12 (3.13.x current) | SQL adapter + migrations | Required alongside Ecto for migration DSL, SQL Sandbox test isolation, `citext` support for case-insensitive email. |
### Authentication Core
| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| argon2_elixir | ~> 4.1 (4.1.3 current, Apr 2025) | Argon2id password hashing | OWASP gold-standard password hashing — memory-hard, GPU/ASIC resistant. argon2_elixir wraps the reference C implementation via Comeonin's behaviour interface. Target Argon2id variant (not Argon2i or Argon2d). Comeonin 5.x spec ensures swappable backends. |
| comeonin | ~> 5.3 | Password hashing behaviour specification | Required by argon2_elixir. Provides the `Comeonin.PasswordHashingAlgorithm` behaviour so bcrypt can be accepted for transparent hash migration on login. Do not expose raw Comeonin calls — wrap behind a `Sigra.Crypto.PasswordHasher` module. |
| assent | ~> 0.3 (0.3.1 current, Jun 2025) | OAuth 2.0 / OIDC / social login | Framework-agnostic, 20+ built-in strategies in one package, PKCE support, OIDC-native. Actively maintained by Dan Schultzer. Preferred over Ueberauth because: single package vs N strategy packages, no Plug coupling in core, PKCE out of the box, cleaner token refresh support. |
| nimble_totp | ~> 1.0 (1.0.0 current, Mar 2023) | TOTP primitive (RFC 6238) | Dashbit-maintained, minimal, correct. Provides secret generation, otpauth URI for QR codes, code generation, and time-windowed verification. Does NOT handle backup codes, enrollment lifecycle, or MFA enforcement — all of that lives in Sigra. Given the tiny surface area (4 functions), consider copy-paste into the library to eliminate the transitive dep. Verify before deciding. |
| wax_ | ~> 0.7 (0.7.0 current, May 2025) | WebAuthn / FIDO2 / passkeys | Only maintained WebAuthn RP library for Elixir. Passes all 170 official test suite tests. Handles attestation, assertion, credential storage. Note the package name is `wax_` (not `wax`) due to a name collision. Version 0.7 supports all required attestation formats. |
### Email Delivery
| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| swoosh | ~> 1.5 (1.25.0 current, Apr 2026) | Transactional email | Phoenix default mailer. Adapters for Postmark, Mailgun, SendGrid, SES, SMTP, and development local preview. Pluggable mailer interface means app devs can swap adapters. Actively maintained — 1.25.0 released Apr 2, 2026. The generated mailer modules (confirmation, password reset, suspicious login) call into Swoosh; the library should expose a `Sigra.Mailer` behaviour so host apps can provide their own mailer. |
### Rate Limiting
| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| hammer | ~> 7.3 (7.3.0 current, Mar 2026) | Rate limiting (account + IP) | Built-in ETS backend (no Redis required), atomic backend for high-concurrency, Redis backend available. Version 7.x was a major rewrite with a cleaner API and built-in ETS backend. Supports fixed-window counter and sliding-window strategies. Use for both account-level (N failed attempts before lockout) and IP-level (M requests per minute) rate limiting. |
### Background Jobs
| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| oban | ~> 2.17 (2.21.1 current, Mar 2026) | Background email delivery + token cleanup | Database-backed, fault-tolerant, PostgreSQL/SQLite/MySQL support. Used for: async email delivery (with inline fallback for non-Oban apps), session/token expiry cleanup jobs, suspicious login notifications. Make Oban integration optional — if the host app does not use Oban, email sends inline. Expose Oban workers as optional modules that apps can add to their Oban config. |
### Field Encryption
| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| cloak_ecto | ~> 1.3 (1.3.0 current, Apr 2024) | Transparent Ecto field encryption | AES-256-GCM encryption at rest for OAuth access/refresh tokens, TOTP secrets, WebAuthn credential blobs. Last updated Apr 2024 — active but slow-moving, which is appropriate for a crypto library. Uses Erlang's `:crypto` underneath. If cloak_ecto maintenance becomes a concern, the alternative is Erlang's `:crypto` directly for the handful of encrypted fields. |
### Option Validation
| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| nimble_options | ~> 1.1 (1.1.1 current) | Option schema validation + docs generation | Dashbit-maintained standard for keyword-list option validation in Elixir libraries. Generates doc output from schemas automatically. Use for all public configuration surfaces: install options, per-request options, strategy config. Eliminates the "giant catch-all opts keyword list" anti-pattern. |
### Development and CI Tools
| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| ex_doc | ~> 0.40 (0.40.1, Jan 2026) | Documentation generation | 0.40.x generates `llms.txt` and Markdown output by default — essential for LLM-assisted development ergonomics. Set `warnings_as_errors: true` in docs config. Pin `:source_ref` to release tag so versioned docs link to correct source. |
| credo | ~> 1.7 (1.7.17 current) | Static analysis / linting | De facto Elixir linter. Run `mix credo --strict` on CI. Configure `.credo.exs` to enforce library-specific rules (no `IO.inspect`, no catch-all patterns on known tuples, etc.). |
| dialyxir | ~> 1.4 (1.4.7 current) | Dialyzer wrapper / type checking | Run on CI with PLT caching. Especially valuable for verifying `@callback` implementations and behaviour contracts. Cache PLT keyed on OS + Elixir version + OTP version + `mix.lock`. |
| erlef/setup-beam | v1 (pin to SHA) | GitHub Actions Elixir/OTP setup | Standard CI action for Elixir. Use `version-type: strict` for deterministic builds. Pin to full commit SHA and let Dependabot update. |
## Installation
# mix.exs — Sigra library dependencies
# After adding deps
# Verify compilation without optional deps (library best practice)
# Run CI quality checks
## Alternatives Considered
| Recommended | Alternative | Why Not / When Alternative Makes Sense |
|-------------|-------------|----------------------------------------|
| argon2_elixir | bcrypt_elixir | bcrypt is acceptable for migration support but NOT as the default. argon2id is OWASP's recommendation because it is memory-hard. Keep bcrypt_elixir as an optional dep only for transparent hash migration path. |
| assent | ueberauth | Ueberauth has 50+ community strategies but: (1) each strategy is a separate package with inconsistent maintenance, (2) it is Plug-coupled in its core, (3) no PKCE in most strategies, (4) no native OIDC. Use Ueberauth only if you need a niche provider that Assent does not have and you are willing to own that strategy dep. |
| assent | auth0/okta SDK | External identity provider SDKs — relevant only if targeting enterprise SSO as a future feature. Out of scope for v1. |
| hammer | ex_rated | Hammer 7.x has a cleaner API, built-in ETS backend, and active maintenance. ex_rated is older and less actively maintained. |
| hammer | Plug.Attack | Plug.Attack is Plug-coupled. Hammer works at any layer — context, plug, or LiveView. |
| oban | quantum (cron-based) | Quantum is cron scheduling, not job queuing with retry semantics. Auth emails need delivery guarantees and retry, not periodic scheduling. |
| oban | Exq (Redis-backed) | Adds Redis dependency. Oban uses the existing PostgreSQL database. |
| cloak_ecto | :crypto directly | cloak_ecto is the right level of abstraction for key rotation and multiple cipher support. Use `:crypto` directly only if cloak_ecto maintenance lapse becomes a real problem. |
| wax_ | web_authn_lite | wax_ is more complete (attestation + assertion), passes the official test suite, and has more recent activity. web_authn_lite is lighter but less feature-complete. |
| nimble_options | Spark | Spark (by Ash Framework) is heavier and tailored to DSL frameworks. nimble_options is focused and appropriate for a lib with keyword options. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Pow | Explicitly blocks Phoenix ~> 1.8+ in its dependency constraint. Architecture uses macros to inject schema fields — the opposite of José's "own your code" philosophy. Effectively unmaintained for modern Phoenix. | Sigra itself is the replacement. |
| Ueberauth (as default) | N separate strategy packages with version conflicts, Plug-coupled core, no PKCE, inconsistent maintenance across strategies. | assent ~> 0.3 |
| Guardian | JWT-only, no user management, no registration, no OAuth, no email flows. Low maintenance activity. Appropriate only for stateless API auth in isolation. | For session auth: database-backed sessions. For JWT: roll within Sigra using `:joken` or Erlang's `:public_key` + `:crypto`. |
| Coherence / Phauxth | Dead projects. Zero activity for multiple years. | Sigra |
| phx.gen.auth (as a dep) | It is a code generator, not a library. Generated code does not receive security patches. No OAuth, MFA, API tokens, or rate limiting. | Sigra generates application scaffolding that calls into library functions for all security-sensitive operations. |
| Macro-heavy `use Sigra.Schema` injection | Fights José's "own your code" principle. Hides schema fields. Creates compile-time coupling. Users cannot see what fields exist. | Behaviours + callbacks. Generated schemas that are explicitly visible. |
| Application.get_env as primary config | Global mutable config is an anti-pattern for libraries. Recompilation hazards. Cannot run multiple configs in one VM. | Runtime struct-based config passed explicitly. App env as optional convenience layer only. |
| Tesla (for HTTP in library internals) | Tesla uses middleware macros which create compile-time deps. For a library that does not do its own HTTP (Assent handles OAuth HTTP), this is not relevant. If HTTP is needed elsewhere, prefer Req or Finch directly. | Req ~> 0.5 or Finch |
| NimbleZTA | Zero Trust Authentication for internal apps behind Cloudflare/IAP/Tailscale. Not relevant for public-facing user auth. | Not applicable |
## Stack Patterns by Feature Area
- Use `argon2_elixir` with Argon2id variant, 200-500ms target hash time
- Accept bcrypt hashes for transparent migration: detect `$2b$` prefix, verify with bcrypt, re-hash to Argon2id on successful login
- Wrap behind `Sigra.Crypto` module — never expose `Argon2` or `Bcrypt` directly in public API
- Use Assent's `Assent.Strategy.*` modules directly
- Generate a `UserIdentities` schema into the host app (not in the library)
- Handle the three cases: new user, existing user (email match), existing user (already has this provider)
- Store provider access/refresh tokens encrypted with `cloak_ecto`
- Use `NimbleTOTP` for the cryptographic primitive only
- Build enrollment state machine, backup code generation, enforcement policies, and "trust this browser" in Sigra
- Store TOTP secret encrypted with `cloak_ecto`
- Generate 8-10 backup codes on enrollment: single-use, SHA-256 hashed, store hash not plaintext
- Use `wax_` for the FIDO2 ceremony (registration + authentication)
- Generate a `UserPasskeys` schema for credential storage
- Support both: (1) passkey as primary passwordless factor, (2) passkey as MFA second factor
- Database-backed tokens (not JWTs for session state): token reference in cookie, token data in DB
- `UserTokens` table: `hashed_token`, `context` (session/confirm/reset/magic_link), `inserted_at`, `expires_at`
- Invalidate all session tokens on password change — single `update_all` query
- Hash tokens before storage: `Base.url_encode64(:crypto.strong_rand_bytes(32))`
- Bearer tokens: stored as SHA-256 hash, shown once at creation, human-readable prefix `sigra_sk_`
- JWT: use Erlang's `:crypto` + `:public_key` or `:joken` for stateless API use cases
- Dual-mode auth plug: detect `Authorization: Bearer` header → API key path, else → session path
- Use Hammer with ETS backend (no external dep required)
- Two separate rate limiters: by IP (10 requests/min), by account (5 failed attempts before lockout)
- Make Hammer optional: if not included, Sigra falls back to a no-op rate limiter with a logged warning
- PostgreSQL primary: use `citext` for email columns, JSONB for audit metadata
- MySQL/SQLite: conditional migration generation — detect adapter in generator, emit appropriate DDL
- Never use PostgreSQL-specific features in core library modules; isolate to `Sigra.Adapters.Postgres`
- Security-critical code in library: hashing, TOTP verification, WebAuthn ceremonies, HMAC token signing, rate limit checks
- Generated into host app: `User` schema, `UserIdentity` schema, `UserToken` schema, `Auth` context module, routes, LiveView pages, migrations
- Generated files call library functions: `Sigra.Auth.verify_password/2`, `Sigra.TOTP.verify/2`, `Sigra.Token.generate/1`
## Version Compatibility Matrix
| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Phoenix 1.8.5 | Elixir ~> 1.14, OTP 25+ | Phoenix 1.8 requires OTP 25 minimum. Target 1.8.x as minimum. |
| Ecto 3.13.5 | Elixir ~> 1.11 | `Repo.transact/2` added in 3.13; use instead of deprecated `Repo.transaction/2`. `:writable` field option added in 3.13. |
| argon2_elixir 4.1.3 | comeonin ~> 5.3 | Requires native compilation via `elixir_make`. CI must have `gcc`/`clang` available. Precompiled NIF available via `:argon2_elixir` options. |
| assent 0.3.1 | No Phoenix/Plug hard dep in core | Framework-agnostic. Phoenix integration layer is separate. Compatible with latest Req/Finch for HTTP. |
| wax_ 0.7.0 | OTP 22+ | Requires `:crypto` and `:public_key` from OTP stdlib. No special install steps. |
| hammer 7.3.0 | Elixir ~> 1.13 | 7.x is a breaking change from 6.x; the API changed significantly. Do not use `~> 6.x` patterns. |
| oban 2.21.1 | Ecto 3.x, PostgreSQL/MySQL/SQLite | Use as optional dep. If host app does not use Oban, emails are sent inline in the calling process. |
| nimble_totp 1.0.0 | Elixir ~> 1.12 | Stable since Mar 2023. No planned changes. Suitable for copy-paste if minimizing transitive deps is a priority. |
| cloak_ecto 1.3.0 | Ecto ~> 3.0 | Last updated Apr 2024. Stable and slow-moving (appropriate for crypto). Uses AES-256-GCM. Key rotation supported via `Cloak.Vault`. |
## Sources
- [hex.pm/packages/assent](https://hex.pm/packages/assent) — v0.3.1, Jun 2025 (HIGH confidence, verified)
- [hex.pm/packages/argon2_elixir](https://hex.pm/packages/argon2_elixir) — v4.1.3, Apr 2025 (HIGH confidence, verified)
- [hex.pm/packages/nimble_totp](https://hex.pm/packages/nimble_totp) — v1.0.0, Mar 2023 (HIGH confidence, verified)
- [hex.pm/packages/wax_](https://hex.pm/packages/wax_) — v0.7.0, May 2025 (HIGH confidence, verified)
- [hex.pm/packages/swoosh](https://hex.pm/packages/swoosh) — v1.25.0, Apr 2026 (HIGH confidence, verified)
- [hex.pm/packages/hammer](https://hex.pm/packages/hammer) — v7.3.0, Mar 2026 (HIGH confidence, verified)
- [hex.pm/packages/oban](https://hex.pm/packages/oban) — v2.21.1, Mar 2026 (HIGH confidence, verified)
- [hex.pm/packages/cloak_ecto](https://hex.pm/packages/cloak_ecto) — v1.3.0, Apr 2024 (HIGH confidence, verified; maintenance is slow but stable)
- [hex.pm/packages/nimble_options](https://hex.pm/packages/nimble_options) — v1.1.1 (HIGH confidence, verified)
- [hex.pm/packages/ex_doc](https://hex.pm/packages/ex_doc) — v0.40.1, Jan 2026 (HIGH confidence, verified; 0.40.x generates llms.txt)
- [hex.pm/packages/phoenix](https://hex.pm/packages/phoenix) — v1.8.5, Mar 2026 (HIGH confidence, verified)
- [hexdocs.pm/ecto/](https://hexdocs.pm/ecto/) — v3.13.5, Mar 2026 (HIGH confidence, verified)
- [elixir-lang.org releases](https://github.com/elixir-lang/elixir/releases) — Elixir 1.19.5 current stable (HIGH confidence)
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — comprehensive ecosystem analysis (HIGH confidence, primary research document)
- `prompts/elixir-best-practices-deep-research.md` — library architecture patterns (HIGH confidence)
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — OSS library best practices (HIGH confidence)
- `prompts/ecto-best-practices-deep-research.md` — Ecto auth patterns (HIGH confidence)
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — CI/CD stack (HIGH confidence)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

## Local development prerequisites

`mix test` requires a live Postgres at `localhost:5432` with credentials
`postgres`/`postgres`. There is no `:postgres` tag exclusion — every test
that runs in CI runs locally too, and a missing database fails fast
instead of silently skipping.

One-liner to start a disposable postgres container:

```bash
docker run -d --name sigra-test-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 postgres:16-alpine
```

Any already-running container on port 5432 with the same credentials
(including the project's `sigra-uat-postgres`) is fine. Run the full
suite with:

```bash
mix test
```

No env prefix is needed: `mix test` sets `MIX_ENV=test` itself, and the
real-DB test repo (`Sigra.Test.PostgresRepo`) plus the install-golden
fixture already default to `postgres`/`postgres`/`localhost`. To point at a
Postgres with different credentials, override the vars the test repo
actually reads — `SIGRA_TEST_PG_HOSTNAME`, `SIGRA_TEST_PG_USERNAME`,
`SIGRA_TEST_PG_PASSWORD`, `SIGRA_TEST_PG_DATABASE` — not the libpq `PG*`
vars.

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
