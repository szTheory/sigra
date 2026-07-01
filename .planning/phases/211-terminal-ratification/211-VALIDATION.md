---
phase: 211
slug: terminal-ratification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-01
---

# Phase 211 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This is a **verify/lock/audit** phase — "validation" here means running the
> existing CI gate scripts + suites in compare mode, not authoring new code.
> No Wave 0 test scaffolding is needed; all gates already exist (D-04, D-10).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash CI gate scripts + ExUnit (`mix test`) + Playwright (6 projects) |
| **Config file** | `.github/workflows/ci.yml`; `scripts/ci/*.sh`; `test/example` Playwright config |
| **Quick run command** | `scripts/ci/quality-ledger-monotonic.sh --base origin/main && scripts/ci/snapshot-canary-guard.sh --base HEAD` |
| **Full suite command** | `mix test` + all 6 Playwright projects (compare mode) + `scripts/ci/admin-acceptance-smoke.sh` (PORT=4017) |
| **Estimated runtime** | ~15–30 min (parity smoke + full Playwright dominate) |

---

## Sampling Rate

- **After every task commit:** Run the relevant gate script for that task (ledger / canary / recapture-gate / smoke).
- **After every plan wave:** Re-run the gate(s) the wave touched in compare mode.
- **Before milestone close (housekeeping edits):** GATE-01 + GATE-02 legs all green.
- **Max feedback latency:** ~120 s for the fast gates; the parity smoke and full Playwright are terminal, run once.

---

## Per-Task Verification Map

> Populated by the planner from the emitted PLAN.md tasks. Each ratification task
> maps to an existing gate script or suite; the "test" is the gate exit code / zero-drift.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 211-01-01 | 01 | 1 | GATE-01 | — | Ledger terminal all-`2`, forward-only lock holds | gate | `scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ | ⬜ pending |
| 211-0x-xx | — | — | GATE-01 | — | Canary + N checkpoint recapture, compare-mode 0 drift vs HEAD | gate | `scripts/ci/snapshot-canary-guard.sh --base HEAD` + `snapshot-recapture-gate.sh` | ✅ | ⬜ pending |
| 211-0x-xx | — | — | GATE-02 | — | Generated-host parity renders elevated admin; golden byte-diff green (phx_new 1.8.7) | integration | `scripts/ci/admin-acceptance-smoke.sh` | ✅ | ⬜ pending |
| 211-0x-xx | — | — | GATE-02 | — | Adversarial milestone audit committed, cites persona verdicts | manual→doc | `test -f .planning/milestones/v1.42-MILESTONE-AUDIT.md` | ❌ W-produced | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Planner refines IDs/waves.*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 scaffolding.
The gate toolchain (`quality-ledger-monotonic.sh`, `snapshot-canary-guard.sh`,
`snapshot-recapture-gate.sh`, `admin-acceptance-smoke.sh`) and the ExUnit/Playwright
suites already exist. This phase RUNS them; it builds none (D-04).

**Pre-flight (not Wave 0, but gating GATE-02):** `mix archive.install --force hex
phx_new 1.8.7` — 1.8.8 is currently installed and will spuriously fail the golden
byte-diff (SEED-004). Do NOT regenerate the fixture.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Adversarial milestone audit judgment (4 RATIFY checks) | GATE-02 SC-4 | Qualitative synthesis via `gsd-audit-milestone`; cites (does not re-run) the committed persona verdicts | Produce `v1.42-MILESTONE-AUDIT.md`; assert the 4 checks + no critical blockers, citing `.planning/v1.42-PERSONA-JTBD-PANEL.md` + 8 per-surface docs |

*Recapture visual approval is NOT manual — it is the automated `snapshot-recapture-gate.sh` (all-green == approval, no human eyeball, per D-02 / zero-human-UAT).*

---

## Validation Sign-Off

- [ ] All tasks map to an existing gate script or suite (no new test infra)
- [ ] Sampling continuity: every ratification task has an automated gate command
- [ ] phx_new 1.8.7 pinned before the GATE-02 parity/golden lane
- [ ] Canary/checkpoint recapture proven zero-drift in compare mode vs HEAD
- [ ] `nyquist_compliant: true` set in frontmatter after planner maps all tasks

**Approval:** pending
