---
phase: 252-measure-current-ci
reviewed: 2026-10-13
depth: standard
scope:
  - scripts/ci/ci-run-metrics.sh
  - scripts/ci/ci-run-metrics.test.sh
findings:
  CR-01: fixed
  WR-01: fixed
---

# Phase 252: Final Code Review Recheck

Rechecked the repaired paths at HEAD `658a19888b06339bd502d7500f8cdabf5bf24195`, including implementation commit `eb5ab1a2e`. Both prior findings are fixed. No other concrete regression was found in the changed paths.

## CR-01 — FIXED

Snapshot replay continues to derive required contexts from hash-checked effective-rules and branch-protection responses and withholds results when the saved set differs (`ci-run-metrics.sh:1355-1364`, `1387-1388`). Standalone family replay now uses the shared `derive_required_contexts` helper after verifying both raw response hashes, then compares the derived set, approved five contexts, source, and manifest assertions (`ci-run-metrics.sh:1188-1198`, `1218-1229`). A mismatch forces `required_changed=true`, which leaves both wait values null and marks the result unknown (`ci-run-metrics.sh:1294-1300`).

Fresh fixtures confirm that changing `effective-rules.json` and refreshing its manifest hash while retaining the approved manifest contexts is rejected (`ci-run-metrics.test.sh:740-756`). A separate fixture empties effective required checks and provides the approved contexts through classic branch protection; replay measures both expected 120-second waits (`ci-run-metrics.test.sh:758-765`).

## WR-01 — FIXED; NO REGRESSION

Artifact metadata remains `pending_download` until download, digest verification, and safe extraction complete. Download failure still becomes `unknown` with the API stop reason (`ci-run-metrics.sh:735-750`). The fresh public-collection 503 fixture confirms the artifact is unknown, retains `download_unavailable` in its diagnostic and request ledger, and never reports `verified` (`ci-run-metrics.test.sh:969-981`).

## Verification

- `PYTHONDONTWRITEBYTECODE=1 bash scripts/ci/ci-run-metrics.test.sh` — passed, 47 tests; comparison-contract suite passed.
- Replayed the archived source bundle twice offline — both outputs had SHA-256 `0e047cb23f8c33e4aa41cb03da7fc6043f46047ed49e26842f80d58b4501643a`.
- `--verify-baseline` against the archived bundle and existing baseline — `ready`, no diagnostics.

---

_Rechecked: 2026-10-13_  
_Reviewer: gsd-code-reviewer (independent final recheck)_
