---
phase: 10
plan: 05
subsystem: dx
tags: [dx, docs, doctests, guides]
requirements: [DX-02]
dependency_graph:
  requires:
    - 10-04 (guide tree scaffold + mix.exs extras wiring)
    - 10-03 (cookie_domain reference in deployment + subdomain-auth recipes)
    - 10-01 (audit helpers referenced in guides/recipes/testing.md and guides/flows/audit-logging.md)
  provides:
    - 14 fully-written Phoenix-style guides (introduction + flows + recipes)
    - getting-started.md as the ex_doc landing page (main: flipped from readme)
    - Sigra.Auth.normalize_email/1 and valid_email?/1 public pure helpers
    - 29 doctests across Sigra.Config, Sigra.Auth, Sigra.Testing
  affects:
    - mix.exs (docs main:)
    - lib/sigra/auth.ex (new pure helpers)
    - lib/sigra/config.ex (replaced placeholder doctests)
    - lib/sigra/testing.ex (expanded doctests)
    - test/sigra/doctest_test.exs (new)
tech-stack:
  added: []
  patterns:
    - "Doctest density Open Q4 resolution: full on Sigra.Testing pure helpers, lighter targeted coverage on Sigra.Auth (two new pure helpers), all common option combinations on Sigra.Config.new!/1"
    - "Bare Module.function references (no /arity) for functions whose canonical arity is ambiguous or overloaded, avoiding ex_doc resolution warnings"
    - "Fake.Repo / Fake.User atoms in Config doctests — NimbleOptions :atom validation accepts any atom so doctests run without a loaded Ecto repo"
key-files:
  created:
    - test/sigra/doctest_test.exs
  modified:
    - guides/introduction/installation.md
    - guides/introduction/getting-started.md
    - guides/flows/registration.md
    - guides/flows/login-and-logout.md
    - guides/flows/password-reset.md
    - guides/flows/mfa.md
    - guides/flows/oauth.md
    - guides/flows/api-authentication.md
    - guides/flows/account-lifecycle.md
    - guides/flows/audit-logging.md
    - guides/recipes/testing.md
    - guides/recipes/custom-user-fields.md
    - guides/recipes/multi-tenant.md
    - guides/recipes/deployment.md
    - mix.exs
    - lib/sigra/auth.ex
    - lib/sigra/config.ex
    - lib/sigra/testing.ex
decisions:
  - "D-12/D-13 enacted: 14 guides filled, getting-started is the single flagship end-to-end walkthrough (register → confirm → login → protect → logout → reset → re-login), 222 lines — targets <30 min readthrough."
  - "D-14 enacted: doctests for library primitives + guides reference shipped Sigra.Testing / Accounts / UserAuth signatures; plan 06 test/example/ will smoke-test the code blocks end-to-end."
  - "Open Q4 resolved: added two small pure helpers (normalize_email/1, valid_email?/1) to Sigra.Auth rather than forcing doctests onto repo-using functions. Matches plan text 'Skip any function that calls Repo'."
  - "Flipped mix.exs main: from \"readme\" to \"getting-started\" per plan Step F now that the landing guide has real content. README.md stays in :extras for the sidebar."
  - "Guide function references use exact shipped arities where possible (Sigra.MFA.enroll/2, Sigra.MFA.verify_totp/4). For functions whose arity is ambiguous across overloads or which ex_doc cannot resolve (Sigra.OAuth.callback, Sigra.Audit.log, Sigra.Session.sudo?), use bare Module.function to avoid warning noise."
metrics:
  duration: "~50 minutes"
  completed: "2026-04-10"
  tasks_completed: 2
  tasks_pending_checkpoint: 1
  files_changed: 18
  doctests_added: 29
  guide_lines_added: ~2300
---

# Phase 10 Plan 05: DX-02 Content + Doctests Summary

One-liner: Replaced the 14 guide stubs from plan 10-04 with full Phoenix-style content (2348 lines across installation, getting-started, 8 flows, 4 recipes), flipped the ex_doc landing page to getting-started, and added 29 doctests across `Sigra.Config`, `Sigra.Auth`, `Sigra.Testing` (including two new pure Auth helpers). DX-02 content layer is complete pending human checkpoint on the <30 min readthrough bar.

## What Was Built

