# Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment — Research

**Researched:** 2026-06-04
**Domain:** Elixir/Phoenix demo seed enrichment, CSS motion audit, Playwright journey filmstrip
**Confidence:** HIGH (all claims verified against live codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01** — Add a SECOND Acme OrganizationInvitation row (`expired-invite@demo.sigra.dev`) with `expires_at` in the real past. Do NOT mutate the existing pending invitation (`invited@demo.sigra.dev`, future-dated `~U[2026-06-30]`). Both must coexist so both pill branches render simultaneously.
- **D-02** — Add a NEW passkey-only persona (`totp: false, passkey: true`) to drive the "Passkeys" (no-MFA) pill. Existing admin persona hits "MFA + passkeys" first.
- **D-03** — Make a member of Acme scheduled for deletion. This can be a new Acme member persona OR a flag on an existing Acme member persona.
- **D-04** — Append to `@persona_audit_events` and/or `@audit_actions` using ALREADY-RESERVED action strings only: `auth.password.change`, `auth.magic_link.*`, `api.token.create`, `auth.oauth.link` with a second provider (e.g. `google`). Do NOT add a presenter label clause.
- **D-05** — Count-threshold guard is derived from list lengths (`length(@audit_actions) + length(@persona_audit_events)`). New rows auto-covered if added to those lists. Re-pin `seeds_test.exs` count assertions in lockstep.
- **D-06** — GATE-03 is satisfied by auditing + documenting the existing motion system plus a keyboard-only Playwright pass. Fix ONLY genuine violations. Open fork: whether `sg-filter-chip` press/tone transition counts as keyboard-frequent (planner adjudicates).
- **D-07** — The 6 coherence screens. Filmstrip as extension of or sibling to `admin-checkpoints.spec.ts`. Open fork: ad-hoc fixtures vs. seeded demo DB for new seed states (planner adjudicates).

### Claude's Discretion

- Exact persona emails/names for new personas
- Exact new audit action strings + second OAuth provider choice
- Whether the in-roster deletion-scheduled member is a new Acme persona or a flag on an existing one (both satisfy D-03)
- Resolution of both open forks (D-06 chip transitions, D-07 fixture-vs-seeded-DB)
- Whether the filmstrip extends `admin-checkpoints.spec.ts` in-place or as a sibling spec

### Deferred Ideas (OUT OF SCOPE)

- `sg-notice-tone-rule-duplication` — already resolved in phase-156
- `admin-overview-cleanup-misc` — quality/refactor with no bearing on seed/motion/coherence criteria
- `admin-overview-needs-review-count-link-mismatch` — deliberate semantics decision needed, out of scope; track as follow-on
- `admin-overview-notice-role-status` — a11y adjudication needing screen-reader decision, orthogonal to this phase
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FIXT-01 | Seed an expired org invitation so the "Expired" pill renders on org overview | D-01 verified; `organization_live.ex:157-163` pill logic confirmed; `detail.ex:116-119` `expired?` computation confirmed; idempotency via per-(org,email) pending check |
| FIXT-02 | Seed a deletion-scheduled user in an org so "Deletion scheduled" renders in the roster | D-03; CRITICAL: roster in `organization_live.ex:132-143` does NOT currently emit a deletion pill — requires code changes to `detail.ex:shape_member_row/1` AND `organization_live.ex` roster template in addition to seed |
| FIXT-03 | Seed a passkey-only (no-MFA) user so that pill renders on users index | D-02 verified; `users_index_live.ex:348-350` condition confirmed |
| FIXT-04 | Richer audit seed variety (password change, magic link, API token, second OAuth provider) | D-04 verified; presenter fallback at `presenter.ex:43-48` confirmed; reserved prefixes at `audit.ex:41` confirmed |
| FIXT-05 | Seed stays deterministic, idempotent, test-env guarded, no leakage | D-05 verified; threshold guard at `seeds.ex:548` confirmed; `@seed_reference_ts` at `seeds.ex:39` confirmed |
| GATE-03 | Motion audit: keyboard-frequent interactions not animated; enters use ease-out; destructive uses flat easing | D-06 verified; all motion tokens at `app.css:117-133` confirmed; cmdk instant active-row at `app.css:1368-1369` confirmed |
</phase_requirements>

---

## Summary

Phase 159 is the final coherence and seed-enrichment phase of the v1.34 ADMIN-UI-COHERENCE milestone. Three distinct jobs must be completed with no net-new surfaces.

**Job 1 (FIXT-01–05):** The demo seed module is mature (607 lines, idempotent, transaction-wrapped) but leaves four pill states undemonstrable: "Expired" invitation, "Deletion scheduled" org roster member, "Passkeys" (no MFA), and thin audit variety. Each gap requires appending to existing data lists or adding a persona — not new seed machinery. One critical gap is code-level, not just data-level: the org roster in `organization_live.ex` has no "Deletion scheduled" pill and `shape_member_row/1` in `detail.ex` does not expose `deleted_at`. FIXT-02 requires both a data fix (seed a deletion-scheduled Acme member) and a code fix (add `deleted_at?` derivation to the roster row shape and a pill clause in the HEEx template).

**Job 2 (GATE-03):** The motion budget is fully implemented. All keyboard-frequent paths are transition-free, enters use `--sg-ease-out`, and destructive easing is flat. GATE-03 is verify-not-build. The only genuine question is whether `sg-filter-chip` press/tone transitions (line 869) violate the keyboard-frequent contract when chips are toggled by keyboard — a scoped `@media (hover: hover) and (pointer: fine)` guard around those transitions resolves it in ~3 CSS lines if the planner adjudicates "yes."

**Job 3 (Criterion 4):** The coherence Playwright sweep extends `admin-checkpoints.spec.ts` (or is a sibling reusing its helpers). The spec already journeys all 6 screens. The open fork is whether new seed pill states (expired pill, in-roster deletion, passkey-only) are verified via the seeded demo DB or via ad-hoc `registerUser` fixtures. Ad-hoc fixtures are the safer choice for baseline stability: they are self-contained, do not depend on the demo DB being seeded, and keep Phase 160 ratification scope predictable.

**Primary recommendation:** Implement FIXT-01–05 as appends to existing lists plus two new personas (passkey-only + deletion-scheduled Acme member). Resolve D-06 by scoping the `sg-filter-chip` transitions to pointer-fine devices (low-risk, ~3 CSS lines). Resolve D-07 with a sibling spec using ad-hoc fixtures for the new pill states and asserting DOM pill text rather than pixel screenshots (baseline churn belongs in Phase 160, not 159).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Demo seed data | test/example app layer | — | Seeds are in `test/example/lib/example/demo/`; lib-owned code is not modified |
| Org roster pill (deletion-scheduled) | Frontend Server (LiveView) | Database/query layer | `organization_live.ex` renders pills; `detail.ex:shape_member_row/1` supplies data; both need changes |
| Expired invitation pill | Frontend Server (LiveView) | — | Already implemented in `organization_live.ex:157-163`; seed provides data |
| Passkey-only pill | Frontend Server (LiveView) | — | Already implemented in `users_index_live.ex:347-350`; seed provides data |
| Motion audit (GATE-03) | CDN/Static (CSS) | Frontend Server (LiveView) | Motion budget is in `app.css`; LiveView provides interaction context for keyboard-only Playwright test |
| Coherence filmstrip | Test layer (Playwright) | — | Extends existing `admin-checkpoints.spec.ts`; no production code change |
| Audit variety seed | test/example app layer | — | Appends to `@audit_actions` / `@persona_audit_events` in `seeds.ex` |

---

## Standard Stack

No new dependencies are introduced in this phase. [VERIFIED: codebase]

The stack in use:
- Elixir ~> 1.18 / OTP ~> 27 — runtime [VERIFIED: CLAUDE.md]
- Phoenix ~> 1.8 / Ecto ~> 3.12 — framework [VERIFIED: CLAUDE.md]
- `test/example/` Phoenix host app with `Example.Demo.Seeds` orchestrator [VERIFIED: codebase]
- Playwright (TypeScript) for e2e tests in `test/example/priv/playwright/` [VERIFIED: codebase]
- `sg-*` token layer in `test/example/priv/static/assets/css/app.css` (build-free, no Tailwind) [VERIFIED: codebase]

---

## Architecture Patterns

### Seed Module Pattern

The seed module (`seeds.ex`) follows a strict append-to-lists pattern for idempotency. All audit rows live in two module attributes:

- `@audit_actions` — list of `{action, outcome, offset_days}` tuples for admin-tied events (lines 414–433) [VERIFIED: codebase:seeds.ex:414]
- `@persona_audit_events` — list of per-persona event maps with `email`, `actor`, `action`, `outcome`, `offset`, `org` keys (lines 435–532) [VERIFIED: codebase:seeds.ex:435]

The count-threshold guard (line 548) compares `demo_tied_count < length(@audit_actions) + length(@persona_audit_events)`. Any row appended to those lists is automatically counted in the threshold, so idempotency holds without any separate guard update. [VERIFIED: codebase:seeds.ex:548]

### Invitation Idempotency Pattern

`seed_invitation/1` (lines 240–268) uses a check-then-insert pattern keyed on `(organization_id, email, is_nil(accepted_at), is_nil(revoked_at))`. Adding a second invitation for a DIFFERENT email (`expired-invite@demo.sigra.dev`) does not conflict with the existing row (`invited@demo.sigra.dev`). On re-run, the same `Repo.one` query finds the existing expired row and skips it. [VERIFIED: codebase:seeds.ex:246-267]

### `expired?` Computation

`Detail.pending_invitations/2` (lines 80–101) queries all pending invitations (no `revoked_at`, no `accepted_at`) and computes `expired?` in Elixir via `DateTime.compare(expires_at, now) == :lt` at line 119. An `expires_at` in the real past is all that is required to hit the "Expired" pill branch. The pending query does NOT filter out expired rows — it returns both active and expired pending invitations. [VERIFIED: codebase:detail.ex:91-101]

### Persona Count Assertions (Lockstep)

`seeds_test.exs:100` — `first.demo_users == length(Personas.all())` — asserts that the number of seeded demo users exactly matches the persona list length. Adding a new persona MUST be accompanied by incrementing this count, which is automatic because `length(Personas.all())` is called dynamically. However, `seeds_test.exs:119` — `assert count == length(Personas.all())` — also auto-derives from the list. No hardcoded persona count exists in the test; both assertions use `Personas.all()` dynamically. [VERIFIED: codebase:seeds_test.exs:100,119]

The `invitations` key in `snapshot_counts/0` (line 54–57) is scoped ONLY to `invited@demo.sigra.dev` (the original pending invite email), so adding a second invitation row for a different email does NOT change that assertion. But the idempotency test (`first == second`) will cover the new invitation row through the `audit_events` key if audit rows are also added. [VERIFIED: codebase:seeds_test.exs:54-57]

A new `expired-invite` invitation needs to be covered by a count key if strict idempotency checking is desired. Currently `snapshot_counts` does not count expired invitations. The planner must decide whether to add an `expired_invitations: count` key or rely on the `organizations: 2` stability.

### Deletion-Scheduled Pill — CRITICAL CODE GAP

The UI-SPEC and CONTEXT.md state that "Deletion scheduled" should render in the org roster when `member.user.deleted_at` is non-nil. HOWEVER, as verified by reading the live code:

1. `organization_live.ex:132-143` (the org roster template) renders ONLY role/locked/confirmed/unconfirmed pills — NO deletion-scheduled pill. [VERIFIED: codebase:organization_live.ex:135-138]
2. `Detail.shape_member_row/1` (line 103–113) builds a map with `user:`, `role:`, `confirmed?:`, `locked?:`, `display_name:` — NO `deleted_at` or `deletion_scheduled?` field. [VERIFIED: codebase:detail.ex:103-113]

FIXT-02 therefore requires TWO code changes plus the seed:
- Add `deletion_scheduled?: not is_nil(Map.get(user, :deleted_at))` to `shape_member_row/1` in `detail.ex`
- Add `<span :if={member.deletion_scheduled?} class="sg-status-pill" data-tone="warn">Deletion scheduled</span>` to the roster template in `organization_live.ex`
- Seed an Acme member with `scheduled_deletion: true`

The "Deletion scheduled" pill for the users INDEX (`users_index_live.ex:355`) already works via `maybe_append(row.user.deleted_at, {"Deletion scheduled", "warn"})`. [VERIFIED: codebase:users_index_live.ex:355] The org ROSTER is a separate code path that is missing the same logic.

### `format_date/1` Divergence — CONFIRMED

`organization_live.ex` has a LOCAL `format_date/1` at lines 190–191 that only handles `%DateTime{}` and falls back to `"—"` for all other values including `%NaiveDateTime{}`. [VERIFIED: codebase:organization_live.ex:190-191]

`Sigra.Admin.Components` has a SHARED `format_date/1` at lines 407–413 that handles `%DateTime{}`, `%NaiveDateTime{}`, `nil`, and raises `ArgumentError` for any other type. [VERIFIED: codebase:components.ex:407-413]

The `expires_at` field on `OrganizationInvitation` is typed as `DateTime.t() | nil` in the `Detail.invitation_row()` typespec (line 33). If Ecto stores it as `NaiveDateTime` (depending on migration type), the local `format_date/1` would silently render "—" instead of the expiry date. The `admin-format-date-naivedatetime` todo says to harden this. The fix is to either:
- Replace the local `format_date/1` in `organization_live.ex` with a call to the shared helper (requires importing or delegating to `Sigra.Admin.Components` private helpers — not directly accessible), or
- Expand the local `format_date/1` to handle `NaiveDateTime` as well

Since `format_date/1` in components.ex is `defp`, the cleanest fix is to expand the local clause in `organization_live.ex` to match the shared one.

### `notice/1` Slot Content — `org-notice-nested-p` Status

The `notice/1` component renders: `<div class="sg-notice"><p class="sg-text-sm">{render_slot(@inner_block)}</p></div>`. [VERIFIED: codebase:components.ex:302-308]

In `organization_live.ex` (lines 64–68), the notice slot contains only inline text and an `<a>` tag — no block `<p>` elements. [VERIFIED: codebase:organization_live.ex:64-68]

In `index_live.ex` (lines 54–59), the notice slot similarly contains only inline text and an `<a>` tag. [VERIFIED: codebase:index_live.ex:54-59]

In `user_show_live.ex` (line 132), the notice slot contains `{elem(summary_alert(@detail), 1)}` — a string, not a block element. [VERIFIED: codebase:user_show_live.ex:132]

The `org-notice-nested-p` CONTEXT.md description says "passes block `<p>` children into the notice's `<p>` wrapper." As of this research, no current call site does this. The issue may be the POTENTIAL for it: the notice's `<p>` wrapper means any call site that passes block-level content (future additions) would produce invalid HTML. The fix is to change the wrapper from `<p>` to `<div>` in `components.ex` — this eliminates the hazard for all call sites including future ones.

### Motion Budget Status (GATE-03)

All motion contracts from the CONTEXT.md verified against live CSS:

| Claim | Line(s) | Status |
|-------|---------|--------|
| `--sg-ease-out` value | `app.css:123` | VERIFIED: `cubic-bezier(0.23, 1, 0.32, 1)` |
| `--sg-motion-pop` 180ms | `app.css:118` | VERIFIED |
| `--sg-motion-press` 120ms | `app.css:117` | VERIFIED |
| `--sg-motion-fast` 140ms | `app.css:119` | VERIFIED |
| Toast enter: `sg-toast-enter`, `--sg-motion-pop`, `--sg-ease-out` | `app.css:1294-1296` | VERIFIED |
| Toast leave: flat `--sg-ease-out` (not spring) | `app.css:1297-1299` | VERIFIED |
| Cmdk dialog enter: `--sg-motion-pop`, `--sg-ease-out` | `app.css:1334-1336` | VERIFIED |
| Cmdk active row: NO transition (intentionally instant) | `app.css:1368-1369` | VERIFIED — `.sg-cmdk__item.is-active` and `[aria-selected="true"]` have NO `transition` property |
| `sg-filter-chip` has press+tone transitions | `app.css:869` | VERIFIED: `transition: var(--sg-transition-tone), var(--sg-transition-press)` |
| `sg-filter-chip` hover guarded with pointer:fine | `app.css:871-877` | VERIFIED: `@media (hover: hover) and (pointer: fine)` wraps hover rules |
| `prefers-reduced-motion` strips transforms+keyframes | `app.css:1458-1467` | VERIFIED |

**D-06 Fork Resolution — Recommendation:**

`--sg-transition-press` is `transform var(--sg-motion-fast) var(--sg-ease)` (line 126). This fires on `.sg-filter-chip` unconditionally (line 869). A keyboard user toggling a filter chip via space/enter will see the press transform animation.

The gate contract says "keyboard-frequent interactions are not animated." Filter chip toggling (applying a filter) is a keyboard-frequent action. The existing hover guard at line 871 already demonstrates the pattern for scoping chip effects to pointer devices.

**Recommendation: scope both `transition` properties on `.sg-filter-chip` to the `@media (hover: hover) and (pointer: fine)` guard.** The change is:

```css
/* Before (app.css:869) — applies to all input devices */
.sg-filter-chip {
  transition: var(--sg-transition-tone), var(--sg-transition-press);
}

/* After — move transition into the existing pointer-fine guard */
@media (hover: hover) and (pointer: fine) {
  .sg-filter-chip {
    transition: var(--sg-transition-tone), var(--sg-transition-press);
  }
  .sg-filter-chip:hover { ... }
}
```

This is ~3 CSS lines inside `@layer sg-components`, no new tokens, no new deps, and makes the motion contract unambiguously compliant. [VERIFIED: codebase:app.css:858-892]

### Playwright Coherence Filmstrip — D-07 Fork Resolution

**Current `admin-checkpoints.spec.ts` facts:**
- Location: `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` [VERIFIED: codebase]
- Uses ad-hoc `registerUser()` / `createOrganization()` fixtures (lines 49–72), NOT the Seeds personas [VERIFIED: codebase:admin-checkpoints.spec.ts:164-172]
- Already journeys: global overview, org overview, global users index, user detail, org-scoped admin, impersonation banner, per-user audit, audit explorer [VERIFIED: codebase:admin-checkpoints.spec.ts:150-345]
- Each checkpoint uses `assertCheckpointScreenshot` which calls `toHaveScreenshot()` — committed baseline snapshots in `admin-checkpoints.spec.ts-snapshots/` [VERIFIED: codebase:admin-checkpoints.spec.ts:132-148]

**What the coherence filmstrip needs to verify:**
- `<.scope_ribbon>` presence on screens 2–6 (already asserted for users index and audit explorer in current spec)
- `<.page_back>` on detail screens (already asserted for per-user audit: line 282)
- Empty-state spacing consistency (not currently tested)
- Notice/flash unification (partially tested via `expect(page.locator('.sg-notice').first()).toBeVisible()` at lines 183, 194)
- Focus ring / hover parity (needs keyboard-only navigation pass)
- Back-nav round-trips (partially covered by impersonation flow)
- New seed states: "Expired" pill, in-roster "Deletion scheduled" pill, "Passkeys" pill

**D-07 Fork Resolution — Recommendation:**

Use **ad-hoc fixtures** (not the seeded demo DB) for the new pill states. Rationale:

1. The existing spec already uses ad-hoc fixtures — extending it in-place preserves the single-spec, single-authenticated-journey discipline.
2. The demo DB is only seeded in the dev environment (`mix run priv/repo/seeds.exs`), not in Playwright's test context (which uses the SQL Sandbox / ephemeral DB per the spec's `registerUser` pattern).
3. Ad-hoc fixtures for the new states are straightforward:
   - Passkey-only: register a new user, insert a display-only passkey row via the test API (or assert the pill via the global users index after the new passkey-only persona is registered in the demo DB... but this requires the seeded DB). Since Playwright runs against the dev server (not sandbox), using the seeded demo DB IS actually viable. However, seeded-DB approach means the coherence filmstrip depends on `mix run priv/repo/seeds.exs` having been run, introducing a CI dependency.
