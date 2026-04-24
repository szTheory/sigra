---
phase: 69
slug: intermediate-path-optional-features
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-23
---

# Phase 69 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (library) + ExDoc |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=dev mix docs --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden` (when `sigra.install` docs change) |
| **Estimated runtime** | ~30–180 seconds |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=dev mix docs --warnings-as-errors`
- **After plan wave touching `lib/mix/tasks/sigra.install.ex`:** Run `mix ci.install_golden`
- **Before `/gsd-verify-work`:** Docs + golden (if install touched) green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 69-01-01 | 01 | 1 | ACF-02, ACF-03 | T-69-01 | Doc does not certify compliance | docs | `MIX_ENV=dev mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 69-01-02 | 01 | 1 | ACF-02, ACF-03 | T-69-02 | Accurate CLI semantics | docs + golden | `mix ci.install_golden` when install doc changes | ✅ | ⬜ pending |

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 stubs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ExDoc nav order | ACF-03 | Visual group ordering | Open `doc/index.html`; confirm **Reference** (or equivalent) lists `generator-options` near intro cluster per CONTEXT D-12 |

---

## Validation Sign-Off

- [x] All tasks have automated verify (`mix docs` / conditional golden)
- [x] Sampling continuity maintained
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending execution
