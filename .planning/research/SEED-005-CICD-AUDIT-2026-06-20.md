# SEED-005 — CI/CD Pipeline Performance Audit (Final Integrated Plan)

**Date:** 2026-06-20
**Scope:** `.github/workflows/ci.yml` (+ `release-please.yml`, `hex-publish.yml`, `playwright-github-pages.yml`), `mix.exs`, `test/**`, `test/example/priv/playwright/**`, branch-protection ruleset `14941512`.
**Baseline run:** `27883386841` (PR `ship/v1.40-ci-perf`, event=pull_request, green). Representative-confirmed against `27854244136`, `27846034918`, `27847562459`.
**Status of prior work:** v1.40 CI-PERF phases 193–197 already landed: baseline/observability, cache-key precision + micro-job fold (`fast_checks`), `library_tests` 2-way partition + per-shard PG + name-preserving aggregator, PR-fast/nightly-broad trigger split for install-matrix/upgrade/passkeys/generated-admin/recapture, and Playwright failure-surfacing + determinism (`!cancelled()` seams, `expect.poll`, self-hosted font). This audit finds the **remaining** wins only. None of the recommendations below re-do 193–197.

> **North Star (Jon, verbatim intent):** fast PR feedback; deterministic non-flaky gates; never trade trust for speed (any speed-for-trust change is flagged + moved to optional/nightly); keep HIGH-value tests, demote/delete ONLY lowest-signal/redundant/flaky/over-scoped with evidence; use all runner cores intelligently without a Rube Goldberg pipeline; caching done right; one local `mix ci` mirroring CI; fast/deterministic/bulletproof specs.

---

## 1. Executive Summary

The single PR wall-clock determinant is **`example_playwright_smoke` at 1226s (~20.4 min)** — 2.4× the next-longest job (`library_tests` shard 2 at 518s, which runs in parallel and finishes ~12 minutes earlier). Inside that one job, **the `design_gallery` step alone is 700s (57% of the job)**, it is currently `continue-on-error: true` AND omitted from the aggregator (so it gates **nothing** on PRs today), and **~700s of it is wasted re-registering a fresh admin user before every one of ~102 board tests** over dev-mode longpoll. That is the bottleneck-on-the-bottleneck, and it is the headline.

The whole audit therefore reduces to one ordered campaign: **make the Playwright critical path collapse**, in this order — (1) stop the per-test re-registration, (2) move the pixel-snapshot gallery to nightly while keeping its a11y/behavior signal on PRs, (3) matrix-shard the remaining seams with per-shard DB+app. Stacked, these take PR Playwright from ~20.4 min to roughly **5–6 min**, making the `library_tests` shard (~8.6 min) the new — and far healthier — pole. Everything else is cost/trust/DX hygiene that adds ~zero PR wall-clock.

### Top 5 changes

| # | Change | Impact (verified/corrected) | Risk | First PR? |
|---|--------|------------------------------|------|-----------|
| 1 | **Kill per-test re-registration in `admin-design.spec.ts`** (one `storageState` per design project; `beforeEach` = goto + ready only) | Design seam **~700s → ~250–300s**; **−6 to −7.5 min PR wall-clock**, 100% on the sole critical path. Largest single win, no coverage loss. | Low | **Yes (Phase 198)** |
| 2 | **Move the pixel-snapshot gallery to nightly; keep axe a11y + L1-state behavior on PR** | Removes the remaining gallery snapshot mass from PR (~−500s) while preserving the only PR-enforced signal it carries (axe WCAG on **library** admin components). | Low–Med (must extract a11y, not move it) | Phase 199 |
| 3 | **Matrix-shard the Playwright seams (per-shard DB + app) behind a name-preserving aggregator** | After #1/#2, collapses residual ~519s serial seams to ~max-shard ~311s. Net stacked PR Playwright ~5–6 min. | Med (required-check name) | Phase 200 |
| 4 | **Add `concurrency:` to cancel superseded PR runs** (PR-only guard) | Reclaims ~40–50 runner-min per superseded fixup push; faster requeue. Idiomatic — the repo's 3 other workflows already have it; `ci.yml` is the lone exception. | Very low | **Yes (Phase 198, bundle)** |
| 5 | **Add a static-check tier (`format`/deps-lock) + `mix ci` alias + make `ci-gate` the required check** | Closes 3 trust gaps at ~zero PR wall-clock: missing format/deps gates, dep-off/golden not enforced, no local mirror. | Low–Med (format needs a one-time tree format; ruleset edit needs admin) | **Yes (Phase 198, bundle)** |

### Recommended first phase

**Phase 198 — "Quick wins + DX bundle" (no Playwright restructure yet):**
1. `admin-design.spec.ts` `storageState` refactor (the −6 to −7.5 min win — low risk, no structural CI change).
2. `concurrency:` block.
3. `mix ci` alias + `deps.get --check-locked` + `deps.unlock --check-unused` wired into `fast_checks` (both exit-0 on `main` today), CONTRIBUTING update.
4. Pin `release-please-action` to its dereferenced commit SHA (security, zero perf).

This banks the biggest single wall-clock win plus all the zero-risk cost/trust/DX items in one phase, before touching workflow topology.

---

## 2. Current Pipeline Map + Critical Path

