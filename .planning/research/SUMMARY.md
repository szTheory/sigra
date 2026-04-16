# Project Research Summary

**Project:** Sigra v1.2 Admin Dashboard
**Domain:** Phoenix authentication-library admin surface
**Researched:** 2026-04-16
**Confidence:** HIGH

## Executive Summary

Sigra v1.2 is not a generic back-office project. It is an auth-first admin surface for Phoenix/LiveView applications, centered on user support, security operations, impersonation, and audit evidence. The research is consistent on the core implementation approach: keep the admin UI inside the existing Phoenix 1.8 + LiveView stack, keep security-critical impersonation/session/audit logic inside the Sigra library, and generate the host-facing admin routes, LiveViews, and verification harness additions rather than introducing a second frontend architecture or a third-party admin framework.

The recommended milestone shape is additive, not transformational. Reuse the current session, scope, audit, and Playwright foundations; add an `Admin` install feature; ship searchable user management, secure impersonation, and audit exploration as one coherent support/security surface; and make automation-first review artifacts part of the deliverable, not a postscript. The right build order starts with admin authorization and session/audit primitives, then user operations, then impersonation, then audit exploration/export, then verification and review gates.

The main risks are security-boundary mistakes, not component complexity. The milestone fails if admin gating is UI-only, if impersonation mutates identity loosely, if dual-actor audit is partial, or if org-scoped queries leak global data. Those are neutralized by explicit route/controller/context boundaries, controller-owned impersonation session transitions, canonical audit semantics in the library, scoped query APIs, and automated verification that checks both visible UX artifacts and underlying session/audit behavior.

## Key Findings

### Recommended Stack

The stack recommendation is mostly about disciplined reuse. Sigra should stay on Phoenix `~> 1.8`, Phoenix LiveView `~> 1.1`, Ecto/Postgres, and the existing example-app Playwright harness. The admin dashboard should be built with HEEx components and LiveViews behind `live_session` and `on_mount`, with `handle_params/3` driving filterable, shareable admin state. Audit exploration stays on Ecto query modules plus indexes, not a search backend.

The explicit non-additions matter as much as the additions. v1.2 should not add React/Vue, a generic admin framework, a masquerade library, a new reporting/search backend, or a separate browser-test vendor. The only material stack extension is operational: expand the existing Playwright config to emit HTML reports, traces, screenshots, and CI-retained video where it helps review.

**Core technologies:**
- Phoenix `~> 1.8`: runtime and router foundation — already aligned with the app and avoids a migration milestone.
- Phoenix LiveView `~> 1.1`: admin UI implementation — supports admin routing, URL-driven filters, tables, banners, and async secondary loads without a SPA.
- Phoenix.Component / HEEx: reusable admin components — keeps the UI inside the existing rendering model.
- Ecto / PostgreSQL: admin and audit queries — enough for searchable lists, audit exploration, and export with the right indexes.
- Existing session/scope/audit modules: impersonation and dual-actor audit basis — the correct trust boundary already exists in Sigra.
- Existing Playwright harness: review artifacts and browser verification — should be extended, not replaced.

### Expected Features

The table stakes are clear: searchable user management, auth-centric user detail, session inspection/revocation, org-aware visibility, global and per-user audit exploration, secure impersonation with a persistent banner and hard restrictions, mobile-usable workflows, and artifact-rich automated verification. The differentiator is not breadth; it is shaping the surface around support and security jobs instead of generic CRUD.

**Must have (table stakes):**
- Searchable user list with filters and stable pagination — this is the entry point for nearly every support workflow.
- User detail with auth-specific tabs — profile, sessions, security, identities, organizations, audit, and danger-zone actions.
- Session inspection and revocation — high-value support action with low ambiguity.
- Security-state summary — operators need immediate account-health context.
- Org-aware visibility and actions — required to make v1.1 organization scope trustworthy.
- Global and per-user audit exploration — audit only becomes valuable when it is searchable.
- CSV export of the active audit slice — necessary for evidence-sharing workflows.
- Secure impersonation start/stop flow with timeout, visible banner, and dual-actor audit — core support capability.
- Forbidden sensitive actions during impersonation — enforced server-side.
- Mobile-usable admin workflows and light/dark support — explicit milestone expectations.
- HTML report, traces, screenshots, and targeted video artifacts — part of the product verification story.

**Should have (competitive):**
- Auth-first information architecture — lead with support/security state, not editable profile forms.
- "Why can't this user sign in?" summary card — compresses the most common diagnosis.
- Explicit org-scope framing in the chrome — prevents tenant mistakes.
- Impersonation return path to the original admin context — reduces support friction.
- Impersonation-aware audit presets and security-event quick views — makes investigation faster.
- Library-shipped verification artifacts — strong differentiator for a generated admin surface.
- Mobile action-sheet/list patterns instead of compressed desktop tables — better than baseline responsive behavior.

