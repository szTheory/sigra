# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library — Initial Release** — Phases 1–10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md) for full details.
- 🚧 **v1.1 Foundations** — Phases 11–23 (Organizations + Passkeys). Started 2026-04-11.

## Phases

<details>
<summary>✅ v1.0 Phoenix Auth Library — Initial Release (Phases 1–10.1.1) — SHIPPED 2026-04-11</summary>

- [x] Phase 1: Foundation (3/3 plans) — completed 2026-04-05
- [x] Phase 2: Core Auth (2/2 plans) — completed 2026-04-06
- [x] Phase 3: Email Flows and Transactional Email (6/6 plans) — completed 2026-04-07
- [x] Phase 4: Session Management and Security Baseline (6/6 plans) — completed 2026-04-08
- [x] Phase 5: OAuth and Social Login (3/3 plans) — completed 2026-04-08
- [x] Phase 6: Multi-Factor Authentication (5/5 plans) — completed 2026-04-08
- [x] Phase 7: API Authentication (4/4 plans) — completed 2026-04-09
- [x] Phase 8: Account Lifecycle (5/5 plans) — completed 2026-04-08
- [x] Phase 9: Audit Logging (5/5 plans) — completed 2026-04-09 (PASS-WITH-CAVEATS; see SEED-002)
- [x] Phase 10: Developer Experience (6/6 plans) — completed 2026-04-10
- [x] Phase 10.1: Installer and Library Fixes (INSERTED, 7/7 plans) — completed 2026-04-10
- [x] Phase 10.1.1: example-app repair + CI install/usage smoke harness (INSERTED, 8/8 plans) — completed 2026-04-11

