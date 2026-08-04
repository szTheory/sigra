# Phase 230: Tier-1 Critical-Path Reclamation - Context

**Gathered:** 2026-07-28 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

All low-risk PR-critical-path wins land in ONE revertible step, judged on ONE before/after pair
of real PR runs: design-gallery snapshots off the PR lane (axe stays), `admin_eval_render`
demoted, `concurrency:`, docs-only path gating, Playwright browser cache, `timeout-minutes`
everywhere.

Owns FAST-02, FAST-03, FAST-04, FAST-05, FAST-06, FAST-07.

**In scope:** `.github/workflows/ci.yml`, `test/example/priv/playwright/tests/admin-design.spec.ts`,
`test/example/priv/playwright/playwright.config.ts`, and a new committed measurement script.

**Explicitly NOT in scope (adjacent waste — do not let it in):**
- `admin_design_recapture` burns 19.28m on every push and discards its output (commit/PR step
  gated to `workflow_dispatch` at `ci.yml:1693`). Real waste, but no FAST-0x requirement covers it.
- `generated_admin_playwright_smoke`'s stale `head_ref == 'ship/v1.42-ci-gate-remediation'`
  condition (`ci.yml:1343`). That is **GATE-02, Phase 231**.
- `storageState` / PW-01 — **Phase 232**. See D-01's rationale for why it stays there.
- Removing `continue-on-error` from `admin_eval_render` — **GATE-04, Phase 231**. See D-10.
</domain>

<decisions>
## Implementation Decisions

### Design-gallery axe/snapshot split (FAST-02)

**Owner-ratified reinterpretation.** ROADMAP.md:74 states the Non-negotiable as "FAST-02 moves
*pixels only*". Measurement showed that reading cannot deliver the phase goal (see D-01 evidence).
The owner selected the collapse shape on 2026-07-28. The Non-negotiable's **intent** — never
silently drop the axe WCAG signal, which no other PR lane covers (SEED-005 P0-2) — is fully
preserved; its **letter** is superseded.

- **D-01:** Collapse the per-board axe scans to **one full-page axe test per design project**
  (`admin-design-chromium`, `admin-design-mobile`, `admin-design-dark`), and tag the ~84 per-board
  tests `@snapshot` so only they are event-gated. Projected PR gallery step: 866s -> ~237s (-629s).
  - *Why the collapse is coverage-neutral:* `admin-design.spec.ts:64-66` calls
    `new AxeBuilder({ page }).withTags([...]).analyze()` with **no `.include()`** — axe-core's API
    doc confirms that scans the entire document. Every board test reaches axe in an identical page
    state (`beforeEach` -> `goto('/admin/_design')` -> nothing else before `:78`), on a gallery the
    spec itself records as "static literal assigns only" (`:248-249`). So the ~84 scans are ~84
    repetitions of the same full-page scan. External research confirms N identical full-page scans
    against the same state carry the rule coverage of one.
  - *Why per-project and not per-run:* research identified viewport and theme as the axes where
    repeated axe scans are genuinely **non**-redundant (`color-contrast` and `target-size` evaluate
    computed style). The three projects are exactly Desktop Chrome / iPhone 13 / `colorScheme: 'dark'`
    (`playwright.config.ts:176-203`) — so one scan per project preserves every non-redundant axis
    and collapses only true duplication.
  - *What is lost:* per-board failure attribution in the test name. Axe violations still carry DOM
    selectors that identify the offending board.
  - *Why not literal pixels-only:* the cost is in `beforeEach` `registerUser()` (`:250-255`), which
    belongs to the axe half that **stays** on PR. Measured: the no-op test at `:263` touches no page
    yet costs 4.4-4.8s. Board-specific work is only ~3.0s of the 7.62s average. A literal split
    saves ~86s on PR and makes push/nightly ~386s **slower** (the new `@snapshot` tests re-pay their
    own registration).
  - *Why not pull PW-01 forward:* ROADMAP.md:103 requires PW-01 to land and be measured in Phase 232
    **before** PW-02 restructures, so the sharding win and the registration win stay distinguishable.

