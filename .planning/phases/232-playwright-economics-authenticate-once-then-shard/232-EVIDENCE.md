# Phase 232 Evidence Ledger

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-PW-01](#before-pw-01) | Pre-change design-gallery PR run `30390832059` | `gh run view` and `ci-run-metrics.sh --jobs` | captured |

---

## BEFORE-PW-01

Status: captured (run `30390832059`)

Pre-change receipt for the design-gallery authentication economics work. This run retains the
pre-shard topology: all three design projects ran serially in one `Example Playwright smoke
(full lifecycle)` job, and every design test registered its own account before navigation.

Commands:

```
gh run view 30390832059 --repo szTheory/sigra --json jobs,event,createdAt,updatedAt,databaseId
bash scripts/ci/ci-run-metrics.sh --jobs 30390832059
```

The producing job was `Example Playwright smoke (full lifecycle)`: `success`, 1710s / 28m30s.
Its `Run design gallery boards (chromium, mobile, dark)` step ran from `19:20:47Z` to
`19:35:13Z` (14m26s). The log reports `Running 120 tests using 1 worker` and `120 passed
(14.4m)`: 84 board snapshot assertions plus the 36 remaining per-project gallery assertions.

Output (verbatim):

```
job                                                                 conclusion  duration_s  duration
Fast checks (milestone/installer/contracts/snapshot/ledger guards)  success     20s         0m20s
Release ref guard                                                   success     3s          0m3s
Example unit smoke (ExUnit + ConnTest)                              success     59s         0m59s
Nightly probe (forced-failure self-test)                            skipped     0s          0m0s
Passkeys manual fallback smoke                                      skipped     0s          0m0s
Install matrix (flag combinations)                                  skipped     0s          0m0s
Passkeys opt-out smoke                                              skipped     0s          0m0s
Install smoke (fresh phx.new + sigra.install)                       success     118s        1m58s
Library tests shard 1                                               success     476s        7m56s
Library tests (dep-off — Threadline absent)                         success     76s         1m16s
Example HTTP smoke (boot + curl critical routes)                    success     53s         0m53s
Library tests shard 2                                               success     332s        5m32s
Install golden + idempotency contract (subprocess harness)          success     36s         0m36s
Admin eval render + probe (evidence only, not a merge gate)         failure     1053s       17m33s
Example Playwright smoke (full lifecycle)                           success     1710s       28m30s
Recapture admin-checkpoint baselines (in-CI)                        skipped     0s          0m0s
Generated admin Playwright smoke                                    skipped     0s          0m0s
Upgrade smoke (published source series -> local candidate)          skipped     0s          0m0s
Recapture admin-design baselines (in-CI)                            skipped     0s          0m0s
Library tests                                                       success     3s          0m3s
ci-gate                                                             success     3s          0m3s
Notify on red ci-gate (release-lane-rot)                            skipped     0s          0m0s
```
