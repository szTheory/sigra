# Phase 190: Flows & Fixture Data (L4) - Research

**Researched:** 2026-06-17
**Domain:** Playwright flow-spec authoring + demo seed verification + ledger ratification
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Three operator personas from `admin-ui-principles.md:9-13`: platform admin, support investigator (= platform admin in investigation posture, NOT a distinct authz role), org admin. Investigator flow driven by `admin@demo.vaultr.test` acting on subject personas.
- **D-02:** Investigator journey: find account → per-user audit evidence → impersonate → resolve → return. Asserts journey-level properties only; does NOT re-test impersonation internals.
- **D-03:** Flow-driver mapping: platform admin = `admin@demo.vaultr.test` (global posture); investigator = same operator (subject-first posture); org admin = `morgan@demo.vaultr.test` (tenant-bounded).
- **D-04:** Case mapping: happy = alice; main-error = dave (locked/unconfirmed) + org-admin permission-denied; boundary = frank/grace (scheduled-deletion), expired/pending invitation pair, and a true empty/no-data state.
- **D-05:** DATA-01 satisfied by existing `Example.Demo.Seeds.run/0`; planner verifies cases and enriches only genuine gaps; any enrichment seeds terminal state directly, uses relative timestamps from `@seed_reference_ts`, idempotent upserts, `MIX_ENV != :test` guard, `demo.vaultr.test` segregation.
- **D-06:** Seed enrichment lands ONLY in `test/example/lib/example/demo/{personas,seeds}.ex`; NO byte-identical-mirror obligation for seed data.
- **D-07:** 3 new ledger rows: `flow-platform-admin`, `flow-support-investigator`, `flow-org-admin` at `Level = L4`, lowercase-item / single-integer-tier, appended below the 6 existing L3 rows.
- **D-08:** Tier = weakest-link rollup (min() of constituent L3 pages + flow-only criteria). Demotion is first-class.
- **D-09:** 3 per-persona flow specs on the `chromium` behavior-truth lane (default: `admin-flow-platform-admin.spec.ts`, `admin-flow-support-investigator.spec.ts`, `admin-flow-org-admin.spec.ts`); shared `helpers/adminFlows.ts`; `waitForLiveViewReady`, role-selectors, stable testids; web-first auto-retrying assertions only; no sleeps.
- **D-10:** No net-new CSS/JS expected. Keyboard: `Tab`/`Enter`/`Space`/`Esc`; `toBeFocused()` after Tab; assert focus-containment invariant not exact element; focus returns to trigger after dialog close. Reduced-motion: `reducedMotion: 'reduce'` at context/config level; assert collapsed CSS effect not just `matchMedia`. Theme: assert `data-sg-admin-theme`/`data-theme`/`localStorage`; cover nav + `page.reload()` + system-flip + no-flash via `addInitScript`.
- **D-11:** If a real defect surfaces (keyboard trap, missed reduced-motion, theme flash), fix becomes shipped CSS/JS — triggers three-surface byte-parity rule.
- **D-12:** Return-context: URL-encoded scope restored as coherent set; breadcrumb back-to-filtered-list; persistent scope/impersonation banner; filter + pagination + scroll restored together.
- **D-13:** Flow tests assert existing copy against ratified brand strings. System-wide voice glossary sweep = Phase 191.
- **D-14 (folded todos):** WR-01 target `[data-sg-confirm-cancel]` not positional `focusables[0]`; WR-02 `<body>` focus-return sentinel; WR-03 Escape `stopImmediatePropagation`. These touch shipped `admin_hooks.js` → byte-identical mirror obligation applies. WR-04: `branding_live` `error_message/1` maps `%Ecto.Changeset{}` to human copy.

### Claude's Discretion (planner resolves)

- Per-persona spec files (default) vs single `admin-flows.spec.ts`.
- Exact seed-enrichment gaps (most likely org-admin permission-denied and/or empty/no-data boundary).
- Whether to introduce `storageState`-per-persona Playwright projects (default: shared login helper, no new project infra).
- Exact L4 tier achieved per flow after evidence.
- Sequencing of folded ConfirmDialog/branding hardening relative to flow specs.
- Whether keyboard-frequent paths need reduced-motion CSS tightening (only if real violation surfaces → D-11 escalation).

### Deferred Ideas (OUT OF SCOPE)

- Distinct least-privilege "support investigator" RBAC role + break-glass impersonation hardening → future authz/security milestone.
- System-wide microcopy/voice glossary + one-term-per-concept sweep → Phase 191.
- Terminal idempotency gate + baseline recapture + generated-host parity → Phase 192.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FLOW-01 | Each persona JTBD journey (platform admin / support investigator / org admin) passes happy + main-error + boundary, with scope and return-context preserved across navigation | Verified: LiveViews, breadcrumb, scope-ribbon, impersonation banner all exist. Return-context assertions pattern found in `admin-theme.spec.ts:866-891` and `admin-user-operations.spec.ts:106-109`. |
| FLOW-02 | Each flow is fully keyboard-operable with visible focus and remains calm under `prefers-reduced-motion` | Verified: `sigra_admin.css:1467` reduced-motion guard exists. ConfirmDialog has focus-trap and Escape. WR-01/02/03 hardening needed for full APG conformance. |
| FLOW-03 | The Light/Dark/System choice persists across the whole flow and on reload (no server state) | Verified: `admin_shell.ex` inline script is the no-flash mechanism; `admin_hooks.js` IIFE-level `applyTheme` is secondary. `page.reload()` + `addInitScript` pattern missing from existing coverage. |
| DATA-01 | Deterministic seed/persona enrichment provides a fixture reproducing each flow's happy, error, and boundary case | Verified: Seeds cover happy (alice), error (dave locked), boundary (frank/grace scheduled-deletion, expired/pending invitations). CONFIRMED gaps below. |
</phase_requirements>

