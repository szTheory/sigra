---
phase: 40
slug: tooling-release-ergonomics
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 40 — Validation strategy

> Per-phase validation contract for doc/CI-only work (TOOL-01, REL-01).

---

## Test infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (existing library suite) |
| **Config file** | `mix.exs`, `config/test.exs` (unchanged) |
| **Quick run command** | `MIX_ENV=test mix compile` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~2–8 minutes (environment-dependent) |

---

## Sampling rate

- **After every task commit:** Run quick compile or targeted `grep` from plan acceptance criteria.
- **After every plan wave:** Full `mix test` at library root (same as Phase 37–39).
- **Before `/gsd-verify-work`:** Full suite green; YAML reviewed for `workflow_dispatch`-only publish.
- **Max feedback latency:** Bounded by full `mix test` (acceptable for two-plan phase).

---

## Per-task verification map

| Task ID | Plan | Wave | Requirement | Threat ref | Secure behavior | Test type | Automated command | File exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 40-02-01 | 02 | 1 | REL-01 | T-40-01 / T-40-02 | Secrets only on publish job; SHA-pinned actions | doc+grep | `rg "workflow_dispatch" .github/workflows/hex-publish.yml` | ⬜ W0 | ⬜ pending |
| 40-02-02 | 02 | 1 | REL-01 | — | N/A (docs) | grep | `grep -q "mix hex.publish" MAINTAINING.md` | ⬜ W0 | ⬜ pending |
| 40-01-01 | 01 | 1 | TOOL-01 | — | No contributor Node gate | grep | `! rg "gsd-tools" scripts/ CONTRIBUTING.md` | ✅ | ⬜ pending |
| 40-01-02 | 01 | 1 | TOOL-01 | — | Supersession pointers | grep | `grep -q "MAINTAINING.md" .planning/MILESTONES.md` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 requirements

Existing infrastructure covers all phase requirements — **no new test stubs**.

---

## Manual-only verifications

| Behavior | Requirement | Why manual | Test instructions |
|----------|-------------|------------|-------------------|
| Optional `workflow_dispatch` publish | REL-01 | Needs GitHub UI + secret | Fork or dry-run: confirm workflow does not appear on `pull_request` trigger list in Actions UI |

---

## Validation sign-off

- [ ] All tasks have `<automated>` verify or grep-only acceptance
- [ ] Sampling continuity maintained (compile/test between plans)
- [ ] No watch-mode flags introduced
- [ ] `nyquist_compliant: true` set in frontmatter after execution

**Approval:** pending