**Defer (v2+):**
- Broad bulk admin actions — high-risk and expensive to verify correctly.
- Analytics-heavy dashboard widgets — weak leverage compared with support/security workflows.
- Runtime theming engine — branding hooks are enough for v1.2.
- Approval-heavy impersonation workflows or advanced policy modes — worth revisiting later.
- Generic back-office capabilities outside identity/access/support/audit — out of scope by design.

### Architecture Approach

The architecture should follow Sigra's existing split: the library owns durable security semantics, while generated code owns the Phoenix-facing admin surface. Add a default-on `Sigra.Install.Features.Admin` generator feature. Keep impersonation, session-state transitions, scope hydration, sensitive-operation blocking, and canonical audit filters in the library. Generate admin access policy hooks, admin query wrappers, LiveViews, controllers, routes, responsive components, fixtures, and Playwright specs into the host app.

**Major components:**
1. `Sigra.Impersonation` + session/scope extensions — start/stop impersonation, enforce invariants, preserve actor identity, and expose effective-user state safely.
2. `Sigra.Audit.Query` extensions + audit field derivation — canonical dual-actor/org-aware audit semantics for list, filter, and export flows.
3. `Sigra.Install.Features.Admin` — generator entry point for routes, admin UI, tests, fixtures, and review artifacts.
4. Generated `AdminAccess` + `Accounts.Admin` layers — host-owned authorization and presentation/query shaping.
5. Generated admin LiveViews/controllers/components — user operations, impersonation endpoints, audit exploration, and layout-level banner behavior.
6. Extended example-app Playwright/system harness — browser artifacts plus direct HTTP smoke around authz, impersonation, and export paths.

### Critical Pitfalls

1. **UI-only admin checks** — neutralize with shared authorization primitives across router, LiveView, controller, export, and job entry points plus an automated auth matrix.
2. **Loose impersonation session modeling** — neutralize with controller-owned session rotation, explicit impersonation fields, non-nestable mode, and hard expiry.
3. **Incomplete dual-actor audit** — neutralize with library-owned audit derivation, explicit actor/effective-user fields, and async context propagation.
4. **Impersonation restrictions enforced only in UI** — neutralize with context/domain-level deny rules and parity tests for direct POST and LiveView paths.
5. **Cross-org data leakage in admin queries or exports** — neutralize with separate platform-admin/org-admin query APIs and parity tests on counts, detail, filters, and CSV output.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Admin Security Foundation
**Rationale:** Every later feature depends on correct authorization, scope hydration, and session/audit semantics. Starting with UI work before this foundation invites privilege bugs and rework.
**Delivers:** `Admin` generator feature skeleton, admin route families, host `AdminAccess`, session/schema changes for impersonation metadata, scope hydration updates, audit field derivation updates, and base plugs for admin and not-impersonating enforcement.
**Addresses:** Org-aware visibility, dual-actor audit groundwork, forbidden-during-impersonation enforcement model.
**Avoids:** UI-only admin gating, loose impersonation state, partial audit attribution, and cross-org leakage by construction.

### Phase 2: User Operations Surface
**Rationale:** The user list and user detail are the stable center of the admin dashboard. They depend on Phase 1 primitives but can land before impersonation and advanced audit exploration.
**Delivers:** Searchable user index, filter model, mobile-first row/list treatment, auth-centric detail tabs, status summary, session inspection/revocation, org membership context, and scoped admin presentation queries.
**Uses:** Phoenix LiveView, HEEx components, `handle_params/3`, Ecto/Postgres indexes, generated `Accounts.Admin`.
**Implements:** Shared LiveViews under platform-admin and org-admin route scopes.
**Avoids:** Generic CRUD drift, mobile-horizontal-scroll failure, stale list/detail query semantics, and hidden org-scope mistakes.

### Phase 3: Secure Impersonation
**Rationale:** Impersonation is high-value but high-risk. It should build on the user detail surface and only ship once the session, auth, and audit foundation is in place.
**Delivers:** Controller-owned start/stop impersonation flow, session rotation, timeout handling, persistent banner, return-to-admin-context behavior, forbidden-operation enforcement, and dual-actor audit events.
**Addresses:** Secure impersonation entry/exit, banner visibility, hard restrictions, support workflow continuity.
**Avoids:** Session confusion, UI-only restrictions, silent privilege escalation, and missing actor attribution.