---

## Summary

Phase 190 is a pure test-authoring + ledger-ratification phase over existing shipped admin UI. Research focused on verifying every factual claim in CONTEXT.md against the live codebase, identifying what the demo seed already covers, and finding genuine gaps.

The codebase is in a clean state. All canonical references cited in CONTEXT.md (`admin-ui-principles.md:9-13`, `admin-fractal-scorecard.md:103-122`, `admin-quality-ledger.md`, `personas.ex`, `seeds.ex`, `impersonation.ex`, `admin_hooks.js`, `sigra_admin.css:1467`, `playwright.config.ts:88-145`) exist exactly as described and say what CONTEXT.md claims.

**Two genuine seed gaps confirmed:** (1) Morgan (`morgan@demo.vaultr.test`) has **zero audit events seeded**, which means the per-user audit view for morgan will render the `empty_state` component — making morgan the natural empty/no-data boundary case for the org-admin flow. (2) The org-admin **permission-denied case** (morgan hitting `/admin` global) is already mechanically present via the `:admin_global` pipeline plug returning a 403, and is already asserted in `admin-generated.spec.ts:179-185` — but that assertion uses a dynamically registered `org-admin+...` email, not the seeded `morgan` persona. The flow spec needs a login-as-morgan approach.

**One significant config gap found:** The proposed flow spec names (`admin-flow-*.spec.ts`) do NOT match the `ADMIN_BEHAVIOR_SPECS` regex in `playwright.config.ts`, which means the `mobile` project will pick them up and run them — contradicting D-09 ("Behavior runs on chromium; mobile/dark stay capture-only"). The planner must update `ADMIN_BEHAVIOR_SPECS` to include the new flow spec pattern.

**One CONTEXT.md inaccuracy to note:** The "applyTheme head script (`admin_hooks.js:83`)" cited in D-10 and the UI-SPEC is not actually a `<head>` script. The no-flash protection lives in an inline `<script>` block inside `admin_shell.ex:24-42` (also in the installer template at `priv/templates/sigra.install/admin/components/admin_shell.ex`). The `applyTheme(storedTheme())` call in `admin_hooks.js:83` is the IIFE-level re-application after the deferred bundle loads. The D-10 assertion should check the inline script in the admin shell component, not admin_hooks.js.

**Primary recommendation:** Proceed with three per-persona spec files, update `ADMIN_BEHAVIOR_SPECS` in `playwright.config.ts` to include `admin-flow`, use morgan's zero-audit-event state as the empty/no-data boundary, add a minimal morgan audit event seed as an optional enrichment so both "has data" (org-scoped happy path) and the "empty audit sub-feed for this user" boundary are testable deterministically.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Persona journey orchestration | Test layer (Playwright) | — | Flow specs drive browser through already-built LiveViews |
| Admin scope enforcement | API/Backend (`Sigra.Admin.Scope`, `Authorizer`, `:admin_global` plug) | Frontend Server (LiveView `on_mount`) | Plug pipeline fires before LiveView; `on_mount` handles live-navigation |
| Demo fixture data | Database/Storage (`Example.Demo.Seeds`) | — | Seeds populate the dev Postgres; no browser-driven setup |
| Theme no-flash | Frontend Server (inline `<script>` in `admin_shell.ex`) | Client (IIFE `admin_hooks.js:83`) | Inline fires synchronously before paint; IIFE re-applies after defer |
| Reduced-motion | CDN/Static (`sigra_admin.css:1467` `@media` block) | — | Pure CSS media query, no JS |
| Return-context / URL scope | Frontend Server (LiveView URL params, breadcrumb links) | — | `?q=`/`order_by` encoded in server-rendered links |
| Impersonation banner | Frontend Server (library-owned LiveView shell) | — | Banner rendered server-side; persistent across navigate |
| Keyboard/focus trap | Client (`admin_hooks.js` ConfirmDialog hook) | — | JavaScript hook; WR-01/02/03 hardening targets this |
| Ledger ratification | Documentation (`admin-quality-ledger.md`) | CI (monotonic guard script) | Human-authored rows; guard enforces monotonicity |

---

## Verification Results: CONTEXT.md Claims Against Live Tree

### Personas (D-01, admin-ui-principles.md:9-13)

**VERIFIED.** `guides/reference/admin-ui-principles.md` lines 9-13 read exactly:

```
- **Platform admin:** starts at `/admin`, checks what needs attention, finds users, investigates audit evidence, and pivots into org scope.
- **Support investigator:** starts from a user or event, keeps scope visible, and needs safe next actions with clear return paths.
- **Org admin:** operates inside one tenant boundary and needs member posture and org-scoped audit evidence without global noise.
```

[VERIFIED: live tree read]

### Fractal Scorecard L4 Add-ons (admin-fractal-scorecard.md lines 103-122)

**VERIFIED.** Lines 103-122 exist and contain exactly the 6 L4 Flow Add-ons cited:

1. Persona JTBD happy + main-error + boundary
2. Scope/return-context preserved
3. Full keyboard operability
4. Calm reduced-motion
5. Light/Dark/System persists across flow
6. Deterministic fixture reproduces flow

[VERIFIED: live tree read]

### Quality Ledger shape (admin-quality-ledger.md)

