# Phase 10: Developer Experience - Research

**Researched:** 2026-04-09
**Domain:** Elixir library DX — testing helpers, scenario fixtures, cookie config, ex_doc guides, smoke-test example app
**Confidence:** HIGH (all shipped code verified against the working tree; external syntax verified via WebFetch against Phoenix `mix.exs` and ex_doc docs)

## Summary

Phase 10 is an extension-and-wiring phase, not a greenfield build. Every subsystem it touches already exists in the working tree:

- `Sigra.Testing` is 1007 LOC with ~30 public functions across Sessions / MFA / API tokens / OAuth / Account Lifecycle / Email — Phase 10 adds audit helpers and organizes the existing surface with section headers (D-18, D-19).
- `AuthFixtures` (generated, 172 lines) already has `user_fixture`, `session_fixture`, `sudo_session_fixture`, `mfa_user_fixture`, `mfa_pending_session_fixture`, `mfa_locked_fixture`, `locked_user_fixture`, `scheduled_deletion_fixture`, `force_password_change_fixture` — Phase 10 adds seven **named scenario wrappers** on top of these primitives (D-02..D-07).
- `ConnCaseHelpers.log_in_user/3` (generated) already matches the D-01 canonical signature `(conn, user, opts)` and takes a `:type` option. D-01 only needs REQUIREMENTS.md text updates, not code changes.
- `Sigra.Config` is a NimbleOptions-validated struct — adding `:cookie_domain` is a one-key addition at the top level (D-08).
- `Sigra.Application.start/2` already emits a `Logger.warning` at boot for the analogous "audit retention configured but Oban absent" case (D-09 has a direct precedent).

The major **non-trivial** work items are:
1. **Refactoring `@remember_me_options` from a compile-time module attribute to a runtime-resolved function** — this is the only place a cookie option list is frozen at compile time, and D-08 requires runtime reads from `Sigra.Config`.
2. **Resolving the three cookie-option call sites consistently** — `UserAuth.@remember_me_options` (template), `Sigra.MFA.Trust.cookie_opts/0` (library), and `Sigra.Plug.FetchSession.@default_cookie_opts` (library, also remember-me adjacent) — and deciding whether cookie_domain is threaded via function arg, struct field, or Process dict.
3. **Building the committed `test/example/` Phoenix app as a sibling Mix project** with `{:sigra, path: "../.."}` and a separate GitHub Actions job.
4. **Deciding how `mfa_complete` differs from `authenticated` given no `mfa_verified_at` field exists** — this is a research GAP that requires a planning decision (see Open Questions §1).

**Primary recommendation:** Plan this phase as six small plans, not one big one: (1) REQUIREMENTS + section headers + audit helpers, (2) scenario fixtures, (3) cookie_domain config + runtime refactor, (4) ex_doc guides scaffold, (5) getting-started + flow guides content, (6) example app + CI job. Plans 1-3 are independent and can land in any order; plans 4-5 depend on 3 for the subdomain-auth recipe; plan 6 depends on everything.

## User Constraints (from CONTEXT.md)

### Locked Decisions (verbatim)

**DX-01 Signature Reconciliation**
- **D-01:** Honor shipped testing-helper names and arities. Do not rename or add arity-matching aliases. Phase 10 updates REQUIREMENTS.md DX-01 wording to reference the canonical signatures: `log_in_user/3` (generated `UserAuth` ConnCase helper), `register_user/2` (generated `Accounts` context), `setup_totp/2` (`Sigra.Testing`), `create_api_token/3` (`Sigra.Testing`).

**Scenario Fixtures (DX-03)**
- **D-02:** Seven named fixture functions in the generated `AuthFixtures` module, one per DX-03 state: `anonymous_fixture/0`, `authenticated_fixture/1`, `mfa_pending_fixture/1`, `mfa_complete_fixture/1`, `sudo_fixture/1`, `locked_fixture/1`, `unconfirmed_fixture/1`. Fixtures live in the generated module (not `Sigra.Testing`).
- **D-03:** Add `scenario/2` dispatcher in `AuthFixtures`.
- **D-04:** Scenario-specific return shapes (not a uniform map). See CONTEXT for each shape.
- **D-05:** MFA state semantics follow Phase 6 session types. `mfa_pending` = user enrolled + session `type: :mfa_pending`. `mfa_complete` = user enrolled + session with `mfa_verified_at` set. **Planner must read `06-CONTEXT.md` to confirm exact field names before implementation.**
- **D-06:** `unconfirmed` means email-unconfirmed. User exists with `confirmed_at: nil`.
- **D-07:** Conn inclusion rule — `authenticated`, `sudo`, `mfa_complete`, `anonymous` include `:conn`; `mfa_pending`, `locked`, `unconfirmed` do not.

**Cookie Domain Config (DX-04)**
- **D-08:** Top-level `:cookie_domain` option in the Sigra runtime config struct. Single source of truth.
- **D-09:** Per-environment defaults: `dev`/`test` nil; `prod` nil with a `Logger.warning` at boot if unset.
- **D-10:** Explicit string or `nil` only — no `:parent` / `:auto` atom.
- **D-11:** Cookies affected: `UserAuth.@remember_me_options`, `Sigra.MFA.Trust.cookie_opts/0` (+ mfa_challenge_controller call site). Phoenix session cookie itself is out of scope — documented in recipes.

**Documentation (DX-02)**
- **D-12:** Phoenix-style `guides/` layout with ~15 guides (`introduction/`, `flows/`, `recipes/`, `upgrading/`). ±2 guide flex.
- **D-13:** Getting-started target: install → register → login → logout + password reset email, < 30 min readthrough.
- **D-14:** Example-sync via doctests + committed `test/example/` app.
- **D-15:** Hosting: HexDocs only via ex_doc `:extras` + `:groups_for_extras`.

**Example Phoenix App**
- **D-16:** Location: `test/example/`, committed, minimal `mix phx.new --no-assets`-style.
- **D-17:** CI smoke flows: install/compile, register/login/logout, password reset, MFA TOTP, OAuth mocked, API token. Separate GitHub Actions job, distinct working directory, separate Mix project.

**Audit Test Helpers (D-18)**
- Ship `audit_event_fixture/1` and `assert_audit_event/2` in `Sigra.Testing`. Closes Phase 9 flag.

**Module Organization (D-19)**
- `Sigra.Testing` stays monolithic. Add section comment headers.

### Claude's Discretion

- Exact guide filenames within `guides/flows/` (final ±2 from D-12 list)
- Doctest density per library module (focus on `Sigra.Testing`, `Sigra.Auth`, `Sigra.Config`)
- Order of example-app smoke jobs in CI
- Whether to split the example-app CI job into parallel matrix entries
- Layout details of `getting-started.md`
- Whether `scenario/2` also accepts string names

### Deferred Ideas (OUT OF SCOPE)