- **D-02:** Tag via Playwright's details-object form — `test('title', { tag: '@snapshot' }, fn)` —
  not by embedding `@snapshot` in the title. Added in Playwright v1.42; repo pins **1.59.1**
  (`test/example/priv/playwright/package-lock.json:121-123`). Keeps titles clean, exposes
  `TestInfo.tags`, and surfaces tags in the HTML report. Filtering is equivalent either way: the
  grep regex matches against project name + file + describe + title + **tags**.

- **D-03:** Use **exactly one** filtering mechanism — either the CLI `--grep-invert` flag or a
  per-project `grepInvert` in config, never both. A CLI `--grep-invert` **replaces** the config
  value rather than intersecting with it (playwright#13852), so setting both means the CLI silently
  wins and the per-project exclusion vanishes. Recommended: CLI flag on the PR step, since the CI
  invocation at `ci.yml:1188-1193` already passes only `--project=` flags and grep is orthogonal to
  project selection.

- **D-04:** The demoted snapshots stay **inside `example_playwright_smoke` as a second,
  event-gated step** — not a new job. The job name `Example Playwright smoke (full lifecycle)` is a
  ruleset-14941512 required context (MAINTAINING.md:99-113); keeping snapshots in-job means a
  push-to-main snapshot regression still reds a hard gate (D-10 posture, `ci.yml:1175-1187`).

- **D-05 (hard-fail boundary):** The new snapshot step's `id` **MUST** be added to the seam-outcome
  aggregator loop at `ci.yml:1234-1238`. That aggregator fails only on `outcome == "failure"`
  (`:1239`), so it is already skip-tolerant — but a step whose id is absent from the loop runs on
  main and has its failures **silently discarded**. That is byte-for-byte the v1.42 failure mode.

### Required checks and docs-only PRs (FAST-05)

- **D-06 (hard-fail boundary):** **Never** add `paths:` / `paths-ignore:` to the `ci.yml` trigger
  block. A path-filtered workflow never creates its check contexts, so all five ruleset-required
  checks sit "Expected — waiting for status" and the PR is unmergeable. GitHub documents this
  directly: *"You should not use path or branch filtering to skip workflow runs if the workflow is
  required to pass before merging."* There are no path filters in `ci.yml` today.

- **D-07:** Compute the docs-only boolean in **one `changes` job with `outputs:`**, and have the
  five ruleset-required jobs consume it at the **step** level so the job still runs and concludes
  `success`. Follow the pattern already shipped in `install_golden_contract` (`ci.yml:228-308`):
  always-run job, a `detect` step (`:246-261`) computing from
  `git diff --name-only "origin/${{ github.base_ref }}...HEAD"`, and `if: steps.detect.outputs.run == 'true'`
  on every heavy step. Measured cost of that no-op path: **36s**.
  - *Why step-level and not job-level:* research confirms a skipped **job** reports success and
    satisfies a required check — but every authoritative sentence saying so lives on
    *branch-protection* pages, and the **ruleset** documentation is silent. Step-level gating makes
    the contexts literally report `success`, so this phase never bets on undocumented ruleset
    semantics. The five contexts are: `Library tests`, `Example unit smoke (ExUnit + ConnTest)`,
    `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`,
    `Example Playwright smoke (full lifecycle)` (MAINTAINING.md:104-110).

- **D-08:** Non-required jobs may gate at the **job** level (cheaper). Only the five required
  contexts need step-level treatment.

- **D-09 (watch item):** `example_unit_smoke` (`ci.yml:523-525`) currently has **no `needs:` at all**
  and is not in `ci-gate.needs`. Adding `needs: [changes]` puts a required lane behind a brand-new
  job for the first time — a real DAG change. If `changes` fails, that required lane skips. Either
  accept and test it, or compute the boolean inline in that one job.

### admin_eval_render demotion (FAST-03)

- **D-10:** Add exactly `if: github.event_name != 'pull_request'` at `ci.yml:2102-2110`. That literal
  condition is the house pattern at seven sites (`:646, 699, 750, 880, 1564, 1871, 2248`) and yields
  push + schedule + `workflow_dispatch` in one line — so Phase 231 can observe it green on every
  merge *and* pull an on-demand dispatch instead of waiting a day per iteration. It is **not** in
  `ci-gate.needs` (`:1464-1473`) and not a ruleset context, so demotion breaks no gate. Removes a
  measured **17m33s** from every PR.

- **D-11 (hard-fail boundary):** **Leave `continue-on-error: true` at `ci.yml:2110` alone.** The two
  underlying bugs are unfixed; removing it turns every push-to-main red and contaminates the "after"
  half of the before/after pair with an unrelated failure. That removal is GATE-04, Phase 231.

### Concurrency (FAST-04)

- **D-12:** Top-level block between `on:` and `permissions:`:
  `group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}` with
  `cancel-in-progress: true`. PR runs on the same PR supersede each other; every non-PR run keys on
  its unique `run_id`, giving it a group of one — structurally never queued and never cancelled.
  - *Why not SEED-005's verbatim form* (`group: github.ref` + `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`,
    research/SEED-005:145-149): research confirms the expression **is** valid, so that form works —
    but `cancel-in-progress: false` still **queues** (GitHub holds one running + one pending per
    group). Queueing two rapid main pushes compounds the known `gate-ci-green` 30-minute polling
    ceiling (`release-please.yml:119-120`) that already blocked the v1.4.0 Hex publish. The
    `run_id` form makes release integrity structural rather than expression-dependent.

