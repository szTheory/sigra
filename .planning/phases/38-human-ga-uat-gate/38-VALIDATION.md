---
phase: 38
slug: human-ga-uat-gate
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-17
---

# Phase 38 — Validation Strategy

> Human GA UAT gate: evidence + documentation. Automated checks prove **artifact completeness** and **shift-left CI contracts** (`docs/uat-ci-coverage.md`); humans prove **residual** UX (real mail clients, live Google, subjective timing).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing repo scripts + markdown evidence (no new unit-test framework) |
| **Config file** | none — uses `test/example` per `scripts/uat/RUNBOOK.md` |
| **Quick run command** | `test -f .planning/v1.3-HUMAN-UAT.md && test -f .planning/uat-evidence/v1.3.0/INDEX.md` && `test -f docs/uat-ci-coverage.md` |
| **Full suite command** | `bash scripts/ci/milestone-verification-gate.sh` (optional gate — run after doc-only edits if policy requires) |
| **Estimated runtime** | ~2 minutes (automated) + human time per SEED-001 estimate |

---

## Sampling Rate

- **After every task commit:** Quick run command + spot-check `INDEX.md` links resolve
- **After every plan wave:** Full suite command when any Elixir/JS touched; else quick command only
- **Before `/gsd-verify-work`:** All eight SEED rows terminal + no raw secrets under `uat-evidence/`
- **Max feedback latency:** Bounded by human session (see SEED-001 scope estimate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 38-01-01 | 01 | 1 | UAT-02 | T-38-01 | INDEX does not embed live secrets | grep + file | `test -f .planning/uat-evidence/v1.3.0/INDEX.md` | ✅ W0 | ⬜ pending |
| 38-01-02 | 01 | 1 | UAT-02 | T-38-02 | Master table schema present | grep | `grep -q 'SEED_item' .planning/v1.3-HUMAN-UAT.md` | ✅ W0 | ⬜ pending |
| 38-02-01 | 02 | 2 | UAT-01 | T-38-01 | Items 1–2 evidence or waiver | manual + grep | human + `grep -q 'SEED-1' .planning/v1.3-HUMAN-UAT.md` | ❌ | ⬜ pending |
| 38-02-02 | 02 | 2 | UAT-01 | T-38-03 | Items 3–4 evidence or waiver | manual | human | ❌ | ⬜ pending |
| 38-02-03 | 02 | 2 | UAT-01 | T-38-03 | Items 5–6 evidence or waiver | manual | human | ❌ | ⬜ pending |
| 38-02-04 | 02 | 2 | UAT-01 | T-38-04 | Items 7–8 evidence or waiver | manual | human | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing `scripts/uat/` + `test/example` harness — no new install
- [ ] `.planning/v1.3-HUMAN-UAT.md` — created in Plan 01
- [ ] `.planning/uat-evidence/v1.3.0/INDEX.md` — created in Plan 01

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Email HTML in 3 clients | UAT-01 items 1–2 | Visual rendering | RUNBOOK mail sections + capture per D-38-06 |
| Google OAuth consent UX | UAT-01 item 4 | Real IdP chrome | Real credentials or tightly waived per D-38-13 |
| Clean-machine doc run | UAT-01 item 8 | Cognitive / timing | Fresh host, follow `guides/introduction/getting-started.md`, record wall time |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` or explicit manual verify
- [ ] Sampling continuity: scaffolding tasks automated; human tasks documented
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution closes

**Approval:** pending
