# Phase 137: Optional-Dependency Source of Truth - Research

**Researched:** 2026-05-29
**Domain:** Elixir optional-dependency guarding (`Code.ensure_loaded?/1` consolidation), internal refactor with zero runtime behavior change
**Confidence:** HIGH (all call sites verified against live code at HEAD on `v1.28-data-lifecycle`)

## Summary

This is a tightly-scoped internal refactor. The design is LOCKED in `137-CONTEXT.md` (D-01..D-10); this research does not re-litigate it. The job was to verify the exact runtime-guard call-site set against the live code, confirm the encryption-predicate reality, confirm the dep-off CI proof surface, and produce a Validation Architecture.

**Reality check confirmed (HIGH):** `Sigra.OptionalDeps` does NOT exist. `grep -r "Sigra.OptionalDeps" lib/` returns ZERO hits [VERIFIED: grep this session]. The v1.21 HARD-02 narrative (PROJECT.md:136, MILESTONES.md:738) and ROADMAP "Depends on" line (ROADMAP.md:54) claim it shipped — they are wrong. `.planning/research/ARCHITECTURE.md:12` and `PITFALLS.md:19` independently corroborate the module's absence. This is a fresh creation; there is no precedent module to extend.

**The grep-total trap is real and confirmed.** `grep -rn "Code.ensure_loaded?" lib/` returns **44 hits** [VERIFIED: grep this session], far more than the ~14 genuine in-scope runtime optional-dep guards. The enumeration below separates the four categories so the planner does not anchor on the raw total.

**Two drift items found in CONTEXT.md's Integration Points** (flagged below): (1) CONTEXT.md omits two additional Bcrypt runtime guards in `lib/sigra/hashers/bcrypt.ex:39,48`; (2) the Swoosh and Req predicates required by OD-01 have **no in-scope runtime delegation target** in `lib/` — they are SOT-completeness predicates only, not OD-02 delegation work. Both are clarifications, not design changes.

**Primary recommendation:** Create `lib/sigra/optional_deps.ex` with the nine flat zero-arity predicates (D-01) plus the config-driven encryption predicate (D-07); rewrite the ~14 runtime guards enumerated below to delegate; leave the 7 compile-time `defmodule` wrappers and the ~13 dynamic-module/tooling/test-helper guards untouched; prove no-behavior-change via the Threadline dep-off lane PLUS per-predicate unit tests (the falsy branch of 8 of 9 predicates is not exercised by any existing CI lane — unit tests are the primary proof there).

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `Sigra.OptionalDeps` exposes one zero-arity predicate per guarded dependency (`oban_available?/0`, `bcrypt_available?/0`, `eqrcode_available?/0`, `threadline_available?/0`, `assent_available?/0`, `swoosh_available?/0`, `joken_available?/0`, `hammer_available?/0`, `req_available?/0`), each a thin wrapper over `Code.ensure_loaded?(TheModule)`. NOT a single `available?(dep_atom)` dispatcher.
- **D-02:** Module lives at `lib/sigra/optional_deps.ex`, top-level under `Sigra.`, sibling to `lib/sigra/rate_limiter.ex`.
- **D-03:** Predicates are pure, side-effect-free, un-memoized thin wrappers — one-to-one with the inline checks. No caching (a dep may be loaded later in dev/test).
- **D-04:** `defmodule`-wrapping guards stay literal `Code.ensure_loaded?` and do NOT delegate (compile-ordering/circularity hazard). Only in-function-body runtime guards delegate.
- **D-05:** SC#2's "all guards delegate" is scoped to runtime call-site guards. Compile-time wrappers documented as out-of-scope-for-delegation in `@moduledoc`.
- **D-06:** Compound guards delegate only the load half; the liveness/arity half stays at the call site.
- **D-07:** Encryption gets NO `cloak_available?/0` load predicate. It is gated by the config-driven `__sigra_encryption_mode__/0` stub-vs-real check (`application.ex` `verify_vault!`), NOT `Code.ensure_loaded?(Cloak)`. Any encryption predicate must mirror the stub-mode check, not invent a load check.
- **D-08:** Out of scope (NOT delegated): dynamic-module guards on variables, the 2 Credo-check wrappers, the 2 test-helper guards.
- **D-09:** In-scope genuine optional-dep guard count is ≈14 sites, NOT the ~29/44 a naive grep returns. Enumerate the exact set.
- **D-10:** The `mix.exs` `no_warn_undefined` whitelist (~65-91) is unchanged. `Code.ensure_loaded?/1` inside the SOT takes a module atom, generates no compile warnings, adds no whitelist entries.

### Claude's Discretion

- Exact wording of the `@moduledoc` scope note (D-05).
- Test-file layout for the SOT unit tests.
- Whether the encryption predicate (D-07) is named `encryption_active?/1` or similar.

