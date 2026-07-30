# Phase 232: Playwright Economics — Authenticate Once, Then Shard — Research

**Researched:** 2026-07-30
**Domain:** GitHub Actions workflow economics · Playwright test-runner topology (setup projects, storageState, sharding) · CI honesty-guard surface
**Confidence:** HIGH (every anchor in this document was re-derived by grep against the working tree at `a1076264`; the three Playwright behavioral claims were re-verified by live experiment against the pinned 1.59.1 install)

**Repo state at research time:** worktree `/Users/jon/projects/sigra/.claude/worktrees/discuss-231`, branch `worktree-discuss-231`, HEAD `a1076264`, clean.

---

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

Copied verbatim from `232-CONTEXT.md` `<decisions>`. **Do not re-derive, do not contradict.** Where this research found a locked decision's *citation* to be wrong (never its substance), the correction is recorded separately in § Corrections to CONTEXT.md — the decision itself stands.

#### PW-01 — authenticate once

- **D-01:** Use a Playwright **setup project** (`dependencies:` + `use.storageState`), not `globalSetup`. Empirically verified against the pinned Playwright **1.59.1** in a throwaway config: `--project=X` auto-pulls X's dependencies, and positional file args, `--grep`, `--grep-invert`, and `--shard` apply **only to primary tests, never to dependency-project tests**. Both real CI invocations (`--grep-invert '@snapshot'` at `ci.yml:1497-1503` and `--grep '@snapshot'` at `:1525-1530`) ran the setup unfiltered. No tagging workaround is needed and those two CI steps require no change.
- **D-02:** The setup logs in as the **already-seeded** `admin@demo.tasklane.test` persona (`test/example/lib/example/demo/personas.ex:58-71`, password `DemoAdmin1!SecurePass`), which `test/example/lib/example/sigra_admin_policy.ex:19-24` grants `platform_admin?` by email match. Seeds already run in every app-booting job (`ci.yml:1314-1322`, `:2048-2055`, `:2356`, `:2608-2615`; `playwright-github-pages.yml:96-103`). Reuse the existing plain controller POST to `/users/log_in` in `test/example/priv/playwright/helpers/adminFlows.ts:65-91` (`loginDemoAdmin`) — its `:57-63` comment records that no MFA challenge fires despite `totp: true`.
- **D-03:** **One shared** storageState file for all three design projects, written to `test/example/priv/playwright/.playwright/design-admin.json` (`.playwright/` is already gitignored). storageState is engine- and emulation-agnostic — verified in `node_modules/playwright-core/types/types.d.ts` (~L9417): no engine or UA field; Playwright docs state cookies/localStorage/IndexedDB/WebAuthn credentials work across browsers. Sigra records `user_agent` at `lib/sigra/session_stores/ecto.ex:123` but **never rejects on mismatch**, so a Chromium-captured session is valid in the WebKit `mobile` project.
- **D-04:** Keep the base URL byte-identical between setup and specs. storageState cookie origin matching is exact — `localhost:4000` and `127.0.0.1:4000` are different origins and the session silently will not apply. Do not vary `SIGRA_EXAMPLE_URL` between the setup project and the design projects.
- **D-05:** The setup must end with an **explicit authenticated assertion** before writing state. storageState auth failure is silent — an unauthenticated run just redirects to the login page with no exception, and every downstream test then fails confusingly.
- **D-06 (hard-fail):** The new setup file must be added to the `testIgnore` arrays of exactly **two** projects — `chromium` (`playwright.config.ts:94`) and `mobile` (`:103-112`) — or it will be picked up as a normal spec by lanes that must not run it.
- **D-07:** Name the setup file **non-`.spec.ts`** (e.g. `auth.setup.ts`) and record its lane binding in this phase, so Phase 234's DX-04 spec inventory (`ROADMAP.md:212`) does not flag it as an unnamed lane.
- **D-08 (hard-fail):** SC-1 says "once **per project**"; the chosen shape authenticates **once total** (one setup project feeding all three). Record an SC restatement in the ROADMAP in the same style as Phase 230's SC-2 (`ROADMAP.md:96-99`), or `scripts/ci/prohibitions/p11-sc-restatement-recorded.test.mjs` reds.
- **D-09:** Do **not** anchor on the ROADMAP's line citation. `ROADMAP.md:180` cites `admin-design.spec.ts:250-255` for the `beforeEach`; it is now at **`:273-278`** (the `registerUser()` call is `:275`).
- **D-10 (hard-fail):** Three ExUnit contracts and one prohibition pin `admin-design.spec.ts` text and must stay green: `test/sigra/planning/phase_230_design_gallery_split_test.exs:65-76` (literal `test.describe('Design gallery board snapshots', () => {`), `:78-95` (`assertBoardScreenshot` must not call the axe helper), `:97-110` (untagged axe test exists), `:111-147` (13+11+4 = 28 boards); plus `p02-axe-signal-not-reduced.test.mjs`.

#### PW-01 — measurement

- **D-11:** Phase 230's D-21 instrument does **not** satisfy SC-1. `scripts/ci/ci-run-metrics.sh:94-124` emits only `{name, conclusion, duration}` per **job** — the jq at `:103-106` never descends into `.steps[]`. SC-1 needs a **step**-level reader. Commit one before measuring (D-21 discipline), modelled on the existing step-level resolution in `scripts/ci/ci-demotion-observer.sh:150,161-165`, which is purpose-bound to the demotion observer and should not be repurposed in place.
- **D-12:** Baselines are already on record and must be cited, not re-derived: PR gallery step `39 passed (3.9m)` (`230-EVIDENCE.md:189-192`, run `30412458437`, job `90451525539`); non-PR snapshot `84 passed (7.2m)` (`:423-426`, job `90459154527`); ungrepped recapture `123 passed (12.1m)` (`:427-430`). `p01-committed-method-provenance.test.mjs` and `p12-run-id-provenance.test.mjs` guard this.
- **D-13:** Set the honest expectation up front: PW-01's **PR-side** saving is **~175s** (39 tests × ~4.5s), *not* SEED-005's −6/−7.5m — because Phase 230 already moved 84 of 123 design tests off the PR path. Non-PR lanes gain more (~378s off `design_gallery_snapshots`, ~553s off `admin_design_recapture`). PW-01 alone lands the critical path near **13.6m**, still above the 12m FAST-01 target.
- **D-14 (hard-fail):** `p03-no-green-on-empty-grep.test.mjs` — the AFTER evidence must record **executed test counts**, not just durations.

#### PW-02 — parallelism

- **D-15:** Shape is **matrix-shard with a per-shard runner** — each shard gets its own `services.postgres` and its own `mix phx.server` — **not** `workers > 1` against one shared boot. `playwright.config.ts:11-13` states verbatim that DB state is shared across specs; settings at `:53-54`.
- **D-16:** Every shard's app binds **port 4000**. `ci.yml:2553-2557` documents that `config.exs:39` bakes `System.get_env("PORT","4000")` as a `compile_env` key, so a non-4000 port trips `validate_compile_env`. DB isolation needs **no code change** — `config/dev.exs:4-12` already reads `PGDATABASE`/`PGHOST`/`PGPORT` from env.
- **D-17:** SC-2 must be proven with `--retries=0` **passed on the CLI**, because `playwright.config.ts:55` sets `retries: process.env.CI ? 1 : 0`.
- **D-18:** The five documented collision sources must each be addressed or explicitly shown moot by per-shard DB: (1) one app / one dev DB (`ci.yml:1376-1388`); (2) shared seeded rows mutated by siblings — `admin-flow-platform-admin.spec.ts:269-320` revokes alice's sessions, `admin-flow-support-investigator.spec.ts:70` impersonates, `admin-coherence-sweep.spec.ts:87-109` asserts on `grace@`/`pat@`; (3) index ordering — `admin-design.spec.ts:448-450` documents `/admin/users` ordering `inserted_at DESC`; (4) 23 bare `Date.now()` across 15 spec files plus the module-level `registrationSequence` at `admin-design.spec.ts:52` which is per-worker-process; (5) `test-results/` wiped per invocation (`ci.yml:1458-1463`, already realized).
- **D-19 (hard-fail):** Add a **shard-emptiness assertion**. Verified hazard: Playwright shards by *file*, so with fewer files than shards a shard runs **zero tests, skips setup, and exits 0 silently** — a green that proves nothing.
- **D-20 (hard-fail):** The seam-outcome aggregator loop at `ci.yml:1584-1589` hard-codes six step ids. PW-02 must carry that contract forward, or a failing seam reports green — the v1.42 failure mode, called out at `ci.yml:1569-1573`.

#### PW-02 — required-check name stability (SC-3)

- **D-21:** Reuse the shipped aggregator template verbatim: rename the working job to `example_playwright_shard` with `name: Example Playwright smoke shard ${{ matrix.seam }}`, plus a thin job that keeps the id `example_playwright_smoke` and a **byte-identical** `name: Example Playwright smoke (full lifecycle)`. This mirrors `library_tests_shard` → `library_tests` at `ci.yml:497-622`; `ci.yml:594-599` documents the failure mode. Interpolating the matrix value into `name:` is what prevents Actions appending ` (value)` to a static matrix job name.
- **D-22 (hard-fail):** The aggregator **must** use `if: always()`. A job whose `needs` dependency failed is *skipped*, and a skipped required check reports success — without `always()` a failing shard silently lets the PR merge. `ci.yml:594-622` already uses `if: always()` + `[[ "$SHARDS" != "success" ]] && exit 1`; copy that, do not re-derive it.
- **D-23 (hard-fail):** Never add the shard job to `ci-gate.needs`. `scripts/ci/honest-skip-verdict.sh:145-156` holds a fixed nine-lane list cross-checked bidirectionally against `ci-gate.needs` (`ci.yml:1849-1859`), and its extractor requires bare `      - id` lines with no trailing comments (`ci.yml:1846-1848`).
- **D-24 (hard-fail):** Four consumers key on the exact name/id and must stay consistent in **one commit**: `honest-skip-verdict.sh:145-156`; `ci-demotion-observer.sh:150` (resolves `design_gallery_snapshots` by parent job *display name*); `.github/ci-skip-manifest.tsv:70,:75` (pins parent_job_id/display_name, asserted by `p10-no-undocumented-demotion.test.mjs`); and the hard-coded five names in `scripts/ci/docs-only-receipt.sh:42-48` + `scripts/ci/prohibitions/_lib.mjs:196-203`. `MAINTAINING.md:102-113`: "Do not rename or remove the five job `name:` strings above."

#### PW-03 — single boot prelude