- Tiered docs (5min / 30min / 2h)
- Dedicated docs site beyond hexdocs
- Splitting `Sigra.Testing` into submodules
- factory_bot-style trait composition
- Cookie domain auto-detection (`:parent` / `:auto`)
- Generated endpoint.ex session-cookie domain patch
- Tiered CI for example-app flows
- llms.txt custom tuning

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-01 | Testing helpers (`log_in_user`, `register_user`, `setup_totp`, `create_api_key`) | §DX-01 Reconciliation below — REQUIREMENTS.md text edit only |
| DX-02 | Comprehensive documentation with copy-paste examples | §Documentation Stack + §Getting-Started Structure + §Example App |
| DX-03 | Scenario-based test fixtures for auth states | §Scenario Fixtures (primitives, composition, conn handling) |
| DX-04 | Cookie domain configuration with sensible defaults | §Cookie Domain (runtime refactor, three call sites) |

## Standard Stack

Already locked by CLAUDE.md / mix.exs. No new dependencies required for Phase 10. Verified against working `mix.exs`:

| Library | Version | Purpose in Phase 10 | Status |
|---------|---------|---------------------|--------|
| ex_doc | ~> 0.40 | Generate `guides/` HTML + auto-generate llms.txt | Present, dev-only [VERIFIED: mix.exs:52] |
| nimble_options | ~> 1.1 | Add `:cookie_domain` to existing schema | Present [VERIFIED: mix.exs:39] |
| swoosh | ~> 1.5 | Test-adapter assertion in example-app reset-email smoke | Present, optional [VERIFIED: mix.exs:45] |
| phoenix | ~> 1.8 | `test/example/` host | Present [VERIFIED: mix.exs:36] |
| phoenix_live_view | (transitive via phoenix) | Example app LiveView routes | Available via Phoenix dep |
| mox | ~> 1.1 | Existing pattern for OAuth mock in `mock_oauth_callback/1` | Present, test-only [VERIFIED: mix.exs:55] |

**No new deps are added in Phase 10.** The example app introduces its own `mix.exs` with its own deps but those are isolated from the library's `mix.lock` (see §Example App).

## User Constraints (from CLAUDE.md)

Already embedded in CONTEXT.md locks. Nothing in CLAUDE.md contradicts Phase 10 decisions. Relevant library-wide constraints to keep in mind while writing guides and the example app:

- phx.gen.auth naming convention (`register_user`, `log_in_user`, `deliver_*`) — **guides must not use `create_user`, `login`, or `sign_in`** even in prose examples.
- "Own your code" — guides emphasize that schemas / contexts / LiveViews are generated and editable. Library function calls (`Sigra.Auth.*`, `Sigra.Testing.*`) are the stable surface.
- Minimal transitive deps — example app should not pull in extras beyond `{:sigra, path: "../.."}`, `{:phoenix, ...}`, `{:ecto_sql, ...}`, `{:postgrex, ...}` (or sqlite3), `{:argon2_elixir, ...}`, `{:swoosh, ...}`, and test-only Mox.

## Architecture Patterns

### Recommended Project Structure (additions only)

```
sigra/
├── guides/                         # NEW: ex_doc extras source
│   ├── introduction/
│   │   ├── installation.md
│   │   └── getting-started.md
│   ├── flows/
│   │   ├── registration.md
│   │   ├── login-and-logout.md
│   │   ├── password-reset.md
│   │   ├── mfa.md
│   │   ├── oauth.md
│   │   ├── api-authentication.md
│   │   ├── account-lifecycle.md
│   │   └── audit-logging.md
│   ├── recipes/
│   │   ├── testing.md
│   │   ├── subdomain-auth.md       # consumes cookie_domain config
│   │   ├── custom-user-fields.md
│   │   ├── multi-tenant.md
│   │   └── deployment.md
│   └── upgrading/                  # empty until v0.2
├── test/
│   └── example/                    # NEW: committed sibling Mix project
│       ├── mix.exs                 # depends on {:sigra, path: "../.."}
│       ├── mix.lock                # isolated from root
│       ├── config/
│       ├── lib/example/            # Accounts, Scope, auth.ex (generated)
│       ├── lib/example_web/        # UserAuth, controllers, LiveViews (generated)
│       ├── priv/repo/migrations/   # generated Sigra migrations
│       └── test/                   # smoke tests for CI (6 flows)
└── .github/workflows/ci.yml        # NEW job: example_app_smoke
```

### Pattern 1: Runtime-resolved cookie options (CRITICAL)

**Problem:** `priv/templates/sigra.install/user_auth.ex` line 21-27 defines `@remember_me_options` as a **module attribute** — frozen at compile time of the generated host app. D-08 requires `:domain` to be read from `Sigra.Config` at call time so runtime config changes (e.g., `COOKIE_DOMAIN` env var at boot) take effect without recompilation.

**Current code (template):**
```elixir
@remember_me_options [
  sign: true,
  max_age: @max_age,
  same_site: "Lax",
  http_only: true,
  secure: Mix.env() == :prod
]

defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
  put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
end
```

**Required refactor:**
```elixir
# Module attribute keeps the static options (sign/max_age/same_site/http_only)
@remember_me_static_options [
  sign: true,
  max_age: @max_age,
  same_site: "Lax",
  http_only: true
]

defp remember_me_options do
  config = <%= context_module %>.sigra_config()
  base = Keyword.put(@remember_me_static_options, :secure, config.require_secure_cookies || Mix.env() == :prod)

  case config.cookie_domain do
    nil -> base
    domain when is_binary(domain) -> Keyword.put(base, :domain, domain)
  end
end

defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
  put_resp_cookie(conn, @remember_me_cookie, token, remember_me_options())
end
```

Note: the generated `Accounts` context already exposes `sigra_config/0` (used by `auth_fixtures.ex` line 96: `Auth.sigra_config()`). The refactor relies on that existing accessor — no new public API.

### Pattern 2: Cookie options at the library layer (`Sigra.MFA.Trust`)

**Current code** (`lib/sigra/mfa/trust.ex:19-35`):
```elixir
@cookie_opts [http_only: true, secure: true, same_site: "Lax"]
def cookie_opts, do: @cookie_opts
```

**Call site** (`priv/templates/sigra.install/mfa_challenge_controller.ex:113`):
```elixir
Sigra.MFA.Trust.cookie_opts() ++ [max_age: trust_ttl]
```

**Recommended refactor:** add `cookie_opts/1` that accepts a `Sigra.Config` struct or a keyword list, keep `cookie_opts/0` as a deprecated shim returning the domain-less default. The mfa_challenge_controller template updates its call to `Sigra.MFA.Trust.cookie_opts(config)` where `config` comes from `Auth.sigra_config()`.

```elixir
def cookie_opts, do: @cookie_opts  # deprecated, domain-unaware
def cookie_opts(%Sigra.Config{cookie_domain: nil}), do: @cookie_opts
def cookie_opts(%Sigra.Config{cookie_domain: domain}) when is_binary(domain),
  do: Keyword.put(@cookie_opts, :domain, domain)
```

This leaves existing callers working while enabling domain propagation.

### Pattern 3: Scenario fixture composition

**Existing primitives** in `priv/templates/sigra.install/auth_fixtures.ex`:

