---
phase: 222
slug: release-lane-hardening-no-silent-rot
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 222 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell + CI-workflow assertions (no unit framework — CI/shell/docs phase) |
| **Config file** | none — resolver logic in `scripts/ci/upgrade-smoke.sh`; structural tests under `test/` |
| **Quick run command** | `bash -n scripts/ci/upgrade-smoke.sh && bash -n scripts/ci/notify-failure-issue.sh` (syntax) |
| **Full suite command** | `mix test` (phase_147 structural test asserts `resolve_latest_sigra_source` + `SIGRA_UPGRADE_SMOKE_START_VERSION` still exist) |
| **Estimated runtime** | ~60–120 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick syntax/lint check for the touched script or `actionlint` for the touched workflow
- **After every plan wave:** Run `mix test` (guards the resolver structural contract) + `actionlint .github/workflows/*.yml`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 222-01-01 | 01 | 1 | HARD-01 | — | Resolver excludes stray `1.20.0`; selects real GA `1.3.0` | unit/shell | `scripts/ci/upgrade-smoke.sh` resolver returns `1.3.0` against a fixture candidate list incl. `1.20.0` | ✅ | ⬜ pending |
| 222-01-02 | 01 | 1 | HARD-01 | — | `resolve_latest_sigra_source` + `SIGRA_UPGRADE_SMOKE_START_VERSION` names preserved; ci.yml:643 pin removed | source | `mix test` (phase_147 structural assertion) exits 0; `grep -c SIGRA_UPGRADE_SMOKE_START_VERSION .github/workflows/ci.yml` == 0 | ✅ | ⬜ pending |
| 222-02-01 | 02 | 1 | HARD-01/02 | — | Shared notify script opens/updates one tracking Issue idempotently | shell | `bash -n scripts/ci/notify-failure-issue.sh`; dry-run against fake token asserts find-then-create branching | ✅ | ⬜ pending |
| 222-02-02 | 02 | 2 | HARD-01 | — | `notify_release_lane_rot` job in ci.yml fires on red main, has job-level `issues: write`, NOT in `ci-gate.needs` | source | `actionlint`; grep asserts `issues: write` + absence from ci-gate needs | ✅ | ⬜ pending |
| 222-02-03 | 02 | 2 | HARD-02 | — | `notify-release-failure` aggregator in release-please.yml covers `gate-ci-green`/`publish-hex` failure | source | `actionlint`; grep asserts notify job `needs` failure surfaces | ✅ | ⬜ pending |
| 222-03-01 | 03 | 2 | HARD-02 | — | Dry-run proof executed OR documented as re-runnable operator step against tag `v1.3.0` | manual | Operator `gh workflow run hex-publish.yml -f dry_run=true` run link captured | ❌ W0 | ⬜ pending |
| 222-03-02 | 03 | 2 | HARD-02 | — | MAINTAINING.md recovery/manual-dispatch runbook subsection added (inputs + timeout read + red-probe) | docs | `grep` asserts new subsection heading + `hex-publish.yml` inputs + cross-ref to `docs/release-runbook-v1-0.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · Task IDs indicative — planner owns final numbering.*

---

## Wave 0 Requirements

- [ ] `scripts/ci/notify-failure-issue.sh` — new shared notify script (created by this phase; verify via `bash -n`)
- [ ] Resolver fixture harness — a way to feed `resolve_latest_sigra_source` a candidate list including `1.20.0` and assert it returns `1.3.0`

*The live-fire release-please auto-publish proof (Success Criterion 2) is intentionally an OR-branch: the loud-failure mechanism + dry-run + wiring trace stand in for a throwaway version bump (D-06). No Wave 0 install needed — CI/shell/docs only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `hex-publish.yml dry_run=true` publish-path proof against `v1.3.0` | HARD-02 | Operator-gated Hex write (221-CONTEXT D-16); requires repo dispatch perms | `gh workflow run hex-publish.yml -f tag=v1.3.0 -f release_version=1.3.0 -f dry_run=true`; confirm compile+test+package+provenance green, no Hex write |
| Loud-signal red-probe (force a failure, confirm Issue opens) | HARD-01/02 | Requires a real workflow run on main to prove the notify path end-to-end | Follow the D-14 forced-failure probe precedent; confirm tracking Issue is opened/updated |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
