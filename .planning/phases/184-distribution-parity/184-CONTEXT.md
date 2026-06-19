# Phase 184: Distribution & Parity - Context

**Gathered:** 2026-06-13 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the admin-CSS distribution gap for the v1.39 DS-COHERENCE milestone. Extract the
canonical admin `sg-*` design system out of the example app into a single shipped installer
asset, ship it to generated hosts, link it in the generated admin layout, have the example
consume the SAME canonical file, prove byte-parity with a merge-blocking test, and prove a
freshly generated host renders a *styled* admin UI.

**In scope:** the `sg-*` admin design system extraction + distribution + parity + styled-host
proof (DIST-01..06), mirroring the v1.37 `sigra_auth.css` distribution pattern.

**Out of scope:** the example-only `vt-*`/Vaultr brand layer (stays in the example, NOT
extracted); any change to token *values* (reserved for Phase 186); new admin features/screens;
the `/admin/_design` gallery + audit infrastructure (Phase 185).
</domain>

<decisions>
## Implementation Decisions

### Extraction Boundary (sg-* out, vt-* stays)
- **D-01:** `priv/templates/sigra.install/admin/sigra_admin.css` is produced as a
  *selector/token-aware re-section* of `test/example/priv/static/assets/css/app.css`, NOT a
  contiguous line-range cut. Carry over: the `@layer sg-base, sg-components, sg-overrides;`
  declaration, all `--sg-*` custom properties from `:root`, all `@layer sg-base{}` /
  `@layer sg-components{}` / `@layer sg-overrides{}` rule blocks, and the leading
  "layer order matters" header comment.
- **D-02:** Drop from the extraction: all `--vt-*` `:root` tokens and every `.vt-*` rule —
  including the "VAULTR HOST APP" subsection that currently lives *inside*
  `@layer sg-components`. After extraction, `app.css` retains only the `vt-*`/Vaultr layer
  (plus whatever non-`sg-*` glue the example still needs).
- **D-03:** MANDATORY planner verification (not an assumption): audit each extracted `sg-*`
  rule to confirm it depends only on `var(--sg-*)` tokens — no residual dependency on a
  `--vt-*` token or a daisyUI `default.css` base rule. Generated hosts ship neither, so any
  such dependency would render that element broken in the host.

### Example Consumption — Stronger-Than-Auth Parity (DIST-04)
- **D-04:** The example consumes the canonical file by linking `/assets/sigra_admin.css` from a
  **checked-in `test/example/priv/static/assets/sigra_admin.css` that is byte-guarded identical
  to the template** (checked-in copy + test-enforced parity; NOT a symlink or build-copy). The
  example stops sourcing `sg-*` from `app.css`.
- **D-05:** This is deliberately a STRONGER guarantee than the v1.37 auth precedent actually
  delivers. The existing example `sigra_auth.css` (12,281 B) is a *stale divergent copy* of its
  template (19,379 B) — only the install-golden fixture is byte-guarded, not the example. Phase
  184 must NOT reproduce that divergence: example ≡ template byte-identity is required so
  "no divergent copy" (DIST-04) is genuinely true and Playwright/axe run against what ships.

### Parity + Styled-Host Proof (DIST-05 / DIST-06)
- **D-06:** DIST-05 = a new merge-blocking ExUnit byte-comparison asserting
  `priv/templates/sigra.install/admin/sigra_admin.css` ≡
  `test/example/priv/static/assets/sigra_admin.css`, PLUS adding the shipped CSS to the
  install-golden fixture tree + manifest so `golden_diff_test.exs` byte-checks the host copy
  for free (template ↔ fixture parity, the existing auth mechanism).
- **D-07:** DIST-06 = extend the EXISTING `generated_admin_playwright_smoke` job
  (`.github/workflows/ci.yml:952` driven by `scripts/ci/admin-acceptance-smoke.sh`) and the
  existing `test/example/priv/playwright/tests/admin-generated.spec.ts` with an explicit
  *styled* assertion (computed-style or loaded-class check proving `sigra_admin.css` actually
  loaded) — NOT a new lane. Today the spec asserts only shell/scope/denial semantics and the
  generated host links no admin CSS, so the styled assertion is what actually closes the gap.

