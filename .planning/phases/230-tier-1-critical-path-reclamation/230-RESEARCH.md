# Phase 230: Tier-1 Critical-Path Reclamation — Research

**Researched:** 2026-07-28
**Domain:** GitHub Actions workflow topology, Playwright test filtering/tagging, CI measurement tooling
**Confidence:** HIGH (every line anchor, duration, and job inventory below was read from HEAD `5db4f0fb` or fetched live from `gh` in this session)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

CONTEXT.md carries 24 owner-ratified decisions (D-01..D-24) gathered in assumptions mode on
2026-07-28. **They are locked inputs. Do not re-derive or re-litigate them.** This research does
not restate them; it supplies the implementation-level detail they leave open, verifies every
line anchor they cite, and flags the hazards they do not cover.

### Locked Decisions — verbatim pointers

| ID | One-line summary | Verified against HEAD? |
|----|------------------|------------------------|
| D-01 | Collapse per-board axe → one full-page axe test per design project; tag ~84 board tests `@snapshot` | ✅ verified (see §Verified Line Anchors) |
| D-02 | Tag via details-object form `test('title', { tag: '@snapshot' }, fn)` — Playwright v1.42+, repo pins 1.59.1 | ✅ lockfile 1.59.1 confirmed |
| D-03 | Use **exactly one** filtering mechanism — CLI `--grep-invert` **or** config `grepInvert`, never both | ✅ no grep/grepInvert in config today |
| D-04 | Demoted snapshots stay **inside** `example_playwright_smoke` as a second event-gated step | ✅ job name is a ruleset context |
| D-05 | New snapshot step's `id` MUST join the seam-outcome aggregator loop at `ci.yml:1234-1238` | ✅ anchor exact |
| D-06 | **Never** add `paths:`/`paths-ignore:` to the `ci.yml` trigger block | ✅ none present (`ci.yml:3-25`) |
| D-07 | One `changes` job with `outputs:`; five ruleset-required jobs consume it at **step** level | ✅ `install_golden_contract` pattern exact |
| D-08 | Non-required jobs may gate at **job** level | — |
| D-09 | Watch item: `example_unit_smoke` has no `needs:` today; adding one is a real DAG change | ✅ confirmed (`ci.yml:523-525`) |
| D-10 | Add exactly `if: github.event_name != 'pull_request'` at `ci.yml:2102-2110` | ✅ anchor exact; 7 house sites confirmed |
| D-11 | **Leave `continue-on-error: true` at `ci.yml:2110` alone** | ✅ anchor exact |
| D-12 | Top-level `concurrency:` — `group: ${{ github.workflow }}-${{ github.event.pull_request.number \|\| github.run_id }}`, `cancel-in-progress: true` | ✅ no concurrency in ci.yml today |
| D-13 | Emit a bare boolean, never a quoted-string ternary | — |
| D-14 | Triggers are `push: [main]` + `pull_request: [main]` — no same-SHA double trigger | ✅ verified `ci.yml:22-25` |
| D-15 | Honest expected FAST-06 win is **~15-25s, not 62s** | ✅ install step measured 61s live |
| D-16 | Cache key **must** encode the browser set | ✅ two distinct browser sets confirmed |
| D-17 | On a cache hit still run OS dep install; gate on `cache-hit != 'true'` | — |
| D-18 | Follow the house `actions/cache` shape at `ci.yml:1028-1036` | ✅ anchor exact |
| D-19 | `timeout-minutes` on all 21 jobs at ~2× observed with a floor | ✅ 21 jobs confirmed; durations re-measured live |
| D-20 | Set `example_playwright_smoke` generously (~45) | ✅ 28.5m observed, 41.7m historical max |
| D-21 | **Commit a measurement script before measuring anything** | ✅ no such script exists in repo |
| D-22 | This is NOT a pure-YAML change set — a spec file is in the manifest | ✅ confirmed |
| D-23 | Record the intended honest-skip set as a phase artifact | ✅ `ci-gate` counts `skipped` as pass (`ci.yml:1502`) |
| D-24 | Prove FAST-02 by the run's own executed-test count, not by reading YAML | — |

### Claude's Discretion (research recommendations in §Recommendations)

- Exact `timeout-minutes` integer per job → **§FAST-07: Complete Job Inventory** gives a full table.
- Shared `changes` job (D-07) vs inline in `example_unit_smoke` (D-09) → **recommend shared job with fail-open polarity**; rationale in §FAST-05.
- Naming of the `@snapshot` tag, axe test titles, measurement script path/flags → recommendations given.
- `--grep-invert` on the PR step vs `--grep` on the non-PR step → **recommend CLI on both steps, config untouched**; §Pitfall 1 is a decisive new argument.
- Commit/plan decomposition inside the phase (phase must not be split).

### Deferred Ideas (OUT OF SCOPE)

- `admin_design_recapture`'s 19.28m/push waste (`ci.yml:1693` dispatch-gated commit step) — no FAST-0x covers it.
- `generated_admin_playwright_smoke`'s stale `head_ref` condition (`ci.yml:1343`) — **GATE-02, Phase 231**.
- `storageState` / PW-01 — **Phase 232**.
- Removing `continue-on-error` from `admin_eval_render` — **GATE-04, Phase 231**.
- Per-board axe failure attribution (lost by D-01) — recoverable later via `AxeBuilder(...).include()`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FAST-02 | Design-gallery snapshot boards off the PR gate; run on push/nightly; axe still on every PR | §FAST-02 (exact test inventory, expected executed-test counts, CLI-flag mechanism, Pitfall 1 recapture-lane hazard) |
| FAST-03 | `admin_eval_render` no longer runs on pull requests | §FAST-03 (one-line edit, **SC-2 wording hazard: skipped ≠ absent**) |
| FAST-04 | Superseded PR runs cancelled; main + scheduled never cancelled | §FAST-04 (house placement precedent, verified trigger block, SC-3 proof recipe) |
| FAST-05 | Docs-only PR skips the full matrix; required checks still merge-eligible | §FAST-05 (**critical: `fast_checks` and `library_tests` read `.planning/` and `guides/` — must NOT be gated off**) |
| FAST-06 | Playwright browsers restored from cache | §FAST-06 (browser-set key, version-drift hazard + guard, post-step save cost) |
| FAST-07 | Every CI job carries an explicit `timeout-minutes` | §FAST-07 (complete 21-job table with live-measured durations and proposed integers) |
</phase_requirements>

## Summary

Every line anchor in CONTEXT.md was re-verified against HEAD `5db4f0fb` and **all of them are still
accurate**. No corrections needed. The phase's factual foundation is sound.

The research therefore concentrates on four things CONTEXT.md leaves open or does not cover:

1. **A complete, live-measured 21-job inventory** for FAST-07 — including three jobs CONTEXT.md's
   duration list omits (`passkeys_manual_fallback_smoke` 1.93m, `nightly_probe` 5s,
   `notify_release_lane_rot` never-observed) — with a proposed integer per job.
2. **Three hazards CONTEXT.md does not cover**, each of which would silently break the phase:
   - **SC-2 is literally unsatisfiable as worded.** A job whose `if:` evaluates false is **still
     present** in `gh run view --json jobs` with `conclusion: "skipped"` and ~0s duration. Verified
     live on PR run `30390832059`: `Nightly probe`, `Install matrix`, `Upgrade smoke`, and three
     others all appear as `skipped`. The satisfiable form of SC-2 is *"present with
     `conclusion == "skipped"` and duration ≈ 0s"*, not *"absent from the job list"*.
   - **Expressing the FAST-02 split as a per-project `grepInvert` in `playwright.config.ts` would
     silently kill baseline recapture.** `admin_design_recapture` (`ci.yml:1685`) and
     `scripts/ci/snapshot-recapture-gate.sh:83` both run the full spec with `--update-snapshots`
     and pass no grep — a config-level `grepInvert` would filter the board tests out of the
     recapture too, and the lane would report green having recaptured nothing. This is a decisive,
     independent argument for D-03's CLI-flag branch.
   - **`fast_checks` and `library_tests` are exactly the lanes a docs-only PR most needs.**
     `milestone-verification-gate.sh` walks `.planning/**`; `getting-started-contract.sh` link-checks
     `guides/introduction/getting-started.md`; and ~12 ExUnit files under `test/sigra/planning/` and
     `test/sigra/*_guides_*` read `.planning/` and `guides/` directly. Gating either off for a
     docs-only PR would turn FAST-05 into a coverage hole in the one dimension the PR actually changes.
3. **The baseline measurement method for D-21 is now reconstructed and reproduced.** Running
   `gh run list --workflow ci.yml --limit 40 --json event,createdAt,updatedAt,conclusion` and
   computing `updatedAt - createdAt` grouped by event reproduces the REQUIREMENTS.md table to
   within 0.1m (PR mean 29.4m vs 29.5m; PR max **41.7m exact**; push max **42.3m exact**; schedule
   0-pass exact). The measurement script has a proven shape to implement.
4. **A named, copyable in-repo template for every artifact this phase creates** —
   `scripts/ci/notify-failure-issue.{sh,test.sh}` is the closest analogue for a `gh`-calling guard
   with a hermetic PATH-stub self-test wired into `fast_checks`.

