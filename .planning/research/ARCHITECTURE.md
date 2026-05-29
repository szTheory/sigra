# Architecture Research

**Domain:** Seed-rich demo integration into a dual-role Phoenix test fixture / evaluator showcase (v1.31 DEMO-SHOWCASE)
**Researched:** 2026-05-29
**Confidence:** HIGH

## Core Architectural Problem

`test/example/` currently plays two roles that have structurally conflicting needs:

- **CI fixture role:** Headless, deterministic, sandbox-isolated. Tests create their own data via
  `Example.AccountsFixtures` and roll it back via `Ecto.Adapters.SQL.Sandbox`. The database is
  empty at test start except for what each test inserts in its sandbox transaction. Tests must not
  see, depend on, or be disrupted by data from any other source.

- **Evaluator showcase role:** Human-facing, seed-populated, persistent. An evaluator runs
  `mix setup && mix phx.server`, browses to `localhost:4000`, and sees a fully populated SaaS with
  realistic personas, organizations, MFA credentials, and OAuth identities — all already there
  without any manual steps.

The conflict: seeds write to the same database that tests use. If seeds populate the `dev`
database and tests somehow read it, determinism breaks. The resolution is structural separation by
Mix environment, enforced at the `seeds.exs` execution boundary.

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  MIX_ENV=dev  (mix setup -> mix phx.server — evaluator path)            │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  priv/repo/seeds.exs                                             │   │
│  │  -> Example.Demo.Seeds  (new module)                             │   │
│  │    ├── upsert_persona(:alice_admin)                              │   │
│  │    ├── upsert_persona(:bob_standard)                             │   │
│  │    ├── upsert_persona(:carol_invited)                            │   │
│  │    ├── upsert_persona(:dave_locked)                              │   │
│  │    ├── upsert_persona(:erin_oauth)                               │   │
│  │    └── upsert_persona(:frank_passkey)                            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│            │                                                             │
│            v                                                             │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  example_dev database (Postgres)                                 │   │
│  │  users | organizations | user_sessions | user_mfa_credentials    │   │
│  │  user_tokens | user_passkeys | audit_events | ...                │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  MIX_ENV=test  (mix test — CI fixture path)                              │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Example.DataCase  ->  SQL.Sandbox (each test owns its tx)       │   │
│  │  Example.AccountsFixtures  (factory helpers, unique integers)    │   │
│  │  -> NO seeds.exs execution (test alias skips seeds.exs)         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│            │                                                             │
│            v                                                             │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  example_test database (Postgres — separate DB name)             │   │
│  │  empty at test start; per-test sandbox transactions              │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  Playwright E2E (boots app in MIX_ENV=dev against example_dev)           │
│                                                                          │
│  golden-path.spec.ts      — registers fresh users, no seed dependency   │
│  ga-uat-shift-left.spec.ts — registers fresh users, no seed dependency  │
│  demo-showcase.spec.ts    — READS seeded personas by known email        │
│  screenshot.spec.ts       — READS seeded personas, captures baselines   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Location |
|-----------|----------------|----------|
| `priv/repo/seeds.exs` | Entry point; calls `Example.Demo.Seeds.run/0`; already wired into `mix setup` alias | existing (modify) |
| `Example.Demo.Seeds` | Seed orchestrator; idempotent upsert loop over all personas in deterministic order | new: `lib/example/demo/seeds.ex` |
| `Example.Demo.Personas` | Persona definitions as a data structure (email, password, role, orgs, MFA state, etc.) | new: `lib/example/demo/personas.ex` |
| `Example.Demo.CredentialsPage` | Dev-only LiveView or controller that renders a table of seeded credentials for evaluators | new: `lib/example_web/live/demo_credentials_live.ex` |
| `demo-showcase.spec.ts` | Playwright spec that logs in as seeded personas and exercises their specific auth state | new: `priv/playwright/tests/demo-showcase.spec.ts` |
| `screenshot.spec.ts` | Playwright spec that captures baselines of populated pages for README/docs | new: `priv/playwright/tests/screenshot.spec.ts` |
| `README.md` lane | "Try it locally" evaluator section with persona table and spin-up steps | existing (modify) |

## Isolation Strategy: The Fundamental Guarantee

The isolation guarantee rests on a single fact that already exists in the codebase:

**The `test` alias in `mix.exs` does not call `seeds.exs`:**

