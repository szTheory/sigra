# Phase 10: Developer Experience - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

The library ships testing helpers that make auth state trivial to set up in tests, scenario-based fixtures covering all seven documented auth states, a configurable cookie domain with sensible per-environment defaults, and copy-paste documentation (guides + doctests + verified example app) such that a developer can go from zero to working auth in an afternoon.

**In scope:**
- Reconciling DX-01 wording with shipped `Sigra.Testing` signatures (update REQUIREMENTS.md)
- Seven scenario fixtures in the generated `AuthFixtures` module + `scenario/2` dispatcher
- `cookie_domain` config key (runtime struct), honored by remember-me and MFA trust cookies, with per-env defaults
- ex_doc guide directory (`guides/`) organized Phoenix-style with ~15 guides
- Getting-started guide: install → register → login → logout + password reset, <30 min read
- Doctest coverage on `Sigra.Testing` and high-traffic library modules
- Minimal committed example Phoenix app under `test/example/` smoke-tested in CI (install, compile, core flows, reset email, MFA, OAuth, API tokens)
- Audit test helpers: `audit_event_fixture/1` + `assert_audit_event/2` in `Sigra.Testing` (Phase 9 carryover)
- Section comment headers to organize the existing monolithic `Sigra.Testing` module

**Out of scope:**
- Splitting `Sigra.Testing` into submodules (Elixir convention is monolithic — Phoenix.ConnTest, Oban.Testing)
- Auto-detecting cookie domain from the endpoint host (`:parent` / `:auto` atoms)
- A dedicated docs site outside hexdocs
- Tiered quickstart/getting-started/full-setup structure (single getting-started suffices)
- factory_bot-style trait composition for fixtures
- Renaming shipped testing helpers to match literal DX-01 wording

</domain>

<decisions>
## Implementation Decisions

### DX-01 Signature Reconciliation

- **D-01:** **Honor shipped testing-helper names and arities.** Do not rename or add arity-matching aliases. Phase 10 updates REQUIREMENTS.md DX-01 wording to reference the canonical signatures: `log_in_user/3` (generated `UserAuth` ConnCase helper), `register_user/2` (generated `Accounts` context), `setup_totp/2` (`Sigra.Testing`), `create_api_token/3` (`Sigra.Testing`). Rationale: shipped arities reflect real option needs (`:mfa`, `:config`), Phase 7 D-63 already standardized on "token" over "key", and renaming would churn prior-phase APIs for no functional gain.

### Scenario Fixtures (DX-03)

- **D-02:** **Seven named fixture functions in the generated `AuthFixtures` module**, one per DX-03 state: `anonymous_fixture/0`, `authenticated_fixture/1`, `mfa_pending_fixture/1`, `mfa_complete_fixture/1`, `sudo_fixture/1`, `locked_fixture/1`, `unconfirmed_fixture/1`. Fixtures live in the generated module (not `Sigra.Testing`) so host-app User schema extensions (extra required fields, custom tenant columns) propagate automatically via the existing `user_fixture/1` composition point. Matches Phase 1 D-33 ("generator owns app-specific fixtures").

- **D-03:** **Add `scenario/2` dispatcher** in `AuthFixtures`: `scenario(name, attrs \\ %{})` where `name` is one of the seven atoms. Delegates to the corresponding `*_fixture` function. Enables parametric test setup (`Enum.each(~w(anonymous authenticated locked)a, &scenario/1)`) without forcing callers away from the direct-call API.