4. **Preferred approach:** Implement the coherence sweep assertions as a **sibling spec** (`admin-coherence-sweep.spec.ts`) that focuses on DOM-level assertions (pill text, component presence, focus behavior) rather than pixel screenshots. This spec uses ad-hoc `registerUser` helpers for the new states and does NOT call `toHaveScreenshot()`. This prevents baseline churn entirely — Phase 160 ratifies baselines; Phase 159 only asserts behavior. The new seed states are verified by text assertions like `await expect(page.locator('.sg-status-pill[data-tone="risk"]')).toContainText('Expired')`.
5. For the pill states that require the new personas (passkey-only, deletion-scheduled member), the sibling spec creates those states via the API (register user, API call to insert passkey row) — mirroring how the existing spec creates organizations via the UI.

**CAVEAT on passkey ad-hoc fixture:** The existing passkey seed inserts a display-only row directly via `UserPasskey.create_changeset`. There is no UI flow to create a passkey from Playwright. The sibling spec would need either a test-only API endpoint or would need to assert the passkey-only pill state via a pre-seeded persona in the demo DB. This is the one case where seeded-DB access is harder to avoid. **Recommendation:** For the passkey-only pill assertion only, assert against the demo DB persona (`pat@demo.sigra.dev`) by logging in as admin and navigating to `/admin/users?q=pat%40demo.sigra.dev`. This requires `mix run priv/repo/seeds.exs` to have run in the dev environment. Document this dependency in the spec.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Audit idempotency | Custom dedup logic | `length(@audit_actions) + length(@persona_audit_events)` threshold guard — already in seeds.ex:548 |
| Invitation expiry computation | DB-side query filter | Elixir `DateTime.compare` in `Detail.shape_invitation_row/2` — already at detail.ex:119 |
| CSS motion scoping | New tokens or JS | `@media (hover: hover) and (pointer: fine)` guard already used at app.css:871 |
| Playwright auth | Custom auth flow | `registerUser()` helper already in admin-checkpoints.spec.ts:49 |
| Audit tone derivation | Per-screen tone logic | `audit_tone/1` in components.ex:398-400 (single source of truth from Phase 158) |

