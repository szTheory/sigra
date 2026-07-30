# Phase 232 Context: Playwright Economics — Authenticate Once, Then Shard

<domain>

Phase 232 attacks the two remaining structural costs on the PR critical path after
Phase 230 moved the design-gallery snapshot mass off it:

1. **PW-01** — the design specs re-register a fresh user before *every* test
   (`beforeEach` → `registerUser()`), paying a full LiveView registration over
   dev-mode longpoll plus an Argon2id hash per test.
2. **PW-02** — the Playwright suite is pinned to `workers: 1` /
   `fullyParallel: false` because DB state is shared across specs, so the
   residual seams run one after another instead of at the same time.
3. **PW-03** — the example-app boot prelude is duplicated verbatim across
   **seven** call sites (ROADMAP says "~6"; Phase 231's 231-10/D-17 added the
   seventh in `playwright-github-pages.yml`).

Post-230 measured baseline: PR critical path is `example_playwright_smoke` at
**989s / 16m29s**, run wall 16m52s (`230-EVIDENCE.md:168,176-178`). The milestone
FAST-01 target is 12m, so PW-01 alone does not get there — hence PW-01 and PW-02
share a phase.

The phase is bounded by a hard proof-ordering rule from the ROADMAP: PW-01 must
land **and be measured** before PW-02 restructures anything, otherwise the two
wins are indistinguishable in the numbers. Retries and `continue-on-error` are
forbidden as flake mitigation (D-15, recorded in `playwright.config.ts`).

</domain>

<decisions>

### PW-01 — authenticate once

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

### PW-01 — measurement

- **D-11:** Phase 230's D-21 instrument does **not** satisfy SC-1. `scripts/ci/ci-run-metrics.sh:94-124` emits only `{name, conclusion, duration}` per **job** — the jq at `:103-106` never descends into `.steps[]`. SC-1 needs a **step**-level reader. Commit one before measuring (D-21 discipline), modelled on the existing step-level resolution in `scripts/ci/ci-demotion-observer.sh:150,161-165`, which is purpose-bound to the demotion observer and should not be repurposed in place.
- **D-12:** Baselines are already on record and must be cited, not re-derived: PR gallery step `39 passed (3.9m)` (`230-EVIDENCE.md:189-192`, run `30412458437`, job `90451525539`); non-PR snapshot `84 passed (7.2m)` (`:423-426`, job `90459154527`); ungrepped recapture `123 passed (12.1m)` (`:427-430`). `p01-committed-method-provenance.test.mjs` and `p12-run-id-provenance.test.mjs` guard this.
- **D-13:** Set the honest expectation up front: PW-01's **PR-side** saving is **~175s** (39 tests × ~4.5s), *not* SEED-005's −6/−7.5m — because Phase 230 already moved 84 of 123 design tests off the PR path. Non-PR lanes gain more (~378s off `design_gallery_snapshots`, ~553s off `admin_design_recapture`). PW-01 alone lands the critical path near **13.6m**, still above the 12m FAST-01 target.
- **D-14 (hard-fail):** `p03-no-green-on-empty-grep.test.mjs` — the AFTER evidence must record **executed test counts**, not just durations.

### PW-02 — parallelism