**VERIFIED.** The ledger currently has:
- L0: 1 row (`token-layer`)
- L1: 13 rows (`stat` through `audit_row`) — all Tier 1
- L2: 11 rows (`mg-1` through `mg-11`) — all Tier 1
- L3: 6 rows (`index-live` through `audit-user-live`) — all Tier 1

The `^\| [a-z]` parsing rule is confirmed by the script in `scripts/ci/quality-ledger-monotonic.sh`. All existing rows are lowercase-item with single-integer-tier. D-07's claim of "L1=13, L2=11, L3=6 rows" is **exactly correct**.

The 3 new L4 rows (`flow-platform-admin`, `flow-support-investigator`, `flow-org-admin`) do not yet exist — they are to be authored in this phase.

[VERIFIED: live tree read]

### Demo Fixture (personas.ex + seeds.ex)

**VERIFIED — with gap analysis:**

The 9 personas exist in `personas.ex` as claimed:

| Persona | Email | Key State | Has Audit Events |
|---------|-------|-----------|-----------------|
| admin | admin@demo.vaultr.test | TOTP+passkey+multi-org, platform admin | YES (18 rows) |
| alice | alice@demo.vaultr.test | Confirmed Acme member, standard | YES (3 rows: login + 2 impersonation) |
| bob | bob@demo.vaultr.test | TOTP, Beta Labs owner | YES (2 rows) |
| carol | carol@demo.vaultr.test | GitHub OAuth, Acme member | YES (3 rows) |
| dave | dave@demo.vaultr.test | Locked + unconfirmed, hashed_password=nil | YES (2 rows: auth.login.failure + auth.lockout.start) |
| frank | frank@demo.vaultr.test | scheduled_deletion=true | YES (1 row: account.deletion.schedule) |
| morgan | morgan@demo.vaultr.test | Non-platform org admin for Acme, :admin role | **ZERO audit events** |
| pat | pat@demo.vaultr.test | Passkey row, no MFA | YES (2 rows) |
| grace | grace@demo.vaultr.test | Acme member + scheduled_deletion=true | YES (1 row: api.token.create) |

**Seeds confirmed:**
- `@seed_reference_ts ~U[2026-05-15 12:00:00Z]` [VERIFIED]
- `MIX_ENV == :test` raise-guard in `priv/repo/seeds.exs` [VERIFIED]
- Idempotent upserts with `on_conflict: :nothing` [VERIFIED]
- `demo.vaultr.test` domain segregation [VERIFIED]
- Expired invitation (`expired-invite@demo.vaultr.test`, `expires_at: ~U[2026-01-01 00:00:00Z]`) [VERIFIED: FIXT-01]
- Pending invitation (`invited@demo.vaultr.test`, `expires_at: ~U[2099-06-30 00:00:00Z]`) [VERIFIED]
- `≥30 audit rows` claimed in CONTEXT.md: actual count is `@audit_actions` (18 entries) + `persona_audit_events()` (16 entries) = 34 total. [VERIFIED]

**Flow case coverage analysis:**

| Flow | Case | Persona | Status |
|------|------|---------|--------|
| Platform admin | Happy | alice (confirmed Acme member) | COVERED by seed |
| Platform admin | Main-error | dave (locked, audit.login.failure + auth.lockout.start) | COVERED by seed |
| Platform admin | Boundary | frank + grace (scheduled-deletion); empty audit filter | COVERED by seed |
| Support investigator | Happy | alice (impersonation start/stop audit events seeded) | COVERED by seed |
| Support investigator | Main-error | dave (locked user, existing audit trail) | COVERED by seed |
| Support investigator | Boundary | frank (scheduled-deletion); empty audit filter via search | COVERED by seed |
| Org admin | Happy | morgan at `/admin/organizations/acme-corp/users` (is :admin member of Acme) | COVERED by seed — morgan's membership exists |
| Org admin | Main-error (permission-denied) | morgan hitting `/admin` global → 403 | COVERED mechanically — but NEEDS FLOW-SPEC-LEVEL login as morgan |
| Org admin | Boundary (empty/no-data) | morgan's user-audit sub-feed → `empty_state` (zero audit events) | **CONFIRMED GAP — morgan has 0 audit events** |

**Confirmed seed gaps:**

1. **GENUINE GAP — morgan audit empty state:** Morgan has zero audit events. The per-user audit view (`/admin/users/:id/audit`) for morgan will render the `<.empty_state title="No audit events for this user">` component. This is a genuine, reproducible, deterministic boundary case. No seed enrichment is needed to create this state — it already exists by absence.

2. **NOT a gap — org-admin permission-denied:** Morgan hitting `/admin` global already returns 403 via the `:admin_global` pipeline plug + `ExampleWeb.AuthErrorHandler.auth_error/3`. This is mechanically present and asserted in `admin-generated.spec.ts:179-185` using a dynamic test user. The flow spec will drive this using the seeded morgan persona directly (log in as morgan → navigate to `/admin` → assert 403 body copy). No seed enrichment needed.

3. **POTENTIAL enrichment (planner discretion):** If the org-admin _happy_ path needs to show a non-empty users list in Acme, the existing seed provides alice, carol, dave, and grace as Acme members — this is already covered. Morgan's own user-detail audit page being empty is the _intended_ boundary.

[VERIFIED: live tree read of seeds.ex + personas.ex]

### Impersonation (lib/sigra/impersonation.ex + impersonation.spec.ts)

**VERIFIED.** `impersonation.spec.ts` lines 130-143 assert:
- Impersonation banner contains `Impersonating ${targetEmail}` and `Signed in as ${adminEmail}`
- Banner persists on org-scoped pages and on `/admin/organizations/:slug/users`
- Stop → returns to `/admin/users?.*q=` with admin header showing "Global"

