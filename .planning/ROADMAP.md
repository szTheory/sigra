# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library - Initial Release** - Phases 1-10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.1 Foundations** - Phases 11-23 (shipped 2026-04-16). See [v1.1 archive](milestones/v1.1-ROADMAP.md), [v1.1 requirements](milestones/v1.1-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **Post-v1.1 Closeout** - Phases 24-26 (completed 2026-04-16).
- 🚧 **v1.2 Admin Dashboard** - Phases 27-31 (planned).

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
- [ ] **Phase 29: Secure Impersonation** - Add time-bounded impersonation with visible state, preserved admin actor context, and hard server-side restrictions.
- [ ] **Phase 30: Audit Exploration and Export** - Provide global, per-user, and per-organization audit investigation with impersonation-aware filtering and CSV export.
- [ ] **Phase 31: Automation-First Verification** - Ship browser, system, and artifact coverage for the admin milestone across desktop, mobile, and dark mode.

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
**Plans**: TBD
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
**Plans**: TBD
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
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 27 -> 28 -> 29 -> 30 -> 31

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 27. Admin Access Foundation | 3/3 | Complete   | 2026-04-16 |
| 28. User Operations Surface | 2/4 | In Progress|  |
| 29. Secure Impersonation | 0/TBD | Not started | - |
| 30. Audit Exploration and Export | 0/TBD | Not started | - |
| 31. Automation-First Verification | 0/TBD | Not started | - |
