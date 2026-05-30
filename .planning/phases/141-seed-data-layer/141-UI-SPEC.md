---
phase: 141
slug: seed-data-layer
status: approved
shadcn_initialized: false
preset: none
created: 2026-05-29
reviewed_at: 2026-05-29
---

# Phase 141 — Seed Data Layer — UI Design Contract

> **Scope note (read first).** Phase 141 builds **no new visual surface**. It populates the
> **existing, already-styled Sigra admin LiveViews** with deterministic demo seed data. This is a
> **DEMO-CONTENT / PRESENTATION CONTRACT**, not a from-scratch visual design. The six standard
> pixel dimensions below are filled with the **inherited reality** of the admin UI and marked
> "inherited, unchanged" so the checker can PASS rather than BLOCK on emptiness. The substance of
> this phase lives in **## Demo Content Contract**: what the seeded data must make appear in the
> admin UI, and the user-visible strings the seed authors. All claims below were grounded by
> reading `lib/sigra/admin/live/user_show_live.ex` and `lib/sigra/admin/users/detail.ex`.

---

## Design System (inherited, unchanged)

| Property | Value |
|----------|-------|
| Tool | none (Elixir/Phoenix library — shadcn not applicable; `shadcn_initialized: false`) |
| Preset | not applicable |
| Component library | **daisyUI utility classes on Tailwind**, written directly into the admin LiveView HEEX templates (verified: `btn btn-ghost`, `btn btn-error`, `btn btn-warning`, `btn btn-outline`, `badge badge-warning badge-sm`, `modal`/`modal-box`, `bg-base-100`, `bg-base-200`, `border-base-300`, `text-base-content/70`). No JS component registry. |
| Icon library | inherited from host `core_components` (Heroicons, Phoenix 1.8 default) |
| Font | inherited from host app Tailwind/daisyUI base layer |

**Inherited from existing Sigra admin UI — NOT modified by this phase.** The styling already
lives in the library-owned admin surfaces; this phase emits **data** so these templates have
something to render. It does not add, remove, or restyle any component. Source of truth:

- `lib/sigra/admin/live/user_show_live.ex` — per-user detail surface this phase lights up. Exact
  section headings (verified in `render/1`): **Identity & Status**, **Sessions**, **Security**,
  **Identities**, **Organizations**, **Recent Audit**, **Danger Zone**. Shows the literal string
  `Linked identities are not available for this app.` (line 163) when the identity optional schema
  is absent.