- **D-15:** Shape is **matrix-shard with a per-shard runner** — each shard gets its own `services.postgres` and its own `mix phx.server` — **not** `workers > 1` against one shared boot. `playwright.config.ts:11-13` states verbatim that DB state is shared across specs; settings at `:53-54`.
- **D-16:** Every shard's app binds **port 4000**. `ci.yml:2553-2557` documents that `config.exs:39` bakes `System.get_env("PORT","4000")` as a `compile_env` key, so a non-4000 port trips `validate_compile_env`. DB isolation needs **no code change** — `config/dev.exs:4-12` already reads `PGDATABASE`/`PGHOST`/`PGPORT` from env.
- **D-17:** SC-2 must be proven with `--retries=0` **passed on the CLI**, because `playwright.config.ts:55` sets `retries: process.env.CI ? 1 : 0`.
- **D-18:** The five documented collision sources must each be addressed or explicitly shown moot by per-shard DB: (1) one app / one dev DB (`ci.yml:1376-1388`); (2) shared seeded rows mutated by siblings — `admin-flow-platform-admin.spec.ts:269-320` revokes alice's sessions, `admin-flow-support-investigator.spec.ts:70` impersonates, `admin-coherence-sweep.spec.ts:87-109` asserts on `grace@`/`pat@`; (3) index ordering — `admin-design.spec.ts:448-450` documents `/admin/users` ordering `inserted_at DESC`; (4) 23 bare `Date.now()` across 15 spec files plus the module-level `registrationSequence` at `admin-design.spec.ts:52` which is per-worker-process; (5) `test-results/` wiped per invocation (`ci.yml:1458-1463`, already realized).
- **D-19 (hard-fail):** Add a **shard-emptiness assertion**. Verified hazard: Playwright shards by *file*, so with fewer files than shards a shard runs **zero tests, skips setup, and exits 0 silently** — a green that proves nothing.
- **D-20 (hard-fail):** The seam-outcome aggregator loop at `ci.yml:1584-1589` hard-codes six step ids. PW-02 must carry that contract forward, or a failing seam reports green — the v1.42 failure mode, called out at `ci.yml:1569-1573`.

### PW-02 — required-check name stability (SC-3)

- **D-21:** Reuse the shipped aggregator template verbatim: rename the working job to `example_playwright_shard` with `name: Example Playwright smoke shard ${{ matrix.seam }}`, plus a thin job that keeps the id `example_playwright_smoke` and a **byte-identical** `name: Example Playwright smoke (full lifecycle)`. This mirrors `library_tests_shard` → `library_tests` at `ci.yml:497-622`; `ci.yml:594-599` documents the failure mode. Interpolating the matrix value into `name:` is what prevents Actions appending ` (value)` to a static matrix job name.
- **D-22 (hard-fail):** The aggregator **must** use `if: always()`. A job whose `needs` dependency failed is *skipped*, and a skipped required check reports success — without `always()` a failing shard silently lets the PR merge. `ci.yml:594-622` already uses `if: always()` + `[[ "$SHARDS" != "success" ]] && exit 1`; copy that, do not re-derive it.
- **D-23 (hard-fail):** Never add the shard job to `ci-gate.needs`. `scripts/ci/honest-skip-verdict.sh:145-156` holds a fixed nine-lane list cross-checked bidirectionally against `ci-gate.needs` (`ci.yml:1849-1859`), and its extractor requires bare `      - id` lines with no trailing comments (`ci.yml:1846-1848`).
- **D-24 (hard-fail):** Four consumers key on the exact name/id and must stay consistent in **one commit**: `honest-skip-verdict.sh:145-156`; `ci-demotion-observer.sh:150` (resolves `design_gallery_snapshots` by parent job *display name*); `.github/ci-skip-manifest.tsv:70,:75` (pins parent_job_id/display_name, asserted by `p10-no-undocumented-demotion.test.mjs`); and the hard-coded five names in `scripts/ci/docs-only-receipt.sh:42-48` + `scripts/ci/prohibitions/_lib.mjs:196-203`. `MAINTAINING.md:102-113`: "Do not rename or remove the five job `name:` strings above."

### PW-03 — single boot prelude

