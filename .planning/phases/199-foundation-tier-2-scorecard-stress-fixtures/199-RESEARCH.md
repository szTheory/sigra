# Phase 199: Foundation — Tier-2 Scorecard & Stress Fixtures - Research

**Researched:** 2026-06-25
**Domain:** CI quality-gate machinery (shell guards), Elixir/Ecto demo seed fixtures, Playwright snapshot/recapture mechanics, admin-UI scorecard/ledger docs
**Confidence:** HIGH

## Summary

This is a "measuring-instrument + stress-data" phase, not a UI-elevation phase. CONTEXT.md already
locks 15 decisions (D-01..D-15) with file:line evidence; that scope is settled and was re-verified
against the live tree below — **all canonical anchors in CONTEXT.md are accurate as of this commit**
(no line-number drift found). The value-add of this research is the *validation strategy* and the
*mechanical landmines* CONTEXT.md does not fully spell out.

Three findings materially shape the plan and are flagged HIGH-priority for the planner:

1. **User list default sort is `inserted_at DESC` (newest-first)** (`lib/sigra/admin/users/query.ex:68-71`).
   D-08 assumes the `admin` persona is "first-listed" on `/admin/users`, but the un-skipped
   content-equivalence test navigates to the **first-listed user's** audit page expecting ≥25 events
   (`admin-design.spec.ts:371-378`). If the D-09 bulk `loadtest-NN` cohort is inserted **after** the
   personas, a loadtest user becomes first-listed and the test fails. **The plan must guarantee the
   first-listed user has ≥25 self-tied audit events** — cleanest fix: seed the bulk cohort BEFORE the
   personas in `run/0` so `admin` stays newest (re-verify empirically), OR top up the first-listed
   loadtest user too. Do not assume D-08's "admin is first-listed" holds for free.

2. **The snapshot blast radius (D-12) is likely SMALLER than "all four surfaces shift."** The
   admin-checkpoints lane registers its **own fresh per-run users** (`checkpoint-target-…@example.test`,
   `admin-checkpoints.spec.ts:16,20,26,32`) and scopes its `/admin/users` capture with `?q=targetEmail`
   and its audit explorer with `?action_prefix=admin.impersonation`. Those captures are insulated from
   the demo `@demo.tasklane.test` seed cohort. The admin-design **gallery board** snapshots render
   "static literal assigns only" (`admin-design.spec.ts:218-220`) and are also data-independent. The
   genuinely data-dependent surface is the **content-equivalence test's live navigation** to
   `/admin/users`, `/admin/audit`, and the first-user audit page. The plan should **empirically
   determine** which (if any) baseline PNGs actually move by running both lanes — not pre-emptively
   recapture all four surfaces.

3. **Two snapshot lanes, two different canaries.** The checkpoint lane canary is `impersonation-banner`
   (default, `snapshot-canary-guard.sh:20`) with allowlist `snapshot-allowlist`; the design lane canary
   is `board-notice` (`ci.yml:108`, `snapshot-recapture-gate.sh:89`) with allowlist
   `snapshot-allowlist-design`. D-14 names `impersonation-banner`; that is correct for the checkpoint
   lane, but the design lane (which owns the MG-5/6 and gallery slugs most exposed to seed changes) is
   guarded by `board-notice`. **Both canaries must stay byte-stable; do not cross lanes.**

**Primary recommendation:** Build the scorecard/ledger Tier-2 add-on as docs-only changes (D-01..D-07),
add the D-05 guard self-test as a **shell test** (lowest friction — see Validation Architecture), seed
the bulk cohort *before* personas and top up `admin` to ≥25 self-tied events, un-skip the
content-equivalence test, then empirically recapture only the PNGs that actually move through
`snapshot-recapture-gate.sh` and reset both allowlists to empty (Phase 192 method).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tier-2 proxy definitions | Docs (`admin-fractal-scorecard.md`, `admin-quality-ledger.md`) | — | Pure reference docs; no runtime code (D-01) |
| Tier-2 ratchet enforcement | CI shell guard (`quality-ledger-monotonic.sh`) | GitHub Actions (`ci.yml`) | Already numeric/tier-agnostic; no parser change (D-04) |
| Guard self-test (2→1) | CI shell test | — | Exercises the guard binary; lowest friction in shell (D-05) |
| ≥25-event persona | Elixir/Ecto seed fixture (`seeds.ex`) | DB (audit_events) | Demo data, not library logic (D-08) |
| Bulk "ugly" user cohort | Elixir/Ecto seed fixture (`seeds.ex`) | DB (users) | Out of persona catalog (D-09) |
| Pagination/content-equivalence proof | Playwright (`admin-design.spec.ts`) | Live LiveView surfaces | Browser-tier behavioral test (D-13) |
| Baseline recapture | Playwright + CI shell gates | git | Snapshot mechanics (D-14, D-15) |