```elixir
# test/example/mix.exs — current state
defp aliases do
  [
    setup: ["deps.get", "ecto.setup"],
    "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
    "ecto.reset": ["ecto.drop", "ecto.setup"],
    test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],   # no seeds.exs
    precommit: [...]
  ]
end
```

The `test` alias creates the test DB and runs migrations but never calls `priv/repo/seeds.exs`.
Additionally, `config/test.exs` points to `example_test` (separate database name from
`example_dev`). Even if seeds ran in the test environment, they would write to a different
database. Seeds and tests are therefore doubly isolated: by alias omission and by database name.

No changes to the `mix.exs` `test` alias are needed to preserve CI determinism. The `setup`
alias already calls `ecto.setup`, which already calls `run priv/repo/seeds.exs`. Populating
`seeds.exs` with real content is the only change required to make `mix setup` produce a
populated dev database.

**One caveat to watch:** If seeds are ever run in MIX_ENV=test (e.g., `MIX_ENV=test mix run
priv/repo/seeds.exs`), they would write to `example_test` and break test isolation. Guard
against this at the top of `seeds.exs`:

```elixir
# priv/repo/seeds.exs
if Mix.env() == :test do
  Mix.raise("seeds.exs must not run in the test environment")
end

Example.Demo.Seeds.run()
```

## Recommended Project Structure (new + modified files)

```
test/example/
├── lib/
│   └── example/
│       └── demo/
│           ├── seeds.ex          # NEW — idempotent seed orchestrator
│           └── personas.ex       # NEW — persona definitions (data, not logic)
│   └── example_web/
│       └── live/
│           └── demo_credentials_live.ex   # NEW — dev-only credentials page
│       └── router.ex             # MODIFY — add /demo/credentials route (dev_routes guard)
├── priv/
│   └── repo/
│       └── seeds.exs             # MODIFY — call Example.Demo.Seeds.run(), add env guard
│   └── playwright/
│       └── tests/
│           ├── demo-showcase.spec.ts    # NEW — Playwright spec over seeded personas
│           └── screenshot.spec.ts      # NEW — screenshot capture for README/docs
└── README.md (test/example/ level) # MODIFY — add "Try it locally" evaluator lane
```

No new top-level files in the Sigra root. No new `examples/` directory. No separate repo.
Everything lives inside `test/example/`.

## Architectural Patterns

### Pattern 1: Upsert-by-natural-key Idempotency

**What:** Each persona is keyed on a stable, well-known email address (e.g.,
`alice@demo.sigra.dev`). The seed function uses `on_conflict: {:replace, [...]}` rather than a
bare `Repo.insert!`. This makes seeds re-runnable: running `mix run priv/repo/seeds.exs` twice
produces the same database state as running it once.

**When to use:** Always for seeds. Never use `Repo.insert!` with no conflict strategy — it fails
on the second run and leaves the evaluator with a broken `mix setup`.

**Trade-offs:** `on_conflict: :replace_all` would wipe fields the evaluator may have changed.
Use `{:replace, [:hashed_password, :confirmed_at, ...]}` to replace only the seeded canonical
fields. For association rows (org memberships, MFA credentials), use `Repo.get_by` then insert if
missing, or unique-index-backed `on_conflict: :nothing` — omitting a duplicate association on
re-seed is correct behavior.

**Example (Elixir pattern):**

```elixir
# lib/example/demo/seeds.ex
defmodule Example.Demo.Seeds do
  alias Example.Repo
  alias Example.Accounts.User

  def run do
    for persona <- Example.Demo.Personas.all() do
      upsert_user(persona)
    end
  end

  defp upsert_user(%{email: email, password: password} = persona) do
    hashed = Argon2.hash_pwd_salt(password)
    confirmed_at = if persona[:unconfirmed], do: nil, else: DateTime.utc_now()

    %User{}
    |> Ecto.Changeset.change(%{
      email: email,
      hashed_password: hashed,
      confirmed_at: confirmed_at,
      locked_at: persona[:locked_at],
      failed_login_attempts: persona[:failed_login_attempts] || 0
    })
    |> Repo.insert!(
      on_conflict: {:replace, [:hashed_password, :confirmed_at, :locked_at,
                               :failed_login_attempts, :must_change_password]},
      conflict_target: :email
    )
  end
end
```

