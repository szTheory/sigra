---
phase: 46
slug: human-ga-matrix-gap-closure
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-21
---

# Phase 46 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Phase 46 is **manual UAT evidence + planning docs**; automated commands prove **machine baselines** only.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `mix.exs`, `config/test.exs` |
| **Quick run command** | `cd test/example && MIX_ENV=test mix test test/example/accounts/emails_security_html_test.exs` (needs Postgres; see `CLAUDE.md`) |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | Quick: ~30–120s (DB-dependent); full suite: minutes |

---

## Sampling Rate

- **After Wave 1 plan commits (GA-02 baseline):** Run quick email HTML test file; confirm exit 0.
- **After Wave 1 GA-03 task:** Run `mix test test/sigra/oauth/oauth_test.exs`.
- **After documentation-only edits:** `grep` acceptance criteria from plan tasks (no full suite required every commit).
- **Before `/gsd-verify-work`:** Full suite per project norm (`CLAUDE.md`).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 46-01-01 | 01 | 1 | GA-02 | T-46-01 | No secrets in evidence | unit + manual | `cd test/example && MIX_ENV=test mix test test/example/accounts/emails_security_html_test.exs test/example/accounts/emails_lifecycle_html_test.exs` | ✅ | ⬜ pending |
| 46-02-01 | 02 | 1 | GA-03 | T-46-02 | No OAuth secrets in repo | unit + manual | `MIX_ENV=test mix test test/sigra/oauth/oauth_test.exs` | ✅ | ⬜ pending |
| 46-03-01 | 03 | 1 | GA-04 | T-46-03 | Honest deviation logging | manual | _(witness protocol — steps.md)_ | ✅ | ⬜ pending |
| 46-04-01 | 04 | 2 | GA-05 | T-46-04 | Matrix matches evidence | grep / read | `grep -E "^\| GA-0[2-5] \|" .planning/v1.4-GA-UAT.md` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] Postgres reachable for example HTML tests (see `CLAUDE.md` docker one-liner).
- [ ] No new ExUnit files required — existing tests are the machine spine.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gmail / Outlook / Apple Mail rendering | GA-02 | MUAs are not headless in CI | Follow `GA-02/steps.md`; attach dated row in record table |
| Live Google OAuth | GA-03 | Needs real IdP | Follow `GA-03/steps.md`; env var names only in notes |
| Clean-machine getting-started | GA-04 | Human friction | Follow `GA-04/README.md` + `steps.md`; 60-day reviewer bar |

---

## Validation Sign-Off

- [ ] All tasks have grep- or test-verifiable acceptance criteria
- [ ] No watch-mode flags in plan verify blocks
- [ ] `nyquist_compliant: true` set in plan frontmatter where applicable
- [ ] Full suite green before human sign-off on phase

**Approval:** pending
