---
status: passed
phase: 56
completed: 2026-04-22
---

# Phase 56 verification — Maintainer announcement checklist

## Goal (from ROADMAP / plan)

Deliver **MAINT-01**: extend **`MAINTAINING.md`** with a **First public launch (announcement checklist)** — Ship vs Announce, durable roles, installer golden + GA evidence pointers, optional comms, HexDocs vs tag URL policy.

## Must-haves checked

| Criterion | Evidence |
|-----------|----------|
| New section after Release automation, before Manual release | `grep` heading order: Release automation (default) < First public launch < Manual release |
| Ship vs Announce, Assignment, roles not handles | Section includes `### Assignment`, Release captain, Roster, Comms DRI, Security / evidence reviewer |
| No bare `](.planning/` markdown targets | `grep -E '\]\(\.planning/' MAINTAINING.md` exits 1 |
| Tag URLs for v1.4 GA UAT + milestone requirements | Full `https://github.com/sztheory/sigra/blob/v0.2.0/.planning/...` strings present |
| Relative packaged doc links | `[docs/uat-ci-coverage.md](docs/uat-ci-coverage.md)` and `[docs/ga-evidence.md](docs/ga-evidence.md)` |
| Branch protection check string | `` `Install golden + idempotency contract (subprocess harness)` `` in body |
| Optional comms | Announce table rows include **Optional** |
| Intro discoverability | Line before `## Installer golden` mentions first public Hex, First public launch, Release automation |
| No duplicate ship mechanics | Ship rows are links/tables; no re-numbered `mix hex.publish` / tag steps in new section |

## Automated commands (re-run)

- `mix compile --warnings-as-errors` — exit 0
- `mix docs --warnings-as-errors` — exit 0
- All PLAN Task 1–2 acceptance greps — pass

## Requirement traceability

- **MAINT-01** — satisfied by `MAINTAINING.md` changes described in `56-01-SUMMARY.md`.

## Human verification

_None required._ All checks automated or static document review.