---

## Common Pitfalls

### Pitfall 1: Inline `Repo.insert!` Outside the Counted Lists
**What goes wrong:** Adding a `Repo.insert!` call for an audit row outside `@audit_actions` or `@persona_audit_events` causes the count-threshold guard to under-count. A second `Seeds.run/0` re-fires the insert and accumulates duplicates. The idempotency test fails.
**Why it happens:** The guard at `seeds.ex:548` only counts rows tied to demo user IDs — it does not distinguish inline inserts from list-driven inserts. Any inline insert bypasses the threshold calculation.
**How to avoid:** ONLY add rows by appending to `@audit_actions` or `@persona_audit_events`. Never add a standalone `Repo.insert!` for audit events.
**Warning signs:** The idempotency test (`first == second` in `seeds_test.exs:96`) fails on the `audit_events` key count.

### Pitfall 2: Using `DateTime.utc_now()` for `occurred_at`
**What goes wrong:** Non-deterministic timestamps break reproducibility. Re-runs produce different timestamps, which technically passes idempotency (counts match) but produces non-reproducible data that can cause flaky tests anchoring on specific timestamps.
**Why it happens:** Developers default to `DateTime.utc_now()` for "current" timestamps.
**How to avoid:** All `occurred_at` values MUST use `DateTime.add(@seed_reference_ts, -offset * 86_400, :second)`.
**Warning signs:** The seed produces different `occurred_at` values on consecutive runs.

