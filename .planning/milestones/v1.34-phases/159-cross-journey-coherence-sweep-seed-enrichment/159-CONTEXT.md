# Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Final coherence + seed-enrichment phase of the **v1.34 ADMIN-UI-COHERENCE** milestone.
Three jobs, no net-new surfaces:

1. **Seed enrichment (FIXT-01–05):** make every previously-empty admin UI state
   self-demonstrating in the demo DB — expired invitation, in-roster deletion-scheduled
   member, passkey-only persona, richer audit variety — while staying deterministic,
   idempotent, and test-env-guarded.
2. **Motion usage audit (GATE-03):** inventory + verify the existing motion budget against
   the keyboard-frequent / ease-out-enter / flat-destructive contract; fix only genuine
   violations.
3. **Coherence sweep (criterion 4):** confirm empty-state spacing, notice/flash unification,
   focus/hover parity, back-nav round-trips, and `<.scope_ribbon>` presence across all 6
   admin screens via a scripted Playwright journey.

**Out of scope:** new admin surfaces, new auth capability, broad CSS redesign, new Hex deps.
Phase 160 ratifies baselines — deliberate captures here are expected; *unintended*
re-records are bugs (keystone law).
</domain>

<decisions>
## Implementation Decisions

### Area 1 — Expired invitation seed (FIXT-01)
- **D-01 [Confident → locked]:** Add a **second** Acme `OrganizationInvitation` row (new email,
  e.g. `expired-invite@demo.sigra.dev`) with `expires_at` pinned in the **real past**. Do NOT
  mutate the existing pending invitation — keep `invited@demo.sigra.dev` future-dated
  (`~U[2026-06-30]`) so both the "Expires {date}" and "Expired" branches render simultaneously.
  - **Why:** `expired?` is computed against `DateTime.utc_now()`, not `@seed_reference_ts`
    (`apps/.../detail.ex:118-119`); any fixed past constant works (today ≫ `@seed_reference_ts`).
    Pill renders via `data-tone="risk"` only when `invite.expired?`
    (`organization_live.ex:157,162`). Pending guard is per-(org,email) `is_nil(accepted_at)/
    is_nil(revoked_at)` (`seeds.ex:247-256`) → a distinct email does not conflict.
  - **Hard-fail boundary:** Do not flip the existing invite's expiry — that trades one empty
    state ("Expires {date}") for another, violating criterion 1.

### Area 2 — Passkey-only persona + in-roster deletion-scheduled member (FIXT-02, FIXT-03)
- **D-02 [Confident → locked]:** Add a **NEW** passkey-only persona (`totp: false, passkey: true`)
  to drive the "Passkeys" (no-MFA) pill. The existing passkey seed attaches to the TOTP `admin`,
  who hits the "MFA + passkeys" branch first — it cannot demonstrate passkey-only.
  - **Why:** `status_pills/1` returns `{"Passkeys","ok"}` only when `not has_mfa and
    passkey_count > 0` (`users_index_live.ex:347-350`).
- **D-03 [Confident → locked]:** Make a **member of Acme** scheduled for deletion (add
  `scheduled_deletion: true` to an Acme member persona, or add a new Acme member persona with
  it). Frank is scheduled-deletion but belongs to no org, so he never appears in a roster.
  - **Why:** roster pills render over org memberships only (`organization_live.ex:135-138`);
    the "Deletion scheduled" pill comes from `row.user.deleted_at` (`users_index_live.ex:355`);
    Frank has `org_owner/admin/member: nil` (`personas.ex:110-123`).
  - **Lockstep requirement:** adding personas forces matching updates to `feature_map/0`
    (`personas.ex:147`) and every persona-count assertion (`seeds_test.exs:100,119`).

### Area 3 — Richer audit variety (FIXT-04)
- **D-04 [Confident → locked]:** Append rows to `@persona_audit_events` and/or `@audit_actions`
  using **already-reserved** action strings: `auth.password.change`, `auth.magic_link.*`,
  `api.token.create`, and `auth.oauth.link` with a **second provider** (e.g. `google`). No
  presenter change — `action_label/1` titleizes unknown actions (`presenter.ex:43-48`) and tone
  derives from `outcome`, not the action string.
  - **Why:** reserved prefixes (`auth. session. mfa. oauth. api. account. sigra.`) at
    `audit.ex:41`; every batch insert already passes `allow_reserved: true` (`seeds.ex:577,601`).
  - **Hard-fail boundary:** a new action without a reserved prefix, or a row that drops
    `allow_reserved: true`, raises ArgumentError and aborts the seed transaction. Do NOT add a
    presenter label clause — it touches lib-owned code for zero benefit.