**One workflow** `ci.yml`, triggers: `push:[main]`, `pull_request:[main]`, `schedule` (nightly cron), `workflow_dispatch`. All jobs `ubuntu-latest` (2-core). A `ci-gate` aggregator (`ci.yml:1342`, `if: always()`, skipped→pass, any failure→fail) `needs:` 9 lanes. The 3 sibling workflows all have `concurrency:`; `ci.yml` does **not**.

### Critical-path table (run 27883386841, event=pull_request)

| Job | Duration | On PR? | Required? | Bottleneck / notes |
|-----|----------|--------|-----------|--------------------|
| **example_playwright_smoke** | **1226s** | yes | yes (ruleset) | **SOLE wall-clock determinant.** 5 serial `npx playwright test` seams on 1 booted app + 1 PG, `workers:1`. `needs:[release_ref_guard]` only — runs parallel to library_tests. |
| └ design gallery step | 700s | — | **no (soft-gate)** | `continue-on-error:true` (`ci.yml:1047`), omitted from aggregator (`ci.yml:1118-1122`). ~102 per-test re-registrations over longpoll. |
| └ non_admin_smoke | 186s | — | yes | golden-path/org/passkey, chromium+mobile(WebKit), shared DB. |
| └ admin_checkpoints | 125s | — | yes | chromium/mobile/dark; batches captures (only ~6 registrations total). |
| └ admin_behavior | 81s | — | yes | chromium only. |
| └ demo_showcase | 22s | — | yes | |
| └ prelude (warm) | ~107s | — | — | container 25s + **browser install 48s** + setup-beam/node + compile/deps/db/seeds/npm. |
| library_tests shard 2 | 518s | yes | yes | ~400s = phx.new/upgrade subprocess tests; ~6s genuine async unit residual. Finishes ~12 min before Playwright. |
| library_tests shard 1 | 464s | yes | yes | ~287s = passkeys subprocess tests. |
| library_tests_dep_off | 202s | yes | **no (advisory!)** | 58s deps.compile + 84s `mix docs` (dev-env, second cold compile) + 18s real dep-off proof. |
| install_golden_contract | 34s (detect-skipped here) | yes | **no (advisory!)** | golden_diff + idempotency; runs only on installer-touching PRs. |
| fast_checks | 11s | yes | yes-ish | folded micro-guards. No format/credo/deps-lock. |
| example_unit_smoke | — | yes | **yes — but NOT in `ci-gate.needs`** | orphan: required but unaggregated. |
| install_smoke / example_http_smoke | <60s | yes | yes | |
| upgrade_smoke / generated_admin_playwright_smoke / passkeys / install_matrix / admin_design_recapture | — | **no (nightly/push)** | no | already PR-gated-off by 193–196. |

**Critical path:** `release_ref_guard` (~2s) → `example_playwright_smoke` (1226s) → `ci-gate`. Wall-clock = 1236s. The 700s gallery step is **57% of the determining job and the single largest unit of work in the entire pipeline.**

**Required-check ruleset `14941512`:** exactly 5 contexts — `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`. `ci-gate` is **not** required; `library_tests_dep_off` and `install_golden_contract` are required by **nothing**.

---

## 3. Findings by Category

