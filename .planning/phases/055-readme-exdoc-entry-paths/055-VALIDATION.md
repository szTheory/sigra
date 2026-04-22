---
phase: 55
slug: readme-exdoc-entry-paths
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-22
---

# Phase 55 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (library) + ExDoc 0.40.x |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | `MIX_ENV=dev mix docs --warnings-as-errors && mix compile --warnings-as-errors` |
| **Estimated runtime** | ~60–120 seconds (docs generation dominates) |

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors` when `mix.exs` or `lib/**` changed; for markdown-only commits, run compile if the prior task touched Elixir, else defer to wave-end docs run.
- **After every plan wave:** Run `MIX_ENV=dev mix docs --warnings-as-errors && mix compile --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 55-01-01 | 01 | 1 | DOC-01 | T-55-01 / T-55-02 | Honest GA framing; no bare `.planning/` Hex-breakers | docs+grep | `MIX_ENV=dev mix docs --warnings-as-errors` + grep | ✅ | ⬜ pending |
| 55-01-02 | 01 | 1 | DOC-01 | T-55-03 | Coordinated disclosure via SECURITY.md | grep | `test -f SECURITY.md` + grep | ✅ | ⬜ pending |
| 55-02-01 | 02 | 2 | DOC-02 | T-55-01 | ≤2-hop docs path; extras wired | docs | `MIX_ENV=dev mix docs --warnings-as-errors` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Existing infrastructure covers all phase requirements — **no** new test stubs required for doc-only edits.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| HexDocs navigation from Getting Started to GA hub | DOC-02 | HTML UX | Build docs locally; open `_build/dev/doc/getting-started.html`; follow reading map to `ga-evidence.html`; confirm links resolve. |
| GitHub Security policy discovery | DOC-01 | Org/repo UI | Open repo on GitHub; confirm **Security** policy is linked from README / SECURITY. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
