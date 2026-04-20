---
status: passed
phase: 37
verified: 2026-04-17
---

# Phase 37 — Verification

**Goal (ROADMAP):** Land **999.2** Dependabot/Actions upgrades with green CI (CI-01–CI-03).

## Must-haves

| Item | Evidence |
|------|----------|
| CI-01 triage documented | `37-TRIAGE-NOTES.md` contains `CI-01 triage` and lists Dependabot PRs #1, #3, #4 |
| First-party pins bumped | No old SHAs in `.github/workflows/`; counts: checkout 12+1, setup-node 2+1, upload-artifact 8 in `ci.yml` |
| Local gate | `bash scripts/ci/milestone-verification-gate.sh` → exit 0 |
| CI-02 / CI-03 docs | `37-CI-PIN-POLICY.md` with `CI-02 evidence:` line + CI-03 sections |
| REQUIREMENTS | CI-01..CI-03 lines are `[x]` |
| Validation | `37-VALIDATION.md` frontmatter `status: approved`, `nyquist_compliant: true` |

## Human verification

1. **Post-push CI-02:** Replace `CI-02 evidence` URL in `37-CI-PIN-POLICY.md` with the **success** `CI` workflow run for the commit that ships these pins (or confirm placeholder remains intentional for your audit bar).

## Gaps

None for automated checks. Hosted full-matrix CI remains the authoritative integration proof after push.

## Requirement traceability

| REQ | Phase artifact |
|-----|----------------|
| CI-01 | `37-TRIAGE-NOTES.md`, Plan 01 |
| CI-02 | `37-CI-PIN-POLICY.md` § CI-02 evidence |
| CI-03 | `37-CI-PIN-POLICY.md` § CI-03 intentional pins |