### Deferred Ideas (OUT OF SCOPE)

- `mix sigra.doctor` — Phase 138 (consumes this SOT).
- Memoizing/caching availability — explicitly rejected (D-03).
- A single `available?(dep_atom)` dispatcher — rejected (D-01).
- Any runtime behavior change in optional-dep handling — REQUIREMENTS.md Out-of-Scope row.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OD-01 | `Sigra.OptionalDeps` exposes per-dep `available?/0` for every optional dep guarded today (Oban, Bcrypt, EQRCode, Threadline, Assent, Swoosh, Joken, cloak/encryption) | D-01 enumerates the 9 flat predicates; D-07 the encryption predicate. NOTE: `swoosh_available?/0` and `req_available?/0` have no in-scope runtime delegation target (see "Runtime Guard Inventory" / drift items) — they exist for SOT completeness and Phase 138 consumption only. |
| OD-02 | Scattered `Code.ensure_loaded?` guards delegate to the SOT, no runtime behavior change — proven by dep-off CI lanes staying green | The exact ~14-site delegation set is enumerated below with current file:line. Proof surface: Threadline dep-off lane (ci.yml:170) + per-predicate unit tests (see Validation Architecture — the falsy branch of 8/9 predicates is NOT covered by any dep-off lane). |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| "Is optional dep X loaded?" | Library (`Sigra.OptionalDeps`) | — | New SOT; the canonical owner of every `Code.ensure_loaded?(OptionalDep)` truth value |
| Runtime feature branching on dep presence | Library call sites (crypto, mfa, jwt, plug, oauth, delivery, forwarders, deletion, validation) | `Sigra.OptionalDeps` | Call sites keep their control flow; only the load-check expression delegates |
| Compile-time conditional module definition | Library (`workers/*.ex`, `forwarders/threadline.ex`) | — | Stays literal `Code.ensure_loaded?` — runs at compile time before SOT may be compiled (D-04) |
| Encryption posture (stub vs real vault) | Host config + `application.ex verify_vault!` | `Sigra.OptionalDeps` (mirror only) | Config-driven, not load-driven (D-07); SOT mirrors the stub check, does not own it |

## Standard Stack

No new dependencies. This phase adds one library module and rewrites existing guard expressions. The relevant existing stack:

| Element | Location | Role in this phase |
|---------|----------|--------------------|
| `Code.ensure_loaded?/1` | Elixir stdlib | The exact primitive each predicate wraps one-to-one (D-03) [VERIFIED: live code] |
| `Sigra.RateLimiter` triad | `lib/sigra/rate_limiter.ex` + `rate_limiters/{hammer,noop}.ex` | Module-shape/location precedent for the new top-level module (D-02) [VERIFIED: read this session] |
| `no_warn_undefined` whitelist | `mix.exs:65-91` | Unchanged (D-10); already lists Bcrypt, Hammer, Swoosh.Email, Threadline.*, Oban.*, Assent.Strategy.*, Joken.*, EQRCode [VERIFIED: read this session] |

