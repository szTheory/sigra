---
id: SEED-010
status: open
planted: 2026-07-18
planted_during: "quick task 260718-t7o — MFA settings page brand polish (Jon flagged the purple button)"
trigger_when: A dedicated auth-surface brand pass, or an adopter-onboarding / generated-code-quality milestone, or an adopter asking why generated auth pages look unstyled.
scope: Large
---

# SEED-010: Auth pages still on daisyUI defaults (demo + shipped templates)

## Problem

The MFA-page purple button (fixed in 260718-t7o by changing the demo core `<.button>` default to
`vt-btn vt-btn--primary`) was the tip of a systemic un-branding issue. Two distinct layers remain:

### 1. Demo auth pages still fully daisyUI (`test/example/lib/example_web/`)
These pages still hard-code `class="btn btn-primary"` (daisyUI purple, NOT `vt-*`) — the core-default
fix does NOT touch them because they pass an explicit class:
- `live/registration_live.ex:87`
- `live/confirmation_live.ex:52, 87`
- `live/reset_password_live.ex:37, 70, 131`
- `live/invitation_accept_live.ex:289, 314, 371, 383, 395, 407`

Bringing these to the Tasklane `vt-*` standard = swap each `btn btn-primary` (and any `btn-error`/
`btn-ghost`/`btn-soft`) to the `vt-btn vt-btn--primary`/`--ghost`/`--danger` equivalent, plus
matching panel/section/empty-state structure (see `settings_live.ex` / `mfa_settings_live.ex` as the
branded reference). Reuse the new `.vt-empty-state` pattern for any empty states.

### 2. Installer templates + golden are 100% daisyUI (`priv/templates/sigra.install/**`, `test/fixtures/install_golden/**`)
Every generated auth page an adopter receives (`core/mfa_settings_live.ex`, `core/mfa_settings_html.ex`,
`core/session_live.ex`/`login_html.ex`, `core/settings_live.ex`, `core/confirmation_*`,
`core/reset_password_*`, `core/registration_*`, `core/sudo_html.ex`, all `organizations/**`, plus
`core/sigra_auth.css` which targets `.btn-primary`/`.btn-outline`) is daisyUI/default — never `vt-*`.

**This needs a PRODUCT DECISION before any conversion, not just a mechanical re-skin:**
- `vt-*` is *Tasklane's demo brand* — adopters don't have it. Converting the shipped templates to
  `vt-*` would impose Tasklane branding on every adopter (wrong).
- The real question: should Sigra ship (a) generic daisyUI/Tailwind auth pages the adopter restyles
  (current), (b) an unstyled/semantic baseline, or (c) a polished-but-neutral design token layer the
  adopter can theme? Decide the philosophy first.
- If any template markup changes, the **golden fixture must be regenerated** (`test/fixtures/install_golden/`,
  via `mix sigra.fixture.rebless_golden`) or the install-golden test breaks. [[reference_installer_template_drift]]

### 3. One stray in lib
- `lib/sigra/admin/components.ex:1052` — `class="btn btn-primary w-full"` ("Send magic link"), the only
  daisyUI class literal in `lib/` source.

## Why deferred

Fixing the whole auth surface is a large, multi-file effort; the installer-template layer additionally
needs a product decision (above) rather than a mechanical change. Jon's 260718-t7o ask was the Tasklane
demo MFA page specifically — done. Related: [[project_next_milestone_admin_ui]],
[[reference_installer_template_drift]], [[project_admin_ui_design_system]].