| Primitive | Returns | Notes |
|-----------|---------|-------|
| `user_fixture/1` | `%User{}` | Registers via `Accounts.register_user/2` |
| `session_fixture/2` | `%UserSession{}` | Inserts directly via repo, type default `"standard"` |
| `sudo_session_fixture/2` | `%UserSession{sudo_at: DateTime}` | Calls `session_fixture` with sudo_at merged |
| `mfa_user_fixture/1` | `%{user, totp_secret, backup_codes}` | Calls `user_fixture` then `Sigra.Testing.setup_totp/2` |
| `mfa_pending_session_fixture/1` | `%{user, session, totp_secret}` | Session type `"mfa_pending"` |
| `mfa_locked_fixture/1` | `%{user, credential}` | Via `Sigra.Testing.simulate_mfa_lockout/2` |
| `locked_user_fixture/1` | `%User{failed_login_attempts: 5, locked_at: ...}` | Repo update |

**New scenario wrappers (D-02..D-07):** these compose the primitives above and add a `:conn` key where D-07 requires it. None duplicate primitive logic:

```elixir
# --- Scenario Fixtures (Phase 10, DX-03) ---

import Phoenix.ConnTest, only: [build_conn: 0]
import <%= web_module %>.ConnCaseHelpers, only: [log_in_user: 2, log_in_user: 3]

def anonymous_fixture do
  %{conn: build_conn()}
end

def authenticated_fixture(attrs \\ %{}) do
  user = user_fixture(attrs)
  session = session_fixture(user)
  %{user: user, session: session, conn: log_in_user(build_conn(), user)}
end

def mfa_pending_fixture(attrs \\ %{}) do
  # delegates to existing primitive; returns without :conn (D-07)
  mfa_pending_session_fixture(attrs)
end

def mfa_complete_fixture(attrs \\ %{}) do
  %{user: user, totp_secret: secret} = mfa_user_fixture(attrs)
  session = session_fixture(user, %{type: :standard})  # post-challenge standard session
  conn = log_in_user(build_conn(), user)
  %{user: user, session: session, conn: conn, totp_secret: secret}
end

def sudo_fixture(attrs \\ %{}) do
  user = user_fixture(attrs)
  session = sudo_session_fixture(user)
  %{user: user, session: session, conn: log_in_user(build_conn(), user)}
end

def locked_fixture(attrs \\ %{}) do
  user = attrs |> user_fixture() |> locked_user_fixture()
  %{user: user}
end

def unconfirmed_fixture(attrs \\ %{}) do
  # User is registered but confirmed_at is nil; register_user does NOT auto-confirm
  user = user_fixture(attrs)
  %{user: user}
end

def scenario(name, attrs \\ %{})
def scenario(:anonymous, _attrs), do: anonymous_fixture()
def scenario(:authenticated, attrs), do: authenticated_fixture(attrs)
def scenario(:mfa_pending, attrs), do: mfa_pending_fixture(attrs)
def scenario(:mfa_complete, attrs), do: mfa_complete_fixture(attrs)
def scenario(:sudo, attrs), do: sudo_fixture(attrs)
def scenario(:locked, attrs), do: locked_fixture(attrs)
def scenario(:unconfirmed, attrs), do: unconfirmed_fixture(attrs)
```

**Critical note — `log_in_user` import:** The generated `AuthFixtures` module currently does NOT import `ConnCaseHelpers`. Adding the import is the cleanest path, but the planner should verify no circular-compile issues (the two modules live in `test/support/` and compile together under `elixirc_paths(:test)`). An alternative is for the scenario fixtures to build the conn inline:

```elixir
conn = build_conn() |> Plug.Conn.put_session(:user_token, token)
```

— this avoids the cross-module dep entirely at the cost of duplicating the `log_in_user` body. Recommendation: **import ConnCaseHelpers.** Both files are generated by the same `mix sigra.install` run into the same `test/support/` dir, and Phoenix's own phx.gen.auth fixtures do the same.

### Pattern 4: Existing `session.type` values are ATOMS not strings

