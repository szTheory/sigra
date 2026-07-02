---
phase: 203-consistency-propagation
reviewed: 2026-06-26T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/sigra/admin/components.ex
  - lib/sigra/admin/live/branding_live.ex
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - test/example/priv/playwright/tests/admin-modal-interaction.spec.ts
  - test/sigra/admin/glossary_test.exs
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 203: Code Review Report

**Reviewed:** 2026-06-26
**Depth:** standard
**Files Reviewed:** 6 source files (3 docs in scope reviewed as context, not flagged)
**Status:** issues_found

## Summary

Phase 203 promotes three previously-private branding preview components
(`color_field/1`, `preview_pair/1`, `detail_input/1`) from `branding_live.ex`
into `Sigra.Admin.Components`, reduces the status-pill vocabulary on two Overview
LiveViews, adds a branding `ConfirmDialog` Playwright a11y test, and extends the
glossary carve-out to `components.ex`.

The core refactor is high quality and low-risk:

- The promoted components are **byte-equivalent** to their private originals
  (the only delta is the alias rewrite `Branding.css_variables` →
  `Sigra.Branding.css_variables`, which is correct because `components.ex` does
  not `alias Sigra.Branding`).
- `mix compile --warnings-as-errors` is clean — no orphaned private functions
  were left behind after deletion. The removed `percent_of/2`, `mfa_users`,
  `passkey_users` in `index_live.ex` have no remaining references; `total_users`
  and `@summary_posture` are still consumed.
- `glossary_test.exs` and `components_test.exs` both pass (2/2 and 35/35).
- The "Confirmed" pill removal on `organization_live.ex` is backed by the
  documented D-02/D-03 reduced-pill vocabulary (admin-ui-principles.md:33); the
  always-present role pill keeps the cluster non-empty, so there is no
  empty-cluster visual regression.

No BLOCKER-level correctness or security defects were found. The findings below
are quality/robustness issues — the most substantive is that the glossary
carve-out claims to exempt "the auth-replica block" but in fact only strips the
**login** replica, leaving the **email** replica scanned (currently clean by
luck, a latent drift trap).

## Warnings

### WR-01: Glossary carve-out only strips the login replica, not the email replica — latent drift trap

**File:** `test/sigra/admin/glossary_test.exs:129-161` (state machine) applied to `lib/sigra/admin/components.ex:1028-1080`
**Issue:**
The carve-out's stated purpose (glossary_test.exs:108-127) is to exempt the
"auth-replica block" that "mirrors host-generated auth copy which may
intentionally say 'Log in'." The state machine anchors on the marker
`sigra-auth sigra-auth--preview` and tracks `<div>` nesting until depth returns
to 0.