## Standard Stack

No new packages. This phase touches existing, already-vendored tooling:

| Tool | Where | Purpose | Notes |
|------|-------|---------|-------|
| bash + `awk -F'|'` + `grep -E` | `scripts/ci/quality-ledger-monotonic.sh` | Tier parse + monotonic check | `[VERIFIED: file read]` already numeric — D-04 no-change |
| Ecto `Repo.transaction` / `Repo.insert(on_conflict: :nothing)` | `test/example/lib/example/demo/seeds.ex` | Idempotent upserts | `[VERIFIED: file read]` count-threshold + transaction pattern at `seeds.ex:634-712` |
| Playwright `@playwright/test` | `test/example/priv/playwright` | Content-equivalence + snapshot recapture | `[VERIFIED: file read]` design lane hard-gates as of Phase 197 (`ci.yml:1041`) |
| `snapshot-canary-guard.sh` / `snapshot-recapture-gate.sh` | `scripts/ci/` | Drift/canary enforcement + per-lane recapture | `[VERIFIED: file read]` two lanes, two canaries |

**No `npm install` / `mix deps` change required.** This phase is docs + fixtures + tests against
existing infrastructure.

## Package Legitimacy Audit

Not applicable — this phase installs **no external packages**. All tooling is already vendored.

## Architecture Patterns

### Pattern 1: Docs-only Tier-2 proxy encoding (D-01, D-03)
**What:** Add a "Tier-2 Add-on" block to `admin-fractal-scorecard.md` mirroring the existing per-level
add-on structure (`admin-fractal-scorecard.md:42-122`), and extend the ledger's Evidence-column
convention. **Do NOT** add a parallel proxy file or per-proxy sub-tier columns.
**Why:** The ledger table column-4 must stay a single `[012]` integer so the guard's positional
`awk -F'|' '{tier=$4; … if (tier ~ /^[012]$/)}'` parse keeps working (`quality-ledger-monotonic.sh:22-27`).

### Pattern 2: Count-threshold idempotent upsert for non-uniquely-indexed rows (D-10)
**What:** Reuse the existing audit-event pattern (`seeds.ex:634-712`): aggregate a scoped count, only
insert the batch if `count < expected`, wrap the whole batch in `Repo.transaction` so a partial insert
can't leave the count below threshold and re-fire on the next run.
```elixir
# Source: test/example/lib/example/demo/seeds.ex:642-651 (VERIFIED file read)
demo_tied_count = Repo.aggregate(from(a in AuditEvent, where: a.effective_user_id in ^demo_user_ids), :count)
if demo_tied_count < length(@audit_actions) + length(persona_audit_events()) do
  insert_audit_batch(admin, users, organizations)
end
```
For the bulk user cohort, the analogous guard is a count of `loadtest-%@demo.tasklane.test` users vs the
target cohort size; insert under a transaction with `on_conflict: :nothing` keyed on email.

### Pattern 3: Bulk cohort lives OUTSIDE `Personas.all/0` (D-09)
**What:** Add a separate `seed_bulk_users/0`-style step that generates `loadtest-NN@demo.tasklane.test`
users directly, never appending to the `Personas.all/0` catalog.
**Why:** `Personas.all/0` drives three SSoT consumers that would break:
- `print_credentials/0` iterates `Personas.all()` (`seeds.ex:64-72`) — bulk users would spam credentials output.
- `feature_map/0` (`personas.ex:188-201`) is the keyed single-source-of-truth for `/demo/credentials`.
- `seeds_test.exs` asserts `demo_users == length(Personas.all())` (`seeds_test.exs:107,126`) — adding
  bulk users to the catalog OR counting them as demo users breaks this. **Note:** `snapshot_counts/0`
  counts `demo_users` by `like(u.email, "%@demo.tasklane.test")` (`seeds_test.exs:40`). If bulk users
  also use `@demo.tasklane.test`, the `demo_users == length(Personas.all())` assertion at line 107
  **will break**. **The planner must resolve this**: either (a) use a different email domain/marker for
  bulk users so they're excluded from the `demo_users` count, or (b) update the `snapshot_counts/0`
  query + assertions to scope to the persona set explicitly. This is a HARD constraint, not optional.