**Primary recommendation:** Implement FAST-02 with **CLI-only** grep flags (`--grep-invert '@snapshot'`
on the existing `design_gallery` step, `--grep '@snapshot'` on a new event-gated
`design_gallery_snapshots` step whose `id` joins the aggregator loop), leave `playwright.config.ts`
**untouched**, use a shared `changes` job with **fail-open** output polarity for FAST-05 while
exempting `fast_checks` and `library_tests` entirely, and restate SC-2 as *skipped-with-zero-duration*
before writing any verification step against it.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Event-based lane gating (FAST-03, FAST-05 job level) | GitHub Actions workflow (`ci.yml`) | — | `if:` expressions are the only place event context exists |
| Test selection within a lane (FAST-02) | CI invocation (`ci.yml` `run:` step) | Playwright spec file (tag declaration) | Tag lives in the spec; **selection stays in CI** so the recapture lane and local runs keep the full set |
| Run supersession (FAST-04) | GitHub Actions run scheduler (`concurrency:`) | — | Workflow-level only; no job or test can express this |
| Browser binary caching (FAST-06) | GitHub Actions cache (`actions/cache`) | Playwright CLI (`install-deps`) | Binaries are cacheable; `/usr/lib` system deps are not |
| Job time bounding (FAST-07) | GitHub Actions job (`timeout-minutes`) | — | Per-job scalar; no other tier |
| Change classification (FAST-05) | A single `changes` job (`git diff`) | Consumers via `needs.*.outputs` | Computing once avoids adding `fetch-depth: 0` + a `git fetch` to five jobs |
| Wall-clock measurement (SC-5, D-21) | `scripts/ci/` bash + `gh` CLI | `fast_checks` (self-test) | Repo convention: guards ship with hermetic self-tests |
| Docs/planning contract enforcement | `fast_checks` + `library_tests` | — | **These read the very files a docs-only PR changes — never gate them off** |

---

## Verified Line Anchors (HEAD `5db4f0fb`)

Every anchor CONTEXT.md cites was re-read. **All accurate; no corrections.**
`[VERIFIED: direct file read at HEAD 5db4f0fb]`

### `.github/workflows/ci.yml` (2254 lines)

| Anchor | Content at HEAD | Phase use |
|--------|-----------------|-----------|
| `3-25` | `on:` block — `workflow_dispatch` (with `force_fail_probe`, `recapture_branch` inputs), `schedule: '30 4 * * *'`, `push: branches: [main]`, `pull_request: branches: [main]`. **No `paths:`/`paths-ignore:` anywhere.** | D-06 confirmed; FAST-04 insertion region |
| `27-32` | `permissions: contents: read` (workflow default) | FAST-04 places `concurrency:` adjacent |
| `39-61` | `release_ref_guard` job | FAST-07 |
| `67-226` | `fast_checks` job — 40+ guard steps, ~24 of them `*.test.sh`/`*.test.mjs` self-tests | D-21 wiring point; **FAST-05 exemption** |
| `88-102` | `fast_checks` `detect` step (installer-path diff, PR-only) — the in-job precedent for path classification | FAST-05 alternative pattern |
| `121-122` | `Quality ledger monotonic guard` + `... self-test` — the exact "guard + self-test adjacency" convention | D-21 template |
| `228-308` | `install_golden_contract` — always-run job, `detect` step at `246-261`, `if: steps.detect.outputs.run == 'true'` on 8 heavy steps; requires `fetch-depth: 0` (`244-245`) and a `git fetch origin <base> --depth=1` (`256`) | **FAST-05 canonical pattern (D-07)** |
| `314-416` | `library_tests_shard` — 2-leg matrix, `fail-fast: false` | FAST-07 |
| `417-435` | `library_tests` — name-preserving aggregator, `if: always()`, `name:` carries the DO-NOT-EDIT comment | Required context #1 |
| `436-522` | `library_tests_dep_off` | FAST-07 |
| `523-580` | `example_unit_smoke` — **no `needs:` at all** (D-09 confirmed), not in `ci-gate.needs` | Required context #2 |
| `581-642` | `install_smoke` | Required context #3 |
| `643-695` | `upgrade_smoke` — `if: github.event_name != 'pull_request'` at `:646` | House-pattern site |
| `696-746` | `passkeys_manual_fallback_smoke` — `if:` at `:699` | House-pattern site |
| `747-876` | `install_matrix` — `if:` at `:750`, 4-leg `flags` matrix (`756-761`) | House-pattern site |
| `877-927` | `passkeys_opt_out_smoke` — `if:` at `:880` | House-pattern site |
| `928-1002` | `example_http_smoke` | Required context #4 |
| `1003-1337` | `example_playwright_smoke` — **required context #5**, `name:` at `:1004` | FAST-02, FAST-06 |
| `1028-1036` | House `actions/cache` shape: `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0`, `${{ runner.os }}-…-v1` key + `restore-keys` prefix | **D-18 template** |
| `1066-1068` | `Install Playwright browsers` → `npx playwright install --with-deps chromium webkit` | **FAST-06 insertion point** |
| `1168-1193` | `design_gallery` step — `id: design_gallery` (`:1169`), `if: ${{ !cancelled() }}`, `run:` block `1188-1193` passing only `--project=` flags | **FAST-02 CI edit point** |
| `1225-1244` | Seam-outcome aggregator — `if: always()`, loop over 5 step outcomes at `1234-1238`, fails only on `"failure"` (`:1239`) | **D-05 mandatory edit** |
| `1254-1260` | `Cache hit summary` step — existing precedent for writing `cache-hit` to `$GITHUB_STEP_SUMMARY` | FAST-06 proof surface |
| `1338-1460` | `generated_admin_playwright_smoke` — stale `head_ref` at `:1343`, **the only existing `timeout-minutes: 60` at `:1347`** | FAST-07 correction |
| `1461-1511` | `ci-gate` — `needs:` list `1464-1473` (9 lanes, **`example_unit_smoke` absent**), `skipped` counted as pass at `:1502` | D-23 |
| `1522-1551` | `notify_release_lane_rot` — `if: always() && github.event_name != 'pull_request' && …` | FAST-07 |
| `1561-1867` | `admin_design_recapture` — `if:` at `:1564`; full-spec `--update-snapshots` invocation at `1684-1691`; commit/PR step dispatch-gated at `:1693` | **Pitfall 1** |
| `1868-2101` | `admin_checkpoint_recapture` — `if:` at `:1871` | FAST-07 |
| `2102-2110` | `admin_eval_render` header — `name:` `:2103`, `needs: [release_ref_guard]` `:2105`, `continue-on-error: true` `:2110` | **FAST-03 edit point; D-11 leave `:2110` alone** |
| `2177-2179` | `Install Playwright browsers (chromium only …)` → `npx playwright install --with-deps chromium` | **D-16 browser-set divergence** |
| `2245-2253` | `nightly_probe` — `if:` at `:2248` | FAST-07 |

All other `npx playwright install` sites: `ci.yml:1379` (generated smoke, `chromium webkit`),
`:1632` (design recapture, `chromium webkit`), `:1939` (checkpoint recapture, `chromium webkit`),
plus `playwright-github-pages.yml:94` (`chromium webkit`) — out of scope but relevant to key design.

### `test/example/priv/playwright/tests/admin-design.spec.ts` (727 lines)

