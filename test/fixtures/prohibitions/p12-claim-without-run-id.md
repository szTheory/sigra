# Observed-run evidence ledger (KNOWN-BAD fixture)
A claim without a verbatim run ID is not evidence.

## BEFORE-PR

Status: captured (run )

Baseline for run 30390832059, produced with the committed instrument.

Command:
```
bash scripts/ci/ci-run-metrics.sh --jobs 30390832059
```

Output (verbatim):
```
Admin eval render + probe                  failure     1053s       17m33s
Example Playwright smoke (full lifecycle)  success     1710s       28m30s
```

## AFTER-PR

Status: captured (run 30412458437)

The pull_request run 30412458437 measured 16m52s wall-clock.

Command:
```
bash scripts/ci/ci-run-metrics.sh --jobs 30412458437
```

Output (verbatim):
```
Fast checks   success  26s
Example Playwright smoke (full lifecycle)  success  989s  16m29s
```

## AFTER-NONPR

Status: captured (run 30414885679)

The receiving lane on run 30414885679 executed the demoted work.

Command:
```
gh run view 30414885679 --repo szTheory/sigra --json jobs
```

Output (verbatim):
```
design_gallery_snapshots  success  436s
Running 84 tests using 1 worker
84 passed (7.2m)
admin_eval_render  failure  1074s
```

## AFTER-PUSH

Status: pending (post-merge obligation)

Post-merge capture command:
```
bash scripts/ci/ci-demotion-observer.sh --run <id>
```

## Restated Success Criterion (SC-2)

SC-2's original ROADMAP wording is superseded by an operative restatement recorded here
before the check was written, with its evidence on run 30412458437.

## FAST-06 cache note

A cache hit was logged on run 30413542431; the install step measured 180s on the hit and
36s on the miss (`Cache not found for input keys`). The non-cacheable apt dependency
install dominates, so no net saving is claimed.