The `admin.impersonation.start` and `admin.impersonation.stop` audit action strings are confirmed in the seed data (`@audit_actions` offsets 9 and 10).

[VERIFIED: live tree read]

### Theme hook (admin_hooks.js + admin_shell.ex)

**VERIFIED — with important correction for D-10:**

The no-flash theme protection is **NOT** in `admin_hooks.js:83` as a `<head>` script. The mechanism is split:

1. **No-flash (synchronous):** An inline `<script>` block at `admin_shell.ex:24-42` (also in the installer template at `priv/templates/sigra.install/admin/components/admin_shell.ex`). This fires synchronously when the admin shell renders — before paint. It reads `localStorage["sigra.admin.theme"]`, sets `data-sg-admin-js`, `data-sg-admin-theme-preference`, and conditionally `data-sg-admin-theme` on `<html>`.

2. **IIFE re-application (deferred):** `admin_hooks.js:83` calls `applyTheme(storedTheme())` as part of the IIFE that runs when the deferred `app.js` bundle loads. This re-syncs the theme with the stored value and initializes `window.SigraAdminHooks`.

**Impact on D-10 assertion:** The "assert the head script is present and NOT `async`/`defer`" should target the inline script in the rendered admin shell HTML, not a `<script src="...">` element in the `<head>`. The correct assertion is: find a synchronous `<script>` block in the page that contains `sigra.admin.theme` and does not have `async` or `defer` attributes.

The existing `admin-theme.spec.ts:364` already uses `addInitScript` to seed `localStorage` before `goto`, validating the no-flash pattern. The missing piece (noted in CONTEXT.md) is `page.reload()` + full-flow span assertions.

**localStorage key:** `"sigra.admin.theme"` [VERIFIED]
**Root attribute:** `data-sg-admin-theme` on `<html>` [VERIFIED]
**Shell attribute:** `data-theme` on `.sg-admin-shell` [VERIFIED]
**System mode:** removes both attributes [VERIFIED: admin_hooks.js lines 67-75]

Current coverage gap in `admin-theme.spec.ts:396-485` (as cited in CONTEXT.md):
- Cross-LiveView-nav persistence: **COVERED** (test navigates to `/admin/users` and checks `data-theme`)
- `page.reload()`: **NOT COVERED** — confirmed gap
- Full-flow span: **NOT COVERED** — confirmed gap
- System flip without reload: **NOT COVERED** — confirmed gap (the test only switches to System once)
- `addInitScript` before `goto` no-flash: **COVERED** at line 364

[VERIFIED: live tree read]

### Reduced-motion CSS guard (sigra_admin.css:1467)

**VERIFIED.** Lines 1467-1484:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-property: color, background-color, border-color, box-shadow, opacity, fill, stroke !important;
    transition-duration: var(--sg-motion-fast) !important;
  }
  .sg-admin-loading-bar::before {
    animation: none !important;
    transform: scaleX(1);
    transition: none !important;
  }
}
```

Note: The guard does NOT zero-out `transition-duration` — it sets `transition-duration: var(--sg-motion-fast)`. The spec should assert `var(--sg-motion-fast)` resolves to a very short value (or assert the animation is removed for specific elements like the loading bar), not unconditionally assert `0s`. The existing `admin-theme.spec.ts:851` uses `page.emulateMedia({ reducedMotion: "reduce" })` (per-page after goto — this is the Firefox footgun D-10 warns about). The new flow specs must set `reducedMotion: 'reduce'` at context/config level.

[VERIFIED: live tree read]

### Behavior lane + helpers (playwright.config.ts:88-145)

**VERIFIED — with critical gap:**

`playwright.config.ts:24-25`:
```typescript
const ADMIN_BEHAVIOR_SPECS =
  /(admin-user-operations|admin-audit|admin-theme|impersonation)\.spec\.ts/;
```

This regex gates which specs the `mobile` project ignores. The proposed flow spec names (`admin-flow-platform-admin.spec.ts`, `admin-flow-support-investigator.spec.ts`, `admin-flow-org-admin.spec.ts`) do **NOT** match this regex.

**CONFIRMED GAP:** New flow specs will run on the `mobile` project unless `ADMIN_BEHAVIOR_SPECS` is updated. The planner must add `admin-flow` to the regex, e.g.:

```typescript
const ADMIN_BEHAVIOR_SPECS =
  /(admin-user-operations|admin-audit|admin-theme|impersonation|admin-flow)\.spec\.ts/;