- **D-25:** Mechanism is a **local composite action** at `.github/actions/boot-example-app/action.yml` with inputs (`seeds`, `browsers`, `port`, `warm-paths`). A `scripts/ci/*.sh` cannot express it — the duplicated block contains four `uses:` steps (`actions/checkout`, `erlef/setup-beam`, `actions/setup-node`, `actions/cache`). No `.github/actions/` directory exists yet.
- **D-26:** Seven call sites (not six): `example_unit_smoke` `ci.yml:742-775` (MIX_ENV=test, no boot, no node); `example_http_smoke` `:1180-1231` (boot, no seeds, no node/browsers); `example_playwright_smoke` `:1270-1408` (full + browser cache); `admin_design_recapture` `:2010-2089` (full, plain `install --with-deps`); `admin_checkpoint_recapture` `:2329-2379+` (full); `admin_eval_render` `:2570-2644` (full, **`PORT: 4011`**, warms only `/admin/_design`); `playwright-github-pages.yml:54-131` (full, p15-guarded). The comment at `ci.yml:2008-2009` calling itself a "verbatim clone of ci.yml:886–968" is **already stale** — the source is now at `:1270-1408`.
- **D-27 (hard-fail):** The composite **must not** unconditionally include an `actions/cache` step. `ci.yml:1333-1355` documents that `admin_eval_render` declares no cache step *as a deliberate structural guarantee*; folding caching into a shared composite "would destroy that guarantee and re-open the Phase 231 GATE-04 bug." Gate caching behind an input, or keep the composite install-only.
- **D-28:** Composite mechanics, verified: `uses:` steps are supported; `if:` on steps is supported; `shell:` is **required** on every run step; inputs are **all strings** (booleans arrive as `'true'`/`'false'`); `$GITHUB_ENV` **leaks outward** to the caller's later steps; `continue-on-error` on composite steps is **not supported**; there is no `secrets:` block; `${{ github.action_path }}` works.
- **D-29:** `actions/cache` post-save works correctly **one level deep only** (actions/runner#2030 — post steps in *nested* composites get the wrong context). Never nest a cache-bearing composite. Composite step ids are action-scoped: the caller **cannot** read `steps.<internal-id>.outputs.cache-hit`; the action must re-export via `outputs.<id>.value`. On a total miss `cache-hit` is the **empty string, not `'false'`** — always compare `!= 'true'` (Sigra already does).
- **D-30 (hard-fail):** Three guards parse the affected YAML literally and will red on a careless refactor: `p15-pages-publisher-seeds-before-boot.test.mjs` parses the literal step list of `playwright-github-pages.yml` (`stepList()` matches `^ {6}- name:`); `scripts/ci/playwright-cache-key-guard.sh:59-62` greps `ci.yml` for `playwright-chromium-webkit-<x.y.z>-vN` and fails closed; `p09-timeouts-not-truncating.test.mjs` requires one `timeout-minutes` per `runs-on:` job; `p10`'s step-id resolution matches `^\s+id: <id>` in `ci.yml`.

#### Ordering

- **D-31 (hard-fail):** Execution order is **PW-01 land → PW-01 measured on a real PR run → PW-03 → PW-02 → PW-02 measured**. PW-03 precedes PW-02 because PW-02 adds N new prelude call sites; factoring after sharding means factoring N copies instead of one.
- **D-32 (hard-fail):** Any same-commit change touching the demotion surface must edit `.github/ci-skip-manifest.tsv`, `MAINTAINING.md:137`, and `MAINTAINING.md:274` together (or `honest-skip-parity.test.mjs` / `p10` red).
- **D-33:** Verification philosophy from STATE.md binds this phase: success criteria are proven by running CI and reading measured numbers, never by reading YAML. A `skipped` job proves nothing.

### Claude's Discretion

CONTEXT.md declares no explicit `## Claude's Discretion` section. The discretion surface is what the 33 decisions leave open:

- The **shard axis** for PW-02 (by seam vs. by `--shard=i/N`) and the **shard count** — D-15 fixes the *isolation shape* (per-shard Postgres + per-shard app), not the partition key. See § Sharding Mechanics: this choice cannot be made honestly until the D-11 step-level reader produces per-seam BEFORE durations.
- The **exact composite input surface** — D-25 names four inputs illustratively; § Composite Action Shape derives the real surface from the seven call sites.
- The **emptiness-assertion mechanism** for D-19 — § Code Examples gives the empirically-verified one.
- The **step-level reader's** name, CLI shape, and output format, subject to D-11's "modelled on `ci-demotion-observer.sh`" and D-14's executed-test-count requirement.

### Deferred Ideas (OUT OF SCOPE)

**Folded in:** `.planning/todos/pending/2026-06-20-playwright-parallelization-per-shard-db.md` — this is the direct PW-02 match and is in scope. (Verified present; frontmatter already carries `resolves_phase: 232`.)

**Reviewed, not folded** (Phase 230/231 subject matter already handled, or explicitly out of scope for 232):
`2026-06-20-runtime-auth-prefix-override.md`,
`2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md`,
`2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md`,
`2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`,
`2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`,
`2026-07-30-recapture-job-transient-hexpm-mirror-failure.md`,
`2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md`, and the
lower-scored functional/UI todos (`w1`–`w8` series,
`2026-07-30-admin-generated-audit-presets-actor-filter-race.md`,
`2026-07-10-canary-recapture-lane-excludes-canary.md`, etc.).

**Deferred out of this phase:**
- Spec-inventory / lane-naming enforcement — Phase 234 DX-04.
- Any `admin_eval_render` cost reduction — it is not on the PR critical path and its no-cache structure is a deliberate guarantee (D-27).
- Rewriting the 23 bare `Date.now()` uniqueness sites, if per-shard DB isolation makes them moot (D-18 item 4) — decide during PW-02, do not pre-commit.

</user_constraints>

---

<phase_requirements>

## Phase Requirements

| ID | Description (`REQUIREMENTS.md:41-43`) | Research Support |
|----|---------------------------------------|------------------|
| **PW-01** | The design-board specs authenticate once per project instead of registering a fresh user before every test. | § Verified Anchor Table (the exact `beforeEach`, the exact `registerUser` body, the 41-tests-per-project arithmetic); § Pattern 1 (setup project + storageState); § Measurement Instrument (SC-1's before/after reader); § Guard Surface rows for `p02` and `phase_230_design_gallery_split_test.exs` — the four assertions that pin this file's text. |
| **PW-02** | Playwright specs can run in parallel without cross-spec database interference, so `workers: 1` is no longer required for correctness. | § Sharding Mechanics (per-shard Postgres/app, port-4000 constraint, PGDATABASE isolation); § Empirical Findings E-1..E-4 (shard/setup/grep interaction, the silent-empty-shard hazard and its two distinct triggers); § Pattern 3 (shard → name-preserving aggregator, copied from `library_tests_shard`); § Guard Surface rows for `p09`, `p10`, `honest-skip-verdict.sh`, `ci-demotion-observer.sh`, and the three `phase_230_design_gallery_split_test.exs` job-scoped tests. |
| **PW-03** | The example-app boot prelude is defined once and reused, rather than duplicated verbatim across jobs. | § Call-Site Difference Matrix (the seven sites' real variance, derived from the file, not from the ROADMAP); § Pattern 2 (composite action, with the D-27 correction); § Guard Surface rows for `p15` and `playwright-cache-key-guard.sh` — the two guards that will hard-fail on a naive composite. |

</phase_requirements>

---

## Summary

Phase 232 is not a "make CI faster" phase. It is a **refactor of the most heavily-instrumented job in the repository**, where the instrumentation is itself the deliverable of the two preceding phases. `example_playwright_smoke` is simultaneously: a ruleset-14941512 required status context; the parent of the only tier-B *step* row in `.github/ci-skip-manifest.tsv`; the subject of three ExUnit job-scoped contracts; a pinned pole in `p09`; a hard-coded lane in `honest-skip-verdict.sh`; and one of five hard-coded names in `docs-only-receipt.sh` and `_lib.mjs`. Every one of those bindings is asserted mechanically, and most of them fail *closed* — so the dominant risk in this phase is not that the refactor breaks CI, but that it breaks a guard whose whole purpose is to make breakage loud, and that the fix for the guard silently weakens it.

The research therefore concentrated on three things the planner cannot get from CONTEXT.md. First, **verified anchors**: every line citation the plan will make, re-derived at HEAD (§ Verified Anchor Table). CONTEXT.md's D-09 warning is correct and understated — the file *paths* in its `<canonical_refs>` are also wrong (`specs/` vs. the real `tests/`), and two of its own decisions cite line numbers that do not resolve. Second, the **guard surface as a table**: for each of the eleven checks in scope, what it parses, what would break it, and how to run it locally (§ Guard and Prohibition Surface). Three of them — `p15`, `playwright-cache-key-guard.sh`, and `phase_230_design_gallery_split_test.exs` — will hard-fail on the *intended* refactor, not on a careless one, and each needs a deliberate, recorded remediation rather than an incidental edit. Third, **empirical verification of the sharding hazards** against the pinned 1.59.1 install, which found a hazard CONTEXT.md does not name: `--shard` suppresses Playwright's own `Error: No tests found` exit-1, so adding `--shard` to today's `--grep`/`--grep-invert` steps silently removes the only thing currently standing between a mistyped tag and a green-on-nothing run.

The economics are modest and already honestly priced by D-13. The measured PR critical path is 989s; PW-01 removes ~175s of it. Nothing in PW-01 or PW-03 gets to the 12m FAST-01 target — only PW-02's shard split can, and **the shard boundary cannot be chosen responsibly until the D-11 step-level reader has produced per-seam BEFORE durations**, because the residual seam mix (`admin_behavior`, `admin_checkpoints`, `design_gallery`, `non_admin_smoke`, `demo_showcase`) has never been measured at step granularity. That makes the reader a Wave-0 blocker for PW-02's *design*, not merely for PW-01's *proof* — a stronger claim than D-11 makes, and the single most consequential finding here.

**Primary recommendation:** Build the step-level reader first as a standalone, self-tested instrument wired into `fast_checks` alongside `ci-run-metrics.test.sh`; capture BEFORE step durations and executed test counts for all six seams on one real PR run; only then land PW-01, re-measure with the same instrument, and use the resulting per-seam numbers to pick the PW-02 shard boundary. Treat `p15`, `playwright-cache-key-guard.sh`, and the three job-scoped ExUnit contracts as *deliverables to be rewritten with recorded justification*, not as incidental collateral.

---

## Architectural Responsibility Map

This phase has no application tiers. The equivalent axis is **which artifact owns which guarantee** — the mapping the planner needs to avoid putting a guarantee in a layer that cannot hold it.

| Capability | Primary Owner | Secondary Owner | Rationale |
|------------|---------------|-----------------|-----------|
| Authenticated browser session for design specs | `playwright.config.ts` setup project + `auth.setup.ts` | `helpers/adminFlows.ts` (`loginDemoAdmin`) | The runner owns project topology and `storageState` lifecycle; the helper owns the login mechanics and already exists. Do not re-implement login in the setup file. |
| Which specs run on which lane | `.github/workflows/ci.yml` step invocations | `playwright.config.ts` `testMatch`/`testIgnore` | Lane routing is a CI concern (`--project`, `--grep`); project *partitioning* is a config concern. Phase 230 established this split; preserve it. |
| Test-data isolation between concurrent shards | GitHub Actions `services.postgres` (one per shard job) + `PGDATABASE`/`PGHOST` env | `test/example/config/dev.exs:4-12` | `dev.exs` already reads every PG connection field from env. **No Elixir change is needed** — isolation is purely a workflow-topology concern. |
| Required-check context stability | A thin aggregator job whose `name:` is a byte-literal | Branch ruleset 14941512 (external, read-only) | GitHub collects contexts from job `name:`. A matrix job cannot produce a bare context name; only a separate non-matrix job can. |
| "Did the work actually execute?" | `scripts/ci/ci-demotion-observer.sh` (runtime, `ci-observe.yml`) + the new step-level reader (evidence capture) | `scripts/ci/prohibitions/p03`, `p12`, `p13` (ledger-side) | Runtime observation and ledger provenance are two halves of the same claim; neither substitutes for the other. |
| Boot prelude definition | `.github/actions/boot-example-app/action.yml` (new) | Each calling job's `with:` block | The composite owns the *steps*; the caller owns the *variance* (env, port, browsers, cache tokens). Variance that cannot be expressed as an input must stay in the caller. |
| Browser-cache correctness | The **calling job**, not the composite | `scripts/ci/playwright-cache-key-guard.sh` | D-27: `admin_eval_render`'s absence of a browser cache is a structural guarantee. A composite that could ever restore browsers into that job destroys it. |

---

## Verified Anchor Table

Every anchor below was re-derived by grep at HEAD `a1076264`. **Cite these, not the ROADMAP's or CONTEXT.md's.**

### `test/example/priv/playwright/` — path correction first

> **`<canonical_refs>` in CONTEXT.md writes `test/example/priv/playwright/specs/…`. That directory does not exist.** The spec directory is `tests/` (`playwright.config.ts:52` → `testDir: './tests'`). Every `specs/…` path in CONTEXT.md must be read as `tests/…`. `[VERIFIED: ls test/example/priv/playwright/]`

| Symbol / construct | Verified location | Notes |
|---|---|---|
| `testDir: './tests'` | `playwright.config.ts:52` | |
| `fullyParallel: false` | `playwright.config.ts:53` | D-15 anchor ✔ |
| `workers: 1` | `playwright.config.ts:54` | D-15 anchor ✔ |
| `retries: process.env.CI ? 1 : 0` | `playwright.config.ts:55` | D-17 anchor ✔ |
| "DB state is shared across specs" comment | `playwright.config.ts:11-13` | D-15 anchor ✔ |
| `chromium` project `testIgnore` | `playwright.config.ts:94` | D-06 anchor ✔ (single-line array) |
| `mobile` project `testIgnore` | `playwright.config.ts:103-112` | D-06 anchor ✔ (multi-line array) |
| `use.baseURL` | `playwright.config.ts:76` | `process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000'` — D-04 anchor |
| `admin-design-chromium` / `-mobile` / `-dark` projects | `playwright.config.ts:176-183` / `:185-192` / `:195-203` | The three that need `dependencies:` + `storageState` |
| `ADMIN_DESIGN_SPEC` regex const | `playwright.config.ts:27` | |
| `.playwright/` gitignored | `test/example/priv/playwright/.gitignore:4` | D-03 anchor ✔ |
| `registerUser` helper | `tests/admin-design.spec.ts:40-50` | LiveView register flow; the thing PW-01 deletes from the hot path |
| `registrationSequence` module state | `tests/admin-design.spec.ts:52` | D-18 item 4 anchor ✔ |
| `adminDesignEmail` | `tests/admin-design.spec.ts:54-64` | Uses `Date.now()` at `:61` |
| `assertNoAxeViolations` | `tests/admin-design.spec.ts:74-91` | Tag set at `:86` — `p02` asserts all five tags |
| `assertBoardScreenshot` | `tests/admin-design.spec.ts:101-117` | Element-scoped locator at `:108` |
| `COMPONENT_BOARDS` (13) | `tests/admin-design.spec.ts:121-126` | ExUnit pins count |
| `test.describe('Design gallery board snapshots', () => {` | `tests/admin-design.spec.ts:266` | ExUnit pins this exact string |
| **`test.beforeEach`** | **`tests/admin-design.spec.ts:273-278`** | D-09 ✔ — `registerUser(...)` call at **`:275`**, `page.goto('/admin/_design')` at `:276`, `waitForLiveViewReady` at `:277` |
| Board loop + `@snapshot` tag | `tests/admin-design.spec.ts:286-290` | `test(\`board: ${boardId}\`, { tag: '@snapshot' }` at `:287` |
| Untagged axe test | `tests/admin-design.spec.ts:300-302` | Title pinned by `p02` **and** ExUnit |
| `/admin/users` `inserted_at DESC` comment | `tests/admin-design.spec.ts:448-450` | D-18 item 3 ✔ |
| File length | `tests/admin-design.spec.ts` = **768** lines | |
| `DEMO_ADMIN_EMAIL` / `DEMO_ADMIN_PASSWORD` | `helpers/adminFlows.ts:22` / `:25` | |
| `loginDemoUser` | `helpers/adminFlows.ts:65-81` | CONTEXT says `:65-91`; `loginDemoUser` ends at `:81` |
| `loginDemoAdmin` | `helpers/adminFlows.ts:87-89` | The function D-02 names |
| "No MFA challenge fires" comment | `helpers/adminFlows.ts:57-63` | D-02 ✔ |

**Test-count arithmetic (verified by enumerating `test(` declarations in `tests/admin-design.spec.ts`):**
28 board tests (tagged `@snapshot`) + 13 untagged tests (`:300, :304, :310, :349, :359, :405, :475, :523, :535, :580, :633, :677, :736`) = **41 per project × 3 design projects = 123 total**. This reconciles exactly with D-12's three recorded baselines: PR `39 passed` (13×3), non-PR `84 passed` (28×3), ungrepped recapture `123 passed`.

### `.github/workflows/ci.yml` (2697 lines)

| Construct | Verified location |
|---|---|
| `fast_checks` job | `:160` |
| → `Playwright cache key guard` step | `:328` (run at `:337`) |
| → `Playwright cache key guard self-test` | `:338` |
| → `Phase 230 prohibition guards` | `:370` (run at `:380`: `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs`) |
| `library_tests_shard` (aggregator template) | `:497-602`; `name:` `:498`, `fail-fast: false` `:503`, `matrix.partition` `:505` |
| `library_tests` (thin aggregator) | `:604-622`; `name: Library tests` `:605`, `needs:` `:608`, `if: always()` `:609`, exit-1 check `:615-622` |
| `example_unit_smoke` | `:718-791`; cache id `example_unit_deps_cache` `:750` |
| `example_http_smoke` | `:1159-1246`; cache id `http_smoke_deps_cache` `:1188`; boot `:1218` |
| **`example_playwright_smoke`** | **`:1248-1700`** |
| → `name:` (required context) | `:1249` |
| → `timeout-minutes: 45` | `:1251` (pinned by `p09`) |
| → `needs: [release_ref_guard, changes]` | `:1252` |
| → job `if:` | `:1259` |
| → `Cache example deps` (id `example_deps_cache`) | `:1283`, id `:1284` |
| → `Run demo seeds` | `:1314-1322` (D-02 ✔) |
| → `Cache Playwright browsers` (id `playwright_browsers_cache`) | `:1327`, id `:1328`, **key `:1359`**, restore-keys `:1360` |
| → `Boot example app in background` | `:1376` |
| → `Wait for app and warm up LiveView routes` | `:1389` |
| → seam `admin_behavior` | id `:1414` |
| → seam `admin_checkpoints` | id `:1440` |
| → `Stage admin checkpoint PNGs` | `:1464` (gated on `steps.admin_checkpoints.outcome == 'success'`) |
| → seam `design_gallery` | id `:1478` |
| → seam `design_gallery_snapshots` | id `:1505` |
| → seam `non_admin_smoke` | id `:1533` |
| → seam `demo_showcase` | id `:1553` |
| → `Aggregate Playwright step outcomes` | `:1563`; **the six-id loop at `:1584-1589`** (D-20 ✔) |
| → `Admin artifact bundle contract` | `:1653` — `MIN_COUNT` default **15** (`admin-artifact-bundle-contract.sh:8`) |
| `generated_admin_playwright_smoke` | `:1702-1835` |
| `ci-gate` | `:1836`; `needs:` list `:1849-1859` (nine lanes + `changes`); `if: always()` `:1860` |
| `admin_design_recapture` | `:1989`; stale "verbatim clone of ci.yml:886–968" comment `:2008-2009`; cache id `:2022`; seeds `:2048`; boot `:2062` |
| `admin_checkpoint_recapture` | `:2297`; cache id `:2330`; seeds `:2356`; boot `:2370` |
| `admin_eval_render` | `:2547`; `PORT: "4011"` `:2558-2559`; **cache id `admin_eval_render_deps_cache` `:2582`**; seeds `:2608`; boot `:2622`; wait `:2632` |
| `nightly_probe` | `:2687` |

### Other files

| Construct | Verified location |
|---|---|
| `library_tests_shard`→`library_tests` template comment ("A bare matrix on a named job emits …") | `ci.yml:594-599` (inside the comment block `:593-603`) |
| `honest-skip-verdict.sh` fixed nine-lane `LANES=(…)` | `scripts/ci/honest-skip-verdict.sh:101-111` (CONTEXT said `:145-156`; that range is the **bidirectional cross-check loop**, `:142-157`) |
| `ci-demotion-observer.sh` `parent_display_name()` | `scripts/ci/ci-demotion-observer.sh:189-199` |
| `ci-demotion-observer.sh` step resolution (`.jobs[] \| select(.name==$pj) \| .steps[]?`) | `scripts/ci/ci-demotion-observer.sh:151-153` |
| `ci-run-metrics.sh` `--jobs` single-run mode (job-level only) | `scripts/ci/ci-run-metrics.sh:93-125` — `DURATION_JQ` at `:100-104` never touches `.steps[]` (D-11 ✔) |
| `docs-only-receipt.sh` five hard-coded contexts | `scripts/ci/docs-only-receipt.sh:41-49` |
| `_lib.mjs` `REQUIRED_CONTEXTS` | `scripts/ci/prohibitions/_lib.mjs:193-200` |
| `playwright-cache-key-guard.sh` key extraction | `scripts/ci/playwright-cache-key-guard.sh:56-62` |
| `.github/ci-skip-manifest.tsv` — `design_gallery_snapshots` step row | data row 10 (tier B, parent `example_playwright_smoke`) |
| `.github/ci-skip-manifest.tsv` — `example_playwright_smoke` job row | data row 15 (tier C, `gate_level=step`) |
| `.github/actions/` | **does not exist** (D-25 ✔) |

---

## Corrections to CONTEXT.md

None of these change a decision's substance. All change a *citation* the planner would otherwise copy into a plan and have fail review.

| # | CONTEXT.md says | Reality at HEAD | Impact |
|---|---|---|---|
| C-1 | `<canonical_refs>` paths under `test/example/priv/playwright/specs/…` | The directory is `tests/`, not `specs/` (`playwright.config.ts:52`) | Every spec path in CONTEXT.md is wrong. Plans must use `tests/`. |
| C-2 | D-08: "Record an SC restatement in the ROADMAP in the same style as Phase 230's SC-2 (`ROADMAP.md:96-99`)" | The Phase 230 SC-2 restatement is at **`ROADMAP.md:76`**, and it *points at* `230-VALIDATION.md`. The machine-readable `## Restated Success Criterion (SC-2)` section — the one `p11` parses — lives in **`230-EVIDENCE.md:660`**, mirrored at `230-VALIDATION.md:169`. `ROADMAP.md:96-99` is a Wave-4/Wave-5 plan list. | The restatement must go in the phase's **EVIDENCE ledger** (heading grammar `^##\s+Restated Success Criterion\s*\(SC-\d+\)\s*$`), with a ROADMAP prose pointer as the human-facing half. A ROADMAP-only restatement satisfies no guard. |
| C-3 | D-08: "…or `p11-sc-restatement-recorded.test.mjs` reds" | `p11`'s `LEDGER` const is hard-coded to `.planning/phases/230-…/230-EVIDENCE.md` (`p11:29`). It will **never** read a 232 ledger and cannot red on a 232 omission. | The obligation is real but is enforced by a *new* Phase-232 prohibition guard, not by the existing `p11`. The planner must create it; nothing existing will catch the gap. Same applies to `p01`, `p03`, `p08`, `p12`, `p13` — all six ledger-side guards are 230-pinned. |
| C-4 | D-27: "`admin_eval_render` declares no cache step *as a deliberate structural guarantee*" | `admin_eval_render` **does** declare an `actions/cache` step — `Cache example deps (admin-eval-render lane)`, id `admin_eval_render_deps_cache`, `ci.yml:2581-2591`. What it declares **no** cache for is the **Playwright browser** cache (`~/.cache/ms-playwright`). The comment at `ci.yml:1333-1355` is specifically about the browser cache. | Materially widens the composite's freedom: the **example-deps cache may be unconditional** in the composite (all seven sites have one). Only the **browser cache** must be caller-owned / input-gated. Getting this wrong in the other direction (keeping deps-cache out of the composite) leaves the largest duplicated block unfactored and SC-4 unmet. |
| C-5 | D-26: `example_http_smoke` "boot, no seeds" | Confirmed — and it is the **only** app-booting construct in the repo with no seeds step. `p15`'s own comment claims "all four example-booting jobs in ci.yml (`:1288`, `:1950`, `:2258`, `:2506`) seed" — those are four *stale* line numbers and the set excludes `example_http_smoke`. | A composite whose `seeds` input defaults to `true` would silently *add* seeding to `example_http_smoke`, changing that lane's behavior. Default must be explicit at every call site, or default to `false`. |
| C-6 | D-24: `honest-skip-verdict.sh:145-156` "holds a fixed nine-lane list" | The list is at `:101-111`. `:142-157` is the bidirectional cross-check loop that consumes it. | Both are load-bearing; cite both. |
| C-7 | D-11: "modelled on the existing step-level resolution in `ci-demotion-observer.sh:150,161-165`" | The step resolution is at `:151-153`; the tri-state verdict block is `:155-183`. | Minor; cite `:151-153` + `:155-183`. |
| C-8 | D-30 lists three guards that "parse the affected YAML literally" | There are **five** in scope, and a sixth ExUnit family. See § Guard and Prohibition Surface — `phase_230_design_gallery_split_test.exs` (three job-scoped tests) and `phase_230_ci_timeouts_test.exs` are omitted from D-30 but will break on PW-02. | The `phase_230_design_gallery_split_test.exs` breakage is *certain*, not conditional. |
| C-9 | D-19: "with fewer files than shards a shard runs zero tests, skips setup, and exits 0 silently" | Confirmed empirically (E-2). **But there is a second, undocumented trigger**: `--shard` combined with a `--grep` that matches nothing also exits 0 silently (E-3), whereas the same `--grep` *without* `--shard` correctly errors `Error: No tests found` and exits 1. | Today's two design steps (`--grep-invert '@snapshot'`, `--grep '@snapshot'`) are protected by Playwright's own exit-1. Adding `--shard` **removes that protection**. The emptiness assertion must cover the grep case, not just the file-count case. |

---

## Empirical Findings (Playwright 1.59.1, run live 2026-07-30)

Verified in a throwaway config at `/tmp/pwshard` symlinking the repo's own `node_modules` (i.e. the **exact pinned install**, `@playwright/test` 1.59.1 confirmed via `require('./node_modules/@playwright/test/package.json').version`). Repo untouched.

| # | Finding | Evidence | Consequence |
|---|---|---|---|
| **E-1** | A sharded run **does** execute its setup-project dependency, and the setup test is counted in the shard's own totals. | `--project=main --shard=1/2` → `Running 2 tests using 1 worker, shard 1 of 2` / `>>> SETUP EXECUTED <<<` / `2 passed`. | Confirms D-01 and the CONTEXT caveat "setup cost is paid once per shard". Budget one login per shard leg, not one per run. |
| **E-2** | A shard leg with **no test files assigned** produces **zero output and exit code 0**. | 2 files, `--shard=3/4` → empty stdout, `exit=0`; JSON reporter `stats` = `{"expected":0,…}`, `suites: []`. | D-19 confirmed exactly as written. Also gives the mechanizable assertion: `stats.expected > 0`. |
| **E-3** | **`--shard` suppresses Playwright's own empty-run failure.** Without `--shard`, an empty `--grep` exits **1** with `Error: No tests found`. With `--shard`, the same empty `--grep` exits **0**, silently. | `--project=main --grep ZZZNOMATCH` → `Error: No tests found`, exit 1. `--project=main --shard=1/2 --grep ZZZNOMATCH` → no output, exit 0. | **Not in CONTEXT.md.** PW-02 removes an existing safety net. The emptiness assertion is therefore *mandatory*, not merely prudent. |
| **E-4** | The setup project runs **once per `npx playwright test` invocation**, not once per dependent project. | Config with `a` and `b` both `dependencies: ['setup']`, invoked `--project=a --project=b` → `SETUP EXECUTED` appears exactly **1** time. | Confirms D-08's premise (the chosen shape authenticates once *total*, not once per project) and prices the cost correctly: 1 login per CI step invocation. `example_playwright_smoke` invokes the design projects in 2 steps → 2 logins on non-PR, 1 on PR. |
| **E-5** | `--pass-with-no-tests` exists as a CLI flag in 1.59.1 ("Makes test run succeed even if no tests were found"), implying default = fail — **but that default does not apply to shards** (E-2/E-3). | `npx playwright test --help \| grep no-test`. | Do not reason from the flag's existence to safety. The shard path is special-cased. |

**Reproduction:** the throwaway config and the four commands are reproduced verbatim in § Code Examples so the planner can re-run them without reconstructing the setup.

---

## Standard Stack

**This phase introduces no new runtime or test dependencies.** It is a workflow-topology and test-runner-configuration change over the already-pinned toolchain.

### Core (all already present and pinned)

| Component | Version | Where pinned | Purpose in this phase |
|---|---|---|---|
| `@playwright/test` | **1.59.1** (resolved) | `test/example/priv/playwright/package-lock.json`; declared `^1.48.0` in `package.json:13` | Setup projects, `storageState`, `dependencies:`, `--shard`. `[VERIFIED: node -e require(...).version, run live]` |
| GitHub Actions composite actions | schema `runs.using: composite` | N/A (platform) | PW-03 mechanism (D-25) |
| `actions/checkout` | `3d3c42e5…` (v7.0.1) | `ci.yml` (SHA-pinned everywhere) | Prelude step |
| `erlef/setup-beam` | `54075bcc…` (v1.24.1) | `ci.yml` | Prelude step |
| `actions/setup-node` | `82076278…` (v7.0.0) | `ci.yml` | Prelude step (node 20) |
| `actions/cache` | `55cc8345…` (v6.1.0) | `ci.yml` | Prelude step — **caller-owned for browsers** (see C-4) |
| `postgres` service image | `postgres:15` | `ci.yml` (7 occurrences) | Per-shard DB (D-15) |
| ExUnit | Elixir ~> 1.18 | `.tool-versions` | `test/sigra/planning/*_test.exs` contracts |
| `node:test` | node 20 | CI `setup-node` | `scripts/ci/prohibitions/*.test.mjs` |
| bash + `jq` + `gh` | runner-provided | — | `scripts/ci/*.sh` instruments |

### Alternatives Considered (and rejected by locked decisions — recorded so they are not re-litigated)

| Instead of | Could Use | Why rejected |
|---|---|---|
| Setup project (`dependencies:` + `storageState`) | `globalSetup` | D-01. `globalSetup` has no project-scoped `storageState` wiring, cannot be selected/inspected as a test, and produces no test-count evidence — which D-14 requires. |
| Matrix shard with per-shard Postgres + app | `workers: N` against one boot | D-15. `playwright.config.ts:11-13` states DB state is shared; multi-worker against one DB is the interference SC-2 forbids. |
| Local composite action | A `scripts/ci/boot-example.sh` | D-25. The block contains four `uses:` steps; a shell script cannot invoke an action. |
| Per-shard alternate ports | Port 4000 on every shard | D-16. `config.exs:39` bakes `PORT` as a `compile_env` key; a non-4000 port trips `validate_compile_env` and aborts boot (this is the documented `admin_eval_render` PORT 4011 lesson, `ci.yml:2553-2557`). |
| Retries / `continue-on-error` to absorb shard flake | — | D-15/D-17 forbid it; `p04`, and the aggregator's whole design, exist to make this loud. |

**Installation:** none. No `mix.exs` or `package.json` change is expected. If the planner finds one is needed, that is a signal the design drifted from D-15/D-25.

---

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.**

| Package | Registry | Verdict | Disposition |
|---|---|---|---|
| *(none)* | — | — | — |

**Packages removed due to `[SLOP]` verdict:** none.
**Packages flagged as suspicious `[SUS]`:** none.

The `package-legitimacy check` gate is satisfied vacuously: `git grep` over the phase's touch surface (`.github/**`, `scripts/ci/**`, `test/example/priv/playwright/playwright.config.ts`, `tests/admin-design.spec.ts`, `test/sigra/planning/**`) finds no dependency-manifest file. Every version referenced in § Standard Stack is already lockfile-resolved and already guarded (`playwright-cache-key-guard.sh` asserts the workflow's Playwright version against `package-lock.json`).

**If the plan proposes any `npm install` / `mix deps` change, it has left the phase's scope** — surface it rather than absorbing it.

---

## Architecture Patterns

### System Data Flow — where PW-01/02/03 intervene

```
                        pull_request / push / schedule / dispatch
                                        │
                        ┌───────────────┴───────────────┐
                        │                               │
                  [changes job]                  [release_ref_guard]
                  docs_only: bool                        │
                        └───────────────┬───────────────┘
                                        ▼
        ╔═══════════════ example_playwright_smoke (TODAY: one job) ═══════════════╗
        ║                                                                         ║
        ║  BOOT PRELUDE  ──────────────────────────────► [PW-03 factors this out] ║
        ║   checkout → setup-beam → setup-node → cache(deps) → deps.get →         ║
        ║   compile → ecto.create/migrate → seeds → npm ci → cache(browsers) →    ║
        ║   playwright install → phx.server(:4000) & → wait + warm 8 routes       ║
        ║                                │                                        ║
        ║                                ▼                                        ║
        ║  SEAMS (serial, workers:1)  ───────────────► [PW-02 splits these]       ║
        ║   ① admin_behavior      (7 specs, --project=chromium)                   ║
        ║   ② admin_checkpoints   (3 checkpoint projects) ──┐                     ║
        ║        └─► Stage admin checkpoint PNGs ◄──────────┘ (order-critical)    ║
        ║   ③ design_gallery      (3 design projects, --grep-invert '@snapshot')  ║
        ║        └─ beforeEach → registerUser() ◄─── [PW-01 removes this]         ║
        ║   ④ design_gallery_snapshots (non-PR only, --grep '@snapshot')          ║
        ║   ⑤ non_admin_smoke     (6 specs, default project)                      ║
        ║   ⑥ demo_showcase       (demo-showcase-chromium)                        ║
        ║                                │                                        ║
        ║                                ▼                                        ║
        ║  AGGREGATOR  if: always() — reads ①..⑥ .outcome; any 'failure' → exit 1 ║
        ║              [D-20: this contract must survive PW-02]                   ║
        ║                                │                                        ║
        ║                                ▼                                        ║
        ║  POST  Collect PNGs → artifact-bundle-contract (MIN_COUNT=15) → uploads ║
        ║        [depends on ② having run IN THIS JOB]                            ║
        ╚═════════════════════════════════╤═══════════════════════════════════════╝
                                          │ job name: "Example Playwright smoke (full lifecycle)"
                                          ▼
                    ┌─────────────────────┴─────────────────────┐
                    ▼                                           ▼
        ruleset 14941512 required context           ci-gate.needs (internal aggregator)
                                                              │
                                          ┌───────────────────┴────────────┐
                                          ▼                                ▼
                              honest-skip-verdict.sh            legacy skip-as-pass loop
                              (nine-lane fixed list)

        ── after the run terminates ──►  ci-observe.yml (workflow_run: completed)
                                          ├─ ci-demotion-observer.sh  (reads .steps[] by NAME)
                                          └─ docs-only-receipt.sh     (five context names)
```

**What the diagram tells the planner:** the job is not a bag of steps. Three ordering couplings are load-bearing and survive into any shard split — ② must precede its staging step *in the same job*; the POST bundle contract needs ②'s PNGs *in the same job*; and the aggregator must see all six outcomes *in whatever job now owns them*.

### Pattern 1 — Setup project + shared `storageState` (PW-01)

**What:** A non-`.spec.ts` file registered as its own Playwright project; the three design projects declare `dependencies: ['<setup>']` and `use: { storageState: '<path>' }`.

**When to use:** exactly this case — N tests in one file that all need the same authenticated identity, where the identity is already seeded.

**Constraints this pattern must satisfy here:**
- The setup file must be excluded from `chromium` and `mobile` `testIgnore` (D-06) — those two projects use directory-wide `testIgnore`, so an unlisted new file in `tests/` is picked up automatically.
- It must live under `testDir` (`tests/`) to be discoverable at all.
- It must not be named `*.spec.ts` (D-07).
- Its `baseURL` must be byte-identical to the design projects' (D-04) — inherited automatically from top-level `use.baseURL` (`playwright.config.ts:76`) provided the setup project does not override `use`.
- It must assert authentication before writing state (D-05).

**Anti-pattern:** writing `storageState` from `beforeAll` in the spec. `admin-design.spec.ts:267-272` documents why the current code registers per-test: each Playwright test gets an isolated browser context, so a `beforeAll` login on a separate page does **not** authenticate test pages. `storageState` is the mechanism that *does* cross that boundary — it is not the same thing as `beforeAll`, and the existing comment must be rewritten rather than deleted, or it will read as contradicting the new code.

### Pattern 2 — Local composite action for a boot prelude (PW-03)

**What:** `.github/actions/boot-example-app/action.yml` with `runs: using: composite`, consumed as `- uses: ./.github/actions/boot-example-app` with a `with:` block.

**Mechanics that are non-obvious (D-28/D-29, all pre-verified in CONTEXT):** `shell:` required on every `run:`; inputs are strings; `$GITHUB_ENV` leaks outward; no `continue-on-error` on composite steps; internal step ids are action-scoped (re-export via `outputs.<name>.value`); `cache-hit` is `''` (not `'false'`) on a total miss; never nest a cache-bearing composite.

**The two structural constraints this repo adds:**
1. **Browser cache stays caller-owned** (C-4-corrected D-27). The example-deps cache may live inside the composite; `~/.cache/ms-playwright` must not, or `admin_eval_render`'s no-browser-cache guarantee becomes an input value rather than a structural fact.
2. **`p15` parses the *caller's* literal step list.** See § Guard Surface — this is the single hardest constraint in PW-03.

**Anti-pattern:** a composite that swallows the docs-only `if:` conditions. Those conditions are what `p10`'s `stepIf()` resolves and what `.github/ci-skip-manifest.tsv`'s tier-C rows record. Moving them inside the composite makes them invisible to every guard that reads `ci.yml`.

### Pattern 3 — Matrix shard → name-preserving thin aggregator (PW-02, SC-3)

**What:** the shipped `library_tests_shard` (`ci.yml:497-602`) → `library_tests` (`:604-622`) pair, copied structurally.

The template's four load-bearing properties, verified in the file:
1. Working job's `name:` **interpolates the matrix value** (`Library tests shard ${{ matrix.partition }}`, `:498`) — this is what stops Actions from emitting `Library tests (1)`/`(2)` and orphaning the bare required context.
2. `strategy.fail-fast: false` (`:503`) — one leg failing must not cancel the sibling.
3. Aggregator declares `needs: [<shard>]` + **`if: always()`** (`:608-609`).
4. Aggregator's body reads `needs.<shard-job>.result` and `exit 1` on anything but `success` (`:615-622`). The inline comment at `:617-618` records the semantics: `needs.<matrix-job>.result` is `success` only if **every** leg succeeded, independent of `fail-fast: false`.

**Anti-pattern (documented at `ci.yml:594-599`):** putting a matrix on the job that carries the required `name:`. That produces `Example Playwright smoke (full lifecycle) (design)` etc. and leaves the ruleset's required context permanently pending — a merge outage, not a test failure.

### Anti-Patterns to Avoid (phase-specific)

- **Editing a prohibition guard to make the refactor pass, without recording it.** `p11`'s own header names this as the failure class it exists to prevent. Three guards *must* change here (`p15`, `playwright-cache-key-guard.sh`, `phase_230_design_gallery_split_test.exs`); each change must preserve the guard's *intent* and be recorded with its evidence, not quietly relaxed.
- **Proving anything by reading YAML.** D-33 + STATE.md. A static read is a necessary-but-not-sufficient pre-check.
- **Treating a `skipped` shard leg as a pass.** `ci-gate` counts skipped as pass; `needs.<matrix>.result` is `skipped` when the whole matrix is skipped. The aggregator's `!= 'success'` test (Pattern 3 property 4) is what closes this — do not relax it to `!= 'failure'`.
- **Measuring PW-01 and PW-02 on the same run.** D-31. Two separate observed runs, two separate ledger slots.

---

## The Measurement Instrument (D-11 / D-14)

### Why the existing instrument is insufficient — verified

`scripts/ci/ci-run-metrics.sh --jobs <run>` fetches `gh run view <id> --json jobs --jq '.jobs'` (`:94`) and projects through `DURATION_JQ` (`:100-104`), emitting `{name, conclusion, duration_seconds}` **per job**. It never descends into `.steps[]`. `[VERIFIED: read scripts/ci/ci-run-metrics.sh:93-125]`

`scripts/ci/ci-demotion-observer.sh` *does* descend — `.jobs[] | select(.name == $pj) | .steps[]? | select(.name == $n)` (`:151-153`) — but it is manifest-driven (it only ever looks at tier-B `assert` rows, `:172-178`), fail-closed on non-terminal state, and its output shape is a verdict list, not a duration table. D-11 is right that it should not be repurposed in place.

### What the new reader must emit

SC-1 needs *the design-board step's before/after duration*. D-14 needs *executed test counts, not just durations*. Those are two different data sources — the Actions API gives step durations; only the Playwright reporter gives test counts. **A single reader cannot produce both from one source.** The instrument must therefore be a pair:

**(a) Step-duration reader** — from the Actions API, one `gh run view` round-trip:

| Field | Source | Why |
|---|---|---|
| `job_name` | `.jobs[].name` | The API returns names, never ids (same constraint `ci-demotion-observer.sh` documents at manifest column `display_name`) |
| `step_name` | `.jobs[].steps[].name` | The SC-1 subject |
| `step_id` | *(not available)* | **The Actions API does not expose a step's `id:`.** Every consumer resolves steps by `name`. This is why `.github/ci-skip-manifest.tsv` carries a `display_name` column at all. |
| `conclusion` | `.steps[].conclusion` | `skipped` must be distinguishable from `success` (D-33) |
| `duration_seconds` | `completedAt - startedAt`, clamped at 0 | Reuse `ci-run-metrics.sh`'s documented clamp rule verbatim — an unfinished step serializes `completedAt: "0001-01-01T00:00:00Z"` |
| `status` | `.steps[].status` | Fail closed when `!= completed`, exactly as `ci-demotion-observer.sh:167-170` does |

**(b) Executed-test-count capture** — from Playwright itself, at run time. Two viable sources, both verified:
- The `list` reporter's terminal line `N passed (Xs)` — this is the form `230-EVIDENCE.md` already records and the form `p03`'s regex (`/\b(\d+)\s+(?:passed|tests)\b/`) already parses. **Lowest-friction: it requires no config change and keeps the ledger format stable.**
- A `json` reporter `stats.expected` — machine-readable, and the same value the D-19 emptiness assertion needs (E-2). Adding `['json', { outputFile: … }]` alongside the existing `[['list'], ['html', …]]` (`playwright.config.ts:56`) costs nothing at runtime and yields one artifact per invocation.

**Recommendation:** implement both — `list` for the human/ledger surface (unchanged), `json` for the emptiness assertion and the count evidence. They are the same instrument serving D-14 and D-19 simultaneously.

### Non-negotiables inherited from the existing instrument family

Every `scripts/ci/*.sh` instrument in this repo shares five properties. The new reader must match them or it will look foreign in review and will not survive `fast_checks`:

1. **A hermetic self-test** (`<name>.test.sh` / `.test.mjs`) wired into `fast_checks`, shadowing `gh` on `PATH` with a recording stub — no network, no `GH_TOKEN`. Precedents: `ci-run-metrics.test.sh` (`ci.yml:151` region), `ci-demotion-observer.test.sh` (`ci.yml:~340`), `docs-only-receipt.test.sh`.
2. **`--from-json <payload>`** so a saved run payload can drive it offline (both `ci-demotion-observer.sh:66-72` and `docs-only-receipt.sh` support this; `ci-observe.yml` depends on it to preserve the one-round-trip contract).
3. **Fail-closed non-vacuity:** an empty parse is a broken run, never a clean one. Every instrument here asserts a floor and says *"the parse broke, this is not a pass"*.
4. **`--format table|json`.**
5. **Never echo secrets;** invoke `gh` bare via `PATH`.

### The stronger claim D-11 does not make

**The step-level reader is a blocker for PW-02's *design*, not only for PW-01's *proof*.** The only per-step number on record anywhere is the design-gallery one (D-12, from a Playwright reporter line, not from a step-duration reader). The other five seams — `admin_behavior`, `admin_checkpoints`, `non_admin_smoke`, `demo_showcase`, and the post-seam artifact steps — have **never been measured**. A shard boundary chosen without them is a guess, and a guess that lands badly produces an *unbalanced* split where one leg dominates and the wall-clock barely moves — exactly the TEST-02 failure mode Phase 233 exists to fix for the library shards. Capture the six BEFORE step durations on one real PR run before choosing the axis.

---

## Guard and Prohibition Surface

Eleven checks constrain this phase. For each: what it parses, what breaks it, and how to run it locally. **Rows marked ⛔ will fail on the *intended* refactor** — they are deliverables, not hazards.

| Guard | Subject it parses | What breaks it | Local command |
|---|---|---|---|
| `p01-committed-method-provenance` | `230-EVIDENCE.md` (hard-coded, `p01:19`) | Nothing in 232 — it never reads a 232 artifact. See C-3: a **new** 232-scoped guard is required for the same clause. | `node --test scripts/ci/prohibitions/p01-*.test.mjs` |
| `p02-axe-signal-not-reduced` | `tests/admin-design.spec.ts` (JS-comment-stripped) **+** `ci.yml` | (a) axe test title changes; (b) axe test gains a `{ tag: … }`; (c) `assertNoAxeViolations` gains `.include(`; (d) any of the five WCAG tags drops; (e) `ci.yml`'s `id: design_gallery` step loses any of the three design projects or its `--grep-invert`. Its `ci.yml` regex is `/id: design_gallery\n[\s\S]*?(?=- name:\|\n {6}- )/` — **it does not care which job the step lives in**, so a shard move is survivable *if* the step id, the three `--project` flags and `--grep-invert` all survive verbatim. | `node --test scripts/ci/prohibitions/p02-*.test.mjs` |
| `p03-no-green-on-empty-grep` | `230-EVIDENCE.md` (hard-coded) | Same as `p01` — 230-pinned. The **runtime half** is `ci-demotion-observer.sh`, which is live and does bind 232. | `node --test scripts/ci/prohibitions/p03-*.test.mjs` |
| `p09-timeouts-not-truncating` ⛔ | `ci.yml`, YAML-comment-stripped, via `jobBlocks()` | (a) **Any new `runs-on:` job without exactly one job-level `timeout-minutes`** — the new `example_playwright_shard` needs one, in `[5, 60]`; (b) **`example_playwright_smoke` must keep `timeout-minutes: 45` exactly** (`p09:74-88` pins it against a *measured* value). A thin aggregator with a 45-minute ceiling is absurd but **required** unless the pin is changed — and `p09`'s own message says changing it "without a fresh measurement is exactly the guesswork this prohibition forbids". **Resolution must be recorded, not incidental.** | `node --test scripts/ci/prohibitions/p09-*.test.mjs` |
| `p10-no-undocumented-demotion` ⛔ | `.github/ci-skip-manifest.tsv` + `ci.yml` | Six assertions, all bidirectional. Breaks if: the tier-B `design_gallery_snapshots` row's `parent_job_id` no longer names a `kind=job` manifest row; a `display_name` no longer matches a literal `^ {4}name: …` in `ci.yml`; a job gated `github.event_name != 'pull_request'` appears with no manifest row; or `stepIf()` cannot find `^ {8}id: <id>` followed by `^ {8}if:` inside the recorded parent job. **A matrix parent's `display_name` is `Example Playwright smoke shard ${{ matrix.seam }}` in `ci.yml` but resolves to `… shard design` in the API** — the manifest serves both `p10` (literal match) and `ci-demotion-observer.sh` (API-name match), and those two requirements are in direct conflict for a matrix parent. See § Sharding Mechanics ▸ The manifest/observer conflict. | `node --test scripts/ci/prohibitions/p10-*.test.mjs` |
| `p11-sc-restatement-recorded` | `230-EVIDENCE.md` (hard-coded) | 230-pinned (C-3). D-08's obligation is real; the enforcing guard must be new. Heading grammar to match: `^##\s+Restated Success Criterion\s*\(SC-\d+\)\s*$`, body must carry a run ID or a command/artifact reference. | `node --test scripts/ci/prohibitions/p11-*.test.mjs` |
| `p12-run-id-provenance` | `230-EVIDENCE.md` (hard-coded) | 230-pinned. Its **format contract** is generic though: `_lib.mjs:214` `SLOT_HEADING_RE = /^##\s+((?:BEFORE\|AFTER)-[A-Z0-9-]+)\s*$/`, `Status: captured (run <id>)` or `pending (<…obligation…>)`, ≥1 fenced block naming `ci-run-metrics.sh` or `gh run/pr/api`, and each Status run id must appear **≥2 times** in the slot body. **The 232 ledger must follow this format exactly** — `_lib.mjs`'s own comment says it is "deliberately GENERIC across every phase's `-EVIDENCE.md`… so Phases 231-235 inherit it." | `node --test scripts/ci/prohibitions/p12-*.test.mjs` |
| `p13-no-lane-green-because-skipped` | `230-EVIDENCE.md` (hard-coded) | 230-pinned. | `node --test scripts/ci/prohibitions/p13-*.test.mjs` |
| `p15-pages-publisher-seeds-before-boot` ⛔⛔ | `.github/workflows/playwright-github-pages.yml`, job `publish` | **This is the hardest constraint in PW-03.** `stepList()` splits on `^ {6}- ` and labels each step by its `^ {6}- name:` (falling back to `uses:<value>`). `seedsOrderingIssue()` then requires: a step literally named `Setup example dev DB`; a step whose name **starts with** `Boot example app`; **exactly one** step whose raw text matches `run:.*seeds\.exs`; the seeds step strictly between the other two; and the seeds step carrying **no** `if:`. Replacing those steps with `- uses: ./.github/actions/boot-example-app` makes all three lookups fail and the guard returns *"the parse broke, this is not a pass"* — **a hard red on the intended refactor.** | `node --test scripts/ci/prohibitions/p15-*.test.mjs` |
| `scripts/ci/playwright-cache-key-guard.sh` ⛔ | `.github/workflows/ci.yml` (default `--workflow`) + `test/example/priv/playwright/package-lock.json` | Greps `ci.yml` for `playwright-chromium-webkit-<x.y.z>-vN` (`:56-62`), `head -1`, **fails closed if absent**. Moving the browser-cache key literal into the composite removes it from `ci.yml` → `no Playwright browser cache key … found`. Guard accepts `--workflow <path>`, so a `fast_checks` invocation pointed at the composite is a clean remediation — but `fast_checks` currently invokes it bare (`ci.yml:337`). | `bash scripts/ci/playwright-cache-key-guard.sh` |
| `scripts/ci/honest-skip-verdict.sh` | `ci.yml` `ci-gate.needs` block + the manifest | Holds a **fixed nine-lane list** (`:101-111`) cross-checked **bidirectionally** against `ci-gate.needs` (`:142-157`): a lane in `needs` but not the list → fail; a lane in the list but not `needs` → fail. Its extractor (`:118-134`) requires bare `^      - <id>$` lines. Also requires **≥5 of the nine** to have a manifest row (`:167-176`). **D-23 restated precisely: adding `example_playwright_shard` to `ci-gate.needs` reds this immediately.** | `bash scripts/ci/honest-skip-verdict.test.sh` |
| `scripts/ci/ci-demotion-observer.sh` | `.github/ci-skip-manifest.tsv` + a terminal run payload | Resolves a `kind=step` row by looking up `.jobs[] \| select(.name == <parent display_name>) \| .steps[] \| select(.name == <step display_name>)`. Both names come from the manifest. Requires **≥2** `assert` rows (`:184-187`) or it hard-fails. Any verdict but `success`/`failure` on an assert row → FAIL. **This runs on every non-PR run, post-merge, from `ci-observe.yml`** — it will judge 232's own merge commit. | `bash scripts/ci/ci-demotion-observer.test.sh` |
| `test/sigra/planning/phase_230_design_gallery_split_test.exs` ⛔⛔ | `tests/admin-design.spec.ts` + `ci.yml` + `scripts/ci/snapshot-recapture-gate.sh` | Nine tests. Four pin the spec file (D-10 ✔, all four re-verified). **Three are job-scoped to `example_playwright_smoke` via `extract_job/2` and will certainly break on PW-02:** (i) `:186-215` requires `design_gallery_snapshots` + a `design_gallery` `run: \|` block containing `--grep-invert` + a `id: design_gallery_snapshots\n(.*?)- name: Run non-admin` region carrying the non-PR `if:` — **this pins step *adjacency*, not just presence**; (ii) `:217-234` requires the `Aggregate Playwright step outcomes` step and all six `steps.<id>.outcome` references **inside that job's body**; (iii) `:148-184` pins `admin_design_recapture`'s ungrepped invocation. Note `extract_job`'s job-id regex is `^  ([a-z_]+):$` — it does **not** match `ci-gate` (hyphen), so `example_playwright_smoke`'s extracted block currently runs to `generated_admin_playwright_smoke:` at `:1702`. | `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs` |
| `test/sigra/planning/phase_230_ci_timeouts_test.exs` | `ci.yml` | Deliberate duplicate of `p09` in ExUnit idiom (`p09:12-17` discloses this and names the ExUnit file as "the one humans read"). Same failure modes. **Keep the two in sync in one commit.** | `mix test test/sigra/planning/phase_230_ci_timeouts_test.exs` |
| `scripts/ci/docs-only-receipt.sh` + `_lib.mjs REQUIRED_CONTEXTS` | five literal context strings | Both hard-code `Example Playwright smoke (full lifecycle)`. Preserved by SC-3's byte-identical `name:`. **Verify with `git grep -c` after any rename, in the same commit (D-24).** | `bash scripts/ci/docs-only-receipt.test.sh` |
| `p06-never-docs-gate-asserting-lanes` | `ci.yml` | Asserts `fast_checks`, `library_tests`, `library_tests_shard` carry **zero** `docs_only` tokens and **no `needs: changes`**. A new `example_playwright_shard` is *not* in `NEVER_DOCS_GATED` — so it may carry docs-only gating. Only relevant if the planner adds a guard-adjacent job. | `node --test scripts/ci/prohibitions/p06-*.test.mjs` |

**Run the whole prohibition set exactly as `fast_checks` does** (`ci.yml:380`) — the glob is load-bearing; a bare directory arg fails under node 22:

```bash
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```

### The three ⛔ remediations, stated as design problems

1. **`p15` vs. the composite.** The guard's *intent* is "the Pages publisher seeds before it boots, unconditionally." Its *implementation* is a literal step-name walk over the caller. Preserving intent under a composite means the guard must **follow the `uses:` indirection**: detect `uses: ./.github/actions/boot-example-app` in the publish job, then run `seedsOrderingIssue()` over the *composite's* step list, and additionally assert the caller passes an explicit non-empty seeds input. Anything weaker (deleting the guard, or asserting only that the `uses:` line exists) is the silent-narrowing failure `p11` names.

2. **`playwright-cache-key-guard.sh` vs. the composite.** The guard already accepts `--workflow <path>` (`:35-40`). If the browser-cache key literal moves, `fast_checks:337` must pass the new path. If the key literal *stays* in `ci.yml` (browser cache caller-owned per C-4), the guard needs no change at all — which is one more argument for keeping browsers out of the composite.

3. **`phase_230_design_gallery_split_test.exs` vs. the shard split.** The three job-scoped tests must be re-pointed at whichever job now owns the seams. That is a *correct* update (the contract's meaning is "these steps and this aggregator exist and are wired"), but it edits a **prior phase's** contract file, so it needs an explicit in-file note recording the Phase 232 re-anchoring — the same discipline `p09` uses when it discloses its duplication with the ExUnit twin.

---

## Composite Action Shape (PW-03)

### Call-Site Difference Matrix

Derived by reading all seven sites, not from the ROADMAP. ✓ = present, ✗ = absent.

| | `example_unit_smoke` | `example_http_smoke` | `example_playwright_smoke` | `admin_design_recapture` | `admin_checkpoint_recapture` | `admin_eval_render` | `pages/publish` |
|---|---|---|---|---|---|---|---|
| **File** | `ci.yml:718` | `ci.yml:1159` | `ci.yml:1248` | `ci.yml:1989` | `ci.yml:2297` | `ci.yml:2547` | `pages.yml:32` |
| `checkout` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `setup-beam` (`id: setup`) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ *(no `id:`)* |
| `setup-node` | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **MIX_ENV** | **test** | dev | dev | dev | dev | dev | dev |
| deps-cache **key shape** | `-example-otp…-test-` | `-example-dev-otp…-dev-` | `-example-dev-otp…-dev-` | `-example-dev-otp…-dev-` | `-example-dev-otp…-dev-` | `-example-dev-otp…-dev-` | **`-example-dev-<hash>`** (no otp/elixir tokens, **no `restore-keys`**) |
| deps-cache step **id** | `example_unit_deps_cache` | `http_smoke_deps_cache` | `example_deps_cache` | `recapture_example_deps_cache` | `checkpoint_recapture_example_deps_cache` | `admin_eval_render_deps_cache` | *(none)* |
| `deps.get` + `compile --warnings-as-errors` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ecto.create && ecto.migrate` | ✓ *(MIX_ENV=test)* | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **`seeds.exs`** | ✗ | **✗** | ✓ `:1314` | ✓ `:2048` | ✓ `:2356` | ✓ `:2608` | ✓ `pages:96` |
| `npm ci` | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **browser cache** (`~/.cache/ms-playwright`) | ✗ | ✗ | **✓ only here** (`:1327`, key `:1359`) | ✗ | ✗ | **✗ (structural guarantee)** | ✗ |
| browser install form | — | — | **branched** (hit→`install-deps`, miss→`install --with-deps`) | plain `install --with-deps chromium webkit` | plain | plain | plain |
| `phx.server &` | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| server log path | — | `/tmp/example-http-server.log` | `/tmp/example-playwright-server.log` | `/tmp/example-recapture-server.log` | `/tmp/example-checkpoint-recapture-server.log` | `/tmp/example-admin-eval-render-server.log` | `/tmp/example-playwright-pages.log` |
| **PORT** | — | 4000 | 4000 | 4000 | 4000 | **4011** (job-level `env:`) | 4000 |
| wait + warm | ✗ | ✗ | ✓ **8 routes** | ✓ 8 routes | ✓ 8 routes | ✓ **1 route** (`/admin/_design`) | ✓ 8 routes |
| per-step `if: docs_only != 'true'` | ✓ **every step** | ✓ every step | ✓ every step | ✗ | ✗ | ✗ | ✗ |
| `changes` job available? | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | **✗ (different workflow)** |

### Derived input surface

| Input | Type (all strings, D-28) | Values observed | Notes |
|---|---|---|---|
| `mix-env` | `'dev'` \| `'test'` | 6× dev, 1× test | Drives both the env and the deps-cache key token |
| `cache-key-suffix` or `cache-key` | string | 3 distinct shapes | The pages workflow's key omits otp/elixir tokens and has no `restore-keys`. **Recommend normalizing it to the ci.yml shape** as part of PW-03 — a divergence with no recorded rationale is dead weight, but this is a behavior change and needs its own justification line. |
| `cache-id` | string | 6 distinct ids, 1 absent | Composite step ids are action-scoped (D-29) — the caller cannot read them. Either drop the per-caller ids and export a single `deps-cache-hit` output, or keep the `Cache hit summary` steps in the callers reading that output. |
| `seeds` | `'true'`\|`'false'` | 5 true, 2 false | **Must not default to `true`** (C-5): `example_http_smoke` and `example_unit_smoke` do not seed today. |
| `node` | `'true'`\|`'false'` | 5 true, 2 false | |
| `browsers` | `'none'`\|`'chromium webkit'` | 5 install, 2 none | |
| `browser-cache` | `'true'`\|`'false'` | **1 true, 6 false** | Per C-4, this is the *only* cache that must be input-gated. Strongly consider keeping this step in the caller entirely (see `playwright-cache-key-guard.sh` remediation). |
| `boot` | `'true'`\|`'false'` | 6 true, 1 false | |
| `port` | `'4000'`\|`'4011'` | 6× 4000, 1× 4011 | D-16 — must agree at compile **and** runtime |
| `server-log` | path | 6 distinct | Could be derived from a `name` input |
| `warm-paths` | space-separated | 8-route set (5×), 1-route set (1×), none (2×) | |
| `enabled` (docs-only gate) | `'true'`\|`'false'` | 3 gated, 4 not | **Risk:** moving `if: needs.changes.outputs.docs_only != 'true'` inside the composite hides it from `p10`'s `stepIf()` and from `honest-skip-verdict.sh`. Prefer a caller-level `if:` on the whole `uses:` step, which stays visible in `ci.yml` — and verify `p10`'s tier-C rows still resolve. |

**Ten inputs is a lot.** The planner should consider whether `example_unit_smoke` (MIX_ENV=test, no node, no boot, no seeds, no browsers, different cache key) belongs in the composite at all. SC-4's wording is "the jobs **that boot the app**" — `example_unit_smoke` does not boot. Excluding it drops the `mix-env`, `boot`, and one cache-key-shape axes and leaves six call sites. That is a materially simpler action and is defensible against SC-4's literal text. Record the decision either way.

---

## Sharding Mechanics (PW-02)

### What is already true and needs no code change

- `test/example/config/dev.exs:4-12` reads `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGPORT`, `PGDATABASE` from env with defaults. **Per-shard DB isolation is achieved entirely by setting `PGDATABASE` (or by giving each matrix leg its own `services.postgres`).** `[VERIFIED: read test/example/config/dev.exs:1-13]`
- Each matrix leg gets its **own runner VM**, so a per-leg `services.postgres` is automatic and there is no port contention between legs. Port 4000 on every leg (D-16) is therefore safe.
- `test-results/` is per-runner, so D-18 item 5 is moot under matrix sharding.
- `registrationSequence` (`admin-design.spec.ts:52`) is per-Node-process; under matrix sharding each leg is a distinct process, so it is moot **provided PW-01 removes the `registerUser` path from the design spec anyway**.

### The three couplings that constrain the shard axis

1. **`admin_checkpoints` → `Stage admin checkpoint PNGs` → `Admin artifact bundle contract`.** The staging step (`ci.yml:1464`) is gated on `steps.admin_checkpoints.outcome == 'success'` and the contract step (`:1653`) enforces `MIN_COUNT=15` PNGs from `test-results/`. All three must land in the **same** shard leg, and the upload steps (`:1654-1700`) must either move with them or be re-scoped. A shard axis that separates ② from its staging step breaks the reviewer artifact bundle silently (green run, zero PNGs — until the contract's `MIN_COUNT` reds it).
2. **`design_gallery` and `design_gallery_snapshots` share a spec file and a `--project` triple.** They differ only by `--grep-invert` vs `--grep` and by the non-PR `if:`. `phase_230_design_gallery_split_test.exs` pins them **adjacent** (`id: design_gallery_snapshots\n(.*?)- name: Run non-admin`). Keeping them in one leg is the low-friction choice.
3. **`p02` requires `id: design_gallery` to still carry the three `--project` flags and `--grep-invert`.** Whatever leg owns it, the invocation text must survive verbatim.

### Two candidate axes

| Axis | Shape | Pros | Cons |
|---|---|---|---|
| **By seam** (`matrix.seam: [behavior, checkpoints, design, smoke]`) | One job template; each of the six steps gated `if: matrix.seam == '<x>'`; aggregator loop keeps **all six** ids verbatim | Satisfies D-20 with **zero change to the aggregator loop** (a step not selected reports `skipped`, which the loop already tolerates); respects all three couplings naturally; `p02`/ExUnit step-id assertions survive if the ExUnit job anchor is re-pointed | Leg durations are whatever the seams happen to be — unbalanced by construction. **Cannot be sized without the step-level BEFORE data.** Aggregator's `all_skipped` branch (`ci.yml:1590-1599`) prints the docs-only message on every leg that runs one seam and skips five — **this logic must be revised or it becomes misleading** |
| **By `--shard=i/N`** | Same seam steps on every leg, each `npx playwright test … --shard=${{matrix.i}}/${{matrix.n}}` | Balanced by Playwright's own file-count heuristic | Multiplies invocations; hits **E-3** (grep+shard silently green) on both design steps; setup project re-runs per leg per invocation (E-1); the ②→staging→contract coupling breaks (PNGs scatter across legs); `MIN_COUNT=15` fails on every leg |

**Read of the evidence:** by-seam is the shape the existing couplings and contracts already fit. By-`--shard` fights three of them. But *neither* can be sized without per-seam BEFORE durations — which is why § Measurement Instrument argues the reader is a Wave-0 blocker for PW-02's design.

### The manifest/observer conflict (a real, unresolved constraint)

If `design_gallery_snapshots` moves into a matrix job, `.github/ci-skip-manifest.tsv`'s tier-B row must record a `parent_job_id` and a `display_name`. Those two columns serve two consumers with **incompatible requirements**:

- `p10` asserts `display_name` matches a literal `^ {4}name: <escaped>` in `ci.yml` → the manifest must record `Example Playwright smoke shard ${{ matrix.seam }}`.
- `ci-demotion-observer.sh:151-153` looks the parent up by `.jobs[].name` from the **Actions API**, which returns the *interpolated* name → the manifest must record `Example Playwright smoke shard design`.

Only one string can go in the cell. Three ways out, all requiring a deliberate decision:

**(a)** Keep `design_gallery_snapshots` in a **non-matrix** job. If the seam split leaves the snapshot seam on a plain job (e.g. the thin aggregator is not the only non-matrix job), both consumers resolve. Simplest, and preserves the tier-B contract untouched.
**(b)** Teach the observer to resolve a matrix parent by prefix. That is a real change to a live, post-merge, fail-closed instrument — needs its own self-test cases.
**(c)** Teach `p10` to accept an interpolated-name manifest cell by normalizing `${{ … }}` out of the ci.yml side. Weakens `p10`'s strictest assertion.

**This conflict is not named in CONTEXT.md and is the single most likely place for PW-02 to produce a green that proves nothing** (the observer FAILs on "not found by name", which at least fails loudly — but only post-merge, from `ci-observe.yml`, on a run nobody is watching).

### The emptiness assertion (D-19), concretely

Given E-2 and E-3, the assertion must fire on **executed count**, not on exit code, and must run **per invocation**, not per job. The cheapest correct form: add a `json` reporter, then after each `npx playwright test`, assert `stats.expected > 0`. See § Code Examples.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Matrix job whose result gates a byte-identical required context | A bespoke `if: contains(needs.*.result, …)` expression | The shipped `library_tests_shard` → `library_tests` pair (`ci.yml:497-622`), copied structurally | D-21/D-22. Four properties must all hold (Pattern 3); the shipped pair already documents *why* each one exists, including the `(1)`/`(2)` context-orphaning failure at `:594-599`. |
| Per-shard database isolation | Elixir config changes, a `Repo` prefix scheme, or a sandbox | `services.postgres` per matrix leg + the existing `PGDATABASE`/`PGHOST` env reads in `config/dev.exs:4-12` | Already works; a code change here would also have to survive the installer/template parity tests. |
| Authenticated browser session reuse | A `beforeAll` login, a cookie-injection helper, or a custom fixture | Playwright setup project + `use.storageState` | D-01. Also the only shape that produces a *test* (hence a count) rather than an invisible hook — which D-14 needs. |
| Detecting an empty test run | Parsing the `list` reporter's stdout for "0 passed" | `json` reporter `stats.expected` | E-2 shows an empty shard produces **no stdout at all** — there is no "0 passed" line to parse. |
| Step-duration extraction | A second `gh` round-trip per step, or scraping the run log | One `gh run view --json jobs` and `jq` over `.jobs[].steps[]` | The payload already contains every step; `ci-demotion-observer.sh:151-153` shows the exact projection. Extra round-trips break the "exactly one round-trip" contract `ci-observe.yml` depends on. |
| A shell script that runs a boot prelude | `scripts/ci/boot-example.sh` | A composite action | D-25. Four of the steps are `uses:` — unreachable from a shell script. |
| Re-deriving the honest-skip set | A new enumeration in the shard job | `.github/ci-skip-manifest.tsv` | Its header explicitly names itself the single source of truth and lists its three consumers. `p10` + `honest-skip-parity` fail in both directions on drift. |

**Key insight:** every problem this phase encounters has already been solved once in this repository, usually by Phase 230 or 231, and usually with an inline comment explaining the failure mode that motivated it. The cost of hand-rolling here is not wasted effort — it is producing a *second* oracle for a question that already has one, which is the exact drift the whole guard apparatus exists to prevent.

---

## Common Pitfalls

### Pitfall 1: The silent-green shard
**What goes wrong:** a shard leg runs zero tests and reports success.
**Why it happens:** two independent triggers — fewer spec files than shards (E-2), *and* `--shard` combined with a non-matching `--grep` (E-3). The second is new to this phase and is not in CONTEXT.md.
**How to avoid:** assert `stats.expected > 0` from a `json` reporter after every invocation in every leg.
**Warning signs:** a leg whose duration is ~0s beyond the prelude; a leg with no `N passed` line in its log.

### Pitfall 2: The orphaned required context
**What goes wrong:** the ruleset's required check never resolves; PRs hang "Expected — Waiting for status".
**Why it happens:** a matrix on the job carrying the required `name:` emits `Name (value)` contexts, never a bare `Name`.
**How to avoid:** Pattern 3 property 1 — interpolate the matrix value into the *shard* job's name and keep a separate non-matrix aggregator.
**Warning signs:** `gh pr checks` shows `Example Playwright smoke (full lifecycle) (design)` instead of the bare name. **This is a merge outage, not a test failure**, and it is only observable on a real PR (D-33).

### Pitfall 3: The skipped aggregator that reports success
**What goes wrong:** a shard fails, the aggregator is skipped, and the skipped required check counts as a pass.
**Why it happens:** a job whose `needs` dependency failed is *skipped* by default; GitHub reports a skipped required check as success.
**How to avoid:** `if: always()` on the aggregator (D-22), plus `needs.<shard>.result != 'success' → exit 1`.
**Warning signs:** the aggregator's conclusion is `skipped` on a run where a shard is red.

### Pitfall 4: `p15` reds on a correct refactor
**What goes wrong:** `fast_checks` fails with "the parse broke, this is not a pass" from `p15`.
**Why it happens:** `p15` walks the publish job's literal step names; a `uses:` composite has no `Setup example dev DB` / `Boot example app` / `seeds.exs` steps.
**How to avoid:** rewrite `p15` to follow the `uses:` indirection *before* landing the composite in `playwright-github-pages.yml`, in the same commit, and record the rewrite.
**Warning signs:** `node --test scripts/ci/prohibitions/p15-*.test.mjs` red locally.

### Pitfall 5: `p09`'s 45-minute pin on a 30-second aggregator
**What goes wrong:** `p09` (and its ExUnit twin) assert `example_playwright_smoke` has `timeout-minutes: 45` exactly.
**Why it happens:** the pin was set against a *measured* 28.5m/41.7m-max, and `p09`'s message forbids changing it "without a fresh measurement".
**How to avoid:** decide explicitly — either keep 45 on the thin aggregator (harmless, absurd-looking, needs a comment) or re-pin against the AFTER measurement and update `p09` + `phase_230_ci_timeouts_test.exs` in one commit with the run ID.
**Warning signs:** none until CI; catch it with `mix test test/sigra/planning/phase_230_ci_timeouts_test.exs`.

### Pitfall 6: storageState written to a path the run cannot see
**What goes wrong:** every design test lands on `/users/log_in`; assertions fail confusingly.
**Why it happens:** origin mismatch (`localhost` vs `127.0.0.1`, D-04), a relative `storageState` path resolved against a different cwd, or a setup that "succeeded" without authenticating (D-05).
**How to avoid:** inherit `baseURL` from top-level `use` (do not re-specify it in the setup project); resolve the state path relative to the config file; end the setup with an explicit authenticated assertion.
**Warning signs:** the setup test passes but every design test fails identically.

### Pitfall 7: Composite `if:` invisible to the guards
**What goes wrong:** `p10` reds with "step row … has no if: line ci.yml can resolve near its id:", or `honest-skip-verdict.sh` mis-classifies a skip.
**Why it happens:** moving `if: needs.changes.outputs.docs_only != 'true'` inside the composite removes it from `ci.yml`, which is the only file those guards read.
**How to avoid:** gate at the caller (`if:` on the `- uses:` step), not inside the action.
**Warning signs:** `node --test scripts/ci/prohibitions/p10-*.test.mjs` red.

### Pitfall 8: Measuring both wins on one run
**What goes wrong:** the PW-01 and PW-02 deltas are indistinguishable and the audit's ordering rationale is lost.
**Why it happens:** landing PW-01 and PW-02 in the same PR, or capturing only one AFTER run.
**How to avoid:** D-31's five-step order, with a ledger slot per step.
**Warning signs:** the evidence ledger has one AFTER slot instead of two.

### Pitfall 9: `--no-deps` in a shard invocation
**What goes wrong:** the setup project is suppressed; every test runs unauthenticated.
**Why it happens:** `--no-deps` is a plausible-looking optimization when the same setup appears to run repeatedly (E-4 shows it runs once per invocation, and E-1 shows once per shard leg — both are correct and necessary).
**How to avoid:** never pass `--no-deps`. Consider a guard assertion that no CI invocation carries it.

### Pitfall 10: The stale-comment cascade
**What goes wrong:** `ci.yml:2008-2009` already claims `admin_design_recapture` is a "verbatim clone of ci.yml:886–968" — a range that no longer contains the source (it is now `:1270-1408`). `ci.yml:2316-2317` makes the same claim about `:1406-1485`. `p15`'s header cites four seeds line numbers (`:1288, :1950, :2258, :2506`) that are all stale, and its set wrongly implies `example_http_smoke` seeds.
**Why it happens:** line-number citations in comments are not machine-checked.
**How to avoid:** PW-03 deletes the *duplication* those comments describe — delete or rewrite the comments in the same commit. Prefer symbol/anchor references over line numbers in anything new.

---

## Code Examples

### Reproducing the empirical findings (E-1..E-5)

Verified working, 2026-07-30, against the repo's pinned 1.59.1 `node_modules`:

```bash
rm -rf /tmp/pwshard && mkdir -p /tmp/pwshard/tests && cd /tmp/pwshard
cat > playwright.config.ts <<'EOF'
import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests',
  reporter: [['list']],
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    { name: 'main', testIgnore: [/auth\.setup\.ts/], dependencies: ['setup'] },
  ],
});
EOF
cat > tests/auth.setup.ts <<'EOF'
import { test } from '@playwright/test';
test('SETUP RAN', async () => { console.log('>>> SETUP EXECUTED <<<'); });
EOF
for i in 1 2; do printf "import { test } from '@playwright/test';\ntest('t%s', async () => {});\n" "$i" > tests/f$i.spec.ts; done
ln -s /Users/jon/projects/sigra/test/example/priv/playwright/node_modules node_modules