**Performance / critical path**
- Design-gallery per-test re-registration (~700s, the #1 hotspot) — *confirmed*.
- Gallery is 57% of the sole PR pole AND non-gating today — *confirmed*.
- Playwright seams serialize on one boot; shardable after isolation — *real, impact contingent on gallery work landing first*.
- phx.new/upgrade subprocess integration tests dominate `library_tests` shards (~400s/shard) and partly duplicate `install_golden_contract` — *confirmed; but shards are OFF the critical path, so this is runner-minutes + future-proofing, not PR latency, until Playwright is fixed*.

**Caching**
- Shared `-library-` cache holds deps only (4.7 MB), no compiled `_build/test` → both shards cold-recompile ~63s despite "cache-hit: true" — *confirmed defect; OFF critical path → runner-minutes, not PR latency*.
- Playwright browser binaries (`~/.cache/ms-playwright`) uncached; 48s prelude — *confirmed, but cacheable slice is only ~14s (the ~33s `--with-deps` apt is not cacheable); net ~5–12s; P3, not P1*.
- dep-off lane: `mix docs` runs in dev env → second cold compile (~84s wasted) — *confirmed; the proposed "run docs in MIX_ENV=test" fix is **refuted** (ex_doc is `only: :dev`); use a `_build/dev` cache instead*.

**Determinism / flakiness**
- 18 specs mint test data with bare `Date.now()` — *real latent flake, but only bites the intra-config multi-worker-on-shared-DB strategy; not a universal prerequisite. P2 enabler*.
- 2 `waitForLoadState('networkidle')` in passkey specs — Playwright-discouraged, redundant with next auto-retrying assertion — *confirmed, P2*.
- `token_test.exs:139` `Process.sleep(1100)` — *confirmed, P2*.
- 2 audit tests use `Process.sleep(2/10)` for insert ordering — *confirmed, P3*.
- `upgrade_test.exs:320` random port `4444 + :rand.uniform(1000)` — *confirmed, nightly-only, P3*.
- `waitForLiveViewReady` copy-pasted into 14 specs with drift (only the design copy has the 197 fonts guard) — *confirmed, DX/maintainability, P2*.

**Topology / required-checks**
- No `concurrency:` block — *confirmed*.
- `ci-gate` not the required check; dep-off + golden + `fast_checks` advisory-only on PRs; `example_unit_smoke` required but absent from `ci-gate.needs` — *confirmed trust gap*.

**Matrix / version policy**
- No Elixir/OTP version matrix; `~> 1.18` floor untested (and `mix.exs:27/32` use Mix-1.19-only `test_load_filters`/`test_ignore_filters`) — *confirmed; nightly leg, zero PR cost*.

**Test-suite quality**
- `credo`/`dialyxir` declared + `.credo.exs` (with 2 custom security checks) but **never run** — *confirmed; large backlog → tier credo nightly, format needs one-time tree format*.
- Stale `:postgres`-excluded doc claim in `mix.exs:132`/`query_index_test.exs` — *confirmed doc/correctness drift, P3, flag-for-owner*.

**Security / release**
- `release-please-action@v5` is the ONLY unpinned action (mutable tag, secrets-bearing release job) — *confirmed; proposed SHA in the source finding is WRONG (annotated-tag object sha); use the dereferenced commit `45996ed1f6d02564a971a2fa1b5860e934307cf7`*.
- Dependabot covers only github-actions, not mix/npm — *confirmed, P2*.
- No `mix_audit`/`hex.audit` for an auth library — *confirmed, nightly, P2*.
- `admin_design_recapture` auto-PR carries `[skip ci]` → required checks never post under strict ruleset → PR stuck pending — *confirmed, P2*.
- Publish-workflow cache keys omit OTP/Elixir/MIX_ENV dims — *confirmed, P3*.
- `sha_pinning_required: false` repo policy — *confirmed, P3 backstop*.

**DX**
- No `mix ci` alias / no local Playwright repro doc / CONTRIBUTING describes pre-v1.40 topology — *confirmed, P1–P2*.

---

## 4. Prioritized Recommendations

> Scores are 1–5. Priorities reflect the **corrected** impact from the verification verdicts (overstated items softened, refuted sub-claims dropped). Items not on the PR critical path are explicitly labeled runner-minutes/trust/DX, not PR-latency.

### P0 — Playwright critical path (the campaign)

#### P0-1 — Remove per-test re-registration in `admin-design.spec.ts` (`design-gallery-per-test-reregistration`) — *verdict: confirmed*
- **Current issue:** `admin-design.spec.ts:221-226` runs a full `registerUser()` (goto /users/register → 2 fills → submit → waitForURL → alert) plus goto /admin/_design before **every** test. 24 board tests + 10 literal `test()` blocks = 34/project × 3 projects (chromium/mobile/dark, `workers:1`) = **~102 serial registrations**, each a multi-step LiveView dance over dev-mode **longpoll** (config comment lines 52-58) plus a server-side Argon2id hash. This is the single biggest cost in all of CI.
- **Proposed change:** A Playwright **setup project** that registers **one admin identity per design project** and writes `storageState`; each design project sets `use.storageState` to its own file; `beforeEach` reduced to `goto('/admin/_design'); await waitForLiveViewReady(page)`. The spec author's static-assigns note (lines 217-220) already establishes a shared admin identity is safe (boards render literal assigns; the only session-mutating test, MG-5/6, is `test.skip`'d).
- **Why idiomatic:** `storageState` is Playwright's canonical cross-test auth-reuse mechanism; `admin-checkpoints` already batches and registers only ~6× total for comparable capture volume — that contrast *is* the proof.
- **Pros:** −6 to −7.5 min PR wall-clock, 100% on the sole critical path; zero coverage loss (same boards, axe, snapshots). **Cons:** must use a distinct admin identity per project satisfying `Example.SigraAdminPolicy`'s email prefix; setup project must be a declared dependency.
- **Corrected impact:** seam ~700s → **~250–300s** (floor ~290s: responsive-width getBoundingClientRect ×5×24 + 72 element-scoped axe scans aren't free, so the finding's optimistic ~150s low end is not reachable, but ~400–450s saved is). **Largest single available win.**
- **Risk:** Low. DB-backed session token must stay valid for the lane (it does — gallery is read-only, app/DB up for whole job). **Rollback:** revert to per-test registration.
- **Verify:** compare the "Run design gallery boards" step time before/after on a PR run; assert identical snapshot/axe pass count.
- **Scores:** runtime 5 · reliability 4 · quality 5 · complexity 2 · DX 4 · reversibility 5.

