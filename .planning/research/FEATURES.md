# Feature Research

**Domain:** Self-hosted auth/operator admin console — coherence/needs-led journey pass (v1.34)
**Researched:** 2026-06-03
**Confidence:** HIGH (all findings from direct source inspection)
**Scope:** Polish and coherence of the EXISTING 6-screen admin surface. No net-new surfaces.

---

## Framing: What "Coherent, Needs-Led" Means for This Domain

An operator lands the admin console because something happened. The session starts with a
situation — a locked user, a suspicious login, a support ticket, a compliance request —
not with curiosity about features. Coherent means: the journey from situation to action is
predictable everywhere, the same job is handled by the same component on every screen, and
nothing fights the operator's mental model. Needs-led means: every screen opens with verbs
("What do you need to do?"), not nouns (tables of data).

The two operator personas from the kickoff brief:
- **Platform Operator** (admin@, global scope): power user; jobs = find-and-fix user access, triage risk, investigate/export, verify posture, scope-switch to tenant.
- **Org Admin** (morgan@, single-org): Persona 1 minus global and minus cross-tenant. Jobs = support org members, manage roster/invitations, review org risk, pull org-scoped audit evidence.

---

## Table Stakes

Features operators expect from any admin console. Missing = product feels broken or incomplete.
Each row is tagged HAVE / PARTIAL / MISSING with screen-level evidence from direct file inspection.

| Feature | Why Expected | Complexity | Status | Screens Affected | Evidence |
|---------|--------------|------------|--------|-----------------|---------|
| Verb-first landing page (triage launcher, not BI dashboard) | Auth-ops is incident-driven; operators arrive with a job, not curiosity | LOW | PARTIAL | IndexLive, OrganizationLive | IndexLive has the H1 "What do you need to do?" and 3 task cards — correct instinct. But the needs-review alarm is buried below the task cards inside the posture strip card. OrganizationLive has a separate "Scoped attention" card that duplicates the alarm. The alarm should be the loudest single element, not a stripe inside a card. |
| Single needs-review alarm (loud if >0, "all clear" if 0) | Risk triage must be impossible to miss; one number, one deep-link | LOW | PARTIAL | IndexLive, OrganizationLive | Both screens compute `needs_review` and render a `sg-status-pill data-tone=risk/ok`. In IndexLive it is inside `.sg-posture-strip__risk` inside the posture-strip card, visually competing with 6 metric links. In OrganizationLive a second alarm inside a `.sg-card.sg-stack--3` duplicates it at a different visual weight. Neither screen makes the alarm the primary visual element above the task grid. |
| Master-detail spine: Overview to List to Detail with identical header anatomy | Operators learn one page shape; nav is predictable | MEDIUM | PARTIAL | All 6 screens | Overview (IndexLive/OrganizationLive), List (UsersIndexLive), Detail (UserShowLive/AuditIndexLive/AuditUserLive) exist but differ in header structure. UserShowLive wraps its identity section in `sg-card` (boxed), while all other screens use open `sg-page-header`. Back-nav only exists on UserShowLive and AuditUserLive (bespoke inline button), not on the List. |
| Consistent back-navigation component | Operators deep-link into detail and must return exactly where they came from | LOW | PARTIAL | UserShowLive, AuditUserLive | Both screens have a back button, but as inline bespoke HEEx (no shared component). Neither the List nor the Overview has an equivalent. `return_to` round-tripping exists and works. |
| In-body scope indicator (persistent throughout nested pages) | When operating org-scoped, operators need visual confirmation they are bounded | LOW | MISSING | All 6 screens | A small `sg-muted sg-text-sm` scope string appears in UserShowLive (line 94) and AuditUserLive (line 66), but only as plain text, not as a persistent visual component. No shared scope ribbon or badge exists. IndexLive has no scope indicator at all. OrganizationLive shows the org name only in the H1. |
| Applied filter chips with individual remove and "clear all" | Standard filter UX; operators must see and remove filters without re-filling the form | LOW | HAVE | UsersIndexLive, AuditIndexLive, AuditUserLive | All three filter screens implement `sg-applied-chip` with per-key remove links and a "Clear all" button. Component is private to each LiveView (duplicated 3x). |
| Empty state: informative, not a blank hole | First-run and filter-no-match states need guidance | LOW | HAVE | UsersIndexLive, AuditIndexLive, AuditUserLive | All three use `sg-empty-state` with context-specific messages for the two cases (no data vs filtered-to-nothing). Component is not shared. |
| Loading skeleton / async mount feedback | Users expect visual feedback during data load; blank content flashes feel broken | LOW | MISSING | All 6 screens | `.sg-skeleton` is defined in app.css but is used by zero LiveViews. All screens mount synchronously; no skeleton is shown during initial load. |
| Status display: one component, consistent tones across all screens | Status must carry meaning, not decoration; same tone must mean the same thing everywhere | LOW | PARTIAL | All 6 screens | `sg-status-pill` with `data-tone` is used everywhere (correct). But tone assignment for org member roles in OrganizationLive uses `"info"` for both owner and admin — identical tone, different semantic weight. Minor but inconsistent. |
| Pagination with orientation readout | Operators need to know where they are in large result sets | LOW | PARTIAL | UsersIndexLive, AuditIndexLive, AuditUserLive | UsersIndexLive has "Showing X-Y of Z" + "Page N of M". AuditIndexLive and AuditUserLive show only "Page N" (cursor-based pagination, so total count is unavailable — this is a pagination model difference, not a gap to fix). Component is private to each screen. |
| Primary action at consistent location per archetype | Operators learn the action placement once, use it everywhere | LOW | PARTIAL | UserShowLive, UsersIndexLive | UsersIndexLive places "Open user" in a right-aligned column. UserShowLive danger-zone places "Start impersonation" and "Revoke all sessions" inline in a cluster. No shared primary-action placement rule is enforced. |
| Destructive action: confirmation before irreversible mutations | Session revocation is consequential; operators must not fat-finger it | MEDIUM | HAVE | UserShowLive | `confirm_action` state machine gates revoke_session and revoke_all_sessions behind a confirmation step. Pattern is inline, not shared as a component. |
| Notice/alert component for in-page contextual warnings | Transient states (locked, deletion-scheduled) need callout, not just status pills | LOW | PARTIAL | UserShowLive | `summary_alert/1` renders a `sg-list-row` with `data-tone` for locked/deletion states. `sg-list-row` is a structural primitive, not a semantic notice component. No shared `<.notice tone=>` component exists. |