### Pitfall 3: Missing `effective_user_id` on Audit Rows
**What goes wrong:** Audit rows tied only via `actor_id` do not surface on the per-user admin detail page. The per-user audit query at `audit/query.ex` filters by `effective_user_id`.
**Why it happens:** `actor_id` feels like the natural "who did this" field. `effective_user_id` is the subject for display purposes.
**How to avoid:** Always set `effective_user_id: subject.id` on persona audit events (mirroring `seeds.ex:599`). Always set `effective_user_id: admin.id` on admin-tied events (mirroring `seeds.ex:575`).

### Pitfall 4: Adding Personas Without Updating `feature_map/0`
**What goes wrong:** `Seeds.print_credentials/0` calls `Personas.feature_map()[local]` to print the feature description. A missing key returns `nil` and prints a nil description. No runtime error, but the credentials display is broken.
**Why it happens:** `feature_map/0` is a separate function from `all/0` and is easy to forget.
**How to avoid:** Every new persona added to `all/0` MUST have a matching entry in `feature_map/0` at `personas.ex:147`.

### Pitfall 5: Persona Count Test — Snapshot Counts Scope
**What goes wrong:** The `snapshot_counts/0` helper in `seeds_test.exs` scopes `invitations:` to `invited@demo.sigra.dev` only (line 54–57). Adding a second expired invitation row for `expired-invite@demo.sigra.dev` does NOT change the `invitations: 1` count. If the planner wants to assert the expired invitation was seeded, a new test assertion or snapshot key is needed.
**Why it happens:** The original invitation scope was narrow by design (one pending invite was the only expected row).
**How to avoid:** Add a separate test assertion for the expired invitation row rather than expecting `snapshot_counts` to cover it. Or add an `expired_invitations:` key to `snapshot_counts`.