### Area 4 — Determinism & idempotency in lockstep (FIXT-05)
- **D-05 [Confident → locked]:** The count-threshold guard is **derived from list lengths**
  (`demo_tied_count < length(@audit_actions) + length(@persona_audit_events)`, `seeds.ex:548`),
  so new rows are auto-covered IF added to those lists. "Lockstep" = (a) keep the lists as the
  single source of the threshold, (b) re-pin the `seeds_test.exs` count assertions (`>=15` at
  :241, `alice_tied >= 3` at :270, `first.demo_users == length(Personas.all())` at :100).
  - **Invariants (hard-fail):**
    - New audit rows MUST anchor `occurred_at` to `@seed_reference_ts` (`DateTime.add(...)`),
      NEVER `DateTime.utc_now/0` — else reproducibility breaks.
    - New audit rows MUST tie via `effective_user_id` (not just `actor_id`) — else they don't
      surface on the right per-user detail page (`seeds.ex:573-575`).
    - Do NOT add inline `Repo.insert!` audit rows outside the counted lists — the guard would
      under-count and a second `run/0` re-fires, accumulating duplicates → idempotency test fails.
  - **MIX_ENV guard location:** lives in `priv/repo/seeds.exs` (`Mix.env() == :test` raise) +
    the `test` mix alias never invoking it — NOT in the `Seeds` orchestrator (tests call
    `Seeds.run/0` directly inside the sandbox). "No leakage" = this two-layer defense holds.

