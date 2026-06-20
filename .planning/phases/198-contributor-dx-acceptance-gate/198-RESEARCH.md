# Phase 198: Contributor DX & Acceptance Gate - Research

**Researched:** 2026-06-20
**Domain:** CI/CD pipeline DX (Elixir/Phoenix mix aliases) + milestone acceptance-evidence authoring (zero-human-UAT)
**Confidence:** HIGH (all findings grounded in committed repo files; primary uncertainties are scoping decisions, flagged as Open Decisions, not factual gaps)

## Summary

Phase 198 is the closeout phase of v1.40 CI-PERF. It has two deliverables and one residual cleanup, all of which are **process/DX work, not feature work** — no new packages, no library research, no security surface. Everything needed is already in the repo; this phase composes existing pieces and writes the honest evidence.

1. **DX-01** — Ship a single documented local command (`mix ci`) that mirrors the *PR-fast required gate*. No such alias exists today; `mix.exs` has only `ci.audit_45`, `ci.install_golden`, `sigra.dep_off`, `test.db` [VERIFIED: mix.exs:138-161 read this session]. Document it in `CONTRIBUTING.md` (which exists, 3.9KB) [VERIFIED: read this session].
2. **GATE-01** — Produce a committed before/after wall-clock + p95 + flake-rate table proving the PR path is meaningfully faster than the Phase 193 baseline (~38m wall-clock, gated by the serialized 22m Playwright pole) with equal-or-greater required-gate quality signal. The baseline lives at `.planning/phases/193-baseline-observability-one-line-wins/193-BASELINE.md` [VERIFIED: read this session]. The "after" numbers must come from **real CI runs on the post-197 ci.yml**, not estimates.
3. **GATE-02** — Confirm no flake introduced, no correctness-critical coverage dropped from the merge gate, the **5 enforced required-check names are byte-stable**, `mix ci` is documented, SEED-004 (phx_new 1.8.7) is respected, and snapshot/baseline determinism holds.

**Primary recommendation:** Add a `mix ci` alias that chains the locally-reproducible portion of the PR gate (`format --check-formatted` *only if you choose to add it as documentation of intent* — see Open Decision 2; `compile --warnings-as-errors`; `mix test`; `ci.install_golden`; `sigra.dep_off`), with CONTRIBUTING documenting which PR-gate lanes are CI/ubuntu-only (Playwright snapshot baselines, generated-host scaffold smoke) and therefore intentionally *not* in `mix ci`. For GATE-01/02, author a single committed acceptance artifact (e.g. `198-ACCEPTANCE.md`) that diffs real post-197 CI run timings against 193-BASELINE.md, asserts the 5 required-check names unchanged via `gh api`, and records the flake check. Resolve the one outstanding residual: the design-gallery step is still `continue-on-error: true` (soft-gated) and the ubuntu recapture has now landed on main — phase 198 can finally remove it (Open Decision 1).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Local PR-gate reproduction (`mix ci`) | Build tooling (mix aliases) | Dev docs (CONTRIBUTING) | A mix alias is the idiomatic Elixir local-task entry point; CONTRIBUTING is where contributors look |
| Before/after acceptance evidence | Planning artifact (committed .md) | CI observability (`$GITHUB_STEP_SUMMARY`) | The evidence is a durable doc; CI step-summaries (added in 193) feed the numbers |
| Required-check-name stability assertion | CI config (ci.yml `name:` strings) + branch ruleset | ExUnit contract tests (`test/sigra/planning/`) | The names live in ci.yml; the ruleset enforces them; contract tests lock structural invariants |
| Snapshot/baseline determinism | CI scripts (snapshot-canary-guard.sh) | Playwright config + committed PNGs | Determinism is already enforced by the canary guard; 198 must not regress it |

## User Constraints

No `198-CONTEXT.md` exists yet (this research precedes discuss-phase). The binding constraints come from REQUIREMENTS.md, ROADMAP.md Phase 198, and the milestone guardrails:

### Locked Decisions (from REQUIREMENTS.md / ROADMAP.md / CLAUDE.md)
- **SEED-004:** phx_new **1.8.7** pin must be respected everywhere it appears. `mix ci` and any acceptance run must not regress to a newer archive. [VERIFIED: ci.yml installs `mix archive.install --force hex phx_new 1.8.7` in 6 jobs; CLAUDE.md "Local development prerequisites"]
- **Required-check names must stay byte-stable.** The live ruleset **14941512** enforces exactly **5** job `name:` strings (NOT `ci-gate`): `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`. [VERIFIED: MAINTAINING.md:100-122 read this session; ROADMAP D-15 reconciliation note]
- **Snapshot/baseline determinism preserved** — `scripts/ci/snapshot-canary-guard.sh` (canary `impersonation-banner`, steady-state-empty allowlist) must keep passing. [VERIFIED: read this session]
- **Equal-or-greater quality signal** on the required gate. Any faster-but-less-trustworthy change must be explicitly labeled a tradeoff and tiered to nightly. [REQUIREMENTS.md GATE-01]
- **No correctness-critical test stranded on nightly only** (already audited in 196 — the D-08 proxy table). [VERIFIED: 196-04-SUMMARY.md table read this session]
- **Zero-human-UAT** is the verification posture: CI measures itself; `mix ci` is run locally and in CI to prove parity. [ROADMAP Phase 198 verification mechanism; MEMORY zero-human UAT preference]

