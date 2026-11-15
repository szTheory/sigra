---
created: 2026-11-14T00:00:00.000Z
status: pending
title: Brand harness code review (Phase 259) - deferred findings needing an owner or scope decision
area: testing
severity: minor
source: Phase 259 code review (259-REVIEW.md) and fix report (259-REVIEW-FIX.md)
files:
  - test/support/brand/copy_scan.ex
  - test/support/brand/copy_inventory.ex
  - test/sigra/brand/copy_contract_test.exs
  - test/sigra/brand/frozen_surface_test.exs
  - test/example/test/example_web/enumeration_parity_test.exs
  - test/sigra/brand/source_pin_test.exs
---

Phase 259's code review found 0 critical and 8 warnings. WR-01, WR-02, WR-06, WR-07, WR-08 and the wording-only part of WR-03 were fixed (see `259-REVIEW-FIX.md`). The items below were deliberately NOT changed because they are scope or owner decisions, not mechanical fixes. Evidence and suggested fixes are in `259-REVIEW.md` under the same ids.

## Decisions needed

- **WR-03 (scope part):** the copy inventory does not extract JS hook copy (`passkey_browser.js`, `admin_hooks.js`), HEEx attribute values (`label=`, `placeholder=`, `aria-label=`, `title=`, `phx-disable-with=`, `data-confirm=`), or raw Elixir literals outside dgettext / put_flash / HEEx / email builders (about 200 multi-word generated strings). The headers now say so. Decide whether a Phase 262-263 task adds `literal` and `heex_attr` kinds (one regeneration plus a reviewed diff) before copy edits begin; until then a copy edit to those forms passes the inventory unseen.
- **WR-04:** the admin copy contract is pinned to nine files. `lib/sigra/error.ex` (27 `safe_message` strings), `lib/sigra/admin/audit/presenter.ex` (7) and a few other strings under `lib/sigra/admin/` sit outside every scope although the inventory lists them. Decide whether to widen the scope (this changes baselines in the growing direction, so it needs review).
- **WR-05:** the add-only and shrink-only ratchets (frozen-surface, copy-baseline) can be loosened by editing the JSON in the same commit as the breaking change; there is no base-branch diff gate or CODEOWNERS file, and an unknown scope name in a baseline entry is ignored. Decide on a CI diff-against-base check and/or CODEOWNERS for `test/fixtures/brand/`.
## Info findings (optional cleanup)

- IN-01: the privacy scan models fewer metadata containers than its claim (UTF-16 font records, JPEG XMP/COM, PNG `iCCP`/`tIME`, PDF XMP). The real `brand/` tree is clean today.
- IN-02: `markup_classes` in `frozen_surface_test.exs` truncates `class={...}` at the first `}`; latent.
- IN-03: duplicated helpers across the brand tests (`pretty/2`, `section_slice`, `cells`, `read!`).
- IN-04 (necessity): the `extend_only` refusal inside `extend_baseline!` is unreachable.
- IN-05 (necessity): the sweep allow-list machinery supports a list the policy says must stay empty.

## Resolved

- **WR-08 (residual), resolved by Plan 259-16:** the `mfa-challenge` row varies by code kind, not account existence, so it is kept as a parity probe and counted separately. The named-surface rule in `enumeration_parity_test.exs` now requires the three account-existence surfaces (`password-signin`, `magic-link-request`, `password-reset-request`) to be parity on their own, with `confirmation-resend` (payload ignored) and `mfa-challenge` (code kind) in separate classes that can never satisfy or stand in for them; the "at least three of five" floor and the parity-or-not_proven tolerance are deleted. The classification is test-only and reversible with a one-line edit; the owner may revisit it.

## Housekeeping noticed by the fixer

`mix format` run inside `test/example` reformats seven pre-existing unformatted files under `test/example/lib/`; the drift is already at HEAD and was left alone.