| Anchor | Content at HEAD | Phase use |
|--------|-----------------|-----------|
| `55-70` | `assertNoAxeViolations(page, label)` — `new AxeBuilder({ page }).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']).analyze()` at `64-66`, **no `.include()`** → full-document scan | D-01 evidence confirmed |
| **`58-60`** | **Doc comment is WRONG:** *"This helper is element-scoped (board locator, not full page)"*. The code at `64-66` scans the whole document. | **Must be corrected as part of D-01** |
| `5-13` | File header repeats the same wrong claim: *"element-scoped PNG baseline (board-level, not full page)"* — that half **is** true for the screenshot, but the axe sentence at `:9-10` is misleading | Correct alongside `58-60` |
| `72-94` | `assertBoardScreenshot(page, testInfo, boardId)` — axe at `:78`, `page.locator('#'+boardId)` at `:85`, `toHaveScreenshot` at `:86-93` | **FAST-02 split point** |
| `98-103` | `COMPONENT_BOARDS` — **13** entries (`board-notice` is the designated canary) | Test-count arithmetic |
| `104-116` | `GROUP_BOARDS` — **11** entries (`board-mg-1` … `board-mg-11`) | Test-count arithmetic |
| `118` | `CONFIG_BOARDS` — **4** entries (`board-cfg-overview`, `-users-list`, `-user-detail`, `-audit`) | Test-count arithmetic |
| `243` | `test.describe('Design gallery board snapshots', …)` | Tag scope |
| `250-255` | `beforeEach` → `adminDesignEmail()` → `registerUser()` → `goto('/admin/_design')` → `waitForLiveViewReady()`; nothing else before `:78` | D-01 evidence confirmed |
| `257-261` | Board test generation — `for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS]) test(\`board: ${boardId}\`, …)` | **The 28 tests to tag `@snapshot`** |
| `263-267` | `notice_link board is registered as a standalone L1 component` — a pure-array assertion that **touches no page** yet pays the full `beforeEach` (D-01's 4.4-4.8s measurement) | Stays on PR |
| `269`, `308`, `318`, `364`, `434`, `482`, `494`, `539`, `592`, `636`, `695` | The other 11 non-board tests (responsive-width overflow, config archetypes, group catalog states, MG-5/6 equivalence, filter form GET, byte-coherence, metrics/help/action/content/notice/skeleton L1 state, Escape focus) | **All stay on PR** — these are the "L1-state behavior" half SEED-005 P0-2 mandates keeping |

**Board test count is 28, not 24.** SEED-005 §P0-2 says "24 boards × 3 projects = 72 baselines" —
that count is stale (CONFIG_BOARDS were added later). The current count is **28 × 3 = 84**, which
matches CONTEXT.md's "~84" and `ci.yml:1554` ("84 admin-design baselines (28 boards × …)").

### `test/example/priv/playwright/playwright.config.ts` (230 lines)

| Anchor | Content at HEAD | Phase use |
|--------|-----------------|-----------|
| `27` | `const ADMIN_DESIGN_SPEC = /admin-design\.spec\.ts/;` | — |
| `53-55` | `fullyParallel: false`, `workers: 1`, `retries: process.env.CI ? 1 : 0` | D-15 posture |
| `69-72` | `expect.toHaveScreenshot.pathTemplate` — baselines omit the OS suffix | — |
| `176-183` | `admin-design-chromium` — `devices['Desktop Chrome']`, `video: checkpointVideo` | Axe-per-project axis |
| `185-192` | `admin-design-mobile` — `devices['iPhone 13']` (**WebKit**) | Axe-per-project axis |
| `195-203` | `admin-design-dark` — `devices['Desktop Chrome']` + `colorScheme: 'dark'` | Axe-per-project axis |

**No `grep:` or `grepInvert:` key exists anywhere in the config today.** `[VERIFIED: grep over file]`

---

## FAST-02 — Design-Gallery Axe/Snapshot Split

### Current executed-test inventory (the numbers SC-1 is proven with)

Per design project: **28 board tests + 12 non-board tests = 40**.
Across the three projects the `design_gallery` step (`ci.yml:1168-1193`) currently runs
**120 tests in 866s** (7.2s/test average). `[VERIFIED: gh run view 30390832059 --json jobs, step 18]`

After the D-01 change:

| Lane | Step | Invocation | Expected executed tests |
|------|------|------------|-------------------------|
| PR **and** non-PR | `design_gallery` (existing, `ci.yml:1169`) | `… --project=×3 --grep-invert '@snapshot'` | **39** = (12 non-board × 3) + 3 new axe tests |
| non-PR only | `design_gallery_snapshots` (new, event-gated) | `… --project=×3 --grep '@snapshot'` | **84** = 28 boards × 3 |

These two integers — **39 on a PR run, 84 additionally on a push run** — are the falsifiable
executed-test counts D-24 demands. They are readable straight from the Playwright `list` reporter
tail (`reporter: [['list'], ['html', …]]`, `playwright.config.ts:56`) in each step's log.

### The three new axe tests

Add inside the existing `test.describe` (so they inherit the `beforeEach` that registers and
navigates to `/admin/_design`), **untagged** so they run on every lane:

```ts
test('axe: full-page WCAG 2.1/2.2 AA on the design gallery', async ({ page }) => {
  await assertNoAxeViolations(page, 'design-gallery');
});
```

One test declaration produces one execution per project — the three projects
(`admin-design-chromium` / `-mobile` / `-dark`) supply the viewport and theme axes D-01 identifies
as the genuinely non-redundant ones. `assertNoAxeViolations` is reused unchanged; only its **call
site** moves out of `assertBoardScreenshot` (`admin-design.spec.ts:78`).

### Tagging the 28 board tests

```ts
for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS]) {
  test(`board: ${boardId}`, { tag: '@snapshot' }, async ({ page }, testInfo) => {
    await assertBoardScreenshot(page, testInfo, boardId);
  });
}
```

The details-object form is the second positional argument, before the body.
`[CITED: playwright.dev/docs/test-annotations — "test('test login page', { tag: '@fast' }, async ({ page }) => {…})"]`
`--grep` "runs tests that have a particular tag" and `--grep-invert` "skips tests with a certain tag".
`[CITED: playwright.dev/docs/test-annotations]`
The claim that this form was **added in v1.42** is `[ASSUMED]` — the docs page does not state a
version. It is moot in practice: the repo's lockfile pins `@playwright/test` **1.59.1**
(`test/example/priv/playwright/package-lock.json:121-123`), far above any plausible floor.
`[VERIFIED: package-lock.json read]`

`test.describe(…, { tag: … }, …)` also exists — **do not** use it here; it would tag all 40 tests
per project including the 12 that must stay on PR. `[CITED: playwright.dev/docs/test-annotations]`

### Also fix the wrong documentation (CONTEXT.md `<specifics>`)

`admin-design.spec.ts:58-60` claims the helper is element-scoped. It is not. Correct that comment
**and** the parallel claim in the file header at `:5-13` in the same commit, so no future planner
re-derives FAST-02's sizing from prose that contradicts the code.

---

## FAST-03 — `admin_eval_render` Demotion

One line, inserted in the job header block (`ci.yml:2102-2110`), alongside `needs:` and above
`continue-on-error: true`:

```yaml
  admin_eval_render:
    name: Admin eval render + probe (evidence only, not a merge gate)
    runs-on: ubuntu-latest
    needs: [release_ref_guard]
    if: github.event_name != 'pull_request'      # ← FAST-03
    continue-on-error: true                       # ← D-11: DO NOT TOUCH
```

Measured PR cost removed: **17m33s** (19:11:21 → 19:28:54 on PR run `30390832059`).
`[VERIFIED: gh run view --json jobs]`

Note the job concluded **`failure`** on that PR run despite `continue-on-error: true` — the job's
own `conclusion` in the jobs JSON is the true result; `continue-on-error` only stops it reddening
the *run*. That is GATE-04's problem (Phase 231), not this phase's, but it matters for the
measurement script: **do not filter on `conclusion == "success"` when computing per-job durations.**

### ⚠️ SC-2 is unsatisfiable as literally worded — restate before planning

> SC-2: *"`admin_eval_render` is **absent from the job list** of a PR run…"*

**This will never be true.** GitHub creates a job record for every job in the workflow, including
ones whose `if:` evaluates false; `gh run view --json jobs` returns them with
`conclusion: "skipped"` and `completedAt ≈ startedAt`. Live proof from PR run `30390832059`:

```
Nightly probe (forced-failure self-test)        skipped  19:11:09 → 19:11:09
Passkeys manual fallback smoke                  skipped  19:11:09 → 19:11:09
Install matrix (flag combinations)              skipped  19:11:09 → 19:11:09
Passkeys opt-out smoke                          skipped  19:11:09 → 19:11:09
Upgrade smoke (published source series …)       skipped  19:11:14 → 19:11:13
Recapture admin-design baselines (in-CI)        skipped  19:11:14 → 19:11:13
```
`[VERIFIED: gh run view 30390832059 --repo szTheory/sigra --json jobs, run live 2026-07-28]`

**Satisfiable restatement the planner must adopt:**

> On a PR run, `Admin eval render + probe (evidence only, not a merge gate)` reports
> `conclusion == "skipped"` with a duration under 5 seconds (0 billable runner-minutes), and on a
> push-to-`main` run the same job reports a non-skipped conclusion with a duration in the ~18m band.

Note also that skipped jobs can report `completedAt` **one second before** `startedAt` (see
`Upgrade smoke` above, and `notify_release_lane_rot` at `-1s` on the push run). **The measurement
script must clamp negative durations to 0.**

---

## FAST-04 — Concurrency

### House precedent (placement)

CONTEXT.md D-12 says "between `on:` and `permissions:`". The three sibling workflows all place it
**after** `permissions:`:

| File | Line | Block |
|------|------|-------|
| `release-please.yml` | `25-27` | `group: release-please-${{ github.workflow }}-${{ github.ref }}` / `cancel-in-progress: true` |
| `playwright-github-pages.yml` | `27-29` | `group: playwright-gh-pages` / `cancel-in-progress: true` |
| `hex-publish.yml` | `29-31` | `group: hex-publish-${{ inputs.tag }}` / `cancel-in-progress: false` |

`[VERIFIED: grep -A3 '^concurrency:' .github/workflows/*.yml]`

Placement is cosmetic (both positions are valid top-level YAML). **Recommendation: follow the house
precedent and place it after the `permissions:` block (i.e. after `ci.yml:32`),** so all four
workflows read identically. D-12's semantics are unchanged either way.

### The block

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}
  cancel-in-progress: true
```

`github.run_id` is unique per run and available in the workflow-level `concurrency` context, so
every non-PR event lands in a group of one — never queued, never cancelled. `[ASSUMED — well-established GitHub Actions idiom; not re-verified against docs this session]`

D-13's warning holds: `cancel-in-progress` must be a bare boolean here (it is), never
`${{ X && 'true' || 'false' }}`, which yields the truthy string `"false"`.

### SC-3 proof recipe

```bash
# On the phase's own PR branch, after the concurrency block has merged into the branch:
git commit --allow-empty -m "probe: supersession A" && git push
sleep 20
git commit --allow-empty -m "probe: supersession B" && git push
gh run list --repo szTheory/sigra --workflow ci.yml --branch <branch> --limit 5 \
  --json databaseId,headSha,status,conclusion,createdAt