---

## Differentiators

Features that elevate the experience from "functional" to "coherent and delightful." These are
what distinguishes Sigra's admin console as an evaluator-facing showcase surface.

| Feature | Value Proposition | Complexity | Status | Screens Affected | Evidence |
|---------|-------------------|------------|--------|-----------------|---------|
| Needs-led landing with verbs-first task cards (not feature matrix) | Evaluators and operators form a positive first impression; the GOV.UK model proves this reduces support-ticket confusion | LOW | PARTIAL | IndexLive, OrganizationLive | Task cards exist and are well-written. The capability matrix ("What Sigra can do" — 7-item grid) competes equally with them at the same visual weight. Kickoff brief specifies: demote capability matrix to lowest priority. |
| Posture strip as metric-deep-links, demoted below task cards | Every metric is an entry point into a filtered list — a power pattern experienced operators discover and use | LOW | HAVE | IndexLive, OrganizationLive | Both screens implement `metric_link` components linking to filtered list views. Pattern is correct; it just needs consistent visual hierarchy (posture strip below tasks, not adjacent). |
| Scope-aware dual-persona (global vs org) from a single IA | One coherent console serves both personas, not forked dashboards | MEDIUM | HAVE | All 6 screens | Both scopes share the same LiveViews, with `admin_scope`-conditional rendering and routing. Clean and correct. |
| Command palette (Cmd-K) as cross-skill accelerator | Power operators use keyboard; novices use sidebar; both are served without compromise | MEDIUM | HAVE (shell) | AdminShell | Cmd-K infrastructure exists in AdminShell. Per IA-JOURNEY-SYNTHESIS: ensure it surfaces actions + entities, not just routes. This milestone audits usage, not re-implements. |
| Org roster with roles, lock state, confirmation state, and pending invitations | Org admin needs member overview in one click, not buried in a user list | LOW | HAVE | OrganizationLive | `@members` and `@pending_invitations` rendered with role pills, locked state, confirmed state, expired invite tone. Gap: member roster rows have no link to open the user detail from the roster. |
| Per-user audit explorer with its own filter set and return-to back-nav | Investigators working a support ticket need a bounded, exportable view of exactly one user's history | MEDIUM | HAVE | AuditUserLive | Full filter set, applied chips, CSV export, `return_to` round-tripping. Mobile layout gap: table-only (same gap as AuditIndexLive). |
| Audit row tone system (risk/info/neutral zebra) | Scannable timelines; failure events pop without visual noise on routine rows | LOW | HAVE | AuditIndexLive, AuditUserLive, UserShowLive (recent audit panel) | All three use identical `row_tone` logic. Failure outcome = risk, impersonation badge = info, routine success = neutral. Consistent and correct. |
| Mobile-responsive users list (card fallback) | Operators work from phones during incidents; mobile must be usable | MEDIUM | HAVE | UsersIndexLive | Desktop table + mobile card layout with `sg-show-desktop` / `sg-show-mobile`. Correct pattern for other screens to mirror. |
| Return-to round-trip preserving full filter state | Operators deep-link to a user, take action, and land back exactly where they were | LOW | HAVE | UsersIndexLive to UserShowLive (back) | `open_user_path` encodes current filter params into `return_to`. UserShowLive decodes and sanitizes it. AuditUserLive also uses `return_to`. Pattern works end-to-end. |