### Pitfall 6: Deletion-Scheduled Pill Missing from Org Roster (FIXT-02 Code Gap)
**What goes wrong:** Seeding a deletion-scheduled Acme member without the corresponding code changes in `organization_live.ex` and `detail.ex` produces a persona with a `deleted_at` value but NO visible "Deletion scheduled" pill in the org roster, silently failing FIXT-02.
**Why it happens:** The `organization_live.ex` roster template does not have a deletion-scheduled pill (verified). `detail.ex:shape_member_row/1` does not include `deleted_at`.
**How to avoid:** FIXT-02 requires THREE changes, not one: (1) new/modified seed data, (2) `shape_member_row/1` exposes `deletion_scheduled?:`, (3) roster template emits the pill.
**Warning signs:** Org overview renders without a "Deletion scheduled" pill even after seeding.

### Pitfall 7: Passport/MFA Seed Attaches to Wrong Persona
**What goes wrong:** The existing `seed_passkey/1` attaches only to `admin@demo.sigra.dev` who already has TOTP. The "Passkeys" (no MFA) pill branch (`not has_mfa and passkey_count > 0`) is never reached by admin — admin hits "MFA + passkeys" first.
**Why it happens:** Adding a passkey to an existing MFA user does not help; only a passkey-only user demonstrates the branch.
**How to avoid:** FIXT-03 requires a NEW persona with `totp: false, passkey: true`. `seed_passkey/1` must be extended to also handle this new persona (or a new helper added). Currently `seed_passkey/1` hard-codes `admin = users["admin@demo.sigra.dev"]`.

