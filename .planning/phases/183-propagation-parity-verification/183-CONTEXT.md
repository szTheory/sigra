# Phase 183 Context: Propagation, Parity + Verification

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Source:** Phase 181/182 outputs + propagation-surface scout + milestone plan

<domain>
## Phase Boundary

Propagate the ratified D4 Linked Rail logo into every shipping location the v1 logo occupied (installer templates + example app), under the SAME filenames; verify/sync sg-* tokens + sigra_auth.css (palette held, so this is verify-unchanged); recapture the admin Playwright baselines exactly once; run the full hygiene + test gate. Ends when the repo is coherent, all gates green, git clean. This is the milestone's final phase. NO new brandbook work, NO new logo design.
</domain>

<decisions>
## Implementation Decisions

### ⚠ CENTRAL REALITY — the "parity tests" pin v1 CONTENT, not just filenames
The milestone plan assumed logos could be swapped "under unchanged filenames so byte-parity assertions pass without test churn." **That premise is false.** The two guard tests assert v1-specific *content*:
- `test/example/test/example_web/admin_shell_test.exs` (~line 73, "ships cropped path-only Sigra lockup assets"): asserts `viewBox="20 12 188 54"`, `"Inter Display Black v4.1."`, has `<path`, NO `<text`, NO `font-family`.
- `test/sigra/install/features/admin_test.exs` (~line 245, "admin logo templates are cropped path-only lockups"): same four assertions on the installer templates.

Swapping in the D4 lockup (Space Grotesk, different viewBox, different descender geometry) will FAIL `viewBox="20 12 188 54"` and `"Inter Display Black v4.1."`. **Therefore these two test files' assertions MUST be updated** to the new D4 cropped viewBox + `"Space Grotesk v2.0"` provenance string. This is intended, minimal test churn that accompanies a deliberate logo change — the tests still verify the SAME invariant (cropped, path-only, no live text/font-family), just for v2. The roadmap SC1 phrase "without modification to test expectations" reflects the wrong premise; the real intent (parity holds, no broad test rewrites, installer == example) is satisfied by updating exactly these two pinned strings per file. **Record this as a deviation in PLAN + VERIFICATION.**

### Propagation targets (scout-confirmed)
- `priv/templates/sigra.install/admin/sigra-logo-primary.svg` + `sigra-logo-primary-dark.svg` (7011/7050 bytes, currently v1 Rail Accent, viewBox `20 12 188 54`, path-only)
- `test/example/priv/static/images/sigra-logo-primary.svg` + `sigra-logo-primary-dark.svg` — currently BYTE-IDENTICAL to the installer templates (`diff -q` confirms). Keep them byte-identical to the templates after the swap (installer is the source of truth; example mirrors it).
- `test/example/priv/static/images/rail-accent-mark.svg` + `rail-accent-mark-dark.svg` (611/625 bytes) — v1 demo-branding companion marks. If the mark changed (it did → D4 abstract rail glyph), update these to the D4 mark; confirm where they are referenced before editing and whether renaming is required (prefer content-swap under same filename to avoid reference churn — check for `rail-accent-mark` references first).
- `test/example/priv/static/images/logo.svg` (3072 bytes), `vaultr-mark.svg` (875, sibling-lib suite evidence) — OUT OF SCOPE unless a reference proves otherwise; vaultr-mark is intentionally a different library's mark.

### The cropped admin lockup is a distinct rendition (not a brandbook file copy)
The installer logo is an admin-topbar-cropped, path-only lockup at `viewBox="20 12 188 54"` (aspect ~3.48:1). The brandbook D4 `logo-primary.svg` is the full lockup at `viewBox="0 220 2410 1026"`. Phase 183 must PRODUCE an admin-cropped, path-only D4 lockup (light + dark) sized for the 54px topbar `<img>` slot, NOT copy the brandbook full lockup. Research must determine how the v1 cropped lockup was produced (crop script? hand-authored viewBox reframe of the outlined paths?) and reproduce that process for the D4 outlined paths. Keep it path-only / no `<text>` / no `font-family` so the (updated) test invariant still holds. The D4 cropped viewBox will differ from `20 12 188 54` because of the extended g-tail descender — compute the correct tight crop.

