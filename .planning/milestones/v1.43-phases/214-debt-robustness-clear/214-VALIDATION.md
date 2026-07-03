---
phase: 214
slug: debt-robustness-clear
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-02
---

# Phase 214 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir ~> 1.18) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test <touched_test_file>` |
| **Full suite command** | `mix test` (requires live test Postgres per CLAUDE.md; NO blanket `:postgres` exclusion) |
| **Estimated runtime** | ~60–180 seconds (full suite; excludes `:upgrade` when prereqs absent) |

---

## Sampling Rate

- **After every task commit:** Run `mix test <touched_test_file>`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green (HEALTH-03 acceptance: zero spurious non-product failures)
- **Max feedback latency:** ~180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 214-01-* | 01 | 1 | DEBT-01 | — | Account deletion succeeds when Oban compiled-but-unsupervised: sessions revoked, user soft-deleted, nothing inserted, no crash | unit | `mix test test/sigra/account/deletion_test.exs` | ❌ W0 | ⬜ pending |
| 214-02-* | 02 | 1 | DEBT-03 | — | Scoped admin cannot revoke a foreign user's session (mismatched `user_id` → no-op, session survives) | unit | `mix test test/sigra/auth_test.exs` | ❌ W0 | ⬜ pending |
| 214-03-* | 03 | 1 | DEBT-05 | — | `app.css` has no top-level `*/` without a matching `/*`; surrounding CSS rules parse in a booted browser | integration | `mix test <app.css guard test>` + Playwright `getComputedStyle` check | ❌ W0 | ⬜ pending |
| 214-04-* | 04 | 1 | HEALTH-03 | — | Clean local `mix test` (test DB up, no phx_new archive / no Chimeway DB) → zero spurious non-product failures | integration | `mix test` (green) | ✅ existing suite | ⬜ pending |
| 214-05-* | 05 | 1 | DEBT-02, DEBT-04 | — | `panel-schema-check.sh` retired with in-file + summary rationale; stray `v1.20.0` tag deleted; `contract.md:9` = `1.1.0` | source/doc | `grep`/`git tag -l` assertions | N/A (doc/script) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Plan-ID grouping above is indicative; the planner sets final plan/wave numbering. Every DEBT-*/HEALTH-03 requirement has an automated verify except the DEBT-04 Hex-side retire (manual runbook, see Manual-Only).*

---

## Wave 0 Requirements

- [ ] `test/sigra/account/deletion_test.exs` — regression test for DEBT-01 (compiled-but-unsupervised Oban, `oban_jobs` absent)
- [ ] `test/sigra/auth_test.exs` — deny-path test for DEBT-03 (foreign-token revocation no-op)
- [ ] app.css CI regex guard (DEBT-05, D-17) — fails on unmatched top-level `*/`
- [ ] Browser parse assertion for DEBT-05 (booted example, `getComputedStyle` / `document.styleSheets[].cssRules`)

*Existing ExUnit infrastructure covers the rest; no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex retire of published `1.20.0` | DEBT-04 (D-14) | External Hex service; local key is read-only; no web retire button; past grace window | Runbook for Jon: `mix hex.user key generate` → `mix hex.retire sigra 1.20.0 invalid --message "..."` (retire, NOT delete) |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
