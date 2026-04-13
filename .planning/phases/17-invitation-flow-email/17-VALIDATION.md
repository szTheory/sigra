---
phase: 17
slug: invitation-flow-email
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Authored from 17-RESEARCH.md § Validation Architecture. Planner fills in the
> Per-Task Verification Map while emitting 17-01..17-NN-PLAN.md.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir ~> 1.18) |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~45–60 seconds (full Sigra suite); ~5–10 seconds for stale |

---

## Sampling Rate

- **After every task commit:** `mix test --stale`
- **After every plan wave:** `mix test` (full suite)
- **Before `/gsd-verify-work`:** Full suite green + `mix credo --strict` + `mix dialyzer`
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

*Planner: fill one row per task from 17-XX-PLAN.md files. Every INV-XX requirement
MUST appear in at least one row. Every <threat_ref> from the threat_model block
MUST appear in at least one row's "Threat Ref" column.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 0 | — | — | register_user_multi/1 is pure builder, no side effects | unit | `mix test test/sigra/auth_test.exs:register_user_multi` | ❌ W0 | ⬜ pending |
| 17-01-02 | 01 | 0 | — | — | add_member_multi/5 composes cleanly with Multi.append | unit | `mix test test/sigra/organizations_test.exs:add_member_multi` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 1 | INV-01 | T-17-01 | Only owners/admins can create invitations | integration | `mix test test/sigra/invitations_test.exs:authorization` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 1 | INV-02 | T-17-02 | Token is HMAC-bound to (org_id,email,role,nonce); SHA-256 hashed at rest | unit | `mix test test/sigra/token_test.exs:invitation_envelope` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 1 | INV-03 | T-17-03 | Default 7d expiry; NimbleOptions validates range; warn >30d | unit | `mix test test/sigra/config_test.exs:invitation_ttl` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 1 | INV-04 | T-17-04 | Hammer rejects 21st invite/day/user with clear error | integration | `mix test test/sigra/invitations_test.exs:rate_limit` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 2 | INV-05 | T-17-05 | Path A signup+accept runs inside single Ecto.Multi; rollback atomic | integration | `mix test test/sigra_web/live/invitation_accept_live_test.exs:path_a` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 2 | INV-06 | T-17-06 | Path B signed-in matching email inserts membership atomically | integration | `mix test test/sigra_web/live/invitation_accept_live_test.exs:path_b` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 3 | INV-06 | T-17-07 (Jetstream #907) | Path C mismatch renders mismatch branch with ZERO accept controls and ZERO DB writes | regression | `mix test test/sigra_web/live/invitation_accept_live_test.exs:jetstream_907` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 3 | INV-07 | T-17-08 | Replay: accepting twice returns "already accepted"; DB unchanged | regression | `mix test test/sigra/invitations_test.exs:replay` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 1 | INV-08 | T-17-09 | Revoke transitions revoked_at; revoked invite cannot be accepted | integration | `mix test test/sigra/invitations_test.exs:revoke` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 1 | INV-09 | — | list_pending/2 returns email, role, invited_by, expires_in for org | unit | `mix test test/sigra/invitations_test.exs:list_pending` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 1 | INV-10 | T-17-10 | Swoosh email delivered with correct template; inline fallback when Oban absent | integration | `mix test test/sigra/mailer_test.exs:invitation_email` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 3 | INV-06 | T-17-11 (citext) | Case-insensitive email compare at accept time (User@Ex.com == user@ex.com) | regression | `mix test test/sigra/invitations_test.exs:citext_case_insensitive` | ❌ W0 | ⬜ pending |
| 17-XX-XX | XX | 4 | all | all | Example-app end-to-end Playwright/LiveView harness — invite→email→accept | e2e | `mix test --only e2e test/example_app/invitation_flow_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/invitations_test.exs` — skeleton with describe blocks for all INV-XX
- [ ] `test/sigra_web/live/invitation_accept_live_test.exs` — 7-branch LiveView test scaffold (loading, mismatch, signup, accept_authed, already_accepted, revoked, expired)
- [ ] `test/support/fixtures/invitations_fixtures.ex` — `invitation_fixture/1`, `pending_invite/1`, `expired_invite/1`, `revoked_invite/1`
- [ ] `test/support/fixtures/organizations_fixtures.ex` — extend with `org_with_owner_and_admin/0` helper
- [ ] `config/test.exs` — ensure `Swoosh.Adapters.Test` mailer + `Hammer` test backend configured
- [ ] Regression fixtures capturing Jetstream #907 and Pow #534 scenarios (two distinct users, mismatch email, no SSO)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual inspection of invitation email rendering across clients (Gmail, Outlook, Apple Mail) | INV-10 | Email client rendering cannot be automated meaningfully | Human checkpoint: deliver invite in example-app dev mode, open Swoosh local preview, verify button/link/copy match UI-SPEC |
| Accessibility audit of `OrganizationMembersLive` invite modal + mismatch page | INV-09 | ARIA semantics for modal focus trap + screen reader announcement need human verification | Human checkpoint: tab navigation, VoiceOver/NVDA reading of modal, color contrast of mismatch page |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