- **D-13:** If any expression form is used, emit a **bare boolean**, never a quoted-string ternary.
  `${{ X && 'true' || 'false' }}` produces the *string* `"false"`, which is truthy and cancels anyway.

- **D-14 (verified, not a risk):** `ci.yml` triggers are `push: branches: [main]` and
  `pull_request: branches: [main]` — no same-SHA double-trigger, so the known "cancelled run strands
  a required context" hazard does not apply here. A `cancelled` conclusion is non-passing and would
  block merge, but only ever lands on a superseded SHA.

### Playwright browser cache (FAST-06)

- **D-15 (expectation correction — record this honestly):** The install step measures **61s**, but
  only ~14s is the cacheable browser download; the ~33s `--with-deps` apt install is **not**
  cacheable (system libs live in `/usr/lib`, not `~/.cache/ms-playwright`). After FAST-03 only
  **one** PR job benefits. Honest expected win: **~15-25s, not 62s.** Playwright's own CI docs
  actively discourage caching browsers ("restore time is comparable to download time"). FAST-06 is
  a milestone requirement so it lands — but the phase must not claim a ~62s win.

- **D-16 (hard-fail boundary):** The cache key **must encode the browser set**. `admin_eval_render`
  installs `chromium` only (`ci.yml:2177-2179`) while its `admin-eval-mobile` project is iPhone 13
  (**WebKit**). A key shared with a `chromium webkit` job would restore WebKit binaries and make
  that job *appear* fixed without the fix — invalidating Phase 231's GATE-04 diagnosis.
  Key shape: `playwright-${{ runner.os }}-<browser-set>-1.59.1`.

- **D-17:** On a cache hit, still run the OS dependency install (`npx playwright install-deps ...`).
  Skipping the install step entirely on a hit produces *"Host system is missing dependencies to run
  browsers"*. Gate on `cache-hit != 'true'` (the safe polarity — `cache-hit` is `'true'` only on an
  **exact** key match; a `restore-keys` prefix hit reports `'false'`). Simplest correct alternative:
  run `--with-deps` unconditionally and accept the ~33s.

- **D-18:** Follow the house cache shape at `ci.yml:1028-1036` —
  `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0`, `${{ runner.os }}-...-v1` key
  plus `restore-keys`. Cache path `~/.cache/ms-playwright`. Prefer the literal version `1.59.1` in
  the key over a lockfile hash, which churns on unrelated dependency changes.