### Task 1 — 14 guide bodies + docs landing flip (commit `0c85c7c`)

All 14 stub guides from plan 10-04 now have full content:

| Guide | Lines | Highlights |
|-------|-------|------------|
| `guides/introduction/installation.md` | 80 | mix.exs dep, `mix sigra.install` generated file inventory, `mix ecto.migrate`, smoke test, troubleshooting |
| `guides/introduction/getting-started.md` | 222 | **The flagship guide.** Prerequisites → register → confirm → login → protect a route → log out → reset password → click link → log in with new password. 10 numbered steps. Explicitly reinforces phx.gen.auth naming (never `create_user`, `login`, `sign_in`, `signup`). |
| `guides/flows/registration.md` | 132 | `Accounts.register_user/2`, enumeration-safe error handling, `require_confirmation: true` flag, customizing changesets, welcome-email hooks, testing |
| `guides/flows/login-and-logout.md` | 157 | `UserAuth.log_in_user/3`, remember-me cookie, session renewal for fixation defense, protecting routes, log-out-everywhere |
| `guides/flows/password-reset.md` | 156 | Enumeration-safe request, HMAC token verification, 60-min TTL, `reset_user_password/2` invalidates ALL sessions, rate limiting |
| `guides/flows/mfa.md` | 150 | TOTP enrollment with QR code, `complete_mfa_verification/4`, backup codes as single-use, trust-this-browser cookie honoring cookie_domain |
| `guides/flows/oauth.md` | 183 | Assent provider config, PKCE state flow, three callback cases (new / existing-linked / needs-linking), account linking confirmation, Cloak token encryption |
| `guides/flows/api-authentication.md` | 182 | Bearer tokens with `sigra_sk_` prefix, scoped authorization, JWT opt-in with refresh rotation + reuse detection, dual-mode session+bearer auth |
| `guides/flows/account-lifecycle.md` | 180 | `request_email_change/4` + `confirm_email_change/3`, `change_password/5` keeps current session, sudo mode gating, scheduled deletion with grace period + three strategies |
| `guides/flows/audit-logging.md` | 179 | Full event schema table, built-in event catalog, `Sigra.Audit.query`, custom event prefixes, `Sigra.Audit.log_multi` for atomicity with business ops, SIEM streaming, retention config |
| `guides/recipes/testing.md` | 191 | 7 scenario fixtures table, assertion helper list, MFA / API token / OAuth / email / audit fixtures with AAA examples, pitfalls section |
| `guides/recipes/custom-user-fields.md` | 189 | Schema extension, migration, changeset, LiveView form, fixture propagation, role-based auth, upgrade safety narrative |
| `guides/recipes/multi-tenant.md` | 173 | Row-based vs schema-based models, `tenant_id` column, session-token scoping across tenants, `Plug.Session` config for subdomain resolution, tradeoff matrix |
| `guides/recipes/deployment.md` | 215 | Env var table, `runtime.exs` wiring, cookie config in prod, Oban worker registration, Hammer rate limit tuning, Fly.io + Gigalixir specifics, secret rotation, telemetry |

Also flipped `mix.exs`:

    # Before (plan 10-04)
    main: "readme",
    # After
    main: "getting-started",

### Task 2 — Doctests across Config / Auth / Testing (commits `4855422` RED + `fa57f1e` GREEN)

**RED step (`4855422`):** Created `test/sigra/doctest_test.exs`:

    defmodule Sigra.DoctestTest do
      use ExUnit.Case, async: true

      doctest Sigra.Config
      doctest Sigra.Auth
      doctest Sigra.Testing
    end

Verified it failed on a clean tree: `doctest Sigra.Config` failed to compile because the pre-existing `iex> Sigra.Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)` expected output used `...` (syntax error, not a valid match).

**GREEN step (`fa57f1e`):**

