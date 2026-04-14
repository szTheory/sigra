---
phase: 17
slug: invitation-flow-email
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
updated: 2026-04-13
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Authored from 17-RESEARCH.md § Validation Architecture. Per-Task
> Verification Map populated from 17-01..17-08-PLAN.md (revision
> iteration 1).

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

One row per code-producing task across 17-01..17-08. Task IDs follow the
`{plan}-{task}` convention (e.g. `17-03-02` = Plan 17-03, Task 2).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 1 | — (W0 prereq for INV-05/06/07) | T-17-05 | `register_user_multi/1` is a pure Ecto.Multi builder — zero Repo calls during construction; composes via `Multi.append/2` | unit | `mix test test/sigra/auth_test.exs` | ❌ W0 | ⬜ pending |
| 17-01-02 | 01 | 1 | — (W0 prereq for INV-05/06/07) | T-17-05 | `add_member_multi/5` is a pure Ecto.Multi builder, composes cleanly with `register_user_multi/1` via `{:changes_key, :user}` | unit | `mix test test/sigra/organizations_test.exs` | ❌ W0 | ⬜ pending |
| 17-01-03 | 01 | 1 | — (W0 scaffolding) | — | Phase 17 test fixtures (`invitation_attrs/1`, `pending_invite/3`, `expired_invite/3`, `revoked_invite/3`, `accepted_invite/3`) + `org_with_owner_and_admin/2` + Swoosh test mailer in config/test.exs | unit (compile) | `mix compile --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 17-02-01 | 02 | 2 | INV-02 | T-17-02 | `Sigra.Token.generate_invite_envelope/2` + `verify_invite_envelope/3` — HMAC envelope binds email into payload via `Plug.Crypto.sign/4` with purpose `"sigra-org-invite-token"`; string-keyed map prevents atom flood; uniform `:invalid` errors prevent info leak; tamper/expire/garbage-base64/wrong-shape all rejected before DB touch | unit | `mix test test/sigra/token_test.exs` | ❌ W0 | ⬜ pending |
| 17-02-02 | 02 | 2 | INV-04 | T-17-03 | `@org_config_schema` adds `invitation_ttl` (default 7d), `invitation_rate_limit_per_user`, `invitation_rate_limit_per_org`, `invitation_cleanup_retention_days`, `emails_module`, `secret_key_base`, `url_builder`; `__warn_long_invitation_ttl__/1` emits Logger.warning when TTL > 30d | unit | `mix test test/sigra/organizations_test.exs` | ❌ W0 | ⬜ pending |
| 17-02-03 | 02 | 2 | INV-02 | T-17-02 | `organization_invitations.hashed_token` is UNIQUE (defense-in-depth against token-generation bugs); Phase 16 IS-NULL partial-unique pending index preserved | unit (grep) | `mix compile --warnings-as-errors && grep -n "unique_index(:organization_invitations, \\[:hashed_token\\])" priv/templates/sigra.install/organizations/migration.exs` | ❌ W0 | ⬜ pending |
| 17-03-01 | 03 | 3 | INV-01, INV-02, INV-04, INV-09 | T-17-01, T-17-02, T-17-04, T-17-05 | `Sigra.Organizations.Invitations.create/2` — owner/admin authorization (INV-01), HMAC-bound token + SHA-256 hashed storage (INV-02), dual-key Hammer rate limit user→org (INV-09), D-05 re-invite Multi atomicity, after-commit email delivery via `url_builder` callback, TTL warning on first use (INV-04) | integration | `mix test test/sigra/organizations/invitations_test.exs` | ❌ W0 | ⬜ pending |
| 17-03-02 | 03 | 3 | INV-08, INV-10 | T-17-08, T-17-09 | `revoke/3` state-guards against already-accepted/revoked (INV-08 + replay prevention); `list_pending/2` + `list_pending_for_user/2` return pending-only with email/role/invited-by/expires preloaded (INV-10 library half); Phase 16 stub at `list_pending_invitations_for_user/2` replaced with real delegation | integration | `mix test test/sigra/organizations/invitations_test.exs` | ❌ W0 | ⬜ pending |
| 17-03-03 | 03 | 3 | — (D-11 hygiene) | T-17-11 (retention) | `Sigra.Workers.CleanupExpiredInvitations` (optional Oban, `@behaviour Sigra.Workers`) hard-deletes `accepted_at IS NULL AND expires_at < now() - retention_days` rows; preserves accepted invitations as forensic history; inline-fallback `cleanup/3` direct-callable when Oban absent | unit | `mix test test/sigra/workers/cleanup_expired_invitations_test.exs` | ❌ W0 | ⬜ pending |
| 17-04-01 | 04 | 3 | INV-03 | T-17-10 (XSS) | `organization_invitation_email.ex` generator template — HTML + text multipart via Swoosh; every user-controllable field (`inviter.name`, `org.name`, `invitation.email`, `product_name`) escaped via `html_escape/1`; subject includes both inviter display name AND org name (phishing defense); "safely ignore" fine print present; CTA label `"Accept invitation"` locked | integration | `mix test test/example/test/example_web/emails/organization_invitation_email_test.exs` | ❌ W0 | ⬜ pending |
| 17-04-02 | 04 | 3 | INV-03 | T-17-10 | `emails.ex` + `auth_mailer.ex` generator templates register `organization_invitation/4` — callable via `apply(config.emails_module, :organization_invitation, [inv, org, inviter, accept_url])` from Plan 17-03's `create/2` | integration | `mix compile --warnings-as-errors && mix test test/example/test/example_web/emails/organization_invitation_email_test.exs` | ❌ W0 | ⬜ pending |
| 17-05-01 | 05 | 4 | INV-06, INV-07 | T-17-02 (DB re-check), T-17-06, T-17-08 (replay), T-17-11 (citext) | `verify_and_load/2` re-asserts `bound_email == downcase(db_row.email)` after DB lookup; `accept/3` signed-in-match path enforces case-insensitive `current_user.email == invitation.email`; Jetstream #907 mismatch → `{:error, :mismatch}` with ZERO DB writes; all 7 outcome branches (`:ok`, `:invalid`, `:expired`, `:revoked`, `:already_accepted`, `:mismatch`, `:not_found` collapsed to `:invalid`); replay returns `:already_accepted` (INV-07); no audit emission on non-transition branches | integration | `mix test test/sigra/organizations/invitations_test.exs` | ❌ W0 | ⬜ pending |
| 17-05-02 | 05 | 4 | INV-05 | T-17-05 (Pow #534) | `accept_with_signup/3` composes `register_user_multi → confirm_user → add_member_multi({:changes_key, :user}) → accept_invitation` in a single `Ecto.Multi` via `repo.transact/2`; Pow #534 regression test uses PINNED strategy — `FailingAcceptRepo` rejects the FINAL `:accept_invitation` update so prior Multi steps committed to the running transaction all roll back; server-side `:email_mismatch` guard defends against direct POST even when UI locks field | integration + regression | `mix test test/sigra/organizations/invitations_test.exs` | ❌ W0 | ⬜ pending |
| 17-06-01 | 06 | 4 | INV-01 | T-17-01, T-17-04 | `OrganizationMembersLive` invite-member modal — button enabled only for owner/admin; form submits to `create_invitation/1` delegator; library re-checks authorization; rate-limit user/org errors render flash with locked copy; `:already_member` renders inline field error | e2e (LiveView) | `mix test test/example/test/example_web/live/organization_members_live_test.exs` | ❌ W0 | ⬜ pending |
| 17-06-02 | 06 | 4 | INV-08, INV-10 | T-17-09 | Pending-invitations section renders all 5 columns (email, role, invited-by, expires-in, actions) via stream; revoke button `aria-label="Revoke invitation for {email}"` per row; revoke-confirm modal with locked copy; `confirm_revoke` handler wired to `revoke_invitation/2` delegator; non-admin members structurally hidden from revoke column; Phase 16 `<section id="pending-invitations-section">` id preserved (additive, zero file moves) | e2e (LiveView) | `mix test test/example/test/example_web/live/organization_members_live_test.exs` | ❌ W0 | ⬜ pending |
| 17-07-01 | 07 | 5 | INV-05, INV-06, INV-07 | T-17-06, T-17-07 (Jetstream #907) | `InvitationAcceptLive.mount/3` verifies signed token, assigns `:branch` atom in `[:signup, :accept, :mismatch, :invalid, :expired, :revoked, :already_accepted]`; router mounts `/invitations/:token/accept` OUTSIDE `:require_authenticated_user` pipeline; structural invariant enforced by grep — `:mismatch` branch contains ZERO `phx-click="accept*"` / `phx-submit="accept*"` / form action matches | e2e (LiveView) + regression | `mix test test/example/test/example_web/live/invitation_accept_live_test.exs` | ❌ W0 | ⬜ pending |
| 17-07-02 | 07 | 5 | INV-05, INV-06, INV-07 | T-17-06 (Jetstream #907), T-17-08 (replay), T-17-11 (citext) | Jetstream #907 regression test: alice signed in, accepts URL for bob → mismatch branch, zero accept DOM, zero DB writes, synthesized `render_click` raises ArgumentError (no such event in mismatch DOM); replay regression: accept twice → `:already_accepted`; citext regression: `User@Ex.com` accepts for `user@ex.com` | regression | `mix test test/example/test/example_web/live/invitation_accept_live_test.exs` | ❌ W0 | ⬜ pending |
| 17-08-01 | 08 | 2 | — (Phase 16 hotfix) | T-17-12 | Slug-alias migration predicate replaced with IMMUTABLE-safe index (Option A or B per consumer-code reading); Postgres `mix ecto.migrate` no longer raises `functions in index predicate must be marked IMMUTABLE`; Phase 16 slug-alias consumer tests still pass | unit + regression | `mix compile --warnings-as-errors && mix test test/sigra/plugs/load_organization_from_slug_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Coverage check