---

## Anti-Features

Features to explicitly NOT build in this milestone (and why).

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Net-new admin surfaces (API-token/service-account management UI) | Out of scope per locked milestone brief; adds surface area before coherence is solved | Track as future milestone |
| Top-level nav restructure (adding or removing nav rungs) | Breaks existing Playwright baselines, ruptures operator mental model, high re-work cost | Keep Overview to List to Detail spine; make existing rungs consistent |
| New `sg-*` CSS token additions | Token layer is mature at ~89 properties; adding without usage governance creates future drift | Audit usage of existing tokens; produce governance document, not new primitives |
| New motion primitives | Emil Kowalski compliance is already achieved in the token layer; adding primitives before usage is governed creates inconsistency | Audit motion USAGE on the existing 6 screens; fix no-animation on keyboard-frequent actions (filter apply, row selection) |
| Role-based admin forking (separate dashboards per persona) | Diverges code and mental models; scope-conditional rendering already serves both personas cleanly | Single LiveView with scope-conditional emphasis — already the right pattern |
| Broad Playwright behavior-matrix expansion | The goal is covering the Overview/UserAudit baseline gaps, not expanding what behaviors are tested | ADD checkpoints: `global-overview`, `org-overview`, `user-audit`; do not widen behavior matrix |
| Passive capability matrix as primary landing content | Feature inventory on landing fights the needs-led pattern; evaluators see a wall of labels, not a front door | Demote to a collapsed secondary disclosure section or remove from primary viewport |

---

## Component Inventory: Same Job, Same Component

The central coherence artifact for v1.34. Every recurring job across the 6 screens must map
to exactly ONE canonical component. All of these should live in a new lib-owned
`Sigra.Admin.Components` module.