#### P0-2 — Move pixel-snapshot gallery to nightly; keep axe a11y + L1-state behavior on PR (`design-gallery-to-nightly` / `design-gallery-visual-lane-to-nightly`) — *verdict: overstated → corrected*
- **Current issue:** Even after P0-1, the gallery still carries 72 `toHaveScreenshot` baselines (24 boards × 3 projects) against a **dev-only** route (`router.ex:172`, `dev_routes`). Snapshots are environment-fragile (the SEED-006 macOS/ubuntu font saga) and — critically — **currently enforce nothing on PRs** (`continue-on-error:true` + omitted from aggregator). The pending todo plans to hard-re-gate them onto the PR path; **do not** — that would put a flaky 700s pixel lane on the critical path.
- **Proposed change:** Gate the **snapshot captures** on `if: github.event_name != 'pull_request'` (the pattern already used by `generated_admin_playwright_smoke` et al.) and **hard-gate them there** (resolving the bootstrap-ordering deadlock, since `admin_design_recapture` already lives post-merge). **Keep on PR:** the per-board axe WCAG 2.1/2.2 AA gate (`admin-design.spec.ts:55-69`) and the ~10 non-snapshot L1-state/focus/Escape/reduced-motion/inert behavior tests.
- **Why idiomatic:** SEED-005 addendum #3 verbatim. Visual baselines are a nightly/main concern; they only regress on intentional UI changes the author can recapture.
- **Corrected impact:** The snapshot half is **strictly not-worse to demote** (it gates nothing on PR today). Moving only snapshots reclaims **~−500s**; this is the trust-preserving variant. (Moving the *whole* spec would reclaim the full −700s but silently drop the axe + behavior signal — see risk.)
- **Risk / TRADEOFF (flagged per North Star):** The axe a11y gate runs on **library** admin components and is **not** covered by `admin_checkpoints` (which never loads /admin/_design). Naively gating all 3 design projects on `event_name` would move that a11y + component-state signal off PRs — a real, non-redundant signal loss. **Mitigation is mandatory:** split the spec (Playwright `grep`/tag, or move only `assertBoardScreenshot`/`toHaveScreenshot` to a nightly-gated project) so a11y + behavior stay on PR and only pixels demote. **Rollback:** one `if:` removal + recombine.
- **Verify:** confirm axe + L1 behavior tests still run on a PR event; confirm snapshots run + hard-fail on a push/nightly event.
- **Scores:** runtime 5 · reliability 4 · quality 4 · complexity 2 · DX 4 · reversibility 5.

### P1 — Topology, trust, and the structural Playwright lever

#### P1-1 — Add `concurrency:` to cancel superseded PR runs (`concurrency-cancel-*`, 4 merged duplicates) — *verdict: confirmed (magnitude softened)*
- **Current issue:** No `concurrency:` in `ci.yml` (the lone workflow without one; the 3 siblings have it). Superseded PR pushes run the full ~20-min pipeline to completion (verified: runs `27882635436` and `27882644882`, 24s apart on the same branch, **both** ran to completion).
- **Proposed change (top-level):**
  ```yaml
  concurrency:
    group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
    cancel-in-progress: ${{ github.event_name == 'pull_request' }}
  ```
- **Why idiomatic:** Universal BEAM-ecosystem pattern; matches `release-please.yml:25`. PR-number keying avoids cross-PR cancellation on reused branch names; the `== 'pull_request'` guard means push/main, tag, schedule, dispatch runs **never** cancel (release integrity preserved — the release gate reads CI by merge-commit SHA on the push event, never a PR run).
- **Corrected impact:** **Not** "several hours/PR." Cancellation only helps **overlapping** pushes (most reds in history were spaced wider than run duration). Realistic reclaim: **~40–50 runner-minutes per superseded fixup push**, ~5–6 such events in the last ~2 weeks. Zero wall-clock change for a clean single-push PR; primary value is faster requeue + reduced runner contention.
- **Risk:** Very low. No cache interaction (run-scheduling only). **Rollback:** delete 3 lines.
- **Scores:** runtime 2 · reliability 3 · quality 1 · complexity 1 · DX 4 · reversibility 5.

#### P1-2 — Make `ci-gate` the required check; fix the `example_unit_smoke` aggregation gap (`required-check-ruleset-gap` / `ci-gate-not-required-trust-gap`) — *verdict: confirmed*
- **Current issue:** Ruleset requires 5 named jobs; `ci-gate` is not required, so `library_tests_dep_off` (compile-without-`:threadline` invariant) and `install_golden_contract` (installer drift) — both running on PRs — **gate merge through nothing.** A PR can merge green with either red.
- **Proposed change:** Use **option (a)** (safe): **add `ci-gate` to the ruleset** (keep the 5 named jobs too), AND **add `example_unit_smoke` to `ci-gate.needs`** (it is required today but absent from the aggregator — `ci.yml:1345-1354`). Do **not** use option (b) (drop the 5 for ci-gate-only) until `example_unit_smoke` is in `ci-gate.needs`, or it silently un-protects that lane.
- **Why idiomatic:** The "one required aggregator" pattern the repo half-built; `ci-gate` already treats `skipped`→pass (`ci.yml:1383`) so nightly-skipped lanes won't block PRs.
- **Impact:** Trust win, zero runtime. Closes a real merge-gate hole.
- **Risk:** Medium-procedural (branch-protection edit, admin-only). Cutover: ensure `ci-gate` has reported on a PR before requiring it; verify it fails on a real failing lane and passes on legitimate skips. **Rollback:** restore the 5-job ruleset.
- **Scores:** runtime 1 · reliability 5 · quality 5 · complexity 2 · DX 3 · reversibility 4.

