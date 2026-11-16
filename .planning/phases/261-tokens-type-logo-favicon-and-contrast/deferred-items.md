# Phase 261 Deferred Items

Out-of-scope discoveries logged by executors. Each is pre-existing and was not fixed by the plan that found it.

## 261-02

- `test/example/lib/example_web/components/layouts.ex` (the `<img src={~p"/images/tasklane-mark.svg"} ... />` line in `app/1`): the example project's own formatter, which includes the HEEx plugin, wants that long tag wrapped. It fails identically on the file at the plan's base commit. The root `mix format --check-formatted` (the CI and plan gate) does not load the HEEx plugin for `test/example/` and passes. Left untouched.

## 261-12

- `test/example/lib/example_web/live/settings_live.ex:133` (`<a href={~p"/dev/mailbox"} ...>`): a verified route to `/dev/mailbox`, which `router.ex` defines only under `Application.compile_env(:example, :dev_routes)` (set in `config/dev.exs` only). Every `MIX_ENV=test` compile of that file therefore prints `no route path for ExampleWeb.Router matches "/dev/mailbox"`, so `MIX_ENV=test mix compile --warnings-as-errors` fails in `test/example` independent of any plan. CI's example compile step runs in the dev env and passes. Plan 261-12's compile verify was amended to `MIX_ENV=dev`. A real fix (a plain string href, or a dev-only branch) is a separate change to an unrelated file; left untouched.

## 261-03

- `test/example/priv/static/assets/css/app.css` `.sg-nav-link:focus-visible` and `.sg-scope-switch__item:focus-visible`: both set `outline: none` and show only the hover tint (`--sg-color-brand-soft` ground, `--sg-color-brand-strong` text), not `--sg-focus-ring`. Every other `:focus-visible` consumer in the template and in `app.css` reads `var(--sg-focus-ring)`, so they inherited the new two-layer ring with no edit. These two set no ring colour of their own (so the plan's "change a consumer that sets its own ring colour" rule did not apply) and a tint-only focus state is existing behaviour that belongs to the layout phase (Phase 262). Left untouched.

## 261-04

- `test/example/priv/static/assets/css/app.css` `.sg-color-field__input` (a text input, `border: 1px solid var(--sg-color-line-strong)`) and `.sg-cmdk__trigger` (a button, `border: 1px solid var(--sg-color-line)`): both are interactive controls whose only edge is a divider-grade line, which the book forbids ("never Paper Line as the only edge of a control"). The plan scoped the `app.css` edit to `.sg-input` and `.sg-select` and pinned it with a one-line numstat criterion, so neither was changed. Each is a one-token fix (`--sg-color-control-edge`); the real-DOM non-text helper (plan 261-07/08) asserts only `.sg-input`, `.sg-select` and `.sg-btn--secondary`, so neither is covered until one of them is added. Phase 262 (layout) or a follow-up.
- Template `.sg-btn--secondary:hover` replaces the resting control edge with `--sg-elev-2`, and `.sg-filter-chip:hover` and `:has(input:checked)` replace it with a brand tint (24% and 32%), so those two states do not carry the 3:1 control edge the resting state now has. The resting edge is what BTOK-08 and the plan name; hover and checked states are unchanged behaviour and need a design decision (keep the edge under the elevation shadow, or accept the state change as the identifier). Phase 262.
- `guides/reference/admin-token-reference.md`: 31 `Brand Ref` cells in the Spacing, Type Scale, Radii, Elevation and Motion tables cite paths that `brand/tokens.json` does not contain (`space.*` 9, `typography.*` 12, `radius.*` 4, `shadow.*` 2, `motion.*` 4); they predate this plan, which re-pointed only the colour rows. The two font rows added here resolve (`font.sans`, `font.mono`). Re-pointing them is a docs-only change with no guard behind it today.

## 261-07

- `guides/reference/admin-fractal-scorecard.md` (D2 row), `guides/reference/admin-graphic-design-lens.md` (lines ~44, 125, 203, 424) and `scripts/panel/lenses.mjs` (lines ~104, 184): still describe Space Grotesk, `#c2410c` / `#fdba74` and the old logo as the admin identity. Documentation and panel-prompt text only, no runtime dependency; the same three files are already named by the pending todo `2026-11-13-residual-brandbook-pointers.md` and sit outside the BPOL-06 approval. Left untouched.
- `test/example/priv/static/assets/css/app.css` comments at ~54, ~91 and ~2413 say the `sg-*` admin chrome keeps Space Grotesk via `--font-sans`; since plan 261-04 the admin shell reads its opt-in Instrument Sans. Comment wording only; app.css has a stray-comment hazard and plan 261-07 forbids editing it, so they are left stale. `demo-showcase.spec.ts:332` carries the same stale phrase in a comment.
- Space Grotesk itself (woff2, `@font-face`, `--font-sans` override) is KEPT for the Tasklane host chrome (`default.css` feeds the override to the `html` font); see the "Retired suite face disposition" in `261-07-SUMMARY.md`. Retiring it needs a host typeface decision.
