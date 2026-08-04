# Phase 232 Evidence Ledger

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-PW-01](#before-pw-01) | Same-current-topology design-gallery PR run `30537470157` | `gh run view`, job log, and `ci-run-metrics.sh --jobs` | captured |
| [AFTER-PW-01](#after-pw-01) | PW-01-only design-gallery PR run `30649942464` | `gh run view`, job log, and `ci-run-metrics.sh --jobs` | captured |
| [AFTER-SHARD-PR](#after-shard-pr) | Retry-free isolated shard PR run `30658864370` | `gh run view`, job logs, `gh pr checks`, and `ci-run-metrics.sh --jobs` | captured |
| [AFTER-SHARD-NONPR](#after-shard-nonpr) | Shared-boot non-PR run `30659282026` | `gh run view`, consumer logs, and `ci-run-metrics.sh --jobs` | captured |

## Historical baseline note

Run `30390832059` remains the original Phase 230 historical receipt: the producing job took
28m30s and its design step reported 120 tests / 14m26s. It predates the current PR
`--grep-invert '@snapshot'` routing shape, so Plan 232-02 correctly replaced it with run
`30537470157` for an attributable, same-topology PW-01 comparison rather than waiving the
count mismatch.

---

## BEFORE-PW-01

Status: captured (run `30537470157`)

Same-current-topology pre-change receipt. The run is a successful `pull_request` event at
head `a897e724b48c21fa25c8893ede99e1a3b3f56ca5`. It retains one serial
`Example Playwright smoke (full lifecycle)` job and performs registration inside each
design test's setup path.

Commands:

```bash
gh run view 30537470157 --repo szTheory/sigra --json databaseId,event,headSha,conclusion,jobs
gh run view 30537470157 --repo szTheory/sigra --job 90854130047 --log
bash scripts/ci/ci-run-metrics.sh --jobs 30537470157
```

Observed design step:

```text
startedAt: 2026-07-30T11:17:21Z
completedAt: 2026-07-30T11:20:57Z
conclusion: success
Running 39 tests using 1 worker
39 passed (3.6m)
```

Canonical metrics excerpt (verbatim):

```text
job                                                                                conclusion  duration_s  duration
Example Playwright smoke (full lifecycle)                                          success     881s        14m41s
```

Coverage receipt: 39 non-snapshot design assertions, 13 per project, across
`admin-design-chromium`, `admin-design-mobile`, and `admin-design-dark`. The 84 tagged
board snapshots remain routed to the non-PR snapshot step and do not execute in this PR
step.

---

## AFTER-PW-01

Status: captured (run `30649942464`)

PW-01-only receipt. The run is a successful `pull_request` event at head
`04ae0ba753e4f0613df5b3f840955018742ffbb9`. That head contains Plans 232-01/02 only;
`.github/workflows/ci.yml` is byte-identical to the BEFORE head and therefore predates all
232-04/232-05 shared-boot and sharding changes.

Commands:

```bash
gh run view 30649942464 --repo szTheory/sigra --json databaseId,event,headSha,conclusion,jobs
gh run view 30649942464 --repo szTheory/sigra --job 91220470078 --log
bash scripts/ci/ci-run-metrics.sh --jobs 30649942464
git show 04ae0ba7:test/example/priv/playwright/playwright.config.ts | rg 'retries: 0'
```

Observed design command and result:

```text
npx playwright test \
  tests/admin-design.spec.ts \
  --project=admin-design-chromium \
  --project=admin-design-mobile \
  --project=admin-design-dark \
  --grep-invert '@snapshot'
Running 42 tests using 1 worker
3 setup-project authentication tests passed
39 unchanged design assertions passed
42 passed (2.2m)
startedAt: 2026-07-31T17:16:24Z
completedAt: 2026-07-31T17:18:37Z
conclusion: success
```

Canonical metrics excerpt (verbatim):

```text
job                                                                                conclusion  duration_s  duration
Example Playwright smoke (full lifecycle)                                          success     879s        14m39s
```

Retry proof: `playwright.config.ts` at the observed head sets `retries: 0`; the job log
contains one successful attempt for each of the 42 reported tests and no retry entry.

### Attributable PW-01 comparison

| Measure | BEFORE `30537470157` | AFTER `30649942464` | Disposition |
|---|---:|---:|---|
| Event | `pull_request` | `pull_request` | identical |
| Workflow topology | one serial Playwright job | one serial Playwright job | identical |
| Design projects | 3 | 3 | identical |
| Design assertions | 39 | 39 | identical |
| PR snapshot routing | 84 tagged assertions excluded | 84 tagged assertions excluded | identical |
| Authentication setup tests | 0 explicit | 3 explicit | expected PW-01 observability addition |
| Retry setting | 0 | 0 | identical |
| Design step duration | 216s | 133s | 83s faster (38.4%) |
| Full Playwright job duration | 881s | 879s | other serial seams dominate |

PW-01 therefore has an attributable observed win before sharding: the same 39 design
assertions and three project contexts complete with one authenticated setup per project,
while the design step falls from 216s to 133s. No claim is made that this alone changes the
full lifecycle job's critical path.

---

## AFTER-SHARD-PR

Status: captured (run `30658864370`, PR `#168`)

The successful `pull_request` run observed the final implementation head
`39e19ad30fe881274e9aeb7c3185c92867a4dd41`. Producing commands:

```bash
gh run view 30658864370 --repo szTheory/sigra --json databaseId,event,headSha,conclusion,jobs
gh run view 30658864370 --repo szTheory/sigra --job <job-id> --log
bash scripts/ci/ci-run-metrics.sh --jobs 30658864370
gh pr checks 168 --repo szTheory/sigra --required
```

Canonical metrics excerpt (verbatim):

```text
Example Playwright shard (design_gallery)     success  244s  4m4s
Example Playwright shard (demo_showcase)      success  107s  1m47s
Example Playwright shard (admin_behavior)     success  331s  5m31s
Example Playwright shard (non_admin_smoke)    success  315s  5m15s
Example Playwright shard (admin_checkpoints)  success  262s  4m22s
Example Playwright smoke (full lifecycle)     success  4s    0m4s
```

| Seam | Started (UTC) | Completed (UTC) | Result | Observed coverage |
|---|---|---|---|---|
| `design_gallery` | 19:23:09 | 19:27:13 | success | 42 passed: 39 assertions + 3 setup projects |
| `demo_showcase` | 19:23:10 | 19:24:57 | success | 4 passed |
| `admin_behavior` | 19:23:17 | 19:28:48 | success | 23 passed |
| `non_admin_smoke` | 19:23:09 | 19:28:24 | success | 16 passed |
| `admin_checkpoints` | 19:23:16 | 19:27:38 | success | 3 passed |

All five intervals are non-zero and overlap. For example, `design_gallery` and
`non_admin_smoke` start at 19:23:09 and overlap for the complete 244-second design
interval. Every seam log contains an explicit `--retries=0`; Playwright reports one
worker and no retry entry. The PR design route remains behavior-only: the unchanged 84
tagged snapshots execute on non-PR events.

| Seam | Database | Port / base URL | Server log | Browsers installed |
|---|---|---|---|---|
| `admin_behavior` | `sigra_admin_behavior` | 4001 / `http://localhost:4001` | `/tmp/example-playwright-admin-behavior.log` | chromium |
| `admin_checkpoints` | `sigra_admin_checkpoints` | 4002 / `http://localhost:4002` | `/tmp/example-playwright-admin-checkpoints.log` | chromium, webkit |
| `design_gallery` | `sigra_design_gallery` | 4003 / `http://localhost:4003` | `/tmp/example-playwright-design-gallery.log` | chromium, webkit |
| `non_admin_smoke` | `sigra_non_admin_smoke` | 4004 / `http://localhost:4004` | `/tmp/example-playwright-non-admin-smoke.log` | chromium, webkit |
| `demo_showcase` | `sigra_demo_showcase` | 4005 / `http://localhost:4005` | `/tmp/example-playwright-demo-showcase.log` | chromium |

The fail-closed terminal log states `all five isolated Playwright shards passed` after all
five matrix results resolve. Required-check output (verbatim fields):

```text
Example Playwright smoke (full lifecycle)  pass  4s  https://github.com/szTheory/sigra/actions/runs/30658864370/job/91251177465
```

No shard is advisory or `continue-on-error`; the terminal result is successful only after
the exhaustive matrix result check.

---

## AFTER-SHARD-NONPR

Status: captured (run `30659282026`)

The successful `workflow_dispatch` run observed the same final head
`39e19ad30fe881274e9aeb7c3185c92867a4dd41`. It was started from a temporary evidence tag;
the tag and automatically produced recapture PR were removed after their receipts were
captured.

```bash
gh run view 30659282026 --repo szTheory/sigra --json databaseId,event,headSha,conclusion,jobs
gh run view 30659282026 --repo szTheory/sigra --job <consumer-job-id> --log
bash scripts/ci/ci-run-metrics.sh --jobs 30659282026
```

| Shared-boot consumer | Duration / result | Readiness and coverage receipt |
|---|---|---|
| five `example_playwright_shard` consumers (the sharded successor to `example_playwright_smoke`) | 175s–499s, all success | each boots independently; design: 87 snapshot/setup tests + 42 behavior/setup tests, all passed |
| `admin_design_recapture` | 629s, success | responding after 3s; warmed `/admin/_design`; 126 design tests, 3 checkpoint compares, and 4 demo compares passed |
| `admin_checkpoint_recapture` | 347s, success | responding after 3s; 3 checkpoint and 4 demo recaptures passed |
| `admin_eval_render` | 1456s, success | responding after 3s; warmed `/admin/_design`; 192 passed; `admin-eval-harness: PASS — all phases green` |

The exact terminal consumer completed in 3 seconds and logged `all five isolated
Playwright shards passed`. The topology intentionally replaces the former single
`example_playwright_smoke` boot consumer with five matrix consumers; the terminal job is
now boot-free and preserves the protected display name. All other Plan 232-04 consumers
execute through the same one shared action. Design non-PR routing preserves the three
projects, 84 snapshot assertions plus three setup tests (87 total), and 39 behavior
assertions plus three setup tests (42 total). No UI implementation or expected baseline
was changed to obtain these receipts.

---

## Final requirement disposition

| Requirement | Structural evidence | Observed evidence | Disposition |
|---|---|---|---|
| PW-01 | setup projects and storage-state contracts in the focused Phase 232 suite | BEFORE-PW-01 vs AFTER-PW-01: unchanged 39 assertions, 216s to 133s | complete |
| PW-02 | five-row isolated matrix, retry-zero commands, exhaustive fail-closed aggregator | AFTER-SHARD-PR: five overlapping successful shards and exact protected context | complete |
| PW-03 | one composite boot definition and consumer-wiring contracts | AFTER-SHARD-PR and AFTER-SHARD-NONPR: every applicable consumer starts and succeeds | complete |

This phase makes no FAST-01 or under-12-minute milestone-window claim; Phase 235 owns
that verdict.

## Flagged Planner Assumptions

- `FLAGGED/UNRESOLVED PW-01 adjacency probe: the source artifacts do not define special semantics for setup definitions that are adjacent or textually equal; the plan assumes project names and state paths, not declaration adjacency, determine separation.`
- `FLAGGED/UNRESOLVED PW-01 empty probe: the source artifacts do not specify an empty, missing, or null storageState fallback; the plan assumes a missing state is a hard setup/test failure and does not invent fallback authentication.`
- `FLAGGED/UNRESOLVED PW-01 ordering probe: the source artifacts do not specify stable ordering when setup projects compare equal; the plan assumes project names are unique, so equality is invalid rather than order-bearing.`
- `FLAGGED/UNRESOLVED PW-02 unclassified probe: the absent plain SPEC defines no additional shard-edge taxonomy; the plan assumes current seam/event routing is exhaustive and proves that set structurally and by live runs.`
- `FLAGGED/UNRESOLVED PW-03 unclassified probe remains: shared-boot equivalence is judged against every current consumer and its parameters, not an invented fallback.`

The unclassified rows received no automatic backstop.

## Descriptor-less prohibitions

These source constraints remain **flagged-unverified** rather than being mislabeled as
mechanically green:

- MUST NOT change rendered admin behavior, markup, styling, brand assets, theme behavior, board inventory, or application copy to make authentication reuse pass.
- MUST NOT make gallery appear covered by silently deleting assertions/snapshots/axe/projects/readiness.
- MUST NOT report PW-01 speedup without verbatim run IDs/commands/equal counts/pre-shard topology proof.
- MUST NOT create a second boot definition, silently drop boot consumer, or redesign app behavior while extracting.
- MUST NOT claim parallel safety only increasing workers/fullyParallel against shared app/db or runtime auth prefix.
- MUST NOT let shard advisory/omitted/retried/continue-on-error.
- MUST NOT accept skipped, serial, retried, partial, or YAML-only evidence.
- MUST NOT mark from inspection/skips/retries/missing consumers/altered counts/unobserved required name.