### Phase 4: Audit Exploration and Evidence Export
**Rationale:** Audit UX should be built after impersonation semantics exist so the explorer can query the real event model instead of retrofitting it later.
**Delivers:** Global/per-user/per-org audit views, canonical filter set, security presets, impersonation-aware filtering, URL-addressable state, scoped CSV export, and audit-specific indexing.
**Addresses:** Searchable audit investigation, export of current slice, impersonation feed, evidence workflows.
**Uses:** `Sigra.Audit.Query` extensions, generated presentation joins/export schemas, Postgres indexes.
**Avoids:** Investigation-hostile filters, export/screen mismatches, raw metadata leakage, and slow high-value queries.

### Phase 5: Automation-First Verification and Review Artifacts
**Rationale:** Verification is a milestone deliverable, not a release-hardening afterthought. The research explicitly calls for asynchronous UX evidence and direct-path testing.
**Delivers:** Extended Playwright config, deterministic admin fixtures, desktop/mobile/dark-mode checkpoint screenshots, HTML report publishing, traces, targeted video retention, and direct HTTP/controller smoke for authz, impersonation, exports, and stale-session cases.
**Addresses:** Automation-backed UX review, mobile verification, artifact-based review ergonomics, non-browser path coverage.
**Avoids:** Human-only confidence, CI/manual drift, browser-happy-path bias, and missed mobile/banner regressions.

### Phase Ordering Rationale

- Foundation first because authorization, scope hydration, and audit semantics are shared dependencies across every admin feature.
- User operations before impersonation because impersonation should begin from a trustworthy user-detail workflow rather than inventing its own surface.
- Impersonation before audit explorer completion because the explorer needs finalized dual-actor semantics and impersonation filters.
- Verification last in the roadmap, but developed alongside each phase, because the final milestone gate depends on artifact completeness and direct-path coverage.
- Automation artifacts should be attached to each feature phase incrementally, with Phase 5 consolidating and hardening the review pipeline rather than inventing it from scratch at the end.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** Session-schema and scope-hydration details need careful validation against the current Sigra internals because impersonation semantics are security-critical.
- **Phase 3:** Impersonation timeout, tab behavior, and return-path details deserve focused planning because the UX/security tradeoffs are narrow and easy to get wrong.
- **Phase 4:** Audit export schema, indexing, and investigation presets may need query-shape validation against realistic data volume.
- **Phase 5:** Artifact retention and CI publishing strategy may need local pipeline-specific decisions even though the tool choice is settled.

Phases with standard patterns (skip research-phase):
- **Phase 2:** LiveView-based list/detail UI is well supported by the existing stack and architecture guidance.
- **Most of Phase 5 Playwright work:** The verification toolchain itself is already chosen and documented; the main work is coverage and fixture discipline, not technology selection.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Strong reuse recommendation based on official Phoenix/LiveView/Playwright docs and the current Sigra stack shape. |
| Features | MEDIUM-HIGH | Vendor patterns strongly agree on table stakes and impersonation guardrails; some mobile/detail UX choices remain product judgment. |
| Architecture | HIGH | The proposed split aligns closely with Sigra's existing library-vs-generated-code model and avoids policy creep. |
| Pitfalls | HIGH | Security, scoping, session, and audit risks are well grounded in established auth/admin failure modes and OWASP guidance. |

**Overall confidence:** HIGH

### Gaps to Address

- **Current-code validation of session schema changes:** confirm the exact generated session model and token-rotation path before phase planning locks the migration shape.
- **Admin authorization extension surface:** decide the smallest host-owned `is_admin?` / policy contract that preserves flexibility without fragmenting generator behavior.
- **Audit export volume strategy:** validate whether synchronous export is enough for expected dataset size or whether Oban-backed export should be included conditionally.
- **Mobile interaction contract:** convert the research guidance into explicit UI acceptance criteria so "responsive" does not pass for "operable."
- **Artifact baseline policy:** define which screenshots, traces, and videos are mandatory per phase so review quality does not drift.

## Sources

### Primary (HIGH confidence)
- Phoenix / LiveView / Router / JS docs — stack and routing patterns
- Playwright docs — HTML reports, traces, screenshots, video, mobile emulation
- OWASP Authorization / Session Management / Logging cheat sheets — authorization, session, and audit-risk controls

### Secondary (MEDIUM confidence)
- Auth0 docs — user-management and audit expectations
- WorkOS docs — impersonation guardrails and support workflow framing
- Clerk docs — modern auth admin information architecture
- FusionAuth docs — user detail and admin capability expectations
- Supabase docs — internal-tool/admin surface patterns
- GitHub Enterprise audit log docs — investigation, filter, and export prior art

### Project Context
- `.planning/research/STACK.md`
- `.planning/research/FEATURES.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/PITFALLS.md`

---
*Research completed: 2026-04-16*
*Ready for roadmap: yes*