### DIST-02 / DIST-03 Wiring (Confident, no decision needed)
- **D-08:** DIST-02 — add `{:eex, "admin/sigra_admin.css", Path.join(["priv","static","assets","sigra_admin.css"])}`
  to `lib/sigra/install/features/admin.ex` `files/1` (exact analog of `core.ex` shipping
  `sigra_auth.css`). The CSS has no EEX markers, so `:eex` copies it verbatim (match the auth
  precedent's `:eex`).
- **D-09:** DIST-03 — add a body-level
  `<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />` inside
  `def admin/1` in `priv/templates/sigra.install/admin/layouts_admin_injection.ex` (the `admin/1`
  content renders body-level; the host `<head>` is in `root.html.heex`). This is the established
  Sigra pattern — identical to the body-level link in `core/sigra_auth_components.ex:27`.

### Canonical Filenames/Paths
- **D-10:** Template `priv/templates/sigra.install/admin/sigra_admin.css`; host target
  `priv/static/assets/sigra_admin.css`; example copy
  `test/example/priv/static/assets/sigra_admin.css`; install-golden fixture copy
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`.

### Snapshot Canary
- **D-11:** The extraction is expected to be a visual no-op for the *example* (same `sg-*` rules,
  relocated), so `scripts/ci/snapshot-canary-guard.sh` (empty steady-state allowlist) should stay
  green. The planner MUST preserve cascade-layer load order so `sg-*` layers still outrank
  daisyUI `default.css` after the move; if a computed style shifts, the canary flags it and the PR
  must declare the intended-delta slug.

### Claude's Discretion
- Exact ExUnit test module/location for the DIST-05 byte-compare (follow existing
  `test/sigra/install/` conventions).
- Precise selector for the DIST-06 "styled" Playwright assertion (any stable, computed-style or
  loaded-class signal that proves the stylesheet applied).
- Whether the example still needs a thin non-`sg-*` glue block in `app.css` beyond `vt-*`
  (determined by the D-03 dependency audit).

### Folded Todos
None — `todo.match-phase 184` returned 0 matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

v1.37 auth-CSS distribution precedent (Phase 184 mirrors this end-to-end):
- `priv/templates/sigra.install/core/sigra_auth.css` — shipped template (the pattern)
- `lib/sigra/install/features/core.ex` — `files/1` shipping `sigra_auth.css` (DIST-02 analog)
- `priv/templates/sigra.install/core/sigra_auth_components.ex` — body-level `<link>` (DIST-03 analog, ~line 27)
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css` — byte-guarded fixture copy
- `test/sigra/install/features/core_test.exs` — manifest assertions (`:155`, `:293`) for sources/targets
- `test/sigra/install/templates_layout_test.exs` — file-count manifest (`:54`)
- `test/sigra/install/` `golden_diff_test.exs` — whole-tree byte comparison

Phase 184 working surfaces:
- `test/example/priv/static/assets/css/app.css` — the 3848-line file holding trapped `sg-*` + `vt-*`
- `lib/sigra/install/features/admin.ex` — `files/1` (currently ships no CSS)
- `priv/templates/sigra.install/admin/layouts_admin_injection.ex` — `def admin/1` (currently links no CSS)
- `test/example/lib/example_web/components/layouts/root.html.heex` — current `app.css` + `default.css` link order
- `.github/workflows/ci.yml` (~line 952) — `generated_admin_playwright_smoke` job
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host install + boot driver (RUN_PARITY=1)
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — DIST-06 styled assertion target
- `scripts/ci/snapshot-canary-guard.sh` — empty-allowlist visual idempotency guard

Milestone refs:
- `.planning/ROADMAP.md` — Phase 184 detail section
- `.planning/REQUIREMENTS.md` — DIST-01..06
- `.planning/METHODOLOGY.md` — Decisive Defaulting / escalation threshold lenses
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The entire v1.37 `sigra_auth.css` distribution pipeline (template → `files/1` → host target →
  install-golden fixture → `golden_diff_test.exs` → manifest assertions → body-level `<link>`) is
  the direct, proven template to copy for the admin CSS.
- The `generated_admin_playwright_smoke` CI job + `admin-acceptance-smoke.sh` already install Sigra
  into a fresh phx_new 1.8.7 host and boot it — DIST-06 extends, not rebuilds.
- The snapshot canary/allowlist harness (`snapshot-canary-guard.sh`) already enforces visual
  idempotency at empty steady-state.

### Established Patterns
- Installer assets ship via `features/*.ex` `files/1` tuples; CSS uses `:eex` even when marker-free.
- Stylesheets are linked body-level from rendered components/layouts (host owns `<head>` via
  `root.html.heex`), per `sigra_auth_components.ex`.
- Byte-parity is enforced template↔fixture through the install-golden tree, NOT template↔example
  (the auth example copy is stale/divergent — a wart Phase 184 deliberately corrects for admin).
- Cascade layers (`@layer sg-base, sg-components, sg-overrides;`) are how `sg-*` outranks daisyUI
  `default.css`; load order must be preserved on extraction.

### Integration Points
- `lib/sigra/install/features/admin.ex` `files/1` — add the CSS tuple.
- `priv/templates/sigra.install/admin/layouts_admin_injection.ex` `def admin/1` — add the `<link>`.
- `test/example/.../root.html.heex` (or the example admin shell) — link the canonical example copy;
  reduce `app.css` to `vt-*`-only.
- install-golden fixture tree + manifest — register the new shipped file.
- `admin-generated.spec.ts` — add the styled assertion.
</code_context>

<specifics>
## Specific Ideas

- The "stale divergent copy" wart in the auth precedent (example `sigra_auth.css` 12,281 B vs
  template 19,379 B, only fixture byte-guarded) is the concrete reason DIST-04/05 demand the
  STRONGER example≡template guarantee for admin. Do not copy the auth example-copy pattern
  literally; guard the example copy.
</specifics>

<deferred>
## Deferred Ideas

- Retroactively byte-guarding / de-staling the example `sigra_auth.css` copy against its template
  (the auth-side wart this phase reveals) — out of scope for Phase 184 (auth UI is not a v1.39
  target surface); note for a future maintenance `/gsd-quick` if desired.

### Reviewed Todos (not folded)
None — `todo.match-phase 184` returned 0 matches.
</deferred>
