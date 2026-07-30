---
phase: 232
slug: playwright-economics-authenticate-once-then-shard
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-30
---

# Phase 232 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `232-RESEARCH.md` § Validation Architecture (lines 837–929).

**Binding constraint (D-33, STATE.md, `230-VALIDATION.md:17-21`):** every success criterion in this
phase is a claim about **what a run did**, not about what a file says. Static reads are acceptable
only as **necessary-but-not-sufficient** pre-checks.
`.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` records the precedent failure — *"code-level reads
that never executed the specs"*. A `skipped` job proves nothing.

**Layer vocabulary used throughout this file** — the layer matters as much as the test:

| Layer | Meaning | Can it close a success criterion? |
|-------|---------|-----------------------------------|
| **L1** | Static pre-check (file read, grep, YAML parse) | **No** — necessary, never sufficient |
| **L2** | Hermetic self-test (stubbed `gh`, `/tmp` fixture, node/bash unit) | Only for a criterion *about the instrument* |
| **L3** | Observed real run, read back by run ID | **Yes** — the only layer that closes an SC |

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (library)** | ExUnit (Elixir ~> 1.18) |
| **Framework (browser)** | `@playwright/test` **1.59.1** (lockfile-pinned) |
| **Framework (guards)** | `node:test` (`scripts/ci/prohibitions/*.test.mjs`) + bash hermetic self-tests (`scripts/ci/*.test.sh`) |
| **Config file** | `test/test_helper.exs` · `test/example/priv/playwright/playwright.config.ts` · `.github/workflows/ci.yml` (`fast_checks`) |
| **Quick run command** | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs && mix test test/sigra/planning/` |
| **Full suite command** | `mix test` (requires Postgres and the `phx_new 1.8.8` archive — see CLAUDE.md) |
| **Estimated runtime** | ~15s quick · ~8m full |

---

## Sampling Rate

- **After every task commit:** `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` + `mix test test/sigra/planning/` (~15s)
- **After every plan wave:** the full local guard sweep (every `scripts/ci/*.test.sh` / `*.test.mjs` the wave touched), ~9m with Postgres
- **Per PW-01 / PW-02 landing:** one observed **PR** run *and* one observed **`workflow_dispatch`** run on the phase branch, each captured into a ledger slot
- **Before `/gsd-verify-work`:** every L3 slot below captured with a verbatim run ID
- **Max feedback latency:** ~15 seconds for the static/unit layer

---

## The Observed-Run Evidence Contract (the phase's real gate)

`232-EVIDENCE.md` must exist in the `scripts/ci/prohibitions/_lib.mjs` slot format
(`^## (BEFORE|AFTER)-[A-Z0-9-]+$`; `Status: captured (run <id>)` / `pending (<obligation>)`; ≥1 fenced
block naming `ci-run-metrics.sh` or `gh`; the Status run id repeated ≥2× in the body).
D-31's ordering (PW-01 land → PW-01 measured → PW-03 → PW-02 → PW-02 measured) implies at minimum
these eight slots:

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| **BEFORE-STEPS** | Per-step durations + executed counts for all six seams, from a pre-change PR run. **Also gates the PW-02 shard-axis choice** — five of six seams have never been measured at step granularity | new step-level reader | ⬜ pending |
| **AFTER-PW01-PR** | Same reader, same run event, post-PW-01 | new step-level reader | ⬜ pending |
| **AFTER-PW01-NONPR** | `workflow_dispatch` — the non-PR gallery and recapture lanes, where PW-01's larger savings land | new step-level reader | ⬜ pending |
| **AFTER-PW03-NONPR** | A full non-PR run proving all six booting jobs still boot (SC-4) | `gh run view <id> --json jobs` | ⬜ pending |
| **AFTER-PW02-PR** | Sharded lane at `--retries=0`, per-leg executed counts, wall clock (SC-2, and FAST-01's number) | `gh run view <id> --json jobs` + per-leg `stats.expected` | ⬜ pending |
| **AFTER-PW02-CONTEXT** | `gh pr checks` + ruleset read showing the bare required context resolving (SC-3) | `gh pr checks <n>` + `gh api …/rulesets/14941512` | ⬜ pending (real PR) |
| **AFTER-PW02-REDPROBE** | A deliberately-failed shard leg showing the aggregator red — SC-3's other half | dispatch probe (`nightly_probe` / `force_rot_probe` precedent, `ci.yml:2687`) | ⬜ pending |
| **AFTER-PUSH** | Post-merge `ci-observe.yml` demotion receipt PASS | `scripts/ci/ci-demotion-observer.sh --run <id>` | ⬜ pending (post-merge) |

**Why the red-probe slot is not optional.** Phase 231's GATE-03 became credible precisely because a
deliberate red was observed, not argued. D-22 makes the same point structurally: a job whose `needs`
dependency failed is *skipped*, and a skipped required check **reports success**. Without
`if: always()` a failing shard silently lets the PR merge. The only honest proof that the aggregator
reds is to make a shard leg red and read the aggregator's conclusion.

**Anti-pattern to reject at review:** any verification step whose command is `grep`, `cat`, or `Read`
against `ci.yml` / `admin-design.spec.ts` / `playwright.config.ts` as the *sole* proof of a success
criterion.

---

## Per-Requirement Verification Map

| Req / SC | Behavior | Layer | Automated Command | File Exists | Status |
|----------|----------|-------|-------------------|-------------|--------|
| PW-01 / SC-1 | `beforeEach` no longer calls `registerUser()` | L1 | `grep -c 'registerUser'` on `admin-design.spec.ts`, inside a new contract test | ❌ W0 | ⬜ pending |
| PW-01 / SC-1 | The four `admin-design.spec.ts` text contracts still hold (D-10) | L1 | `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs` | ✅ exists | ⬜ pending |
| PW-01 / SC-1 | axe signal not reduced | L1 | `node --test scripts/ci/prohibitions/p02-*.test.mjs` | ✅ exists | ⬜ pending |
| PW-01 / SC-1 | Setup project wired into exactly the three design projects; `auth.setup.ts` in **both** `testIgnore` arrays (D-06); no CI invocation carries `--no-deps` | L1 | new contract test over `playwright.config.ts` topology (`--list` as cross-check) | ❌ W0 | ⬜ pending |
| PW-01 / SC-1 | **Design-gallery step duration fell, at identical passing assertion and snapshot count** | **L3** | new step-level reader vs. `230-EVIDENCE.md:189-192` baseline (`39 passed (3.9m)`, run `30412458437`) | ❌ W0 (the reader) | ⬜ pending |
| PW-01 / SC-1 | Executed test count unchanged: 39 (PR) / 84 (non-PR) / 123 (recapture) — D-14 requires **counts**, not just durations | **L3** | `N passed` from the `list` reporter **and** `stats.expected` from the `json` reporter | ❌ W0 (json reporter) | ⬜ pending |
| PW-01 | Step-level reader is correct and fail-closed | L2 | new `scripts/ci/<reader>.test.sh` with a PATH-shadowed `gh` stub | ❌ W0 | ⬜ pending |
| PW-02 / SC-2 | **A multi-worker or matrix-sharded run passes at `--retries=0` with no cross-spec interference** | **L3** | `npx playwright test … --retries=0` on the sharded lane, on a real run (D-17: `playwright.config.ts:55` sets `retries: CI ? 1 : 0`, so `--retries=0` must be on the CLI) | ❌ W0 | ⬜ pending |
| PW-02 / SC-2 | No shard leg executed zero tests (D-19) | L3 (in-run) | the emptiness assertion — fires per invocation, permanently | ❌ W0 | ⬜ pending |
| PW-02 / SC-3 | `Example Playwright smoke (full lifecycle)` byte-identical | L1 | `git grep` + `docs-only-receipt.sh:42-48` / `_lib.mjs:196-203` constants | ✅ partial (`p10`) | ⬜ pending |
| PW-02 / SC-3 | **Branch protection still resolves the context on a real PR** | **L3** | `gh pr checks <n>` showing the bare name required, plus ruleset read before/after | ❌ W0 | ⬜ pending |
| PW-02 / SC-3 | Aggregator **fails** when a shard fails (D-22) | **L3** | deliberate red-probe leg; assert aggregator conclusion `failure` | ❌ W0 | ⬜ pending |
| PW-02 | Seam-outcome aggregator's hard-coded step ids carried forward (D-20) | L1 | contract over `ci.yml:1584-1589` loop vs. the post-split step id set | ❌ W0 | ⬜ pending |
| PW-02 | Every runner job has exactly one in-range `timeout-minutes` | L1 | `node --test scripts/ci/prohibitions/p09-*.test.mjs` + `mix test …phase_230_ci_timeouts_test.exs` | ✅ exists | ⬜ pending |
| PW-02 | Manifest ↔ `ci.yml` ↔ `MAINTAINING.md` parity (D-24, D-32) | L1 | `node --test scripts/ci/prohibitions/p10-*.test.mjs` | ✅ exists | ⬜ pending |
| PW-02 | `ci-gate.needs` ↔ nine-lane list parity — shard job **never** added (D-23) | L2 | `bash scripts/ci/honest-skip-verdict.test.sh` | ✅ exists | ⬜ pending |
| PW-02 | The demoted step still executes on a non-PR run **after** the split | **L3** | `bash scripts/ci/ci-demotion-observer.sh --run <id> --format table` | ✅ exists (must stay **resolvable** — see Open Conflict below) | ⬜ pending |
| PW-03 / SC-4 | Exactly one prelude definition | L1 | new contract: `.github/actions/boot-example-app/action.yml` exists **and** no calling job re-declares the prelude steps | ❌ W0 | ⬜ pending |
| PW-03 / SC-4 | Pages publisher still seeds before boot | L1 | rewritten `p15` following the `uses:` indirection | ❌ W0 (rewrite) | ⬜ pending |
| PW-03 / SC-4 | Browser-cache key still discoverable | L1 | `bash scripts/ci/playwright-cache-key-guard.sh` | ✅ exists (may need `--workflow`) | ⬜ pending |
| PW-03 / SC-4 | **Every one of those jobs still boots successfully** | **L3** | full `workflow_dispatch` run with all six booting jobs green | ❌ W0 | ⬜ pending |
| all | `ci.yml` contract tests still pass after the edits | L1 (regression) | `mix test test/sigra/planning/` | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> Per-task IDs are bound at execution time; the planner maps each task to a row above via its
> `<acceptance_criteria>`.

---

## What Can Be Proven Locally vs. Only on CI

| Provable **locally** | Provable **only on a real run** |
|---|---|
| Every guard in § Guard Surface (all have hermetic self-tests or are pure file reads) | Any duration, any executed count, any wall-clock claim |
| Playwright config topology (`--list` shows project/dependency wiring) | Whether the sharded lane actually passes at `--retries=0` |
| The emptiness assertion's logic (reproduce E-2/E-3 in `/tmp`) | Whether a shard leg was empty **on CI** |
| Composite YAML validity (`actionlint`, if available) | Whether the composite boots the app in each of six jobs |
| That the five required-context strings are unchanged (`git grep`) | Whether GitHub **resolves** the required context on a PR |
| That the manifest parses and cross-checks | Whether `ci-demotion-observer.sh` **finds** the construct by API name |

---

## Wave 0 Requirements

- [ ] **Step-level duration reader** + its hermetic self-test, wired into `fast_checks` — blocks SC-1's measurement **and** PW-02's shard-axis choice. `scripts/ci/ci-run-metrics.sh:94-124` is job-level only (its jq never descends into `.steps[]`); model on the step-level resolution in `scripts/ci/ci-demotion-observer.sh:150,161-165` without repurposing it in place (D-11)
- [ ] **`json` reporter** added to `playwright.config.ts` reporters — enables D-14's executed counts and the D-19 emptiness assertion from one change
- [ ] **Shard-emptiness assertion** as a reusable step/script — must cover **both** triggers: the file-count trigger *and* the grep trigger (see the E-3 hazard below)
- [ ] **`232-EVIDENCE.md`** seeded with all eight slots in `_lib.mjs` format, `pending (<obligation>)` where not yet captured
- [ ] **Phase-232 prohibition guards** for the ledger clauses — the existing `p01`/`p03`/`p11`/`p12`/`p13` analogues are hard-pinned to the **230** ledger and will never red on a 232 omission
- [ ] **`p15` rewrite** to follow the `uses:` indirection — must land *with* the composite, not after
- [ ] **`phase_230_design_gallery_split_test.exs` re-anchoring note** — three job-scoped tests, one pinning step *adjacency*; record the re-pointing in-file
- [ ] **`p09` / `phase_230_ci_timeouts_test.exs` decision** on the 45-minute pin against a thin aggregator job, recorded either way
- [ ] **Contract test for the setup-project wiring** (`playwright.config.ts` topology)
- [ ] **Contract test for SC-4** ("exactly one definition")

---

## Hazard the CONTEXT did not name — E-3

Verified live against the pinned Playwright 1.59.1: **`--shard` suppresses Playwright's own
`Error: No tests found` exit-1.** An empty `--grep` alone exits 1 loudly; the *same* grep with
`--shard` exits **0 silently**. Today's two design steps (`--grep-invert '@snapshot'` at
`ci.yml:1497-1503` and `--grep '@snapshot'` at `:1525-1530`) are protected by that exit-1 — **PW-02
removes the protection.**

Consequences for validation:

- D-19's emptiness assertion is **mandatory**, and must cover the **grep** trigger, not just the
  file-count trigger.
- An empty shard leg produces **zero stdout** — there is no `0 passed` line to parse. `stats.expected`
  from the `json` reporter is the only workable signal, which is why the reporter is a Wave 0 item.
- Setup runs once per *invocation* (not per project), and **does** run per shard leg — so setup cost
  is paid once per shard, as CONTEXT's sharding caveats already noted.

---

## Open Conflict to resolve during planning — manifest ↔ observer

If `design_gallery_snapshots` moves into a matrix job, **`p10` demands the manifest record the literal
`Example Playwright smoke shard ${{ matrix.seam }}`**, while **`ci-demotion-observer.sh:150` resolves
it against the API's *interpolated* `… shard design`.** One cell, two incompatible requirements, both
fail closed. RESEARCH documents three resolutions and recommends **keeping the demoted step on a
non-matrix job**. This must be decided in the plan, not discovered at execution.

---

## Correction carried from RESEARCH — D-27 is materially misstated

CONTEXT.md D-27 states the composite "must not unconditionally include an `actions/cache` step"
because `admin_eval_render` declares no cache step as a deliberate structural guarantee.
**`admin_eval_render` *does* declare an `actions/cache` (`ci.yml:2581`).** Its structural guarantee is
about the **Playwright browser** cache only. The deps cache may therefore be unconditional in the
composite — which widens PW-03's freedom and is the difference between meeting SC-4 and leaving the
largest duplicated block unfactored.

**Operative reading: gate only the *browser* cache behind an input; the deps cache need not be gated.**
D-27's *intent* (do not re-open the Phase 231 GATE-04 bug) stands; its stated *fact* does not.

Also corrected: CONTEXT.md's spec paths say `specs/`, but the directory is **`tests/`**.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | — |

*All phase behaviors have automated verification.* Every L3 slot is an **automated command**
(`gh run view` / `gh pr checks` / the new step-level reader) whose precondition is a real CI run —
they require no human judgment, only that the run exists. This preserves the zero-human-UAT posture:
the operator triggers runs, the evidence is machine-read.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (10 items above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s for the static/unit layer
- [ ] All eight observed-run slots captured with verbatim run IDs, or closed as explicit post-merge obligations each carrying its capture command and its reason
- [ ] The D-31 ordering held: `BEFORE-STEPS` and `AFTER-PW01-*` captured **before** PW-02 restructured anything
- [ ] No success criterion closed by a static read alone
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