```

Note: `admin-coherence-sweep.spec.ts` also runs on mobile (it matches neither the mobile testIgnore list nor ADMIN_BEHAVIOR_SPECS). This appears to be an existing accepted state, not a regression. Flow specs are explicitly admin-behavior-truth specs (D-09) and MUST be excluded from mobile.

**Helpers directory** (`test/example/priv/playwright/helpers/`):

Existing helpers:
- `helpers/adminArtifacts.ts` — checkpoint screenshot capture (not relevant to flow specs)
- `helpers/adminUsersIndex.ts` — `adminUsersEmailLocator(page, email)` for desktop/mobile user row locating
- `helpers/fixtures.ts` — `TEST_PASSWORD = 'CorrectHorseBatteryStaple123!'`

`waitForLiveViewReady` is a **locally-defined async function** in each spec file (not in helpers/), defined identically across `impersonation.spec.ts:20-24`, `admin-theme.spec.ts:8-11`, `admin-user-operations.spec.ts:18-22`, `admin-coherence-sweep.spec.ts:34-38`. The proposed `helpers/adminFlows.ts` should extract this shared utility once and for all.

[VERIFIED: live tree read]

### ConfirmDialog focus/keyboard (WR-01/02/03)

**VERIFIED current state:**

Current `ConfirmDialog` in `admin_hooks.js` (identical in both template and example mirrors):

- **Focus on open:** `focusables[0].focus()` — positional, NOT `[data-sg-confirm-cancel]`. **WR-01 target.**
- **Cancel dispatch:** `focusables[0].click()` — same positional pattern as the focus, dispatches click on first focusable. This works IF cancel is always first, but a stable selector is safer.
- **Escape handler:** `document.addEventListener("keydown", this._onKeydown)` — no `stopImmediatePropagation`. **WR-03 target.**
- **Focus return on close:** `destroyed()` calls `this._trigger.focus()` — `this._trigger = document.activeElement` captured in `mounted()`. If the trigger element is removed from the DOM between open and close, `this._trigger.focus()` silently fails (no fallback to `<body>`). **WR-02 target.**
- **Tab trap:** Present and correct (`_trapFocus`).

**WR-04 — branding_live error_message:**

Current `branding_live.ex:710-719`:
```elixir
defp error_message(%{message: message}) when is_binary(message), do: message
defp error_message(%ArgumentError{} = error), do: Exception.message(error)
defp error_message(%{__struct__: _module} = exception) do
  Exception.message(exception)
rescue
  _ -> inspect(exception)
end
defp error_message(reason), do: "Could not save auth branding: #{inspect(reason)}"
```

The `%Ecto.Changeset{}` case: `Ecto.Changeset` implements `Exception.message/1` by returning `"changeset is invalid"` — not a user-facing string. The `rescue _ -> inspect(exception)` fallback would produce a raw `inspect/1` dump if `Exception.message/1` raises. WR-04 is to add an explicit `%Ecto.Changeset{}` clause that traverses errors into human copy.

[VERIFIED: live tree read]

### Three-surface byte-parity (D-06 / D-11 scope)

**VERIFIED.** Current state: `admin_hooks.js` template and example copies are **byte-identical** (confirmed by MD5 comparison). Any WR-01/02/03 changes to `admin_hooks.js` must propagate to both:
- `priv/templates/sigra.install/admin/admin_hooks.js` (canonical template)
- `test/example/assets/js/admin_hooks.js` (example mirror)

Seed data enrichment has **no parity obligation** (D-06). [VERIFIED: MD5 comparison + CONTEXT.md D-06]

### Brand microcopy strings (brandbook/brand-book.md:245-249)

**VERIFIED.** Lines 245-249 contain exactly the three ratified strings cited in UI-SPEC:
- Line 245: `"The reset link is expired. Request a new link to continue."`
- Line 247: `"No audit rows yet. Authentication events appear here after users sign in, change credentials, or trigger admin actions."`
- Line 249: `"Session revoked. The user will need to sign in again on that device."`

**Discrepancy found:** `user_show_live.ex:81` emits `put_flash(:info, "Session revoked.")` — NOT the full ratified string `"Session revoked. The user will need to sign in again on that device."`. The flow spec for the platform admin / investigator journey must assert against the **actual rendered string** (`"Session revoked."`) unless WR-04 or a separate fix aligns the flash copy to the brand-book string. The planner should note this mismatch.

[VERIFIED: live tree read]

---

## Standard Stack

No new packages are introduced. All work uses existing tooling.

| Tool | Version | Role |
|------|---------|------|
| `@playwright/test` | existing in project | Behavior spec authoring |
| `axe-core` / `@axe-core/playwright` | existing in project | Accessibility assertions |
| `otplib` | existing in project | TOTP (available but not needed for flow specs) |

### Package Legitimacy Audit

No new packages introduced. Not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
[Playwright flow specs]
        │
        │  log in as persona (loginDemoUser helper)
        ▼
[Example Phoenix app - dev server :4000]
        │
        ├── `:admin_global` plug pipeline
        │       └── RequireAdminAccess → Scope.resolve → {:error, :forbidden}
        │               └── AuthErrorHandler → 403 "Access denied..."  (morgan hitting /admin)
        │
        ├── AdminScope on_mount (live navigation)
        │       └── Scope.resolve → {:ok, admin_scope} → proceed
        │               or → {:error, :not_found} → sigra_not_found
        │
        ├── Library LiveViews (lib/sigra/admin/live/)
        │       ├── IndexLive → global overview
        │       ├── UsersIndexLive → user list with ?q= / order_by scope
        │       ├── UserShowLive → user detail + impersonation + ConfirmDialog
        │       ├── AuditIndexLive → global audit explorer
        │       └── AuditUserLive → per-user audit (empty_state for morgan)
        │
        ├── admin_shell.ex inline <script> → no-flash theme on first render
        │       └── admin_hooks.js (deferred IIFE) → ThemeSwitch, ConfirmDialog, CmdK
        │
        └── sigra_admin.css → reduced-motion guard (@media prefers-reduced-motion)

[Quality Ledger]  admin-quality-ledger.md
        └── 3 new L4 rows appended after evidence
        └── quality-ledger-monotonic.sh (CI guard, merge-blocking)
```

### Recommended Project Structure (additions only)

```
test/example/priv/playwright/
├── helpers/
│   ├── adminArtifacts.ts       # existing
│   ├── adminUsersIndex.ts      # existing
│   ├── fixtures.ts             # existing (TEST_PASSWORD)
│   └── adminFlows.ts           # NEW — shared flow helpers
│           waitForLiveViewReady, loginDemoUser, loginDemoAdmin,
│           assertScopeRibbon, assertBreadcrumb, assertThemeAttributes,
│           assertFocusReturnsToTrigger, assertReducedMotionEffect
└── tests/
    ├── admin-flow-platform-admin.spec.ts     # NEW
    ├── admin-flow-support-investigator.spec.ts # NEW
    └── admin-flow-org-admin.spec.ts          # NEW
```