#### P1-3 — Add static-check tier (`format`/deps-lock now; credo/dialyzer tiered) (`missing-static-check-tier` / `credo-dialyzer-format-not-run`) — *verdict: confirmed (deployability corrected)*
- **Current issue:** No `mix format --check-formatted`, `mix credo --strict`, `mix deps.get --check-locked`, `mix deps.unlock --check-unused` anywhere. `.credo.exs` defines 2 custom **security** checks (`NoUnscopedOrgQueryInLib`, `NoLogSafe2InLib`) that therefore never run. Only signal is `compile --warnings-as-errors`.
- **Proposed change (phased — backlog is real):**
  1. **Now, zero backlog:** wire `deps.get --check-locked` + `deps.unlock --check-unused` into `fast_checks` (both exit-0 on `main`).
  2. **After a one-time tree format:** `mix format --check-formatted` (today ~37 real lib/test files fail on the CI-pinned Elixir 1.19.5 — must format first). **CRITICAL:** the `.formatter.exs` inputs include `test/fixtures/**`; `test/fixtures/install_golden/tree/**` is byte-compared by `golden_diff_test`. **Exclude that golden tree from format inputs** or `mix format` will break the golden contract.
  3. **Nightly, report-only first:** `mix credo --strict` (exit 31, ~3900 issues, `.credo.exs` also needs to stop scanning `test/example/deps|_build`). Fix backlog → promote.
  4. **Nightly:** `mix dialyzer` with split restore/save PLT cache keyed on OS+OTP+Elixir+mix.lock.
- **Why idiomatic:** Exactly the lint-on-latest / dialyzer-nightly split Oban/Ash/Phoenix use; CLAUDE.md already prescribes `mix credo --strict`.
- **Impact:** Near-zero PR wall-clock (folds into the 11s `fast_checks`, off critical path); recovers signal already paid for, incl. the multi-tenant org-scoping guard. Satisfies GATE-02 "equal-or-greater quality signal" honestly.
- **Risk:** Med one-time backlog. **Do not** add `format`/`credo` as required gates before the cleanup commits, or the next PR reds on pre-existing drift. **Rollback:** per-tool.
- **Scores:** runtime 1 · reliability 3 · quality 5 · complexity 2 · DX 4 · reversibility 5.

#### P1-4 — Matrix-shard the Playwright seams (per-shard DB + app) (`matrix-shard-the-five-seams` / `split-playwright-into-parallel-jobs`) — *verdict: overstated → sequence after P0*
- **Current issue:** After P0-1/P0-2, the residual enforced seams (admin_behavior 81 + checkpoints 125 + non_admin 186 + demo 22 = 414s + ~107s prelude ≈ 519s) still serialize on one boot only because they share DB state.
- **Proposed change:** Convert `example_playwright_smoke` to `strategy.matrix` over seams with `fail-fast: false`, each leg booting its own app on its own port + its own `services.postgres`; add a **name-preserving aggregator** `Example Playwright smoke (full lifecycle)` (mirror `library_tests` aggregator `ci.yml:282-306`) so the required-check string stays byte-identical.
- **Corrected impact:** In **isolation today** (gallery still 700s on PR) this barely helps — max-shard becomes the 805s gallery leg. **Only after P0-2** does it collapse the ~519s residual to ~max-shard **~311s (~5m11s)**, a ~40% / ~200s cut. The advertised "20m→4–5m" is **mostly the P0 wins**, not this. **Sequence strictly after P0.**
- **Cost:** +3 runner jobs + 2 PG services + ~3× prelude (~+210–428 runner-min). Per-shard DB isolation is correctness-**safe** (removes the shared-mutation hazard that forced `workers:1`).
- **Risk:** Med. Required-check name MUST be preserved (proven template exists). WebKit can't be dropped per-shard (iPhone-13 mobile/checkpoint projects). **Rollback:** collapse matrix to one job.
- **Scores:** runtime 4 · reliability 3 · quality 4 · complexity 4 · DX 3 · reversibility 3.

#### P1-5 — Extract phx.new/upgrade subprocess tests from `library_tests` shards (`extract-phx-new-integration-tests-from-unit-shards`) — *verdict: confirmed (impact is runner-minutes until Playwright fixed)*
- **Current issue:** `library_tests_shard` runs `mix test --partitions 2 --slowest 10` with NO `--exclude` (`ci.yml:255`), so it runs all phx.new-spawning integration tests. They ARE the shard wall-clock (shard 1 top-10 = 82.7%, shard 2 = 98.6%); genuine units are sub-second. golden_diff + idempotency *also* run in `install_golden_contract` (conditional duplication).
- **Proposed change:** Add a single unifying `:scaffold` moduletag to the 7 phx.new-spawning files (`generator_passkeys_opt_out`, `features/passkeys_js`, `golden_diff`, `idempotency`, `vault_promotion`, `upgrade`; NOT `template_render` which is tagged `:install` but is fast), `--exclude :scaffold` in the shard command, and run the heavy set in a dedicated **PR-triggered** job.
- **Corrected impact:** Shards ~7.5–8.5 min → fixed prelude (~60–110s) + serial unit residual (low tens of s under `--trace`). **But the shards are OFF the critical path** (they finish ~12 min before Playwright), so this is **runner-minutes + future-proofing**, NOT PR latency — until the Playwright pole is gone. Re-rank to P1 for runner-cost, P2 for PR-latency.
- **Risk — coverage routing (sharper than the finding stated):** `ci-gate` counts `skipped` as pass, and `upgrade_test` runs on PRs **only** via the shards (`upgrade_smoke` is nightly). The extracted job MUST be **unconditionally PR-triggered** (or folding into `install_golden_contract` is wrong — it detect-skips on non-installer PRs), or upgrade/golden coverage silently vanishes from the PR gate with ci-gate still green.
- **Scores:** runtime 5 · reliability 4 · quality 4 · complexity 3 · DX 3 · reversibility 5.