npx playwright test --project=main --shard=1/2                      # E-1: setup runs, "2 passed"
npx playwright test --project=main --shard=3/4; echo "exit=$?"       # E-2: silent, exit 0
npx playwright test --project=main --grep ZZZ; echo "exit=$?"        # E-3a: "No tests found", exit 1
npx playwright test --project=main --shard=1/2 --grep ZZZ; echo "exit=$?"  # E-3b: silent, exit 0
```

### The shard-emptiness assertion (D-19), keyed on the verified signal

```bash
# After every `npx playwright test …` invocation in a sharded leg.
# stats.expected is 0 on BOTH empty-shard triggers (E-2 file-count, E-3 grep no-match).
npx playwright test "$@" --reporter=list,json --output-file=/tmp/pw-stats.json || RC=$?
EXPECTED="$(jq -r '.stats.expected' /tmp/pw-stats.json)"
if [ "${EXPECTED:-0}" -le 0 ]; then
  echo "::error::shard executed 0 tests -- a green on nothing. \
Playwright suppresses its own 'No tests found' exit-1 when --shard is present."
  exit 1
fi
echo "shard executed ${EXPECTED} test(s)"
exit "${RC:-0}"
```

> The `json` reporter writes to the path given by `PLAYWRIGHT_JSON_OUTPUT_NAME` or the reporter's `outputFile` option; prefer wiring it in `playwright.config.ts` alongside the existing `[['list'], ['html', …]]` (`playwright.config.ts:56`) rather than via CLI, so every invocation gets it uniformly. `[ASSUMED: exact CLI flag spelling — verify with `npx playwright test --help` before writing the plan; the `stats.expected` field itself is VERIFIED above.]`

### Step-duration projection for the new reader (mirrors `ci-demotion-observer.sh:151-153` + `ci-run-metrics.sh:100-104`)

```bash
gh run view "$RUN_ID" --repo "$REPO" --json jobs > /tmp/run.json