- **D-25:** Mechanism is a **local composite action** at `.github/actions/boot-example-app/action.yml` with inputs (`seeds`, `browsers`, `port`, `warm-paths`). A `scripts/ci/*.sh` cannot express it — the duplicated block contains four `uses:` steps (`actions/checkout`, `erlef/setup-beam`, `actions/setup-node`, `actions/cache`). No `.github/actions/` directory exists yet.
- **D-26:** Seven call sites (not six): `example_unit_smoke` `ci.yml:742-775` (MIX_ENV=test, no boot, no node); `example_http_smoke` `:1180-1231` (boot, no seeds, no node/browsers); `example_playwright_smoke` `:1270-1408` (full + browser cache); `admin_design_recapture` `:2010-2089` (full, plain `install --with-deps`); `admin_checkpoint_recapture` `:2329-2379+` (full); `admin_eval_render` `:2570-2644` (full, **`PORT: 4011`**, warms only `/admin/_design`); `playwright-github-pages.yml:54-131` (full, p15-guarded). The comment at `ci.yml:2008-2009` calling itself a "verbatim clone of ci.yml:886–968" is **already stale** — the source is now at `:1270-1408`.
- **D-27 (hard-fail):** The composite **must not** unconditionally include an `actions/cache` step. `ci.yml:1333-1355` documents that `admin_eval_render` declares no cache step *as a deliberate structural guarantee*; folding caching into a shared composite "would destroy that guarantee and re-open the Phase 231 GATE-04 bug." Gate caching behind an input, or keep the composite install-only.
- **D-28:** Composite mechanics, verified: `uses:` steps are supported; `if:` on steps is supported; `shell:` is **required** on every run step; inputs are **all strings** (booleans arrive as `'true'`/`'false'`); `$GITHUB_ENV` **leaks outward** to the caller's later steps; `continue-on-error` on composite steps is **not supported**; there is no `secrets:` block; `${{ github.action_path }}` works.
- **D-29:** `actions/cache` post-save works correctly **one level deep only** (actions/runner#2030 — post steps in *nested* composites get the wrong context). Never nest a cache-bearing composite. Composite step ids are action-scoped: the caller **cannot** read `steps.<internal-id>.outputs.cache-hit`; the action must re-export via `outputs.<id>.value`. On a total miss `cache-hit` is the **empty string, not `'false'`** — always compare `!= 'true'` (Sigra already does).
- **D-30 (hard-fail):** Three guards parse the affected YAML literally and will red on a careless refactor: `p15-pages-publisher-seeds-before-boot.test.mjs` parses the literal step list of `playwright-github-pages.yml` (`stepList()` matches `^ {6}- name:`); `scripts/ci/playwright-cache-key-guard.sh:59-62` greps `ci.yml` for `playwright-chromium-webkit-<x.y.z>-vN` and fails closed; `p09-timeouts-not-truncating.test.mjs` requires one `timeout-minutes` per `runs-on:` job; `p10`'s step-id resolution matches `^\s+id: <id>` in `ci.yml`.

### Ordering

- **D-31 (hard-fail):** Execution order is **PW-01 land → PW-01 measured on a real PR run → PW-03 → PW-02 → PW-02 measured**. PW-03 precedes PW-02 because PW-02 adds N new prelude call sites; factoring after sharding means factoring N copies instead of one.
- **D-32 (hard-fail):** Any same-commit change touching the demotion surface must edit `.github/ci-skip-manifest.tsv`, `MAINTAINING.md:137`, and `MAINTAINING.md:274` together (or `honest-skip-parity.test.mjs` / `p10` red).
- **D-33:** Verification philosophy from STATE.md binds this phase: success criteria are proven by running CI and reading measured numbers, never by reading YAML. A `skipped` job proves nothing.

</decisions>

<canonical_refs>

**Phase / milestone**
- `.planning/ROADMAP.md` (lines 173–186 — phase 232 definition; 96–99 — SC-restatement precedent; 212 — Phase 234 DX-04)
- `.planning/REQUIREMENTS.md` (lines 41–43 — PW-01/PW-02/PW-03)
- `.planning/STATE.md` (milestone baseline + verification philosophy)
- `.planning/METHODOLOGY.md`
- `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md`
- `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` (lines 168, 176–178, 189–192, 423–430)
- `.planning/phases/231-gate-honesty-nightly-revival/231-CONTEXT.md`

**Playwright**
- `test/example/priv/playwright/playwright.config.ts` (11–13, 53–55, 94, 103–112)
- `test/example/priv/playwright/specs/admin-design.spec.ts` (52, 108–109, 273–278, 286–290, 448–450)
- `test/example/priv/playwright/helpers/adminFlows.ts` (57–63, 65–91)
- `test/example/priv/playwright/specs/admin-flow-platform-admin.spec.ts` (269–320)
- `test/example/priv/playwright/specs/admin-flow-support-investigator.spec.ts` (70)
- `test/example/priv/playwright/specs/admin-coherence-sweep.spec.ts` (87–109)
- `test/example/priv/playwright/.gitignore`

**Example app**
- `test/example/lib/example/demo/personas.ex` (58–71)
- `test/example/lib/example/sigra_admin_policy.ex` (19–24)
- `test/example/config/config.exs` (39 — PORT compile_env)
- `test/example/config/dev.exs` (4–12 — PG* env)
- `lib/sigra/session_stores/ecto.ex` (123 — user_agent recorded, not enforced)

**CI**
- `.github/workflows/ci.yml` (497–622, 742–775, 1180–1231, 1270–1408, 1314–1322, 1333–1355, 1376–1388, 1458–1463, 1477–1531, 1569–1589, 1846–1859, 2008–2089, 2329–2379, 2553–2557, 2570–2644)
- `.github/workflows/playwright-github-pages.yml` (54–131, 96–103)
- `.github/ci-skip-manifest.tsv` (70, 75)
- `MAINTAINING.md` (102–113, 137, 274)
- `scripts/ci/ci-run-metrics.sh` (94–124)
- `scripts/ci/ci-demotion-observer.sh` (150, 161–165)
- `scripts/ci/honest-skip-verdict.sh` (145–156)
- `scripts/ci/docs-only-receipt.sh` (42–48)
- `scripts/ci/playwright-cache-key-guard.sh` (59–62)
- `scripts/ci/prohibitions/_lib.mjs` (196–203)
- `scripts/ci/prohibitions/p01, p02, p03, p09, p10, p11, p12, p15, honest-skip-parity`
- `test/sigra/planning/phase_230_design_gallery_split_test.exs` (65–147)

**Todo folded in**
- `.planning/todos/2026-06-20-playwright-parallelization-per-shard-db.md`

</canonical_refs>

<code_context>

**Already done by Phases 230/231 — do not redo:**
- PW-01 is *partially enabled*: 28 board tests are tagged `@snapshot`
  (`admin-design.spec.ts:286-290`) and the CI step is split
  (`ci.yml:1477-1531`). The `beforeEach` still calls `registerUser()`
  (`admin-design.spec.ts:273-278`, call at `:275`).
- No `storageState`, `dependencies:`, or `globalSetup` exists anywhere in the
  repo today.
- PW-02 is not started; `workers: 1` / `fullyParallel: false` unchanged
  (`playwright.config.ts:53-54`).
- PW-03 is not started; Phase 231 (231-10, D-17) **added a seventh** prelude copy
  in `playwright-github-pages.yml:54-131`, locked behind `p15`.

**Snapshot safety:** `assertBoardScreenshot` captures
`page.locator('#' + boardId)` (`admin-design.spec.ts:108-109`) — element-scoped,
so switching the authenticated identity cannot leak a different header email into
baselines.

**Sharding caveats carried from research:**
- Setup cost is paid **once per shard**, not once per run.
- `--no-deps` is a footgun: it suppresses the setup project and yields
  unauthenticated runs.
- `sessionStorage` is not captured by storageState; `partitionKey`/CHIPS are not
  relevant at this origin.
- `needs.<matrix-job>.result` is `success` only if every leg succeeded,
  independent of `fail-fast: false`.
- Partial matrix re-runs do not cleanly re-evaluate the aggregator.
- Prefer `!cancelled()` over `always()` if a cancelled run should abort rather
  than fail — decide deliberately given the docs-only gating path.

</code_context>

<specifics>

- Playwright is pinned at **1.59.1**; the setup-project filtering behavior was
  verified empirically against that exact install (throwaway config in `/tmp`,
  repo untouched). Behavior is unchanged 1.40→1.59
  (microsoft/playwright#28296, #36120).
- Login path is a plain controller `POST /users/log_in` — not a LiveView flow —
  so the setup does not depend on longpoll timing.
- The persona password `DemoAdmin1!SecurePass` is a seeded demo credential in a
  local example app; it is not a secret.
- ROADMAP line citations for `admin-design.spec.ts` are stale (see D-09);
  planners should grep for the symbol, not the line.

</specifics>

<deferred>

**Folded in:** `2026-06-20-playwright-parallelization-per-shard-db.md` — this is
the direct PW-02 match and is in scope.

**Reviewed, not folded** (matched the todo scan but are Phase 230/231 subject
matter already handled, or explicitly out of scope for 232):
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
- Any `admin_eval_render` cost reduction — it is not on the PR critical path and
  its no-cache structure is a deliberate guarantee (D-27).
- Rewriting the 23 bare `Date.now()` uniqueness sites, if per-shard DB isolation
  makes them moot (D-18 item 4) — decide during PW-02, do not pre-commit.

</deferred>
