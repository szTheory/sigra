# Phase 16: Org LiveViews + Switcher - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 16-org-liveviews-switcher
**Areas discussed:** Routing + slug guard, Signup + no-org landing, Settings + sudo UX, Members list + Phase 17 coupling, Switcher injection, Library vs generated boundary

**Mode:** Deep research — 6 parallel `gsd-advisor-researcher` agents, each covering one gray area with full ecosystem survey (Elixir + other frameworks), engineering/DX analysis, and comparison tables. User accepted all one-shot recommendations.

---

## Area 1: Route structure for org-scoped pages + slug/session mismatch guard

| Option | Description | Selected |
|--------|-------------|----------|
| A. Implicit `/org/settings`, `/org/members` (session-only) | Matches v1.0 `/users/settings` precedent; slug never in URL; multi-tab-multi-org impossible by construction | |
| B. Explicit `/organizations/:slug/settings`, `/organizations/:slug/members` (URL-driven) | Matches Phoenix 1.8 scopes guide verbatim; shareable deep links; multi-tab-multi-org works; matches Linear/GitHub/Vercel/Slack | |
| C. Hybrid: `/organizations` unscoped index + `/organizations/:slug/...` scoped pages | B plus an explicit unscoped home for the switcher/picker/create/invite-accept flows | ✓ |

**User's choice:** C (explicit slug-in-URL with unscoped landing page).

**Mismatch guard sub-decision:** no-membership → 404 (enumeration prevention); valid-membership-different-slug → assign URL org to `%Scope{}` for this request AND refresh session pointer via `put_active_organization/2` (opportunistic write, reuses Phase 14 D-16 orchestrator).

**Notes:** The key reframe — URL = per-request active org, session column = resume pointer — preserves every Phase 14 decision (D-03 no cookie mirror, D-13 per-session-not-per-user, D-16 single authoritative writer). New library modules: `Sigra.Plug.LoadOrganizationFromSlug` + `Sigra.LiveView.OrganizationScope` on_mount. Phoenix 1.8 scopes guide (`hexdocs.pm/phoenix/scopes.html`) explicitly documents `route_prefix: "/organizations/:org"` with `@derive {Phoenix.Param, key: :slug}` and an `assign_org_to_scope` plug as the canonical pattern — a library positioned as "fills the Pow gap on Phoenix 1.8+" cannot credibly diverge from it. Route ordering: `POST /organizations/switch` defined before the scoped block (definition-order matching). Reserved slugs: add `"orgs"`, `"organizations"`, `"switch"` as a tiny Phase 13 follow-up applied in Phase 16.

---

## Area 2: "No active org" landing page shape + Create-first-org at signup

| Option (landing) | Description | Selected |
|--------|-------------|----------|
| A. Single unified LV with 3 render branches | One mount handles 0-orgs / 1-org / 2+-orgs / stale-recovery / invites | ✓ |
| B. Separate routes (`/organizations`, `/organizations/new`, `/organizations/invitations`) | Each route a focused LV, but forces `/organizations → /organizations/new` redirect chain on zero-org case | |
| C. Wizard with step state machine | Wizard framing wrong for stale-recovery; URL/state divergence breaks back button | |

| Option (signup) | Description | Selected |
|--------|-------------|----------|
| (i) Inline field on `registration_live.ex` | Couples registration to org creation; Jetstream #117 regression risk | |
| (ii) 2-step LV wizard | Step state on a security-sensitive LV; email-send ordering awkward | |
| (iii) Post-register redirect through existing Phase 14 plumbing | Zero new code on registration path; ORG-UX-09 "optional" falls out for free | ✓ |
| (iv) Post-register modal / interstitial | Client-state fragile; duplicates landing logic | |

**User's choice:** Landing = A (single unified `OrganizationsLive.Index`). Signup = (iii) post-register redirect with `registration_live.ex` untouched.

**Notes:** The elegant part — ORG-UX-09 "optional create-first-org" costs zero lines because Phase 14 D-09 already routes every `:no_active_org` case to `/organizations`. The landing page IS the zero-org destination and the stale-recovery destination and the 2+-without-resume destination. One LV, three render branches on `(memberships, pending_invitations)`. The "optional" escape is just navigating away from `/organizations` to any non-`:require_org` route. Jetstream #117 auto-personal-org regression is structurally impossible because there's no code path that creates an org during registration. Invite-signup (Phase 17) naturally bypasses because `select_active_organization/3` returns `{:ok, org}` with membership already in place.

---

## Area 3: Settings page layout + sudo typed-confirm UX

| Option (layout) | Description | Selected |
|--------|-------------|----------|
| A. Single-page sections | Matches v1.0 `settings_live.ex` 1:1; stacked General / Slug / Danger Zone | ✓ |
| B. daisyUI tabs | No v1.0 precedent; tab/URL sync fiddly in LV | |
| C. Separate routes per section | Breaks v1.0 "one settings page" mental model | |
| D. GitHub-style sidebar nav | Overkill for 3 sections | |