### Anti-Patterns to Avoid
- **Adding a `severity` column / decorators to the ledger Tier column.** No `severity` exists in the
  audit schema — vocab is `~w(success failure error)` (`changeset.ex:28`, VERIFIED). "Varied severities"
  maps to `outcome` + action-prefix variety (D-11). Decorating column-4 breaks the `[012]` parse.
- **Recapturing all four surfaces pre-emptively.** Determine the real blast radius empirically (Finding 2).
- **Passing the same `--allow` set to both recapture lanes.** The gate routes slugs per-lane by globbing
  the snapshot dir (`snapshot-recapture-gate.sh:32-55`); cross-lane `--require-all` is self-defeating.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Idempotent seed re-runs | Custom dedup/delete-then-insert | Existing count-threshold + transaction pattern (`seeds.ex:642-651`) | Already proven idempotent; matches `seeds_test.exs` SEED-01 |
| Per-lane snapshot recapture | Manual `--update-snapshots` + hand-checking `git status` | `snapshot-recapture-gate.sh <slug>...` | Auto-routes slugs per lane, runs canary guard, resets to all-green proof |
| Tier monotonic check | New tier-comparison logic for Tier 2 | Existing `quality-ledger-monotonic.sh` (already numeric, D-04) | `head_tier -lt base_tier` already protects 2→1 for free |

**Key insight:** Every machine the phase needs already exists and is merge-blocking. The phase's job is
to *feed* them (proxies in the ledger, ≥25 events for pagination) and *positively exercise* the Tier-2
path (D-05 self-test), not to rebuild any guard.

## Runtime State Inventory

This is a fixtures/docs/CI phase, not a rename/refactor. Inventory of state that persists beyond a file edit:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Demo DB rows: new bulk `loadtest-NN` users + topped-up `admin` audit events. Idempotent upserts mean re-seed is a no-op. | Code edit (seed module) + count-threshold guard; no destructive migration |
| Live service config | None — no external service stores these strings | None |
| OS-registered state | None | None |
| Secrets/env vars | None new. `MIX_ENV=test` raise guard (`seeds.exs:17`) already exists and is contract-tested (`seeds_script_test.exs:14`) | None — keep bulk inserts under the same guard (D-10) |
| Build artifacts | Playwright baseline PNGs in two snapshot dirs may change for data-dependent slugs; both allowlists currently steady-state empty (verified) | Recapture only moved slugs via gate; reset allowlists to empty (D-15) |

## Common Pitfalls

### Pitfall 1: First-listed user is newest, not the `admin` persona
**What goes wrong:** Content-equivalence test (`admin-design.spec.ts:371-378`) opens the **first** user's
detail → audit page and expects ≥25 events for pagination. With `inserted_at DESC` sort
(`users/query.ex:68-71`), a bulk `loadtest` user inserted after personas is first-listed and has few events.
**Why it happens:** D-08 assumes `admin` is first-listed; that only holds if `admin` is the newest
demo-domain user the test actually lands on.
**How to avoid:** Seed the bulk cohort BEFORE personas in `run/0` (so personas stay newest), and/or assert
empirically that the first-listed user the test reaches is `admin`. If the test is on `/admin/users`
unscoped, the absolute-newest user wins regardless of catalog membership.
**Warning signs:** Content-equivalence test fails with "no pagination controls" after un-skip.

### Pitfall 2: Breaking the `[012]` ledger column shape
**What goes wrong:** Any decorator, footnote marker, or extra integer in ledger column-4 makes
`if (tier ~ /^[012]$/)` skip the row, silently dropping it from the guard.
**How to avoid:** Tier-2 evidence goes in the **Evidence** column (column 5+), never column 4. Tier stays
a bare `0`/`1`/`2`. Reconcile the "Tier 2 NOT declared here" prose (`admin-quality-ledger.md:81-84`, D-06)
in the prose section only.
**Warning signs:** Guard prints fewer "cells checked" than expected; a cell silently loses protection.