I traced the state machine over the real `preview_pair/1` markup: it ENTERS at
components.ex:1032 and EXITS at components.ex:1057 — i.e. it strips **only the
login-preview `<div>`** (which contains `<h1>Log in</h1>` at line 1048). The
sibling **email-preview block** at components.ex:1060-1080 — which is equally a
host-auth replica (`<strong>{@profile.product_name}</strong>`, "Confirm your
email address…", "Confirm email") — is KEPT and scanned by the banned-term
filter.

Today this passes only because the email replica happens to contain no banned
synonyms. But the carve-out's comment asserts the whole replica is exempt, so a
future edit that legitimately mirrors host email copy containing, e.g.,
"login" / "log in" / "org" inside the email preview would trip a **false-positive
glossary failure** that a maintainer would (correctly, per the comment) believe
should be exempt. The exemption is narrower than documented.

**Fix:** Either (a) make the marker/exemption cover both replica surfaces, e.g.
also anchor on `sigra-auth-email-preview` and strip through its closing `</div>`,
or (b) correct the carve-out comment to state explicitly that **only the login
replica is exempt and the email replica is intentionally scanned**, so the
narrowness is a deliberate, documented contract rather than an accident:

```elixir
# Carve-out scope (NARROW, intentional): only the `sigra-auth sigra-auth--preview`
# login replica is exempt. The sibling `sigra-auth-email-preview` block is NOT
# exempt and IS scanned — keep host-mirrored email copy glossary-clean, or widen
# this marker if that copy must legitimately diverge.
```

### WR-02: Branding modal Playwright test can hang instead of failing cleanly when no admin profile exists

**File:** `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts:213-229`
**Issue:**
The "Restore config defaults" button renders only when `admin_profile?/1` is true
(branding_live.ex:337). The test probes `triggerLocator.isVisible()`, and if
absent, clicks "Save profile" once to create an admin profile, then asserts
`expect(triggerLocator).toBeVisible()`.

If the one-shot save fails validation (`handle_event("save", …)` returns
`{:error, …}` — e.g. a default profile with an empty required field such as
`email_from_address` or `logo_alt`), no admin profile is persisted, the trigger
never appears, and the test blocks on `toBeVisible()` until the Playwright
timeout rather than surfacing the real cause. The save path is fire-and-forget:
the test does not assert the save succeeded (no flash assertion, no
`expect(...).not.toHaveText('error')`), so a regression in the default-profile
validity would manifest as an opaque timeout.

**Fix:** Assert the save outcome before depending on it — e.g. after clicking
Save, assert the success flash ("Auth branding profile saved.") or assert the
error notice is **absent** — so a failed seed fails the test with a meaningful
message instead of a generic visibility timeout:

```ts
await saveButton.click();
await waitForLiveViewReady(page);
// Seed must succeed for the Restore button to render; fail loudly if it didn't.
await expect(page.locator('[data-tone="risk"][role="alert"]')).toHaveCount(0);
```

### WR-03: Duplicated id-derivation logic across `detail_input/1` (promoted) and `detail_select/1` (still private)

**File:** `lib/sigra/admin/components.ex:1091-1095` and `lib/sigra/admin/live/branding_live.ex:493-551`
**Issue:**
`detail_input/1` was promoted to `components.ex` along with its id helpers
`branding_field_id/1` / `branding_help_id/1`
(`"branding-" <> String.replace(name, "_", "-")` and `<> "-help"`). The sibling
`detail_select/1` was **not** promoted and remains private in `branding_live.ex`,
carrying byte-identical helpers `detail_field_id/1` / `detail_help_id/1`. The
same id-derivation contract now lives in two modules under two names.

This is a "same job → same component" partial-promotion seam: the two helpers
must stay in lockstep (both produce the `branding-<name>` / `-help` convention so
`<label for>` matches the input id), but nothing enforces that. If one is changed
(e.g. the slug convention is revised), the Light/Dark color inputs and the
Details text inputs would silently diverge from the Theme-mode select's
label/`for` wiring.

**Fix:** Either promote `detail_select/1` into `components.ex` so it reuses the
shared `branding_field_id/1` / `branding_help_id/1` helpers (preferred, completes
the same-job→same-component invariant the phase is propagating), or, if
`detail_select` is intentionally kept per-page, have its private helpers delegate
to the shared component helpers rather than re-implementing the string transform.

## Info

### IN-01: Stale section comment in `components.ex` private-helper block

**File:** `lib/sigra/admin/components.ex:1086`
**Issue:** The section header reads
`# Private helpers for audit_row/1, audit_table_row/1, audit_pagination_nav/1`,
but the newly added `branding_field_id/1` and `branding_help_id/1` (which serve
`detail_input/1`, not the audit components) were inserted directly beneath it.
The comment no longer accurately describes the helpers it heads.
**Fix:** Update the header to include the branding helpers, or move the two
branding helpers under their own subheading
(`# Private helpers for detail_input/1`).

### IN-02: `preview_pair/1` renders a literal `style=` attribute from `Sigra.Branding.css_variables/1`

**File:** `lib/sigra/admin/components.ex:1036` and `:1068`
**Issue:** Both preview surfaces interpolate
`style={Sigra.Branding.css_variables(@profile)}` directly into an inline style
attribute. This is unchanged from the pre-promotion original (no regression), and
the values are admin-authored CSS custom properties rather than untrusted user
input, so it is not a stored-XSS vector in the current threat model. Flagging only
for visibility: if `css_variables/1` ever begins reflecting unsanitized
free-text profile fields (e.g. a future `custom_css` field) into this attribute,
it would become an injection sink. The function's output contract should remain
"CSS-var declarations only, no caller free-text."
**Fix:** None required now. Keep `Sigra.Branding.css_variables/1` constrained to
emitting `--sg-*: <validated-color>;` pairs; add a regression test if a free-text
branding field is ever routed through it.

### IN-03: `index_live.ex` alarm copy lacks singular/plural handling that `organization_live.ex` has

**File:** `lib/sigra/admin/live/index_live.ex:49`
**Issue:** `index_live.ex` renders `{@needs_review} users need review` with no
singular branch, whereas `organization_live.ex:67` correctly renders
`{@needs_review} {if @needs_review == 1, do: "member needs", else: "members need"}`.
This produces "1 users need review" on the Global Overview. **This is
pre-existing** (the line is untouched by the Phase 203 diff) and therefore out of
strict scope, but the phase's stated goal is consistency propagation across these
two Overview LiveViews, so it is worth capturing as an inconsistency the phase
did not close.
**Fix:** Mirror the org pluralization on the global alarm:
`{@needs_review} {if @needs_review == 1, do: "user needs", else: "users need"} review`.

### IN-04: `format_date/1` divergence between `organization_live.ex` and the shared `components.ex` helper

**File:** `lib/sigra/admin/live/organization_live.ex:158-161` vs `lib/sigra/admin/components.ex:1124-1131`
**Issue:** `organization_live.ex` keeps a private `format_date/1` whose catch-all
clause returns `"—"` for unexpected types (line 161), while the shared
`components.ex` `format_date/1` deliberately **raises** `ArgumentError` on
unexpected types (the D-09 T-158-01 mitigation, components.ex:1128-1131) to avoid
silently rendering a wrong-typed value. Two `format_date/1` implementations with
opposite failure semantics now coexist. Not introduced by this diff and not a
bug for the org page (its inputs are `expires_at` DateTimes), but it is exactly
the kind of "same job, two components" divergence the consistency-propagation
phase targets.
**Fix:** Consider routing `organization_live.ex`'s pending-invitation date
formatting through the shared `components.ex` date helper (or align the
fail-mode) so the admin surface has one date-formatting contract.

---

_Reviewed: 2026-06-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