### Pitfall 8: `allow_reserved: true` Omission
**What goes wrong:** Any audit event insertion using a reserved prefix without `allow_reserved: true` raises `ArgumentError` and aborts the entire seed transaction, leaving the DB partially seeded.
**Why it happens:** The `AuditEvent.changeset/3` third-arg option is easy to omit when copy-pasting code.
**How to avoid:** Every batch insert in `seeds.ex` already passes `allow_reserved: true` at lines 577 and 601. Verify new entries match this pattern.

### Pitfall 9: `sg-filter-chip` Transition Without Pointer Guard
**What goes wrong:** Removing the transition from `.sg-filter-chip` at the top level also removes the pointer-device hover animation. The fix must KEEP the transitions for pointer devices while removing them for keyboard/touch.
**How to avoid:** Move the `transition` property inside the existing `@media (hover: hover) and (pointer: fine)` block, alongside the hover rules. Do NOT remove it entirely.

### Pitfall 10: Playwright Baseline Churn from New Seed States
**What goes wrong:** If the coherence filmstrip uses `toHaveScreenshot()` and visits pages that show the new seed states, Phase 160's baseline ratification is conflated with Phase 159's implementation. Unintended re-records in Phase 159 are bugs.
**Why it happens:** Adding `toHaveScreenshot()` assertions to a spec that navigates to new seed states will fail against existing baselines.
**How to avoid:** Phase 159's filmstrip asserts BEHAVIOR (DOM text, component presence, CSS classes, aria attributes), not pixels. All `toHaveScreenshot()` baseline captures happen in Phase 160.

---

## Code Examples

### Pattern: Appending a Persona Audit Event [VERIFIED: codebase:seeds.ex:435-532]

```elixir
# Append to @persona_audit_events — auto-counted by threshold guard
%{
  email: "pat@demo.sigra.dev",          # subject: the new passkey-only persona
  actor: "pat@demo.sigra.dev",          # actor: same user (self-action)
  action: "auth.password.change",       # reserved prefix: "auth." — OK
  outcome: "success",
  offset: 30,                           # DateTime.add(@seed_reference_ts, -30 * 86_400, :second)
  org: nil                              # or :acme if this persona is an Acme member
}
```

### Pattern: Adding a Passkey for a New Persona [VERIFIED: codebase:seeds.ex:294-312]

```elixir
# In seed_passkey/1 — extend to handle multiple personas
defp seed_passkey(users) do
  admin = users["admin@demo.sigra.dev"]
  pat = users["pat@demo.sigra.dev"]   # new passkey-only persona

  upsert_passkey(admin, "sigra-demo-admin-passkey-credential-id-v1")
  upsert_passkey(pat, "sigra-demo-pat-passkey-credential-id-v1")
end

defp upsert_passkey(user, seed_string) do
  credential_id = :crypto.hash(:sha256, seed_string)
  public_key = :crypto.hash(:sha256, seed_string <> "-pubkey")

  %UserPasskey{}
  |> UserPasskey.create_changeset(%{
    user_id: user.id,
    credential_id: credential_id,
    public_key: public_key,
    nickname: "Demo Security Key"
  })
  |> Repo.insert!(on_conflict: :nothing, conflict_target: [:credential_id])
end
```

### Pattern: Roster Deletion-Scheduled Pill Fix [VERIFIED: codebase:organization_live.ex:132-143, detail.ex:103-113]

```elixir
# detail.ex — add deletion_scheduled? to shape_member_row/1
defp shape_member_row(%{user: user, role: role}) do
  display_name = Map.get(user, :display_name) || Map.get(user, :email)

  %{
    user: user,
    role: role,
    confirmed?: not is_nil(Map.get(user, :confirmed_at)),
    locked?: not is_nil(Map.get(user, :locked_at)),
    deletion_scheduled?: not is_nil(Map.get(user, :deleted_at)),  # NEW
    display_name: display_name
  }
end
```

```heex
<%!-- organization_live.ex — add deletion pill to roster template --%>
<span :if={member.locked?} class="sg-status-pill" data-tone="risk">Locked</span>
<span :if={member.deletion_scheduled?} class="sg-status-pill" data-tone="warn">Deletion scheduled</span>
<span :if={member.confirmed?} class="sg-status-pill" data-tone="ok">Confirmed</span>
<span :if={not member.confirmed?} class="sg-status-pill" data-tone="warn">Unconfirmed</span>
```

### Pattern: `format_date/1` Fix in `organization_live.ex` [VERIFIED: codebase:organization_live.ex:190-191]

```elixir
# Replace the local format_date/1 with NaiveDateTime support
defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%Y-%m-%d")
defp format_date(nil), do: "—"
defp format_date(_), do: "—"
```

### Pattern: CSS Motion Scope Fix for `sg-filter-chip` [VERIFIED: codebase:app.css:858-892]

```css
/* In @layer sg-components — move transition inside the pointer guard */
.sg-filter-chip {
  display: inline-flex;
  /* ... all other properties ... */
  /* REMOVE: transition: var(--sg-transition-tone), var(--sg-transition-press); */
}
@media (hover: hover) and (pointer: fine) {
  .sg-filter-chip {
    transition: var(--sg-transition-tone), var(--sg-transition-press); /* MOVED here */
  }
  .sg-filter-chip:hover {
    background: var(--sg-color-brand-soft);
    box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--sg-color-brand) 24%, transparent);
    transform: translateY(-1px);
  }
}
```