### Pitfall 3: `@demo.tasklane.test` bulk users inflate the `demo_users` count assertion
**What goes wrong:** `seeds_test.exs:40` counts `demo_users` via `like(u.email, "%@demo.tasklane.test")`;
`:107` asserts `demo_users == length(Personas.all())`. Bulk users on that domain break it.
**How to avoid:** Use a distinguishable marker for bulk users (e.g. `loadtest-NN@demo.tasklane.test` is
still on-domain — prefer a sub-marker the count query can exclude, OR update the assertion to scope to
persona emails explicitly). Decide this before writing the seed step.
**Warning signs:** `idempotency (SEED-01)` test fails on `first.demo_users == length(Personas.all())`.

### Pitfall 4: Wrong-lane canary/allowlist during recapture
**What goes wrong:** Recapturing design-lane slugs while passing the checkpoint canary (or vice versa)
arms/disarms the wrong tripwire (`ci.yml:1666-1667` warns about exactly this).
**How to avoid:** Design lane → canary `board-notice`, allowlist `snapshot-allowlist-design`. Checkpoint
lane → canary `impersonation-banner`, allowlist `snapshot-allowlist`. `snapshot-recapture-gate.sh`
auto-routes by globbing the snapshot dir — prefer it over hand-calling `snapshot-canary-guard.sh`.

### Pitfall 5: Reserved audit-action prefixes rejected by changeset
**What goes wrong:** `auth.*` / `session.*` / `mfa.*` / `oauth.*` / `api.*` / `account.*` / `sigra.*` are
reserved (`changeset.ex:26`); inserting them without `allow_reserved: true` fails.
**How to avoid:** Pass `allow_reserved: true` on every audit insert, mirroring the existing batch
(`seeds.ex:678,702`). The topped-up `admin` events must follow the same convention.

## Code Examples

### D-05 guard self-test (recommended: shell test exercising the binary)
```bash
# A synthetic ledger fixture asserting the guard exits non-zero on a 2→1 decrease.
# Lowest friction: a bash test that builds two temp git states (or uses a fixture
# ledger + a stubbed `git show`) and asserts exit code 1.
# Mirror the guard's own interface: it reads `${BASE}:${LEDGER}` via `git show`
# (quality-ledger-monotonic.sh:33) and the working-tree LEDGER (:43).
# Cleanest harness: a throwaway git repo in $TMPDIR with two commits where one
# cell goes 2 -> 1, run the guard with --base <first-commit>, assert non-zero.
```
See Validation Architecture for placement rationale (shell test vs Elixir vs CI step).