### Pattern 1: waitForLiveViewReady (extract to helpers/adminFlows.ts)

Currently copy-pasted in every spec file. Canonical form (from `impersonation.spec.ts:20-24`):

```typescript
// Source: test/example/priv/playwright/tests/impersonation.spec.ts:20
export async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}
```

### Pattern 2: loginDemoUser (from demo-showcase.spec.ts:183-193)

```typescript
// Source: test/example/priv/playwright/tests/demo-showcase.spec.ts:183
export async function loginDemoUser(page: Page, email: string, password: string) {
  await page.goto("/users/log_in");
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');
  await expect(page).not.toHaveURL(/\/users\/log_in/);
}
```

Note: `admin@demo.vaultr.test` has TOTP enrolled but the example app's `sigra_config()` does not set `mfa.check_fn`, so login creates a `:standard` session directly without MFA challenge. No TOTP step needed.

### Pattern 3: Theme no-flash assertion via addInitScript

```typescript
// Source: test/example/priv/playwright/tests/admin-theme.spec.ts:364
await page.addInitScript(() => {
  window.localStorage.setItem("sigra.admin.theme", "dark");
});
await page.goto("/admin");
await expect(page.locator("html")).toHaveAttribute("data-sg-admin-theme", "dark");
// assert the inline script is synchronous (no async/defer attribute)
const scriptContent = await page.locator('script').filter({
  hasText: 'sigra.admin.theme'
}).first().evaluate(el => ({
  async: (el as HTMLScriptElement).async,
  defer: (el as HTMLScriptElement).defer,
}));
expect(scriptContent.async).toBe(false);
expect(scriptContent.defer).toBe(false);
```

### Pattern 4: Keyboard focus assertions (from APG Dialog spec context)

```typescript
// Assert focus is inside the dialog (containment invariant)
const dialog = page.locator('.sg-confirm-dialog');
const focused = page.locator(':focus');
await expect(dialog).toContainElement(focused);

// Assert focus returns to trigger after dialog close
const triggerButton = page.locator('[data-testid="revoke-session-trigger"]');
await triggerButton.focus();
await page.keyboard.press('Enter'); // open dialog
// ... dialog appears ...
await page.keyboard.press('Escape'); // close dialog  
await expect(triggerButton).toBeFocused(); // focus returned
```

### Pattern 5: Reduced-motion at context level

```typescript
// Source: D-10, playwright#31328 — must be at context/config level, not per-page after goto
// In playwright.config.ts project definition or test.use():
use: { reducedMotion: 'reduce' }

// Assert collapsed CSS effect (not just matchMedia)
// The reduced-motion guard sets transition-duration: var(--sg-motion-fast) for most elements
// and animation: none for .sg-admin-loading-bar::before
const loadingBar = page.locator('.sg-admin-loading-bar');
const animName = await loadingBar.evaluate(el =>
  window.getComputedStyle(el, '::before').animationName
);
expect(animName).toBe('none');
```

### Pattern 6: Org-admin permission-denied assertion

```typescript
// morgan@demo.vaultr.test is org-admin for Acme, not platform admin
// Hitting /admin triggers :admin_global plug → 403
await loginDemoUser(page, 'morgan@demo.vaultr.test', 'MorganDemo1!OrgAdmin');
const response = await page.goto('/admin');
expect(response?.status()).toBe(403);
await expect(page.locator('body')).toContainText('Access denied. You do not have access to this admin scope.');
```

### Anti-Patterns to Avoid

- **Positional focusable queries:** Use `[data-sg-confirm-cancel]` (WR-01 target), not `dialog.querySelectorAll(FOCUSABLE)[0]`. The planner must add the `data-sg-confirm-cancel` attribute to the Cancel button in both LiveViews that render `sg-confirm-overlay`.
- **sleep() in specs:** Never. Use `waitForLiveViewReady`, `expect(...).toBeVisible()`, and `expect(...).toBeFocused()` with Playwright's built-in auto-retry.
- **Computed color assertions:** At most one `toHaveCSS` smoke check. Use attribute + localStorage assertions for theme.
- **`page.emulateMedia` after `goto`:** Firefox drops it. Set `reducedMotion: 'reduce'` at context/config level.
- **Testing impersonation internals in flow spec:** The flow spec asserts journey-level continuity only. Impersonation mechanics (stale-sudo redirect, etc.) are owned by `impersonation.spec.ts`.
- **Timer-dependent seed data:** All timestamps relative to `@seed_reference_ts ~U[2026-05-15 12:00:00Z]`, never `DateTime.utc_now()`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| LiveView readiness gate | Custom polling loop | `waitForSelector('[data-phx-session].phx-connected', {state: 'attached'})` | Established pattern already in every spec |
| Admin scope enforcement | Custom permission check | `:admin_global` plug + `Sigra.Admin.Scope.resolve/3` | Already ships in library |
| User-row locating | Custom query | `adminUsersEmailLocator(page, email)` from `helpers/adminUsersIndex.ts` | Handles desktop/mobile layout switching |
| Focus trap | Custom Tab-counting logic | Assert containment invariant (`dialog contains :focus`) | Tab count is fragile; containment invariant is robust |
| Theme flash prevention | Custom `<head>` script | Inline script in `admin_shell.ex:24-42` | Already exists; assert it, don't rebuild it |

---