### Pattern 2: Seeded RNG for Determinism

**What:** Seeds that need any randomness (backup code generation, TOTP secrets) must use fixed
constants per persona rather than `:crypto.strong_rand_bytes/1`. The standard approach is to
store a fixed base32-encoded TOTP secret per persona as a module attribute.

**When to use:** Wherever a seed function would otherwise produce a different result on each run.
For TOTP secrets specifically, use a fixed base32-encoded string per persona rather than calling
`NimbleTOTP.generate_secret/0`.

**Trade-offs:** A fixed TOTP secret means the evaluator can scan the QR code and the code in
their authenticator app matches the secret that `ecto.reset` will always restore. If the secret
regenerated on every seed run, the evaluator's authenticator app would stop working. Fixed
constants are correct here.

**Example:**

```elixir
# lib/example/demo/personas.ex
defmodule Example.Demo.Personas do
  # Fixed TOTP secrets for MFA-enabled personas.
  # These are dev-demo constants — not production secrets.
  # Standard base32, compatible with NimbleTOTP and authenticator apps.
  @alice_totp_secret "JBSWY3DPEHPK3PXP"

  def all do
    [
      %{
        name: "Alice Admin",
        email: "alice@demo.sigra.dev",
        password: "DemoPassw0rd!",
        role: :admin,
        mfa_totp_secret: @alice_totp_secret,
        organizations: ["Acme Corp", "Beta Inc"]
      },
      # ... other personas
    ]
  end
end
```

### Pattern 3: Env-gated Dev-only Credentials Page