**No `npm`/`pip`/`cargo`/`mix` install step.** No external packages added — Package Legitimacy Audit is N/A (no new deps; see note below).

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. The nine deps the SOT references (Oban, bcrypt_elixir, eqrcode, threadline, assent, swoosh, joken, hammer, and the transitive `req`) are all already present in the project: eight are declared `optional: true` in `mix.exs:107-117` [VERIFIED: read this session], and `req` is a transitive dep (see drift item #2). No new `mix.exs` entries.

## Runtime Guard Inventory (the exact delegation set)

This is the load-bearing output of the research. Every `Code.ensure_loaded?` hit in `lib/` (44 total [VERIFIED: grep this session]) is classified into one of four buckets.

### Bucket A — IN SCOPE: runtime guards that MUST delegate to the SOT

| # | File:line | Current expression | Optional dep | SOT predicate | Notes |
|---|-----------|--------------------|--------------|----------------|-------|
| 1 | `lib/sigra/crypto.ex:244` | `if Code.ensure_loaded?(Bcrypt) do` | Bcrypt | `bcrypt_available?/0` | In `bcrypt_verify/2` private helper |
| 2 | `lib/sigra/hashers/bcrypt.ex:39` | `if Code.ensure_loaded?(Bcrypt) do` | Bcrypt | `bcrypt_available?/0` | **DRIFT: not in CONTEXT.md.** In `no_user_verify/0`; else-branch falls back to Argon2 timing |
| 3 | `lib/sigra/hashers/bcrypt.ex:48` | `unless Code.ensure_loaded?(Bcrypt) do` | Bcrypt | `bcrypt_available?/0` | **DRIFT: not in CONTEXT.md.** In `ensure_loaded!/0` raise guard |
| 4 | `lib/sigra/mfa.ex:1059` | `if Code.ensure_loaded?(EQRCode) do` | EQRCode | `eqrcode_available?/0` | In `generate_qr_svg/1`; else returns `nil` |
| 5 | `lib/sigra/jwt/signer.ex:18` | `unless Code.ensure_loaded?(Joken) do` | Joken | `joken_available?/0` | In `ensure_joken!/0` raise guard |
| 6 | `lib/sigra/plug/rate_limit.ex:85` | `if Code.ensure_loaded?(Hammer) do` | Hammer | `hammer_available?/0` | In `resolve_limiter(nil)`; else → Noop + warn |
| 7 | `lib/sigra/oauth/strategies/apple.ex:76` | `unless Code.ensure_loaded?(Assent) do` | Assent | `assent_available?/0` | In `ensure_assent!/0` raise guard |
| 8 | `lib/sigra/oauth/strategies/facebook.ex:80` | `unless Code.ensure_loaded?(Assent) do` | Assent | `assent_available?/0` | Identical shape |
| 9 | `lib/sigra/oauth/strategies/github.ex:77` | `unless Code.ensure_loaded?(Assent) do` | Assent | `assent_available?/0` | Identical shape |
| 10 | `lib/sigra/oauth/strategies/generic.ex:83` | `unless Code.ensure_loaded?(Assent) do` | Assent | `assent_available?/0` | Identical shape |
| 11 | `lib/sigra/oauth/strategies/google.ex:74` | `unless Code.ensure_loaded?(Assent) do` | Assent | `assent_available?/0` | Identical shape |

**CONTEXT.md cited `oauth/strategies/{generic,google,facebook,github,apple}.ex` without line numbers — all five verified present, line numbers above.** [VERIFIED: read this session]

### Bucket A (compound) — IN SCOPE: delegate the LOAD HALF ONLY (D-06)

| # | File:line | Current expression | Delegate to | Keep at call site |
|---|-----------|--------------------|-------------|---------------------|
| 12 | `lib/sigra/delivery.ex:114` | `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil` | `oban_available?/0` | `and Process.whereis(Oban) != nil` |
| 13 | `lib/sigra/audit/forwarders.ex:99` | `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil` | `oban_available?/0` | `and Process.whereis(Oban) != nil` — **NOTE: this is the `:error` (production) branch of a `case` inside `oban_running?/1`; the `{:ok, oban_override}` test branch at line 94 does NOT contain a `Code.ensure_loaded?` and must NOT change** [VERIFIED: read this session, forwarders.ex:90-101] |
| 14 | `lib/sigra/enterprise_connections/validation.ex:91` | `Code.ensure_loaded?(Req) and function_exported?(Req, :get, 1)` | `req_available?/0` | `and function_exported?(Req, :get, 1)` |
| 15 | `lib/sigra/account/deletion.ex:307` | `with true <- Code.ensure_loaded?(Oban),` | `oban_available?/0` | `with true <- ...` structure |
| — | `lib/sigra/account/deletion.ex:308` | `true <- Code.ensure_loaded?(Sigra.Workers.AccountDeletion),` | **DO NOT delegate** | `Sigra.Workers.AccountDeletion` is a Sigra-internal conditionally-compiled worker, NOT a named optional dep — belongs to Bucket C, not the SOT. **CONTEXT.md D-06 says "delegate each `Code.ensure_loaded?` leg" — research flags this as a clarification: only the `Oban` leg (307) is in scope; the worker-module leg (308) is a dynamic/internal-module check.** |

**Genuine in-scope runtime guard count: 15 expressions across 12 files** (line 308 excluded; the 5 OAuth strategies are 5 identical sites). This reconciles with D-09's "≈14 sites" — the gap is the two Bcrypt sites CONTEXT.md missed (drift item #1) minus rounding. Plan to the enumerated set, not a count.

### Bucket B — OUT OF SCOPE: compile-time `defmodule`-wrapping guards (stay literal, D-04)

| File:line | Expression | Why excluded |
|-----------|------------|--------------|
| `lib/sigra/workers/account_deletion.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | Compile-time module def; SOT may not be compiled yet (D-04) |
| `lib/sigra/workers/audit_cleanup.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | Same |
| `lib/sigra/workers/audit_forward.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | Same |
| `lib/sigra/workers/cleanup_expired_invitations.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | Same |
| `lib/sigra/workers/email_delivery.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | Same |
| `lib/sigra/workers/token_cleanup.ex:1` | `if Code.ensure_loaded?(Oban.Worker) do` | Same |
| `lib/sigra/audit/forwarders/threadline.ex:1` | `if Code.ensure_loaded?(Threadline) do` | Same |

7 compile-time wrappers [VERIFIED: grep this session]. All `:1` guards confirmed. (CONTEXT.md D-04 listed 6 worker files; the live tree has 6 worker `:1` guards + the threadline forwarder `:1` = 7 total — matches.)

### Bucket C — OUT OF SCOPE: dynamic-module / internal-module guards (D-08)

| File:line | Expression | Why excluded |
|-----------|------------|--------------|
| `lib/sigra/account/deletion.ex:308` | `Code.ensure_loaded?(Sigra.Workers.AccountDeletion)` | Sigra-internal conditionally-compiled worker, not a named optional dep |
| `lib/sigra/admin/audit/export.ex:169` | `Code.ensure_loaded?(schema)` | Variable (host schema module) |
| `lib/sigra/admin/users/detail.ex:270` | `Code.ensure_loaded?(schema)` | Variable |
| `lib/sigra/admin/users/query.ex:718` | `Code.ensure_loaded?(schema)` | Variable |
| `lib/sigra/application.ex:108` | `unless Code.ensure_loaded?(module)` | Variable (configured forwarder module) |
| `lib/sigra/application.ex:154` | `if Code.ensure_loaded?(module)` | Variable |
| `lib/sigra/application.ex:192` | `Code.ensure_loaded?(module)` | Variable (host `Encrypted.Binary` module); part of the D-07 encryption check, NOT a load gate |
| `lib/sigra/application.ex:77` | `Code.ensure_loaded?(Oban) ->` | Boot-warning `cond` in `maybe_warn_audit_cleanup_fallback/0`. **JUDGMENT CALL: this IS a named-dep (`Oban`) literal load check at runtime.** It is technically eligible to delegate to `oban_available?/0`. CONTEXT.md does not list it. Recommend the planner treat it as an OPTIONAL stretch delegation (it is a one-shot boot warning, behavior is identical either way) but it is safe to EXCLUDE to keep the phase minimal. Flagged for a planner decision. |
| `lib/sigra/workers/audit_forward.ex:174` | `if Code.ensure_loaded?(module) do` | Variable |
| `lib/sigra/install.ex` / `sigra.install.ex:153` | `Code.ensure_loaded?(repo_module)` | Variable (host repo) |

### Bucket D — OUT OF SCOPE: tooling + test-helper guards (D-08)

| File:line | Expression | Why excluded |
|-----------|------------|--------------|
| `lib/sigra/credo/no_log_safe2_in_lib.ex:1` | `if Code.ensure_loaded?(Credo.Check) do` | Credo-check wrapper (tooling) |
| `lib/sigra/credo/no_unscoped_org_query_in_lib.ex:1` | `if Code.ensure_loaded?(Credo.Check) do` | Credo-check wrapper |
| `lib/mix/tasks/sigra.fixture.rebless_golden.ex:86` | `unless Code.ensure_loaded?(InstallFixture) do` | Test-helper guard |
| `lib/sigra/testing.ex:98` | `if Code.ensure_loaded?(Swoosh.TestAssertions) do` | **The ONLY Swoosh `ensure_loaded?` in `lib/`** — a test-helper guard on `Swoosh.TestAssertions`. Out of scope. See drift item #2. |

## Encryption Predicate Reality (D-07) — what the SOT must mirror

Verified against `lib/sigra/application.ex:184-230` [VERIFIED: read this session].

Encryption is **NOT** gated by `Code.ensure_loaded?(Cloak)`. The real check in `verify_vault!/1`:

```elixir
# lib/sigra/application.ex:191-205 (the operative branch)
module ->
  Code.ensure_loaded?(module)   # side-effecting load attempt on host's Encrypted.Binary module

  if function_exported?(module, :__sigra_encryption_mode__, 0) and
       module.__sigra_encryption_mode__() == :stub do
    raise "...passkeys enabled but #{module} is still the plaintext stub..."
  end
```

The truth the SOT must mirror is: **"is encryption ACTIVE (real vault) vs. STUB (plaintext)?"** — derived from `module.__sigra_encryption_mode__() == :stub`, gated behind `function_exported?/3`, where `module` is the host's derived `*.Encrypted.Binary` module (`encrypted_binary_module/1`, application.ex:218-230 derives it from `:user_schema`).

**Implication for the predicate (D-07, planner discretion on name):** the encryption predicate must take host config (e.g. `encryption_active?(host_sigra_config)`), derive the binary module the same way `encrypted_binary_module/1` does, and return the stub-vs-real boolean. A bare `cloak_available?/0` would report "available" while the app is still on the plaintext stub — a silent security-posture regression (D-07 rationale). The `Code.ensure_loaded?(module)` at line 192 is a side-effecting load-attempt on a DYNAMIC host module, NOT a gate, and belongs to Bucket C — do not route it through the SOT.

## Dep-Off CI Lane Reality (the OD-02 proof surface)

Verified against `.github/workflows/ci.yml` [VERIFIED: read this session].

**There is ONE genuine dep-removal lane, not three.** The "3 dep-off CI lanes" claim in PROJECT.md:136 / MILESTONES.md:738 refers to v1.21 HARD-02 history and does not match the current `ci.yml`. The current state:

| Job (ci.yml) | What it does | What it proves for OD-02 |
|--------------|--------------|--------------------------|
| `library_tests` (122) | `mix deps.get` fetches ALL optional deps (they ARE in `deps/` — verified: assent, bcrypt_elixir, eqrcode, hammer, joken, oban, req, swoosh, threadline all present), then `mix test` + `mix docs --warnings-as-errors` | Proves the **truthy** branch of every predicate (all deps loaded → all `*_available?/0` return `true`). Does NOT exercise any falsy branch. |
| `library_tests_dep_off` (170) | `mix deps.unlock threadline` + `mix deps.clean threadline --build`, then `mix compile --warnings-as-errors --no-deps-check`, then `mix test --exclude requires_threadline` | Proves the **falsy** branch for **Threadline only** (`threadline_available?/0 == false`), AND proves the compile-time `defmodule` wrappers still compile clean with the dep absent. |
| `example_unit_smoke`, `install_smoke`, `passkeys_*`, etc. | Integration smoke against `test/example/` | Indirect — exercises real wiring but not dep-absence per dep |

**Critical Validation insight:** of the nine predicates, only `threadline_available?/0`'s **falsy** branch is exercised by a CI dep-off lane. The other eight predicates' falsy branches (`oban`, `bcrypt`, `eqrcode`, `assent`, `swoosh`, `joken`, `hammer`, `req`) are **not exercised by any current lane** — every dep is present in the standard test environment. Therefore the dep-off lane ALONE is insufficient to prove OD-02 for those eight. Per-predicate unit tests are the primary behavior-preservation proof (see Validation Architecture).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Is dep loaded?" | A `Map`/registry of dep_atom → module with a dispatcher | One zero-arity predicate per dep wrapping `Code.ensure_loaded?` directly (D-01) | A dispatcher invents a name→module map (its own drift surface) and fails silently (`false`) on a typo'd atom instead of at compile time (D-01 rationale) |
| Caching availability | An ETS/persistent_term memo | Un-memoized thin wrapper (D-03) | A dep may be loaded later in dev/test; caching would break the one-to-one semantic equivalence that makes OD-02 provable |
| Encryption "available" check | `Code.ensure_loaded?(Cloak)` | Mirror `__sigra_encryption_mode__() == :stub` (D-07) | Load check reports "available" on the plaintext stub — silent security regression |

**Key insight:** the entire value of this phase is the one-to-one semantic mapping. Any abstraction that changes the truth value or the timing of the check (caching, dispatch fallback, load-vs-config conflation) violates OD-02. Keep each predicate a literal `Code.ensure_loaded?(Mod)` body.

## Common Pitfalls

### Pitfall 1: Anchoring on the grep total
**What goes wrong:** Planning tasks against "~29" or "44" guards and trying to delegate all of them.
**Why it happens:** ROADMAP.md:45/58 say "~29 scattered guards"; raw grep returns 44.
**How to avoid:** Use the Bucket A enumeration (15 expressions, 12 files). Buckets B/C/D stay literal.
**Warning signs:** A task touching `workers/*.ex:1`, `credo/*.ex`, `testing.ex`, or any `Code.ensure_loaded?(variable)` — those are out of scope.

### Pitfall 2: Delegating the test-override branch in forwarders.ex
**What goes wrong:** Rewriting `oban_running?/1` to call `oban_available?/0` in BOTH `case` branches.
**Why it happens:** The function has two branches; only the `:error` branch (line 99) has the load check.
**How to avoid:** The `{:ok, oban_override}` branch (line 94) deliberately skips `Code.ensure_loaded?` because the override is a named process atom, not a module (forwarders.ex:85-95 comments). Only line 99's `Code.ensure_loaded?(Oban)` delegates.
**Warning signs:** `oban_running?/1` tests with a test override start behaving differently.

### Pitfall 3: Treating deletion.ex:308 as a named-dep guard
**What goes wrong:** Adding a `Sigra.Workers.AccountDeletion`-availability predicate to the SOT.
**Why it happens:** D-06 says "delegate each `Code.ensure_loaded?` leg of its `with`."
**How to avoid:** Only the `Oban` leg (line 307) is a named optional dep. Line 308 guards an internal conditionally-compiled worker module (Bucket C). Leave it literal.

### Pitfall 4: Flipping the compound liveness check
**What goes wrong:** Folding `Process.whereis(Oban) != nil` / `function_exported?(Req, :get, 1)` into the predicate.
**Why it happens:** It looks like part of the same guard.
**How to avoid:** D-06 — delegate the LOAD half only. delivery.ex:110-112 and forwarders.ex:81-83 carry explicit comments that the liveness check is a separate concern; an app that adds `:oban` but never supervises it would flip `:sync`→`:async` and crash on insert.

## Runtime State Inventory

This is a code-only internal refactor — no stored data, live service config, OS-registered state, secrets, or build-artifact migration.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore keys involve dep names | None |
| Live service config | None — the only config touched is read-only host `sigra_config` for the encryption predicate (D-07) | None |
| OS-registered state | None | None |
| Secrets/env vars | None — `CLOAK_KEY` referenced only in an error message, not read/renamed | None |
| Build artifacts | None — no package rename; `no_warn_undefined` unchanged (D-10) so no recompile-required artifact drift | None — verified mix.exs whitelist unchanged |

## Code Examples

### Predicate shape (D-01, D-03) — one-to-one with the inline check
```elixir
# lib/sigra/optional_deps.ex
defmodule Sigra.OptionalDeps do
  @moduledoc """
  Canonical source of truth for optional-dependency availability.

  Each predicate is a thin, un-memoized wrapper over `Code.ensure_loaded?/1`
  — identical semantics to the inline guard it replaced. Scope: RUNTIME
  call-site guards only. Compile-time `defmodule` wrappers (workers/*.ex,
  audit/forwarders/threadline.ex) stay literal (D-04) and do NOT delegate
  here, because they run before this module may be compiled.
  """
  @spec oban_available?() :: boolean()
  def oban_available?, do: Code.ensure_loaded?(Oban)

  @spec bcrypt_available?() :: boolean()
  def bcrypt_available?, do: Code.ensure_loaded?(Bcrypt)
  # ...eqrcode/threadline/assent/swoosh/joken/hammer/req identical shape
end
```

### Compound-guard delegation (D-06) — load half only
```elixir
# lib/sigra/delivery.ex:113-115  (BEFORE → AFTER)
# defp oban_running?, do: Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil
defp oban_running?, do: Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
```

### Encryption predicate (D-07) — mirror, don't load-check
```elixir
# Mirrors application.ex:191-205 — config-driven, NOT Code.ensure_loaded?(Cloak)
@spec encryption_active?(keyword()) :: boolean()
def encryption_active?(host_sigra) when is_list(host_sigra) do
  case encrypted_binary_module(host_sigra) do  # same derivation as application.ex:218
    nil -> false
    module ->
      function_exported?(module, :__sigra_encryption_mode__, 0) and
        module.__sigra_encryption_mode__() != :stub
  end
end
```
(Name and exact signature are planner discretion per CONTEXT.md Claude's Discretion.)

## Validation Architecture

> nyquist_validation is enabled (no `.planning/config.json` opt-out found). This section drives VALIDATION.md / Dimension 8.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5 / OTP 28, per `.tool-versions`) [VERIFIED: read this session] |
| Config file | none custom — standard `mix test`; `test/test_helper.exs` |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/optional_deps_test.exs` (new file, Wave 0) |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| Prereq | Live Postgres at localhost:5432 (postgres/postgres) per CLAUDE.md — but the SOT unit tests themselves need no DB |

### What signals prove the refactor is behavior-preserving

The core OD-02 obligation: each delegated call site has **identical truth value** before and after. Two complementary signals:

1. **Per-predicate unit tests (PRIMARY).** Because the standard `library_tests` lane has ALL optional deps present, every predicate returns `true` there and no falsy branch is exercised except Threadline. Unit tests must assert each predicate's truth value matches `Code.ensure_loaded?(TheModule)` directly — i.e. assert the wrapper is a faithful mirror. In the all-deps-present test env this asserts `== true`; the test should assert equality to a freshly-evaluated `Code.ensure_loaded?(Mod)` (tautological-but-drift-catching) rather than a hardcoded `true`, so the same test stays valid in a dep-off env.
2. **Threadline dep-off lane (SECONDARY, the one real dep-absence proof).** `library_tests_dep_off` (ci.yml:170) removes `:threadline`, recompiles `--warnings-as-errors`, and runs `mix test --exclude requires_threadline`. After the refactor this lane must stay green — it proves `threadline_available?/0` correctly returns `false` and that the compile-time wrappers still compile clean.
3. **Existing call-site tests must stay green unchanged.** The behavior tests for crypto (bcrypt fallback), mfa (QR svg nil path), jwt signer raise, rate_limit Noop fallback, oauth ensure_assent raise, delivery sync/async routing, forwarders dispatch, deletion job enqueue, and enterprise_connections Req path are the regression net. None of their assertions change — that invariance IS the no-behavior-change proof.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OD-01 | All 9 predicates + encryption predicate exist and return correct truth value | unit | `mix test test/sigra/optional_deps_test.exs` | ❌ Wave 0 |
| OD-01 | `encryption_active?/1` returns false for stub mode, true for real vault | unit | `mix test test/sigra/optional_deps_test.exs -k encryption` | ❌ Wave 0 |
| OD-02 | crypto bcrypt-verify fallback unchanged | unit (existing) | `mix test test/sigra/crypto_test.exs` | ✅ (verify exists) |
| OD-02 | rate_limit resolves Hammer vs Noop unchanged | unit (existing) | `mix test test/sigra/plug/rate_limit_test.exs` | ✅ |
| OD-02 | delivery/forwarders sync/async routing unchanged | unit (existing) | `mix test test/sigra/application_forwarders_test.exs test/sigra/delivery*` | ✅ (forwarders test confirmed present) |
| OD-02 | Threadline-absent lane green | CI lane | `library_tests_dep_off` job | ✅ (ci.yml:170) |
| OD-02 | compile clean, no new no_warn_undefined entries | compile | `mix compile --warnings-as-errors` (both standard + dep-off lanes) | ✅ |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/optional_deps_test.exs` + the touched call-site's existing test file.
- **Per wave merge:** full `mix test` + `mix compile --warnings-as-errors` + `mix credo` (no new strict regressions — REQUIREMENTS.md Out-of-Scope posture).
- **Phase gate:** full suite green + `library_tests_dep_off` lane green + `mix docs --warnings-as-errors` green before `/gsd-verify-work`.

### Observability / drift detection
- **How a maintainer detects drift:** a future bare `Code.ensure_loaded?(NamedOptionalDep)` reintroduced at a call site. Phase 138 (`sigra.doctor`) consumes the SOT; a future Credo check (`NoBareOptionalDepReference`, modeled on Mailglass's `NoBareOptionalDepReference`, PITFALLS.md:37) could enforce single-callsite — OUT OF SCOPE for 137 but worth a `@moduledoc` note.
- **Truth-value drift between predicate and inline:** caught by the unit test asserting `predicate() == Code.ensure_loaded?(Mod)`.

### Wave 0 Gaps
- [ ] `test/sigra/optional_deps_test.exs` — unit tests for all 9 predicates + the encryption predicate (covers OD-01, primary OD-02 proof)
- [ ] Confirm `test/sigra/crypto_test.exs` covers the bcrypt-verify fallback path; if not, add a falsy-branch assertion (the bcrypt sites' falsy branch is otherwise unexercised by CI)
- [ ] No framework install needed — ExUnit is present

*Note: the encryption predicate test needs a fixture host module exporting `__sigra_encryption_mode__/0` returning `:stub` and `:real` — model on existing `verify_vault!` tests in `test/sigra/application_*_test.exs`.*

## Security Domain

> security_enforcement enabled (absent = enabled, per CLAUDE.md OWASP posture).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | indirect | bcrypt fallback path (crypto.ex) preserved exactly — no change to verification timing semantics |
| V6 Cryptography | yes (D-07) | The encryption predicate must mirror stub-vs-real, never report a stub as "available" — preventing a silent at-rest-encryption-disabled regression |
| V5 Input Validation | no | No external input; module atoms only |

### Known Threat Patterns for this refactor
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Encryption predicate reports plaintext stub as "available" | Information Disclosure | D-07: mirror `__sigra_encryption_mode__() == :stub`, NOT `Code.ensure_loaded?(Cloak)` |
| bcrypt timing-protection fallback altered | Information Disclosure (timing) | Keep crypto.ex:244-251 else-branch (`no_user_verify(); false`) byte-equivalent; only the load-check expression delegates |
| Joken/Assent raise-guards weakened | Tampering / DoS | jwt/signer.ex:18 and oauth raise-guards must still raise on absence — `unless predicate(), do: raise` preserves the raise |

## State of the Art

No moving-target ecosystem concern — `Code.ensure_loaded?/1` is stable Elixir stdlib. The only "state of the art" note is internal: the Mailglass sister-lib (in `test/example/deps/`) uses a **sub-module-per-dep namespace** pattern (`Mailglass.OptionalDeps.Oban` with `available?/0`) [VERIFIED: read this session]. CONTEXT.md D-01 deliberately chose the **flat single-module** form instead (`Sigra.OptionalDeps.oban_available?/0`). The planner must follow D-01 (flat), NOT the Mailglass namespace pattern, despite PITFALLS.md:22 suggesting "mirror Mailglass's pattern" — that research note predates and is superseded by the locked D-01 decision.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `application.ex:77` `Code.ensure_loaded?(Oban)` boot-warning is safe to either delegate or leave literal (judgment call, flagged for planner) | Runtime Guard Inventory, Bucket C | Low — one-shot boot warning, identical behavior either way; recommend leaving literal to keep phase minimal |
| A2 | Existing call-site test files (`crypto_test.exs`, `delivery*`) cover the falsy branches — needs confirmation in Wave 0 | Validation Architecture | Medium — if a falsy branch is untested, the bcrypt/eqrcode delegations have weaker regression coverage; Wave 0 gap covers this |

**Otherwise:** all guard call sites, the encryption predicate, the CI lane structure, the mix.exs whitelist, and the SOT-absence reality are VERIFIED against live code this session.

## Open Questions

1. **`application.ex:77` boot-warning delegation (A1)**
   - What we know: it is a literal `Code.ensure_loaded?(Oban)` runtime check on a named optional dep.
   - What's unclear: CONTEXT.md does not enumerate it; D-04 only excludes `defmodule`-wrappers, not this `cond`.
   - Recommendation: planner decides. Default to LEAVE LITERAL (Bucket C-adjacent, minimal-phase posture) and note it in the `@moduledoc` as a known non-delegated runtime check, OR delegate it as a trivial extra (zero behavior risk). Either is defensible; do not silently change behavior.

2. **`deletion.ex:308` worker-module leg**
   - What we know: it guards `Sigra.Workers.AccountDeletion` (internal), not a named optional dep.
   - What's unclear: D-06 literally says "delegate each leg."
   - Recommendation: delegate ONLY the `Oban` leg (307); leave 308 literal (it is a Bucket C internal-module check). Flag to user via the plan if strict D-06 reading is preferred.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/OTP | compile + test | ✓ (declared) | 1.19.5-otp-28 | — |
| PostgreSQL @ localhost:5432 | full `mix test` (not the SOT unit tests) | host-dependent | 15/16 | SOT unit tests need no DB; full suite does (CLAUDE.md) |
| Optional deps (oban, bcrypt, etc.) | truthy-branch coverage | ✓ all present in `deps/` | per mix.exs | dep-off lane removes threadline only |

No blocking missing dependencies for the refactor itself.

## Sources

### Primary (HIGH confidence) — live code verified this session
- `lib/sigra/optional_deps.ex` — confirmed ABSENT (grep zero hits)
- `lib/sigra/{crypto,mfa,delivery}.ex`, `lib/sigra/hashers/bcrypt.ex`, `lib/sigra/jwt/signer.ex`, `lib/sigra/plug/rate_limit.ex`, `lib/sigra/oauth/strategies/{apple,facebook,github,generic,google}.ex`, `lib/sigra/account/deletion.ex`, `lib/sigra/audit/forwarders.ex`, `lib/sigra/enterprise_connections/validation.ex` — all guard call sites read
- `lib/sigra/application.ex:60-231` — encryption gating (D-07) + boot warnings
- `lib/sigra/rate_limiter.ex` + `rate_limiters/noop.ex` — triad precedent
- `mix.exs:60-120` — optional deps + `no_warn_undefined` whitelist
- `.github/workflows/ci.yml:170-219` — the single dep-off lane
- `.tool-versions` — Elixir 1.19.5 / OTP 28
- `.planning/phases/137-.../137-CONTEXT.md` — LOCKED decisions D-01..D-10
- `.planning/REQUIREMENTS.md` — OD-01/OD-02 + Out-of-Scope row

### Secondary (MEDIUM) — corroborating research docs
- `.planning/research/{SUMMARY,ARCHITECTURE,PITFALLS,STACK}.md` — independently confirm SOT absence
- `test/example/deps/mailglass/lib/mailglass/optional_deps.ex` — sister-lib namespace precedent (superseded by D-01)

### Tertiary (LOW / corrected)
- PROJECT.md:136, MILESTONES.md:738, ROADMAP.md:54 "shipped `Sigra.OptionalDeps`" / "3 dep-off lanes" — CONTRADICTED by live code; documented as drift

## Metadata

**Confidence breakdown:**
- Runtime guard inventory: HIGH — every site read at exact line this session
- Encryption predicate reality (D-07): HIGH — `verify_vault!` read in full
- CI proof surface: HIGH — ci.yml read; corrected the "3 lanes" narrative
- SOT absence: HIGH — grep + 4 corroborating research docs

**Drift flagged to planner:**
1. CONTEXT.md omits `hashers/bcrypt.ex:39,48` (two Bcrypt guards) — add to delegation set.
2. `swoosh_available?/0` and `req_available?/0` have no in-scope runtime delegation target (Swoosh's only `lib/` guard is the test-helper `testing.ex:98`; Req is not in mix.exs and is guarded only at `validation.ex:91`). They are SOT-completeness predicates (OD-01), not OD-02 delegation work. `req` is a transitive dep, not declared in mix.exs.
3. `deletion.ex:308` and `application.ex:77` are judgment calls (Open Questions 1-2).
4. "3 dep-off CI lanes" narrative is stale — one real dep-removal lane (Threadline) exists.

**Research date:** 2026-05-29
**Valid until:** 2026-06-28 (stable internal refactor; re-verify call-site line numbers if `lib/` churns before planning)