jq -r '
  .jobs[] as $j
  | $j.steps[]? as $s
  | (if ($s.completedAt // "") == "" or ($s.startedAt // "") == "" then 0
     elif ($s.completedAt | startswith("0001-")) then 0
     else ((($s.completedAt|fromdate) - ($s.startedAt|fromdate)) as $r
           | if $r < 0 then 0 else $r end)
     end) as $dur
  | [$j.name, $s.name, $s.status, ($s.conclusion // "-"), ($dur|tostring)]
  | @tsv
' /tmp/run.json | column -t -s $'\t'
```

Notes carried from the existing instruments, all load-bearing:
- Clamp negative durations at 0 — a skipped or unfinished step can serialize `completedAt` before `startedAt` (`ci-run-metrics.sh:36-42`).
- `0001-01-01T…` means unfinished — treat as 0 and **fail closed**, never infer (`ci-demotion-observer.sh:161-170`).
- Steps have **no `id:` in the API** — resolve by `name` only.

### Aggregator template to copy verbatim (`ci.yml:604-622`)

```yaml
  example_playwright_smoke:
    name: Example Playwright smoke (full lifecycle)   # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT
    runs-on: ubuntu-latest
    timeout-minutes: 45          # p09 pins this value — see Pitfall 5 before changing
    needs: [example_playwright_shard]
    if: always()                 # a skipped required check reports SUCCESS (D-22)
    steps:
      - name: Require all example_playwright shards to pass
        env:
          # needs.<matrix-job>.result is 'success' only if EVERY leg succeeded,
          # independent of fail-fast: false.
          SHARDS: ${{ needs.example_playwright_shard.result }}
        run: |
          set -euo pipefail
          if [[ "$SHARDS" != "success" ]]; then
            echo "example_playwright_shard result: $SHARDS"
            exit 1
          fi
          echo "all example_playwright shards passed"
```

### Local guard sweep (run before every commit in this phase)

```bash
cd /Users/jon/projects/sigra/.claude/worktrees/discuss-231
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
bash scripts/ci/playwright-cache-key-guard.sh
bash scripts/ci/playwright-cache-key-guard.test.sh
bash scripts/ci/honest-skip-verdict.test.sh
bash scripts/ci/ci-demotion-observer.test.sh
bash scripts/ci/ci-run-metrics.test.sh
bash scripts/ci/docs-only-receipt.test.sh
mix test test/sigra/planning/          # requires Postgres per CLAUDE.md
```

---

## Runtime State Inventory

Phase 232 is a refactor. The canonical question — *after every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?* — applies.

| Category | Items Found | Action Required |
|---|---|---|
| **Stored data** | **None in application datastores.** Nothing in this phase renames a DB key, collection, user_id, or seeded record. The design spec's per-test registered users (`platform-admin+dg-…@example.test`) become *unwritten* rather than renamed — after PW-01 the design lane creates zero users. **Consequence to verify, not migrate:** `admin-design.spec.ts:448-450` filters `/admin/users?q=admin%40demo.tasklane.test` explicitly *because* the harness-created user would otherwise sort first under `inserted_at DESC`. With no harness user, that filter is now redundant but still correct — leave it, and confirm the pagination fixture (≥25 audit events on the seeded admin) still satisfies the test. | Verify on a real run; no data migration. |
| **Live service config** | **GitHub branch ruleset 14941512** stores five required-status-check *context strings* server-side, outside the repo. `Example Playwright smoke (full lifecycle)` is one of them. This is exactly the "config lives in a UI/API, not git" category. SC-3 exists because of it. | **No change** — SC-3's entire point is that the string stays byte-identical. **Verify** with `gh api repos/szTheory/sigra/rulesets/14941512 --jq '.rules[] \| select(.type=="required_status_checks") \| .parameters.required_status_checks[].context'` (command recorded at `MAINTAINING.md:116`) **before and after**, on a real PR. |
| **OS-registered state** | **None.** No Task Scheduler, launchd, systemd, or pm2 registration is involved. GitHub Actions schedules (`cron: '30 4 * * *'` in `ci.yml`, `'45 6 * * *'` in `playwright-github-pages.yml`) are file-defined and travel with the commit. | None. |
| **Secrets / env vars** | **None renamed.** `SIGRA_EXAMPLE_URL`, `PGUSER`/`PGPASSWORD`/`PGHOST`/`PGDATABASE`/`PGPORT`, `PORT`, `PHX_SERVER`, `CI`, `SIGRA_PLAYWRIGHT_PAGES_PUBLISH`, `MIX_ENV` all keep their names. PW-02 *adds* per-shard `PGDATABASE` values; PW-03 moves existing env into composite inputs but must not rename them (D-28: `$GITHUB_ENV` leaks outward, so a composite that sets `MIX_ENV` affects the caller's later steps — deliberate use only). The seeded persona password `DemoAdmin1!SecurePass` is a public-by-design demo credential (`personas.ex:12` comment), not a secret. | None; verify no accidental rename in the composite. |
| **Build artifacts / caches** | **Three live GitHub Actions cache namespaces are affected.** (1) `${{runner.os}}-example-dev-otp…-dev-<hash>-v1` — the example deps cache; if PW-03 changes the key *shape*, every warm entry is orphaned and the first run after merge is a full cold compile on six jobs. (2) `${{runner.os}}-playwright-chromium-webkit-1.59.1-v2` — the browser cache; **its `restore-keys` is a bare prefix and its documented sole consumer is `example_playwright_smoke`** (`ci.yml:1342-1355`). If PW-02 splits that job, **more than one job will consume that prefix**, which invalidates the comment's stated safety argument and reopens the Phase 231 GATE-04 reasoning. (3) `actions/setup-node`'s npm cache, keyed on `package-lock.json` — unaffected. | **(1)** Keep the key shape identical, or accept and record one cold run. **(2)** Re-token `-v2` → `-v3` **and** rewrite the `ci.yml:1342-1355` comment to state the new consumer set — otherwise the file documents a guarantee it no longer has. **(3)** none. |

**Nothing found in a category is stated explicitly above.** No category was left blank.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| `node` | prohibition guards, the new reader's `.test.mjs`, Playwright | ✓ | v24.9.0 (local); CI pins **20** via `setup-node` | — |
| `@playwright/test` | E-1..E-5, PW-01/02 | ✓ | **1.59.1** (lockfile-resolved) | — |
| `jq` | every `scripts/ci/*.sh` instrument, the new reader | ✓ | present (used by existing green guards) | — |
| `gh` CLI | `ci-run-metrics.sh`, `ci-demotion-observer.sh`, the new reader, ruleset verification | ✓ | present | Instruments accept `--from-json` for offline work |
| `mix` / Elixir / OTP | `test/sigra/planning/*` contracts | ✓ | per `.tool-versions` | — |
| **PostgreSQL (local)** | `mix test` — CLAUDE.md states there is no `:postgres` tag exclusion; a missing DB fails fast | **⚠ must be booted** | 15 (CI); local via `scripts/db/up.sh` | `scripts/db/up.sh` + `direnv allow` (or `source tmp/db.env`); falls back to `localhost:5432` |
| **`phx_new` 1.8.8 archive** | `test/sigra/install/golden_diff_test.exs` — a different local version produces spurious byte-diffs | **⚠ must match CI pin** | 1.8.8 | `mix archive.install --force hex phx_new 1.8.8` |
| GitHub Actions runner | every SC — all four are run-observed (D-33) | ✓ (remote) | `ubuntu-latest` | **None.** No SC in this phase can be closed locally. |
| Branch ruleset read access | SC-3 verification | ✓ (via `gh api`) | — | — |

**Missing dependencies with no fallback:** none blocking. **The binding constraint is not a missing tool — it is that SC-1..SC-4 are all only closable on real CI runs** (D-33). Plan for that latency.

**Runner CPU count matters and is not on record.** The folded todo warns against "oversubscribing a 2-core hosted runner"; `ubuntu-latest` for public repos has since been upgraded. `library_tests_shard` already prints `schedulers_online` to `$GITHUB_STEP_SUMMARY` (`ci.yml:~573`) — read it off a recent run rather than assuming. `[ASSUMED: current ubuntu-latest core count — verify from a real run's step summary before sizing shards.]`

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`. This section is required.

**Binding constraint (D-33, STATE.md, `230-VALIDATION.md:17-21`):** every success criterion in this phase is a claim about **what a run did**, not about what a file says. Static reads are acceptable only as *necessary-but-not-sufficient* pre-checks. `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` is the precedent failure.

### Test Framework

| Property | Value |
|---|---|
| Framework (library contracts) | ExUnit, Elixir ~> 1.18 |
| Framework (browser) | `@playwright/test` **1.59.1** (lockfile-pinned) |
| Framework (guards) | `node:test` (`scripts/ci/prohibitions/*.test.mjs`) + bash hermetic self-tests (`scripts/ci/*.test.sh`) |
| Config files | `test/test_helper.exs` · `test/example/priv/playwright/playwright.config.ts` · `.github/workflows/ci.yml` (`fast_checks`) |
| Quick run command | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs && mix test test/sigra/planning/` |
| Full suite command | `mix test` (requires Postgres and the `phx_new 1.8.8` archive — see § Environment Availability) |
| Estimated runtime | ~15s quick · ~8m full |

### Phase Requirements → Test Map

The layer matters as much as the test. **L1 = static pre-check (necessary, never sufficient). L2 = hermetic self-test. L3 = observed real run (the only layer that closes an SC).**

| Req / SC | Behavior | Layer | Automated command | Exists? |
|---|---|---|---|---|
| PW-01 / SC-1 | `beforeEach` no longer calls `registerUser()` | L1 | `grep -c 'registerUser' test/example/priv/playwright/tests/admin-design.spec.ts` inside a new contract test | ❌ Wave 0 |
| PW-01 / SC-1 | The four `admin-design.spec.ts` text contracts still hold (D-10) | L1 | `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs` | ✅ exists |
| PW-01 / SC-1 | axe signal not reduced | L1 | `node --test scripts/ci/prohibitions/p02-*.test.mjs` | ✅ exists |
| PW-01 / SC-1 | Setup project is wired into exactly the three design projects and excluded from `chromium`/`mobile` | L1 | new ExUnit or node contract over `playwright.config.ts` | ❌ Wave 0 |
| PW-01 / SC-1 | **The design-gallery step's duration fell, at an identical passing assertion and snapshot count** | **L3** | new step-level reader vs. `230-EVIDENCE.md:189-192` baseline (`39 passed (3.9m)`, run `30412458437`) | ❌ Wave 0 (the reader) |
| PW-01 / SC-1 | Executed test count unchanged at 39 (PR) / 84 (non-PR) / 123 (recapture) | **L3** | `N passed` from the `list` reporter **and** `stats.expected` from the `json` reporter | ❌ Wave 0 (json reporter) |
| PW-01 | Step-level reader is correct and fail-closed | L2 | new `scripts/ci/<reader>.test.sh` with a PATH-shadowed `gh` stub | ❌ Wave 0 |
| PW-02 / SC-2 | **A multi-worker or matrix-sharded run passes at `--retries=0` with no cross-spec interference** | **L3** | `npx playwright test … --retries=0` on the sharded lane, on a real run | ❌ Wave 0 |
| PW-02 / SC-2 | No shard leg executed zero tests | L3 (in-run) | the emptiness assertion (§ Code Examples) — fires per invocation, permanently | ❌ Wave 0 |
| PW-02 / SC-3 | `Example Playwright smoke (full lifecycle)` is byte-identical | L1 | `grep -c` in `phase_146_release_validation_test.exs` idiom + `docs-only-receipt.sh` / `_lib.mjs` constants | ✅ partial (`p10` display_name check, `_lib.mjs:193-200`) |
| PW-02 / SC-3 | **Branch protection still resolves the context on a real PR** | **L3** | `gh pr checks <n>` showing the bare name as required, plus `gh api …/rulesets/14941512` before/after | ❌ Wave 0 |
| PW-02 / SC-3 | Aggregator fails when a shard fails | **L3** | a deliberate red-probe leg (the `nightly_probe` / `force_rot_probe` precedent, `ci.yml:2687`; Phase 231 SC-3 used exactly this and it is what made GATE-03 credible) | ❌ Wave 0 |
| PW-02 | Every runner job has exactly one in-range `timeout-minutes` | L1 | `node --test scripts/ci/prohibitions/p09-*.test.mjs` + `mix test …phase_230_ci_timeouts_test.exs` | ✅ exists |
| PW-02 | Manifest ↔ ci.yml ↔ MAINTAINING.md parity | L1 | `node --test scripts/ci/prohibitions/p10-*.test.mjs` | ✅ exists |
| PW-02 | `ci-gate.needs` ↔ nine-lane list parity | L2 | `bash scripts/ci/honest-skip-verdict.test.sh` | ✅ exists |
| PW-02 | The demoted step still executes on a non-PR run **after** the split | **L3** | `bash scripts/ci/ci-demotion-observer.sh --run <id> --format table` (runs automatically post-merge from `ci-observe.yml`) | ✅ exists (must stay resolvable — see § the manifest/observer conflict) |
| PW-03 / SC-4 | Exactly one prelude definition | L1 | new contract: `.github/actions/boot-example-app/action.yml` exists **and** no calling job declares a duplicate `mix phx.server` / `seeds.exs` / `deps.get` block | ❌ Wave 0 |
| PW-03 / SC-4 | Pages publisher still seeds before boot | L1 | rewritten `p15` following the `uses:` indirection | ❌ Wave 0 (rewrite) |
| PW-03 / SC-4 | Browser-cache key still discoverable | L1 | `bash scripts/ci/playwright-cache-key-guard.sh` | ✅ exists (may need `--workflow`) |
| PW-03 / SC-4 | **Every one of those jobs still boots successfully** | **L3** | a full non-PR run (`workflow_dispatch` on the phase branch) with all six booting jobs green | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` + `mix test test/sigra/planning/` (~15s)
- **Per wave merge:** the full local guard sweep in § Code Examples (~9m with Postgres)
- **Per PW-01 / PW-02 landing:** one observed **PR** run + one observed **`workflow_dispatch`** run on the phase branch, each captured into a ledger slot
- **Phase gate:** all L3 slots captured with run IDs before `/gsd-verify-work`

### The Observed-Run Evidence Contract

232 needs its own `232-EVIDENCE.md` in the `_lib.mjs` slot format (`^## (BEFORE|AFTER)-[A-Z0-9-]+$`, `Status: captured (run <id>)` / `pending (<obligation>)`, ≥1 fenced block naming `ci-run-metrics.sh` or `gh`, Status run id repeated ≥2× in the body). D-31's ordering implies at minimum:

| Slot | What it is | Closable when |
|---|---|---|
| `BEFORE-STEPS` | Per-step durations + executed counts for all six seams, from a pre-change PR run, via the new reader | Pre-PW-01 (**and it gates the PW-02 shard-axis choice**) |
| `AFTER-PW01-PR` | Same reader, same run event, post-PW-01 | After PW-01 lands |
| `AFTER-PW01-NONPR` | `workflow_dispatch` — the non-PR gallery and recapture lanes, where PW-01's larger savings land | After PW-01 lands |
| `AFTER-PW03-NONPR` | A full non-PR run proving all six booting jobs still boot (SC-4) | After PW-03 lands |
| `AFTER-PW02-PR` | Sharded lane at `--retries=0`, per-leg executed counts, wall clock (SC-2, and FAST-01's number) | After PW-02 lands |
| `AFTER-PW02-CONTEXT` | `gh pr checks` + ruleset read showing the bare required context resolving (SC-3) | On a real PR, post-PW-02 |
| `AFTER-PW02-REDPROBE` | A deliberately-failed shard leg showing the aggregator red (SC-3's other half) | Dispatch probe |
| `AFTER-PUSH` | Post-merge `ci-observe.yml` demotion receipt PASS | **Post-merge, by construction** |

### What Can Be Proven Locally vs. Only on CI

| Provable **locally** | Provable **only on a real run** |
|---|---|
| Every guard in § Guard Surface (all have hermetic self-tests or are pure file reads) | Any duration, any executed count, any wall-clock claim |
| Playwright config topology (`--list` shows project/dependency wiring) | Whether the sharded lane actually passes at `--retries=0` |
| The emptiness assertion's logic (reproduce E-2/E-3 in `/tmp`) | Whether a shard leg was empty **on CI** |
| Composite YAML validity (`actionlint`, if available) | Whether the composite boots the app in each of six jobs |
| That the five required-context strings are unchanged (`git grep`) | Whether GitHub **resolves** the required context on a PR |
| That the manifest parses and cross-checks | Whether `ci-demotion-observer.sh` **finds** the construct by API name |

### Wave 0 Gaps

- [ ] **Step-level duration reader** + its hermetic self-test, wired into `fast_checks` — blocks SC-1's measurement **and** PW-02's shard-axis choice
- [ ] **`json` reporter** added to `playwright.config.ts` reporters — enables D-14 counts and the D-19 emptiness assertion from one change
- [ ] **Shard-emptiness assertion** as a reusable step/script — covers both E-2 and E-3 triggers
- [ ] **`232-EVIDENCE.md`** seeded with all eight slots in `_lib.mjs` format, `pending (<obligation>)` where not yet captured
- [ ] **Phase-232 prohibition guards** for the ledger clauses (`p01`/`p03`/`p11`/`p12`/`p13` analogues) — the existing ones are 230-pinned (C-3)
- [ ] **`p15` rewrite** to follow the `uses:` indirection — must land *with* the composite, not after
- [ ] **`phase_230_design_gallery_split_test.exs` re-anchoring note** — three job-scoped tests, with the re-pointing recorded in-file
- [ ] **`p09` / `phase_230_ci_timeouts_test.exs` decision** on the 45-minute pin, recorded either way
- [ ] **Contract test for the setup-project wiring** (`playwright.config.ts` topology: three design projects have `dependencies` + `storageState`; `auth.setup.ts` is in both `testIgnore` arrays; no CI invocation carries `--no-deps`)
- [ ] **Contract test for SC-4** ("exactly one definition"): the action exists and no calling job re-declares the prelude steps

---

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json`, so this section is included. The phase touches no application authentication logic; the surface is **CI supply chain and credential handling**.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard control in this phase |
|---|---|---|
| V2 Authentication | **Indirectly** | The setup project performs a real login against the example app's `/users/log_in`. It must use the **existing** `loginDemoAdmin` helper (D-02), not a bypass, not a forged cookie, not a direct session insert. A login bypass here would silently invalidate every design-lane assertion about authenticated rendering. |
| V3 Session Management | **Indirectly** | `storageState` persists a real Sigra session cookie to disk. It must be written under the already-gitignored `.playwright/` (D-03) and must never be uploaded in an artifact bundle. **Check:** the failure-diagnostics upload (`ci.yml:1673-1700`) uploads `test-results/` — verify `.playwright/` is not under it and is not swept into any new artifact path. |
| V4 Access Control | No | No policy change. `sigra_admin_policy.ex:19-24` already grants the seeded admin persona `platform_admin?` by email match; PW-01 uses that existing grant. |
| V5 Input Validation | No | No new user input surface. |
| V6 Cryptography | No | No crypto change. The persona password is a seeded, public-by-design demo credential (`personas.ex:12`), not a secret, and is already committed in `helpers/adminFlows.ts:25`. |
| V14 Configuration | **Yes** | Composite actions, action pinning, cache poisoning, and required-check integrity — see below. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard mitigation | Status in this phase |
|---|---|---|---|
| Unpinned third-party action | Tampering / Elevation | SHA-pin with a trailing version comment | Already done throughout `ci.yml`. **The composite must carry the same SHA pins**, not floating tags — moving four `uses:` steps is the exact moment a pin gets dropped. `p`-guard coverage: none today; DX-02 (Phase 234) owns the general case. |
| Cache poisoning across jobs | Tampering | Scope cache keys so a job cannot restore an artifact it did not earn | This is precisely the Phase 231 GATE-04 bug (`ci.yml:1333-1355`). D-27 + C-4: **browser cache stays caller-owned**, and PW-02 must re-token the key and rewrite the comment (§ Runtime State Inventory, category 5). |
| Required-check bypass via renamed/skipped context | Spoofing / Repudiation | Byte-identical `name:`; `if: always()` on aggregators; `honest-skip-verdict.sh` | SC-3 + D-22 + D-23. A skipped required check reports **success** — this is the highest-severity failure mode available in this phase, and it is a *merge-integrity* failure, not a test failure. |
| Secret exfiltration through a composite | Information Disclosure | Composites have **no `secrets:` block** (D-28); they inherit only what the caller passes | The prelude needs no secrets. **Do not** add `GH_TOKEN` or any `secrets.*` to the composite's inputs. |
| Credential leakage into logs/artifacts | Information Disclosure | Instruments never echo secrets; `gh` invoked bare via PATH | Existing convention across `scripts/ci/*.sh`; the new reader must follow it (§ Measurement Instrument, non-negotiable 5). |
| `pull_request_target` / fork-PR privilege | Elevation | Not used | `ci.yml` triggers on `pull_request`, not `pull_request_target`. **Do not change this.** The composite is a *local* action (`./.github/actions/…`), so it is checked out from the PR head — which is safe under `pull_request` and would not be under `pull_request_target`. |

---

## Project Constraints (from CLAUDE.md)

Actionable directives extracted from `./CLAUDE.md`. Treat with the same authority as locked decisions.

| Directive | Bearing on this phase |
|---|---|
| **GSD workflow enforcement:** do not make direct repo edits outside a GSD workflow. | All Phase 232 edits go through `/gsd-execute-phase`. |
| **Testing:** comprehensive spec coverage — happy path, main error cases, boundary conditions; AAA style, flat, self-contained. | Applies to the new reader's self-test and the new contract tests. The existing guards' "negative control" idiom (`p15:141-176`, `honest-skip-verdict.test.sh`) is the local expression of "main error cases" — a guard with only positive assertions is not falsifiable. |
| **`mix test` requires a live Postgres** (`postgres`/`postgres`, DB `sigra_test`); no `:postgres` tag exclusion. Boot via `scripts/db/up.sh` + `direnv allow`. | Any local `mix test` in this phase needs it. Never "fix" a failure by skipping. |
| **Install golden tests require `phx_new` 1.8.8** locally to match the CI pin. | `mix test` will show spurious `golden_diff_test` failures without it. Install before treating a failure as a regression. |
| **Admin UI direction / `sg-*` design system / brand assets.** | **Not touched.** PW-01 changes *who is logged in* for the design gallery, not what it renders — `assertBoardScreenshot` is element-scoped to `#<boardId>` (`admin-design.spec.ts:108`), so the authenticated identity cannot leak into a baseline. **No snapshot recapture is expected.** If any board PNG diffs after PW-01, that is a signal the change reached further than intended — investigate, do not recapture. |
| **Keep browser tests deterministic.** | Directly reinforces D-17 (`--retries=0`) and the D-15 ban on `continue-on-error` as flake mitigation. |
| **Minimal transitive deps; copy-paste over deps when code is small and stable.** | Supports building the step-level reader in-repo rather than adding a dependency. |
| **Security: OWASP standards throughout.** | § Security Domain. |

---

## State of the Art

| Old approach | Current approach | When changed | Impact here |
|---|---|---|---|
| `globalSetup` for shared auth | Setup **project** + `dependencies:` + `use.storageState` | Playwright 1.31 (project dependencies); stable and unchanged through 1.59 | D-01's mechanism; the CONTEXT records microsoft/playwright#28296 and #36120 as evidence the filtering semantics are unchanged 1.40→1.59 |
| One monolithic browser job | Matrix shard + name-preserving aggregator | Adopted in this repo by Phase 195/230 for `library_tests` | Pattern 3 — a shipped, in-repo precedent, not an external one |
| Prose-only CI documentation | `.github/ci-skip-manifest.tsv` as data, with `MAINTAINING.md` as a *renderer* | Phase 230 (D-23) | Any demotion this phase makes must be data, then prose, in one commit (D-32) |
| Human UAT for "did the demoted work run?" | `ci-observe.yml` + `ci-demotion-observer.sh` on `workflow_run: [completed]` | Phase 230 closeout | The AFTER-PUSH slot is now automatic and permanent — but it will also **judge this phase's own merge commit**, so a broken manifest row shows up post-merge |

**Deprecated / superseded in this repo:**
- `ROADMAP.md:180`'s `admin-design.spec.ts:250-255` citation → now `:273-278` (D-09)
- `ci.yml:2008-2009` and `:2316-2317` "verbatim clone of …" line ranges → both stale (Pitfall 10)
- `p15`'s header claim that four ci.yml jobs seed at `:1288/:1950/:2258/:2506` → line numbers stale and the set wrongly excludes/includes (C-5)
- CONTEXT.md `<canonical_refs>` `specs/` paths → `tests/` (C-1)

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| **A1** | The exact CLI/config spelling for the Playwright `json` reporter's output path (`--output-file` vs `PLAYWRIGHT_JSON_OUTPUT_NAME` vs reporter `outputFile`). `stats.expected` itself is VERIFIED. | Code Examples, Wave 0 | Low — the emptiness assertion fails loudly at authoring time; verify with `npx playwright test --help` before writing the plan. |
| **A2** | `ubuntu-latest` runner core count for this public repo. | Environment Availability, Sharding | Medium — an over-sized shard matrix wastes runner-minutes without wall-clock gain. Read `schedulers_online` from a recent `library_tests_shard` step summary. |
| **A3** | PW-01's ~4.5s-per-test registration cost, and therefore the ~175s PR saving. Inherited from D-13; not independently re-derived here. | Summary, PW-01 economics | Medium — if the real per-test cost is lower, PW-01's contribution to FAST-01 shrinks and PW-02 must carry more. The BEFORE-STEPS slot resolves it with measurement. |
| **A4** | The design gallery's `admin_checkpoints`-adjacent seams have durations that make a by-seam split roughly balanceable. **Explicitly unmeasured** — this is the gap that makes the reader a Wave-0 blocker. | Sharding Mechanics | **High** — an unbalanced split produces the TEST-02 failure mode (one leg idling) and may not reach FAST-01's 12m at all. |
| **A5** | Composite-action mechanics D-28/D-29 (shell required, string inputs, `$GITHUB_ENV` leakage, no `continue-on-error`, action-scoped ids, `cache-hit` empty-string on miss, one-level cache nesting). Verified during discuss, not re-verified here. | Composite Action Shape | Low-medium — each is individually testable on a throwaway workflow; `actions/runner#2030` is the cited source for the nesting limit. |
| **A6** | `storageState` engine-agnosticism across Chromium→WebKit. Verified during discuss via `types.d.ts` + docs; not re-verified. Sigra's non-enforcement of `user_agent` (`lib/sigra/session_stores/ecto.ex:123`) was not re-read in this session. | Pattern 1 | Medium — if a session were UA-bound, the `admin-design-mobile` project would fail wholesale. Fails loudly and immediately, so it is self-diagnosing. |
| **A7** | Branch ruleset 14941512 is still `enforcement: active` with the five contexts as documented in `MAINTAINING.md:102-113`. Not re-queried in this session (needs network). | SC-3, Runtime State Inventory | Medium — SC-3 is a merge-integrity criterion. Re-query before and after with the command at `MAINTAINING.md:116`. |
| **A8** | `actionlint` availability for local composite validation. | Validation Architecture | Low — a nice-to-have; the L3 run is the real gate. |

---

## Open Questions

1. **The manifest / observer name conflict for a matrix parent** (§ Sharding Mechanics)
   - *What we know:* `p10` needs the literal `${{ matrix.seam }}` template; `ci-demotion-observer.sh` needs the API-interpolated name. One cell, two incompatible requirements. Both fail closed.
   - *What's unclear:* which of the three resolutions the maintainer prefers — keep the demoted step on a non-matrix job (a), teach the observer prefix-matching (b), or normalize interpolation out in `p10` (c).
   - *Recommendation:* prefer **(a)** — it changes no live instrument and preserves both guards at full strength. Surface this to the user at planning time; it constrains the shard axis.

2. **`p09`'s 45-minute pin on a thin aggregator** (Pitfall 5)
   - *What we know:* `p09:74-88` pins `example_playwright_smoke: 45` and its own message forbids changing it without a fresh measurement.
   - *What's unclear:* whether to keep 45 (harmless, absurd) or re-pin to a measured aggregator value (which requires the AFTER run to exist first — a chicken-and-egg with the guard).
   - *Recommendation:* keep 45 through the phase with an explicit comment; re-pin in Phase 235 alongside every other post-steady-state tightening, which is what `p09`'s message already says ("tightening belongs in Phase 235").

3. **Does `example_unit_smoke` belong in the composite?** (§ Composite Action Shape)
   - *What we know:* SC-4 says "the jobs **that boot the app**". `example_unit_smoke` does not boot, runs MIX_ENV=test, and uses a different cache key shape. Including it adds three input axes.
   - *What's unclear:* whether the maintainer reads SC-4's "~6 jobs" as including it.
   - *Recommendation:* exclude it, record the exclusion against SC-4's literal wording, and note it in the SC restatement if one is being written anyway (D-08).

4. **Should the pages workflow's divergent cache key be normalized?** (§ Composite Action Shape)
   - *What we know:* `playwright-github-pages.yml:63-70` uses `-example-dev-<hash>` with no otp/elixir tokens and **no `restore-keys`** — a shape no ci.yml job uses, with no recorded rationale.
   - *What's unclear:* whether the divergence is deliberate.
   - *Recommendation:* normalize as part of PW-03 (it is exactly the "defined once" the requirement asks for), but call it out as a behavior change with its own line in the summary — a cache-key change orphans warm entries.

5. **Where does the browser-cache `restore-keys` prefix argument stand after a shard split?** (§ Runtime State Inventory)
   - *What we know:* `ci.yml:1348-1355` argues the bare-prefix `restore-keys` is safe because "its ONLY consumer is this job". A shard split makes that false.
   - *What's unclear:* whether the safety argument survives with N leg-consumers that all install the same browser set.
   - *Recommendation:* it does survive *if* every leg installs `chromium webkit` on both cache branches — but the comment states a premise that will no longer hold, so **re-token `-v2` → `-v3` and rewrite the comment in the same commit**. A file that documents a guarantee it no longer has is the failure class this milestone exists to remove.

---

## Sources

### Primary (HIGH confidence — re-derived by tool this session)

- `test/example/priv/playwright/playwright.config.ts` — full read (230 lines) — project topology, `workers`/`fullyParallel`/`retries`, `testIgnore` arrays
- `test/example/priv/playwright/tests/admin-design.spec.ts` — heads/regions + full `test(` enumeration (768 lines) — `beforeEach`, board loop, axe test, 41-tests-per-project arithmetic
- `test/example/priv/playwright/helpers/adminFlows.ts:1-120` — `loginDemoUser` / `loginDemoAdmin`, no-MFA comment
- `.github/workflows/ci.yml` — targeted reads of all seven prelude sites, the full `example_playwright_smoke` job, the `library_tests_shard`/`library_tests` template, `ci-gate.needs`, `fast_checks` guard invocations
- `.github/workflows/playwright-github-pages.yml:1-140` — the seventh prelude site
- `.github/ci-skip-manifest.tsv` — full read, all 15 data rows + column semantics
- `scripts/ci/prohibitions/_lib.mjs` — full read (subject indirection, `jobBlocks`, `stripYamlComments`, `REQUIRED_CONTEXTS`, `parseEvidenceSlots`, `SLOT_HEADING_RE`)
- `scripts/ci/prohibitions/p01, p02, p03, p06, p09, p10, p11, p12, p15` — full reads; `p04, p05, p07, p08, p13, p14, p16` — subject-line reads
- `scripts/ci/ci-run-metrics.sh`, `ci-demotion-observer.sh`, `honest-skip-verdict.sh`, `playwright-cache-key-guard.sh`, `docs-only-receipt.sh`, `admin-artifact-bundle-contract.sh` — targeted reads
- `test/sigra/planning/phase_230_design_gallery_split_test.exs` — full read (all nine tests)
- `test/example/config/dev.exs:1-20`, `config/config.exs:30-45`, `lib/example/demo/personas.ex:50-80`, `lib/example/sigra_admin_policy.ex:1-35`
- `.planning/ROADMAP.md`, `REQUIREMENTS.md:39-43`, `STATE.md:1-40`, `config.json`, `MAINTAINING.md:95-145,265-285`
- `.planning/phases/230-…/230-EVIDENCE.md:1-70,660-680`, `230-VALIDATION.md:1-60`
- `.planning/todos/pending/2026-06-20-playwright-parallelization-per-shard-db.md`
- **Live experiment:** Playwright 1.59.1, `/tmp/pwshard`, six invocations — findings E-1 through E-5

### Secondary (MEDIUM confidence — inherited from `232-CONTEXT.md`'s discuss-phase research, not re-verified this session)

- Playwright setup-project filtering semantics vs. `--project`/`--grep`/`--shard`/positional args (D-01) — *partially re-verified here via E-1/E-3*
- `storageState` engine-agnosticism, `playwright-core/types/types.d.ts` ~L9417 (D-03)
- Composite-action mechanics (D-28) and `actions/runner#2030` cache-nesting limitation (D-29)
- microsoft/playwright#28296, #36120 — behavior unchanged 1.40→1.59
- `lib/sigra/session_stores/ecto.ex:123` — `user_agent` recorded, not enforced

### Tertiary (LOW confidence — assumption, flagged in the Assumptions Log)

- Per-test registration cost (~4.5s) and the derived ~175s PR saving (A3)
- `ubuntu-latest` core count (A2)
- Playwright `json` reporter output-path flag spelling (A1)
- Ruleset 14941512 current state (A7)

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| Verified anchors | **HIGH** | Every line/symbol re-derived by grep at HEAD `a1076264` this session |
| Guard & prohibition surface | **HIGH** | All eleven guards read in full or to their subject/assertion boundary; three ⛔ breakages traced to specific regexes |
| Sharding mechanics (behavior) | **HIGH** | E-1..E-5 run live against the pinned 1.59.1 install; E-3 is a new finding not in CONTEXT.md |
| Sharding mechanics (sizing) | **LOW** | Per-seam durations do not exist anywhere (A4) — this is the phase's real unknown |
| Composite call-site variance | **HIGH** | All seven sites read; the matrix is derived from the file, and it corrects D-27 (C-4) and D-26 (C-5) |
| Measurement instrument spec | **HIGH** | Both existing instruments read in full; the API's lack of step `id:` confirmed by how every consumer resolves by name |
| Economics / savings estimates | **MEDIUM** | D-12's baselines are on record and reconcile exactly with the verified 39/84/123 arithmetic; the per-test cost (A3) is inherited |
| Security domain | **MEDIUM** | Threat patterns are standard and repo precedent is strong; no external ASVS lookup performed this session |

**Research date:** 2026-07-30
**Valid until:** 2026-08-13 (14 days). Short window: `ci.yml` is 2697 lines and under active change across phases 230–235, and every anchor in this document is a line number in it. **Re-grep every anchor before writing plans if more than a week has passed or if any commit has touched `.github/workflows/ci.yml`.**
</content>
</invoke>