### Area 5 — Motion usage audit (GATE-03)
- **D-06 [Likely → locked]:** GATE-03 is satisfied by **auditing + documenting** the existing
  motion system plus a **keyboard-only Playwright pass**, NOT by writing new motion code. The
  budget is already implemented: `--sg-ease-out` enters (`app.css:131-133`, toast :1295, cmdk
  :1335), flat non-spring destructive easing (`app.css:1290-1298`), keyboard-frequent
  interactions already transition-free (cmdk active row "intentionally instant", `app.css:1314`;
  `.sg-cmdk__item.is-active`/`[aria-selected]` :1368-1369), `prefers-reduced-motion` baseline
  (`app.css:1458-1467`). Fix ONLY genuine violations.
  - **Open fork (planner's discretion, below escalation threshold):** `sg-filter-chip` press/tone
    transitions (`app.css:869`). If "filter apply" counts as keyboard-frequent under the gate's
    strict reading, a small CSS scoping change inside `@layer sg-components` resolves it — still no
    new deps/Tailwind. Adjudicate during planning.

### Area 6 — Coherence sweep verification (criterion 4)
- **D-07 [Likely → locked]:** The **6 screens** are: global overview (`/admin`), org overview
  (`/admin/organizations/:slug`), users index (`/admin/users`), user audit/show
  (`/admin/users/:id/audit`), audit explorer (`/admin/audit`), org roster (roster section of the
  org overview / `/admin/organizations/:slug/users`). Implement the "journey filmstrip" as an
  **extension of the existing `admin-checkpoints.spec.ts`** (or a sibling reusing its helpers) —
  it already runs a single authenticated journey across all 6 with `scope_ribbon` + back-nav
  assertions and committed baselines. Do NOT create a net-new surface.
  - **Open fork (planner's discretion):** checkpoints uses ad-hoc `registerUser` fixtures, NOT the
    `Seeds` personas. Verifying the **new seed states** (expired pill, in-roster deletion, passkey-
    only) requires either pointing the journey at the seeded demo DB OR registering equivalent
    fixtures. Resolve during planning; whichever path keeps baseline churn minimal wins.

### Folded Todos
- **`org-notice-nested-p`** — fix the `organization_live` notice that passes block `<p>` children
  into the notice's `<p>` wrapper (nested `<p>`, a LiveView patch-desync hazard). Directly serves
  criterion 4's "notice/flash unification" on the org overview (one of the 6 screens).
- **`admin-format-date-naivedatetime`** (light) — harden `format_date/1` so non-DateTime host
  timestamps don't silently render as "—". FIXT-01 adds invitation rows whose `expires_at` renders
  via `format_date` on a checkpoint screen, so it's in the blast radius. Most deferrable of the
  folds if time-boxed.

### Claude's Discretion
- Exact persona emails/names, exact new audit action strings + second OAuth provider choice.
- Whether the in-roster deletion-scheduled member is a new Acme persona or a flag on an existing
  one (both satisfy D-03).
- Resolution of both open forks (D-06 chip transitions, D-07 fixture-vs-seeded-DB).
- Whether the journey filmstrip extends `admin-checkpoints.spec.ts` in-place or as a sibling spec.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 159 definition + success criteria
- `.planning/REQUIREMENTS.md` — FIXT-01…05, GATE-03
- `.planning/METHODOLOGY.md` — decisive-defaulting + escalation lenses
- `.planning/phases/158-audit-mobile-per-user-audit-high-effort/158-CONTEXT.md` — prior
  shared-component + audit-row decisions (D-01…D-04 there)
- `test/example/lib/example/demo/seeds.ex` — seed module (personas, invitation, MFA/passkey,
  audit lists, idempotency guards, `@seed_reference_ts`)
- `test/example/lib/example/demo/personas.ex` — persona definitions + `feature_map/0`
- `test/example/test/example/demo/seeds_test.exs` + `seeds_script_test.exs` — seed contracts
- `lib/sigra/admin/live/organization_live.ex` — invitation/expired pill + roster member pills
- `lib/sigra/admin/live/users_index_live.ex` — `status_pills/1` (passkey-only, deletion pill)
- `lib/sigra/admin/components.ex` — shared `sg-*` function components
- `test/example/priv/static/assets/css/app.css` — `sg-*` motion budget (ease-out, spring,
  prefers-reduced-motion, sg-filter-chip, sg-list-row, sg-cmdk)
- `admin-checkpoints.spec.ts` (under test/example) — existing single-journey checkpoint spec
  the coherence filmstrip extends
- Audit presenter + reservation: `lib/sigra/.../presenter.ex`, `lib/sigra/.../audit.ex`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Seed module is mature** (`seeds.ex`, 607 lines): personas, Acme/Beta orgs, pending
  invitation, MFA/passkey seeds, audit-action lists, transaction-wrapped count-threshold guard,
  `@seed_reference_ts ~U[2026-05-15 12:00:00Z]` anchor. Enrichment = append to existing lists +
  one new invitation clause + new persona(s), not new machinery.
- **Audit presenter has a generic titleizing fallback** (`presenter.ex:43-48`) → new action
  strings need zero label code.
- **Motion budget already fully implemented** in `app.css` (ease-out enters, flat destructive,
  transition-free keyboard nav, prefers-reduced-motion) — GATE-03 is verify-not-build.
- **`admin-checkpoints.spec.ts`** already journeys all 6 screens with scope_ribbon + back-nav
  assertions and committed baselines — criterion 4 extends it.

### Established Patterns
- Idempotency: `on_conflict: :nothing` keyed on unique indexes for most rows; **count-threshold
  guard** (derived from list lengths) for audit events (no unique index).
- Determinism: all timestamps anchor to `@seed_reference_ts`, never `utc_now`.
- Reserved action prefixes enforced at changeset; batch inserts pass `allow_reserved: true`.
- Pill/tone keys off `outcome` and user state flags, not action strings.
- "Same job → same component" milestone law (no bespoke per-screen patterns).

### Integration Points
- New invitation row → org overview "Expired"/"Expires" pills.
- New passkey-only persona → users-index "Passkeys" pill; new Acme deletion-scheduled member →
  org roster "Deletion scheduled" pill.
- New audit rows (tied via `effective_user_id`) → per-user audit detail + global audit explorer.
- New seed states must be visible to the coherence Playwright journey (fixture-vs-seeded-DB fork).
- **Flagged interaction:** the new deletion-scheduled seed member exercises the open
  `admin-overview-needs-review-count-link-mismatch` bug (count includes `:deleted` but deep-links
  to `?locked=true`). Verify the overview doesn't look broken; track a follow-on rather than
  guess-fix (a deliberate semantics decision is out of scope here).
</code_context>

<specifics>
## Specific Ideas

- Candidate persona email for expired invite: `expired-invite@demo.sigra.dev` (planner may pick).
- Candidate passkey-only persona: a new `pat@demo.sigra.dev` (`totp: false, passkey: true`).
- Second OAuth provider for audit variety: `google` (carol already uses `auth.oauth.link` —
  use a distinct provider/metadata for the second row).
</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
- **`sg-notice-tone-rule-duplication`** — already `status: folded` into phase-156 (shared-selector
  merge visible at `app.css:962-974`). Resolved; not 159 work.
- **`admin-overview-cleanup-misc`** — quality/refactor items (hardcoded paths, duplicated
  `runtime_config!/0`, `role_tone`) with no bearing on seed/motion/coherence criteria. Opportunistic.
- **`admin-overview-needs-review-count-link-mismatch`** — DEFER + FLAG. The new FIXT-02 seed will
  *exercise* this bug; needs a deliberate count-vs-deep-link semantics decision. Verify the overview
  doesn't visibly break during the sweep; file a tracked follow-on rather than guess-fix.
- **`admin-overview-notice-role-status`** — `role="status"` a11y adjudication needing a
  screen-reader decision; orthogonal to this phase's visual/seed criteria.
</deferred>