#### P1-6 — Pin `release-please-action` to an immutable SHA (`pin-release-please-action`) — *verdict: confirmed (SHA corrected)*
- **Current issue:** `release-please.yml:88` `googleapis/release-please-action@v5` is the ONLY unpinned action — a mutable annotated tag in the secrets-bearing release job (`contents/issues/pull-requests: write`, `RELEASE_PLEASE_TOKEN`).
- **Proposed change:** Pin to the **dereferenced commit** (the finding's SHA is the annotated-tag object sha and would 422/break the job):
  ```yaml
  uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5
  ```
  Verify the trailing `# v5` comment so Dependabot tracks bumps.
- **Impact:** Closes the lone mutable-tag supply-chain vector on the only secrets path. Zero perf (push/dispatch-only path). Bounded (upstream-compromise only, never fork/PR-exposed) → P2 defensible, but cheap so keep at P1.
- **Scores:** runtime 1 · reliability 2 · quality 2 · complexity 1 · DX 2 · reversibility 5.

#### P1-7 — Add minimum-supported Elixir/OTP nightly matrix leg (`min-supported-version-matrix-nightly`) — *verdict: confirmed*
- **Current issue:** `mix.exs:11` declares `~> 1.18` but CI tests only 1.19.5/OTP28 (`.tool-versions`). Real 1.19 coupling already exists: `mix.exs:27/32` use Mix-1.19-only `test_load_filters`/`test_ignore_filters`. The compatibility promise is untested.
- **Proposed change:** Nightly-only (`if: github.event_name != 'pull_request'`) matrix leg running `library_tests` on the **literal** min pair (`version-type: strict`, not `version-file`), keyed cache (already namespaced by otp+elixir). Determine the TRUE floor first (Phoenix 1.8 deps + built-in `JSON` mean min is Elixir 1.18.x with a specific OTP — don't blindly pin OTP 25).
- **Impact:** Zero PR cost; converts `~> 1.18` from aspirational to tested. **Risk:** may discover the lib doesn't build on 1.18 (the point) — must be nightly/optional so it never blocks PRs.
- **Scores:** runtime 1 · reliability 3 · quality 5 · complexity 2 · DX 2 · reversibility 5.

### P2 — Determinism, caching hygiene, DX, security

| ID | Title | Corrected note |
|----|-------|----------------|
| `add-mix-ci-local-mirror` / `mix-ci-*` | `mix ci` alias mirroring the gate | **Narrower than claimed:** CI runs no format/deps checks today, so it can't save those round-trips *yet*. Land **with** P1-3 so alias == CI. Example smoke lives in a separate Mix project → use a thin script or `cmd:`, not a one-line composite. |
| `library-cache-missing-build` | Split `-library-` cache: `-library-build-` (incl `_build`, saved by a compiling job) vs `-library-deps-` (deps only) | **OFF critical path** → ~126 runner-sec/run, not PR latency. Re-rank P1→P2. Note: checkout rewrites mtimes, so project `.ex` may still partially recompile; the deps bulk (the 63s) is saved. |
| `remove-networkidle-waits` | Delete 2 `waitForLoadState('networkidle')` in passkey specs | Confirmed; the following web-first assertion is the real gate. |
| `remove-token-test-1100ms-sleep` | Replace `Process.sleep(1100)` with `max_age:0` immediate-expiry assertion | Confirmed; on the shard serial tail. |
| `extract-shared-waitforliveviewready-helper` | One `tests/helpers/live-view.ts` (+ `uniqueId(testInfo)`) replacing 14 drifted copies | Confirmed; the home for the parallel-safe uniqueId. |
| `playwright-datenow-collision-blocks-parallelism` | Swap bare `Date.now()` for `crypto.randomUUID()`/`workerIndex` token | **Softened to P2 enabler:** only blocks the intra-config multi-worker strategy; per-shard-DB sharding (P1-4) makes cross-shard collisions impossible. The design-spec pattern is NOT a clean worker-safe template. Verify with a temporary `workers:2` run. |
| `playwright-browsers-uncached` / `cache-playwright-browsers` / `split-browser-install-by-engine` | Cache `~/.cache/ms-playwright` keyed on Playwright version; per-engine install on sharded legs | **P1→P3:** cacheable slice is ~14s (not 48s — the ~33s apt `--with-deps` isn't cacheable); net ~5–12s, ~3% of the critical job. Minor enabler for P1-4. |
| `dep-off-double-cold-compile` | Stop the dev-env `mix docs` second cold compile | **Primary fix REFUTED** (ex_doc is `only: :dev` → `mix docs` fails in test env). Use **option (b):** add `_build/dev` to the dep-off cache path. OFF critical path → push/nightly runner-min only. |
| `dependabot-mix-npm-ecosystems` | Add `mix` (`/`) + `npm` (`/test/example/priv/playwright`) Dependabot, weekly+grouped | Confirmed; security coverage for an auth lib. |
| `mix-audit-dep-vuln-nightly` | `{:mix_audit, ...}` + nightly `mix deps.audit` + `mix hex.audit` | Confirmed; nightly (advisory-DB network flake). |
| `recapture-pr-skip-ci-pending-trap` | Drop `[skip ci]` from the recapture commit | Confirmed; the recapture job's own `if: != pull_request` already prevents re-fire, so `[skip ci]` only deadlocks the PR under the strict ruleset. |
| `contributing-stale-pipeline` / `playwright-local-repro-doc` | Update CONTRIBUTING to the post-v1.40 topology + document local Playwright repro | Confirmed; pairs with `mix ci`. |
| `complete-d10-design-gallery-re-gate` / `design-gallery-not-actually-gating` | Resolve the D-10 re-gate **on the nightly lane** (per P0-2), not on PR | Confirmed; re-gating onto PR would add +700s. Couple to P0-2. |

### P3 — Low-impact / classification

| ID | Note |
|----|------|
| `rebalance-shards-by-cost-not-file-count` | **Overstated → P3.** ~50s inter-shard gap is real but OFF critical path → zero PR-latency. Subsumed by P1-5 extraction. |
| `drop-slowest-after-fixing-async-env-hazards` | **Confirmed but P3 ordering:** standalone saves ~2–3s (async residual already ~5.7s). Only pays off AFTER P1-5 extraction, and ONLY after converting `audit_security_test`/`hammer_test` to `async:false` (hard prerequisite — `lib/sigra/audit.ex:485` is read by 6+ concurrent async modules). |
| `convert-private-ddl-postgres-tests-to-async` | Secondary tidy-up after `--slowest` drop; low absolute impact. |
| `library-repo-pool-size-hardcoded-4` | `pool_size: System.schedulers_online() * 2` — latent ceiling for the drop-`--slowest` work; no PR change today. |
| `non-admin-smoke-*` | Downstream of P1-4; do NOT parallelize before per-shard DB isolation (would reintroduce the v1.39 flake). |
| `design-mobile-move-to-nightly` | **TRADEOFF:** move WebKit mobile design/checkpoint legs to nightly, keep chromium+dark on PR. Flagged speed-for-coverage; do alongside P0-2. |
| `upgrade-smoke-random-port` | `:gen_tcp.listen(0)` free-port; nightly-only. |
| `fix-clock-ordering-sleeps` | Explicit `occurred_at` timestamps instead of `Process.sleep(2/10)`. |
| `postgres-tag-exclude-doc-drift` | **Flag-for-owner:** `mix.exs:132`/`query_index_test.exs` claim `:postgres` is excluded but `test_helper.exs` has no exclude. Decide intent; don't silently "fix" (test may be load-bearing). |
| `publish-cache-key-imprecise` | Add `id: setup` + ci.yml key shape to both publish workflows. |
| `enforce-sha-pinning-repo-policy` | Enable `sha_pinning_required: true` AFTER P1-6. |
| `dep-off-cache-cold-on-pr` | Self-heals after one merge with the new key format; observational. |
| `dep-off-docs-keep-off-pr-or-nightly` | **Category B (keep, already optimized).** No action; documented so a future pass doesn't "optimize" it. |

---

## 5. Proposed Target Pipeline

**PR (fast, representative):**
- `fast_checks` (folded guards + `deps.get --check-locked` + `deps.unlock --check-unused` + `format --check-formatted` post-cleanup) — ~12s.
- `library_tests` (2-way shard, **fast units only** after P1-5 extraction) — ~2–3 min.
- `library_tests_scaffold` (extracted phx.new/upgrade/golden set, PR-triggered, one parallel lane).
- `library_tests_dep_off` (+ `_build/dev` cache).
- `example_unit_smoke` / `install_smoke` / `example_http_smoke`.
- `example_playwright_smoke` → **matrix-sharded** (admin / non_admin / demo) behind the name-preserving aggregator; **gallery snapshots NOT here**; axe a11y + L1 behavior kept on the admin leg. Target ~5–6 min.
- `ci-gate` = **the single enforced aggregator** (needs all PR lanes incl. `example_unit_smoke`).
- `concurrency:` cancels superseded PR runs.

**main (push):** same as PR + the gallery pixel snapshots (hard-gated) + `admin_design_recapture` (no `[skip ci]`).

**nightly (schedule):** min-supported Elixir/OTP matrix leg · gallery snapshots · WebKit mobile design/checkpoint legs · `upgrade_smoke` · `generated_admin_playwright_smoke` · `install_matrix` · `mix dialyzer` (PLT split cache) · `mix credo --strict` · `mix deps.audit`/`hex.audit`.

**release/tag:** `release-please.yml` + `hex-publish.yml`, all actions SHA-pinned, precise cache keys, gate-by-merge-SHA preserved.

---

## 6. Stepwise PR Sequence (mapped to GSD phases, next = 198+)

- **Phase 198 — Quick wins + DX bundle (headline + zero-risk):** P0-1 (storageState, the −6 to −7.5 min win) · P1-1 (concurrency) · P1-3 step 1 (deps-lock checks) + `mix ci` alias (P2 mix-ci, scoped) · CONTRIBUTING refresh · P1-6 (release-please SHA). *Banks the biggest single wall-clock win before any topology change.*
- **Phase 199 — Gallery placement + a11y preservation:** P0-2 (snapshots→nightly, hard-gated there; axe + L1 behavior stay on PR) · couple D-10 re-gate · `design-mobile-move-to-nightly` · `recapture` `[skip ci]` drop.
- **Phase 200 — Playwright per-shard-DB parallelization (the SEED-005 #1 lever):** P1-4 (matrix-shard + name-preserving aggregator + per-shard PG/app) · prerequisite `playwright-datenow` uniqueId + shared `waitForLiveViewReady` helper · browser-binary cache + per-engine install · `remove-networkidle`. *Headline structural phase; sequenced after the gallery is off the PR path so sharding actually pays.*
- **Phase 201 — Required-gate trust + library-shard cost:** P1-2 (ci-gate required + example_unit_smoke aggregation) · P1-5 (extract `:scaffold` tests, PR-triggered) · library cache split (`-library-build-`/`-library-deps-`) · dep-off `_build/dev` cache · `token_test` sleep removal.
- **Phase 202 — Static-analysis + compat + security nightly:** P1-3 steps 3–4 (credo report-only→promote, dialyzer PLT) · P1-7 (min-version matrix) · `mix_audit` · Dependabot mix/npm · publish-workflow cache keys · `sha_pinning_required` · `format` tree-cleanup + gate (with golden-tree exclusion).
- **Phase 203 — Determinism tail + classification:** `--slowest` drop (after async-env fixes) + pool_size · clock-ordering sleeps · upgrade-smoke free-port · postgres-tag doc drift (flag owner).

---

## 7. Test-Value Cleanup Plan (A–E)

- **A — Must remain in PR gate:** library unit suite (post-extraction), `example_unit_smoke`, install/http smoke, admin_behavior/checkpoints/non_admin/demo behavior seams, **the gallery axe WCAG gate + L1-state behavior tests**, dep-off compile-without-`:threadline` proof, golden contract.
- **B — Keep in PR, optimize:** `admin-design.spec.ts` (P0-1 storageState) · Playwright seams (P1-4 shard) · library shards (P1-5 extract; library cache split). `library_tests_dep_off` is already optimally placed (Category B, no action).
- **C — Move to nightly/main:** gallery **pixel snapshots** (hard-gated post-merge) · WebKit mobile design/checkpoint legs · min-supported version matrix · credo/dialyzer · mix_audit · install_matrix/upgrade/generated-admin (already done by 193–196). *Never move a correctness-critical test nightly-only — the a11y/behavior signal explicitly stays on PR.*
- **D — Quarantine/fix before trusting:** bare `Date.now()` uniqueness (before any multi-worker) · 2 `networkidle` waits · clock-ordering `Process.sleep` audit tests · upgrade-smoke random port.
- **E — Delete/rewrite:** none recommended. `token_test`'s 1.1s sleep is rewritten (not deleted) to an immediate `max_age:0` assertion. No low-signal test meets the evidence bar for deletion.

---

## 8. Exact local `mix ci` to add

Land **with** P1-3 so the alias and CI run identical commands (the only thing keeping them honest). Fast library gate as a composite alias; browser/scaffold seams as separate documented commands.

```elixir
# mix.exs aliases — keep in lockstep with .github/workflows/ci.yml fast lanes
ci: [
  "deps.unlock --check-unused",
  "deps.get --check-locked",
  "format --check-formatted",
  "compile --warnings-as-errors",
  "test"
],
# heavier lanes that need a booted app / phx.new are NOT in `mix ci`:
#   mix test --only scaffold        # phx.new/upgrade/golden integration set
#   scripts/ci/playwright-local.sh  # boot test/example + npx playwright test (documented in CONTRIBUTING)
```

Prereq (CONTRIBUTING): `scripts/db/up.sh && source tmp/db.env` (or rely on the localhost:5432 fallback). Have a CI lane invoke `mix ci` directly where practical so the two cannot drift.

---

## 9. Validation Plan (before/after)

| Metric | Baseline (run 27883386841) | Target after Phases 198–200 |
|--------|----------------------------|------------------------------|
| PR wall-clock (critical path) | **1236s (~20.6 min)** | **~520–550s (~8.6–9.5 min)** — library shard pole, post-Playwright-collapse |
| `example_playwright_smoke` job | 1226s | ~310–360s (sharded, gallery off PR) |
| └ design gallery seam | 700s | ~250–300s (P0-1), then off PR (P0-2) |
| `library_tests` shard (longest) | 518s | ~2–3 min (post-extraction; runner-min win) |
| Superseded-run runner-min | full ~49 min/superseded push | ~0 (cancelled) |
| PR-enforced quality signal | 5 named checks; dep-off/golden advisory; no format/credo | ci-gate enforces all PR lanes + format/deps-lock; a11y preserved on PR |
| Cache honesty | `-library-` 4.7 MB (no `_build`) | split build/deps caches; warm `_build` restore |

**How to capture:** `gh run view <id> --json jobs` for per-step timing before/after each phase; `gh api repos/szTheory/sigra/actions/caches` for cache sizes; a temporary `workers:2` Playwright run to validate parallel-safety before P1-4; confirm required-check posting on a throwaway PR before the ruleset cutover (P1-2).

---

## Open Questions / Assumptions
- **`postgres`-tag doc drift** (P3): cannot pick intent read-only — flag for owner whether the EXPLAIN test should be PR-gated (delete stale comments) or opt-in (add the exclude).
- **`mix ci` ↔ CI lockstep:** assumes a CI lane will invoke the alias; otherwise drift risk per the verdict.
- **Min-version floor:** assumes the true floor is Elixir 1.18.x + a specific OTP (Phoenix 1.8 + built-in `JSON`); confirm before pinning to avoid a false-failing gate.