## Common Pitfalls

### Pitfall 1: Flow specs run on mobile project
**What goes wrong:** Tests fail on mobile viewport because admin UI is not designed for it, or mobile silently "passes" with wrong behavior.
**Why it happens:** `admin-flow-*.spec.ts` names don't match `ADMIN_BEHAVIOR_SPECS` regex, so the `mobile` project doesn't exclude them.
**How to avoid:** Update `playwright.config.ts` `ADMIN_BEHAVIOR_SPECS` to include `admin-flow` before authoring specs.
**Warning signs:** CI shows flow spec results in both `chromium` and `mobile` columns.

### Pitfall 2: TOTP challenge surprises admin login
**What goes wrong:** Flow spec hangs at MFA step when logging in as `admin@demo.vaultr.test`.
**Why it happens:** `admin` has TOTP enrolled — but the example app's `sigra_config()` has no `mfa.check_fn`, so login creates a `:standard` session without MFA challenge.
**How to avoid:** Login pattern is identical for all 9 demo personas. No special TOTP handling needed. Document this assumption in `helpers/adminFlows.ts`.
**Warning signs:** Spec stuck waiting for a page that never leaves `/users/log_in`.

### Pitfall 3: Asserting `"Session revoked. The user will need to sign in again on that device."` fails
**What goes wrong:** Test fails because the actual flash is `"Session revoked."` (short form in `user_show_live.ex:81`).
**Why it happens:** `brand-book.md:249` has the full string but the LiveView emits only the short form.
**How to avoid:** Assert against `"Session revoked."` (actual) until the copy is aligned. Route the copy gap to Phase 191 or fix it as part of WR-04 scope.
**Warning signs:** `toHaveText('Session revoked. The user will need to sign in again on that device.')` fails.

