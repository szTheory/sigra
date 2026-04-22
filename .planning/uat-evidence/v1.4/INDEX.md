# UAT evidence — Sigra v1.4 (GA-02..GA-05 + GA-01 pointer)

This folder holds **text-first** evidence, steps, and waivers for **v1.4 GA** items. The canonical status matrix is **`.planning/v1.4-GA-UAT.md`**.

**Machine closure:** Outcomes are anchored to merge-blocking CI per **`docs/uat-ci-coverage.md`**. After human runs, attach GitHub Actions run URL(s) and short transcripts — **no raw secret values** (see each folder’s `waiver.md` and **D-38-P04**).

## Sigra version anchor

- **Git SHA:** run `git rev-parse HEAD` at the repo root after checkout — use that value in audit narratives.
- **CI workflow:** `.github/workflows/ci.yml` — see coverage doc for job ↔ SEED mapping.

## GA directories

- [GA-01-pointer](GA-01-pointer/README.md) — GA-01: Phase 41 / CI proof links only (**no rotation re-run in Phase 42**)
- [GA-02](GA-02/README.md) — GA-02: email visual QA (lockout, suspicious-login, lifecycle templates)
- [GA-03](GA-03/README.md) — GA-03: live Google OAuth vs library contract tests
- [GA-04](GA-04/README.md) — GA-04: clean-machine getting-started witness protocol
- [GA-05](GA-05/README.md) — GA-05: consolidation / matrix ownership (pointers, not duplicate CI lists)

## Waiver records

Use each GA folder’s `waiver.md`. **Never paste live OAuth secrets or tokens** — reference env var **names** only.
