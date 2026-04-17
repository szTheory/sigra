# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library - Initial Release** - Phases 1-10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.1 Foundations** - Phases 11-23 (shipped 2026-04-16). See [v1.1 archive](milestones/v1.1-ROADMAP.md), [v1.1 requirements](milestones/v1.1-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **Post-v1.1 Closeout** - Phases 24-26 (completed 2026-04-16).
- 🚧 **v1.2 Admin Dashboard** - Phases 27-31 + gap closure 32-35 (in progress — audit-found gaps).

## Backlog

- [ ] **Phase 999.1: Retroactive Nyquist validation pass**
- [ ] **Phase 999.2: Dependabot major-version bumps cleanup**

## v1.2 Admin Dashboard

**Milestone Goal:** Ship an auth-first admin surface on the existing Phoenix/LiveView stack: secure admin access, mobile-friendly user operations, guarded impersonation, richer audit exploration, and automation-first review artifacts.

## Phases

**Phase Numbering:**
- Integer phases continue from prior milestone work.
- Decimal phases are reserved for urgent insertions.

- [x] **Phase 27: Admin Access Foundation** - Establish default-on admin wiring, explicit policy hooks, scope-safe route protection, and visible admin scope chrome. (completed 2026-04-16)
- [ ] **Phase 28: User Operations Surface** - Deliver searchable, filterable, mobile-friendly user management and detail flows for operator jobs-to-be-done.
- [x] **Phase 29: Secure Impersonation** - Add time-bounded impersonation with visible state, preserved admin actor context, and hard server-side restrictions. (completed 2026-04-17)
- [x] **Phase 30: Audit Exploration and Export** - Provide global, per-user, and per-organization audit investigation with impersonation-aware filtering and CSV export. (completed 2026-04-17)
- [x] **Phase 31: Automation-First Verification** - Ship browser, system, and artifact coverage for the admin milestone across desktop, mobile, and dark mode. (completed 2026-04-17)
- [ ] **Phase 32: Generated Installer Admin Surface Parity** - Close critical generator gaps so a freshly installed host ships a functional admin surface (closes INT-01/02/03 from v1.2 audit).
- [ ] **Phase 33: Admin Shell Navigation and Audit Preview Polish** - Port users nav + mobile bottom-nav to the generated shell and align Phase 28 recent-audit preview with Phase 30's Presenter (closes INT-04/05).
- [ ] **Phase 34: Generated-Host E2E Coverage and Phase 28 Retroactive Verification** - Produce the missing Phase 28 VERIFICATION.md and extend Playwright + smoke coverage to the generated host (closes VFY-01 generated-host gap + Phase 30 human-UAT #2).
- [ ] **Phase 35: Shift-Left Verification Automation** - Install machine gates for the classes of defects that caused v1.2 audit gaps: generator-emission drift, dead-reference detection, a11y + visual regression baselines, phase-VERIFICATION.md gate, installer-scoped pre-merge audit, and artifact-bundle contract.

## Phase Details

### Phase 27: Admin Access Foundation
**Goal**: Developers can install and trust an admin surface that is default-on, explicitly policy-driven, and scope-safe for both platform admins and org admins.
**Depends on**: Phase 26
**Requirements**: ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-04, ADMIN-05
**Success Criteria** (what must be TRUE):
  1. Developer can generate the admin surface by default and omit it with `--no-admin` without introducing a second frontend stack or third-party admin framework.
  2. Host app can declare platform-admin and org-admin policy decisions explicitly, and Sigra enforces those decisions server-side for admin pages, exports, and mutations.
  3. Org admins only see data and actions inside their allowed organization scope, while platform admins can enter cross-org views intentionally.
  4. Admin navigation and page chrome keep the active global or organization scope visible so operators can tell where actions apply.
**Plans**: 3 plans
Plans:
- [ ] 27-01-PLAN.md — Default-on admin installer feature and host boundary scaffolding
- [ ] 27-02-PLAN.md — Library-owned admin policy, scope resolution, and Plug/LiveView enforcement
- [ ] 27-03-PLAN.md — Example-app router/shell wiring and integration coverage for visible scope chrome
**UI hint**: yes

### Phase 28: User Operations Surface
**Goal**: Admins can quickly find a user, understand their auth state, and take the highest-value support actions from a mobile-friendly LiveView UI.
**Depends on**: Phase 27
**Requirements**: USER-01, USER-02, USER-03, USER-04, USER-05
**Success Criteria** (what must be TRUE):
  1. Admin can find users by email, id, name, or organization membership from searchable, paginated admin views.
  2. Admin can filter users by operational auth states including confirmation, MFA/passkeys, lockout, deletion, provider mix, and registration date range.
  3. Admin can open a user detail view that summarizes sessions, MFA/passkeys, linked identities, organizations, and recent audit activity in one place.
  4. Admin can revoke one session or all active sessions for a user from the admin UI with clear confirmation and recorded audit coverage.
  5. The core user-management workflows remain usable on mobile and desktop instead of collapsing into a desktop-only table.
**Plans**: 4 plans
Plans:
- [ ] 28-01-PLAN.md — Contracts, host hooks, example display-name support, and Wave-0 validation scaffolding
- [ ] 28-02-PLAN.md — Scope-safe searchable user index plus admin routing and shell navigation handoff
- [ ] 28-03-PLAN.md — User detail assembly and canonical session-revocation workflows
- [ ] 28-04-PLAN.md — Responsive polish, browser operator journey, and finalized Phase 28 validation
**UI hint**: yes

### Phase 29: Secure Impersonation
**Goal**: Admins can impersonate allowed users for support work without losing actor attribution, without nesting sessions, and without opening security-sensitive mutation paths.
**Depends on**: Phase 28
**Requirements**: IMPR-01, IMPR-02, IMPR-03, IMPR-04, IMPR-05
**Success Criteria** (what must be TRUE):
  1. Platform admins can start impersonation for allowed users through a controller-owned flow that rotates session state and preserves the original admin as the real actor.
  2. Org admins can impersonate only users inside their allowed organization scope, and denied attempts fail server-side with audit evidence.
  3. Every impersonation session is time-bounded, non-nestable, visibly marked with a persistent banner, and can always be ended from the UI.
  4. While impersonating, sensitive account-security mutations remain blocked server-side, including password, MFA/passkey, API-key, and account-deletion actions.
  5. Ending impersonation returns the admin to the original admin context without destroying the original admin session.
**Plans**: 5 plans
Plans:
- [ ] 29-01-PLAN.md — Library-owned impersonation runtime, dual-actor audit, and direct-path authorization
- [ ] 29-02-PLAN.md — Controller-owned start flow plus app-wide stop/restore routing and timeout handling in generated/example web code
- [ ] 29-03-PLAN.md — User-detail entry point plus persistent impersonation chrome in generated/example layouts
- [ ] 29-04-PLAN.md — Shared impersonation gate for blocked non-API-token sensitive operations across controllers, LiveViews, and direct-path calls
- [ ] 29-05-PLAN.md — Generated API-token seam guards and blocked-operation coverage during impersonation
**UI hint**: yes

### Phase 30: Audit Exploration and Export
**Goal**: Admins can investigate security and support history across global, user, and organization scopes using canonical dual-actor audit data and stable exports.
**Depends on**: Phase 29
**Requirements**: AUD-01, AUD-02, AUD-03, AUD-04
**Success Criteria** (what must be TRUE):
  1. Audit records for admin and impersonation workflows preserve real actor, effective user, organization scope, and impersonation context as first-class queryable fields.
  2. Admin can investigate audit history from global, per-user, and per-organization views with URL-addressable filters for actor, effective user, organization, action family, and time range.
  3. Admin can distinguish impersonation activity from normal user activity in the audit explorer without reading raw metadata blobs.
  4. Admin can export the currently filtered audit slice as stable, scope-respecting CSV evidence.
**Plans**: 4 plans
Plans:
- [ ] 30-01-PLAN.md — Canonical audit attribution fixes and shared normalized query contract
- [ ] 30-02-PLAN.md — Global and organization audit explorer surfaces plus generated/example navigation wiring
- [ ] 30-03-PLAN.md — Per-user audit explorer routes and Phase 28 recent-audit preview alignment
- [ ] 30-04-PLAN.md — Scope-safe CSV export plus controller and browser verification
**UI hint**: yes

### Phase 31: Automation-First Verification
**Goal**: The admin milestone is proven by automation and review artifacts, with browser and non-browser coverage that makes UX and authorization regressions easy to inspect asynchronously.
**Depends on**: Phase 30
**Requirements**: VFY-01, VFY-02, VFY-03, VFY-04
**Success Criteria** (what must be TRUE):
  1. Critical admin workflows including user search/detail, session revocation, impersonation start/stop, and audit filtering/export are covered by automated browser and system checks.
  2. Reviewers can inspect Playwright HTML reports, screenshots, traces, and retained video artifacts to assess admin UX progress without heavy manual walkthroughs.
  3. Authorization, scope, impersonation, and export rules are verified through direct-path smoke coverage outside the browser happy path.
  4. CI artifacts make mobile and dark-mode regressions visible for the admin UI before release.
**Plans**: 4 plans
Plans:
- [ ] 31-01-PLAN.md — Partition the Playwright admin harness and generated-host parity smoke
- [ ] 31-02-PLAN.md — Complete example-app admin browser journeys and curated checkpoint artifacts
- [ ] 31-03-PLAN.md — Extend direct-path verification and thin runtime parity smoke
- [ ] 31-04-PLAN.md — Publish dedicated admin review artifacts and retention in CI
**UI hint**: yes

### Phase 32: Generated Installer Admin Surface Parity
**Goal**: A freshly generated host ships a functional admin surface. Generator emits UsersIndexLive/UserShowLive router mounts, an ImpersonationController template, and wires the orphaned audit_export_controller template — closing the three CRITICAL integration blockers surfaced by the v1.2 milestone audit.
**Depends on**: Phase 31
**Requirements**: USER-01, USER-02, USER-03, USER-04, IMPR-01, IMPR-03, IMPR-05, AUD-04 (reassigned from Phases 28/29/30 for generated-host reachability)
**Gap Closure**: Closes INT-01, INT-02, INT-03 from v1.2-MILESTONE-AUDIT.md
**Success Criteria** (what must be TRUE):
  1. `router_injection.ex` mounts UsersIndexLive + UserShowLive in both global and organization-scoped live_session blocks, mirroring `test/example/lib/example_web/router.ex:237-272`.
  2. `priv/templates/sigra.install/admin/impersonation_controller.ex` exists as a parameterized template and is emitted by `Sigra.Install.Features.Admin.files/1`.
  3. `priv/templates/sigra.install/admin/audit_export_controller.ex` is listed in `Sigra.Install.Features.Admin.files/1` (currently orphaned).
  4. Generator test asserts all three emissions and fails if any regresses.
**Plans**: 2 plans
Plans:
- [ ] 32-01-PLAN.md — Template emission + router injection (INT-01/02/03 unit-level closure)
- [ ] 32-02-PLAN.md — admin-acceptance-smoke.sh runtime probes (Nyquist integration gate)
**UI hint**: no

### Phase 33: Admin Shell Navigation and Audit Preview Polish
**Goal**: The generated admin shell's Users navigation becomes a live link with a mobile bottom-nav entry (matching the example app), and Phase 28's recent-audit preview renders consistently with Phase 30's explorer via the shared Presenter.
**Depends on**: Phase 32
**Requirements**: USER-05 (mobile bottom-nav), supports USER-01/03 UX parity
**Gap Closure**: Closes INT-04 (dead Users nav) and INT-05 (preview bypasses Presenter) from v1.2-MILESTONE-AUDIT.md
**Success Criteria** (what must be TRUE):
  1. Generated `admin_shell.ex` template includes `users_link/1` helper, top-bar Users entry, and mobile bottom-nav entry ported from `test/example/lib/example_web/components/admin_shell.ex:52-60,98-102`.
  2. `Sigra.Admin.Users.Detail.recent_audit_preview/*` pipes events through `Sigra.Admin.Audit.Presenter.present/2` so impersonation badges and actor labels match the Phase 30 explorer rendering.
**UI hint**: yes

### Phase 34: Generated-Host E2E Coverage and Phase 28 Retroactive Verification
**Goal**: Produce the missing Phase 28 VERIFICATION.md and extend generated-host E2E coverage to include user operations, impersonation, and audit export — closing the VFY-01 generated-host parity gap and automating Phase 30 human-UAT item #2.
**Depends on**: Phase 33
**Requirements**: VFY-01 (generated-host coverage portion; reassigned from Phase 31)
**Gap Closure**: Closes the Phase 28 VERIFICATION.md gap + Phase 30 human-UAT item #2 (generated-app runtime parity for audit routes and CSV export)
**Success Criteria** (what must be TRUE):
  1. `28-VERIFICATION.md` exists and documents Phase 28 goal achievement against the live codebase.
  2. `admin-generated.spec.ts` exercises `GET /admin/users`, `POST /impersonation`, and `GET /admin/audit/export.csv` on the freshly generated host with strict status expectations.
  3. `admin-acceptance-smoke.sh` grows `--test audit-export` and `--test impersonation-controller` cases, wired into the `generated_admin_playwright_smoke` CI job.
**UI hint**: no (test/artifact work)

### Phase 35: Shift-Left Verification Automation
**Goal**: Install the machine gates that would have caught INT-01/02/03/04 before the audit. Automate the remaining mechanically-verifiable human-verification items so future milestone audits surface only genuinely subjective review items.
**Depends on**: Phase 34
**Requirements**: None reassigned — adds net new coverage on top of existing VFY reqs
**Gap Closure**: Prevents future recurrence of INT-01..04 defect classes; closes Phase 30 human-UAT item #1 (audit explorer readability) and Phase 31 human-UAT item #1 (artifact bundle usefulness)
**Success Criteria** (what must be TRUE):
  1. `generator_emission_audit_test.exs` scans all `priv/templates/sigra.install/**` for `<%= web_module %>.*` references and asserts every referenced module is in its feature's `files/1` emission list.
  2. Extended `installer_drift_test.exs` catches dead-text navigation labels (INT-04 class).
  3. axe-core accessibility assertions + Playwright `toHaveScreenshot()` baselines exist for the 5 curated checkpoint views across chromium/mobile/dark.
  4. `scripts/ci/milestone-verification-gate.sh` blocks PRs that leave a phase in the active milestone without a `{N}-VERIFICATION.md`.
  5. Installer-scoped milestone-audit CI job runs on PRs touching `priv/templates/sigra.install/` or `lib/sigra/install/` and fails on CRITICAL integration blockers.
  6. Artifact-bundle contract asserts all 15 expected PNGs (5 views × 3 projects) exist above a size floor; reviewer checklist documented in `CONTRIBUTING.md`.
**UI hint**: no (CI + test infrastructure)

## Progress

**Execution Order:**
Phases execute in numeric order: 27 -> 28 -> 29 -> 30 -> 31 -> 32 -> 33 -> 34 -> 35

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 27. Admin Access Foundation | 3/3 | Complete   | 2026-04-16 |
| 28. User Operations Surface | 4/4 | In Progress (gap closure pending) |  |
| 29. Secure Impersonation | 5/5 | Complete    | 2026-04-17 |
| 30. Audit Exploration and Export | 4/4 | Complete    | 2026-04-17 |
| 31. Automation-First Verification | 4/4 | Complete   | 2026-04-17 |
| 32. Generated Installer Admin Surface Parity | 0/2 | Planned |  |
| 33. Admin Shell Navigation and Audit Preview Polish | 0/0 | Pending |  |
| 34. Generated-Host E2E Coverage and Phase 28 Retroactive Verification | 0/0 | Pending |  |
| 35. Shift-Left Verification Automation | 0/0 | Pending |  |
