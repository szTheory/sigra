# Phase 230: Tier-1 Critical-Path Reclamation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `230-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-07-28
**Phase:** 230-tier-1-critical-path-reclamation
**Mode:** assumptions
**Areas analyzed:** Design-gallery axe/snapshot split · Required-check topology and docs-only PRs ·
`admin_eval_render` demotion and concurrency scope · Browser cache and timeout coverage ·
Revertibility, sequencing, and measurement

**Method:** a `gsd-assumptions-analyzer` subagent read `ci.yml` (~2300 lines), the Playwright config
and specs, SEED-005, the v1.42 findings, and MAINTAINING.md, and reproduced per-job/per-step
durations from PR run `30390832059` and push run `30389700235` via `gh run view --json jobs`.
A second `general-purpose` subagent researched the five GitHub Actions / Playwright / axe-core
semantics questions the codebase could not answer.

## Assumptions Presented

### Design-gallery axe/snapshot split (FAST-02)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Axe and snapshot are welded into one test body; no grep/tag/project seam exists — FAST-02 is not YAML-only | Confident | `admin-design.spec.ts:77-94` (axe `:78`, screenshot `:86`), `:257-261`; `playwright.config.ts:176-203`; `ci.yml:1188-1193` |
| "Move pixels only" is worth ~60-100s, not ~500s — the cost is `beforeEach` registration, which stays with the axe half | Confident | Gallery step 866s/120 tests; no-op test `:263` costs 4.4-4.8s touching no page; `beforeEach` at `:250-255`; SEED-005:135 assumed P0-1 had landed |
| The ~84 per-board axe scans are ~84 repetitions of 3 identical full-page scans | Unclear (evidence solid; *authority* to reinterpret the Non-negotiable was not) | `admin-design.spec.ts:64-66` has no `.include()`; comment at `:58-60` wrongly claims element-scoped; gallery is "static literal assigns only" `:248-249` |
| Demoted snapshots stay inside `example_playwright_smoke` as an event-gated step, not a new job | Confident | Required context name, MAINTAINING.md:99-113; aggregator already skip-tolerant `ci.yml:1225-1244` |

### Required-check topology and docs-only PRs (FAST-05)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `paths-ignore` on the trigger is forbidden — contexts never report and the PR hangs | Confident | Five ruleset contexts MAINTAINING.md:104-110; no path filters in `ci.yml` today |
| Gate at step level via a `changes` job, following `install_golden_contract` | Likely -> Confident after research | `ci.yml:228-308`, detect step `:246-261`; measured 36s no-op path |
| `example_unit_smoke` has no `needs:` and is not in `ci-gate.needs` — a new edge is a real DAG change | Confident | `ci.yml:523-525` vs `:1464-1473` |

### `admin_eval_render` demotion and concurrency scope (FAST-03, FAST-04)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Demote with `if: github.event_name != 'pull_request'`; keep `continue-on-error: true` | Confident | House pattern at `ci.yml:646, 699, 750, 880, 1564, 1871, 2248`; not in `ci-gate.needs`; 17m33s measured; `continue-on-error` at `:2110` |
| Key non-PR runs on `github.run_id` rather than `github.ref` to avoid queueing | Likely -> Confident after research | SEED-005:145-149 verbatim form; `gate-ci-green` 30-min ceiling `release-please.yml:119-120` |

### Browser cache and timeout coverage (FAST-06, FAST-07)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Cache buys ~25-30s of a 61s step at most, and only in one PR job post-FAST-03 | Confident | Installs at `ci.yml:1068, 1379, 1632, 1939, 2179`; step 12 of job `90381709730` = 61s; Playwright pinned 1.59.1 |
| Exactly 1 of 21 jobs has `timeout-minutes`, and it is mis-sized | Confident | Only `ci.yml:1347` (60 min for a 3.73m job) |
| `example_playwright_smoke` must be set generously (~45) or the baseline run is timed out | Confident | 28.5m observed, 41.7m max per REQUIREMENTS.md:11 |

### Revertibility, sequencing, and measurement

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 230 is not a pure-YAML change set; FAST-02 needs a spec edit | Confident | ROADMAP.md:73 framing vs `admin-design.spec.ts:78` |
| No measurement script is committed anywhere in the repo | Confident | `grep -rn "gh run list\|gh run view"` returns only prose: MAINTAINING.md:154, ROADMAP.md:41, SEED-005:319 |

## External Research

Spawned because the codebase could not resolve five semantics questions that changed the
recommended approach.