### Bulk cohort seed step shape (D-09/D-10)
```elixir
# Source: pattern derived from seeds.ex:634-712 (VERIFIED). Slot into run/0 BEFORE
# seed_users() if first-listed-must-be-admin (Pitfall 1) is resolved by insert order.
defp seed_bulk_users do
  existing = Repo.aggregate(from(u in User, where: like(u.email, ^"loadtest-%")), :count)
  if existing < @bulk_cohort_size do
    Repo.transaction(fn ->
      Enum.each(1..@bulk_cohort_size, fn n ->
        # long display name, near-max email, UUID-shaped identifier (Claude's discretion on values)
        upsert_user(%{email: bulk_email(n), display_name: ugly_name(n), ...})
      end)
    end)
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Design gallery lane `continue-on-error` (SEED-006 font drift) | Hard-gating; `document.fonts.ready` await added | Phase 197 (`ci.yml:1041-1053`) | Un-skipped content-equivalence test runs in a **hard-gating** lane — must be green, not masked |
| MG-5/6 content-equivalence `test.skip` (data-dependent) | Un-skip once ≥25-event persona exists | This phase (D-13) | Closes `2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent` todo |
| Tier 2 "not declared / earned separately" prose | Tier-2 add-on block + objective proxies | This phase (D-01, D-06) | Ledger prose must be reconciled so it no longer says "Tier 2 not declared" |

**Deprecated/outdated:** None. The todo's "Update 2026-06-19" note about the gallery board-snapshot
dimension mismatch (SEED-006) was a **separate** test from the content-equivalence test; per Phase 197
the font issue was addressed and the lane hard-gates again. The planner should still run the gallery
board lane to confirm it's green before/after seed changes (the gallery boards are static-assign, so
they should not move — confirm empirically).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Bulk users on `@demo.tasklane.test` will break `demo_users == length(Personas.all())` unless excluded/scoped | Pitfall 3 | If wrong, an over-engineered exclusion; if right and ignored, SEED-01 test fails. **Verify by reading the chosen bulk email domain against `seeds_test.exs:40`** |
| A2 | The checkpoint lane is insulated from demo-seed changes (own per-run users + scoped queries) | Finding 2 | If some checkpoint capture is unscoped, an unexpected baseline moves; the recapture gate will catch it — low risk because the gate is empirical |
| A3 | Seeding the bulk cohort before personas keeps `admin` (or a persona) newest/first-listed | Pitfall 1 | If the content-equivalence test lands on an unscoped `/admin/users` and a persona other than admin is newest, pagination may still not render on the intended user. **Verify by running the un-skipped test locally against seeded data** |

**No `[ASSUMED]` package or version claims** — this phase adds no dependencies.

## Open Questions

1. **Does the content-equivalence test require the FIRST-listed user, or any user, to have ≥25 events?**
   - What we know: `admin-design.spec.ts:371-378` reads the `.first()` "Open user" link's href and navigates there; the test expects pagination controls on that user's audit feed.
   - What's unclear: whether the test's `/admin/users` view is unscoped (newest-first wins) at the point of navigation.
   - Recommendation: Plan a Wave-0 step to run the un-skipped test against seeded data and observe which user it lands on; adjust insert order or add an explicit `?q=admin@demo.tasklane.test` scope to the test navigation if needed (test edit is in-scope per D-13).

2. **Exact bulk-cohort size (Claude's discretion, ~30-60).**
   - Recommendation: Pick the smallest size that produces >1 page on `/admin/users` (page size 25, `users/query.ex:65`) — i.e. ≥26 list-visible users total including personas. ~35-40 bulk users gives a clear second page without bloating CI snapshot time. Confirm the page actually paginates with the chosen number.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL (`sigra_test`) | seed/Ecto tests, Playwright DB | Assumed ✓ (CLAUDE.md prereq) | — | `scripts/db/up.sh` ephemeral PG |
| Node + `@playwright/test` | content-equivalence + recapture | Assumed ✓ (existing lanes) | — | — |
| `git` (for guard `git show`) | monotonic guard + self-test | ✓ | — | — |

**Missing dependencies with no fallback:** None identified — all tooling pre-exists.
Local boot of the example for Playwright follows the documented "compile-time PORT/PG" gotcha
(see MEMORY: Example Playwright boot) — the planner should reference `scripts/db/up.sh` + the
disposable-PG fallback when the shared local Postgres is saturated.

## Validation Architecture

Nyquist validation is enabled (`.planning/config.json: nyquist_validation: true`).

### Test Framework
| Property | Value |
|----------|-------|
| Frameworks | ExUnit (seed fixtures), bash (CI guards), Playwright `@playwright/test` (content-equivalence/snapshots) |
| Config files | `test/example/priv/playwright/playwright.config.ts`; `.github/workflows/ci.yml` |
| Quick run (seeds) | `MIX_ENV=test mix test test/example/test/example/demo/seeds_test.exs` (run from `test/example`) |
| Quick run (guard) | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` |
| Recapture gate | `bash scripts/ci/snapshot-recapture-gate.sh <slug>...` (dry-run: `RECAPTURE_DRYRUN=1`) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Concrete Command / Location | Exists? |
|-----|----------|-----------|------------------------------|---------|
| LEDGER-01 | Tier-2 proxies defined in scorecard + ledger; `[012]` shape preserved | docs + parse-smoke | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` still PASS (proves parse intact) | ✅ guard exists |
| LEDGER-02 | Guard fails on a Tier-2 decrease (2→1) | shell self-test | NEW `scripts/ci/` test (see below) | ❌ Wave 0 |
| LEDGER-02 | Guard stays merge-blocking vs `origin/main` | CI wiring check | `ci.yml:109-110` unchanged (D-07) | ✅ wired |
| FIXT-01 | ≥25 self-tied events on first-listed/admin persona → pagination renders | Playwright | un-skip `admin-design.spec.ts:328` + run design lane | ⚠️ skipped → un-skip |
| FIXT-01 | Admin persona ≥25 self-tied events | ExUnit | extend `seeds_test.exs` audit-liveness assert from `>=15` to `>=25` (admin) | ⚠️ exists at `:285-310`, raise threshold |
| FIXT-02 | Bulk cohort + idempotent upserts; no duplicate on re-run | ExUnit | `seeds_test.exs` SEED-01 idempotency (`:96-109`) — extend to assert bulk count stable across two `run/0` | ✅ pattern exists |
| FIXT-02 | Seeds refuse to run in `MIX_ENV=test` (raise guard) | ExUnit subprocess | `seeds_script_test.exs:14` unchanged — bulk inserts under same guard | ✅ contract exists |
| FIXT-02 | `demo_users == length(Personas.all())` still holds with bulk cohort excluded | ExUnit | `seeds_test.exs:107,126` (resolve Pitfall 3 before/while editing) | ✅ must stay green |

### D-05 guard self-test placement recommendation
**Recommend: a bash test in `scripts/ci/`** (e.g. `test/ci/quality-ledger-monotonic.bats` or a plain
`scripts/ci/quality-ledger-monotonic.test.sh` invoked from CI), for three reasons grounded in the
existing setup:
- The guard is a **shell binary** that reads `git show ${BASE}:${LEDGER}` and the working-tree file
  (`quality-ledger-monotonic.sh:33,43`). Exercising it through ExUnit would mean shelling out and
  fabricating git state from Elixir — more friction, no extra signal.
- The repo already invokes guards directly in `ci.yml` as bash steps; a sibling bash test that builds a
  throwaway `$TMPDIR` git repo with a 2→1 ledger delta and asserts non-zero exit is the most faithful,
  lowest-ceremony exercise.
- It keeps the Tier-2 ratchet's *positive* test co-located with the guard it protects.
Wire it as a CI step alongside the existing guard invocation so it's merge-blocking.

### Sampling Rate
- **Per task commit:** the relevant quick command (seeds ExUnit, or guard self-test, or `RECAPTURE_DRYRUN=1`).
- **Per wave merge:** full `seeds_test.exs` + `seeds_script_test.exs` + monotonic guard vs `origin/main`.
- **Phase gate:** design lane Playwright green (content-equivalence un-skipped) + recapture gate all-green + both allowlists empty + monotonic guard green vs `origin/main`.

### Wave 0 Gaps
- [ ] NEW guard self-test (2→1) — covers LEDGER-02 D-05.
- [ ] Raise `seeds_test.exs` admin audit-liveness threshold to `>=25` and add a bulk-cohort idempotency assertion — covers FIXT-01/FIXT-02.
- [ ] Resolve Pitfall 3 (bulk-user domain vs `demo_users` count) before extending seeds.
- [ ] Empirical blast-radius run of both Playwright lanes to enumerate which (if any) PNGs move (Finding 2).

## Snapshot / Recapture Operator Procedure (D-12, D-14, D-15)

This is the riskiest mechanical part. Current, verified procedure:

**Lane map (VERIFIED):**
| Lane | Spec | Snapshot dir | Canary | Allowlist |
|------|------|--------------|--------|-----------|
| Checkpoint | `admin-checkpoints.spec.ts` | `…/admin-checkpoints.spec.ts-snapshots` | `impersonation-banner` | `snapshot-allowlist` |
| Design | `admin-design.spec.ts` | `…/admin-design.spec.ts-snapshots` | `board-notice` | `snapshot-allowlist-design` |

**Procedure:**
1. **Determine real blast radius first.** Boot the example with seeds, run both lanes in compare mode.
   The gate's step (a)/(a2) do exactly this (`snapshot-recapture-gate.sh:64-86`). Note which slugs actually
   drift. Expect the **design lane content-equivalence** path to be the primary mover; gallery boards
   (static assigns) and checkpoint captures (own per-run users) should NOT move — confirm.
2. **Recapture only the moved non-canary slugs**:
   `bash scripts/ci/snapshot-recapture-gate.sh <slug1> <slug2> …` — the gate auto-routes each slug to the
   lane whose snapshot dir contains it (`:32-55`) and applies the correct per-lane canary/allowlist.
   Dry-run the routing first: `RECAPTURE_DRYRUN=1 bash scripts/ci/snapshot-recapture-gate.sh <slug>…`.
3. **Keep both canaries byte-stable.** Never list `impersonation-banner` or `board-notice` in any
   allowlist (both allowlist headers state this explicitly). If a seed change *would* move a canary, that's
   a red flag to investigate, not allowlist.
4. **End the phase with both allowlists reset to empty** (comments only) — mirroring Phase 192's
   steady-state proof (`admin-quality-ledger.md:88`, D-15). Do NOT defer cleanup to Phase 204.
5. Manual `--update-snapshots` is the *input* to the gate, not a substitute: run
   `--update-snapshots` only for intended slugs, restore any unintended PNGs, then let the gate prove
   all-green. The dedicated in-CI `admin_design_recapture` job (`ci.yml:1377-1577`) is for the
   font-driven full recapture and is NOT the right tool here — it recaptures all 72 design PNGs and is
   gated differently. Use the local gate for targeted seed-driven slugs.

## Security Domain

`security_enforcement` is not disabled in config (treated as enabled), but this phase's surface is
docs + demo fixtures + CI tests — it introduces no new auth/crypto/input-handling code paths.

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V5 Input Validation | indirect | Bulk fixtures route through existing `User`/`AuditEvent` changesets — no new validation surface |
| V6 Cryptography | no | No new crypto; demo TOTP secret is existing public-by-design fixture (`personas.ex:18`) |
| Other (V2/V3/V4) | no | No auth/session/access-control logic changed |

**Threat note:** The only security-adjacent invariant is the **`MIX_ENV=test` raise guard** keeping demo
fixtures out of the CI fixture DB (`seeds.exs:17`, contract-tested `seeds_script_test.exs:14`). The bulk
cohort MUST stay under that guard (D-10). No threat model change otherwise.

## Sources

### Primary (HIGH confidence — all VERIFIED via file read this session)
- `scripts/ci/quality-ledger-monotonic.sh` — numeric `[012]` parse, `head_tier -lt base_tier`, `--base` arg
- `scripts/ci/snapshot-recapture-gate.sh` — per-lane slug routing, two canaries, dry-run flag
- `scripts/ci/snapshot-canary-guard.sh` — default canary `impersonation-banner`, allowlist semantics, `--require-all`
- `guides/reference/admin-quality-ledger.md` — ledger table shape, terminal-ratification prose (`:81-84`)
- `.github/workflows/ci.yml` — guard wiring (`:109-110`), design-lane canary/allowlist (`:107-108`), hard-gate note (`:1041`), cross-lane warning (`:1666-1667`)
- `test/example/lib/example/demo/seeds.ex` — `@audit_actions` (`:479-498`), idempotency guard (`:642-651`), insert batch (`:653-712`), `run/0` order (`:49-61`), `print_credentials` (`:64-72`)
- `test/example/lib/example/demo/personas.ex` — `all/0` catalog, `feature_map/0` SSoT (`:188-201`)
- `test/example/test/example/demo/seeds_test.exs` — `demo_users == length(Personas.all())` (`:107,126`), audit-liveness `>=15` (`:285-310`), `snapshot_counts/0` domain filter (`:40`)
- `test/example/test/example/demo/seeds_script_test.exs` — `MIX_ENV=test` raise guard contract (`:14`)
- `test/example/priv/playwright/tests/admin-design.spec.ts` — skip at `:328`, first-listed navigation `:371-378`, static-assign note `:218-220`
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — per-run user registration (`:16-32`), scoped captures (`:210,322`)
- `lib/sigra/audit/changeset.ex:26-28` — reserved prefixes + `~w(success failure error)` (no severity)
- `lib/sigra/admin/audit/query_params.ex:22` + `lib/sigra/admin/users/query.ex:65-71` — `@default_limit 25`, `inserted_at DESC`
- `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` — closes via FIXT-01

### Secondary
- Project MEMORY: Example Playwright boot, Admin baseline auto-gate, Example CSS/JS bundle drift, v1.40 known pre-test failures

## Metadata

**Confidence breakdown:**
- Validation strategy: HIGH — every guard, test, and anchor verified by direct file read.
- Snapshot/recapture mechanics: HIGH — both lanes, both canaries, and routing logic read from source.
- Blast-radius minimization (Finding 2): MEDIUM-HIGH — reasoned from per-run-user registration + scoped queries; flagged for empirical confirmation (A2, OQ1).
- First-listed-user risk (Finding 1/Pitfall 1): HIGH on the sort mechanics; MEDIUM on whether the test lands on `admin` — flagged for empirical confirmation (A3, OQ1).

**Research date:** 2026-06-25
**Valid until:** ~2026-07-25 (stable internal tooling; re-verify line anchors if the seed/CI files churn)
