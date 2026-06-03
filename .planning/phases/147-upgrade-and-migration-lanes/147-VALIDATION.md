---
phase: 147
slug: upgrade-and-migration-lanes
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-31
updated: 2026-05-31
---

# Phase 147 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit / Mix test |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` |
| **Docs gate command** | `mix docs --warnings-as-errors` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | <5 seconds targeted; smoke lane may run longer |

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
| 147-01-01 | 147-01 | 1 | UPGRADE-02 | T-147-02 | Upgrade proof cannot be claimed without consumer smoke evidence | integration/contract | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` + `bash scripts/ci/upgrade-smoke.sh` | Yes - `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` and `scripts/ci/upgrade-smoke.sh` | green |
| 147-02-01 | 147-02 | 1 | UPGRADE-01 | T-147-01 | Upgrade guide lists rollback and verification commands without changing auth primitives | docs/contract | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` + `mix docs --warnings-as-errors` | Yes - guide + contract test | green |
| 147-02-02 | 147-02 | 1 | MIGRATE-01 | T-147-03 | `phx.gen.auth` guidance documents scope/session/token boundaries and when not to migrate | docs/contract | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` + `mix docs --warnings-as-errors` | Yes - guide + contract test | green |
| 147-02-03 | 147-02 | 1 | MIGRATE-02 | T-147-04 | Pow/Guardian/Ueberauth guidance documents ownership boundaries and cutover risk | docs/contract | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` + `mix docs --warnings-as-errors` | Yes - guide + contract test | green |
| 147-03-01 | 147-03 | 2 | UPGRADE-01, MIGRATE-01, MIGRATE-02 | T-147-05 | Discovery links point to the final published guidance surfaces | docs/link contract | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` + `mix docs --warnings-as-errors` | Yes - README/CHANGELOG/ExDoc assertions | green |
| 147-04-01 | 147-04 | 2 | UPGRADE-01, UPGRADE-02, MIGRATE-01, MIGRATE-02 | T-147-10/T-147-11/T-147-12 | Release evidence separates machine upgrade proof from editorial migration review | docs/evidence contract | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` + `mix docs --warnings-as-errors` | Yes - release evidence assertions | green |

*Status: pending, green, red, flaky.*

---

## Wave 0 Requirements

- [x] `scripts/ci/upgrade-smoke.sh` - covers UPGRADE-02 by testing the configured published source series against local candidate source.
- [x] CI workflow wiring for a dedicated upgrade smoke lane - covers UPGRADE-02 and prevents proof from being manual-only.
- [x] ExDoc extras/groups entries for new docs pages - covers UPGRADE-01, MIGRATE-01, and MIGRATE-02 publication checks.
- [x] `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` - fast persistent contract coverage for CI lane wiring, guide/discovery routing, and release evidence boundaries.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Migration-lane judgment is boundary-accurate | MIGRATE-01, MIGRATE-02 | Ecosystem equivalence and "when not to migrate" claims require editorial review | Read the migration lane docs and verify they do not promise automatic migration, preserve ownership boundaries, and list cutover risks. |
| Rollback guidance is operationally understandable | UPGRADE-01 | The docs can list commands, but rollback clarity needs human review | Follow the guide headings and confirm rollback notes are explicit for generated-file review and schema/migration impact. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10 minutes for targeted checks
- [x] `nyquist_compliant: true` set in frontmatter after the planner assigns final task IDs

**Approval:** validated 2026-05-31

## Validation Audit 2026-05-31

| Metric | Count |
|--------|-------|
| Gaps found | 4 |
| Resolved | 4 |
| Escalated | 0 |

### Added Persistent Coverage

- `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` verifies:
  - `upgrade_smoke` remains a distinct CI job wired to `scripts/ci/upgrade-smoke.sh`.
  - The smoke harness preserves configurable published-source-series resolution, validated override support, install/upgrade commands, compile/migrate gates, and runtime route probing.
  - README, CHANGELOG, and ExDoc extras route to the v1.0 upgrade and migration guides.
  - The guides retain rollback, when-not-to-migrate, ownership-boundary, non-goal, and verification language.
  - Release runbook, UAT/CI coverage, and GA evidence surfaces separate machine upgrade proof from editorial migration review.

### Verification Run

- `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` - 3 tests, 0 failures.
- `mix docs --warnings-as-errors` - passed.