### sg-* tokens + auth CSS (BRAND2-12) — verify-unchanged
Palette was NOT changed in Phases 181–182 (#c2410c / #fdba74 ratified, no micro-tuning). So `--sg-color-brand*`/`--sg-logo-*` in `test/example/priv/static/assets/css/app.css`, the `#c2410c` accent defaults in `priv/templates/sigra.install/core/sigra_auth.css`, and `guides/reference/admin-design-contract.md` should be VERIFIED UNCHANGED (grep the hex values, confirm they already equal brandbook tokens) — no value edits expected. Document the three-surface ember parity as verified. A grep-based hex-parity check is a good gate.

### Playwright baseline recapture (BRAND2-13) — exactly once
The logo is in every admin screen's topbar, so changing it changes every baseline. Recapture ALL admin slugs once via `scripts/ci/snapshot-recapture-gate.sh`, then restore `scripts/ci/snapshot-canary-guard.sh` to its empty steady state. Per prior-phase learnings (memory): boot the dev server on an ALT port (4000 collides with Rulestead Docker; use 4011 per milestone plan), pre-compile to avoid code-reload crash, use `--update-snapshots=all`, and restore canary/unchanged slugs afterward. Postgres is available at localhost:5432 (scout-confirmed) so `mix test` and the dev server can run.

### Hygiene gate (BRAND2-14)
JSON/SVG/HTML parseability; no committed binaries introduced; brandbook size delta small (currently ~604KB); `mix test` exits 0; clean `git status`.

### Claude's Discretion
- The exact tight crop viewBox for the D4 admin lockup (compute from the outlined path bounds).
- Whether to add a grep-based hex-parity CI check or just assert inline.
- How to reproduce the cropping (reuse/extend `scripts/brand/` tooling vs hand-reframe).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The guard tests (must update assertions)
- `test/example/test/example_web/admin_shell_test.exs` — "ships cropped path-only Sigra lockup assets" test (~line 73)
- `test/sigra/install/features/admin_test.exs` — "admin logo templates are cropped path-only lockups" test (~line 245)

### Propagation targets
- `priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg` (installer source of truth)
- `test/example/priv/static/images/sigra-logo-primary{,-dark}.svg` (mirror — keep byte-identical to templates)
- `test/example/priv/static/images/rail-accent-mark{,-dark}.svg` (demo companion marks)
- admin shell template that embeds the logo `<img src=...>` (filenames load-bearing — do not rename)

### Source assets
- `brandbook/logo-primary.svg` / `logo-primary-dark.svg` (D4 full lockup, outlined Space Grotesk paths — source geometry to crop)
- `brandbook/logo-mark.svg` / `favicon.svg` (D4 abstract mark — source for rail-accent-mark companions)
- `brandbook/tokens.json` / `tokens.css` (ember values to parity-check against sg-*)

### Token parity surfaces (verify-unchanged)
- `test/example/priv/static/assets/css/app.css` (--sg-color-brand*/--sg-logo-* ~lines 67–77 + dark ~200)
- `priv/templates/sigra.install/core/sigra_auth.css` (#c2410c accent defaults)
- `guides/reference/admin-design-contract.md`

### CI harness
- `scripts/ci/snapshot-recapture-gate.sh`, `scripts/ci/snapshot-canary-guard.sh` (port 4011; all admin slugs)
- `test/example/priv/playwright/` (chromium baselines)
</canonical_refs>

<specifics>
## Specific Ideas

- Installer == example logo files are currently byte-identical; preserve that invariant after the swap (the example app demonstrates exactly what the installer ships).
- The updated test assertions should keep the SAME shape (cropped + path-only + no `<text>` + no `font-family`) and only change the two v1-pinned values (viewBox + font provenance) to the D4 equivalents — this proves the invariant survived the logo change rather than weakening the test.
- mix test requires Postgres at localhost:5432 (postgres/postgres) — confirmed accepting connections. SIGRA_TEST_PG_* env overrides exist if needed.
- Watch repo bloat: SVG-only, no rasters; the recapture PNGs are the only new binaries and they are intended Playwright baselines (not arbitrary binaries) — the hygiene "no binaries" check must scope to exclude the legitimate baseline artifacts.
</specifics>

<deferred>
## Deferred Ideas

- README header + GitHub social preview adoption → post-milestone gsd-quick fast-follow
- HexDocs/ExDoc theming, marketing site → out of milestone scope
- Sibling-library mark propagation (vaultr etc.) → not this milestone
</deferred>

---

*Phase: 183-propagation-parity-verification*
*Context gathered: 2026-06-13 from Phase 181/182 outputs + propagation scout (no separate discuss-phase — propagation surface is concrete and decisions follow from prior phases)*