# Expect: run A conclusion == "cancelled"; run B still in progress / success.
```

Precedent that the pre-change behaviour is real: SEED-005 §P1-1 cites runs `27882635436` and
`27882644882`, 24s apart on the same branch, **both** ran to completion.

For the "main and scheduled are never cancelled" half, the honest evidence is:
(a) the two most recent push-to-`main` runs both concluded normally, and
(b) a `workflow_dispatch` run keyed on its own `run_id` — the *structural* argument. A deliberate
double-push to `main` is not worth staging; state the structural argument and cite the run pair.

Confirmed non-hazards: `ci.yml` has no `push`+`pull_request` same-SHA overlap (`:22-25`, D-14), and
`release-please.yml`'s `gate-ci-green` polls by `--commit <sha>` on the **push** event
(`release-please.yml:119-130`), which the `run_id` keying leaves in a group of one.

---

## FAST-05 — Docs-Only PRs

### 🔴 Two required lanes must be EXEMPT from docs-only gating

This is the most important finding in this document and CONTEXT.md does not cover it.

**`fast_checks` reads `.planning/**` and `guides/**`:**

| Step (`ci.yml`) | Script | Reads |
|-----------------|--------|-------|
| `:86-87` | `milestone-verification-gate.sh` | `find .planning/ -name '<n>-VERIFICATION.md'` for 7 phases; greps each for `##` and `verification` |
| `:106-107` | `getting-started-contract.sh` | Link-checks every relative `.md`/`.html` link in `guides/introduction/getting-started.md`; asserts 3 documented commands still present |
| `:108-109` | `phase34-uat-contracts.sh` | Phase-34 UAT contract docs |
| `:119-120`, `:126-128`, `:131-133`, `:136-138`, `:186-194` | ledger/findings/award/settled/fix-queue/verdicts guards | `guides/reference/*.json`, committed ledgers, `--base <merge-base>` diffs |

`[VERIFIED: read scripts/ci/milestone-verification-gate.sh and getting-started-contract.sh in full]`

**`library_tests` runs ExUnit files that read `.planning/` and `guides/`:**

```
test/sigra/planning/phase_50_nyquist_docs_contract_test.exs
test/sigra/planning/phase_51_install_golden_ci_contract_test.exs
test/sigra/planning/phase_52_milestone_honesty_contract_test.exs
test/sigra/planning/phase_57_nyquist_matrix_contract_test.exs
test/sigra/planning/phase_146_release_validation_test.exs
test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs
test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs
test/sigra/planning/phase_153_infra_stability_contract_test.exs
test/sigra/planning/phase_222_release_lane_hardening_test.exs
test/sigra/guides_dx02_test.exs
test/sigra/architecture_guides_contract_test.exs
test/sigra/admin/glossary_test.exs
test/sigra/recipes/companion_lib_contract_test.exs
```
`[VERIFIED: grep -rln '\.planning/\|guides/' test/]`

**Conclusion:** the docs-only fast path must gate off the *app-behaviour* lanes, not the
*doc-contract* lanes. Recommended exemption set:

| Job | Docs-only behaviour | Why |
|-----|--------------------|-----|
| `fast_checks` | **runs fully, always** | Its guards are the docs contract |
| `library_tests_shard` / `library_tests` | **runs fully, always** | 13 ExUnit files assert on `.planning/` + `guides/` |
| `example_unit_smoke` | heavy steps skipped | Pure app behaviour |
| `install_smoke` | heavy steps skipped | Pure app behaviour |
| `example_http_smoke` | heavy steps skipped | Pure app behaviour |
| `example_playwright_smoke` | heavy steps skipped | Pure app behaviour (the 28.5m pole) |
| `library_tests_dep_off`, `install_golden_contract` | job-level gate (D-08); `install_golden_contract` already self-gates | Non-required |

That leaves **four** of the five ruleset-required contexts step-gated, with `Library tests` running
in full. The wall-clock win is still overwhelming: `example_playwright_smoke` alone is 28.5m of the
28.7m critical path.

### ⚠️ Contract tests assert on `ci.yml` content — run them before pushing

Six ExUnit files read `.github/workflows/ci.yml` and assert on substrings:

| File | What it asserts |
|------|-----------------|
| `phase_153_infra_stability_contract_test.exs:11,68-80` | `ci.yml` still contains the strings `library_tests`, `library_tests_dep_off`, `example_unit_smoke`, `example_playwright_smoke`, `generated_admin_playwright_smoke` |
| `phase_51_install_golden_ci_contract_test.exs:28` | `install_golden_contract` job shape |
| `phase_58_oauth_oa01_ci_contract_test.exs:23-36` | `library_tests_shard` keeps a `Run library tests` step |
| `phase_222_release_lane_hardening_test.exs:22-58` | `notify_release_lane_rot` gates on non-PR, has job-level `issues: write`, is absent from `ci-gate.needs`, and both workflows call `notify-failure-issue.sh` |
| `phase_146_release_validation_test.exs:20`, `phase_147_upgrade_migration_lanes_test.exs:20` | release/upgrade lane shape |

`[VERIFIED: grep -n over test/sigra/planning/*.exs]`

None of the FAST-0x edits should break these (all are additive), but **`mix test test/sigra/planning/`
must be a task-level verification step** in every plan that touches `ci.yml`. Prior art: the memory
record of "Phase51 ci-contract drift" as a recurring local failure means the planner should also
capture the pre-change baseline of that directory so a pre-existing red is not misattributed.

### Recommended shape (resolves the D-07/D-09 discretion)

**Recommend: one shared `changes` job with fail-open consumer polarity.** Rationale:

1. Step-level gating in five jobs would each need `fetch-depth: 0` **and** a `git fetch origin
   <base> --depth=1` before `git diff` (`install_golden_contract:244-245,256`). Only
   `install_golden_contract` and `fast_checks` have `fetch-depth: 0` today; the other five use a
   bare `actions/checkout` (e.g. `ci.yml:1017`, `:536`). One `changes` job computes it once.
2. D-09's DAG risk dissolves under **fail-open** polarity:

```yaml
  changes:
    name: Detect docs-only change
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      docs_only: ${{ steps.detect.outputs.docs_only }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
        with: { fetch-depth: 0 }
      - id: detect
        shell: bash
        run: |
          set -euo pipefail
          if [ "${{ github.event_name }}" != "pull_request" ]; then
            echo "docs_only=false" >> "$GITHUB_OUTPUT"; exit 0
          fi
          git fetch origin "${{ github.base_ref }}" --depth=1
          if git diff --name-only "origin/${{ github.base_ref }}...HEAD" \
               | grep -qvE '(\.md$|^\.planning/)'; then
            echo "docs_only=false" >> "$GITHUB_OUTPUT"
          else
            echo "docs_only=true" >> "$GITHUB_OUTPUT"
          fi
```

Consumers:

```yaml
  example_unit_smoke:
    needs: [changes]
    if: always()                       # preserves today's "no needs" semantics exactly
    steps:
      - name: Run smoke tests
        if: needs.changes.outputs.docs_only != 'true'
```

If `changes` fails or is cancelled, `docs_only` is the empty string → `!= 'true'` → **the heavy
steps run**. The failure mode is "we ran the full matrix unnecessarily", never "a required lane
silently skipped". `if: always()` on `example_unit_smoke` is *behaviour-preserving* precisely
because that job has no `needs:` today.

Cost of the no-op path, by direct analogy to `install_golden_contract`: **36s** on that run
(`19:11:23 → 19:11:59`) `[VERIFIED: gh run view 30390832059 --json jobs]`. Expect a similar figure
per gated job (checkout + setup-beam + cache restore dominate).

### D-06 restated as a hard boundary

Do **not** add `paths:`/`paths-ignore:` to `ci.yml:3-25`. A path-filtered workflow never creates its
check contexts, so all five ruleset-14941512 contexts sit *"Expected — waiting for status"* and the
PR is permanently unmergeable. `[CITED: GitHub Actions docs — "You should not use path or branch filtering to skip workflow runs if the workflow is required to pass before merging"]`
Verified: no path filters exist today. `[VERIFIED: read ci.yml:1-37]`

### The five ruleset-required contexts (authoritative, `MAINTAINING.md:100-117`)

| # | Required check name (byte-exact) | Job id | Job header line |
|---|----------------------------------|--------|-----------------|
| 1 | `Library tests` | `library_tests` | `ci.yml:417-418` |
| 2 | `Example unit smoke (ExUnit + ConnTest)` | `example_unit_smoke` | `ci.yml:523-524` |
| 3 | `Install smoke (fresh phx.new + sigra.install)` | `install_smoke` | `ci.yml:581-584` |
| 4 | `Example HTTP smoke (boot + curl critical routes)` | `example_http_smoke` | `ci.yml:928-929` |
| 5 | `Example Playwright smoke (full lifecycle)` | `example_playwright_smoke` | `ci.yml:1003-1004` |

`ci-gate` is **not** an enforced required check (`MAINTAINING.md:112-115`).
Live re-verification command: `gh api repos/szTheory/sigra/rulesets/14941512 --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'`

---

## FAST-06 — Playwright Browser Cache

### The measured reality (D-15 confirmed)

Step 12 of `example_playwright_smoke` on PR run `30390832059`, `Install Playwright browsers`:
**61s**. `[VERIFIED: gh run view --json jobs, per-step timing]` D-15's split (~14s cacheable
download, ~33s non-cacheable `--with-deps` apt install) means the realistic win is **~15-25s**.

After FAST-03, `example_playwright_smoke` is the **only** PR-path job that installs browsers —
verified by enumerating all five `ci.yml` install sites: `:1068` (this job, PR), `:1379`
(`generated_admin_playwright_smoke`, effectively non-PR via `:1343`), `:1632`
(`admin_design_recapture`, non-PR `:1564`), `:1939` (`admin_checkpoint_recapture`, non-PR `:1871`),
`:2179` (`admin_eval_render`, non-PR after FAST-03).

### Shape

```yaml
      - name: Cache Playwright browsers
        id: playwright_browsers_cache
        uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0
        with:
          path: ~/.cache/ms-playwright
          key: ${{ runner.os }}-playwright-chromium-webkit-1.59.1-v1
          restore-keys: ${{ runner.os }}-playwright-chromium-webkit-
      - name: Install Playwright browsers
        working-directory: test/example/priv/playwright
        run: |
          if [ "${{ steps.playwright_browsers_cache.outputs.cache-hit }}" = "true" ]; then
            npx playwright install-deps chromium webkit
          else
            npx playwright install --with-deps chromium webkit
          fi
```

D-16 is satisfied by `chromium-webkit` in the key: `admin_eval_render` installs **chromium only**
(`ci.yml:2177-2179`) while its `admin-eval-mobile` project is iPhone 13 = **WebKit**
(`playwright.config.ts:215-217`). A shared key would restore WebKit into that job and make Phase
231's GATE-04 diagnosis wrong. If a cache is later added there, it must use
`…-playwright-chromium-1.59.1-v1`.

D-17's polarity is the safe one: `cache-hit` is `'true'` only on an **exact** key match; a
`restore-keys` prefix hit reports `'false'`, so the fallback path re-runs the full install.
`[CITED: actions/cache README — cache-hit outputs]`

### 🔴 New hazard: hard-coded version vs. the `^1.48.0` range

`package.json:13` declares `"@playwright/test": "^1.48.0"`; the lockfile resolves **1.59.1**.
`[VERIFIED: read both files]` A literal `1.59.1` in the cache key means that when the lockfile is
bumped (e.g. by DX-03's Dependabot npm coverage in Phase 234), the key is unchanged, an exact hit
restores the **old** browser revision directory, and the `cache-hit == 'true'` branch runs only
`install-deps` — leaving Playwright to fail at test time with *"Executable doesn't exist at
~/.cache/ms-playwright/chromium-XXXX/…"*.

Two acceptable mitigations; **recommend (a)** because it matches the repo's guard culture and D-21
already brings a `fast_checks` self-test into this phase:

- **(a) Add a hermetic guard** (`scripts/ci/playwright-cache-key-guard.sh` + `.test.sh`, wired into
  `fast_checks` next to the other self-tests) asserting that the version string embedded in
  `ci.yml`'s Playwright cache key equals `@playwright/test`'s resolved version in
  `test/example/priv/playwright/package-lock.json`. Fails loudly the moment they diverge.
- **(b) Derive the version at runtime** into a step output
  (`node -p "require('./node_modules/@playwright/test/package.json').version"`) and interpolate it
  into the key. Costs a step; no guard needed.

D-18 explicitly prefers the literal over `hashFiles(package-lock.json)` (which churns on unrelated
dependency changes) — mitigation (a) preserves that preference while closing the hole.

### Honest counter-consideration for the phase's "after" numbers

Playwright's own CI documentation discourages caching browsers ("restore time is comparable to
download time"). `[CITED: CONTEXT.md D-15, sourced from playwright.dev CI docs]` On a **cache miss**
the `actions/cache` post-step must compress and upload ~400-500MB of chromium+webkit binaries at
the end of a ~19-min job. **The plan should record the post-step duration from the "after" run**
alongside the install-step duration, so the net is reported honestly rather than only the
headline. FAST-06 is a milestone requirement, so it lands regardless — but SC-5's claim must be
"a cache hit was logged", not "we saved 62s".

### SC-5 proof surface (already exists)

`ci.yml:1254-1260` (`Cache hit summary`) already writes `example_deps_cache.outputs.cache-hit` to
`$GITHUB_STEP_SUMMARY`. **Add the Playwright cache-hit line to that same step** — the run's own
summary then carries the FAST-06 evidence with zero new machinery.

---

## FAST-07 — Complete Job Inventory (21 jobs)

Durations below are `completedAt - startedAt` from
`gh run view <id> --json jobs`, run live 2026-07-28.
Push run **`30389700235`** (all jobs execute) and PR run **`30390832059`**.
`[VERIFIED: gh run view, both runs]`

| # | Job id | `ci.yml` header | Existing `timeout-minutes` | Observed (push) | Observed (PR) | **Proposed** | Note |
|---|--------|-----------------|---------------------------|-----------------|---------------|--------------|------|
| 1 | `release_ref_guard` | `39-41` | — | 2s | 3s | **5** | floor |
| 2 | `fast_checks` | `67-69` | — | 27s | 20s | **10** | grows with each new self-test |
| 3 | `changes` *(new, FAST-05)* | — | — | n/a | n/a | **5** | floor |
| 4 | `install_golden_contract` | `228-230` | — | 5m49s | 36s (no-op) | **15** | path-gated; full path 5.81m |
| 5 | `library_tests_shard` (×2) | `314-316` | — | 7m52s / 5m13s | 7m56s / 5m32s | **20** | per-leg; `fail-fast: false` |
| 6 | `library_tests` (aggregator) | `417-419` | — | 3s | 3s | **5** | required context #1 |
| 7 | `library_tests_dep_off` | `436-438` | — | 1m16s | 1m16s | **10** | cache-miss headroom |
| 8 | `example_unit_smoke` | `523-525` | — | 56s | 59s | **10** | required context #2 |
| 9 | `install_smoke` | `581-585` | — | 1m55s | 1m58s | **10** | required context #3 |
| 10 | `upgrade_smoke` | `643-645` | — | 2m01s | skipped | **15** | network-bound (Hex fetch) |
| 11 | `passkeys_manual_fallback_smoke` | `696-698` | — | **1m56s** | skipped | **10** | ⚠️ **omitted from CONTEXT.md D-19's list** |
| 12 | `install_matrix` (×4) | `747-749` | — | ≤1m58s/leg | skipped | **15** | per-leg; 4-leg `flags` matrix |
| 13 | `passkeys_opt_out_smoke` | `877-879` | — | 3m23s | skipped | **10** | |
| 14 | `example_http_smoke` | `928-930` | — | 58s | 53s | **10** | required context #4 |
| 15 | `example_playwright_smoke` | `1003-1005` | — | 26m25s | **28m30s** | **45** | **D-20 hard-fail boundary**; historical max 41.7m |
| 16 | `generated_admin_playwright_smoke` | `1338-1340` | **60** (`:1347`) | 3m44s | skipped | **15** | ⚠️ **correct the existing value** — 16× oversized |
| 17 | `ci-gate` | `1461-1463` | — | 3s | 3s | **5** | clock starts after `needs` resolve |
| 18 | `notify_release_lane_rot` | `1522-1524` | — | skipped (−1s) | skipped (−1s) | **10** | never observed running; size defensively |
| 19 | `admin_design_recapture` | `1561-1563` | — | 19m17s | skipped | **40** | |
| 20 | `admin_checkpoint_recapture` | `1868-1870` | — | 5m15s | skipped | **20** | |
| 21 | `admin_eval_render` | `2102-2104` | — | 18m22s | 17m33s | **40** | non-PR after FAST-03 |
| 22 | `nightly_probe` | `2245-2247` | — | 5s | skipped | **5** | ⚠️ **omitted from CONTEXT.md D-19's list** |

(Rows 1-22 with `changes` added = **22 jobs after this phase**; 21 before.)

**Sizing rule applied:** `max(2 × observed, 5)`, rounded up to a round integer, **widened** where
the observed sample sits on a warm-cache path, where the job is network-bound, or where the
historical max materially exceeds the sample. `example_playwright_smoke` follows D-20 explicitly.

### ⚠️ `timeout-minutes` includes runner-acquisition and setup time

The clock starts when the job is scheduled onto a runner, and queue/setup time counts against it —
it is **not** purely the sum of visible step durations.
`[CITED: github.com/orgs/community/discussions/108006; github.com/actions/runner/discussions/3699]`
On this repo, queueing is currently negligible (run `createdAt` 19:11:08 → earliest job `startedAt`
19:11:09, i.e. **1s**) `[VERIFIED: gh run list + gh run view]`, so the 2× rule holds. But this is
the reason the floor exists and why the aggregators get 5 rather than 1. For `ci-gate` and
`library_tests`, the clock starts only after `needs` resolve (confirmed: `library_tests` startedAt
19:19:21 vs its shard's completedAt 19:19:11), so 5 is generous, not tight.

### Placement convention

Put `timeout-minutes:` immediately after `runs-on: ubuntu-latest` in each job header, matching the
one existing site at `ci.yml:1347` (which sits between `if:` at `:1343-1346` and `needs:` at
`:1344`). Consistency of position across all 22 jobs matters more than the exact slot.

---

## D-21 — The Measurement Script

### 🟢 The baseline's measurement method is now reconstructed and reproduced

CONTEXT.md D-21 correctly notes nothing in the repo records how the 2026-07-28 baseline table was
computed. **This session reconstructed it and reproduced it to within 0.1m.**

```bash
gh run list --repo szTheory/sigra --workflow ci.yml --limit 40 \
  --json event,createdAt,updatedAt,conclusion \
  --jq '.[] | [.event, .conclusion, ((.updatedAt|fromdate)-(.createdAt|fromdate))] | @tsv'
```

Grouping by `event`, wall-clock = `updatedAt - createdAt` (**queue-inclusive**), produced:

| trigger | n | mean | max | pass/n | REQUIREMENTS.md baseline (2026-07-28) |
|---------|---|------|-----|--------|----------------------------------------|
| `pull_request` | 23 | **29.4m** | **41.7m** | 20/23 | 29.5m / p50 27.3m / **41.7m** / 17 pass / 4 fail (n=21) |
| `push` | 9 | 29.7m | **42.3m** | 8/9 | 30.5m / p50 27.6m / **42.3m** / 6 pass / 1 fail (n=7) |
| `schedule` | 7 | 27.0m | 27.7m | **0/7** | 27.3m / p50 27.1m / 29.4m / **0 pass / 9 fail** (n=9) |
| `workflow_dispatch` | 1 | 7.8m | 7.8m | 0/1 | (not in table) |

`[VERIFIED: live gh run list, 2026-07-28]` The two `max` values match **exactly**, and the
schedule lane's 0-pass matches exactly. `n` differs only because the 40-run window slid forward.
Confidence that this is the baseline's method: **HIGH**.

### Recommended script contract

**Path:** `scripts/ci/ci-run-metrics.sh` (+ `scripts/ci/ci-run-metrics.test.sh`)

| Flag | Default | Purpose |
|------|---------|---------|
| `--repo <owner/name>` | `szTheory/sigra` | |
| `--workflow <file>` | `ci.yml` | |
| `--limit <n>` | `40` | Reproduces the baseline window shape |
| `--since <ISO8601>` | unset | **Required for FAST-01's ≥10-run post-change window** — without it the window straddles the change |
| `--event <name>` | unset (all) | |
| `--mode wall\|jobspan` | `wall` | `wall` = `updatedAt - createdAt` (baseline method); `jobspan` = `max(job.completedAt) - min(job.startedAt)` |
| `--format table\|json` | `table` | `table` must emit the exact REQUIREMENTS.md column shape: `trigger \| n \| mean \| p50 \| max \| outcomes` |
| `--jobs <run_id>` | — | Per-job / per-step breakdown for a single run (the D-24 / SC-1 / SC-2 evidence mode) |

**Behavioural requirements the self-test must pin:**

1. **Clamp negative durations to 0.** Skipped jobs report `completedAt` up to 1s *before*
   `startedAt` (observed on `Upgrade smoke` and `notify_release_lane_rot`).
2. **p50 definition must be explicit** — sort ascending, index `floor(n/2)` on 0-based (or state
   the interpolation rule). Undefined p50 is exactly the ambiguity D-21 exists to remove.
3. **Do not filter on `conclusion == "success"` for per-job durations** — `admin_eval_render`
   concludes `failure` under `continue-on-error: true` and its 17m33s is real runner time.
4. **Fail-closed on missing `gh`**, on a non-zero `gh` exit, and on an empty run list.
5. **Emit the exact table shape** so the "after" table is diffable against REQUIREMENTS.md:9-13.

### Available JSON fields (verified live with `gh` 2.95.0)

```
gh run list --json  : attempt conclusion createdAt databaseId displayTitle event headBranch
                      headSha name number startedAt status updatedAt url workflowDatabaseId workflowName
gh run view  --json : (above) + jobs
jobs[]              : name status conclusion startedAt completedAt databaseId steps[]
steps[]             : name number status conclusion startedAt completedAt
```
`[VERIFIED: gh run list --json / gh run view --json, run live]`

⚠️ `gh run list --json` does **not** expose a `jobs` field — per-job data requires a
`gh run view <id> --json jobs` call per run. A 40-run per-job sweep is 40 API round-trips; keep
`--jobs` a single-run mode, not a sweep, or add explicit rate-limit handling.

### Self-test template (repo convention)

`scripts/ci/notify-failure-issue.test.sh` (138 lines) is the closest analogue and should be copied
structurally: `mktemp -d` sandbox → write a recording `gh` stub into `$TMPDIR/bin` → prepend to
`PATH` → run the script under test → assert on the stub's argv log and the script's exit code →
`pass`/`fail` counters → summary block → `exit 1` on any failure.
`[VERIFIED: read scripts/ci/notify-failure-issue.{sh,test.sh} in full]`

Wire it into `fast_checks` beside the other self-tests (`ci.yml:121-226`), e.g. after `:167`:

```yaml
      - name: CI run metrics self-test
        run: bash scripts/ci/ci-run-metrics.test.sh
```

The stub should return canned `gh run list --json` output (including a negative-duration skipped
job and a `failure`-with-continue-on-error job) so cases 1 and 3 above are pinned hermetically —
no network, no `GH_TOKEN`.

---

## Common Pitfalls

### Pitfall 1 — 🔴 A config-level `grepInvert` silently kills baseline recapture

**What goes wrong:** If FAST-02's split is expressed as `grepInvert: /@snapshot/` on the three
`admin-design-*` projects in `playwright.config.ts` (D-03's second branch), the exclusion applies to
**every** invocation of those projects — including the two that must run the board tests in full:

- `ci.yml:1684-1691` — `admin_design_recapture`'s `npx playwright test tests/admin-design.spec.ts
  --project=admin-design-{chromium,mobile,dark} --update-snapshots` (no grep flags)
- `scripts/ci/snapshot-recapture-gate.sh:82-86` — the local compare-mode recapture gate (no grep flags)

`[VERIFIED: grep -n 'admin-design.spec.ts' over ci.yml and scripts/ci/]`

The recapture lane would then run 36 tests instead of 120, recapture **zero** board PNGs, and
conclude green. That is byte-for-byte the v1.42 failure mode this milestone exists to remove.

**How to avoid:** Use the **CLI branch of D-03**. Put `--grep-invert '@snapshot'` on the existing
`design_gallery` step and `--grep '@snapshot'` on the new `design_gallery_snapshots` step. Leave
`playwright.config.ts` **unmodified** — recapture, local runs, and `--update-snapshots` all keep the
full set for free.

(Note: passing `--grep-invert` on one step and `--grep` on a *different* step does not violate D-03.
D-03's hazard — a CLI flag silently **replacing** a config value rather than intersecting with it,
playwright#13852 — is a property of a single invocation. Two invocations, each using CLI only, is
"exactly one mechanism".)

**Warning sign:** the recapture step's log reporting `36 passed` instead of `120 passed`.

### Pitfall 2 — 🔴 Writing SC-2's verification against "absent from the job list"

See §FAST-03. A false `if:` produces a **`skipped`** job record, never an absent one. A verification
step asserting absence fails 100% of the time and will be "fixed" by weakening it — the exact
dishonest-gate pattern this milestone is correcting. Restate the criterion before writing the check.

### Pitfall 3 — 🔴 Gating `fast_checks` or `library_tests` off on docs-only PRs

See §FAST-05. Those two lanes contain every guard and test that reads `.planning/` and `guides/`.
Gating them for a docs-only PR removes coverage precisely where the change is. D-08 permits
job-level gating for non-required jobs — `fast_checks` is a non-required job (it is in
`ci-gate.needs` but not in ruleset 14941512), so the trap is easy to fall into.

### Pitfall 4 — Forgetting the aggregator `id` (D-05, restated because it is the phase's #1 silent-failure mode)

`ci.yml:1234-1238` iterates a hard-coded list of five step outcomes. A new step whose `id` is absent
from that list runs on push, fails, and has its failure **silently discarded** (`:1239` fails only
on `"failure"` for ids it iterates). The new snapshot step's `id` must be added. The aggregator is
already skip-tolerant, so the PR lane (where the step is skipped) needs no special handling.

### Pitfall 5 — `mix test test/sigra/planning/` after any `ci.yml` edit

Six ExUnit contract files assert on `ci.yml` substrings (§FAST-05). All this phase's edits are
additive, so none should break — but capture the pre-change result so a **pre-existing** red (the
recorded "Phase51 ci-contract drift") is not misattributed to this phase.

### Pitfall 6 — Hard-coded `1.59.1` in the browser cache key silently rots

See §FAST-06. `package.json` allows `^1.48.0`; a lockfile bump leaves the key stale and the
`cache-hit == 'true'` branch skips the install that would have fetched the new revision. Ship the
key guard (or derive the version) in the same plan.

### Pitfall 7 — Claiming a 62s FAST-06 win

D-15 already forbids this. Reinforced here: on a cache **miss** the post-job save of ~400-500MB of
chromium+webkit binaries is new cost that did not exist before. Record the post-step duration in the
"after" evidence.

### Pitfall 8 — Losing per-board axe attribution without saying so

D-01 accepts this loss. The phase artifact (D-23's honest-skip set is the natural home) should
record it explicitly alongside the recovery route: `AxeBuilder(…).include(selector)`, already proven
in-repo at `test/example/priv/playwright/tests/admin-generated.spec.ts:160-161`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Excluding a subset of tests from one CI invocation | A second spec file, a `testIgnore` regex, or an `if (process.env.CI_LANE)` early-return inside the test | Playwright tags + `--grep` / `--grep-invert` (D-02/D-03) | Tags are visible in `TestInfo.tags` and the HTML report; a spec split duplicates `beforeEach` and doubles registration cost (D-01's measured `+386s` on push) |
| Run supersession | A cancel step calling `gh run cancel` | `concurrency:` + `cancel-in-progress` | Native scheduler feature; a cancel step burns a runner to cancel a runner |
| Change classification for docs-only PRs | `paths:` / `paths-ignore:` on the trigger | A `changes` job + step/job-level `if:` | Path filters strand required checks permanently (D-06) |
| Path-detect step | A fresh bespoke implementation | Copy `install_golden_contract`'s `detect` step (`ci.yml:246-261`) | Working, reviewed, and already proven at 36s on the no-op path |
| Cache-hit detection | Testing for the existence of `~/.cache/ms-playwright` | `steps.<id>.outputs.cache-hit` | Directory existence is true after a partial `restore-keys` hit; `cache-hit` is exact-match only (D-17) |
| A `gh`-calling guard's test harness | A mock library or a live API call | A PATH-shadowing recording stub, per `notify-failure-issue.test.sh` | Repo convention; hermetic, no token, runs in `fast_checks` in <1s |
| A skipped-job "did it run?" heuristic | Inferring from `conclusion` alone | `conclusion` **plus** a non-trivial duration, plus the step's own executed-test count | `ci-gate` counts `skipped` as pass (`ci.yml:1502`) — the milestone's founding defect |

**Key insight:** every capability this phase needs already exists either as a first-class GitHub
Actions / Playwright feature or as a working pattern elsewhere in this same `ci.yml`. The phase's
risk is entirely in *wiring*, not in *invention* — which is why the aggregator-`id` omission (D-05)
and the recapture-lane regression (Pitfall 1) are the two failure modes worth the most scrutiny.

---

## Runtime State Inventory

This is a CI-configuration phase, not a rename/migration, but three categories of state live
outside the repo and are worth an explicit answer:

| Category | Items found | Action required |
|----------|-------------|-----------------|
| Stored data | **None.** No datastore keys change. | None |
| Live service config | **Ruleset 14941512** on `github.com/szTheory/sigra` holds the five required check **name** strings. Not in git. This phase does not rename any of them (verified byte-exact against `MAINTAINING.md:106-110`). | **None** — but any plan that renames a job `name:` must be rejected |
| OS-registered state | **None.** No runner-side registration. | None |
| Secrets / env vars | **None.** `HEX_API_KEY` unread by `ci.yml` (`:34-36`); `GITHUB_TOKEN` scopes unchanged; `notify_release_lane_rot`'s job-level `issues: write` (`:1527-1528`) untouched. | None |
| Build artifacts | **GitHub Actions cache entries.** A new `playwright-*` cache key is created. The existing `-example-dev-…-v1` and `-library-…-v1` entries are untouched. | None — new key coexists; audit with `gh api repos/szTheory/sigra/actions/caches` if quota pressure appears |

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `gh` CLI | SC-1..SC-5 evidence, D-21 script | ✓ | 2.95.0 (2026-06-17) | none needed |
| `gh` auth to `szTheory/sigra` | live run queries | ✓ | verified by live `gh run list` | none needed |
| `jq`-style filtering | `--jq` flag on `gh` | ✓ | built into `gh` | `jq` binary |
| `node` | self-tests (`*.test.mjs`) | ✓ | 22.14.0 (asdf) | CI pins node 20 (`ci.yml:213-217`) |
| `bash` | guard scripts | ✓ | — | — |
| Postgres (for `mix test`) | Pitfall 5 verification (`mix test test/sigra/planning/`) | ⚠️ not probed this session | — | `scripts/db/up.sh` + `direnv allow` per CLAUDE.md; the `planning/` contract tests are `async: true` file-readers and should not need a DB, but `test_helper.exs` may still require one |
| Playwright browsers (local) | not required — no local Playwright run needed for this phase | n/a | — | all FAST-02 proof comes from CI runs |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** local Postgres, per CLAUDE.md's documented `scripts/db/up.sh` path.

---

## Validation Architecture

Every success criterion in this phase is a claim about **what a run did**, not about what a file
says. `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` records the precedent failure —
*"code-level reads that never executed the specs"* — and it binds every proof below. Accordingly
this section is split into (a) the ordinary automated test infrastructure, and (b) the
**observed-run evidence contract**, which is where the phase's real validation lives.

### Test Framework

| Property | Value |
|----------|-------|
| Framework (library) | ExUnit (Elixir ~> 1.18) |
| Framework (browser) | `@playwright/test` **1.59.1** (lockfile-pinned) |
| Framework (guards) | bash + node hermetic self-tests under `scripts/ci/`, executed by `fast_checks` |
| Config files | `test/test_helper.exs`; `test/example/priv/playwright/playwright.config.ts`; `.github/workflows/ci.yml` (`fast_checks` job) |
| Quick run command | `mix test test/sigra/planning/` (ci.yml contract tests, seconds) |
| Guard self-test command | `bash scripts/ci/ci-run-metrics.test.sh` (new, hermetic, <1s) |
| Full suite command | `mix test` (requires Postgres per CLAUDE.md) |

### Phase Requirements → Test Map

| Req | Behavior | Test type | Automated command | Exists? |
|-----|----------|-----------|-------------------|---------|
| FAST-02 | Board tests carry `@snapshot`; axe tests do not; `assertBoardScreenshot` no longer calls axe | unit (static) | `mix test test/sigra/planning/` *(after adding an assertion, see Wave 0)* | ❌ Wave 0 |
| FAST-02 | PR gallery step executes **39** tests; non-PR snapshot step executes **84** | **observed run** | `gh run view <pr_id> --json jobs --jq '…design gallery…'` + step log tail | ✅ evidence contract |
| FAST-02 | `admin_design_recapture` still executes **120** tests (Pitfall 1 regression guard) | **observed run** | `gh run view <push_id> --json jobs` → `Recapture admin-design baselines` step log | ✅ evidence contract |
| FAST-03 | `admin_eval_render` skipped on PR, executes on push | **observed run** | `gh run view <id> --json jobs --jq '.jobs[]\|select(.name\|startswith("Admin eval render"))'` | ✅ evidence contract |
| FAST-04 | Superseded PR run concludes `cancelled`; push/schedule do not | **observed run** | double-push probe + `gh run list --branch <b> --json conclusion` | ✅ evidence contract |
| FAST-05 | Docs-only PR: five required contexts report a merge-eligible state | **observed run** | `gh pr checks <n>` on a throwaway docs-only PR | ✅ evidence contract |
| FAST-05 | `fast_checks` and `library_tests` still execute in full on a docs-only PR | **observed run** | same run's job durations (must be ~27s and ~8m, not ~0s) | ✅ evidence contract |
| FAST-06 | PR run logs a Playwright browser **cache hit** | **observed run** | job step summary (`$GITHUB_STEP_SUMMARY`) + `Install Playwright browsers` step duration | ✅ evidence contract |
| FAST-06 | Cache key version tracks the lockfile | unit (guard) | `bash scripts/ci/playwright-cache-key-guard.test.sh` | ❌ Wave 0 |
| FAST-07 | Every job in `ci.yml` declares `timeout-minutes` | unit (static) | new assertion in `test/sigra/planning/` | ❌ Wave 0 |
| SC-5 / D-21 | Measurement script reproduces the baseline table shape; clamps negatives; explicit p50 | unit (hermetic) | `bash scripts/ci/ci-run-metrics.test.sh` | ❌ Wave 0 |
| all | `ci.yml` contract tests still pass after the edits | unit (regression) | `mix test test/sigra/planning/` | ✅ exists |

### The Observed-Run Evidence Contract (the phase's real gate)

The phase is judged on **one before/after pair of real runs**. Concretely:

| Slot | What it is | How captured |
|------|-----------|--------------|
| **BEFORE-PR** | PR run `30390832059` (2026-07-28, pre-change) | already captured this session; re-fetchable via `gh run view 30390832059 --json jobs` |
| **BEFORE-PUSH** | Push run `30389700235` (2026-07-28, pre-change) | already captured |
| **AFTER-PR** | The phase's own PR, final commit | `scripts/ci/ci-run-metrics.sh --jobs <id>` |
| **AFTER-PUSH** | The push-to-`main` run of the merge commit | `scripts/ci/ci-run-metrics.sh --jobs <id>` |
| **AFTER-DOCSONLY** | A throwaway docs-only PR (touch one `.md`) | `gh pr checks <n>` + `gh run view <id> --json jobs` |
| **AFTER-CANCEL** | Double-push probe on the phase branch | `gh run list --branch <b> --json conclusion` |

Every one of these must be recorded **verbatim** in the phase's verification artifact with its run
ID, so a reviewer can re-fetch and re-verify. A claim without a run ID is not evidence.

**Anti-pattern to reject at review:** any verification step whose command is `grep`, `cat`, or
`Read` against `ci.yml` / `admin-design.spec.ts` as the *sole* proof of a success criterion. Static
reads are acceptable only as **necessary-but-not-sufficient** pre-checks before the run.

### Sampling Rate

- **Per task commit:** `mix test test/sigra/planning/` + the new guard self-tests (seconds).
- **Per wave merge:** full `fast_checks` equivalent locally — every `scripts/ci/*.test.sh` and
  `*.test.mjs` the wave touched.
- **Phase gate:** the six observed-run slots above, all captured, before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `scripts/ci/ci-run-metrics.sh` + `scripts/ci/ci-run-metrics.test.sh` — D-21, wired into `fast_checks`
- [ ] `scripts/ci/playwright-cache-key-guard.sh` + `.test.sh` — FAST-06 version-drift guard (Pitfall 6)
- [ ] A `timeout-minutes` completeness assertion — every `runs-on:` in `ci.yml` has a sibling
      `timeout-minutes:` (FAST-07). Natural home: a new `test/sigra/planning/phase_230_*_test.exs`
      following the existing contract-test convention, **or** a bash guard in `fast_checks`. Prefer
      the ExUnit file — `phase_153_infra_stability_contract_test.exs` is the exact precedent.
- [ ] A `@snapshot` tag-integrity assertion — all 28 board tests tagged, the 12 non-board tests and
      the 3 axe tests untagged (FAST-02, guards against a future test being added untagged and
      silently landing on the PR critical path)
- [ ] The D-23 honest-skip artifact — the enumerated set of jobs/steps that legitimately skip on a
      PR event after this phase, as the documented baseline Phase 231's GATE-03 inherits

---

## Security Domain

`security_enforcement` is not disabled in `.planning/config.json`, so this section is required.
This phase ships no application code and no user-facing surface; the relevant surface is
**CI supply chain and workflow injection**.

### Applicable ASVS categories

| ASVS category | Applies | Standard control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth code touched |
| V3 Session Management | no | — |
| V4 Access Control | **yes (CI)** | Workflow default stays `permissions: contents: read` (`ci.yml:31-32`). **No new job may widen it.** The only job-level widenings today are `notify_release_lane_rot` (`issues: write`), `admin_design_recapture` and `admin_checkpoint_recapture` (`contents: write`, `pull-requests: write`) — all pre-existing and untouched |
| V5 Input Validation | **yes (CI)** | GitHub context strings must reach `run:` blocks via `env:` mapping, never inlined into shell — the convention `notify-failure-issue.sh:14-18` documents. The new `changes` job interpolates `github.base_ref` into a `git fetch`; `base_ref` on a `pull_request: branches: [main]` trigger is always `main`, but the safer form maps it through `env:` |
| V6 Cryptography | no | — |
| V14 Configuration | **yes** | Third-party actions stay SHA-pinned with a trailing version comment (house convention throughout `ci.yml`). The FAST-06 cache step reuses the already-pinned `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0` — **no new action is introduced by this phase** |

### Known threat patterns for GitHub Actions

| Pattern | STRIDE | Standard mitigation | Status in this phase |
|---------|--------|---------------------|----------------------|
| Script injection via untrusted context (`github.head_ref`, PR title/body) into `run:` | Tampering / EoP | Map through `env:`, quote, never `${{ }}` inline in shell | New `changes` job — use `env:` mapping for `base_ref` |
| Unpinned third-party action → supply-chain swap | Tampering | SHA-pin + version comment | ✅ no new actions; reuse the pinned `actions/cache` SHA |
| Cache poisoning across refs | Tampering | GitHub scopes caches by branch with restricted cross-ref restore; key encodes the browser set (D-16) | ✅ D-16 |
| Over-broad `GITHUB_TOKEN` | EoP | Least-privilege default + job-level overrides only | ✅ unchanged |
| Secret exposure in a `concurrency`-cancelled run | Info disclosure | No secrets in `ci.yml` beyond `GITHUB_TOKEN`; `HEX_API_KEY` explicitly unread (`ci.yml:34-36`) | ✅ unchanged |
| Required check bypass via path filtering | Repudiation | **D-06** — never add `paths:` to a required workflow | ✅ D-06 is a hard-fail boundary |

**No new dependency, action, or secret is introduced by this phase.** The Package Legitimacy Audit
section is therefore omitted — see below.

---

## Package Legitimacy Audit

**Not applicable.** This phase installs no new packages in any ecosystem.

- No `mix.exs` / `mix.lock` change.
- No `package.json` / `package-lock.json` change — `@playwright/test` 1.59.1 and
  `@axe-core/playwright` ^4.10.0 are already present and are used unchanged.
- No new GitHub Action — the FAST-06 cache step reuses the SHA already pinned at `ci.yml:1030`.

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

If a plan proposes adding any package, the legitimacy gate must be run before it is accepted.

---

## State of the Art

| Old approach | Current approach | When changed | Impact here |
|--------------|------------------|--------------|-------------|
| `@tag` embedded in the test title | `test('title', { tag: '@x' }, fn)` details object | Playwright ~v1.42 `[ASSUMED]` | D-02; repo at 1.59.1 so both work, details object preferred |
| `grepInvert` in config | CLI `--grep-invert` per invocation | — | D-03 + **Pitfall 1** make CLI strictly correct here |
| Caching Playwright browsers as a default optimization | Playwright docs actively discourage it ("restore time is comparable to download time") | — | D-15 already records this; FAST-06 lands as a requirement, not as an optimization claim |
| `concurrency: group: ${{ github.ref }}` + conditional `cancel-in-progress` | `group: …-${{ pr.number \|\| run_id }}` + unconditional `cancel-in-progress: true` | — | D-12; avoids the queueing that compounds `gate-ci-green`'s 30-min ceiling |
| Legacy branch protection rules | Repository **rulesets** (14941512) | — | D-07: ruleset docs are silent on skipped-job semantics → step-level gating is the safe bet |

**Deprecated / superseded in the repo's own docs:**
- SEED-005 §P0-2's "24 boards × 3 = 72 baselines" — stale; the current count is **28 × 3 = 84**.
- ROADMAP.md:73's "six independently revertible **YAML**" — D-22 corrects this; a spec file is in scope.
- ROADMAP.md:74's "pixels only" Non-negotiable — D-01 supersedes the letter, preserves the intent.
- `admin-design.spec.ts:58-60` / `:5-13`'s "element-scoped axe" — factually wrong; fix in this phase.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | Playwright's details-object tag form was added in **v1.42** | FAST-02 | **None material** — the repo pins 1.59.1 and the docs confirm the form exists; only the version attribution is unverified |
| A2 | `github.run_id` is available in the workflow-level `concurrency:` context | FAST-04 | If wrong, non-PR runs would share a group. Mitigation: the SC-3 probe observes a push run completing, which falsifies it directly. Cheap to verify in the first real run |
| A3 | The `changes` job's no-op cost will be ~36s per gated job, by analogy to `install_golden_contract` | FAST-05 | Under-estimate erodes the FAST-05 win but breaks nothing; measured in AFTER-DOCSONLY |
| A4 | The `actions/cache` post-step for ~400-500MB of browsers costs ~30-60s on a miss | FAST-06 | Affects the honest net-win statement only; measured directly in the AFTER-PR run |
| A5 | `test/sigra/planning/*` contract tests do not require a live Postgres | Environment | If wrong, Pitfall 5's local pre-check needs `scripts/db/up.sh` first — documented fallback exists |
| A6 | The 2026-07-28 baseline used `--limit 40` with `updatedAt - createdAt` | D-21 | **Low** — reproduced to within 0.1m with two `max` values matching exactly. If the original used a different window, the reconstructed method is still the one to standardize on, and D-21 exists precisely to end the ambiguity |
| A7 | Per-board axe scans are ~1.5-2.0s of the 7.62s board-test average | FAST-02 | Affects only the projected 866s→~237s arithmetic, which CONTEXT.md already marks "to be confirmed by measurement, not asserted" |

---

## Open Questions

1. **Does `example_playwright_smoke`'s docs-only step gate risk stranding its aggregator?**
   - What we know: the seam aggregator (`ci.yml:1225-1244`) is `if: always()` and skip-tolerant
     (`:1239`), so all-skipped seams produce "all seams passed".
   - What's unclear: whether that is the *desired* semantic for a docs-only PR (job concludes
     `success` having asserted nothing) or whether the aggregator should log an explicit
     "docs-only: all seams intentionally skipped" line for D-23's honest-skip inventory.
   - Recommendation: **add the explicit log line.** It costs nothing and it is exactly the
     "distinguish correct-skip from rotted-skip" signal Phase 231's GATE-03 will need.

2. **Should the D-23 honest-skip artifact be a standalone file or a section of the phase SUMMARY?**
   - What we know: D-23 requires it be emitted explicitly; Phase 231 GATE-03 and Phase 235 GATE-05
     both consume it.
   - Recommendation: a standalone, durable path — e.g. `.planning/CI-HONEST-SKIP-SET.md` or a
     `guides/reference/` entry — because a phase SUMMARY is archived at milestone close while
     GATE-03/GATE-05 need it live. Planner's call.

3. **`generated_admin_playwright_smoke`'s `timeout-minutes: 60` correction vs. GATE-02's scope.**
   - What we know: FAST-07 owns "every job has a timeout"; the existing 60 is 16× oversized
     (CONTEXT.md `<specifics>`). GATE-02 (Phase 231) owns the stale `head_ref` condition on the
     same job (`ci.yml:1343`).
   - Recommendation: **correct the timeout here** (it is squarely FAST-07) and **do not touch
     `:1343`**. Two adjacent lines, two phases — call it out in the plan so a reviewer does not
     read the timeout edit as scope creep into GATE-02.

4. **Is a real `schedule` observation obtainable inside the phase window?**
   - The nightly fires at 04:30 UTC and has been **0-pass/9-fail** for the whole sampled window.
     SC-3's "a scheduled run under the same conditions runs to completion" may need to be satisfied
     by a `workflow_dispatch` proxy plus the structural `run_id` argument, since nightly greenness
     is Phase 231's GATE-01, not this phase's.
   - Recommendation: state the substitution explicitly in the verification artifact rather than
     letting it pass silently.

---

## Sources

### Primary (HIGH confidence — read or executed in this session)

- `.github/workflows/ci.yml` @ `5db4f0fb` — full job inventory, all cited anchors
- `test/example/priv/playwright/tests/admin-design.spec.ts` @ `5db4f0fb` — test inventory, axe helper, board arrays
- `test/example/priv/playwright/playwright.config.ts` @ `5db4f0fb` — three design projects, no grep seam
- `test/example/priv/playwright/package-lock.json:121-123` — `@playwright/test` 1.59.1
- `test/example/priv/playwright/package.json:12-13` — `^1.48.0` range (drift hazard)
- `scripts/ci/notify-failure-issue.sh`, `scripts/ci/notify-failure-issue.test.sh` — guard + hermetic self-test template
- `scripts/ci/milestone-verification-gate.sh`, `scripts/ci/getting-started-contract.sh` — the docs-reading guards
- `scripts/ci/snapshot-recapture-gate.sh:82-86` — second ungrepped full-spec invocation
- `MAINTAINING.md:100-160` — the five ruleset-14941512 required check names, cadence, residuals
- `test/sigra/planning/*.exs` (6 files) — `ci.yml` contract assertions
- `gh run view 30390832059 --json jobs` (PR, pre-change) — per-job + per-step timings, skipped-job behaviour
- `gh run view 30389700235 --json jobs` (push, pre-change) — all-jobs-execute durations
- `gh run list --workflow ci.yml --limit 40 --json …` — baseline table reconstruction
- `gh run list --json` / `gh run view --json` field enumeration (gh 2.95.0)

### Secondary (MEDIUM confidence)

- `playwright.dev/docs/test-annotations` — details-object tag form, `--grep` / `--grep-invert` semantics
- GitHub Actions workflow-syntax docs — required-check vs path-filter interaction (via CONTEXT.md D-06's citation)
- `actions/cache` README — `cache-hit` exact-match polarity (via CONTEXT.md D-17's citation)

### Tertiary (LOW confidence — flagged, not load-bearing)

- [github.com/orgs/community/discussions/108006](https://github.com/orgs/community/discussions/108006) and
  [github.com/actions/runner/discussions/3699](https://github.com/actions/runner/discussions/3699) —
  `timeout-minutes` includes queue/setup time. Community discussions, not official docs. Not
  load-bearing here (measured queue on this repo is 1s), but it is why the floor exists.

### Upstream planning artifacts (authoritative for this phase)

- `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md` — D-01..D-24
- `.planning/REQUIREMENTS.md:9-13` — the measured baseline table
- `.planning/ROADMAP.md:30-105` — v1.47 Verification Philosophy, Phase 230 criteria
- `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` — §P0-2 (131-138), §P1-1 (142-153), §9 (307-319)
- `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` — the binding precedent failure mode

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Line anchors / current code state | **HIGH** | Every anchor read directly at HEAD `5db4f0fb`; all 30+ CONTEXT.md citations verified accurate |
| Job inventory + durations (FAST-07) | **HIGH** | Fetched live from two real runs via `gh run view --json jobs` |
| Baseline measurement method (D-21) | **HIGH** | Reproduced to within 0.1m with two `max` values matching exactly |
| SC-2 skipped-vs-absent hazard | **HIGH** | Directly observed on six jobs in a real PR run |
| Recapture-lane hazard (Pitfall 1) | **HIGH** | Both ungrepped invocations located by grep |
| Docs-only exemption set (FAST-05) | **HIGH** | Guard scripts read in full; 13 doc-reading test files enumerated |
| Playwright tag/grep semantics | **MEDIUM** | Official docs confirm the form and flags; version attribution unverified |
| Cache post-step cost estimate | **LOW** | Reasoned, not measured — flagged as A4, measured in the AFTER run |
| `timeout-minutes` queue-time semantics | **LOW** | Community sources only; not load-bearing |

**Research date:** 2026-07-28
**Valid until:** 2026-08-11 (14 days — CI run windows slide; re-fetch the baseline before the
"after" comparison if the phase spans more than two weeks. Line anchors are valid until the next
`ci.yml` edit.)