**Verified from source** (`lib/sigra/session.ex:33, 69`; `lib/sigra/config.ex:464, 1000`; `lib/sigra/plug/require_mfa.ex:57`):
- Library type: `:standard | :remember_me | :mfa_pending`
- These are atoms in the `%Sigra.Session{}` struct
- Config `type:` option uses `{:in, [:standard, :remember_me]}` (no `:mfa_pending` there because sessions never start as mfa_pending via config — they're transitioned by the auth orchestrator)

**However** the existing generated `session_fixture/2` stores `type: "standard"` and `type: "mfa_pending"` as **strings** (see `auth_fixtures.ex:50, 115`). This is because the Ecto column is stored as text/varchar — see `lib/sigra/session_stores/ecto.ex:32`: `type: to_string(Map.get(metadata, :type, :standard))`.

**Implication for planner:** Scenario fixtures must match the existing string-based DB convention in `session_fixture` calls. Passing `type: :standard` (atom) to `session_fixture` will insert the atom via `Ecto.Changeset.change` and may fail at the schema boundary. Use `type: "standard"` / `type: "mfa_pending"` strings to match the existing primitive.

**Confirmed by:** `session_fixture` at line 50 uses `"standard"` as the default string.

### Anti-Patterns to Avoid

- **Uniform map return shape across scenarios.** D-04 explicitly rejects this — each scenario returns only the keys the caller needs.
- **Adding `create_api_key` as an alias for `create_api_token`.** D-01 explicitly rejects this; Phase 7 D-63 standardized "token".
- **Auto-detecting cookie domain from Endpoint.** D-10 rejected; stay explicit.
- **Splitting `Sigra.Testing` into submodules.** D-19 rejected; keep monolithic with section comment headers.
- **Patching the Phoenix session cookie `:domain`** in the generated endpoint. D-11 out of scope; document in `recipes/subdomain-auth.md` only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown → HTML sidebar rendering | Custom docs site | ex_doc `:extras` + `:groups_for_extras` | HexDocs hosting, llms.txt auto-gen, Elixir-ecosystem familiarity |
| LLM-discovery manifest | Hand-written llms.txt | ex_doc ≥ 0.40 auto-gen | Already pinned, zero config [CITED: hexdocs.pm/ex_doc] |
| OAuth callback mocking in smoke tests | New mock strategy | Existing `Sigra.Testing.mock_oauth_callback/1` | Shipped helper already used by library tests |
| Audit row creation in fixtures | Build row via changeset inline | `Sigra.Audit.log/2` public API + Sigra.Test.AuditFixtures schema | D-18 extends existing primitives |
| Example app from scratch | Hand-roll minimal Phoenix | `mix phx.new test/example --no-assets --no-dashboard --no-mailer` then `mix sigra.install` | One-time setup, commits result |
| Phoenix.ConnTest conn building | Roll your own | `Phoenix.ConnTest.build_conn/0` | Standard, works in any ExUnit context |

**Key insight:** Phase 10 is almost entirely about **wiring existing pieces**. The only original code is the `test/example/` app scaffold, the seven scenario wrappers, and the cookie_domain config path. Guides are prose around shipped code.

## Runtime State Inventory

N/A — Phase 10 is greenfield additions (guides, example app, scenario fixtures) and in-place refactors (cookie options, Sigra.Testing sections). No rename / migration / string-replacement work. **Nothing to invalidate at runtime.**

| Category | Status |
|----------|--------|
| Stored data | None — verified: no schema changes, no data migrations |
| Live service config | None — verified: no external services touched |
| OS-registered state | None |
| Secrets/env vars | **New documented env var `COOKIE_DOMAIN`** (string) — not required, just a recommended pattern per D-10. No existing secrets touched. |
| Build artifacts | None — verified: no package renames, no pyproject/mix rewrites |

## Common Pitfalls

### Pitfall 1: Compile-time cookie options frozen at host-app compile
**What goes wrong:** Developer sets `COOKIE_DOMAIN=".example.com"` at prod boot, but `UserAuth.@remember_me_options` was baked in at compile time with no `:domain` key. Remember-me cookies are issued host-only and don't span subdomains.
**Why it happens:** Module attributes evaluate once at compile time.
**How to avoid:** Pattern 1 above — convert to a function that reads `Accounts.sigra_config().cookie_domain` at call time.
**Warning signs:** Subdomain login works in session but fails on the remember-me path after browser restart. The `recipes/subdomain-auth.md` guide must call this out explicitly.

### Pitfall 2: Session `type` atom vs string mismatch
**What goes wrong:** New scenario fixture passes `type: :standard` atom; repo stores "standard" string; downstream `%Sigra.Session{type: :standard}` struct builds correctly but DB round-trip yields `"standard"` and comparisons in `Sigra.Plug.RequireMFA` fail.
**Why it happens:** `session_stores/ecto.ex:32` always calls `to_string/1` on the type before insert, but in-memory fixture code can skip this.
**How to avoid:** Always pass strings (`"standard"`, `"mfa_pending"`, `"remember_me"`) to `session_fixture` consistent with the existing primitive. Alternatively, follow the primitive's own default and override only when needed.
**Warning signs:** `(Ecto.ChangeError) value :standard cannot be cast to type :string` at `session_fixture` insert.

### Pitfall 3: `mfa_verified_at` does not exist as a schema field
**What goes wrong:** D-05 and D-04 reference `mfa_verified_at` as a session-level flag distinguishing `mfa_pending` from `mfa_complete`. **Grep confirms this field exists only in `10-CONTEXT.md` itself** — it is nowhere in `lib/sigra/session.ex`, the Ecto store, or any Phase 6 artifact. [VERIFIED: Grep across working tree 2026-04-09]
**Why it happens:** Phase 6's actual mechanism is session **transition** — the mfa_pending session is replaced by a standard or remember_me session on successful challenge verification (`lib/sigra/auth.ex:884-899`). There is no "mfa_verified_at" column.
**How to avoid:** `mfa_complete_fixture` should return a session with `type: "standard"` (the post-transition state) — not a session with `mfa_verified_at`. See §Pattern 3 above and Open Question §1. Planner must resolve this before implementation.
**Warning signs:** Scenario fixture attempts to set a nonexistent field and the `Ecto.Changeset.change/2` call quietly drops it, producing a session indistinguishable from `authenticated`.

### Pitfall 4: `test/example/mix.lock` polluting root library lockfile
**What goes wrong:** A developer runs `mix deps.get` from the repo root and it picks up `test/example/mix.exs`, merging its deps into `mix.lock`.
**Why it happens:** Mix resolves whichever `mix.exs` is in CWD.
**How to avoid:** Keep `test/example/` as a completely separate Mix project (it has its own `mix.exs` and `mix.lock`). The root `mix.exs` must NOT add `test/example/` to `elixirc_paths`. CI jobs must `cd test/example` before running any Mix commands. Recommend adding `test/example/deps/` and `test/example/_build/` to the root `.gitignore`, keeping `test/example/mix.lock` committed.
**Warning signs:** `mix deps.tree` from the root shows Phoenix-example-only deps leaking in.

### Pitfall 5: `AuthFixtures` importing `ConnCaseHelpers` (cross-test-support dep)
**What goes wrong:** Generator writes both files to `test/support/`; AuthFixtures imports ConnCaseHelpers; in some projects ConnCaseHelpers imports AuthFixtures (for `register_and_log_in_user`); circular compile error.
**Why it happens:** `test/support/` compiles all `.ex` files together under `:test` env; mutual imports create dependency cycles.
**How to avoid:** Import only the specific functions needed (`import ConnCaseHelpers, only: [log_in_user: 2, log_in_user: 3]`) OR inline the conn-building in scenario fixtures. Verify no cycle: ConnCaseHelpers currently imports `Fixtures` (line 21 alias) — it takes a user and logs them in, doesn't call `user_fixture` except in `register_and_log_in_user/1`. The planner should test both compile orders before committing to the import approach.
**Warning signs:** `(CompileError) module Example.AuthFixtures is not loaded and could not be found` during test compile.

### Pitfall 6: Guide examples drifting from shipped signatures
**What goes wrong:** A guide shows `Accounts.register_user(%{...})` (arity 1) but the shipped function is `register_user(attrs, opts \\ [])` (arity 2). Copy-paste works initially but fails when the reader supplies opts.
**Why it happens:** Guides written once, not re-verified against code.
**How to avoid:** D-14 mandates doctest extraction OR cross-reference the example app. The example app is the canonical reference — any guide code block should also appear as a real call in `test/example/` and be exercised by a smoke test.
**Warning signs:** CI passes but copy-paste from docs fails in a user's project.

## Code Examples

### Scenario Fixture Usage (target UX)
```elixir
# Source: new pattern for Phase 10, verified against existing AuthFixtures
defmodule ExampleWeb.DashboardControllerTest do
  use ExampleWeb.ConnCase, async: true

  test "anonymous user is redirected to login", %{} do
    %{conn: conn} = AuthFixtures.anonymous_fixture()
    conn = get(conn, ~p"/dashboard")
    assert redirected_to(conn) == ~p"/users/log_in"
  end

  test "authenticated user sees dashboard", %{} do
    %{conn: conn, user: user} = AuthFixtures.authenticated_fixture()
    conn = get(conn, ~p"/dashboard")
    assert html_response(conn, 200) =~ user.email
  end

  test "locked user cannot log in", %{conn: conn} do
    %{user: user} = AuthFixtures.locked_fixture()
    conn = post(conn, ~p"/users/log_in", %{"user" => %{"email" => user.email, "password" => "hello world!!"}})
    assert html_response(conn, 200) =~ "account is locked"
  end

  # Parametric setup via dispatcher (D-03)
  for state <- ~w(anonymous authenticated locked)a do
    @tag state: state
    test "state #{state} renders home page", %{state: state} do
      %{conn: conn} = AuthFixtures.scenario(state) |> Map.put_new(:conn, build_conn())
      assert get(conn, ~p"/") |> html_response(200)
    end
  end
end
```

### Audit Test Helpers in `Sigra.Testing` (D-18)
```elixir
# Source: pattern derived from test/support/audit_fixtures.ex (existing Wave 0 scaffold)
# and lib/sigra/audit.ex:46-62 (Sigra.Audit.log/2 public API)

# --- Audit (Phase 9) ---

@doc """
Inserts an audit event directly via the configured repo, bypassing Multi wrapping.

## Options
  * `:repo` (required) - the Ecto repo
  * `:audit_schema` (required) - the generated audit_events schema module
  * `:action` (default "test.event")
  * `:outcome` (default "success")
  * `:actor_id`, `:actor_type`, `:target_id`, `:target_type`, `:metadata`
"""
@spec audit_event_fixture(keyword()) :: struct()
def audit_event_fixture(opts) do
  repo = Keyword.fetch!(opts, :repo)
  audit_schema = Keyword.fetch!(opts, :audit_schema)

  attrs = %{
    action: Keyword.get(opts, :action, "test.event"),
    outcome: Keyword.get(opts, :outcome, "success"),
    actor_id: Keyword.get(opts, :actor_id),
    actor_type: Keyword.get(opts, :actor_type, "user"),
    target_id: Keyword.get(opts, :target_id),
    target_type: Keyword.get(opts, :target_type),
    metadata: Keyword.get(opts, :metadata, %{}),
    occurred_at: Keyword.get(opts, :occurred_at, DateTime.utc_now())
  }

  audit_schema
  |> struct()
  |> Ecto.Changeset.change(attrs)
  |> repo.insert!()
end

@doc """
Asserts that the most recent audit event matches the given map.

Deep-matches `:metadata` keys (extras allowed). Raises with a diff on mismatch.
"""
@spec assert_audit_event(map(), keyword()) :: true
def assert_audit_event(expected, opts) do
  repo = Keyword.fetch!(opts, :repo)
  audit_schema = Keyword.fetch!(opts, :audit_schema)
  position = Keyword.get(opts, :position, 0)

  import Ecto.Query

  event =
    from(e in audit_schema, order_by: [desc: e.inserted_at], limit: 1, offset: ^position)
    |> repo.one()

  if is_nil(event) do
    raise ExUnit.AssertionError, message: "Expected an audit event at position #{position}, found none"
  end

  Enum.each(expected, fn
    {:metadata, expected_meta} when is_map(expected_meta) ->
      Enum.each(expected_meta, fn {k, v} ->
        actual = Map.get(event.metadata || %{}, to_string(k)) || Map.get(event.metadata || %{}, k)
        unless actual == v do
          raise ExUnit.AssertionError,
            message: "Expected metadata[#{inspect(k)}] == #{inspect(v)}, got #{inspect(actual)}"
        end
      end)
    {key, expected_value} ->
      actual = Map.get(event, key)
      unless actual == expected_value do
        raise ExUnit.AssertionError,
          message: "Expected #{key} == #{inspect(expected_value)}, got #{inspect(actual)}"
      end
  end)

  true
end
```

### ex_doc `:extras` + `:groups_for_extras` config
```elixir
# Source: Phoenix mix.exs pattern (https://github.com/phoenixframework/phoenix/blob/main/mix.exs)
# Verified against ex_doc >= 0.40 [CITED: hexdocs.pm/ex_doc]

defp docs do
  [
    main: "getting-started",
    source_ref: "v#{@version}",
    source_url: @source_url,
    formatters: ["html"],
    extras: [
      "CHANGELOG.md",
      "guides/introduction/installation.md",
      "guides/introduction/getting-started.md",
      "guides/flows/registration.md",
      "guides/flows/login-and-logout.md",
      "guides/flows/password-reset.md",
      "guides/flows/mfa.md",
      "guides/flows/oauth.md",
      "guides/flows/api-authentication.md",
      "guides/flows/account-lifecycle.md",
      "guides/flows/audit-logging.md",
      "guides/recipes/testing.md",
      "guides/recipes/subdomain-auth.md",
      "guides/recipes/custom-user-fields.md",
      "guides/recipes/multi-tenant.md",
      "guides/recipes/deployment.md"
    ],
    groups_for_extras: [
      Introduction: ~r{guides/introduction/.?},
      Flows: ~r{guides/flows/.?},
      Recipes: ~r{guides/recipes/.?}
    ],
    groups_for_modules: [
      Core: [Sigra, Sigra.Auth, Sigra.Config, Sigra.Crypto],
      Plugs: ~r{Sigra.Plug.*},
      MFA: ~r{Sigra.MFA.*},
      Audit: ~r{Sigra.Audit.*},
      Testing: [Sigra.Testing]
    ]
  ]
end
```

llms.txt is auto-generated by ex_doc ≥ 0.40 with no additional config. [CITED: CLAUDE.md stack notes]

### Cookie Domain in `Sigra.Config`
```elixir
# Addition to the NimbleOptions schema in lib/sigra/config.ex (top-level key)
cookie_domain: [
  type: {:or, [:string, nil]},
  default: nil,
  doc: """
  The cookie domain applied to Sigra-managed cookies (remember-me, MFA trust).

  Set to `nil` (the default) for host-only cookies — suitable for dev, test, and
  single-domain prod deployments. Set to a string like `".example.com"` for
  subdomain auth (recognized by `app.example.com`, `api.example.com`, etc.).

  Recommended prod pattern:

      config :my_app, MyApp.Auth.Config,
        cookie_domain: System.get_env("COOKIE_DOMAIN")

  A `Logger.warning` is emitted at application boot in the `:prod` environment
  if this value is nil. See `guides/recipes/subdomain-auth.md`.
  """
]
```

### Boot-time warning in `Sigra.Application`
```elixir
# Additional private fn in lib/sigra/application.ex, called from start/2

defp maybe_warn_missing_cookie_domain do
  if Mix.env() == :prod do
    otp_app = Application.get_env(:sigra, :otp_app)
    config = otp_app && Application.get_env(otp_app, :sigra_config, [])
    cookie_domain = config[:cookie_domain]

    if is_nil(cookie_domain) do
      Logger.warning("""
      [Sigra.Config] :cookie_domain is not set in :prod.

      Remember-me and MFA trust cookies will be issued as host-only. Subdomain
      auth (app.example.com / api.example.com) will not work.

      Set a string value like ".example.com" via:

          config :my_app, MyApp.Auth.Config,
            cookie_domain: System.get_env("COOKIE_DOMAIN")

      See guides/recipes/subdomain-auth.md for details.
      """)
    end
  end
end
```

**Note on the precedent match:** `maybe_warn_audit_cleanup_fallback/0` (`lib/sigra/application.ex:28-48`) uses exactly this pattern — `Application.get_env`, conditional check, single `Logger.warning` block. [VERIFIED: lib/sigra/application.ex]

### Section comment headers for `Sigra.Testing` (D-19)

Based on the grep of all top-level `def`s in the module (see Code Insights below), the natural clusters are:

```elixir
# --- Core Assertions ---
# assert_password_hashed, assert_session_created, assert_token_sent

# --- Email ---
# assert_email_sent, extract_confirmation_token, extract_reset_token, with_test_mailer

# --- Lockout ---
# simulate_lockout, assert_rate_limited

# --- MFA ---
# setup_totp, generate_totp_code, create_backup_codes, bypass_mfa,
# simulate_mfa_lockout, assert_mfa_enabled, assert_mfa_disabled, trust_browser

# --- API Tokens ---
# create_api_token, put_bearer_token, put_api_token, assert_token_revoked,
# assert_scope_denied, expired_api_token_fixture, revoked_api_token_fixture,
# scoped_api_token_fixture, generate_jwt, expired_jwt, jwt_with_scopes

# --- Account Lifecycle ---
# scheduled_deletion_fixture, deleted_user_fixture, assert_deletion_scheduled,
# assert_deletion_cancelled, assert_account_deleted, simulate_grace_period_expiry,
# force_password_change_fixture, assert_password_changed, assert_sessions_invalidated

# --- Hooks ---
# with_hook

# --- OAuth ---
# mock_oauth_callback, create_identity, oauth_user_fixture

# --- Audit (Phase 9) ---   # NEW
# audit_event_fixture, assert_audit_event
```

Nine section headers total. Order matches the current function order in the file so no code moves — only comment lines are added.

### Example app CI job (`.github/workflows/ci.yml` fragment)
```yaml
# Source: standard pattern from erlef/setup-beam docs + Hashrocket/Felt Elixir CI guides
example_app_smoke:
  name: Example app smoke tests
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      ports: ['5432:5432']
      options: >-
        --health-cmd pg_isready --health-interval 10s
        --health-timeout 5s --health-retries 5
  steps:
    - uses: actions/checkout@v4
    - uses: erlef/setup-beam@v1
      with:
        otp-version: '27.3'
        elixir-version: '1.18.4'
    - name: Cache example deps
      uses: actions/cache@v4
      with:
        path: |
          test/example/deps
          test/example/_build
        key: ${{ runner.os }}-example-${{ hashFiles('test/example/mix.lock') }}
    - name: Fetch example deps
      working-directory: test/example
      run: mix deps.get
    - name: Compile example
      working-directory: test/example
      run: mix compile --warnings-as-errors
    - name: Setup database
      working-directory: test/example
      run: mix ecto.create && mix ecto.migrate
    - name: Run smoke tests
      working-directory: test/example
      run: mix test --include example_app
```

### `test/example/mix.exs` (minimal skeleton)
```elixir
defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.0.1",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {Example.Application, []}, extra_applications: [:logger, :runtime_tools]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:sigra, path: "../..", override: true},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:swoosh, "~> 1.5"},
      {:argon2_elixir, "~> 4.1"},
      {:oban, "~> 2.17"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"}
    ]
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-written llms.txt | ex_doc ≥ 0.40 auto-generates | ex_doc 0.40 (Jan 2026) | Zero config; Sigra is already on 0.40 |
| Guide markdown scattered in README | `guides/` directory with `:groups_for_extras` | Phoenix 1.4+, now universal | Sidebar grouping, search, llms.txt inclusion |
| Module-attribute cookie options (phx.gen.auth template) | Function-resolved at request time | N/A — this is a Sigra-specific delta | Required to support runtime-resolved `cookie_domain` |

**Deprecated/outdated:**
- `@remember_me_options` as a static module attribute — Phase 10 replaces with `remember_me_options/0`
- `Sigra.MFA.Trust.cookie_opts/0` (no argument) — Phase 10 adds `cookie_opts/1` taking config; 0-arity kept as deprecated shim
- `audit_fixtures.ex` in `test/support/` — gets consolidated into `Sigra.Testing` per D-18 (the support file can stay as a thin re-export, or be deleted once `Sigra.Testing.audit_event_fixture/1` lands)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `mfa_verified_at` is NOT a shipped field; Phase 6 transitions sessions instead of stamping a timestamp | Pitfall 3, Pattern 3 | [VERIFIED via grep 2026-04-09] — risk is that CONTEXT D-05 envisioned a field that was never built. Planner must either (a) add the field as part of Phase 10 (scope creep), or (b) redefine `mfa_complete` to mean "post-transition standard session" (recommended). |
| A2 | `AuthFixtures` can safely `import ConnCaseHelpers, only: [log_in_user: 2, log_in_user: 3]` without circular compile error | Pattern 3, Pitfall 5 | [ASSUMED] — both files live in `test/support/` and compile together. Current ConnCaseHelpers aliases `Fixtures` (i.e., `AuthFixtures`) in its `register_and_log_in_user/1` function. The mutual reference is via alias + function call, not compile-time macro invocation, so it should be safe. Planner should verify with a test-compile before relying on it. Fallback: inline the `log_in_user` body in scenario fixtures. |
| A3 | The generated `Accounts` context already exposes `sigra_config/0` as a public function | Pattern 1 | [VERIFIED: priv/templates/sigra.install/auth_fixtures.ex:96 calls `Auth.sigra_config()`] |
| A4 | ex_doc 0.40+ auto-generates `llms.txt` with no additional config | §State of the Art | [CITED: CLAUDE.md lines "0.40.x generates llms.txt and Markdown output by default"] — verified in project instructions. |
| A5 | The example app Mix project can be committed under `test/example/` with its own `mix.lock` and not pollute the root | Pattern 6 Pitfall 4 | [ASSUMED] — this is standard for umbrella-adjacent patterns but NOT an umbrella. Risk: devs running `mix deps.get` from the wrong CWD. Mitigation: document in root README and use `working-directory: test/example` in CI. |
| A6 | Phase 9 `audit_events` schema exposes `:action`, `:outcome`, `:actor_id`, `:actor_type`, `:target_id`, `:target_type`, `:metadata`, and a timestamp column | §Code Examples §Audit | [CITED: 10-CONTEXT.md D-18; test/support/audit_fixtures.ex uses `:action`, `:outcome`, `:actor_id`, `:actor_type`, `:metadata`, `:occurred_at`. Full schema verification requires reading the Phase 9 generator template — planner should grep `priv/templates/sigra.install/audit_event.ex` before finalizing the assert function's field list.] |
| A7 | `put_resp_cookie/4` accepts a `:domain` key in its options list | Pattern 1 | [VERIFIED via Plug docs — standard Plug.Conn behaviour; confirmed by LiveDashboard PR #200 cited in CONTEXT D-10] |

## Open Questions (RESOLVED)

1. **`mfa_complete` fixture session shape** — CONTEXT D-04 / D-05 reference `%UserSession{mfa_verified_at: ~U[...]}` but no such field exists in the codebase. Options:
   - **(a) Redefine `mfa_complete` as "standard session after challenge" — return `%{user, session: %{type: "standard"}, conn, totp_secret}`.** This matches Phase 6's actual transition model (`:mfa_pending` → `:standard`/`:remember_me`). Cleanest.
   - (b) Add `mfa_verified_at` to `UserSession` as a denormalization. Scope creep; should be a separate phase if needed.
   - **Recommendation: (a)** — Planner should add a note in the scenario fixture comment: "`mfa_complete` represents a post-challenge standard session; Phase 6's session type machine replaces `:mfa_pending` on successful verification rather than stamping a separate timestamp."

2. **Cookie domain threading into `Sigra.Plug.FetchSession`** — D-11 explicitly lists only `@remember_me_options` and `Sigra.MFA.Trust.cookie_opts/0` as in-scope cookie sites. But `lib/sigra/plug/fetch_session.ex:38-42` also has `@default_cookie_opts` that governs remember-me cookie writes inside the library plug itself. **Is FetchSession's cookie a separate site that also needs `cookie_domain`, or is it covered by the generated `UserAuth` refactor?** Options:
   - (a) Thread `cookie_domain` into `FetchSession` via `config.cookie_domain` at init/call time — most thorough.
   - (b) Accept that FetchSession is an alternative path not used when the generated `UserAuth` is present, document the exclusion in subdomain-auth recipe.
   - **Recommendation: (a)** — threading through a third call site is low effort and avoids a subtle footgun. Planner should confirm with a quick code trace whether `FetchSession.call/2` actually issues `put_resp_cookie` or only *reads* the cookie.

3. **`Sigra.Test.AuditFixtures` (the existing 48-line support file) vs `Sigra.Testing` additions** — D-18 says "Ship `audit_event_fixture/1` and `assert_audit_event/2` in `Sigra.Testing`". The existing support file is at `test/support/audit_fixtures.ex`. Options:
   - (a) Delete the support file; move functions to `Sigra.Testing`; update the 2-3 test files that import it.
   - (b) Keep the support file as-is for internal library tests; ship *additional* versions in `Sigra.Testing` targeted at host apps. Duplication.
   - **Recommendation: (a)** — one canonical location. Planner should `grep "Sigra.Test.AuditFixtures"` and migrate the callsites.

4. **Doctest density for `Sigra.Auth` and `Sigra.Config`** — D-14 mandates doctests but leaves density to Claude's discretion. How many doctests is "enough" for a module like `Sigra.Auth` which has 40+ public functions and requires a live repo to exercise most of them? **Recommendation:** focus doctests on pure helpers (`Sigra.Config.new/1` with options, `Sigra.Crypto.hash_password/1`) and skip ones requiring repo setup. Guides + example-app smoke tests carry the integration weight.

5. **Whether `scenario/2` should accept string names in addition to atoms** — explicitly flagged as Claude's discretion. **Recommendation:** atoms only. String coercion adds a code path without a real use case; parametric tests use `~w(...)a`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All | ✓ | 1.18.x expected | — |
| PostgreSQL | Example app smoke CI | CI only | 15 via GH Action service | — (required for example-app job) |
| ex_doc | Guide rendering | ✓ | ~> 0.40 [VERIFIED: mix.exs:52] | — |
| swoosh | Example-app reset-email smoke | ✓ | ~> 1.5 (optional dep) [VERIFIED: mix.exs:45] | — (example app adds it as a non-optional dep) |
| Mix phx.new | Initial example app scaffold | One-time | — | Commit result; subsequent runs don't need it |

No missing dependencies. The phase is pure additions using the existing dep graph.

## Validation Architecture

Nyquist validation is enabled. The four success criteria map to executable tests as follows:

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (library root) + ExUnit (test/example, separate project) |
| Config file | `test/test_helper.exs` (root); `test/example/test/test_helper.exs` (example) |
| Quick run command | `mix test test/sigra/testing_test.exs` (root) |
| Full suite command | `mix test` (root) |
| Example-app command | `cd test/example && mix test --include example_app` |
| Phase gate | Both root suite AND example-app suite green before `/gsd-verify-work` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-01 | REQUIREMENTS.md wording matches shipped signatures | doc/manual | `grep -n 'log_in_user/3\|register_user/2\|setup_totp/2\|create_api_token/3' .planning/REQUIREMENTS.md` | ❌ Wave 0 (text edit) |
| DX-01 | `Sigra.Testing.setup_totp/2` importable and returns shape | unit | `mix test test/sigra/testing_test.exs -x` | ✓ (existing coverage) |
| DX-01 | `Sigra.Testing.create_api_token/3` importable | unit | `mix test test/sigra/testing_test.exs -x` | ✓ (existing coverage) |
| DX-02 | All 15 guide files exist and ex_doc builds cleanly | build | `mix docs --warnings-as-errors` | ❌ Wave 0 (new guide files) |
| DX-02 | Getting-started walk-through works end-to-end | smoke/integration | `cd test/example && mix test test/example_web/smoke/getting_started_test.exs` | ❌ Wave 0 (new test in example) |
| DX-03 | All 7 scenario fixtures return the D-04 shapes | unit | `cd test/example && mix test test/example/fixtures_test.exs` | ❌ Wave 0 |
| DX-03 | `scenario/2` dispatcher routes correctly for all 7 atoms | unit | `cd test/example && mix test test/example/fixtures_test.exs -x --only scenario` | ❌ Wave 0 |
| DX-04 | `:cookie_domain` validates in `Sigra.Config.new/1` (string and nil) | unit | `mix test test/sigra/config_test.exs -x` | ❌ Wave 0 (extend existing config test) |
| DX-04 | `remember_me_options/0` (refactored fn) includes `:domain` when cookie_domain set | unit | `cd test/example && mix test test/example_web/user_auth_test.exs -x --only cookie_domain` | ❌ Wave 0 |
| DX-04 | `Sigra.MFA.Trust.cookie_opts/1` includes `:domain` when config set | unit | `mix test test/sigra/mfa/trust_test.exs -x --only cookie_domain` | ❌ Wave 0 |
| DX-04 | Boot-time `Logger.warning` fires in prod when cookie_domain is nil | unit | `mix test test/sigra/application_test.exs -x --only cookie_domain_warning` | ❌ Wave 0 |
| All | Example app install/compile/smoke | integration | `cd test/example && mix test --include example_app` | ❌ Wave 0 (entire example dir) |
| All | Audit helpers `audit_event_fixture/1` + `assert_audit_event/2` | unit | `mix test test/sigra/testing_test.exs -x --only audit_helpers` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** quickest affected command above (typically `mix test test/sigra/<file>_test.exs -x`)
- **Per wave merge:** `mix test && (cd test/example && mix test --include example_app)`
- **Phase gate:** Both green + `mix docs --warnings-as-errors` + `mix credo --strict` before `/gsd-verify-work`

### Wave 0 Gaps

The following test infrastructure must be created in Wave 0 before implementation plans can proceed:

- [ ] `test/sigra/application_test.exs` — new file; test the boot-time `Logger.warning` for missing cookie_domain in `:prod`
- [ ] `test/sigra/config_test.exs` — extend with `:cookie_domain` NimbleOptions validation cases (string, nil, invalid)
- [ ] `test/sigra/mfa/trust_test.exs` — extend with `cookie_opts/1` covering config with and without cookie_domain
- [ ] `test/sigra/testing_test.exs` — extend with `audit_event_fixture/1` and `assert_audit_event/2` cases; needs a minimal audit schema fixture
- [ ] `test/example/` — **entire example Mix project** is Wave 0 scaffolding:
  - `test/example/mix.exs` (see Code Examples)
  - `test/example/mix.lock` (generated by first `mix deps.get`)
  - `test/example/config/*.exs` (test, dev, config)
  - `test/example/lib/example/application.ex`, `repo.ex`, `accounts.ex` (post-install)
  - `test/example/lib/example_web/endpoint.ex`, `router.ex`, `user_auth.ex` (post-install)
  - `test/example/priv/repo/migrations/*` (generated by `mix sigra.install`)
  - `test/example/test/example_web/smoke/` — 6 smoke test files (one per D-17 flow)
  - `test/example/test/example/fixtures_test.exs` — verifies 7 scenario fixtures
  - `test/example/test/test_helper.exs` — `ExUnit.start(exclude: [:example_app])` by default; CI job uses `--include example_app`
- [ ] `.github/workflows/ci.yml` — new `example_app_smoke` job per §Code Examples
- [ ] `guides/` directory and all 15 `.md` files (empty stubs in Wave 0, content in implementation plans)
- [ ] `mix.exs` `docs/0` — extend with full `:extras` list and `:groups_for_extras` regex map

**Existing test infrastructure adequate for:** existing `Sigra.Testing` coverage (1007 LOC module has tests), existing `Sigra.Config.new/1` tests, existing `Sigra.MFA.Trust` tests, existing audit fixture file. These expand rather than get created.

## Security Domain

> `security_enforcement` is enabled by default. Phase 10 is primarily DX but touches cookie options and documented env-var patterns — both are security-adjacent.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (covered by prior phases) | — |
| V3 Session Management | yes (cookie_domain affects session + remember-me + MFA trust) | Phoenix `Plug.Conn.put_resp_cookie/4` with HttpOnly/Secure/SameSite=Lax; `:domain` from runtime config |
| V4 Access Control | no | — |
| V5 Input Validation | yes (cookie_domain string) | NimbleOptions `{:or, [:string, nil]}` type; no further validation needed (Plug accepts any string) |
| V6 Cryptography | no (guides reference shipped crypto) | — |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overly-broad cookie domain (e.g., `.com`) | Information Disclosure | Document in `subdomain-auth.md` — always lead with the leading dot, scope to your own registrable domain. Cookie prefix `__Host-` mentioned but NOT used (incompatible with `:domain`). |
| Missing cookie_domain in prod → subdomain auth silently broken | Repudiation / UX | `Logger.warning` at boot (D-09) |
| Guide code examples drifting from shipped signatures | Info Disclosure (dev confusion leading to insecure workarounds) | Doctest extraction + example-app smoke test as CI gate |
| Example app committing a real secret_key_base | Tampering | Use `System.get_env("SECRET_KEY_BASE") \|\| "test-only-key-base-#{String.duplicate("a", 64)}"` in config/test.exs. Never commit prod secrets. |
| `test/example/mix.lock` committing unpinned git deps | Supply chain | Only hex deps in example; no `{:foo, github: ...}` entries |

### Security-specific test cases to add to Wave 0
- `test/sigra/application_test.exs` — verify the boot warning fires in `:prod` when cookie_domain is nil and does NOT fire in `:dev`/`:test` or when cookie_domain is set.
- `test/sigra/config_test.exs` — assert that `:cookie_domain` rejects non-string non-nil values (e.g., an atom `:parent`) with a clear NimbleOptions error pointing to D-10's rejected atom form.
- `test/example/test/example_web/smoke/cookie_domain_test.exs` — assert that when `config.cookie_domain` is set, `put_resp_cookie` is called with `[domain: domain]` in its options list on both remember-me and MFA trust paths.

## Sources

### Primary (HIGH confidence) — verified in working tree
- `priv/templates/sigra.install/auth_fixtures.ex` (172 lines) — fixture primitives [r5]
- `priv/templates/sigra.install/user_auth.ex` (382 lines) — remember_me_options module attribute [r6]
- `priv/templates/sigra.install/conn_case_helpers.ex` (60 lines) — `log_in_user/3` canonical signature [r20]
- `priv/templates/sigra.install/mfa_challenge_controller.ex` — `maybe_set_trust_cookie` call site [r22]
- `lib/sigra/config.ex` (NimbleOptions schema) — top-level options pattern [r7, r10]
- `lib/sigra/mfa/trust.ex` (119 lines) — `@cookie_opts` + `cookie_opts/0` [r11]
- `lib/sigra/application.ex` (49 lines) — boot warning precedent [r12]
- `lib/sigra/testing.ex` (1007 lines) — 30+ functions grepped and clustered [r9, r16, r30]
- `lib/sigra/audit.ex` (405 lines) — `log/2`, `log_multi/3`, `log_safe/2` API [r15]
- `lib/sigra/session.ex`, `lib/sigra/session_stores/ecto.ex`, `lib/sigra/plug/require_mfa.ex` — session type atom/string convention [r19]
- `lib/sigra/plug/fetch_session.ex` — `@default_cookie_opts` third cookie site [r23]
- `test/support/audit_fixtures.ex` (48 lines) — existing scaffold [r13]
- `mix.exs` (79 lines) — current deps and docs config [r14]

### Secondary (HIGH confidence) — verified via WebFetch
- [Phoenix mix.exs](https://github.com/phoenixframework/phoenix/blob/main/mix.exs) — `:extras` + `:groups_for_extras` + `groups_for_modules` reference [r26, r27]
- [ex_doc readme](https://hexdocs.pm/ex_doc/readme.html) — `:extras` syntax and supported formats [r25]
- [Oban.Testing source](https://github.com/sorentwo/oban/blob/main/lib/oban/testing.ex) — monolithic testing module precedent [CITED in CONTEXT D-19]

### Tertiary (MEDIUM confidence) — ecosystem patterns
- Phoenix Files + Felt blog + Hashrocket guides — GitHub Actions Elixir CI patterns with `working-directory:` and `hashFiles('**/mix.lock')` [r28, r29]
- [phx.gen.auth context_fixtures template](https://github.com/phoenixframework/phoenix/blob/main/priv/templates/phx.gen.auth/context_fixtures_functions.ex.eex) — fixture module composition pattern [CITED in CONTEXT canonical refs]

### Cross-referenced from CLAUDE.md stack (no re-verification this session)
- ex_doc ~> 0.40 — llms.txt auto-gen
- Phoenix 1.8.5, Elixir 1.18.x, OTP 27.3.x
- swoosh ~> 1.25 — test adapter for reset-email smoke

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps, all versions already pinned in mix.exs [VERIFIED]
- Architecture (three cookie call sites, monolithic Testing, AuthFixtures composition): HIGH — all code paths read and grepped [VERIFIED]
- Pitfalls: HIGH — pitfalls 1-5 map directly to lines of code in the working tree [VERIFIED]
- Example app CI pattern: MEDIUM — based on standard Elixir community practice (Phoenix Files, Felt), not on reading an exact upstream reference implementation. Planner should cross-check a live Oban or Phoenix workflow file before finalizing.
- `mfa_verified_at` gap (Pitfall 3, Open Q1): HIGH confidence that the field does not exist; resolution approach is a planning decision.

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (30 days — shipped library code is stable; ex_doc and Phoenix versions already on current releases)

## RESEARCH COMPLETE
