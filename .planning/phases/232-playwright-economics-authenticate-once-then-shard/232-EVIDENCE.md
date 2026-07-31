# Phase 232 Evidence Ledger

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-PW-01](#before-pw-01) | Same-current-topology design-gallery PR run `30537470157` | `gh run view`, job log, and `ci-run-metrics.sh --jobs` | captured |
| [AFTER-PW-01](#after-pw-01) | PW-01-only design-gallery PR run `30649942464` | `gh run view`, job log, and `ci-run-metrics.sh --jobs` | captured |
| AFTER-SHARD-PR | Retry-free isolated shard PR run | pending | pending |
| AFTER-SHARD-NONPR | Shared-boot non-PR consumers | pending | pending |

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