### Pitfall 4: `reducedMotion` emulation dropped by Firefox
**What goes wrong:** Reduced-motion assertions pass in CI but the CSS effect isn't actually collapsed.
**Why it happens:** `page.emulateMedia({ reducedMotion: 'reduce' })` called after `goto` is dropped by Firefox (playwright#31328).
**How to avoid:** Set `reducedMotion: 'reduce'` at the Playwright project/context level, or in `test.use()` inside the describe block, before any `goto`.
**Warning signs:** Assertion on `animation-duration` returns non-`0.01ms` value.

### Pitfall 5: Ledger tier integer formatting
**What goes wrong:** Monotonic guard script fails to parse new rows.
**Why it happens:** Tier column contains `"1"` with surrounding whitespace but the awk parser expects a bare integer after stripping whitespace — works correctly. The failure mode is writing `Tier 1` or `1 (ratified)` instead of `1`.
**How to avoid:** Write tier as a bare integer: `| flow-platform-admin | L4 | 1 | [link] |`.
**Warning signs:** `quality-ledger-monotonic.sh` exits with "parse error" on the new rows.

### Pitfall 6: Calling `_cancel()` with no `[data-sg-confirm-cancel]` attribute
**What goes wrong:** After WR-01 lands, the Cancel button needs the `data-sg-confirm-cancel` attribute in the HEEx template. If the attribute isn't added to both `user_show_live.ex` and `branding_live.ex`, the hardened `_cancel()` function finds nothing.
**Why it happens:** WR-01 changes `_cancel()` to query `[data-sg-confirm-cancel]` instead of `focusables[0]`, but only the JS is updated — the template is forgotten.
**How to avoid:** WR-01 task must cover BOTH the `admin_hooks.js` change AND the HEEx template attribute additions in `user_show_live.ex` and `branding_live.ex`.

---

## Runtime State Inventory

Not applicable. Phase 190 introduces no renames, refactors, or migrations — it authors new Playwright spec files and appends ledger rows.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Playwright CLI | ✓ | (via existing playwright setup) | — |
| Playwright | Flow spec execution | ✓ | existing in `test/example/priv/playwright/node_modules` | — |
| PostgreSQL (dev DB) | `mix run priv/repo/seeds.exs` | ✓ (per CLAUDE.md, port 5432 with postgres/postgres) | 16-alpine (dev) | — |
| Live dev server | Playwright `baseURL: http://localhost:4000` | started via `mix phx.server` | — | — |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `@playwright/test` (existing in `test/example/priv/playwright/`) |
| Config file | `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `cd test/example/priv/playwright && npx playwright test --project=chromium admin-flow` |
| Full suite command | `cd test/example/priv/playwright && npx playwright test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FLOW-01 | Platform admin journey: overview → users → user detail → audit → return with scope/breadcrumb preserved | Playwright (chromium) | `npx playwright test admin-flow-platform-admin --project=chromium` | ❌ Wave 0 |
| FLOW-01 | Support investigator journey: find account → impersonation → return context | Playwright (chromium) | `npx playwright test admin-flow-support-investigator --project=chromium` | ❌ Wave 0 |
| FLOW-01 | Org admin journey: morgan logged in → acme scope → member list → user detail → empty audit | Playwright (chromium) | `npx playwright test admin-flow-org-admin --project=chromium` | ❌ Wave 0 |
| FLOW-02 | ConfirmDialog keyboard: focus on cancel, Escape returns focus, Tab trap, no keyboard trap | Playwright (chromium) | included in flow specs above | ❌ Wave 0 |
| FLOW-02 | Reduced-motion: CSS effect collapsed (`animation: none` on loading bar) | Playwright (chromium) | included in flow specs above | ❌ Wave 0 |
| FLOW-03 | Theme: attribute + localStorage set; persists after `page.reload()`; no-flash via `addInitScript` | Playwright (chromium) | included in flow specs above | ❌ Wave 0 |
| DATA-01 | Seed reproducibility: `mix run priv/repo/seeds.exs` idempotently produces all required personas | ExUnit smoke / seed smoke | `mix run priv/repo/seeds.exs` (idempotent) | ✓ existing (seeds.ex) |

### Sampling Rate

- **Per task commit:** `npx playwright test admin-flow --project=chromium -x`
- **Per wave merge:** `npx playwright test --project=chromium` (full behavior lane)
- **Phase gate:** Full suite (`npx playwright test`) + `mix test` green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/example/priv/playwright/helpers/adminFlows.ts` — shared login/readiness/theme/keyboard helpers
- [ ] `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts`
- [ ] `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts`
- [ ] `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts`
- [ ] `playwright.config.ts` update — add `admin-flow` to `ADMIN_BEHAVIOR_SPECS` regex
- [ ] `guides/reference/admin-quality-ledger.md` — 3 new L4 rows

---

## Security Domain

Phase 190 is a test-authoring phase. The security-relevant behaviors being _asserted_ (not introduced) are:

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V4 Access Control | yes (org-admin permission-denied test) | `Sigra.Admin.Authorizer`, `:admin_global` plug, `AuthErrorHandler` |
| V3 Session Management | yes (theme persistence is client-only, not server state; tested to confirm no server leak) | localStorage key, no cookie involvement |
| V5 Input Validation | no | — |

The **anti-enumeration** brand-voice rule (D-13) is asserted: the 403 body is a generic `"Access denied..."` string — it does not confirm or deny org existence to the org-admin persona.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `waitForLiveViewReady` defined in each spec | Extract to `helpers/adminFlows.ts` | Phase 190 | Reduces copy-paste; one canonical definition |
| `page.emulateMedia` after `goto` (per-spec) | `reducedMotion: 'reduce'` at context/config level | Phase 190 (per D-10) | Reliable cross-browser media query emulation |
| Impersonation banner tested incidentally | Explicit journey-level banner continuity assertion | Phase 190 | Canonical flow-level evidence for ledger |

**Deprecated/outdated:**
- `focusables[0]` in `_cancel()` / `mounted()`: replaced by `[data-sg-confirm-cancel]` (WR-01)
- `document.addEventListener("keydown"...)` without `stopImmediatePropagation` on Escape: replaced by WR-03

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `admin@demo.vaultr.test` login does not trigger TOTP challenge because `sigra_config()` lacks `mfa.check_fn` | Verification Results: Demo Fixture | If mfa.check_fn is added before Phase 190, all admin-logged-in flow specs will hang at MFA step |
| A2 | The 403 response for morgan hitting `/admin` is rendered as a plain HTTP response body (not a LiveView redirect) | Architecture Patterns | If the auth error handler was changed to redirect instead of render, the `response.status()` assertion won't work |

---

## Open Questions (RESOLVED)

1. **Session revoke copy mismatch**
   - What we know: `brand-book.md:249` has `"Session revoked. The user will need to sign in again on that device."` but `user_show_live.ex:81` emits `"Session revoked."` (short form).
   - What's unclear: Is the short form intentional (the brand-book string is aspirational), or is this an unintentional copy gap?
   - Recommendation: Assert against `"Session revoked."` in Phase 190 flow spec. If aligning the copy is in scope, do it under WR-04 / Phase 191. Do not block the flow spec on resolving this.

2. **Morgan empty audit boundary — flow assertion target**
   - What we know: Morgan has zero audit events. The per-user audit view will render `<.empty_state title="No audit events for this user">`.
   - What's unclear: Should the flow spec navigate to morgan's user-detail audit page as the org-admin flow boundary case? Morgan can only see morgan's own org users as org-admin; can morgan navigate to their own user detail via `/admin/organizations/acme-corp/users`?
   - Recommendation: Planner verifies that an org-admin can navigate to their own user-detail page within scope. If not, the boundary case is instead "filter that returns no users" or "audit feed empty state via date-range filter."

---

## Sources

### Primary (HIGH confidence)

- Live tree reads: `guides/reference/admin-ui-principles.md`, `admin-fractal-scorecard.md`, `admin-quality-ledger.md`, `test/example/lib/example/demo/personas.ex`, `test/example/lib/example/demo/seeds.ex`, `test/example/assets/js/admin_hooks.js`, `priv/templates/sigra.install/admin/admin_hooks.js`, `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/playwright/playwright.config.ts`, `test/example/priv/playwright/tests/impersonation.spec.ts`, `test/example/priv/playwright/tests/admin-theme.spec.ts`, `test/example/lib/example_web/components/admin_shell.ex`, `lib/sigra/admin/authorizer.ex`, `lib/sigra/live_view/admin_scope.ex`, `brandbook/brand-book.md` [VERIFIED: live tree read]

- MD5 byte-identity check: `admin_hooks.js` template == example mirror [VERIFIED]

### Secondary (MEDIUM confidence)

- playwright#31328 (Firefox emulateMedia after goto): cited from CONTEXT.md D-10, not independently web-searched. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; existing tooling verified
- Architecture: HIGH — all canonical files verified against live tree
- Seed gap analysis: HIGH — personas.ex + seeds.ex fully read, all audit event subjects enumerated
- Pitfalls: HIGH — ADMIN_BEHAVIOR_SPECS gap confirmed by live regex test, copy mismatch confirmed by reading both source files
- ConfirmDialog WR-01/02/03 analysis: HIGH — admin_hooks.js read in full

**Research date:** 2026-06-17
**Valid until:** 2026-07-17 (30 days; stable codebase)
