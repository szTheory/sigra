---
phase: 36
slug: retroactive-nyquist-validation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-17
---

# Phase 36 — Validation Strategy

> Planning-artifact verification only (no product code changes in baseline plans).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell + `grep` / `find` / `test` |
| **Config file** | none |
| **Quick run command** | `test -f .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md && grep -q "phase_dir" .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md` |
| **Full suite command** | `bash .planning/phases/36-retroactive-nyquist-validation/scripts/verify-phase36.sh` (created by Plan 36-02) |
| **Estimated runtime** | under 5 seconds |

---

## Sampling Rate

- After **Plan 36-01:** Regenerate or re-read `36-INVENTORY.md`.
- After **Plan 36-02:** Run `verify-phase36.sh` once.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 36-01-01 | 01 | 1 | VAL-01 | T-36-01 | Inventory cannot silently omit a phase directory | shell | `test -f .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md && wc -l .planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md \| awk '$1>=15 {exit 0} {exit 1}'` | ⬜ after task | ⬜ pending |
| 36-02-01 | 02 | 1 | VAL-02, VAL-03 | T-36-02 | No empty duplicate phase dirs; missing VALIDATION paths exist | shell | `test -f .planning/phases/36-retroactive-nyquist-validation/scripts/verify-phase36.sh && bash .planning/phases/36-retroactive-nyquist-validation/scripts/verify-phase36.sh` | ⬜ after task | ⬜ pending |

---

## Wave 0 Requirements

- [x] Existing repo shell — no installer.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Waiver wording review | VAL-02 | Policy judgment on bulk waiver | Maintainer reads `36-WAIVERS.md` once before milestone audit |

---

## Validation Sign-Off

- [ ] `36-INVENTORY.md` present and ≥ 15 lines
- [ ] `36-WAIVERS.md` present when any draft phase is waived in bulk
- [ ] `verify-phase36.sh` exits 0
- [ ] `nyquist_compliant: true` retained after final edits

**Approval:** pending