- **`lib/sigra/auth.ex`:** Added two pure public helpers — `normalize_email/1` (trims + downcases, passes `nil` through) and `valid_email?/1` (loose regex for obvious typos, returns false for non-binary). 10 iex prompts total covering happy path, edge cases, and nil input. These helpers are genuinely useful for apps doing in-memory lookup normalization before `Accounts.get_user_by_email/1`.
- **`lib/sigra/config.ex`:** Replaced the pre-existing `...` placeholder doctest on `new!/1` with six concrete iex examples using `Fake.Repo` / `Fake.User` atoms (NimbleOptions `:atom` validation accepts any atom, so no loaded Ecto repo is required). Also replaced `MyApp.Repo` references in `oauth_enabled?/1` and `oauth_providers/1` doctests and added default-case examples for both. 20 iex prompts total covering cookie_domain (default, nil, binary), require_confirmation, session_ttl, and oauth defaults.
- **`lib/sigra/testing.ex`:** Expanded the existing `extract_confirmation_token/1` and `extract_reset_token/1` doctests to cover absolute URLs, bare paths, and dotted SFMyNTY-encoded tokens. Added new doctests to `put_bearer_token/2` and `put_api_token/2` using `Plug.Test.conn/2`. 15 iex prompts total.

Final counts (acceptance ≥ 4 / ≥ 5 / ≥ 10):

    lib/sigra/config.ex:20   (acceptance ≥ 4)
    lib/sigra/auth.ex:10     (acceptance ≥ 5)
    lib/sigra/testing.ex:15  (acceptance ≥ 10)

### Task 3 — Human verification checkpoint (PENDING)

Human-verify checkpoint — see "Checkpoint" section below.

## Must-Haves Audit

- ✅ `guides/introduction/getting-started.md` is a complete end-to-end walkthrough: 10 numbered steps from prerequisites to "log in with new password", 222 lines (≥ 200 required).
- ✅ All 14 remaining guide stubs replaced with full content; zero banned vocabulary (`create_user`, `signup`, `sign_in`) used as function names. The two matches in `rg` are (a) a migration filename `_create_users_auth_tables.exs` and (b) an explicit "never use `create_user/1` or `signup/1`" pedagogical warning in `getting-started.md` — both are benign per the acceptance criterion's compound-word exclusion.
- ✅ `Sigra.Testing` has full doctest coverage on its pure helper functions (15 iex prompts across extract_confirmation_token, extract_reset_token, put_bearer_token, put_api_token).
- ✅ `Sigra.Auth` has doctests on pure helpers — added `normalize_email/1` and `valid_email?/1` as new pure helpers (no repo setup required).
- ✅ `Sigra.Config` has doctests showing `new!/1` with common option combinations including `cookie_domain` (default nil, explicit nil, binary leading-dot).
- ⚠️ `mix docs --warnings-as-errors` — still emits 27 warnings, all pre-existing from plan 10-04 (`rg -c "LICENSE\|RateLimiter\.check_rate\|Assent\|Audit\.log_safe\|Audit\.__log_internal__"` on baseline = 27, on HEAD = 27). Zero new warnings introduced by the guide bodies or doctests. Scope boundary per `deferred-items.md` (2026-04-10 entry): pre-existing doc warnings in unrelated modules are out of scope for the content-fill-in plan.
- ✅ No doctest hard-codes secrets; `Fake.Repo` / `Fake.User` atoms used throughout. No `System.get_env` strings in doctests either — doctest values are all static.

## Must-Haves — Link Verification