Every INV-XX requirement appears in ≥ 1 row:

- **INV-01** → 17-03-01 (library), 17-06-01 (UI)
- **INV-02** → 17-02-01 (token envelope), 17-02-03 (unique index), 17-03-01 (create/2 usage)
- **INV-03** → 17-04-01 (template), 17-04-02 (registration)
- **INV-04** → 17-02-02 (TTL config + warning), 17-03-01 (create/2 consumption)
- **INV-05** → 17-05-02 (`accept_with_signup/3` atomicity), 17-07-01, 17-07-02 (LV + regression)
- **INV-06** → 17-05-01 (`accept/3` + mismatch), 17-07-01, 17-07-02 (LV + Jetstream #907 regression)
- **INV-07** → 17-05-01 (`:already_accepted`), 17-07-01, 17-07-02 (replay regression)
- **INV-08** → 17-03-02 (`revoke/3`), 17-06-02 (UI)
- **INV-09** → 17-03-01 (Hammer dual-key rate limit)
- **INV-10** → 17-03-02 (`list_pending*` library), 17-06-02 (UI 5-column table)

All 10 INV requirements covered. 17-01 (Wave 0 prereq) and 17-08 (Phase 16 hotfix sidecar) carry `requirements: []` by design.

---

## Wave 0 Requirements

- [ ] `test/sigra/auth_test.exs` — extend with `describe "register_user_multi/1"` block (Plan 17-01 Task 1)
- [ ] `test/sigra/organizations_test.exs` — extend with `describe "add_member_multi/5"` block (Plan 17-01 Task 2)
- [ ] `test/support/fixtures/invitations_fixtures.ex` — new file with `invitation_attrs/1`, `pending_invite/3`, `accepted_invite/3`, `revoked_invite/3`, `expired_invite/3` (Plan 17-01 Task 3)
- [ ] `test/support/fixtures/organizations_fixtures.ex` — extend with `org_with_owner_and_admin/2` helper (Plan 17-01 Task 3)
- [ ] `config/test.exs` — ensure `Swoosh.Adapters.Test` mailer configured for example app (Plan 17-01 Task 3)
- [ ] `test/sigra/token_test.exs` — extend with `describe "generate_invite_envelope/2 + verify_invite_envelope/3"` block (Plan 17-02 Task 1)
- [ ] `test/sigra/organizations/invitations_test.exs` — new file with `describe "create/2" "revoke/3" "list_pending/2" "list_pending_for_user/2" "accept/3" "accept_with_signup/3"` blocks (Plans 17-03 + 17-05)
- [ ] `test/sigra/workers/cleanup_expired_invitations_test.exs` — new file (Plan 17-03 Task 3)
- [ ] `test/example/test/example_web/emails/organization_invitation_email_test.exs` — new file (Plan 17-04 Task 1)
- [ ] `test/example/test/example_web/live/invitation_accept_live_test.exs` — new file, 7-branch LV test scaffold (Plan 17-07)
- [ ] Regression fixtures capturing Jetstream #907 (Plan 17-07-02) and Pow #534 (Plan 17-05-02 — `FailingAcceptRepo` strategy)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual inspection of invitation email rendering across clients (Gmail, Outlook, Apple Mail) | INV-03 | Email client rendering cannot be automated meaningfully | Human checkpoint: deliver invite in example-app dev mode, open Swoosh local preview, verify button/link/copy match UI-SPEC |
| Accessibility audit of `OrganizationMembersLive` invite modal + mismatch page | INV-01, INV-10 | ARIA semantics for modal focus trap + screen reader announcement need human verification | Human checkpoint: tab navigation, VoiceOver/NVDA reading of modal, color contrast of mismatch page |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter (flipped during execution when Wave 0 tasks complete — see Plan 17-07 Task 3 for the sign-off handoff)

**Approval:** pending — execution-phase flips `nyquist_compliant: true` + `wave_0_complete: true` + records Approval date after Wave 0 files exist and Wave 5 (17-07) closes out the phase.