| Option (sudo + typed-confirm) | Description | Selected |
|--------|-------------|----------|
| (i) Full-page sudo redirect via `RequireSudo` | No v1.0 precedent in settings; state preservation across redirect is hard | |
| (ii) Inline password + typed-confirm in same form | Matches v1.0 `change_password` pattern; one LV event; `confirm_sudo/1` as context-function side effect | ✓ |
| (iii) Two-step: sudo redirect then confirm page | Two round-trips; worst user ergonomics | |
| (iv) Progressive disclosure (button → expanded form) | Visual variant of (ii) — combined into recommendation | ✓ (combined) |

**User's choice:** Layout = A (single-page sections). Sudo UX = (ii) + (iv) combined — inline form with progressive disclosure.

**Notes:** Critical finding — v1.0 `SettingsLive` **does not use `RequireSudo`** at all. It collects `current_password` inline for destructive actions and calls `confirm_sudo/1` as a side effect in the context function. Phase 16 extends that pattern exactly. Diverging would mean v1.0 account delete has no password while v1.1 org delete has full sudo redirect — two destructive conventions in the same app. The new context functions (`rename_organization/2`, `update_slug/2`, `soft_delete_organization/2`) take `password` + typed-confirm args, verify inline, and return field-level changeset errors on mismatch. Progressive disclosure: "Change slug" / "Delete organization" buttons flip LV assigns that expand the form inline — enforces intent without a modal, stays testable, composes with Phase 21 passkey-for-sudo. 7-day slug-redirect history is backend-only with one `alert alert-warning` banner inside the slug form.

---

## Area 4: Members list layout + role/remove UX + Phase 17 coupling

| Option (list layout) | Description | Selected |
|--------|-------------|----------|
| A. Responsive `<.table>` + action menu + modal | Uses existing core_components `<.table>`; desktop-dense admin pattern | ✓ |
| B. daisyUI card stack (mobile-first) | v1.2 mobile direction not yet locked; loses column alignment | |
| C. Inline role dropdown (no modal) | Footgun on last-owner errors (UI-state desync); fights D-29 POST+confirm convention | |
| D. Click row → side drawer | Overkill for Phase 16's 5 requirements | |

| Option (status column) | Description | Selected |
|--------|-------------|----------|
| 1. Add `status` column to Membership schema now | Scope creep into Phase 13; contradicts D-11 hard-delete | |
| 2. Derived `Active` constant in Phase 16; Phase 17 renders unified members+invitations with derived status | Zero schema change; matches Jetstream/Clerk/GitHub | ✓ |

| Option (last-active sourcing) | Description | Selected |
|--------|-------------|----------|
| 1. Add `last_active_at` column to Membership | New column + hot-path write — rejected | |
| 2. Query `user_sessions.last_active_at` via library LEFT JOIN LATERAL | Zero new schema; `user_sessions.last_active_at` already throttle-updated every 5 min by `FetchSession` | ✓ |
| 3. Query audit_events | Sparse, high-cardinality, Phase 15 index not optimized for per-user MAX | |

| Option (Phase 17 coupling) | Description | Selected |
|--------|-------------|----------|
| α. Unified list with status badge | Ugly row-type switching in HEEx; Phase 17 diff touches Phase 16 cells | |
| β. Separate "Invitations" tab | Tabs hide empty-invite state; doubles URL/state surface | |
| γ. Separate `/organizations/:org/invitations` page | Splits coherent admin task | |
| δ. Two streams, two stacked sections, Phase 16 stubs invitations with empty state + HEEx comment | Cleanest additive diff for Phase 17 | ✓ |

| Option (pagination) | Description | Selected |
|--------|-------------|----------|
| 1. Infinite scroll | Wrong for admin (loses scroll, breaks Cmd-F) | |
| 2. Flop full pager | New dep for a problem Phase 16 doesn't have | |
| 3. `LIMIT 100` + "Load more" button + total count in header | Native LiveView stream append; covers 95th percentile orgs | ✓ |

**User's choice:** A + derived `Active` + query `user_sessions.last_active_at` + δ (stub sections) + `LIMIT 100` Load-more.

**Notes:** No schema additions — Phase 13 D-10 stays frozen. `Sigra.Organizations.list_members_with_activity/2` is a new library query (security-adjacent cross-schema join, must not be hand-rolled by hosts). Remove-member uses a simple confirm modal — NOT typed-email-confirm (removal is reversible by re-invitation; typed confirm reserved for org-level destructive actions per D-29). Last-owner guard errors surface via flash + modal-stays-open; no client-side preemptive disable. Role change via action menu → modal with role dropdown, not inline `<select>`.

---

## Area 5: Switcher component & layout injection