- **getting-started.md → test/example/ app (plan 06):** code blocks use `Accounts.register_user/2`, `UserAuth.log_in_user/3`, `deliver_user_confirmation_instructions/2`, `deliver_user_reset_password_instructions/2`, `reset_user_password/2` — all shipped in `priv/templates/sigra.install/auth.ex` + `user_auth.ex`. `rg 'register_user' guides/` = 17 matches across 4 guides (acceptance ≥ 3).
- **guides/*.md doctests → mix test:** `test/sigra/doctest_test.exs` runs `doctest Sigra.Config`, `doctest Sigra.Auth`, `doctest Sigra.Testing` — verified `mix test test/sigra/doctest_test.exs` → 29 doctests, 0 failures.

## Verification Results

    mix test test/sigra/doctest_test.exs
    # 29 doctests, 0 failures

    mix test test/sigra/config_test.exs test/sigra/cookie_domain_test.exs \
             test/sigra/doctest_test.exs test/sigra/testing_audit_test.exs
    # 29 doctests, 68 tests, 0 failures

    mix compile --warnings-as-errors
    # clean (no warnings)

    wc -l guides/introduction/getting-started.md
    # 222 (acceptance ≥ 200)

    wc -l guides/introduction/installation.md
    # 80 (acceptance ≥ 40)

    wc -l guides/flows/*.md | tail -1
    # 1319 total (acceptance ≥ 800)

    rg -c 'register_user' guides/
    # 17 across 4 files (acceptance ≥ 3)

    rg -n 'main: "getting-started"' mix.exs
    # 73:      main: "getting-started", (acceptance: exactly 1 match)

    grep -c "iex>" lib/sigra/config.ex lib/sigra/auth.ex lib/sigra/testing.ex
    # lib/sigra/config.ex:20
    # lib/sigra/auth.ex:10
    # lib/sigra/testing.ex:15

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Pre-existing Sigra.Config doctest had syntax-invalid `...` placeholder**
- **Found during:** Task 2 RED step — `doctest Sigra.Config` failed to compile on a clean tree because the pre-existing `new!/1` doctest used `%Sigra.Config{repo: MyApp.Repo, user_schema: MyApp.User, ...}` as expected output. The `...` was a human-readable placeholder, not valid Elixir.
- **Fix:** Replaced with six concrete iex examples using `Fake.Repo` / `Fake.User` atoms (NimbleOptions `:atom` validation accepts any atom). Kept the same documentation intent.
- **Files modified:** `lib/sigra/config.ex`
- **Commit:** `fa57f1e`

**2. [Rule 2 — Missing functionality] Sigra.Auth had no public pure helpers suitable for doctests**
- **Found during:** Task 2 planning — plan 10-05 listed `normalize_email/1`, `valid_email?/1`, "token-format helpers", "password-policy helpers" as doctest candidates. Grep confirmed none existed as public functions.
- **Fix:** Added `normalize_email/1` and `valid_email?/1` as public pure helpers (≤ 20 LOC total). Both are genuinely useful — apps often normalize email for in-memory lookups before hitting the DB (citext handles DB-side case). Doctest coverage follows naturally.
- **Files modified:** `lib/sigra/auth.ex`
- **Commit:** `fa57f1e`
- **Rule:** Rule 2 — the plan assumed these helpers existed; adding them is adding missing functionality implied by the plan text, not architectural change.

**3. [Rule 3 — Blocking] Guide function references with wrong arities triggered ex_doc resolution warnings**
- **Found during:** Task 1 `mix docs --warnings-as-errors` verification
- **Issue:** Several guide bodies used `Module.function/arity` syntax with guessed arities (e.g. `Sigra.MFA.enroll/3` but actual is `/2`, `Sigra.MFA.verify_totp/3` but actual is `/4`, `Sigra.Audit.multi/4` doesn't exist, `Sigra.APIToken.cleanup_expired/1` doesn't exist, `Sigra.Session.sudo?/1` doesn't exist).
- **Fix:** Corrected arities where the function exists under a canonical name (`Sigra.MFA.enroll/2`, `Sigra.MFA.verify_totp/4`). Removed arity suffix for functions whose canonical arity is ambiguous across overloads (`Sigra.Audit.log`, `Sigra.OAuth.callback`) — ex_doc only resolves `Module.function/arity` patterns, so bare `Module.function` stays as inline code without warnings. Replaced nonexistent references (`Sigra.Audit.multi/4` → `Sigra.Audit.log_multi`, `Sigra.APIToken.cleanup_expired/1` → `Sigra.Workers.TokenCleanup.cleanup_expired_tokens/2`, `Sigra.Session.sudo?/1` → local `sudo_mode?/1` helper in example code, `Ecto.Repo.prepare_query/3` → prose).
- **Files modified:** `guides/flows/mfa.md`, `guides/flows/oauth.md`, `guides/flows/audit-logging.md`, `guides/flows/account-lifecycle.md`, `guides/flows/api-authentication.md`, `guides/recipes/multi-tenant.md`
- **Commit:** `0c85c7c` (included in Task 1 final commit)

**4. [Scope] `mix docs --warnings-as-errors` still emits 27 pre-existing warnings**
- **Found during:** Task 1 verification
- **Issue:** The verification command still exits non-zero, but all 27 warnings are pre-existing from the baseline (verified via `git stash && mix docs --warnings-as-errors 2>&1 | grep -c ...` = 27 before changes, 27 after changes).
- **Decision:** Scope boundary — pre-existing warnings in unrelated modules (OAuth strategies delegating to hidden Assent.Strategy functions, Sigra.Session referencing hidden `__log_internal__`, Sigra.RateLimiters.Hammer referencing undefined `Sigra.RateLimiter.check_rate/3`, README.md referencing missing LICENSE file) are already tracked in `deferred-items.md` (2026-04-10 entry from plan 10-04). Not fixing here.

## Checkpoint — Task 3 pending human verification

**Type:** `checkpoint:human-verify`
**Gate:** blocking

The automated portion of plan 10-05 is complete. Task 3 requires manual verification that `guides/introduction/getting-started.md` delivers the DX-02 "< 30 minute readthrough" bar.

**Pending human actions:**

1. Open `guides/introduction/getting-started.md` (222 lines, 10 numbered steps) and read end-to-end as if you were a developer new to Sigra. Start a timer.
2. Follow the code blocks mentally or literally against a scratch Phoenix app (plan 06 will also exercise them against `test/example/`).
3. Confirm readthrough took < 30 minutes.
4. Spot-check `guides/flows/mfa.md` and `guides/recipes/testing.md` for signature accuracy against shipped code.
5. Open `doc/index.html` (generated by the last `mix docs` run) — confirm sidebar has three groups (Introduction, Flows, Recipes) with all 15 guides visible.
6. Reply with `approved` or describe specific revisions needed (e.g., "getting-started step 5 is too detailed; trim plug internals").

Until resume-signal is received, this SUMMARY reflects **tasks 1-2 complete, task 3 pending**. No further orchestrator action should advance plan counter until checkpoint is resolved.

## Known Stubs

None — all 14 guide stubs are now fully written. The `guides/upgrading/` directory still contains only a `.keep` file per plan 10-04's D-12 layout (reserved for future version-migration guides, not in scope here).

## Threat Flags

None — no new network surface, auth path, file access, or schema changes. Doctests introduce zero runtime behavior changes (all iex examples are pure computations with fake module atoms). The new `Sigra.Auth.normalize_email/1` and `valid_email?/1` are pure functions with no side effects.

## Commits

| Task | Step | Commit | Files |
|------|------|--------|-------|
| 1 | Full guide bodies + mix.exs main flip | `0c85c7c` | 14 guides + mix.exs |
| 2 | RED: failing doctest runner | `4855422` | `test/sigra/doctest_test.exs` |
| 2 | GREEN: pure helpers + doctest density | `fa57f1e` | `lib/sigra/auth.ex`, `lib/sigra/config.ex`, `lib/sigra/testing.ex` |
| 3 | Pending human verification | — | — |

## Self-Check

- `[ -f guides/introduction/getting-started.md ]` → FOUND (222 lines)
- `[ -f guides/introduction/installation.md ]` → FOUND (80 lines)
- `[ -f guides/flows/registration.md ]` → FOUND (132 lines)
- `[ -f guides/flows/login-and-logout.md ]` → FOUND (157 lines)
- `[ -f guides/flows/password-reset.md ]` → FOUND (156 lines)
- `[ -f guides/flows/mfa.md ]` → FOUND (150 lines)
- `[ -f guides/flows/oauth.md ]` → FOUND (183 lines)
- `[ -f guides/flows/api-authentication.md ]` → FOUND (182 lines)
- `[ -f guides/flows/account-lifecycle.md ]` → FOUND (180 lines)
- `[ -f guides/flows/audit-logging.md ]` → FOUND (179 lines)
- `[ -f guides/recipes/testing.md ]` → FOUND (191 lines)
- `[ -f guides/recipes/custom-user-fields.md ]` → FOUND (189 lines)
- `[ -f guides/recipes/multi-tenant.md ]` → FOUND (173 lines)
- `[ -f guides/recipes/deployment.md ]` → FOUND (215 lines)
- `[ -f test/sigra/doctest_test.exs ]` → FOUND
- `grep 'main: "getting-started"' mix.exs` → FOUND at line 73
- Commit `0c85c7c` → FOUND in `git log` (Task 1)
- Commit `4855422` → FOUND in `git log` (Task 2 RED)
- Commit `fa57f1e` → FOUND in `git log` (Task 2 GREEN)

## Self-Check: PASSED
