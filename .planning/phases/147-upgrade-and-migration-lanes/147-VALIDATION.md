---
phase: 147
slug: upgrade-and-migration-lanes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-31
---

# Phase 147 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit / Mix test |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix docs --warnings-as-errors` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~60-180 seconds, smoke lane may run longer |

---

## Sampling Rate

- **After every task commit:** Run `mix docs --warnings-as-errors`
- **After every plan wave:** Run `mix test` plus any targeted smoke script created by the wave
- **Before `$gsd-verify-work`:** Full suite and upgrade smoke must be green
- **Max feedback latency:** 10 minutes for targeted docs/test checks; CI smoke can exceed this when generating consumer apps

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 147-01-01 | TBD | 0/1 | UPGRADE-02 | T-147-02 | Upgrade proof cannot be claimed without consumer smoke evidence | integration | `bash scripts/ci/upgrade-smoke.sh` | No - Wave 0 | pending |
| 147-02-01 | TBD | 1 | UPGRADE-01 | T-147-01 | Upgrade guide lists rollback and verification commands without changing auth primitives | docs | `mix docs --warnings-as-errors` | No - planned | pending |
| 147-03-01 | TBD | 1 | MIGRATE-01 | T-147-03 | `phx.gen.auth` guidance documents scope/session/token boundaries and when not to migrate | docs | `mix docs --warnings-as-errors` | No - planned | pending |
| 147-04-01 | TBD | 1 | MIGRATE-02 | T-147-04 | Pow/Guardian/Ueberauth guidance documents ownership boundaries and cutover risk | docs | `mix docs --warnings-as-errors` | No - planned | pending |
| 147-05-01 | TBD | 2 | UPGRADE-01, MIGRATE-01, MIGRATE-02 | T-147-05 | Discovery links point to the final published guidance surfaces | docs/link | `mix docs --warnings-as-errors` | Existing surfaces | pending |

*Status: pending, green, red, flaky.*

---

## Wave 0 Requirements

- [ ] `scripts/ci/upgrade-smoke.sh` - covers UPGRADE-02 by testing latest published `0.3.x` posture against local `1.0.0` candidate source.
- [ ] CI workflow wiring for a dedicated upgrade smoke lane - covers UPGRADE-02 and prevents proof from being manual-only.
- [ ] Planned ExDoc extras/groups entries for new docs pages - covers UPGRADE-01, MIGRATE-01, and MIGRATE-02 publication checks.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Migration-lane judgment is boundary-accurate | MIGRATE-01, MIGRATE-02 | Ecosystem equivalence and "when not to migrate" claims require editorial review | Read the migration lane docs and verify they do not promise automatic migration, preserve ownership boundaries, and list cutover risks. |
| Rollback guidance is operationally understandable | UPGRADE-01 | The docs can list commands, but rollback clarity needs human review | Follow the guide headings and confirm rollback notes are explicit for generated-file review and schema/migration impact. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10 minutes for targeted checks
- [ ] `nyquist_compliant: true` set in frontmatter after the planner assigns final task IDs

**Approval:** pending