- **Skipped jobs vs required checks under a ruleset:** a skipped *job* reports success and satisfies
  a required check — but every authoritative statement lives on branch-protection pages and the
  ruleset docs are silent. A path-filtered *workflow* never reports and blocks merge. GitHub
  documents the avoidance form: *"You should not use path or branch filtering to skip workflow runs
  if the workflow is required to pass before merging."* The "no-op duplicate workflow" pattern is
  community folklore (discussion #26857), not documented. → **Upgraded D-07 to step-level gating**
  so the phase never bets on undocumented ruleset semantics.
  (docs.github.com/.../troubleshooting-required-status-checks, /pull-requests/reference/status-checks)
- **`cancel-in-progress` expressions:** valid and documented; `github.event.pull_request.number` is
  available at workflow level. Gotchas: a quoted-string ternary evaluates truthy, and
  `cancel-in-progress: false` still **queues** (depth 1). → **Confirmed D-12's `run_id` form** as
  structurally safer than SEED-005's verbatim `github.ref` proposal.
  (docs.github.com/actions/reference/workflows-and-actions/workflow-syntax#concurrency; community #163013, #53506)
- **Cancelled-run check state:** `cancelled` is non-passing and blocks merge if it is the latest
  report on the head SHA. Harmless in normal supersession (older SHA); the hazard is two runs on the
  same SHA in one group. → **Verified inapplicable here**: `ci.yml` triggers are `push: [main]` and
  `pull_request: [main]`, so no same-SHA double-trigger (D-14).
  (docs.github.com/pull-requests/reference/status-checks; community #26127, #168145)
- **Playwright 1.59.1 tag semantics:** `test('title', { tag }, fn)` added in v1.42, so supported.
  Grep matches against project + file + describe + title + **tags**, so both forms filter
  equivalently. CLI `--grep-invert` **replaces** rather than intersects with per-project
  `grepInvert` (playwright#13852). Setup/dependency projects ignore grep filters (#28296).
  → **D-02** (use the tag option) and **D-03** (exactly one filtering mechanism).
  (playwright.dev/docs/api/class-test, class-testproject, test-annotations)
- **`actions/cache` for `~/.cache/ms-playwright`:** Playwright's own CI docs *discourage* caching
  browsers ("restore time is comparable to download time") and note OS deps are not cacheable. The
  browser set must be in the key or one job's cache masks another's missing browser. `cache-hit` is
  `'true'` only on an exact key match. → **D-15** (honest ~15-25s expectation), **D-16** (browser set
  in key — protects Phase 231's GATE-04 diagnosis), **D-17** (still run `install-deps` on a hit).
  (playwright.dev/docs/ci; github.com/actions/cache)
- **Axe scan scope:** `AxeBuilder({ page }).withTags([...]).analyze()` with no `.include()` scans the
  entire document (axe-core API doc). N identical full-page scans against the same state carry the
  rule coverage of one. Non-redundant axes are route, DOM state, **viewport**, **theme**, tag set,
  and shadow DOM/iframes. → **Decisive input to D-01**: the three design projects are exactly
  Desktop Chrome / iPhone 13 / dark, so one scan per project preserves every non-redundant axis.
  (github.com/dequelabs/axe-core/blob/develop/doc/API.md; playwright.dev/docs/accessibility-testing)

## Corrections Made

One question was escalated to the owner. Per `.planning/METHODOLOGY.md`, it was the only item in
this phase clearing the escalation threshold: it changes what the phase can honestly claim, and it
reinterprets a Non-negotiable stated in ROADMAP.md:74.

### Design-gallery axe/snapshot split (FAST-02)

- **Original assumption:** Collapse the per-board axe scans to one full-page scan per design
  project — flagged **Unclear** by the analyzer, not on evidence but on *authority*.
- **Options presented:**
  1. Collapse axe to 1 scan/project — PR 866s -> ~237s (-629s), push unchanged, coverage identical,
     loses per-board attribution, reinterprets the Non-negotiable.
  2. Literal pixels-only split — PR -86s, **push +386s**, attribution preserved, phase reads as a
     miss on its own measured evidence.
  3. Pull PW-01 (`storageState`) forward from Phase 232 — PR -496s with the Non-negotiable honored
     verbatim, but breaks the 230/232 boundary and muddies PW-01's clean measurement (ROADMAP.md:103).
- **User selection:** **Option 1 — collapse axe to one scan per design project.**
- **Reason:** WCAG rule coverage is identical across the three projects (the only non-redundant
  axes are viewport and theme, both preserved), it is the sole option that delivers the phase goal
  without slowing main or violating a phase boundary, and the lost per-board attribution is
  recoverable from the DOM selectors axe already reports.
- **Consequence recorded:** ROADMAP.md:74's Non-negotiable is superseded in letter and preserved in
  intent (never silently drop the axe signal). Captured as D-01 with full rationale.

No other assumption was corrected; the remaining areas were decided under METHODOLOGY's
decisive-defaulting lens, several upgraded from Likely to Confident by the research pass.

## Hazards Carried Into Planning

These were surfaced by the analyzer and are recorded in CONTEXT.md as hard-fail boundaries:

1. **D-05** — a new snapshot step whose `id` is absent from the aggregator loop (`ci.yml:1234-1238`)
   runs on main with its failures silently discarded: the v1.42 failure mode, verbatim.
2. **D-06** — any `paths:`/`paths-ignore:` on the trigger makes docs-only PRs permanently unmergeable.
3. **D-11** — removing `continue-on-error` from `admin_eval_render` reds every push and contaminates
   the after-measurement.
4. **D-16** — a browser cache key without the browser set restores WebKit into the chromium-only
   `admin_eval_render` job and makes it *look* fixed, invalidating Phase 231's GATE-04 diagnosis.
5. **D-20** — a tight `timeout-minutes` on `example_playwright_smoke` kills the pre-change baseline run.
6. **D-23** — every job-level `if:` added here enlarges the honest-skip set GATE-03 must enumerate
   in Phase 231; `ci-gate` counts `skipped` as pass (`ci.yml:1502`).
7. **Doc drift** — `admin-design.spec.ts:58-60` describes behavior the code does not have; a planner
   reasoning from the comment will size FAST-02 wrong.