- **D-04:** **Scenario-specific return shapes** (not a uniform map). Each fixture returns exactly what that scenario needs — no `nil`-padded keys. Concretely:
  - `anonymous_fixture()` → `%{conn: Phoenix.ConnTest.build_conn()}`
  - `authenticated_fixture(attrs)` → `%{user: user, session: session, conn: logged_in_conn}`
  - `mfa_pending_fixture(attrs)` → `%{user: user, session: %UserSession{type: :mfa_pending}, totp_secret: secret}` (no `:conn` — caller hasn't passed the challenge yet)
  - `mfa_complete_fixture(attrs)` → `%{user: user, session: %UserSession{mfa_verified_at: ~U[...]}, conn: logged_in_conn, totp_secret: secret}`
  - `sudo_fixture(attrs)` → `%{user: user, session: %UserSession{sudo_at: ~U[...]}, conn: logged_in_conn}`
  - `locked_fixture(attrs)` → `%{user: %User{failed_login_attempts: 5, locked_at: ~U[...]}}` (no `:conn` — locked users can't log in)
  - `unconfirmed_fixture(attrs)` → `%{user: %User{confirmed_at: nil}}` (no `:conn` — email not yet confirmed; see D-06)

- **D-05:** **MFA state semantics follow Phase 6 session types.** `mfa_pending` = user enrolled in TOTP + session `type: :mfa_pending` (awaiting code entry). `mfa_complete` = user enrolled + session with `mfa_verified_at` set (successfully passed challenge this session). Planner must read `06-CONTEXT.md` to confirm exact field names before implementation.

- **D-06:** **`unconfirmed` means email-unconfirmed**, not MFA-enrollment-in-progress. Matches phx.gen.auth vocabulary and Phase 3 email-flow conventions. User exists with `confirmed_at: nil`.

- **D-07:** **Conn inclusion rule:** fixtures whose scenario implies active HTTP state (`authenticated`, `sudo`, `mfa_complete`, `anonymous`) include `:conn` in the returned map, pre-logged-in via the ConnCase `log_in_user/3` helper. Fixtures representing pre-login or blocked states (`mfa_pending`, `locked`, `unconfirmed`) return data only; callers compose their own `conn` when needed.

### Cookie Domain Config (DX-04)

- **D-08:** **Top-level `:cookie_domain` option in the Sigra runtime config struct.** Single source of truth applied to all Sigra-managed cookies (remember-me, MFA trust, any future cookies). Not per-cookie. Rationale: matches how `session_max_age`, `lockout_threshold`, etc. are configured; avoids config-surface bloat; real-world subdomain setups want one value.

- **D-09:** **Per-environment defaults:**
  - `dev` / `test`: `nil` (host-only cookies — localhost-safe, no subdomain complications)
  - `prod`: `nil` with a `Logger.warning` emitted at application boot if unset, pointing to the cookie-domain guide. Rationale: safe defaults without silent failure; loud enough to be caught in staging before users hit subdomain auth bugs.

- **D-10:** **Explicit string or `nil` only** — no `:parent` / `:auto` atom. Document the recommended env-var pattern: `cookie_domain: System.get_env("COOKIE_DOMAIN")`. Rationale: auto-detection is not an Elixir ecosystem convention (phx.gen.auth never sets `:domain`; Plug.Session `:domain` is compile-time; LiveDashboard's `:parent` is an outlier). Keeping the surface explicit avoids hidden magic.

- **D-11:** **Cookies affected in Phase 10:**
  - Generated `UserAuth.@remember_me_options` reads `cookie_domain` from the Sigra config at runtime
  - `Sigra.MFA.Trust.cookie_opts/0` (and `mfa_challenge_controller` call site) reads the same value
  - Phoenix session cookie itself is **out of scope** — that's configured in the host app's `endpoint.ex` Plug.Session opts; Sigra documents the recommended config in `guides/recipes/subdomain-auth.md` but does not patch it.

### Documentation (DX-02)

- **D-12:** **Phoenix-style `guides/` layout** with ~15 guides organized into subdirectories:
  - `guides/introduction/` — `installation.md`, `getting-started.md`
  - `guides/flows/` — `registration.md`, `login-and-logout.md`, `password-reset.md`, `mfa.md`, `oauth.md`, `api-authentication.md`, `account-lifecycle.md`, `audit-logging.md`
  - `guides/recipes/` — `testing.md`, `subdomain-auth.md`, `custom-user-fields.md`, `multi-tenant.md`, `deployment.md`
  - `guides/upgrading/` — reserved for future version-migration guides
  Matches Phoenix/Absinthe/Oban convention. Final guide count may shift ±2 during writing.

- **D-13:** **Getting-started target:** a single `getting-started.md` covering **install → register → login → logout + password reset email**, readable end-to-end in under 30 minutes, verified against the `test/example/` app. MFA, OAuth, API tokens, audit logging are each separate flow guides linked from the getting-started conclusion. Rationale: "an afternoon" means first-success fast, not feature-completeness upfront.

- **D-14:** **Example-sync strategy:** doctests for library code (`@doc` examples verified via `doctest Sigra.Testing` etc.) **plus** a minimal committed example Phoenix app under `test/example/` that CI smoke-tests. Markdown snippets in guides are drawn from (or cross-referenced to) doctests and the example app so drift surfaces in CI.

- **D-15:** **Hosting:** HexDocs only, via ex_doc `:extras` + `:groups_for_extras` config. llms.txt auto-generated by ex_doc ≥ 0.40 (already pinned in CLAUDE.md stack). No dedicated docs site. Matches Phoenix/Ecto/Oban.

### Example Phoenix App

- **D-16:** **Location: `test/example/`** — a minimal Phoenix app (`mix phx.new --no-assets`-style) with Sigra installed, **committed** to the repo. Regenerated once during Phase 10 implementation, then maintained by hand as the library evolves. Rationale: real verification that install + generated code works without pulling fresh Hex deps every CI run.

- **D-17:** **CI smoke flows** (all must pass for Phase 10 to be verifiable):
  1. `mix deps.get && mix sigra.install && mix compile` — clean install + compile
  2. **Register / login / logout** — core happy path via controller tests in the example app
  3. **Password reset email delivery** — via Swoosh test adapter
  4. **MFA enrollment + challenge** — TOTP setup and successful verification
  5. **OAuth callback** — mocked via `Sigra.Testing.mock_oauth_callback`
  6. **API token create + authenticated request** — using `create_api_token` + `put_bearer_token`
  The CI job runs as a separate GitHub Actions job from the main test suite (distinct working directory, separate Mix project) to avoid `mix.lock` pollution. Slower jobs (MFA/OAuth/API) may be marked `@tag :example_app` for optional local skip.

### Audit Test Helpers (Phase 9 carryover)

- **D-18:** **Ship `audit_event_fixture/1` and `assert_audit_event/2` in `Sigra.Testing`.** Closes the Phase 9 flag.
  - `audit_event_fixture(attrs \\ %{})` inserts a row directly via the configured repo (bypassing `Ecto.Multi`) for tests that need pre-existing events to query against. Uses Phase 9 `audit_events` schema.
  - `assert_audit_event(expected_map, opts \\ [])` matches the most recent event (or the event at `opts[:position]`) against `:action`, `:outcome`, `:actor_id`, `:actor_type`, `:target_id`, `:target_type`, and a `:metadata` subset (deep-matches the keys present in `expected_map`, ignores extras). Raises with a diff on mismatch.
  - Planner should read Phase 9 `09-CONTEXT.md` for the canonical schema and query API before implementing.

### Module Organization

- **D-19:** **`Sigra.Testing` stays monolithic.** Add section comment headers — `# --- Sessions ---`, `# --- MFA ---`, `# --- API Tokens ---`, `# --- OAuth ---`, `# --- Account Lifecycle ---`, `# --- Email ---`, `# --- Lockout ---`, `# --- Audit (Phase 9) ---` — to organize the existing ~60 functions. No submodules, no re-exports. Rationale: Elixir convention (Phoenix.ConnTest, Oban.Testing 711 LOC, Ecto.Adapters.SQL.Sandbox); single `import Sigra.Testing` stays the UX; splitting would churn every existing test in the repo.

### Claude's Discretion

- Exact guide filenames within the `guides/flows/` directory (final ±2 from D-12 list)
- Doctest density per library module (focus on `Sigra.Testing`, `Sigra.Auth`, `Sigra.Config`; lighter on internal modules)
- Order in which `test/example/` smoke jobs run in CI
- Whether to split the example-app CI job into parallel matrix entries per feature (performance optimization)
- Layout details of the `getting-started.md` (heading structure, code-block count, screenshots if any)
- Whether `scenario/2` also accepts string names (`"mfa_pending"`) in addition to atoms

### Folded Todos

None — no pending todos from the todo-match surfaced for this phase.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior phase context (required reading)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-32 (`Sigra.Testing` as assertion helper module), D-33 (generator owns app-specific fixtures + ConnCase helpers), D-43 (phx.gen.auth naming convention)
- `.planning/phases/02-core-auth/02-CONTEXT.md` — generated `auth.ex` shape; `register_user/2` signature
- `.planning/phases/03-email-flows-and-transactional-email/03-CONTEXT.md` — D-45 email test helpers; email-confirmation semantics for `unconfirmed_fixture`
- `.planning/phases/04-session-management-and-security-baseline/04-CONTEXT.md` — D-59/D-61 session test helpers and fixtures
- `.planning/phases/05-oauth-and-social-login/05-CONTEXT.md` — D-64 OAuth test helpers (needed for example-app OAuth smoke test)
- `.planning/phases/06-multi-factor-authentication/06-CONTEXT.md` — D-92/D-93 MFA test helpers, `mfa_pending` vs `mfa_verified_at` session semantics (critical for D-05)
- `.planning/phases/07-api-authentication/07-CONTEXT.md` — D-63 `create_api_token/3`, `put_bearer_token/2` (critical for D-01 reconciliation)
- `.planning/phases/08-account-lifecycle/08-CONTEXT.md` — D-53 `with_hook/3` pattern; account-lifecycle fixtures
- `.planning/phases/09-audit-logging/09-CONTEXT.md` — audit_events schema, query API, `Sigra.Audit` module (critical for D-18)

### Project-level specs
- `.planning/PROJECT.md` — DX principles, copy-paste-over-deps philosophy, testing AAA style
- `.planning/REQUIREMENTS.md` §DX-01..DX-04 — will be updated per D-01 to match shipped signatures
- `.planning/ROADMAP.md` §"Phase 10: Developer Experience" — phase goal and success criteria

### Existing code (must read before modifying)
- `lib/sigra/testing.ex` — current 1007-line helper module; all ~60 function signatures
- `priv/templates/sigra.install/auth_fixtures.ex` — template for generated `AuthFixtures`; scenario fixtures extend this
- `priv/templates/sigra.install/user_auth.ex` — template for generated `UserAuth` ConnCase helper; cookie_domain integration point
- `priv/templates/sigra.install/mfa_challenge_controller.ex` — MFA trust cookie set site (`maybe_set_trust_cookie`)
- `lib/sigra/config.ex` — runtime config struct; `:cookie_domain` key added here per D-08
- `lib/mix/tasks/sigra.install.ex` — install task; example-app verification hooks here
- `test/support/audit_fixtures.ex` — existing 48-line audit fixture file; scope of D-18 expansion

### External research sources (informing decisions)
- Phoenix `guides/` directory layout — https://github.com/phoenixframework/phoenix/tree/main/guides
- Oban.Testing source — https://github.com/sorentwo/oban/blob/main/lib/oban/testing.ex (monolithic precedent for D-19)
- phx.gen.auth `context_fixtures_functions.ex.eex` — https://github.com/phoenixframework/phoenix/blob/main/priv/templates/phx.gen.auth/context_fixtures_functions.ex.eex (fixture API precedent for D-02)
- Phoenix LiveDashboard `:parent` cookie_domain precedent — https://github.com/phoenixframework/phoenix_live_dashboard/pull/200/files (researched and explicitly rejected in D-10)
- ex_doc `:extras` config — https://hexdocs.pm/ex_doc/readme.html#extras

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Sigra.Testing` (1007 LOC, ~60 functions)** — already has `setup_totp/2`, `create_api_token/3`, `assert_email_sent/1`, `with_hook/3`, `simulate_lockout/3`, `mock_oauth_callback/1`, `bypass_mfa/1`, `trust_browser/3`, plus account-lifecycle and audit-adjacent helpers. Phase 10 **extends** this module (sections + audit helpers), does not rewrite it.
- **Generated `AuthFixtures` template** (`priv/templates/sigra.install/auth_fixtures.ex`, 172 lines) — already has `user_fixture`, `session_fixture`, `sudo_session_fixture`, `mfa_user_fixture`, `mfa_pending_session_fixture`, `mfa_locked_fixture`, `locked_user_fixture`, `scheduled_deletion_fixture`, `force_password_change_fixture`. Phase 10 adds the seven named scenario fixtures + `scenario/2` dispatcher, refactoring existing fixtures into composition primitives where overlap exists.
- **Generated `UserAuth` template** (`priv/templates/sigra.install/user_auth.ex`) — has `log_in_user/3`, `log_out_user/1`, `@remember_me_options` (no `:domain`), `renew_session/1`. Phase 10 adds `cookie_domain` resolution to `@remember_me_options`.
- **`Sigra.Config`** — runtime config struct + `NimbleOptions` schema. D-08 adds `:cookie_domain` key here.
- **`Sigra.MFA.Trust`** — already has `cookie_opts/0` and `cookie_name/0`. D-11 threads cookie_domain through `cookie_opts/0`.

### Established Patterns
- **Generator owns app-specific code** (D-33 Phase 1) — fixtures, ConnCase helpers, `Accounts` context. `Sigra.Testing` holds library-level helpers that need no per-app context.
- **phx.gen.auth naming** (D-43 Phase 1) — `register_user`, `log_in_user`, `deliver_*`, `verify_*`, `validate_*`. Phase 10 must not introduce `create_user`, `login`, or `sign_in` even in guides.
- **Test fixtures compose** — bigger fixtures call smaller ones (`mfa_user_fixture` calls `user_fixture`). Phase 10 scenarios follow the same pattern so host-app extensions propagate.
- **Per-env config defaults via `Sigra.Config.new/1`** — existing pattern. Cookie domain follows it.
- **Logger.warning at boot for soft-failable misconfigurations** — precedent exists elsewhere in `Sigra.Application`; D-09 uses the same pattern.
- **ConnCase pattern** — generated `conn_case.ex` imports `Sigra.Testing` + `AuthFixtures`. D-02 fixtures are designed to work alongside existing ConnCase helpers without collision.

### Integration Points
- `priv/templates/sigra.install/auth_fixtures.ex` — scenario fixtures added here
- `priv/templates/sigra.install/user_auth.ex` — `@remember_me_options` reads cookie_domain
- `priv/templates/sigra.install/mfa_challenge_controller.ex` — `maybe_set_trust_cookie` reads cookie_domain
- `lib/sigra/config.ex` — `:cookie_domain` added to NimbleOptions schema + struct
- `lib/sigra/application.ex` — startup warning hook for missing prod cookie_domain
- `lib/sigra/testing.ex` — add audit section + fixture/assertion functions + section comment headers
- `mix.exs` — `:extras` and `:groups_for_extras` config for ex_doc
- `.github/workflows/ci.yml` — new example-app smoke job
- `.planning/REQUIREMENTS.md` §DX-01 — wording update

</code_context>

<specifics>
## Specific Ideas

- **"Zero to working auth in an afternoon"** (REQUIREMENTS.md DX-02) is the concrete bar. Getting-started must demonstrably hit register → login → logout + password reset email in under 30 minutes on a fresh Phoenix app, verified by the `test/example/` smoke job.
- **Factory_bot traits are NOT the target** — Jon considered and rejected in favor of named functions + dispatcher. Don't reintroduce.
- **Cookie domain auto-detection is NOT the target** — Jon considered and rejected. Explicit config + documented env-var pattern only. Don't add `:parent` or `:auto` atoms "for convenience" during implementation.
- **Don't rename `create_api_token`** — Phase 7 D-63 standardized "token"; Phase 10 D-01 affirms it. If you feel the urge to add `create_api_key` as an alias, re-read D-01.
- **Scenario return shapes are deliberately non-uniform** — don't "improve" them to a uniform map during planning. See D-04.

</specifics>

<deferred>
## Deferred Ideas

- **Tiered docs (5min quickstart / 30min getting-started / 2h full setup)** — considered in D-13, rejected for maintenance burden. Revisit if user feedback suggests the single getting-started is insufficient.
- **Dedicated docs site beyond hexdocs** — out of scope for a library. Revisit if the community asks.
- **Splitting `Sigra.Testing` into submodules** — considered in D-19, rejected. Revisit only if the module grows past ~2000 LOC or section headers become unwieldy.
- **Factory_bot-style trait composition** — considered in D-02, rejected as non-idiomatic. Revisit if Rails-heavy users request it.
- **Cookie domain auto-detection (`:parent` / `:auto`)** — considered in D-10, rejected. Revisit if Plug.Session adds runtime `:domain` support.
- **Generated endpoint.ex session-cookie domain patch** — D-11 leaves Phoenix session cookie alone. Revisit if subdomain auth onboarding proves painful without it.
- **Tiered CI for example-app flows** — D-17 puts everything in one job; could split into parallel matrix entries for speed if the job becomes a CI bottleneck.
- **llms.txt custom tuning** — ex_doc auto-generates it; we get the default. Revisit if LLM-assisted onboarding needs a curated subset.

### Reviewed Todos (not folded)

None — no pending todos surfaced from todo-match for Phase 10.

</deferred>

---

*Phase: 10-developer-experience*
*Context gathered: 2026-04-09*