**Full details:** [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

### 🚧 v1.1 Foundations — Organizations + Passkeys

- [x] **Phase 11: Generator Feature System** — subdirectory + behaviour manifest; mechanical move of v1.0 templates into `core/` (completed 2026-04-11, verified 13/13 must-haves — PR #7 / commit 4efb4a5; ROADMAP checkbox retroactively ticked 2026-04-15)
- [x] **Phase 12: Scope + Session Foundation** — `%Scope{}` gets `:active_organization` + `:membership` + reserved `:impersonating_from`; `user_sessions.active_organization_id` column (completed 2026-04-12)
- [x] **Phase 13: Organizations Schemas + Context** — `Organization` / `OrganizationMembership` / `OrganizationInvitation` schemas + `Sigra.Organizations` context with raising `for_org/2` helper + last-owner guard (completed 2026-04-12)
- [x] **Phase 14: Org Plugs + Scope Hydration** — `LoadActiveOrganization` / `RequireMembership` plugs + LV `on_mount` hydration + stale-pointer handling (completed 2026-04-12)
- [x] **Phase 15: Audit Integration** — real `organization_id` + `effective_user_id` columns on `audit_events`, `metadata_from_scope/2` assembly point, `Sigra.Workers` behaviour (completed 2026-04-13)
- [x] **Phase 16: Org LiveViews + Switcher** — `OrganizationSwitcherLive` / `OrganizationSettingsLive` / `OrganizationMembersLive` + POST-switch controller + 0/1/2+ org login handling
- [x] **Phase 17: Invitation Flow + Email** — email-locked HMAC-bound invite acceptance + `organization_invitation_email` template + rate-limited creation (INV-08 cross-tenant IDOR gap in `Sigra.Organizations.Invitations.revoke/3` closed by plan 17-09, re-verified 2026-04-14 status: passed 10/10) (completed 2026-04-14)
- [x] **Phase 18: Backfill + `--organizations` Generator Wiring** — `mix sigra.upgrade --backfill-personal-orgs` + `--no-organizations` opt-out + combinatorial smoke test + upgrade test fixture (completed 2026-04-14)
- [ ] **Phase 19: Passkey Schema + Contexts** — `wax_` dep + `UserPasskey` Cloak-encrypted schema + `Sigra.Passkeys.{Registration,Authentication}` + credential-confusion + sign-count monotonicity
- [ ] **Phase 20: Passkey Challenge Plug + Runtime Config + JS Hooks Infra** — `PasskeyChallenge` plug (Plug-session 60s TTL) + runtime RP ID config + `passkey_hooks.js` generator injection
- [ ] **Phase 21: Passkey LiveViews + POST-Auth Controller** — sudo-gated `PasskeyEnrollmentLive` + `PasskeyAuthenticationLive` + POST login controller + registration email + conditional UI + duplicate detection
- [ ] **Phase 22: `--passkeys` Generator Wiring** — `--no-passkeys` opt-out validated against feature manifest pattern
- [ ] **Phase 23: Docs, CI Smoke, Upgrade Guide** — `getting-started.md` update + 3 new guides + Playwright org + passkey specs + `mix docs` clean + testing helpers

## Phase Details

### Phase 11: Generator Feature System
**Goal**: Developer running `mix sigra.install` on a fresh Phoenix app gets v1.0 output byte-identical to 10.1.1, but the templates now live under a `core/` subdirectory driven by a `Sigra.Install.Feature` behaviour — the seam that makes organizations, passkeys, and (v1.2) admin purely additive.
**Depends on**: Nothing (v1.1 foundation phase)
**Requirements**: GEN-01, GEN-02, GEN-04, GEN-05, GEN-07
**Pitfalls addressed**: X-1 (generator partial-apply), X-2 (migration ordering), X-3 (template drift)
**v1.2 load-bearing**: subdir + feature manifest pattern is the exact seam v1.2 `--no-admin` consumes; getting it wrong forces a retrofit.
**Success Criteria** (what must be TRUE):
  1. Developer can run `mix sigra.install --yes` on a fresh `mix phx.new` project and the resulting app compiles, boots, and passes the existing v1.0 HTTP smoke routes with zero content diff vs phase 10.1.1 output.
  2. Developer can re-run `mix sigra.install --yes` on an already-installed project and the generator skips existing files + already-present injections without erroring (idempotent per GEN-04).
  3. Post-install summary output shows a clear table of generated / modified / skipped / manual-action files (GEN-05), and migrations are emitted with strictly-ordered timestamps so cross-feature ordering hazards cannot arise at install or upgrade time (GEN-07).
  4. `priv/templates/sigra.install/core/` contains every v1.0 template file with zero content drift; `Sigra.Install.Feature` behaviour is implemented by `Sigra.Install.Features.Core` with `enabled?/1` always returning true.
**Plans:** 6/6 plans complete
Plans:
- [x] 11-01-PLAN.md — Wave 0: Golden-diff harness + pre-refactor snapshot capture (GEN-02)
- [x] 11-02-PLAN.md — Wave 1: Feature behaviour + %Injection{} struct + Report + MigrationTimestamps primitives (GEN-01, GEN-05, GEN-07)
- [x] 11-03-PLAN.md — Wave 2: Mechanical template relocation into core/ subdirectory (GEN-02)
- [x] 11-04-PLAN.md — Wave 3: Features.Core extraction owning v1.0 files, injections, migrations, instructions (GEN-01, GEN-02)
- [x] 11-05-PLAN.md — Wave 4: Walker refactor + idempotency proof (GEN-01, GEN-04, GEN-05, GEN-07)
- [x] 11-06-PLAN.md — Wave 5: V-PA-01 purely-additive + V-ISOLATION-01 guardrails + VALIDATION.md finalize (GEN-01)

### Phase 12: Scope + Session Foundation
**Goal**: `%Scope{}` and the `user_sessions` row carry the fields every org-aware and (v1.2) impersonation-aware plug needs, with zero business logic attached — a mechanical data-shape extension.
**Depends on**: Phase 11
**Requirements**: ORG-SCOPE-01, ORG-SCOPE-02
**Pitfalls addressed**: O-5 (cross-org session confusion setup), O-6 (stale pointer prep)
**v1.2 load-bearing**: reserved `%Scope{impersonating_from: nil}` field means v1.2 impersonation pattern matches are purely additive; `user_sessions.active_organization_id` is the single source of truth v1.2 impersonation also piggybacks on.
**Success Criteria** (what must be TRUE):
  1. Developer can pattern-match `%Scope{active_organization: org, membership: m, impersonating_from: from}` in generated `user_auth.ex` without a compile warning; generator template emits all three fields.
  2. Running `mix sigra.install --yes` produces a migration that adds `active_organization_id :binary_id` nullable on `user_sessions`, and the example app's session fixture inserts succeed with the new column unset.
  3. Fresh install's session serialization round-trips the new session column: logging in, writing an arbitrary `active_organization_id` via `Sigra.Session`, reading it back via `Plug.Conn.get_session/2` all work end-to-end.
**Plans:** 4/4 plans complete
Plans:
- [x] 12-01-PLAN.md — Wave 1: Sigra.Session struct + SessionStore.Ecto round-trip (ORG-SCOPE-02 library half)
- [x] 12-02-PLAN.md — Wave 1: :active_org_column feature manifest slot + new ALTER migration template (ORG-SCOPE-02 generator half)
- [x] 12-03-PLAN.md — Wave 1: Generated Scope/UserSession templates + reserved-field invariant test + UPGRADE-v1.2.md (ORG-SCOPE-01)
- [x] 12-04-PLAN.md — Wave 2: Golden-diff rebase + example app mirror + D-14 end-to-end round-trip (integration gate)

### Phase 13: Organizations Schemas + Context
**Goal**: `Sigra.Organizations` is a complete, hazard-safe data layer — schemas, queries, context functions — with the cross-tenant leak, last-owner lockout, and cascade-destroys-audit-log pitfalls wired in as executable tests from day one.
**Depends on**: Phase 12
**Requirements**: ORG-01, ORG-03, ORG-04, ORG-05, ORG-06, ORG-07, ORG-08
**Pitfalls addressed**: O-1 (cross-tenant leak), O-4 (last-owner lockout + admin-deletes-owner escalation), O-9 (slug squatting), O-10 (cascade wipes audit log)
**v1.2 load-bearing**: `admin` in the hardcoded reserved slug list prevents `/admin` collision when v1.2 ships; soft-delete orgs + `audit_events.organization_id → :nilify_all` means v1.2 audit feed survives org deletion.
**Success Criteria** (what must be TRUE):
  1. Developer can call `Sigra.Organizations.Query.for_org(Post, scope)` and get a scoped query; calling it on a schema without `:organization_id` raises at compile or first-call time (layer 1 of the O-1 defense).
  2. Attempting to remove, demote, or self-delete the last owner of an organization returns `{:error, :last_owner}` from inside a single `Ecto.Multi` (not a DB constraint) with a fresh-count read inside the same transaction.
  3. Creating an organization with a reserved slug (`admin`, `api`, `www`, `static`, and the ~20-entry reserved list) returns a changeset error; every reserved word has a regression test.
  4. Soft-deleting an organization sets `deleted_at`, leaves the row in-place, and audit rows referencing it survive with `organization_id` nilified via `on_delete: :nilify_all` FK config.
  5. The time-boxed Credo custom-check spike for tenant-scope discipline either ships (≤300 lines) or falls back to integration-test-only enforcement with a documented CONVENTIONS.md entry (DX-09).
**Plans:** 3/3 plans complete
Plans:
- [x] 13-01-PLAN.md — Wave 1: Schema templates + migration template + Features.Organizations + Scope typespec (ORG-01, ORG-03, ORG-04)
- [x] 13-02-PLAN.md — Wave 2: for_org/2 tenant scoping + prepare_query/3 enforcement + Slug validation (ORG-06, ORG-07)
- [x] 13-03-PLAN.md — Wave 3: Sigra.Organizations context + use macro + NimbleOptions + last-owner guard + audit (ORG-05, ORG-08)

### Phase 14: Org Plugs + Scope Hydration
**Goal**: Every authenticated request — Plug pipeline or LiveView — lands at its handler with `current_scope.active_organization` correctly populated, stale session pointers gracefully reset, and org-required routes blocked for non-members with a clear error.
**Depends on**: Phase 12, Phase 13
**Requirements**: ORG-SCOPE-03, ORG-SCOPE-04, ORG-SCOPE-05, ORG-SCOPE-06
**Pitfalls addressed**: O-5 (cross-org session confusion), O-6 (stale pointer 500)
**Success Criteria** (what must be TRUE):
  1. User whose session `active_organization_id` points at an org they were removed from is silently reset to "no active org" (scope.active_organization = nil) instead of getting a 500 — stale-pointer regression test proves it.
  2. User hitting a route guarded by `Sigra.Plug.RequireMembership` without an active org is redirected to the "pick or create an org" landing page; user with the wrong role (when `roles: [:owner]`) is redirected to an access-denied page.
  3. LiveView `on_mount` and the Plug path produce byte-identical `current_scope` values for the same session state — parity test covers both login, switch, and stale-pointer cases.
  4. User logging in with zero orgs lands on the create/accept landing page; one org is auto-selected; 2+ resumes the most-recent non-nil `active_organization_id` (per-session, not per-user) or shows the picker.
**Plans**: 6 plans
- [ ] 16-01-PLAN.md — Wave 1: library foundations (rename/update_slug/soft_delete/list_members/count_members + force-logout Multi + slug_alias schema + LoadOrganizationFromSlug plug + OrganizationScope on_mount)
- [ ] 16-02-PLAN.md — Wave 1: switcher component + POST switch controller + Features.Organizations manifest + router scope block + user_auth on_mount + thin wrapper
- [ ] 16-03-PLAN.md — Wave 2: OrganizationsLive.Index (3 render branches) + OrganizationsLive.New + Slug.generate + signup→zero-org flow
- [ ] 16-04-PLAN.md — Wave 2: OrganizationSettingsLive (General/Slug/Danger zone, inline sudo, progressive disclosure, typed-confirms)
- [x] 16-05-PLAN.md — Wave 2: OrganizationMembersLive (table + role/remove modals, last-owner surfacing, force-logout DB assertion, Phase 17 stub) (completed 2026-04-14)
- [ ] 16-06-PLAN.md — Wave 3: integration — instantiate templates + paste switcher + end-to-end integration test + 16-VALIDATION.md sign-off + human visual checkpoint
**UI hint**: yes

### Phase 15: Audit Integration
**Goal**: Every security-relevant write emitted through `Sigra.Audit.log/*` carries `organization_id` and `effective_user_id` on real indexed columns — not JSONB — so v1.2 per-org and impersonation audit views become trivial filter additions.
**Depends on**: Phase 14
**Requirements**: AUD-01, AUD-02, AUD-03, AUD-04, AUD-05
**Pitfalls addressed**: O-7 (audit misattribution under IMP+), O-11 (worker runs without tenant context)
**v1.2 load-bearing**: `audit_events.organization_id` and `effective_user_id` as real indexed columns (not JSONB) are the exact shape v1.2 views require; `metadata_from_scope/2` is the single assembly point v1.2 impersonation extends; `Sigra.Workers` behaviour is the contract v1.2 worker audits rely on.
**Success Criteria** (what must be TRUE):
  1. Generator emits a migration adding `organization_id :binary_id` (nullable, indexed, `on_delete: :nilify_all`) and `effective_user_id :binary_id` (nullable, indexed) as real columns on `audit_events`; library-emitted password-reset audits outside org context land cleanly with `organization_id` null.
  2. Every existing v1.0 audit call site that assembled metadata routes through `Sigra.Audit.metadata_from_scope/2`; the helper has a documented reserved-comment block for v1.2 `effective_user_id = scope.impersonating_from` population.
  3. `Sigra.Audit.Query` gains an `:organization_id` filter backed by the real column; an index hit-count test proves it uses the index.
  4. `Sigra.Workers` behaviour enforces that workers accept `args["organization_id"]` + `args["actor_id"]`, reconstruct a minimal `%Scope{}` in `perform/1`, and emit audits through `metadata_from_scope`; an existing v1.0 worker is refactored to the behaviour as the reference implementation.
  5. In v1.1, `effective_user_id` is populated identically to `user_id` on every audit row — v1.2 divergence (impersonator vs target) is purely additive.
**Plans:** 3/3 plans complete
Plans:
- [x] 15-01-schema-helper-sweep-PLAN.md — Wave 1: ALTER migration + log_safe/3 + Query extension + Sigra.Scope.build/3 + mechanical 79-site sweep (AUD-01..03, AUD-05)
- [x] 15-02-semantic-workers-credo-PLAN.md — Wave 2: session.create reorder + semantic enrichment + Sigra.Workers behaviour + AccountDeletion refactor + Credo check + assert_audit_logged (AUD-02..05)
- [x] 15-03-generator-fixtures-changelog-PLAN.md — Wave 3: Generator manifest + install-golden regen + example app regen + CHANGELOG + Postgres EXPLAIN index-hit test (AUD-01, AUD-03)

### Phase 16: Org LiveViews + Switcher
**Goal**: User experiences the full organization UX end-to-end in the example app — switching orgs, creating them, managing settings, viewing members, changing roles, inviting pending members — with the last-owner guard and sudo gates enforced in the UI as tightly as they are in the context.
**Depends on**: Phase 13, Phase 14, Phase 15
**Requirements**: ORG-UX-01, ORG-UX-02, ORG-UX-03, ORG-UX-04, ORG-UX-05, ORG-UX-06, ORG-UX-07, ORG-UX-08, ORG-UX-09
**Pitfalls addressed**: O-5 (switcher-driven session confusion)
**Success Criteria** (what must be TRUE):
  1. User can create a new organization from the example app UI, get a slug auto-generated with reserved-word rejection, and land inside the org as an owner.
  2. User can switch the active organization via the header dropdown; switching POSTs to a plain controller (not a LV event), rotates the Plug session's `active_organization_id`, and redirects to the referrer — matching v1.0's sensitive-mutation-via-POST D-29 convention.
  3. Organization owner can rename, change the slug (with sudo + typed confirmation + 7-day redirect), and soft-delete the organization (sudo + typed org-name confirmation); non-owner attempts return 403 at the plug layer, not just the UI.
  4. Organization owner/admin can view the member list, change a member's role with a confirmation step, and remove a member — which revokes the membership row and force-logs-out that user's org-scoped sessions in the same `Ecto.Multi`.
  5. Signup flow offers an optional "create your first organization" step; no auto-personal-org is created on registration (ORG-UX-09 / Jetstream #117 lesson).
**Plans**: 6 plans
- [x] 16-01-PLAN.md — Wave 1: library foundations (rename/update_slug/soft_delete/list_members/count_members + force-logout Multi + slug_alias schema + LoadOrganizationFromSlug plug + OrganizationScope on_mount)
- [x] 16-02-PLAN.md — Wave 1: switcher component + POST switch controller + Features.Organizations manifest + router scope block + user_auth on_mount + thin wrapper
- [x] 16-03-PLAN.md — Wave 2: OrganizationsLive.Index (3 render branches) + OrganizationsLive.New + Slug.generate + signup→zero-org flow
- [x] 16-04-PLAN.md — Wave 2: OrganizationSettingsLive (General/Slug/Danger zone, inline sudo, progressive disclosure, typed-confirms)
- [x] 16-05-PLAN.md — Wave 2: OrganizationMembersLive (table + role/remove modals, last-owner surfacing, force-logout DB assertion, Phase 17 stub)
- [x] 16-06-PLAN.md — Wave 3: integration — instantiate templates + paste switcher + end-to-end integration test + Playwright browser smoke (replaces human visual checkpoint) + 16-VALIDATION.md sign-off
**UI hint**: yes
**Status**: ✅ COMPLETE — verified 2026-04-13 (VERIFICATION.md PASS, 9/9 ORG-UX requirements, 5/5 Success Criteria)

### Phase 17: Invitation Flow + Email
**Goal**: Organization owners/admins can invite users by email through a replay-safe, email-bound HMAC flow that closes the Jetstream #907 / Keycloak CVE-2026-1529 class of invite-hijack bugs by construction, not by convention.
**Depends on**: Phase 16
**Requirements**: INV-01, INV-02, INV-03, INV-04, INV-05, INV-06, INV-07, INV-08, INV-09, INV-10
**Pitfalls addressed**: O-2 (invite hijack), O-3 (invite replay)
**Success Criteria** (what must be TRUE):
  1. Owner or admin can invite a user by email via `OrganizationMembersLive`; token is generated by `Sigra.Token` HMAC, SHA-256-hashed in storage, and expires at 7d (configurable via NimbleOptions with a dev-only warning above 30d).
  2. Invitee with no account signs up through a form that pre-fills and locks the email; membership creation is atomic with user confirmation inside one `Ecto.Multi` (O-2 path A).
  3. Invitee signed in as a different user (case-insensitive via citext) gets an explicit "this invitation is for [other-email]" mismatch page with no accept button — never a silent takeover (O-2 Jetstream #907 regression test covers this).
  4. Accepting an invite marks `accepted_at` inside the Multi; replay attempts return a clear "already accepted" flash; revoked invites return "no longer valid"; rate-limited invite creation (20/day/user via Hammer) rejects abuse.
  5. Pending-invite list shows email, role, invited-by, expires-in, and a revoke button that transitions the row to `revoked_at`.
**Plans**: 9 plans
- [x] 17-01-PLAN.md — Wave 1: extract register_user_multi + add_member_multi + invitation fixtures + Swoosh test mailer config (Nyquist scaffolding)
- [x] 17-02-PLAN.md — Wave 2: Sigra.Token invite envelope helpers + @org_config_schema NimbleOptions keys (incl. url_builder) + hashed_token UNIQUE migration
- [x] 17-03-PLAN.md — Wave 3: Sigra.Organizations.Invitations module (create/2, revoke/3, list_pending/2, list_pending_for_user/2) + Hammer rate-limit wiring + CleanupExpiredInvitations Oban worker (D-11)
- [x] 17-04-PLAN.md — Wave 3: organization_invitation_email.ex generator template + emails.ex/auth_mailer.ex registration (HTML-escaped multipart)
- [x] 17-05-PLAN.md — Wave 4: verify_and_load/2 + accept/3 (signed-in-match path) + accept_with_signup/3 (composed Multi) + Pow #534 regression
- [x] 17-06-PLAN.md — Wave 4: fill OrganizationMembersLive invite modal + pending-invitations section + revoke modal/handlers (Phase 16 stub replacement)
- [x] 17-07-PLAN.md — Wave 5: InvitationAcceptLive 7 render branches + Jetstream #907 regression + replay + citext regression tests + 17-VALIDATION.md sign-off
- [x] 17-08-PLAN.md — Wave 2 (sidecar): Phase 16 slug-alias migration IMMUTABLE-safe hotfix (Open Q4 RESOLVED, independent of main path)
- [x] 17-09-PLAN.md — Gap closure: INV-08 scope `revoke/3` lookup to `actor_scope.active_organization.id` via Ecto query; cross-tenant probes collapsed to `{:error, :not_found}` (re-verified passed 10/10 on 2026-04-14; ROADMAP checkbox retroactively ticked 2026-04-15)
**UI hint**: yes

### Phase 18: Backfill + `--organizations` Generator Wiring
**Goal**: Developer upgrading a v1.0 app to v1.1 can run the upgrade with or without backfill and reach a working app on the other side, with a boot-tested upgrade fixture proving it; `--no-organizations` produces a zero-org install that compiles clean.
**Depends on**: Phase 17
**Requirements**: ORG-02, ORG-UPGRADE-01, ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03 (org-axis slice)
**Pitfalls addressed**: O-8 (backfill idempotency), X-1 (combinatorial partial-apply — org axis), X-2 (migration ordering), X-4 (upgrade crashes)
**Success Criteria** (what must be TRUE):
  1. `mix sigra.install --no-organizations` produces a Phoenix app that compiles, boots, and passes the HTTP smoke suite with zero org-related schemas, routes, templates, or context modules generated.
  2. `mix sigra.upgrade --backfill-personal-orgs` on a v1.0 install is idempotent, batched, adapter-branched (PG/MySQL/SQLite), and safe to re-run; re-running does not create duplicate memberships.
  3. `mix sigra.upgrade` without the flag leaves existing users in the "create or accept invite" state on next login — no 500s, no dead ends, nil-guarded template accessors verified by boot test.
  4. Repository ships `test/upgrade_test.exs` that boots a v1.0 install, runs the v1.1 upgrade in both backfill-on and backfill-off paths, and asserts login still works in each path (X-4 regression lock).
  5. CI org-axis matrix (install with `--organizations` and `--no-organizations`) compiles and boots clean on every PR.
**Plans**: 3 plans
- [x] 18-01-foundation-schema-and-flag-PLAN.md — Wave 1: bake owner_user_id + personal into fresh-install organizations migration template; register Features.Organizations + forward organizations? binding; create_organization/3 sets owner_user_id (ORG-02)
- [x] 18-02-upgrade-task-and-backfill-PLAN.md — Wave 2: Sigra.Upgrade orchestrator + Sigra.Upgrade.Backfill library (keyset NOT EXISTS + insert_all on_conflict :nothing + telemetry) + mix sigra.upgrade Mix task + 3 upgrade templates + version sentinel injection (ORG-UPGRADE-01)
- [x] 18-03-upgrade-test-fixture-and-ci-matrix-PLAN.md — Wave 2: InstallFixture run_sigra_install/run_sigra_upgrade helpers + test/upgrade_test.exs (backfill-on + backfill-off) + CI install_matrix job (ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03)

### Phase 19: Passkey Schema + Contexts
**Goal**: `Sigra.Passkeys` is a correct, credential-confusion-safe, monotonic-sign-count data layer around `wax_ ~> 0.7`, with Cloak-encrypted public keys reusing the v1.0 OAuth vault — no new encryption infra, no new migration hazards.
**Depends on**: Phase 11 (parallel with phase 13 onwards)
**Requirements**: PK-01, PK-03, PK-04, PK-05, PK-07, PK-08
**Pitfalls addressed**: P-4 (sign-count false positives), P-6 (StrongKey CVE-2025-26788 credential confusion)
**Spike required at kickoff**: 30-min Context7 verify of `Wax.Challenge` struct shape + `aaguid` return type in `wax_ 0.7`; 2-4 hour `WaxJson` bridge validation against SimpleWebAuthn vectors (research flag from SUMMARY.md).
**Success Criteria** (what must be TRUE):
  1. `mix.exs` adds `{:wax_, "~> 0.7"}` and `mix deps.compile` is clean on OTP 27 / Elixir 1.18; `UserPasskey` schema has `credential_id` unique+indexed (unencrypted) and `public_key` encrypted via the existing `Sigra.Vault` Cloak pipeline.
  2. `Sigra.Passkeys.register/3` and `authenticate/3` wrap `wax_` correctly — register stores `rp_id` on the `UserPasskey` row at registration time (P-3 prep), authenticate verifies the returned `credential_id` belongs to the requested user (P-6 StrongKey defense) and rejects mismatch before any further processing.
  3. Sign-count regression handling defaults to `:warn` (log + audit event `:passkey_sign_count_regression` + banner affordance); `:require_reauth` and `:revoke` modes are selectable via NimbleOptions and each has a regression test.
  4. `Sigra.Passkeys.{list_for_user, rename, delete}` have passing unit tests covering the happy path + missing-credential error case.
**Plans**: TBD

### Phase 20: Passkey Challenge Plug + Runtime Config + JS Hooks Infra
**Goal**: WebAuthn challenges are server-generated, server-stored in the signed+encrypted Plug session, and server-verified — making the OneUptime GHSA-gjjc-pcwp-c74m replay class impossible — and the JS hooks scaffolding that binds SimpleWebAuthn to LiveView ships with runtime-configured RP ID + graceful `app.js` injection.
**Depends on**: Phase 19
**Requirements**: PK-06, PK-09, PK-10, GEN-06
**Pitfalls addressed**: P-1 (challenge replay — OneUptime CVE), P-3 (RP ID rotation), P-8 (JS hook abort/timeout/cancel)
**Spike required at kickoff**: Plug session cookie size sanity check under 60s TTL with passkey challenge payload (<4KB ceiling) + `assets/js/app.js` injection-target detection on a non-default esbuild layout.
**Success Criteria** (what must be TRUE):
  1. Challenge is generated via `Sigra.Token.generate/4` with purpose `"sigra-passkey-challenge"` and `max_age: 60`, stored only in the Plug session, verified on response, and deleted on successful verify; `clientDataJSON` is never trusted as a challenge source (P-1 regression test covers the replay attempt).
  2. `Sigra.Passkeys.config/0` loads `rp_id`, `rp_name`, `origin`, `attestation` (default `:none`), `user_verification` (default `:preferred`), and `timeout_ms` from runtime config; NimbleOptions fast-fails on first use if unset or malformed.
  3. Per-user passkey ceremony rate limiter via Hammer (default 5/min) rejects the 6th attempt in the same minute with a clear error — regression test proves the key shape.
  4. Generator injects `passkey_hooks.js` import + hook registration into `assets/js/app.js` when the marker comment is present; when absent (custom esbuild/Vite/Webpack), generator writes the hook file, skips injection, and prints exact manual instructions — no silent failure (GEN-06).
**Plans**: 6 plans
- [ ] 16-01-PLAN.md — Wave 1: library foundations (rename/update_slug/soft_delete/list_members/count_members + force-logout Multi + slug_alias schema + LoadOrganizationFromSlug plug + OrganizationScope on_mount)
- [ ] 16-02-PLAN.md — Wave 1: switcher component + POST switch controller + Features.Organizations manifest + router scope block + user_auth on_mount + thin wrapper
- [ ] 16-03-PLAN.md — Wave 2: OrganizationsLive.Index (3 render branches) + OrganizationsLive.New + Slug.generate + signup→zero-org flow
- [ ] 16-04-PLAN.md — Wave 2: OrganizationSettingsLive (General/Slug/Danger zone, inline sudo, progressive disclosure, typed-confirms)
- [ ] 16-05-PLAN.md — Wave 2: OrganizationMembersLive (table + role/remove modals, last-owner surfacing, force-logout DB assertion, Phase 17 stub)
- [ ] 16-06-PLAN.md — Wave 3: integration — instantiate templates + paste switcher + end-to-end integration test + 16-VALIDATION.md sign-off + human visual checkpoint
**UI hint**: yes

### Phase 21: Passkey LiveViews + POST-Auth Controller
**Goal**: User can enroll and authenticate with passkeys end-to-end in the example app — as a second factor today and optionally as a primary factor — with the stolen-session enrollment, lost-device lockout, and JS-abort-corruption classes of bugs closed at the plug and hook layers.
**Depends on**: Phase 20
**Requirements**: PK-UX-01, PK-UX-02, PK-UX-03, PK-UX-04, PK-UX-05, PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-09, PK-UX-10, PK-UX-11, PK-UX-12
**Pitfalls addressed**: P-2 (stolen-session enrollment takeover), P-5 (lost-device lockout), P-8 (JS abort/timeout), P-9 (duplicate-device 500)
**v1.2 load-bearing**: passkey enrollment lives in the v1.2 "locked-down ops" list — the plug-layer `RequireSudo` gate here is what prevents v1.2 impersonator from enrolling their own passkey as the target.
**Success Criteria** (what must be TRUE):
  1. User can enroll a passkey from account settings only after passing `Sigra.Plug.RequireSudo` (password or TOTP re-auth); enrollment emits an audit event and sends the v1.0 suspicious-login-shaped email with device hint, IP, city, time (P-2 defense).
  2. User can log in via passkey as a second factor alongside TOTP on `MfaSettingsLive`; passkey list shows AAGUID-derived friendly names (iCloud Keychain, Google Password Manager, 1Password, Windows Hello) from a bundled registry; user can rename or delete passkeys (delete sudo-gated), with a soft cap of 10 per user.
  3. User with `:passkey_primary_enabled` config can log in with email + passkey without a password; every passkey-as-primary user has mandatory magic-link recovery that cannot be disabled (P-5 lockout defense).
  4. Login completion POSTs to a plain controller (never a LV event) to rotate the Plug session, matching v1.0 D-29; Conditional UI / autofill ships feature-detected (unsupported browsers degrade to explicit click); duplicate-credential-id returns "already registered" instead of 500; JS hook cleanly handles browser abort, timeout, user cancel, and AbortController tear-down from LV `destroyed()`.
**Plans**: 6 plans
- [ ] 16-01-PLAN.md — Wave 1: library foundations (rename/update_slug/soft_delete/list_members/count_members + force-logout Multi + slug_alias schema + LoadOrganizationFromSlug plug + OrganizationScope on_mount)
- [ ] 16-02-PLAN.md — Wave 1: switcher component + POST switch controller + Features.Organizations manifest + router scope block + user_auth on_mount + thin wrapper
- [ ] 16-03-PLAN.md — Wave 2: OrganizationsLive.Index (3 render branches) + OrganizationsLive.New + Slug.generate + signup→zero-org flow
- [ ] 16-04-PLAN.md — Wave 2: OrganizationSettingsLive (General/Slug/Danger zone, inline sudo, progressive disclosure, typed-confirms)
- [ ] 16-05-PLAN.md — Wave 2: OrganizationMembersLive (table + role/remove modals, last-owner surfacing, force-logout DB assertion, Phase 17 stub)
- [ ] 16-06-PLAN.md — Wave 3: integration — instantiate templates + paste switcher + end-to-end integration test + 16-VALIDATION.md sign-off + human visual checkpoint
**UI hint**: yes

### Phase 22: `--passkeys` Generator Wiring
**Goal**: Developer running `mix sigra.install --no-passkeys` gets a zero-passkey install; combinatorial install matrix (orgs × passkeys) compiles clean — validating the Phase 11 feature-manifest pattern on its second consumer.
**Depends on**: Phase 21, Phase 11
**Requirements**: PK-02
**Pitfalls addressed**: X-1 (partial-apply — passkey axis + combinatorial)
**Success Criteria** (what must be TRUE):
  1. `mix sigra.install --no-passkeys` produces a Phoenix app that compiles, boots, and passes the HTTP smoke suite with zero passkey schemas, contexts, plugs, LiveViews, JS hooks, or `wax_` runtime references generated (and no `@simplewebauthn/browser` added to `assets/package.json`).
  2. CI combinatorial matrix runs the four `--(no-)organizations × --(no-)passkeys` combinations on every PR and each produces a compiling, booting app.
  3. `Sigra.Install.Features.Passkeys` drops into the feature manifest alongside Core and Organizations with no special-casing in `sigra.install.ex` beyond registration — proving the Phase 11 pattern holds for a second feature.
**Plans**: TBD

### Phase 23: Docs, CI Smoke, Upgrade Guide
**Goal**: Developer landing on `getting-started.md` fresh can go from `mix phx.new` to a working multi-tenant Phoenix app with passkey login in under 30 minutes; developer upgrading from v1.0 has a clear, tested path; CI catches regressions in org + passkey flows via Playwright.
**Depends on**: Phase 18, Phase 22
**Requirements**: DX-01, DX-02, DX-03, DX-04, DX-05, DX-06, DX-07, DX-08, DX-09
**Pitfalls addressed**: X-4 (upgrade docs gap), P-3 (RP ID rename operational playbook), P-10 (ceremony rate DoS documentation), P-11 (recovery fallback docs)
**Success Criteria** (what must be TRUE):
  1. `getting-started.md` has an "Organizations & Passkeys" section that walks a developer from `mix phx.new` to a working multi-tenant app with passkey login; a human follow-along spike completes in under 30 minutes end-to-end.
  2. Three new guides ship under `guides/`: `upgrading-to-v1.1.md` (both backfill modes + breaking-change callouts + upgrade test invocation), `how-to/multi-tenancy.md` (logical MT model + `for_org/2` discipline + why schema-per-tenant is rejected), and `how-to/passkeys.md` (enrollment + primary-mode config + RP ID rename playbook + recovery guidance). `mix docs --warnings-as-errors` stays clean.
  3. Generated testing helpers (`create_organization/1`, `create_membership/3`, `log_in_user_with_org/3`, `register_passkey/2`, `authenticate_with_passkey/2`) and library helpers in `Sigra.Testing` (`assert_scope_has_org/2`, `assert_membership/3`, `assert_audit_logged_for_org/2`) are exercised by their own unit tests.
  4. Playwright CI smoke harness extends to cover: organization switcher happy path, invitation-accept by both new signup and existing logged-in user, passkey registration, passkey authentication — all green on PRs.
**Plans**: 6 plans
- [ ] 16-01-PLAN.md — Wave 1: library foundations (rename/update_slug/soft_delete/list_members/count_members + force-logout Multi + slug_alias schema + LoadOrganizationFromSlug plug + OrganizationScope on_mount)
- [ ] 16-02-PLAN.md — Wave 1: switcher component + POST switch controller + Features.Organizations manifest + router scope block + user_auth on_mount + thin wrapper
- [ ] 16-03-PLAN.md — Wave 2: OrganizationsLive.Index (3 render branches) + OrganizationsLive.New + Slug.generate + signup→zero-org flow
- [ ] 16-04-PLAN.md — Wave 2: OrganizationSettingsLive (General/Slug/Danger zone, inline sudo, progressive disclosure, typed-confirms)
- [ ] 16-05-PLAN.md — Wave 2: OrganizationMembersLive (table + role/remove modals, last-owner surfacing, force-logout DB assertion, Phase 17 stub)
- [ ] 16-06-PLAN.md — Wave 3: integration — instantiate templates + paste switcher + end-to-end integration test + 16-VALIDATION.md sign-off + human visual checkpoint
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 11. Generator Feature System | 6/6 | Complete    | 2026-04-15 |
| 12. Scope + Session Foundation | 4/4 | Complete    | 2026-04-12 |
| 13. Organizations Schemas + Context | 3/3 | Complete    | 2026-04-12 |
| 14. Org Plugs + Scope Hydration | 3/3 | Complete    | 2026-04-12 |
| 15. Audit Integration | 3/3 | Complete    | 2026-04-13 |
| 16. Org LiveViews + Switcher | 0/? | Not started | — |
| 17. Invitation Flow + Email | 9/9 | Complete    | 2026-04-14 |
| 18. Backfill + `--organizations` Generator Wiring | 3/3 | Complete   | 2026-04-14 |
| 19. Passkey Schema + Contexts | 0/? | Not started | — |
| 20. Passkey Challenge Plug + Runtime Config + JS Hooks | 0/? | Not started | — |
| 21. Passkey LiveViews + POST-Auth Controller | 0/? | Not started | — |
| 22. `--passkeys` Generator Wiring | 0/? | Not started | — |
| 23. Docs, CI Smoke, Upgrade Guide | 0/? | Not started | — |

## Backlog

Unsequenced ideas parked for a future milestone. Promote via `/gsd-review-backlog` when the triggering milestone is defined.

### Phase 999.1: Retroactive Nyquist validation pass (BACKLOG)

**Goal:** Complete Nyquist validation contracts for the 6 phases whose `*-VALIDATION.md` files are still in `status: draft` with `nyquist_compliant: false`, and create the missing VALIDATION.md for phase 10.1. Produces audit-grade records for any future compliance review without blocking v1.0 shipment.
**Requirements:** TBD (no new REQ-IDs; remediation phase)
**Depends on:** v1.0 archived
**Plans:** 3/3 plans complete

**Scope (from v1.0 audit):**
- Phase 02 (core-auth) — VALIDATION.md draft, nyquist_compliant: false
- Phase 03 (email-flows) — VALIDATION.md draft, nyquist_compliant: false
- Phase 04 (session-mgmt) — VALIDATION.md draft, nyquist_compliant: false
- Phase 06 (mfa) — VALIDATION.md draft, nyquist_compliant: false
- Phase 07 (api-auth) — VALIDATION.md draft, nyquist_compliant: false
- Phase 09 (audit-logging) — VALIDATION.md draft, nyquist_compliant: false
- Phase 10.1 (installer-fixes) — no VALIDATION.md exists (remediation phase, never validated)

**Traceability:** `milestones/v1.0-MILESTONE-AUDIT.md` Section 6 "Nyquist Compliance" table.

**Notes:** Run `/gsd-validate-phase {N}` for each entry. Each phase should be a separate plan inside this single backlog phase. Total effort estimate: 3–5 hours. Not a v1.0 release blocker — the 1249-test suite + 5 CI smoke jobs + Playwright golden path provide functional coverage, this just closes out the formal sampling contracts.

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

### Phase 999.2: Dependabot major-version bumps cleanup (BACKLOG)

**Goal:** Review and safely land the 3 open Dependabot PRs that bump major versions of SHA-pinned GitHub Actions used across the 5 CI jobs. Major bumps require per-job CI verification because they can change default Node runtime, cache semantics, or artifact behavior.
**Requirements:** TBD
**Depends on:** v1.0 archived
**Plans:** 0 plans — promote with `/gsd-review-backlog` or handle as a v1.0.1 patch milestone

**Scope (open PRs as of 2026-04-11):**
- [szTheory/sigra#1](https://github.com/szTheory/sigra/pull/1) — actions/setup-node 4.0.4 → 6.3.0 (v5 dropped Node 16; v6 changed default cache behavior)
- [szTheory/sigra#3](https://github.com/szTheory/sigra/pull/3) — actions/upload-artifact 4.4.3 → 7.0.1 (v5 removed "upload to same name twice"; v6 changed compression defaults — this is the riskiest one)
- [szTheory/sigra#4](https://github.com/szTheory/sigra/pull/4) — actions/checkout 4.3.1 → 6.0.2 (v5 Node 20 default; v6 Node 22 default)

**Traceability:** IN-03 (SHA-pinned Actions from phase 10.1), `.github/dependabot.yml` config, `.github/workflows/ci.yml` action pin sites.

**Notes:** Do NOT merge blindly. Land each bump on its own commit, verify all 5 required CI checks pass on a PR, confirm upload-artifact behavior (failure trace upload in `example_playwright_smoke` is the most likely regression surface). Consider bundling into a v1.0.1 patch milestone alongside any post-GA hotfixes.

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

### Phase 24: Repair Phase 16/17 organizations generator templates

**Goal:** Fix pre-existing defects in Phase 16/17 organizations generator templates (DEF-18-01 and DEF-18-02) so that mix sigra.install --yes runs end-to-end without a template compile error, mix test test/sigra/install/ returns to a clean baseline, and Phase 18 Plan 18-03 (install CI matrix --yes leg) is unblocked.
**Requirements**: TBD
**Depends on:** Phase 23
**Plans:** 1/1 plans complete

Plans:
- [x] 24-01-repair-phase-16-17-org-templates-PLAN.md — DEF-18-01 dispatcher refactor + DEF-18-02 feature ownership move + 3 regression tests + golden rebless

### Phase 25: fix Sigra.Upgrade duplicate-migration-version bug and restore upgrade integration tests

**Goal:** Un-skip `Sigra.UpgradeIntegrationTest` (3 tests in `test/upgrade_test.exs`) by fixing the two latent bugs PR #9 (`63ea853`) surfaced when it renamed the shadowed integration module and unblocked its compilation.

**Context:** For ~5 months both `test/upgrade_test.exs` (353-line integration) and `test/sigra/upgrade_test.exs` (170-line unit) defined `Sigra.UpgradeTest`. In a full `mix test`, Elixir silently replaced the first module with the second — CI reported green while the integration file was dead code. PR #9 renamed the integration module to `Sigra.UpgradeIntegrationTest`, removed `--no-mailer` from the install fixture, injected `--allow-dirty` into `run_sigra_upgrade/2`, added `ecto.drop --force` to `seed_users!/2`, and quarantined the 3 integration tests with `@moduletag skip:` pointing at Bugs A + B below. This phase fixes both and un-skips the module.

**Requirements:**
- **Bug A (test-only, ~10 lines):** `organizations_table_exists?/1` at `test/upgrade_test.exs:221` calls `:erlang.binary_to_integer/1` on what is actually the concatenation of the echoed SQL query string and its result, because `mix run -e` emits the query trace alongside the `IO.puts` output. Needs a parser that extracts the last numeric line from `mix run -e` output — or better, a pattern that pipes the SQL through `Postgrex.query!` directly without going through `IO.puts` string scraping. Applies to sibling helpers `count_personal_orgs!/1` and any other `mix run -e | binary_to_integer` paths in the same file.
- **Bug B (real product bug in `Sigra.Upgrade`):** `mix sigra.upgrade` generates a migration file whose timestamp collides with the `mix sigra.install` migration when both tasks run back-to-back in the same second. Ecto rejects the resulting `priv/repo/migrations/` directory with `** (Ecto.MigrationError) migrations can't be executed, migration version NNNN is duplicated`. Fix requires reading `Sigra.Upgrade`'s migration-filename generator (`lib/sigra/upgrade.ex` or similar) and adding a monotonic tiebreaker — candidates: (1) use `System.unique_integer([:monotonic, :positive])` as a stable suffix; (2) inspect the existing `priv/repo/migrations/` directory and bump past the highest extant timestamp; (3) sleep until the next whole second before stamping. Option 2 is most robust (handles multi-task bursts without clock dependency) and mirrors how Ecto's own `mix ecto.gen.migration` picks timestamps.

**Depends on:** Phase 24

**Success criteria:**
1. Remove `@moduletag skip:` from `test/upgrade_test.exs` (the skip reason added by PR #9).
2. All 3 `Sigra.UpgradeIntegrationTest` tests pass locally against `sigra-uat-postgres` (zero-org path, default-org path, backfill path).
3. All 3 tests pass in the CI `library_tests` job against its `postgres:15` service.
4. New regression test in `test/sigra/upgrade_test.exs` (the unit file): running `Sigra.Upgrade`'s migration-timestamp generator twice in the same second produces two distinct, monotonically-increasing version prefixes.
5. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` reports `0 failures, 0 skipped` on `test/upgrade_test.exs`.
6. Full `mix test` locally and in CI stays green on every existing test.

**Plans:** 2/2 plans complete

Plans:
- [x] 25-01-PLAN.md — Bug B fix: scan-and-bump migration timestamps + unit regression test
- [x] 25-02-PLAN.md — Bug A fix: SIGRA_TEST_RESULT sentinel parser + un-skip Sigra.UpgradeIntegrationTest