### Timeouts (FAST-07)

- **D-19:** Add `timeout-minutes` to all 21 jobs at roughly **2x observed duration with a floor**.
  Only one job has it today (`ci.yml:1347`), and it is mis-sized (60 for a job measuring 3.73m).
  Observed durations to size against (PR run `30390832059` / push run `30389700235`):
  `release_ref_guard` 3s · `fast_checks` 20-27s · `library_tests`/`ci-gate` aggregators 3s ·
  `example_unit_smoke` 0.93m · `example_http_smoke` 0.96m · `library_tests_dep_off` 1.26m ·
  `install_smoke` 1.91m · `install_matrix` <=1.96m · `upgrade_smoke` 2.01m ·
  `passkeys_opt_out_smoke` 3.38m · `generated_admin_playwright_smoke` 3.73m ·
  `admin_checkpoint_recapture` 5.25m · `install_golden_contract` 5.81m · `library_tests_shard` 7.86m ·
  `admin_eval_render` 18.36m · `admin_design_recapture` 19.28m · `example_playwright_smoke` **28.5m**.

- **D-20 (hard-fail boundary):** Set `example_playwright_smoke` **generously (~45)** in this change.
  It measured 28.5m and has hit **41.7m** (REQUIREMENTS.md:11). A 30m ceiling would time out the
  pre-change baseline run and destroy the before/after pair the phase is judged on. Tighten in
  Phase 235 once the new steady state is known.

### Measurement and proof (SC-5, proof discipline)

- **D-21:** **Commit a measurement script before measuring anything.** No measurement script exists
  anywhere in the repo — `grep -rn "gh run list\|gh run view"` returns only prose
  (MAINTAINING.md:154, ROADMAP.md:41, SEED-005:319), and the quick task that produced the
  2026-07-28 baseline table records no commands. Nothing defines how "last 40 runs" was windowed,
  how mean/p50/max were computed, or whether wall-clock is `updatedAt - createdAt` (queue-inclusive)
  or job-span. Without it, Phase 230's "after" and Phase 235's FAST-01 verdict are measured
  differently from the baseline and the milestone's headline claim is unfalsifiable.
  Per `ci.yml:121-226`, a new script is expected to ship with a hermetic self-test wired into
  `fast_checks`.

- **D-22:** **This phase is NOT a pure-YAML change set.** FAST-03/04/05/06/07 touch only `ci.yml`;
  FAST-02 requires editing `admin-design.spec.ts` (and possibly `playwright.config.ts`). The
  ROADMAP.md:73 framing "six independently revertible YAML" is inaccurate as written. Revertibility
  survives — a tag-plus-grep split reverts by deleting the tag and the flag — but the phase manifest
  must list a spec file. Do not split the phase; do correct the framing.

- **D-23:** **Record the intended honest-skip set as a phase artifact.** `ci-gate` counts `skipped`
  as pass (`ci.yml:1502`). Every job-level `if:` added here (FAST-03, FAST-05) enlarges the set that
  GATE-03 must enumerate in Phase 231. Emit the list explicitly or Phase 231 inherits an
  undocumented baseline.

- **D-24:** Prove FAST-02 by the run's own **executed-assertion / test count**, not by reading YAML.
  The PR run must show the axe tests executing (3 per gallery step) and the `@snapshot` tests absent;
  the push/nightly run must show the snapshots executing and hard-fail capable.

### Claude's Discretion

- Exact `timeout-minutes` integer per job, within the 2x-observed rule and D-20's floor.
- Whether the `changes` boolean is one shared job (D-07) or computed inline in `example_unit_smoke`
  to avoid the new DAG edge (D-09) — either is acceptable; pick one and state why.
- Naming of the `@snapshot` tag, the new axe test titles, and the measurement script's path/flags.
- Whether the snapshot demotion uses `--grep-invert` on the PR step or `--grep` on the non-PR step
  (D-03 requires only that exactly one mechanism is used).
