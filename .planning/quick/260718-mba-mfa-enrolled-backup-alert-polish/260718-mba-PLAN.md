---
quick_id: 260718-mba
title: "Polish the MFA enrolled-state backup-code alert (drop dead icon + add rhythm)"
status: ready
---

# MFA enrolled backup-code alert — brand polish. Example-only (test/example/).

ALL example-only. NO priv/templates/, NO test/fixtures/, NO *.png. (The installer MFA template is
daisyUI by design — deferred under SEED-010; do NOT touch it.) Continues t7o (which did the
UNENROLLED state + passkey empty-state); this is the ENROLLED state.

Two off-brand problems on `/users/settings/mfa` (enrolled state, in `mfa_settings_live.ex`):
1. The `vt-alert vt-alert--danger` "All backup codes used. Generate new ones now." (and its
   `--warning` sibling) each start with `<.icon name="hero-exclamation-triangle" class="h-4 w-4" />`.
   `hero-exclamation-triangle` has NO backing CSS in this build-free example (default.css defines
   only 10 hero classes, not this one) — so it renders as an empty ~1rem box that pushes the text
   right, reading as awkwardly offset/centered. EVERY other `vt-alert` in the demo is icon-free.
2. No vertical rhythm inside the enrolled panel below the alert: the alert butts against
   "Regenerate codes", and the backup block butts against "Revoke all trusted browsers".
   (`.vt-panel__header` already spaces itself via `margin-bottom: var(--sg-space-4)`, but the panel
   itself has no gap, so its non-header children stack tight.)

Verified: no test asserts these strings (grep clean); no PNG baseline captures this page. Keep the
"Disable" `vt-btn--danger` button and all copy verbatim ("All backup codes used. Generate new ones
now.", "{N} of 8 backup codes remaining", "Regenerate codes", "Revoke all trusted browsers").

## Task 1 — drop the dead icons + add a stack utility (`mfa_settings_live.ex`)
`test/example/lib/example_web/live/mfa_settings_live.ex`:
(a) Remove the `<.icon name="hero-exclamation-triangle" class="h-4 w-4" />` line from BOTH alerts —
    the `--danger` one (~L96) and the `--warning` one (~L101). Leave the alert `<div>` + its text
    exactly as-is otherwise. (This alone fixes the offset-text look — `.vt-alert` is `display:flex;
    align-items:flex-start`, and with only the text node it lays out clean and left-aligned.)
(b) Give the enrolled panel and the backup-status block a stack class for even rhythm:
    - The enrolled panel (~L77): `class="vt-panel"` → `class="vt-panel vt-stack"`.
    - The backup-status inner `<div>` (~L92, the one wrapping the `cond` alert + the "Regenerate
      codes" `<p>`): `<div>` → `<div class="vt-stack">`.
    Do NOT add it to the trust `<div>` (single child) — it becomes a panel grid child and is spaced
    by the panel's own gap.

## Task 2 — the `.vt-stack` utility (`app.css`)
`test/example/priv/static/assets/css/app.css` (add near the `.vt-panel` rules). `.vt-stack` does not
exist yet (verified). Because the panel becomes `display:grid`, the header's existing
`margin-bottom` would double up with the grid gap — neutralize it:
```css
/* Uniform vertical rhythm for stacked panel content (e.g. the enrolled MFA panel:
   header / backup-code status / trusted-browser controls). */
.vt-stack {
  display: grid;
  gap: var(--sg-space-4);
}

/* When a panel header sits inside a stack, the grid gap owns the spacing below it. */
.vt-stack > .vt-panel__header {
  margin-bottom: 0;
}
```
Result: header → backup block → trust block, and (within the backup block) alert → "Regenerate
codes", are all evenly spaced by `--sg-space-4`. Other panels (no `vt-stack`) are unaffected and
keep the header `margin-bottom` convention.

## Verification (executor, browser-free)
- `cd test/example && mix compile --warnings-as-errors` clean.
- `git diff --stat`: only the two test/example/ files (mfa_settings_live.ex + app.css). No priv/templates, no test/fixtures, no *.png.
- `cd test/example && mix test test/example_web/smoke/mfa_totp_test.exs test/example_web/live/passkey_settings_live_test.exs --include example_app` green (copy/ids preserved). If DB down: scripts/db/up.sh && source tmp/db.env if present, else note SKIPPED.
- Commit in one part (code only, NOT docs). Live browser verification (enrolled MFA page: no empty icon box, even spacing above Regenerate codes + Revoke all trusted browsers, error tint preserved) is the orchestrator's job.
