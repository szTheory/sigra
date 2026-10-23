---
phase: 252-measure-current-ci
reviewed: 2026-10-12T00:00:00Z
depth: standard
scope:
  - scripts/ci/ci-run-metrics.sh
  - scripts/ci/ci-run-metrics.test.sh
findings:
  CR-01: open_partial
  WR-01: fixed
---

# Phase 252: Code Review Recheck

Rechecked the two findings from [252-REVIEW.md](252-REVIEW.md) against HEAD `998962deb6faadc9b638449ad232d5603efe705f`. The collector suite passed: `PYTHONDONTWRITEBYTECODE=1 bash scripts/ci/ci-run-metrics.test.sh` (46 passed, 0 failed).

## CR-01 — OPEN (partial fix; BLOCKER)

Snapshot replay now derives required contexts from the hash-checked saved rules and branch-protection responses and gates required-wait/full-PR results on that derivation (`ci-run-metrics.sh:1355-1364`, `1387-1388`). The new tampered-snapshot fixture confirms that changing the effective-rules bytes and refreshing their hash cannot produce a required-wait measurement (`ci-run-metrics.test.sh:940-951`). The shared context derivation also handles classic branch protection when effective rules have no required contexts (`ci-run-metrics.sh:504-520`).

Standalone family replay still trusts `.required_rules_changed` and `.required_contexts` from its manifest after checking only that each raw file matches the hash declared in that same manifest (`ci-run-metrics.sh:1188-1198`, `1242-1243`, `1285-1290`). It never derives the required contexts from `raw/effective-rules.json` and `raw/branch-protection.json`, even though those files are hash-checked. A changed family rules response can therefore be paired with a refreshed manifest hash while retaining `required_rules_changed:false` and the approved context list; the replay then computes the endpoint from those manifest contexts and returns `status:"measured"`. The existing family altered-rules test only flips the manifest boolean (`ci-run-metrics.test.sh:740-748`), so it does not exercise this case.

Fix: in `replay_family`, derive expected/actual/source from the saved rules and branch-protection JSON using the same approved-context contract, then require the manifest fields and effective contexts to match before calculating either wait. Add a fixture that changes the raw rules response and refreshes its recorded hash while leaving the manifest's approved contexts unchanged; replay must return unknown.

## WR-01 — FIXED

The collector now records a pending status before downloading and only accepts it after both archive-digest validation and safe extraction succeed (`ci-run-metrics.sh:735-744`). A failed download produces `status:"unknown"` with the API stop reason, and the incomplete request ledger retains that reason (`ci-run-metrics.sh:746-750`). The new 503 download fixture verifies the artifact remains unknown, `download_unavailable` is retained, and no `verified` artifact result appears (`ci-run-metrics.test.sh:953-965`).

---

_Rechecked: 2026-10-12_  
_Reviewer: gsd-code-reviewer (independent recheck)_