| Job | Current State | Canonical Component Needed | Where Duplicated Today |
|-----|--------------|---------------------------|------------------------|
| Display a scalar stat with a deep-link | `metric_link` in IndexLive (private), byte-identical `metric_link` in OrganizationLive (private), non-linking `summary_chip` in UsersIndexLive | One shared `stat_link/3` (linked variant) + `stat/2` (non-linking variant) | IndexLive lines 118-125, OrganizationLive lines 169-176 (identical), UsersIndexLive lines 336-343 |
| Verb-first task card with primary CTA | `task_card` in IndexLive (private), byte-identical `task_card` in OrganizationLive (private) | One shared `task_card/4` | IndexLive lines 132-144, OrganizationLive lines 183-195 (identical) |
| Applied filter chip with remove | Private HEEx block in UsersIndexLive, AuditIndexLive, AuditUserLive | One shared `applied_chip/3` | All three filter screens |
| Empty state (no data or filtered-no-match) | Private `sg-empty-state` HEEx blocks in UsersIndexLive, AuditIndexLive, AuditUserLive | One shared `empty_state/2` (title + body slot) | Three screens, each with two cases |
| Back navigation consuming return_to | Bespoke inline button in UserShowLive (line 91-94), AuditUserLive (lines 63-66) | One shared `page_back/2` (label + href) | UserShowLive, AuditUserLive |
| In-body scope indicator | Plain `sg-muted sg-text-sm` text span in UserShowLive (line 94), AuditUserLive (line 66); absent on other screens | One shared `scope_ribbon/1` consuming `admin_scope` | UserShowLive, AuditUserLive; MISSING from IndexLive, OrganizationLive, UsersIndexLive, AuditIndexLive |
| Contextual notice/alert for in-page warnings | `sg-list-row` with `data-tone` in UserShowLive (lines 131-133) via `summary_alert/1` | One shared `notice/3` (tone + title + body) | UserShowLive only; no other screen has an equivalent |
| Loading skeleton | `.sg-skeleton` defined in CSS but unused in any LiveView | One shared `skeleton/1` (height/width) for async mount states | ALL 6 screens (none use it today) |
| Status pill (single state label) | `sg-status-pill` with `data-tone` — used consistently across all screens | KEEP as-is; document tone assignment rules in governance doc | Tone assignments mostly correct; minor inconsistency on org role tones (owner + admin both "info") |
| Destructive action confirmation | Inline state machine + bespoke HEEx in UserShowLive (`confirm_action` assign) | Extract to a shared `confirm_modal/3` pattern | UserShowLive only today |

---

## Seed Data: What Each Screen Must Show to Be Self-Demonstrating

Existing personas: admin, alice, bob, carol, dave, frank, morgan. Orgs: Acme Corp, Beta Labs.
Per-screen audit of which states must be present and which are MISSING from current seeds.

### IndexLive (Global Overview)

HAVE states: needs_review > 0 (dave locked, frank deletion-scheduled), confirmed/MFA/passkeys/locked/deleted counts all non-zero across personas.

Seed gaps: NONE for primary demonstration. The alarm renders "2 accounts need review" (dave + frank), which is the correct self-demonstrating state.

### OrganizationLive (Org Overview via morgan, Acme scoped)

HAVE states: org with varied roles (admin=owner, morgan=admin, alice/carol/dave=member), locked member in org (dave), unconfirmed member (dave), pending invitation (invited@demo.sigra.dev).

Seed gaps:
1. MISSING: An **expired invitation** (expires_at in the past). Seeds only seed a future-dated invite. `OrganizationLive` renders `data-tone="risk"` on expired invitations. Without one, the "Expired" pill on the org overview never renders in the demo. Add an expired invitation to Acme with `expires_at` in the past.
2. MISSING: A member with **scheduled_deletion** visible in the Acme roster. Frank has `scheduled_deletion: true` but is NOT in any org. `OrganizationLive` renders `member.locked?` and `member.confirmed?` but not deletion-scheduled — however, getting frank into Acme would demonstrate his state on the user detail pivot. Simplest fix: add frank to Acme membership in seeds. Low-impact.

### UsersIndexLive (Users List, Global)

HAVE states: confirmed, unconfirmed (dave), TOTP MFA (admin, bob), passkey (admin), MFA+passkeys combined (admin), no MFA (neutral pill), locked (dave), deletion-scheduled (frank), GitHub OAuth (carol), multi-org membership (admin in Acme+Beta), last-active date (admin has 3 sessions).

Seed gaps:
1. MISSING: A user with **multiple OAuth providers** (e.g. github + google). The "Provider: Google" filter never matches any user today. Add a Google identity to carol or another persona.
2. MISSING: A **passkey-only user** (passkey without TOTP). Admin has both. The "Passkeys" status pill (without the MFA pill) never renders alone. Add `passkey: true` to a persona with `totp: false` — alice or morgan are the cleanest candidates.
3. PARTIAL: Pagination is always single-page (7 users). Pagination nav renders with both arrows disabled. Not a blocking gap for demonstration, but the "Showing 1-7 of 7 users" readout is accurate.

### UserShowLive (User Detail, admin persona is richest)

HAVE states: identity panel (confirmed, display_name, email, ID), TOTP MFA enrolled, passkey with nickname ("Demo Security Key"), 3 active sessions (multi-session table), security summary facts, 2 org memberships with pivot links, GitHub identity (carol), recent audit with impersonation and failure tone rows, summary_alert for locked (dave) and deletion-scheduled (frank), danger-zone impersonation + revoke buttons.