**What:** A `/demo/credentials` route exists only when `dev_routes: true` is configured (the same
guard used by Phoenix's dev-only mailbox and dashboard routes). It renders a table of all seeded
personas with email, password, and current auth state. This is the "cheat sheet" for evaluators
who don't want to read the README.

**When to use:** Always — this is the lowest-friction evaluator affordance and the single place
where demo credentials are canonical.

**Trade-offs:** Must be guarded behind `Application.compile_env(:example, :dev_routes)` in the
router so it is completely absent from any non-dev path. The route should be excluded from
Playwright's golden-path specs.

**Example (router guard):**

```elixir
# lib/example_web/router.ex
if Application.compile_env(:example, :dev_routes) do
  scope "/demo", ExampleWeb do
    pipe_through :browser
    live "/credentials", DemoCredentialsLive, :index
  end
end
```

## Data Flow

### Seed Execution Flow (mix setup)

```
mix setup
  -> deps.get
  -> ecto.setup
      -> ecto.create          (creates example_dev if absent)
      -> ecto.migrate         (runs all migrations)
      -> run priv/repo/seeds.exs
            -> env guard (raises if MIX_ENV=test)
            -> Example.Demo.Seeds.run/0
                -> for each persona: upsert_user/1
                    -> Argon2.hash_pwd_salt (seeded password, ~200ms each)
                    -> Repo.insert! with on_conflict
                -> for each persona with MFA: upsert_totp_credential/1
                    -> stores fixed TOTP secret (no random generation)
                    -> stores hashed backup codes (8 fixed codes per persona)
                -> for each org: upsert_organization/1
                    -> for each membership: upsert_membership/1
```

### Test Execution Flow (mix test)

```
mix test
  -> ecto.create --quiet      (creates example_test if absent — separate DB)
  -> ecto.migrate --quiet     (runs migrations on example_test)
  -> test                     (seeds.exs is NEVER called)
      -> each test: Example.DataCase.setup_sandbox
          -> SQL.Sandbox.start_owner! (test owns a transaction)
          -> test body: Example.AccountsFixtures.user_fixture/1 etc.
          -> on_exit: SQL.Sandbox.stop_owner (rolls back all inserts)
```

### Playwright Demo Spec Flow

```
demo-showcase.spec.ts boots against MIX_ENV=dev (localhost:4000)
  -> login as alice@demo.sigra.dev with known password
  -> assert admin panel is visible (proves admin role seeded)
  -> login as dave@demo.sigra.dev with known password
  -> assert account locked message (proves locked state seeded)
  -> login as alice@demo.sigra.dev, navigate to MFA settings
  -> assert TOTP enabled (proves MFA credential seeded)
```

This spec is NOT run in the CI `mix test` lane. It runs in the Playwright lane that boots the dev
server, which already depends on seeds being present. The spec is correctly coupled to seeded data
— it is testing the demo presentation, not the Sigra auth library internals.

### Playwright Golden-Path Spec (unchanged, no seed coupling)

All existing specs (`golden-path.spec.ts`, `ga-uat-shift-left.spec.ts`, etc.) register fresh
users with `Date.now()` suffixes in emails (`lifecycle-${Date.now()}@example.test`). They have
zero dependency on seeded personas. No changes needed. CI determinism is preserved because:

1. Golden-path specs create their own data dynamically.
2. Seeded personas use a `@demo.sigra.dev` email domain that golden-path specs never reference.
3. The test DB (`example_test`) never receives seeds.

## Build Order / New vs Modified File Map

Build in this order to respect dependencies:

### Step 1 — Seed Data Layer (no UI dependencies)

| File | Action | Why first |
|------|--------|-----------|
| `lib/example/demo/personas.ex` | NEW | Pure data module; no deps on anything else |
| `lib/example/demo/seeds.ex` | NEW | Depends on personas.ex and Accounts context |
| `priv/repo/seeds.exs` | MODIFY | Calls Seeds.run/0; add env guard |

Verify: `MIX_ENV=dev mix run priv/repo/seeds.exs` succeeds and is idempotent (run twice, same DB
state). Verify: `MIX_ENV=test mix run priv/repo/seeds.exs` raises with a clear error.

### Step 2 — Dev Credentials Page (depends on Step 1: needs persona list)

| File | Action | Why here |
|------|--------|----------|
| `lib/example_web/live/demo_credentials_live.ex` | NEW | renders persona table from Personas module |
| `lib/example_web/router.ex` | MODIFY | add dev-only `/demo/credentials` route |

Verify: `mix phx.server` (dev), visit `/demo/credentials`, see persona table with correct entries.

### Step 3 — Playwright Demo Spec (depends on Step 1: seeds must exist)

| File | Action | Why here |
|------|--------|----------|
| `priv/playwright/tests/demo-showcase.spec.ts` | NEW | exercises seeded personas over browser |
| `priv/playwright/playwright.config.ts` | MODIFY | add `demo-showcase` project partition |

The new `demo-showcase.spec.ts` pattern:
- Reads personas by their stable `@demo.sigra.dev` email addresses
- Does NOT generate fresh accounts (contrast with golden-path)
- Asserts auth-state-specific behavior: admin panel visible for alice, lock screen for dave, MFA
  enabled for alice
- Tagged/isolated so it does not run when the DB has not been seeded

### Step 4 — Screenshot Script (depends on Step 3: Playwright working)

| File | Action | Why last |
|------|--------|----------|
| `priv/playwright/tests/screenshot.spec.ts` | NEW | capture populated pages for README |

### Step 5 — README Evaluator Lane (depends on Step 4: screenshots exist)

| File | Action | Why last |
|------|--------|----------|
| `test/example/README.md` (create if absent) or root README | MODIFY | add "Try it locally" section |

## Crypto at Seed Time

The example app uses `Example.Accounts.Encrypted.Binary` as a passthrough (no-op) type — not
real `Cloak.Ecto`. The module's own docstring states: "A production app MUST replace this with a
real `Cloak.Ecto.Binary` subtype backed by a `Cloak.Vault`."

This means:
- TOTP secrets stored in `user_mfa_credentials.encrypted_secret` are NOT actually encrypted in
  the dev database. The passthrough type stores the raw binary as-is.
- OAuth access/refresh tokens (if any seeded persona has OAuth) are similarly unencrypted.

This is acceptable for a local dev demo. Seeds must store the TOTP secret in the format the
passthrough type expects: a raw binary string (not a cloak ciphertext envelope).

Password hashing at seed time is the main latency concern. The fast Argon2 config (`t_cost: 1,
m_cost: 8`) is in `config/test.exs` only. Seeds run under `MIX_ENV=dev` which uses
production-equivalent Argon2 parameters (~200-500ms per hash). With 6 personas:

- Total seed time: ~1.2 – 3 seconds for password hashing alone
- Acceptable for a one-time `mix setup`; this is why tests use the fast config and never call seeds

If seed time becomes a concern, precompute hashed passwords as known-good constants using
`mix run -e "IO.puts Argon2.hash_pwd_salt(\"DemoPassw0rd!\")"` and store them as module
attributes. This reduces seed runtime to near-zero at the cost of a one-time precomputation step.

Recommendation: do not precompute for v1.31. Accept the ~2-3s seed time; document it. Only
precompute if evaluator feedback identifies `mix setup` speed as a friction point.

## Integration Points

### Existing Boundaries (unchanged)

| Boundary | How Demo Seeds Interact | Notes |
|----------|------------------------|-------|
| `Example.Accounts.register_user/1` | Seeds should call through it for initial user creation | Fires audit rows, handles normalization; seeds then patch `confirmed_at` via direct `Repo.update!` |
| `Sigra.Testing.setup_totp/2` | Seeds can call it directly for MFA credential creation | Available in all envs (not test-only); correct way to populate credential schema |
| `Example.Repo` | Seeds write directly via Repo for fields context API does not expose | No sandbox; writes persist to `example_dev` DB |
| `SQL.Sandbox` | Tests use it; seeds never interact with it | Completely separate execution path |

### New Integration Points

| Boundary | Pattern | Notes |
|----------|---------|-------|
| `Example.Demo.Seeds` vs `Example.Accounts` context | Prefer context API; use direct Repo writes only for fields context does not expose (confirmed_at, locked_at) | Context calls fire correct audit events |
| `demo-showcase.spec.ts` vs dev server | Playwright connects to localhost:4000; server must be running with seeded DB | In CI: launch server in background, verify seeded, then run Playwright |
| `DemoCredentialsLive` vs `Example.Demo.Personas` | LiveView reads persona list at mount time from module attribute | No DB query needed; `personas.ex` is the source of truth for displayed credentials |

## Critical Architectural Risk and Mitigation

### Risk: Demo Seeds Breaking CI Determinism

**What could go wrong:** A future CI job inadvertently runs seeds in the test database, or a
Playwright spec references seeded personas in a context where the DB has not been seeded.

**Why this is the single biggest risk:** All other risks (seed idempotency, credential page
exposure, screenshot flakiness) are recoverable with a one-line fix. This risk could silently
corrupt CI reliability — tests pass locally with seeds, fail in CI without seeds, or vice versa.

**Concrete failure modes:**

1. A future CI step adds `mix setup` (which calls seeds) before `mix test`. Seeds run in
   `MIX_ENV=test`, write to `example_test`, tests see unexpected rows causing test failures or
   false positives due to unique-constraint conflicts on email.

2. A Playwright golden-path spec is updated to use a hard-coded email like `alice@demo.sigra.dev`
   (copying from the credentials page) instead of a fresh `Date.now()` address. The spec becomes
   dependent on seeded data and fails whenever the DB is reset without re-seeding.

3. The `demo-showcase.spec.ts` is added to the existing Playwright `chromium` project instead of
   a dedicated project. It runs in CI alongside golden-path specs where seeds may not be present.

**Mitigations (in priority order):**

1. **Hard env guard in `seeds.exs`:** `if Mix.env() == :test, do: Mix.raise(...)`. This makes
   accidental test-env seeding a loud failure rather than silent corruption. Most important
   mitigation. Two lines. Ship it.

2. **Reserve `@demo.sigra.dev` as the seed email domain.** All seeded personas use
   `*@demo.sigra.dev` emails. All Playwright golden-path specs use `*@example.test` emails with
   `Date.now()` suffixes. The domain difference is visually distinct in code review. Any spec
   using `@demo.sigra.dev` is immediately recognizable as seed-coupled.

3. **Playwright demo spec goes in a dedicated CI project.** Put `demo-showcase.spec.ts` in a
   separate Playwright project (`demo-showcase`) in `playwright.config.ts`. Exclude it from the
   `chromium` and `mobile` projects via `testIgnore`. The demo lane only runs when the dev server
   is pre-seeded. This mirrors the existing partition pattern already established in the config
   (ADMIN_BEHAVIOR_SPECS, ADMIN_CHECKPOINTS_SPEC, etc.).

4. **Do not modify the `test` alias.** The `test: ["ecto.create --quiet", "ecto.migrate --quiet",
   "test"]` alias is the invariant that preserves CI determinism. No seeds clause is ever added.

## Anti-Patterns

### Anti-Pattern 1: Seeds in the Test Alias

**What people do:** Add `run priv/repo/seeds.exs` to the `test` alias in `mix.exs` to make test
data "richer" or to pre-populate state for Playwright tests.

**Why it's wrong:** Breaks sandbox isolation. Tests see rows they did not insert. Ordering-
dependent test failures emerge. Async tests will see each other's seeded state. Seeds run with
`MIX_ENV=test` parameters and produce different behavior than dev.

**Do this instead:** Keep seeds out of the test alias entirely. Tests create all their own data
via `Example.AccountsFixtures`. Seeds are only for the dev database.

### Anti-Pattern 2: Hard-coded UUIDs in Seeds

**What people do:** Specify fixed UUID primary keys in seed upserts (e.g., `id:
"00000000-0000-0000-0000-000000000001"` for alice) to enable stable cross-references.

**Why it's wrong:** Any foreign key in another seed or fixture that references this UUID will
break if applied to a database where that UUID is already taken. Creates false coupling.

**Do this instead:** Let UUIDs be database-generated. Key all upserts on the natural key (email
for users, slug for organizations). Fetch the generated ID after upsert when cross-referencing.

### Anti-Pattern 3: Playwright Demo Spec in the Golden-Path Lane

**What people do:** Add demo-aware assertions to `golden-path.spec.ts` (e.g., "log in as alice
and check admin panel").

**Why it's wrong:** `golden-path.spec.ts` runs in CI against a server that may or may not be
seeded. If seeds are not present, the spec fails because alice does not exist.

**Do this instead:** Keep demo-coupled assertions in `demo-showcase.spec.ts` only. Run that spec
in a dedicated Playwright project that explicitly depends on seeds. The golden-path spec continues
to register fresh users and has zero dependency on seeded personas.

### Anti-Pattern 4: Bypassing Context API for All Seed Writes

**What people do:** Bypass the `Example.Accounts` context and write directly to schemas for every
seed insert (e.g., `%User{} |> Repo.insert!` without going through `Accounts.register_user`).

**Why it's wrong:** Context functions fire audit events, trigger optional-dep hooks (Oban jobs,
Threadline forwarder), and validate invariants. Seeds that bypass the context will produce a
database state that looks wrong to anyone inspecting audit logs — the demo becomes untrustworthy
as a representation of how Sigra actually works.

**Do this instead:** Seed through `Accounts.register_user` then patch fields the API does not
expose (like `confirmed_at`, `locked_at`) via a direct `Repo.update!` with a plain changeset.
For MFA enrollment, use `Sigra.Testing.setup_totp/2` which is available in all environments and
correctly populates the credential schema.

## Sources

- `test/example/mix.exs` — aliases (setup / test / ecto.setup) confirming seeds.exs execution path (HIGH confidence, direct inspection)
- `test/example/priv/repo/seeds.exs` — currently empty; `ecto.setup` alias confirmed as the entry point (HIGH confidence)
- `test/example/config/test.exs` — separate `example_test` DB + `Ecto.Adapters.SQL.Sandbox` pool (HIGH confidence)
- `test/example/config/dev.exs` — `example_dev` DB; no sandbox pool (HIGH confidence)
- `test/example/test/support/fixtures/auth_fixtures.ex` — all test data factory patterns; `System.unique_integer()` suffix and `@example.com` domain convention (HIGH confidence)
- `test/example/priv/playwright/playwright.config.ts` — Playwright project partitioning pattern to follow for demo-showcase isolation (HIGH confidence)
- `test/example/priv/playwright/helpers/fixtures.ts` — `@example.test` domain convention for golden-path specs (HIGH confidence)
- `test/example/lib/example/accounts/encrypted.ex` — passthrough cloak type; confirms encryption is no-op in example app (HIGH confidence)
- `test/example/lib/example/accounts/user_mfa_credential.ex` — `encrypted_secret` field type; seeding TOTP secrets requires raw binary compatible with passthrough type (HIGH confidence)
- `.planning/MILESTONE-ARC.md` — DEMO-SHOWCASE scope: extend test/example, not separate repo; Phase 114 nested-app-drift cost already paid (HIGH confidence)
- `.planning/PROJECT.md` — v1.31 goal: idempotent deterministic seeds.exs, one-command spin-up (HIGH confidence)

---
*Architecture research for: v1.31 DEMO-SHOWCASE — dual-role CI fixture + evaluator showcase*
*Researched: 2026-05-29*