### Pattern: Coherence Filmstrip Sibling Spec Structure [VERIFIED: codebase:admin-checkpoints.spec.ts:49-72]

```typescript
// admin-coherence-sweep.spec.ts — sibling spec, behavior assertions only
// No toHaveScreenshot() — pixel baselines are Phase 160

import { test, expect, type Page } from '@playwright/test';
import { registerUser } from '../helpers/fixtures';  // or inline

test.describe('Phase 159 coherence sweep', () => {
  test('scope_ribbon, page_back, notice, empty-state across 6 screens', async ({ page }) => {
    // ad-hoc admin
    const adminEmail = `platform-admin+coherence-${Date.now()}@example.test`;
    await registerUser(page, adminEmail, TEST_PASSWORD);

    // Screen 1: global overview — scope_ribbon NOT required (overview archetype)
    await page.goto('/admin');
    await expect(page.locator('.sg-notice').first()).toBeVisible();

    // Screen 2: org overview — notice present, scope_ribbon expected
    // ...

    // Screen 3: users index — scope_ribbon present
    await page.goto('/admin/users');
    await expect(page.locator('.sg-scope-ribbon')).toBeVisible();

    // Keyboard-only motion check: tab through filter chips, assert no transition fires
    // (use page.keyboard.press('Tab') and check computed style)
  });
});
```

---

## Runtime State Inventory

This is not a rename/refactor phase. No runtime state migration is required. The seed module runs only in dev/non-test environments. Demo DB state is ephemeral per the Playwright test setup.

**None — verified by codebase inspection.** Seeds run against the dev database. Playwright tests use `registerUser` ad-hoc fixtures, not the seeded demo DB. No OS-registered state, no secrets, no env vars change.

---

## Open Questions

1. **Passkey-only persona for Playwright verification**
   - What we know: Playwright uses ad-hoc fixtures; inserting a display-only passkey row requires a direct DB call or test API not currently exposed
   - What's unclear: Whether the sibling spec can verify the "Passkeys" pill without either (a) a test-only DB-insert endpoint or (b) depending on the seeded demo DB
   - Recommendation: Assert the passkey-only pill against the seeded demo DB persona (`pat@demo.sigra.dev`) in the coherence spec, with a documented dependency that `mix run priv/repo/seeds.exs` must have been run in the dev environment. Alternatively, skip pixel assertion and rely on ExUnit tests for the passkey pill path.

2. **`snapshot_counts` coverage of expired invitation**
   - What we know: `snapshot_counts` scopes `invitations:` only to `invited@demo.sigra.dev`
   - What's unclear: Whether the planner wants strict idempotency testing of the expired invitation row
   - Recommendation: Add a standalone test assertion in `seeds_test.exs` that verifies exactly one expired invitation row for `expired-invite@demo.sigra.dev` exists after `Seeds.run/0`.

3. **Dave's org membership and FIXT-02 options**
   - What we know: Dave (`dave@demo.sigra.dev`) has `org_member: nil` in personas.ex — he is NOT an Acme member (contradicting the misleading `seed_memberships` comment which suggests he is added to Acme). Checking `seeds.ex:225`: `upsert_membership(dave.id, acme.id, :member)` IS called. So Dave IS an Acme member but is locked (not deletion-scheduled). Frank has `scheduled_deletion: true` but `org_member: nil` — he is never added to any org.
   - What's unclear: Whether the planner prefers to add `scheduled_deletion: true` to an existing Acme member (e.g., Alice or Dave) or add a NEW persona (`pat@demo.sigra.dev` or similar).
   - Recommendation: Add a NEW Acme member persona (e.g., `grace@demo.sigra.dev`) with `scheduled_deletion: true, org_member: :acme`. This avoids mutating existing personas whose states are tested individually (Alice/Carol are confirmed+happy, Dave is locked). Grace demonstrates the deletion-scheduled-in-org state cleanly.

---

## Environment Availability

This phase operates only on the existing dev environment and test suite. No new external dependencies.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | Seeds, Ecto tests | Must be running (see CLAUDE.md) | 16-alpine (Docker) | None — tests fail fast |
| Playwright | Coherence filmstrip | Available in test/example/priv/playwright | Per `package.json` | None |
| Node.js | Playwright | Must be installed | Per `playwright.config.ts` | None |
| mix (Elixir) | Seeds, ExUnit | Available | Elixir ~> 1.18 | None |

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`. Validation architecture section is required.

### Test Framework

| Property | Value |
|----------|-------|
| ExUnit framework | `mix test` in project root; ExUnit in `test/example/` |
| Config file | `test/example/test/test_helper.exs` |
| Quick run command (seeds) | `mix test test/example/test/example/demo/seeds_test.exs` |
| Full suite command | `mix test` |
| Playwright quick run | `npx playwright test admin-coherence-sweep.spec.ts --project=admin-checkpoints-chromium` |
| Playwright full suite | `npx playwright test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FIXT-01 | Expired invitation row exists after Seeds.run/0; org overview renders "Expired" pill | unit (ExUnit) | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — add assertion |
| FIXT-02 | Deletion-scheduled Acme member exists; org roster emits "Deletion scheduled" pill | unit (ExUnit) + Playwright | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — add assertion |
| FIXT-03 | Passkey-only persona exists; "Passkeys" pill renders on users index | unit (ExUnit) | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — add assertion |
| FIXT-04 | New audit action strings present in `@audit_actions`/`@persona_audit_events` | unit (ExUnit) | `mix test test/example/test/example/demo/seeds_test.exs` | ✅ — existing `audit liveness` describe block needs extended assertions |
| FIXT-05 | Seeds.run/0 twice → identical counts (including new rows) | unit (ExUnit) | `mix test test/example/test/example/demo/seeds_test.exs -t idempotency` | ✅ — idempotency test auto-covers via dynamic `length(Personas.all())` |
| GATE-03 | Keyboard-only Playwright pass: no animation on filter chip toggle by keyboard | e2e (Playwright) | `npx playwright test admin-coherence-sweep.spec.ts` | ❌ Wave 0 |