Seed gaps:
1. MISSING: A user with **only a passkey, no TOTP**. Admin has both. To show the Passkeys detail panel without the MFA panel active: add `passkey: true` to alice or morgan (totp=false). This also fixes the UsersIndexLive gap above.
2. MISSING: A user with **multiple OAuth providers** (beyond carol's single GitHub). The Identities panel shows one row. Add a second identity (e.g. google) to carol to show the panel with 2+ rows.
3. PARTIAL: Backup codes count in the security panel — admin has a TOTP credential seeded but the backup codes state depends on whether `mfa_value` reads from backup_codes_count. If it silently shows 0, that is an acceptable demo state. If the panel omits the count entirely, it is a gap in seed coverage but not in the component.

### AuditIndexLive (Global Audit Explorer)

HAVE states: >=6 distinct action types (18+ across both seed batches), failure rows with risk tone, impersonation rows with info tone, applied filter chips (in code), CSV export button, empty state (reachable by filtering to a nonexistent actor).

Seed gaps:
1. MISSING: An **`account.password.change`** event. Operators investigating security incidents want to see password-change events. Not in either seed batch.
2. MISSING: An **`auth.magic_link`** or **`auth.email_confirm`** event. Common auth primitives that demonstrate the full event vocabulary. Neither is seeded.
3. MISSING: An **`api.token_verify.failure`** or **`api.jwt_refresh`** event. These demonstrate Sigra's API auth surface in the audit trail.
4. MISSING: **Mobile card fallback layout**. The audit table is desktop-only. On mobile the table overflows. This is a template gap, not a seed gap.

### AuditUserLive (Per-User Audit, admin persona)

HAVE states: >=20 events for admin (18 admin-batch + 2 persona-batch), impersonation badge events, failure tone events, applied filter chips, return-to back-nav, CSV export, "View full audit" link from UserShowLive.

Seed gaps:
1. MISSING: **Mobile card fallback layout** (same as AuditIndexLive). Table-only on mobile.
2. PARTIAL: Actor != effective_user distinction on alice's per-user view. The persona batch includes `admin.impersonation.start/stop` with `actor_id=admin, effective_user_id=alice`. This SHOULD render the "Actor: admin / Effective user: alice" distinction on alice's AuditUserLive. Worth verifying this renders correctly when alice's AuditUserLive is loaded — if it does, this is already covered.

---

## Feature Dependencies

```
scope_ribbon component
    depends on: admin_scope assign (already in all LiveViews — no new data needed)

skeleton component
    depends on: decision on sync vs async mount pattern
    note: skeleton can be added without full async conversion — shows on websocket handshake

shared task_card component
    required by: Phase 1 (component foundation)
    consumed by: Phase 2 (IndexLive + OrganizationLive reconciliation)

shared stat_link / stat components
    required by: Phase 1
    consumed by: IndexLive, OrganizationLive, UsersIndexLive

page_back component
    required by: Phase 1
    consumed by: UserShowLive, AuditUserLive

mobile audit card layout
    required by: Phase 4 (AuditIndexLive + AuditUserLive)
    depends on: existing sg-show-desktop / sg-show-mobile classes (already in CSS)
    does NOT depend on: skeleton or other new components

needs-review alarm prominence
    required by: Phase 3 (Overview landings)
    is: purely visual hierarchy change — no new data, no new component

expired invitation seed
    required for: OrganizationLive expired pill to render
    depends on: OrganizationInvitation with expires_at in the past (trivial seed change)

frank as Acme member seed
    required for: OrganizationLive "Deletion scheduled" pill in member roster
    depends on: adding frank to Acme org membership (1 line in seed_memberships/3)

passkey-only persona seed
    required for: UsersIndexLive "Passkeys" pill without MFA pill; UserShowLive passkeys panel solo
    depends on: adding passkey: true to alice or morgan persona
```

### Dependency Notes

- **Shared components before screen reconciliation.** All consolidated component slots (stat_link, stat, task_card, applied_chip, empty_state, page_back, scope_ribbon, notice, skeleton) must be extracted into `Sigra.Admin.Components` before the individual screen passes in Phases 2-4 can swap to them. This is the Phase 1 prerequisite.

- **Seed enrichment is independent of component work.** Seed gaps can be closed in any phase. They do not gate component consolidation. The coherence sweep (Phase 5) benefits from all seed states being present so the journey is self-demonstrating end-to-end.

- **Mobile audit layout depends only on existing CSS.** `sg-show-desktop` / `sg-show-mobile` utility classes exist and are proven on UsersIndexLive. The audit card fallback is a template change, not a CSS primitive addition.

- **Skeleton requires a pattern decision.** If screens stay sync-mount (all assigns in `mount`), skeleton shows only briefly during the LiveView websocket handshake. If a screen moves to `assign_async`, skeletons become meaningfully visible. The skeleton component itself is separable from the async decision.

---

## Feature Prioritization Matrix

| Feature | Operator Value | Implementation Cost | Priority |
|---------|---------------|---------------------|----------|
| Consolidate stat_link + task_card into shared components | HIGH (foundation for all subsequent screen changes) | LOW (byte-identical extraction) | P1 |
| Shared page_back component | MEDIUM | LOW | P1 |
| Shared applied_chip + empty_state + notice components | MEDIUM | LOW | P1 |
| Needs-review alarm prominence on IndexLive (alarm above task grid) | HIGH (primary triage job; first evaluator impression) | LOW (visual hierarchy rearrangement) | P1 |
| OrganizationLive: expired invitation seed | HIGH (makes the "Expired" pill render in demo) | LOW (1 seed addition) | P1 |
| OrganizationLive: frank added to Acme membership seed | MEDIUM (shows deletion-scheduled member in roster) | LOW (1 line in seed_memberships) | P1 |
| Scope ribbon component used on all 6 screens | MEDIUM (org-scope orientation) | LOW | P1 |
| Audit mobile card layout (AuditIndexLive + AuditUserLive) | HIGH (audit table unusable on mobile today) | MEDIUM (mirrors UsersIndexLive pattern) | P1 |
| IndexLive: demote capability matrix below posture strip | MEDIUM (cleaner evaluator impression) | LOW | P2 |
| OrganizationLive: add "Open user" link per member in roster | MEDIUM (Org Admin's #1 shortcut from roster) | LOW | P2 |
| PassKey-only persona seed (alice or morgan gets passkey, no TOTP) | MEDIUM (demonstrates Passkeys panel without MFA lit up; fixes UsersIndexLive gap) | LOW (1-line persona change) | P2 |
| Carol: second OAuth identity seed (add Google) | LOW (shows multi-row Identities panel) | LOW | P2 |
| Global audit: additional action types in seed (password.change, magic_link, api events) | MEDIUM (makes audit explorer vocabulary-rich for evaluators) | LOW (3-4 seed rows) | P2 |
| Skeleton component + usage on initial mount | LOW-MEDIUM (perception improvement) | MEDIUM (async decision + implementation) | P3 |
| Confirm modal as shared component | LOW (only one screen uses confirms today) | LOW | P3 |
| Pagination demonstration (add more seed personas to exceed 25) | LOW (disabled-state pagination is not broken, just unreachable) | LOW | P3 |

---

## Sources

- `lib/sigra/admin/live/index_live.ex` — direct inspection (HIGH confidence)
- `lib/sigra/admin/live/organization_live.ex` — direct inspection (HIGH confidence)
- `lib/sigra/admin/live/users_index_live.ex` — direct inspection (HIGH confidence)
- `lib/sigra/admin/live/user_show_live.ex` — direct inspection (HIGH confidence)
- `lib/sigra/admin/live/audit_index_live.ex` — direct inspection (HIGH confidence)
- `lib/sigra/admin/live/audit_user_live.ex` — direct inspection (HIGH confidence)
- `test/example/lib/example/demo/personas.ex` — direct inspection (HIGH confidence)
- `test/example/lib/example/demo/seeds.ex` — direct inspection (HIGH confidence)
- `~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md` — approved kickoff brief (HIGH confidence)
- `.planning/research/IA-JOURNEY-SYNTHESIS.md` — prior research synthesis (HIGH confidence)
- `.planning/PROJECT.md` — milestone scope and persona definitions (HIGH confidence)

---

*Feature research for: Sigra admin console coherence/needs-led journey pass (v1.34)*
*Researched: 2026-06-03*