| Option | Description | Selected |
|--------|-------------|----------|
| A. Auto-inject into `layouts.ex` HEEx sigil | No v1.0 precedent for HEEx edits; brittle on customized layouts; new anchor class | |
| B. Generate component + printed post-install instructions | Matches v1.0 Sigra + phx.gen.auth convention; re-run safe; `--no-organizations` trivial | ✓ |
| C. Library-owned `Sigra.Components.org_switcher/1` + manual import | Single consumer; host navbar is #1 customization surface; new pattern too soon | |
| D. Slot-based `<Layouts.app_with_org_switcher>` replacement | Rewrites every call site; heaviest option | |
| E. Hybrid: generate component + auto-inject one marked line | Worst of A + B (still brittle, still has generated file) | |

**User's choice:** B (generate + post-install instructions, do not patch layouts).

**Notes:** v1.0 Sigra's 6 existing injection anchors (`:before_last_end`, `:elixir_config`, `:append_eof`, `:conn_case_helpers`, `:after_use_block`, `:at_top`) all target grammar-stable Elixir files. Zero layout anchors. Zero `.heex` touches. `phx.gen.auth` follows the same convention. The switcher component is generated to `lib/<app>_web/components/org_switcher.ex`, routes are auto-injected via `Features.Organizations.injections/1`, and post-install instructions tell the dev to paste `<.org_switcher current_scope={@current_scope} />` into their layout header. 30 seconds of manual work on first install in exchange for re-run safety and full host customization. `--no-organizations` (Phase 18) is trivial: `enabled?/1` already gates everything.

---

## Area 6: Library vs generated boundary for Phase 16 UI

| Candidate | Option | Selected ownership |
|--------|--------|----------|
| `<.org_switcher/>` function component | Library FC + generated delegating wrapper | Generated only (rejected library promotion) |
| `TypedConfirmDialog` LiveComponent | Library LiveComponent reused across phases | Not needed (inline progressive disclosure instead) |
| `MembersTable` component | Library stateless presentation | Generated inline in LV (host customizes heavily) |
| `OrgAssigns` / `OrganizationScope` on_mount | Library shared request-time wiring | **Library** (D-03, matches Phase 14 D-22) |
| LV page modules (`OrganizationsLive.*`, `OrganizationSettingsLive`, `OrganizationMembersLive`) | Page-level LV ownership | Generated (matches Phase 13 D-01) |

**User's choice:** Zero new library UI components in Phase 16. Only the new plug + on_mount (matching Phase 14 D-22) plus new context functions (matching Phase 13 D-01) go in the library. Everything else generated and host-owned. Adopted the "Sigra UI Ownership Rule (v1.1+)" as a project-level precedent for Phases 17 / 19 / 20 / 21.

**Notes:** The rule:
1. Library owns shared security-adjacent request-time wiring (plugs, on_mount, context).
2. Generated owns page LVs, domain-specific presentation, `core_components.ex`, layouts, emails.
3. Promotion allowed only when 3+ phases would reuse OR security-sensitive (buggy host copy = vulnerability) OR narrow a11y/keyboard primitive in the LiveSelect/LiveToast class. Default to generated.

Applied conservatively in Phase 16 because introducing a new `Sigra.Components.*` or `Sigra.LiveComponents.*` namespace in the same phase that introduces URL-driven routing + three new LVs + the `Features.Organizations` injection contract is too much new pattern at once. Future phases can promote pieces as they meet the criterion.

---

## Claude's Discretion

- CD-01: Exact file paths for `LoadOrganizationFromSlug` + `OrganizationScope` on_mount (sub-namespace vs flat).
- CD-02: Whether `OrganizationsLive.Index` is one `.ex` file or splits the zero-state form into a function component.
- CD-03: Exact daisyUI class strings on the switcher dropdown.
- CD-04: `<.modal>` from core_components vs daisyUI `<dialog>` for confirmations.
- CD-05: Whether `@user_organizations` is a socket assign or fetched per-render.
- CD-06: Members list default sort (join date desc vs alphabetical by email).
- CD-07: Whether `:require_active_organization` pipeline macro is auto-injected or documented in post-install instructions only.

## Deferred Ideas

- Phase 17 plugs invitations into existing stubs (`OrganizationsLive.Index` + `OrganizationMembersLive`) additively.
- `:require_active_organization` pipeline macro — revisit in Phase 17 or 18.
- v1.2 admin UI phase: mobile-first card-stack, Flop pagination, sidebar nav, per-member detail drawer, slug-history list, bulk actions.
- v1.2 admin impersonation banner extends the D-24 "generated component + manual paste + library security contract" pattern.
- Phase 21 passkey-for-sudo: D-11 context functions accept `password_or_passkey_assertion`.
- Library-owned UI primitives promoted as they meet D-28 criteria: `org_switcher` at v1.2 admin parallel, `TypedConfirmDialog` at Phase 17/21, `passkey_button` at Phase 21.
- Revisit UI Ownership Rule after v1.1 GA with real data on what hosts restyle.