- Commit/plan decomposition inside the phase, provided the phase is not split across gates.

### Folded Todos

None. Every high-scoring CI/release todo is already tagged `resolves_phase` for a different phase
(231, 232, or 223) — see `<deferred>`.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` — the finished audit and source of truth.
  §P0-2 (lines 131-138) is FAST-02's mandatory mitigation; §P1-1 (142-153) is FAST-04's verbatim
  proposal (superseded by D-12, with reason); §9 (307-319) is the validation method.
- `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` — verbatim scope guardrails
  (lines 90-101); the 2026-07-28 addendum (208-285) holds the re-measured baseline and five locked
  decisions.
- `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` — the precedent failure mode ("code-level reads
  that never executed the specs"). Binds every proof claim in this phase; D-05 exists because of it.
- `.planning/ROADMAP.md` — v1.47 section: Verification Philosophy (36-43), Phase 230 success
  criteria and Proof discipline / Non-negotiable (73-74). **Note D-01 and D-22 record two
  owner-ratified corrections to this text.**
- `.planning/REQUIREMENTS.md` — FAST-01..07 and the measured baseline table (lines 9-13).
- `.planning/METHODOLOGY.md` — decisive-defaulting and escalation threshold. FAST-02's shape was the
  one item in this phase that cleared the threshold; it was escalated and ratified 2026-07-28.
- `MAINTAINING.md:99-160` — authoritative list of the five ruleset-14941512 required check names,
  the PR-fast/nightly-broad cadence, and the two disclosed nightly-only residuals.
- `.planning/todos/pending/2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md` —
  FAST-03's diagnosis; the demote-then-fix ordering and the `stale-render-guard.sh` exposure.
- `.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` —
  why FAST-04 must not introduce queueing on main (D-12).
- `.planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md` — the gallery's
  snapshot-fragility history. DX-06 closes it in Phase 234; useful background for D-01/D-04.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `ci.yml:228-308` (`install_golden_contract`) — the working "always-run job, path-detect step,
  `if: steps.detect.outputs.run == 'true'` on every heavy step" pattern. Detect step at `:246-261`.
  Directly copyable for FAST-05 (D-07). Requires `fetch-depth: 0` (`:71-73`).
- `ci.yml:1225-1244` — the seam-outcome aggregator, already skip-tolerant (`:1239` fails only on
  `"failure"`). A new event-gated snapshot step slots in by adding one `id` to the loop (D-05).
- `ci.yml:417-435` (`library_tests`) — the name-preserving aggregator pattern; the proven technique
  for restructuring behind a byte-identical required-check name.
- `ci.yml:1028-1036` — house `actions/cache` shape (SHA-pinned v6.1.0, `${{ runner.os }}-...-v1` key
  plus `restore-keys`). Template for the Playwright browser cache (D-18).
- `test/example/priv/playwright/tests/admin-generated.spec.ts:160-161` — in-repo proof of
  `AxeBuilder(...).include(selector)`, if scoped axe is ever wanted later.
- `ci.yml:121-226` — the `fast_checks` hermetic self-test wiring a new guard script hooks into (D-21).

### Established Patterns

- Non-PR gating is always the literal `if: github.event_name != 'pull_request'`
  (`ci.yml:646, 699, 750, 880, 1564, 1871, 2248`).
- Third-party actions are SHA-pinned with a trailing version comment throughout `ci.yml`.
- Playwright determinism posture: `workers: 1`, `fullyParallel: false`, `retries: 1` in CI only, and
  **D-15 forbids `continue-on-error` / retries as flake mitigation** (`playwright.config.ts:11-13, 53-55`).
- Guards ship with hermetic self-tests wired into `fast_checks`.
- The three design projects are `admin-design-chromium` (Desktop Chrome), `admin-design-mobile`
  (iPhone 13), `admin-design-dark` (Desktop Chrome + `colorScheme: 'dark'`) — all plain
  `testMatch: ADMIN_DESIGN_SPEC` with no grep seam (`playwright.config.ts:176-203`).

### Integration Points

- `ci.yml:1168-1193` — the design-gallery step. FAST-02's CI edit point.
- `ci.yml:1234-1238` — the aggregator outcome list. D-05's mandatory edit.
- `ci.yml:2102-2110` — `admin_eval_render` header. FAST-03 inserts one `if:` line; leave `:2110` alone.
- `ci.yml:1-37` — trigger block. FAST-04's top-level `concurrency:` goes between `on:` and `permissions:`.
- `ci.yml:1066-1068` — Playwright browser install in the sole PR-path Playwright job. FAST-06's
  cache step goes immediately before it. Other installs: `:1379, :1632, :1939, :2179`.
- `test/example/priv/playwright/tests/admin-design.spec.ts:77-94` (`assertBoardScreenshot` —
  axe at `:78`, screenshot at `:86`), `:250-255` (`beforeEach` `registerUser`), `:257-261` (board
  test generation). FAST-02's split point.
- `test/example/priv/playwright/playwright.config.ts:176-203` — the three design projects, if the
  split is expressed as per-project `grepInvert` rather than a CLI flag (D-03: pick one).
</code_context>

<specifics>
## Specific Ideas

- **Documentation comment is wrong and must be fixed as part of D-01.**
  `admin-design.spec.ts:58-60` claims the axe scan is "element-scoped (board locator, not full
  page)". The code at `:64-66` scans the whole document. Any planner reasoning from the comment
  rather than the code will size FAST-02 wrong.

- **`generated_admin_playwright_smoke`'s existing `timeout-minutes: 60`** (`ci.yml:1347`) is
  mis-sized by ~16x against its 3.73m measured duration. FAST-07 should correct it, not just add
  timeouts elsewhere.

- **Projected post-phase PR arithmetic** (to be confirmed by measurement, not asserted):
  gallery step -629s, `admin_eval_render` -17m33s off the PR lane entirely, browser cache ~-15-25s.
</specifics>

<deferred>
## Deferred Ideas

- **`admin_design_recapture` burns 19.28m on every push and discards its output** — its commit/PR
  step is gated to `workflow_dispatch` (`ci.yml:1693`). Genuine waste on the push lane, but no
  FAST-0x requirement covers it and it is not on the PR critical path. Candidate for a future
  milestone or a filed todo.
- **Per-board axe failure attribution** — lost by D-01. If it is ever wanted back, the in-repo
  `AxeBuilder(...).include(selector)` pattern (`admin-generated.spec.ts:161`) is the cheap route,
  and it would be genuinely non-redundant only if boards were scanned in distinct DOM states.

### Reviewed Todos (not folded)

All matched at score 0.9 but are already tagged `resolves_phase` for another phase:

- `2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md` -> **Phase 231** (GATE-04).
  Phase 230 only demotes the job (D-10); 231 fixes it and proves it green.
- `2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md` -> **Phase 231**
  (GATE-02, the stale `head_ref` at `ci.yml:1343`).
- `2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` -> **Phase 231** (DX-05).
  Informs D-12 here but is not fixed here.
- `2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` -> **Phase 231** (DX-05).
- `2026-07-27-playwright-github-pages-publisher-red.md` -> **Phase 231** (GATE-01).
- `2026-06-20-playwright-parallelization-per-shard-db.md` -> **Phase 232** (PW-02).
- `2026-07-03-hex-retire-stray-1-20-0.md`, `2026-07-10-upgrade-smoke-button-type-hex-publish.md`
  -> **Phase 223** (operator-deferred, ADR 003).

Untagged and reviewed:

- `2026-07-10-canary-recapture-lane-excludes-canary.md` (score 0.9, area `ci`) — the
  `admin_checkpoint_recapture` lane opens a canary-only PR on every main push. Real recurring noise
  and a latent trap, but it touches the **recapture** lane, not the PR critical path, and no FAST-0x
  requirement covers it. Best home is Phase 234 (hygiene) or a standalone quick task. Not folded.
</deferred>