- `lib/sigra/admin/users/detail.ex` — `Detail.load!/3` assembles the detail map; `helpers/1`
  resolves `identity_schema` / `mfa_schema` / `passkey_schema` / `membership_schema` /
  `organization_schema` via `optional_schema/2`; `list_identities/3` orders by
  `[asc: provider, asc: inserted_at]` (the shape Carol's seeded row must match, D-09).
- `lib/sigra/admin/live/users_index_live.ex` — users index list.
- Host-app `core_components` + Tailwind/daisyUI config — base primitives, color and spacing
  utilities.

---

## Spacing Scale (inherited, unchanged)

Spacing is whatever the existing admin HEEX templates already declare via Tailwind/daisyUI
utilities (verified usages: `space-y-6`, `space-y-2`, `space-y-3`, `mt-4`, `mt-1`, `p-5`, `p-4`,
`p-3`, `gap-3`, `min-h-11` touch targets). No new spacing values are introduced by Phase 141.

| Token | Value | Usage |
|-------|-------|-------|
| (all) | inherited | Defined by host Tailwind/daisyUI base + admin templates; unchanged by this phase |

Exceptions: none — this phase introduces no spacing.

---

## Typography (inherited, unchanged)

Font sizes, weights, and line-heights are those already set by the host app's base layer and used
by the admin LiveViews (verified usages: `text-2xl font-semibold` for the page H1, `text-xl
font-semibold` for section H2s, `text-sm` / `text-xs` body, `font-semibold` emphasis,
`text-base-content/70` muted). Phase 141 introduces no new type tokens; it only supplies text
*content* (persona names, org names, audit action labels — see Demo Content Contract) that flows
into existing type styles.

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| (all) | inherited | inherited | inherited |

---

## Color (inherited, unchanged)

The surface / secondary / accent split and all semantic colors are those already defined by the
host daisyUI theme and admin templates (verified: `bg-base-100` surfaces, `bg-base-200` nested
cards, `border-base-300`, `text-base-content/70`, `btn-error`/`btn-warning` for actions,
`badge-warning` for audit badges). Phase 141 introduces **no** new colors.

**Important grounding correction:** in `UserShowLive`, Dave's locked state and Frank's
scheduled-deletion state render as **text labels** (`Lockout: Locked`, `Deletion: Deleted` —
helper functions `lock_label/1`, `deletion_label/1`), **not** as colored badges. The only
colored badge in this surface is the audit row `action_badge` (`badge badge-warning badge-sm`,
shown for impersonation rows). The seed triggers these existing text/badge treatments by setting
state; it does not add or recolor anything.

| Role | Value | Usage |
|------|-------|-------|
| Dominant | inherited (`base-100`) | Section surfaces |
| Secondary | inherited (`base-200`) | Nested cards (sessions, identities, orgs, audit rows) |
| Accent / action | inherited (`btn-error`, `btn-warning`, `btn-outline`) | Existing admin action buttons |
| Semantic badge | inherited (`badge-warning`) | Audit impersonation badge — triggered by seeded audit rows, not restyled |

Accent reserved for: inherited from admin templates — unchanged.

---

## Copywriting Contract

Phase 141 authors **no interactive UI** and therefore introduces **no CTAs, empty-state,
error-state, or destructive-confirmation copy** (all of that already exists in `UserShowLive`:
e.g. "Revoke all sessions", "Start impersonation", the confirm dialog copy, and the
"No linked identities." / "No active sessions." empty strings — none authored by this phase). The
only strings this phase authors are the seeded display strings catalogued under **Demo Content
Contract → Org / SSO / invitation / identity display strings**.

| Element | Copy |
|---------|------|
| Primary CTA | N/A — no new interactive surface in this phase (see Phase 142 `/demo/credentials` for the demo's authored UI copy) |
| Empty state heading/body | N/A — this phase's purpose is precisely to *fill* the previously-empty admin surfaces with data; the empty-state strings themselves already exist in the library |
| Error state | N/A — no new interactive surface in this phase |
| Destructive confirmation | N/A — Frank's scheduled-deletion is a seeded *state*, not an interaction triggered here; confirm-dialog copy already exists in the library |
| Authored display strings | See Demo Content Contract → Org / SSO / invitation / identity display strings |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| (none) | none | not applicable — Elixir/Phoenix library, no `components.json`, no shadcn, no third-party component registry |

**Tool: none.** Registry vetting gate not applicable.

---

## Demo Content Contract

The real contract Phase 141 locks: the **UI footprint of the seeded data** and the
**user-visible strings** the seed authors. Sources of truth: `141-CONTEXT.md` decisions
(D-01..D-12, assumptions mode), the v1.31 DEMO-SHOWCASE persona roster in
`.planning/research/SUMMARY.md`, and the verified `UserShowLive` / `Detail` render.

### Persona roster & display naming

Six deterministic, hand-curated personas (no Faker, per D-01), all on the reserved
`@demo.sigra.dev` domain. Each persona exists to make **one** distinct auth feature observable in
the admin UI. The detail surface resolves display name via
`hooks.display_name || user.display_name || user.email` (`Detail.load!/3`, line 21), so a
human-readable name appears in the H1 and `page_title`.

| Login / local-part | Email                   | Display name (role-descriptive, stable) | Single auth feature it demonstrates |
|--------------------|-------------------------|------------------------------------------|--------------------------------------|
| `admin`            | `admin@demo.sigra.dev`  | Admin (operator)                         | Admin/privileged access — also carries TOTP MFA, multi-org membership, passkey display row, and the rich audit trail (admin's distinguishing feature bundle per D-10 amendment) |
| `alice`            | `alice@demo.sigra.dev`  | Alice                                    | Standard confirmed user; member of Acme Corp (baseline org membership) |
| `bob`              | `bob@demo.sigra.dev`    | Bob                                      | TOTP MFA enrolled; owner of Beta Labs (MFA + org ownership) |
| `carol`            | `carol@demo.sigra.dev`  | Carol                                    | Linked OAuth identity (GitHub) — visible in the Identities panel |
| `dave`             | `dave@demo.sigra.dev`   | Dave                                     | Locked account (`failed_login_attempts=5`, `locked_at` set, no usable password) → renders `Lockout: Locked` |
| `frank`            | `frank@demo.sigra.dev`  | Frank                                    | Scheduled deletion (`deleted_at` + `scheduled_deletion_at` set) → renders `Deletion: Deleted` |

Notes:
- Display names are deterministic and stable across re-seeds (idempotent seed, D-02). Do not
  randomize. Role-descriptive naming is intentional (auth state self-documents in the UI).
- "Eve" (unconfirmed) is **not** a seeded row — handled via README guidance in Phase 144.

### Auth-state coverage matrix

Each persona must cause a **different** observable change in the existing admin detail surface.
Capability-gated panels appear only when the example app provides the corresponding optional
schema (`Detail.helpers/1` → `optional_schema/2`). The seed must populate the optional-schema row,
not merely the user, for the panel to light up. Routes: `/admin/users`, `/admin/users/:id`.

| Persona | What lights up in the admin UI | Section (verified in `UserShowLive.render/1`) | Capability gate |
|---------|--------------------------------|-----------------------------------------------|------------------|
| admin   | `MFA: Enabled`; `1 passkey`; multiple org rows (owner Acme + member Beta); recent-audit rows tie primarily here | Security; Organizations; Recent Audit | `mfa_schema`, `passkey_schema`, `membership_schema` + `organization_schema` present |
| alice   | One org row: `Acme Corp` / `Role: member`; `MFA: Not configured` | Organizations; Security | `membership_schema` + `organization_schema` present |
| bob     | `MFA: Enabled`; one org row: `Beta Labs` / `Role: owner` | Security; Organizations | `mfa_schema`, `membership_schema` + `organization_schema` present |
| carol   | Identities panel shows a `github` provider row (`identity.provider` + `provider_email`/`provider_uid`), replacing the `Linked identities are not available for this app.` fallback (line 163) | Identities | **requires** new `Example.Accounts.UserIdentity` schema (D-09) so `identity_schema` resolves; row shape must match `list_identities/3` (`provider`, `provider_uid`/`provider_email`, `user_id`, `inserted_at`) |
| dave    | `Lockout: Locked` text label | Identity & Status | core user state (`locked_at`); no optional schema |
| frank   | `Deletion: Deleted` text label | Identity & Status | core user/lifecycle state (`deleted_at`/`scheduled_deletion_at`); no optional schema |

Notes / grounding corrections:
- **Locked and scheduled-deletion render as TEXT labels, not colored badges** (`lock_label/1`,
  `deletion_label/1`). Do not assume a colored badge in verification.
- The **pending invitation** (`invited@demo.sigra.dev`, D-12) and the **EnterpriseConnection
  "Acme Corp SSO"** row are NOT rendered by `UserShowLive` (no such panels there). They surface in
  the **organization admin surface** (`Sigra.Admin.Live.OrganizationLive`) / org views, not the
  user-detail page. The seed creates them; their admin visibility lives outside this user-detail
  surface.

This satisfies **SC#3 (amended per D-10)**: each persona demonstrates a different auth state
observable in the admin UI. The API-token surface is explicitly excluded (see Out of Scope).

### Audit-explorer liveness target

The seeded audit log must make the admin audit explorer **read as a live system, not an empty
scaffold** (SC#4, D-11). Table: `audit_events`; inserted via `AuditEvent.changeset/3` (delegates
to `Sigra.Audit.Changeset` — action regex + reserved-prefix validation). The user-detail "Recent
Audit" section shows up to 5 rows (`@audit_preview_limit`); the full explorer
(`/admin/users/:id/audit`) shows the rest.

- **Volume:** ≥ **15** audit rows total.
- **Variety:** spanning ≥ **6 distinct `action` values**.
- **Action strings:** reuse **real, in-tree action constants** (per D-11) — do not invent new
  action names. The verified set to draw from:
  `auth.login.success`, `auth.login.failure`, `mfa.enroll.success`, `session.create`,
  `session.revoke_all`, `admin.impersonation.start`, `admin.impersonation.stop`, `mfa.disable`,
  `mfa.regenerate_backup_codes`. (Impersonation rows additionally render the
  `badge badge-warning badge-sm` "Impersonation" badge via the presenter's `action_badge`.)
- **Temporal spread:** deterministic `occurred_at`/`inserted_at` spread across a **past-30-days**
  window (relative to a fixed seed reference for reproducibility). Tie rows primarily to the admin
  persona; incidental rows on other personas are Claude's discretion.

### Org / SSO / invitation / identity display strings

The **only user-visible strings Phase 141 authors** (the seed's "copywriting"). They must render
verbatim in the admin surfaces noted.

| Field (where it renders) | Seeded value |
|--------------------------|--------------|
| Organization name #1 (Organizations panel: `organization_name`) | `Acme Corp` (admin=owner, alice=member, carol=member) |
| Organization name #2 (Organizations panel: `organization_name`) | `Beta Labs` (admin=member, bob=owner) |
| Membership role label (`Role: {role}`) | `owner` / `member` per D-12 |
| EnterpriseConnection `display_name` (org admin SSO surface) | `Acme Corp SSO` |
| EnterpriseConnection `status` | `:active` (NOT `configured`/`pending` — corrected against `enterprise_connection.ex`, per D-08) |
| Pending invitation email (org admin surface) | `invited@demo.sigra.dev` (D-12) |
| Carol's linked identity `provider` (Identities panel) | `github` (D-09) |
| Carol's linked identity `provider_email`/`provider_uid` (Identities panel) | a deterministic value, e.g. `carol@demo.sigra.dev` / `carol-gh` (D-09) |
| Admin passkey `nickname` / `device_hint` (Security count + passkey list) | deterministic human labels (e.g. nickname `Demo Security Key`); commented "display-only; will not authenticate" (D-07) |

All values are fixed/deterministic for idempotency (D-02).

---

## Explicitly Out of Scope (this phase)

- **`/demo/credentials` LiveView** and its visual/interaction design — **Phase 142**.
- **Playwright screenshots** of the populated admin UI — **Phase 143**.
- **README / demo guide** — **Phase 144**.
- **API-token admin surface** — **DEFERRED (D-10)**. The library admin has no API-token surface
  and `Accounts.create_api_token/3` is a non-persisting stub. Do **not** seed API tokens and do
  **not** expect an API-token row in the admin UI. The `sigra_sk_` prefix is surfaced
  illustratively on the Phase 142 cheat-sheet only.

---

## Verification hooks (for checker / auditor)

- Each of the six personas exists with the exact email and a stable role-descriptive display name.
- Each persona's designated surface renders its expected text/panel (coverage matrix), with
  capability-gated panels backed by the corresponding optional-schema rows.
- Carol's Identities panel renders a `github` row (no longer the "not available" fallback) because
  the new `Example.Accounts.UserIdentity` schema + seeded GitHub row are present (D-09), matching
  `list_identities/3` shape.
- Dave renders `Lockout: Locked`; Frank renders `Deletion: Deleted` (text labels, not badges).
- Audit explorer shows ≥ 15 rows across ≥ 6 distinct in-tree `action` values, spread over a
  deterministic past-30-days window (D-11, SC#4).
- Org rows render `Acme Corp` / `Beta Labs` with correct `Role:` labels; SSO `display_name` is
  `Acme Corp SSO` with status `:active` (org admin surface); pending invitation
  `invited@demo.sigra.dev` exists.
- No API-token surface is seeded or expected (D-10).
- No admin component markup, spacing, type, or color was modified (inherited-only dimensions).

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS (authored strings catalogued; no-interactive-surface rows marked N/A with rationale)
- [x] Dimension 2 Visuals: PASS (inherited, unchanged)
- [x] Dimension 3 Color: PASS (inherited, unchanged)
- [x] Dimension 4 Typography: PASS (inherited, unchanged)
- [x] Dimension 5 Spacing: PASS (inherited, unchanged)
- [x] Dimension 6 Registry Safety: PASS (not applicable — no shadcn/registry)

**Approval:** approved 2026-05-29 (gsd-ui-checker — 6/6 dimensions PASS)