### Idempotency Verification (FIXT-05 Core Invariant)

The canonical idempotency test is `seeds_test.exs:88-103`:
```
run Seeds.run/0 twice → first == second (all snapshot_counts keys identical)
```

New rows added to `@audit_actions` or `@persona_audit_events` are automatically covered by the threshold guard. New personas are automatically covered by the dynamic `length(Personas.all())` check. The ONLY risk is inline `Repo.insert!` outside the lists (Pitfall 1 above).

New assertion needed:
- `snapshot_counts` either gains `expired_invitations: 1` key OR a dedicated test assertion checks for it separately
- `passkeys: N` count in `snapshot_counts` updates (currently only admin's passkey is counted; adding a new passkey-only persona increases this by 1)

### Sampling Rate

- **Per task commit:** `mix test test/example/test/example/demo/seeds_test.exs` (covers FIXT-01–05)
- **Per wave merge:** `mix test` full suite + `mix test test/example/test/example/demo/seeds_test.exs`
- **Phase gate:** Full ExUnit suite green + Playwright coherence-sweep spec green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts` — covers GATE-03 + criterion 4 filmstrip
- [ ] New seed assertions in `seeds_test.exs`: expired invitation count, passkey-only persona passkey count, deletion-scheduled Acme member, new audit action strings

---

## Security Domain

This phase makes no changes to authentication logic, session management, or access control. All changes are:
- Demo seed data in `test/example/` (not shipped to host apps)
- CSS motion scoping in the example app's static assets
- Playwright test additions

ASVS categories are not applicable to this phase's scope. [VERIFIED: phase description — no auth code changes]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `expires_at` on `OrganizationInvitation` is stored as `DateTime` (not `NaiveDateTime`) in PostgreSQL | `format_date/1` analysis | If stored as `NaiveDateTime`, the local `format_date/1` in `organization_live.ex` silently renders "—" for expiry dates — a user-facing regression |
| A2 | `Detail.pending_invitations/2` returns expired rows (does not filter them out) | FIXT-01 analysis | If expired rows are filtered, FIXT-01 requires a different approach (separate query or flag) |
| A3 | The Playwright `admin-coherence-sweep.spec.ts` sibling runs in the same `admin-checkpoints-*` projects | D-07 resolution | If it runs in a different project, baseline management changes |

Items A2 has been partially verified: `detail.ex:91-101` queries `WHERE accepted_at IS NULL AND revoked_at IS NULL` — no filter on `expires_at`. Both active and expired pending invitations are returned. [VERIFIED: codebase:detail.ex:91-101] A2 is therefore CONFIRMED, not assumed.

---

## Sources

### Primary (HIGH confidence — verified against live codebase)

All claims in this research were verified by direct file reads of:
- `test/example/lib/example/demo/seeds.ex` — seed orchestrator, idempotency guards, lists
- `test/example/lib/example/demo/personas.ex` — persona definitions, feature_map/0
- `test/example/test/example/demo/seeds_test.exs` — count assertions, idempotency test
- `lib/sigra/admin/live/organization_live.ex` — invitation pills, roster template, format_date/1
- `lib/sigra/admin/live/users_index_live.ex` — status_pills/1, deletion pill
- `lib/sigra/admin/organizations/detail.ex` — shape_member_row/1, shape_invitation_row/2
- `lib/sigra/admin/audit/presenter.ex` — action_label/1 titleization fallback
- `lib/sigra/audit.ex` — reserved prefix enforcement, @default_reserved
- `lib/sigra/admin/components.ex` — notice/1 slot wrapper, format_date/1, scope_ribbon/1
- `test/example/priv/static/assets/css/app.css` — motion tokens, sg-filter-chip, cmdk, prefers-reduced-motion
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — existing journey, ad-hoc fixtures
- `.planning/config.json` — nyquist_validation: true, commit_docs: true

---

## Metadata

**Confidence breakdown:**
- Seed enrichment patterns: HIGH — verified against live seeds.ex and seeds_test.exs
- FIXT-02 code gap discovery: HIGH — verified by reading organization_live.ex and detail.ex
- Motion budget: HIGH — verified against app.css line by line
- D-06 fork recommendation: HIGH — reasoning from verified CSS + existing pattern at line 871
- D-07 fork recommendation: MEDIUM — architectural recommendation; planner may override
- Playwright filmstrip structure: MEDIUM — based on existing spec; actual implementation will vary

**Research date:** 2026-06-04
**Valid until:** 2026-06-11 (7 days — fast-moving phase, actively being implemented)
