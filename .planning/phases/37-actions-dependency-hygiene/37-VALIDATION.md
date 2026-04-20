---
phase: 37
slug: actions-dependency-hygiene
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-17
---

# Phase 37 — Validation strategy

> Per-phase validation contract for **GitHub Actions + supply-chain hygiene** (no new library tests).

---

## Test infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GitHub Actions (`CI` workflow) + optional local bash gates |
| **Config file** | `.github/workflows/ci.yml`, `.github/workflows/playwright-github-pages.yml` |
| **Quick run command** | `bash scripts/ci/milestone-verification-gate.sh` |
| **Full suite command** | GitHub Actions: **CI** workflow all jobs green on the PR / `main` merge commit |
| **Estimated runtime** | 30–90 minutes wall clock (Playwright + install matrix lanes) |

---

## Sampling rate

- **After Plan 01 (YAML edits):** Run milestone gate locally; open PR and wait for **CI** (CI-02).
- **After Plan 02 (docs + REQUIREMENTS):** Grep acceptance only if CI already green on merged pins.

---

## Per-task verification map

| Task ID | Plan | Wave | Requirement | Threat ref | Secure behavior | Test type | Automated command | File exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 37-01-01 | 01 | 1 | CI-01 | T-37-01 | Pins resolve to official `actions/*` tags | grep | `rg "actions/checkout@de0fac2"` `.github/workflows/ci.yml` | ✅ | ✅ done |
| 37-01-02 | 01 | 1 | CI-01 | T-37-02 | No stray v4 checkout SHA | grep | `! rg "34e114876b0b11c390a56381ad16ebd13914f8d5" .github/workflows` | ✅ | ✅ done |
| 37-02-01 | 02 | 2 | CI-02 | — | Green **CI** recorded | manual | `gh pr checks <PR#>` (or GitHub UI) | — | ✅ done |
| 37-02-02 | 02 | 2 | CI-03 | — | Pin policy documented | grep | `grep -q "actions/checkout" .planning/phases/37-actions-dependency-hygiene/37-CI-PIN-POLICY.md` | ✅ | ✅ done |

---

## Wave 0 requirements

Existing infrastructure covers all phase requirements — **no Wave 0 install**.

---

## Manual-only verifications

| Behavior | Requirement | Why manual | Test instructions |
|----------|-------------|------------|-------------------|
| Full CI green on merge | CI-02 | Hosted runners + Postgres + Playwright | Open PR from branch with Plan 01; confirm every required check on `main` after merge (or paste `gh run list` / run URL into `37-CI-PIN-POLICY.md`). |

---

## Validation sign-off

- [x] All tasks have automated grep verify or documented manual CI-02 evidence
- [x] No watch-mode flags introduced
- [x] `nyquist_compliant: true` after execution sign-off

**Approval:** approved 2026-04-17