### Claude's Discretion (research recommends, planner/discuss confirms)
- Tooling choice for the local command: `mix ci` alias vs `make`/`just` target (Open Decision 3 — recommend `mix ci`).
- Whether `mix ci` includes `format --check-formatted` / `credo` / `dialyzer` given those are **not** in the PR gate (Open Decision 2).
- Whether to resolve the design-gallery soft-gate residual in this phase (Open Decision 1 — recommend yes; it's now unblocked).
- Format/location of the acceptance evidence artifact (recommend `198-ACCEPTANCE.md` in the phase dir + a pointer from MAINTAINING.md).

### Deferred Ideas (OUT OF SCOPE)
- Adding Dialyzer/Sobelow as new mandatory PR gates (REQUIREMENTS.md "Out of Scope").
- Multi-OS / broad Elixir-OTP matrix on PRs (Out of Scope).
- Rewriting the pipeline (Out of Scope — stepwise reversible PRs only).
- Per-shard-DB Playwright parallelization (tracked todo `2026-06-20-playwright-parallelization-per-shard-db.md` — a *future* optimization, not a closeout requirement).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-01 | Single documented local CI equivalent (`mix ci`) mirroring the PR gate, documented in CONTRIBUTING | No `mix ci` exists yet (mix.exs:138-161); CONTRIBUTING.md exists and already documents CI overview at a high level — extend it. The reproducible PR-gate steps are enumerated in §"Current PR-Gate Shape" below. |
| GATE-01 | Measured before/after: PR wall-clock + p95 meaningfully faster, equal-or-greater quality signal; tradeoffs labeled and tiered | Baseline = 193-BASELINE.md (~38m wall-clock / 22m post-CRIT-01 target / long-pole table). "After" must be captured from real post-197 CI runs via `gh run view --json jobs`. Quality-signal parity = the 5 required names + ci-gate's needs-list unchanged + the 196 D-08 proxy table. |
| GATE-02 | No flake, no correctness-critical coverage dropped, names stable, `mix ci` documented, SEED-004 respected, determinism preserved | Required names asserted via `gh api ...rulesets/14941512`; flake via repeated-run rate from `gh run list`; determinism via snapshot-canary-guard; phx_new 1.8.7 grep-auditable in ci.yml + mix ci. |

## Current PR-Gate Shape (the thing `mix ci` must mirror)

Enumerated from `.github/workflows/ci.yml` [VERIFIED: read in full this session, 1718 lines].

### Triggers
- `pull_request` → branches: [main] — **the PR-fast gate** (what `mix ci` mirrors)
- `push` → branches: [main]
- `schedule` → `cron: '30 4 * * *'` — **nightly-broad** (exhaustive lanes)
- `workflow_dispatch` (with `force_fail_probe` input)

### PR-path jobs (run on `pull_request`)
These have **no** `if: github.event_name != 'pull_request'` guard, so they run on PRs:

| Job id | `name:` string | Required? | Locally reproducible? |
|--------|----------------|-----------|------------------------|
| `release_ref_guard` | Release ref guard | no | n/a (manual-release guard; no-op on PR) |
| `fast_checks` | Fast checks (milestone/installer/contracts/snapshot/ledger guards) | no (flows into ci-gate) | partial — shell guards run locally; some need git base ref |
| `install_golden_contract` | Install golden + idempotency contract (subprocess harness) | no (path-scoped → ci-gate) | YES — `mix ci.install_golden` (needs PG + phx_new 1.8.7) |
| `library_tests_shard` (matrix 1,2) | Library tests shard N | no (feeds aggregator) | YES — `mix test` (or `MIX_TEST_PARTITION=1 mix test --partitions 2`) |
| `library_tests` (aggregator) | **Library tests** | **REQUIRED** | YES — `mix test` (full suite locally; shards are a CI parallelism detail) |
| `library_tests_dep_off` | Library tests (dep-off — Threadline absent) | no (→ ci-gate) | YES — `mix sigra.dep_off` (exact CI command parity, mix.exs:151-156) |
| `example_unit_smoke` | **Example unit smoke (ExUnit + ConnTest)** | **REQUIRED** | YES — `cd test/example && mix test --include example_app` (needs PG) |
| `install_smoke` | **Install smoke (fresh phx.new + sigra.install)** | **REQUIRED** | YES but heavy — `scripts/ci/install-smoke.sh` (needs PG + phx_new 1.8.7 + CLOAK_KEY) |
| `example_http_smoke` | **Example HTTP smoke (boot + curl critical routes)** | **REQUIRED** | YES — boot example + `scripts/ci/http-smoke.sh` (needs PG) |
| `example_playwright_smoke` | **Example Playwright smoke (full lifecycle)** | **REQUIRED** | partial — Playwright behavior specs run locally; **visual snapshot baselines are ubuntu-only** (see Landmines) |
| `ci-gate` | ci-gate | no (internal aggregator) | n/a |

### Nightly-only jobs (guarded `if: github.event_name != 'pull_request'`)
[VERIFIED: ci.yml lines 518, 571, 622, 752, 1224, 1404, 1711]
`upgrade_smoke` (516), `passkeys_manual_fallback_smoke` (569), `install_matrix` ×4 (620), `passkeys_opt_out_smoke` (750), `generated_admin_playwright_smoke` (1222), `admin_design_recapture` (1402), `nightly_probe` (1709). **`mix ci` must NOT include these** — they are the broad tier (CRIT-02), and 196's D-08 table records each one's PR-path proxy.

### The 5 enforced required checks (ruleset 14941512)
[VERIFIED: MAINTAINING.md:100-122] Only these 5 `name:` strings block merge. `ci-gate` is an internal aggregator that `needs:` 9 jobs (install_golden_contract, library_tests, library_tests_dep_off, install_smoke, upgrade_smoke, example_http_smoke, example_playwright_smoke, generated_admin_playwright_smoke, fast_checks) and tolerates `skipped` (so nightly-skipped jobs don't red the gate on PRs) [VERIFIED: ci.yml:1342-1392]. **GATE-02's name-stability assertion targets these 5 strings + the ci-gate needs-list.**

## Recommended `mix ci` Composition (DX-01)

### Pattern: thin alias chaining locally-faithful steps; document the CI-only gaps

**Recommendation — add to `mix.exs` aliases/0:**

```elixir
# DX-01: single local mirror of the PR-fast required gate. Chains the
# locally-reproducible portion; CI-only lanes (ubuntu Playwright snapshot
# baselines, generated-host scaffold smoke) are documented in CONTRIBUTING
# as intentionally out of scope for the local command. Requires Postgres
# (see CLAUDE.md) and the phx_new 1.8.7 archive (SEED-004) for the install
# golden leg. Run: mix ci
"ci": [
  "compile --warnings-as-errors",
  "test",
  "ci.install_golden",
  "sigra.dep_off"
]
```

Rationale for each leg:
- `compile --warnings-as-errors` — every required CI job compiles this way; a contributor's first red is usually a warning. [VERIFIED: ci.yml uses `--warnings-as-errors` in library/example/install jobs]
- `test` — mirrors the **Library tests** required check (the shard partitioning is a CI parallelism detail; the same tests run). [VERIFIED: ci.yml:255 `mix test --partitions 2`]
- `ci.install_golden` — mirrors `install_golden_contract` (golden-diff + idempotency); already a documented local repro in MAINTAINING.md:40. [VERIFIED: mix.exs:143-145]
- `sigra.dep_off` — mirrors `library_tests_dep_off` exactly (its final command is byte-identical to the CI step). [VERIFIED: mix.exs:151-156 vs ci.yml:380-386]

**Tradeoff to label in CONTRIBUTING (the honest "what `mix ci` cannot reproduce locally"):**
- **Ubuntu-baselined Playwright visual snapshots** — `admin-design` / `admin-checkpoints` PNG baselines are captured on ubuntu CI; macOS-local Playwright runs will show font-metric pixel diffs (this is the exact root cause Phase 197 fixed for CI, but it is OS-specific). A contributor can run Playwright *behavior* specs locally but should not trust local *snapshot* comparisons. Direct them to the CI artifact (`admin-example-report`) for visual review, per CONTRIBUTING's existing "Reviewing admin Playwright artifacts" section.
- **`install_smoke` / `example_http_smoke`** — reproducible but heavy (scaffold a fresh phx.new app + boot). Document the exact commands (`scripts/ci/install-smoke.sh`, boot + `scripts/ci/http-smoke.sh`) as an *optional* deeper local check rather than folding the multi-minute scaffold into the default `mix ci`. (Open Decision 4.)
- **Prerequisites:** PG must be up (`scripts/db/up.sh` + `source tmp/db.env`, per CLAUDE.md) and the phx_new 1.8.7 archive installed (`mix archive.install --force hex phx_new 1.8.7`) for the install-golden leg. CONTRIBUTING must state these or `mix ci` gives a misleading red.

### Anti-Patterns to Avoid
- **Don't add `format --check-formatted`, `credo --strict`, or `dialyzer` to `mix ci` silently.** None of those are in the PR gate today [VERIFIED: grep of ci.yml found NONE]. Adding them makes `mix ci` *stricter than the gate*, so a contributor could get a local red that CI is green on — the opposite of DX-01's "reproduce a red CI check locally." If you want them, that's a *separate* decision to also add them to CI (out of scope — REQUIREMENTS.md forbids new mandatory gates). See Open Decision 2.
- **Don't make `mix ci` include nightly-broad lanes** (install_matrix, upgrade_smoke, generated-host) — it would no longer mirror the *PR* gate and would be slow.
- **Don't use `make`/`just`** unless there's a reason — this is an Elixir lib; `mix` aliases are the idiomatic, discoverable, zero-extra-dependency entry point and the repo already uses the `ci.*` alias namespace.

## Acceptance Evidence Authoring (GATE-01 / GATE-02)

### Where the baseline lives
`193-BASELINE.md` [VERIFIED: read this session] is the falsifiable reference. Key numbers to diff against:
- **Wall-clock (pre-CRIT-01):** ~38.4m avg, p95 ~40m (n=6, 2026-06-19 cohort) — gated by `example_playwright_smoke` (22.2m) *serialized behind* `library_tests` (15.9m).
- **Expected post-CRIT-01 wall-clock:** ~22m (Playwright pole no longer serialized).
- **Per-job long poles:** example_playwright_smoke 22.2m (p95 22.3m), library_tests 16.0m (p95 16.3m), library_tests_dep_off 13.8m (p95 14.0m).
- **Named optimization targets table** (193-BASELINE §Summary) gives the expected improvement per phase: TEST-01 partition → <8m, TEST-02 dep-off → <3m.

### How wall-clock + p95 are measured in this repo
[VERIFIED: 193-BASELINE.md §Commit-safe verification] All CI timing was gathered read-only via `gh run view --json jobs` (authenticated `gh`). The "after" capture must use the same method on **post-197 PR runs of the current ci.yml**. p95 needs a sample (193 used n=9 across a week); for the "after" you need several recent PR-path runs — gather via `gh run list --workflow CI --json ... ` then `gh run view <id> --json jobs`. BASE-03 also added `$GITHUB_STEP_SUMMARY` observability (versions, cache hit/miss, slowest-tests) [VERIFIED: ci.yml CI-run-summary + Test-timing-summary steps].

### "After" must be real, not estimated
The success criterion is a *measured* before/after. The honest path:
1. Ensure the post-197 ci.yml is on main (it is — PR #58 merged the partial v1.40, PR #60 merged the ubuntu recapture) [VERIFIED: `git log` this session].
2. Trigger / collect several PR-path CI runs on the current pipeline.
3. Pull per-job durations + run-level wall-clock with `gh run view --json jobs`.
4. Compute p95 from the sample; compute flake-rate (failed-then-passed reruns / total).
5. Tabulate before (193-BASELINE) vs after side-by-side.

If real "after" runs are not yet plentiful, the plan should include a step to **generate the runs** (e.g. trigger N CI runs) rather than substituting estimates — estimates would violate the zero-human-UAT "CI measures itself" contract.

### Recommended artifact: `198-ACCEPTANCE.md`
Mirror 193-BASELINE's table shape so the diff is mechanical. Suggested sections:
- **Before/after wall-clock + p95 table** (run-level and per-long-pole job).
- **Quality-signal parity proof:** the 5 required `name:` strings unchanged (paste `gh api repos/szTheory/sigra/rulesets/14941512 --jq '...'` output); ci-gate needs-list unchanged; the 196 D-08 per-moved-job proxy table referenced (no correctness-critical test stranded).
- **Flake-rate:** before vs after rerun rate; confirm FLAKE-01 (demo-showcase rgb) de-flaked and `retries` not masking.
- **Tradeoffs ledger:** any speed-for-trust move tiered to nightly (the 196 broad split) — already documented in MAINTAINING.md §"CI cadence"; reference it.
- **SEED-004 + determinism attestation:** phx_new 1.8.7 still pinned (grep-auditable); snapshot-canary-guard still green.

Add a one-line pointer from MAINTAINING.md to this artifact (ADD-only discipline, matching how 196-04 appended its CI-cadence subsection).

## Outstanding Residual: Design-Gallery Soft-Gate (resolve in 198?)

**This is the single most important landmine and a live decision.** [VERIFIED this session:]
- The 197-05 SUMMARY claims `continue-on-error: true` was *removed* (hard-gated). **But the current ci.yml STILL has `continue-on-error: true` on the design_gallery step (line 1047), marked `TEMP SOFT-GATE`.** [VERIFIED: grep + read ci.yml:1037-1047]
- Reason: a **bootstrap deadlock** — the committed admin-design baselines were macOS-captured; the recapture job (`admin_design_recapture`) only runs on push/schedule (post-merge), so the PR that introduced it couldn't pass the hard gate. So it was re-softened to ship v1.40. [VERIFIED: todo `2026-06-20-complete-d10-design-gallery-re-gate-after-recapture.md` read this session]
- **The deadlock is now resolved:** PR #60 ("recapture admin-design baselines in ubuntu CI") **is merged to main** [VERIFIED: `git log` — commit 9eed3474]. So step 2 of the deferral todo is done; **step 3 (remove the `TEMP SOFT-GATE continue-on-error`) is now unblocked.**
- The aggregator (`Aggregate Playwright step outcomes`, ci.yml:1102-1127) currently **omits** `design_gallery` from its failure loop while soft-gated [VERIFIED: ci.yml:1118-1123 loop excludes design_gallery]. Restoring the hard gate means re-adding `design_gallery.outcome` to that loop *and* removing `continue-on-error`.

**Recommendation:** Phase 198 should close this — it directly serves GATE-02 ("snapshot/baseline determinism preserved" and "no correctness-critical coverage dropped"). The design-gallery is a correctness-critical visual gate that is currently non-blocking. Leaving it soft would make the "equal-or-greater quality signal" claim dishonest. The OQ3 cross-lane compare came back **clean** (no `oq3-cross-lane` todo exists → siblings did not shift) [VERIFIED: ls of pending todos], so there's no sibling-lane drift blocking the hard re-gate. **Open Decision 1** confirms scope with the user, but the evidence says: do it here.

> Note: there is a *second* `continue-on-error: true` at ci.yml:1612 on the OQ3 cross-lane compare step inside `admin_design_recapture` (a nightly-only measurement step) — that one is intentional and should stay. Don't touch it.

## Landmines (read before planning)

| # | Landmine | Detail | Mitigation |
|---|----------|--------|------------|
| 1 | **Design-gallery still soft-gated** | ci.yml:1047 `continue-on-error: true` (TEMP); aggregator omits design_gallery | Recapture merged (#60) → unblocked; remove continue-on-error + restore aggregator loop entry. See above. |
| 2 | **Known pre-existing local `mix test` failures** | MEMORY: 6 known env/golden failures on v1.40 (Phase51 ci-contract drift, golden-diff phx 1.8.8-vs-1.8.7, 3 UpgradeIntegrationTest env-DB). NOT regressions. | `mix ci` run locally will show these if the env differs from CI (esp. phx_new 1.8.8 installed locally vs 1.8.7 pin). CONTRIBUTING must tell contributors to install phx_new **1.8.7** (CLAUDE.md already does). Don't "fix" these in 198. |
| 3 | **phx_new 1.8.8 byte-diff trap (SEED-004)** | A newer archive adds a `config :phoenix_live_view, root_tag_attribute:` block → spurious golden-diff failure locally while CI (1.8.7) is green. | `mix archive.install --force hex phx_new 1.8.7`. Do NOT regenerate the fixture. [VERIFIED: CLAUDE.md] |
| 4 | **Phase51 contract-test todo is STALE** | Todo `2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md` says the test asserts the removed `installer_milestone_audit:` job key. **The test no longer does** — it now asserts `install_golden_contract:` + the fast_checks step + the duplicated path-detector regex (×2). [VERIFIED: read test file + grep'd, no old-job-key assertion]. | The todo can be closed as already-resolved; don't re-fix. But verify `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` is green after any ci.yml edit (the regex-count×2 assertion is sensitive to ci.yml structure). |
| 5 | **Editing ci.yml can break contract tests** | `phase_51` locks the path-detector regex appearing **exactly twice** in ci.yml; `phase_192` locks the `test.skip(` marker on admin-design MG-5/6. | Any ci.yml change (e.g. re-gate) must keep the path-detector ×2 and not touch MG-5/6 skip. Run `mix test test/sigra/planning/` after edits. |
| 6 | **PG + dynamic-port harness** | `mix test` (and thus `mix ci`) needs live Postgres; the repo uses an ephemeral dynamic-port docker PG (`scripts/db/up.sh` → `tmp/db.env`). Falls back to localhost:5432. | CONTRIBUTING must document the PG prereq (it already links CLAUDE.md). `mix ci` will hard-fail (by design — no `:postgres` exclusion) without it. |
| 7 | **Required-check name byte-stability** | Renaming any of the 5 `name:` strings (or the `library_tests` aggregator name, marked "DO NOT EDIT (D-02)") strands the required check → merge outage. | GATE-02 assertion: `gh api ...rulesets/14941512`; diff against the 5 known strings. Never edit `name: Library tests` (ci.yml:290). |
| 8 | **Don't strand coverage to make numbers prettier** | Moving more to nightly speeds PRs but the 196 D-08 table is the contract that nothing correctness-critical is nightly-only. | 198 should not move anything new to nightly; it measures the *existing* split. Any new move must update the D-08 proxy table. |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local PR-gate runner | A bash script or Makefile reimplementing the gate | `mix` alias chaining existing aliases (`ci.install_golden`, `sigra.dep_off`) | Idiomatic Elixir; reuses already-verified per-lane commands; zero new deps |
| Snapshot determinism check | Custom PNG diff in `mix ci` | `scripts/ci/snapshot-canary-guard.sh` (already gates in fast_checks) | Already solves canary + allowlist + base-ref logic |
| CI timing capture | Scraping HTML or hand-stopwatching | `gh run view --json jobs` (the method 193-BASELINE used) | Authoritative, scriptable, already the established repo method |
| Required-name assertion | Reading ci.yml and guessing | `gh api repos/szTheory/sigra/rulesets/14941512 --jq '...'` | Asserts the *live enforced* set, not just the file |
| dep-off local repro | Hand-removing threadline | `mix sigra.dep_off` (mix.exs:151) | Byte-identical to the CI lane's final command |

## Validation Architecture

> nyquist_validation: config not checked for an explicit `false`; treating as enabled. This phase is CI/DX/docs — its "tests" are the contract tests + the acceptance evidence itself.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir ~> 1.18 / 1.19.5) |
| Config | `test/test_helper.exs` (`ExUnit.start(exclude: [:postgres])`) |
| Quick run command | `mix test test/sigra/planning/` (contract locks) |
| Full suite command | `mix test` (needs PG + phx_new 1.8.7) |
| Local mirror (new) | `mix ci` (this phase delivers it) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | Exists? |
|-----|----------|-----------|-------------------|---------|
| DX-01 | `mix ci` exists + mirrors PR gate | structural | `mix ci` runs green locally (with PG + 1.8.7) | ❌ deliver in 198 |
| DX-01 | `mix ci` documented in CONTRIBUTING | doc-contract | optional: extend a `phase_*_ci_contract_test.exs` to assert CONTRIBUTING mentions `mix ci` | ❌ optional new lock |
| GATE-02 | Required names stable | assertion | `gh api ...rulesets/14941512 --jq '...'` == 5 known strings | ✅ method exists (MAINTAINING) |
| GATE-02 | ci.yml contract invariants hold after re-gate | unit | `mix test test/sigra/planning/phase_51... phase_192...` | ✅ exist |
| GATE-02 | Snapshot determinism | shell | `bash scripts/ci/snapshot-canary-guard.sh` | ✅ exists |
| GATE-01 | Before/after measured | evidence | author `198-ACCEPTANCE.md` from `gh run view --json jobs` | ❌ deliver in 198 |

### Wave 0 Gaps
- [ ] `mix ci` alias in `mix.exs` — covers DX-01.
- [ ] CONTRIBUTING.md section documenting `mix ci` + prereqs + CI-only caveats — covers DX-01.
- [ ] `198-ACCEPTANCE.md` (or chosen name) with real before/after numbers — covers GATE-01.
- [ ] (Optional) a `phase_198_*_contract_test.exs` locking `mix ci` presence in mix.exs + CONTRIBUTING mention — consistent with the repo's contract-lock pattern; recommend it so `mix ci` can't silently drift out of CONTRIBUTING.
- [ ] (If Open Decision 1 = yes) remove `continue-on-error: true` at ci.yml:1047 + restore `design_gallery` to the aggregator loop.

## State of the Art

| Old (193-BASELINE) | Current (post-197) | When | Impact |
|--------------------|--------------------|------|--------|
| example_playwright_smoke serialized behind library_tests | decoupled (CRIT-01, 193-03) | Phase 193 | -16m wall-clock |
| `library_tests` single 16m runner | 2-shard partition + aggregator | Phase 195 | ~halved test portion |
| `library_tests_dep_off` full 14m re-run | `--only threadline_guard` subset (~65 tests) | Phase 195 | <3m target |
| Install matrix ×4 + upgrade + generated-host on every PR | moved to nightly `cron: '30 4 * * *'` | Phase 196 | lighter PR path |
| `ci-gate` framed as the required check | 5 lane `name:` strings enforced by ruleset 14941512; ci-gate = aggregator | Phase 196 (D-13/D-15) | name-stability target clarified |
| design-gallery `continue-on-error` (SEED-006, font reflow) | hard-gate intended; **currently still soft (bootstrap deadlock, now unblocked)** | Phase 197 / 198 | the one open residual |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The post-197 ci.yml on main is the final PR-gate shape `mix ci` must mirror (no further ci.yml change pending before 198 besides the re-gate) | Current PR-Gate Shape | Low — verified via git log #58/#60 merged; if a later PR alters lanes, re-enumerate before authoring `mix ci` |
| A2 | "After" CI runs on the current pipeline are available or can be triggered to compute p95 | GATE-01 | Medium — if too few runs exist, the plan must include a step to generate them; do NOT substitute estimates |
| A3 | OQ3 cross-lane compare came back clean (no sibling-lane font drift) so the design-gallery hard re-gate has no blocking dependency | Design-Gallery Residual | Low — inferred from absence of an `oq3-cross-lane` pending todo; confirm by checking the latest `admin_design_recapture` run log before re-gating |
| A4 | Adding format/credo/dialyzer to `mix ci` is undesirable because they're absent from the PR gate | mix ci Composition | Low — this is a recommendation; Open Decision 2 lets the user override |

## Open Questions / Decisions for the Planner

1. **Resolve the design-gallery soft-gate in 198?** Evidence says yes (recapture merged, OQ3 clean, serves GATE-02). Risk: it touches a REQUIRED lane (`Example Playwright smoke`) — the hard gate must be confirmed green against the new ubuntu baselines first. *Recommendation: include it; gate it behind a confirm-green step.*
2. **Does `mix ci` include `format --check-formatted` / `credo --strict`?** They are NOT in the PR gate. Including them makes `mix ci` stricter than CI (local red where CI is green) — contradicts DX-01's intent. *Recommendation: exclude; document them separately as "additional local hygiene" if desired, not as part of the gate mirror.*
3. **`mix ci` vs `make`/`just`?** *Recommendation: `mix ci` — idiomatic, no new dependency, matches the existing `ci.*` namespace.*
4. **Does `mix ci` include the heavy scaffold lanes (`install_smoke`, `example_http_smoke`)?** They're reproducible but multi-minute and need a fresh phx.new app. *Recommendation: keep `mix ci` fast (compile + test + install_golden + dep_off); document install_smoke/http_smoke as an optional deeper local check with exact commands.* The user (per MEMORY: one-shot coherent rec, optimize DX) likely wants the fast default.
5. **Where does the acceptance evidence live + what's the artifact name?** *Recommendation: `198-ACCEPTANCE.md` in the phase dir, mirroring 193-BASELINE's table shape, with a MAINTAINING.md pointer (ADD-only).*
6. **Close the stale Phase51 todo?** The contract test is already fixed (Landmine #4). *Recommendation: close `2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md` as already-resolved during this phase's hygiene.*

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | `mix test`, `mix ci`, install/http smokes | assumed (dev machine) | — | `scripts/db/up.sh` ephemeral docker PG → `tmp/db.env`; else localhost:5432 |
| phx_new archive | install golden / install smoke | must be **1.8.7** | 1.8.7 (SEED-004) | none — newer version breaks golden-diff |
| `gh` CLI | GATE-01 timing capture, GATE-02 ruleset assertion | assumed (193 used 2.94.0) | ≥2.94 | none — required for honest "after" capture |
| node/npm + Playwright | example_playwright local (behavior only) | assumed | node 20 (CI) | snapshot lanes are CI-only regardless |

**Missing-with-no-fallback:** phx_new must be exactly 1.8.7; `gh` must be authenticated for the acceptance capture.

## Sources

### Primary (HIGH confidence — read this session)
- `.github/workflows/ci.yml` (full, 1718 lines) — PR/nightly job split, required names, ci-gate, design-gallery soft-gate, recapture job
- `.planning/phases/193-baseline-observability-one-line-wins/193-BASELINE.md` — before-state numbers + measurement method
- `mix.exs` — existing aliases (no `mix ci`), deps, phx_new usage
- `CONTRIBUTING.md`, `MAINTAINING.md` (required-check + CI-cadence sections)
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` (Phase 198 + D-15 reconciliation)
- `.planning/phases/196-*/196-04-SUMMARY.md` (D-08 proxy table, 5-name enforcement)
- `.planning/phases/197-*/197-05-SUMMARY.md`, `197-UAT.md` (re-gate + bootstrap-deadlock context)
- `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs`, `phase_192_known_failure_contract_test.exs`
- `.planning/todos/pending/2026-06-20-complete-d10-design-gallery-re-gate-after-recapture.md`, `...phase51-installer-milestone-audit-ci-contract-stale.md`
- `.planning/STATE.md`, `scripts/ci/snapshot-canary-guard.sh`, `.tool-versions`
- `git log` (PR #58 partial-v1.40 + #60 recapture merged to main)

### Secondary (MEDIUM)
- Project MEMORY notes (known v1.40 pre-test failures; phx_new 1.8.7 pin; zero-human-UAT preference; one-shot decision style)

## Metadata

**Confidence breakdown:**
- Current PR-gate shape / required names: HIGH — read ci.yml in full + ruleset doc
- `mix ci` recommendation: HIGH — grounded in existing aliases + actual CI commands; only the format/credo inclusion is a discretionary call (flagged)
- Before/after method: HIGH — 193-BASELINE documents the exact `gh` method; the "after" numbers themselves are not yet captured (that's the phase work)
- Design-gallery residual: HIGH — verified the live ci.yml state + merge status + OQ3 cleanliness
- Landmines: HIGH — each verified against a specific file/line this session

**Research date:** 2026-06-20
**Valid until:** ~2026-07-20 (stable; invalidated earlier if ci.yml lanes change before 198 plans land)
