# Phase 183: Propagation, Parity + Verification — Research

**Researched:** 2026-06-13
**Domain:** SVG crop derivation, test assertion migration, Playwright baseline recapture, CSS hex parity
**Confidence:** HIGH — all findings verified against live repo files

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Propagation targets:** `priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg` (installer source) + `test/example/priv/static/images/sigra-logo-primary{,-dark}.svg` (mirror, byte-identical to templates). Keep installer == example byte-identical after swap.
- **Companion marks:** `test/example/priv/static/images/rail-accent-mark{,-dark}.svg` — if the mark changed (it did), update to D4 abstract mark content under the same filenames (content-swap, no rename, to avoid reference churn).
- **Test assertion churn is intended:** Two test files assert v1-pinned content strings. Both MUST be updated to D4 equivalents (`viewBox` + provenance). This is documented deviation from the ROADMAP SC1 phrase "without modification to test expectations" — the real intent (same structural invariant, installer == example) is satisfied by updating exactly the two pinned strings per file.
- **The admin lockup is a DISTINCT RENDITION,** not a direct copy of the brandbook full lockup. Must be produced as an admin-topbar-cropped, path-only D4 SVG.
- **sg-* tokens + auth CSS (BRAND2-12):** Verify UNCHANGED. Palette was not changed in Phase 181–182 (#c2410c / #fdba74 ratified, no micro-tuning). No value edits expected.
- **Playwright recapture (BRAND2-13):** Exactly once via `scripts/ci/snapshot-recapture-gate.sh`. Port 4011. ALL 7 non-canary admin slugs. After gate passes, reset `snapshot-allowlist` to empty (comments only).
- **Hygiene gate (BRAND2-14):** JSON/SVG/HTML parseability; no committed binaries outside allowed Playwright baseline dir; brandbook size delta small; `mix test` exits 0; clean `git status`.

### Claude's Discretion

- The exact tight crop viewBox for the D4 admin lockup (compute from outlined path bounds). Resolved below.
- Whether to add a grep-based hex-parity CI check or just assert inline. Resolved: inline grep check in verification, no new CI script.
- How to reproduce the cropping (reuse/extend scripts/brand/ tooling vs hand-reframe). Resolved: pure viewBox reframe — the D4 brandbook paths are used verbatim; only the `viewBox` attribute is tightened.

### Deferred Ideas (OUT OF SCOPE)

- README header + GitHub social preview adoption
- HexDocs/ExDoc theming, marketing site
- Sibling-library mark propagation (vaultr etc.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRAND2-11 | The ratified logo propagated byte-identically to installer + example under unchanged filenames; all installer/example parity tests pass | Derivation recipe below; exact viewBox and desc provenance for updated test assertions documented |
| BRAND2-12 | sg-* token values in example CSS, sigra_auth.css accent defaults, and admin design contract re-synced (or verified unchanged if palette held) | Hex values grepped, confirmed unchanged — verify-only task, no edits |
| BRAND2-13 | Admin Playwright baselines recaptured once via snapshot-recapture-gate.sh; canary guard returns to empty steady state | Full recapture procedure, port, slug list, allowlist state documented |
| BRAND2-14 | Hygiene gate: parseability, no binary sprawl, small brandbook size delta, green mix test, clean git | Scoped binary check, test suite structure, SVG size delta estimated |
</phase_requirements>

---

## Summary

Phase 183 is the final milestone phase: propagate the ratified D4 Linked Rail logo into the four shipping SVG locations, update two test assertion strings, recapture all 7 non-canary Playwright baselines, and verify palette parity across three CSS surfaces.

The core technical challenge is that the D4 admin lockup must be DERIVED, not copied — the brandbook `logo-primary.svg` uses `viewBox="0 220 2410 1026"` which includes padding and the full coordinate space. The installer needs a tighter crop that respects the extended g-tail descender unique to D4. The derivation is a pure viewBox reframe of the brandbook paths: no path data changes, no script invocation. The computed tight-crop viewBox is `"20 220 2361 1000"` (see Unknown 1 below for full derivation).

The two test assertion changes are minimal and mechanical: replace `viewBox="20 12 188 54"` with the D4 crop value and replace `"Inter Display Black v4.1."` with `"Space Grotesk v2.0"`. The structural assertions (has `<path`, no `<text`, no `font-family`) remain correct for D4 and require no change.

**Primary recommendation:** Produce the admin lockup SVGs by pure viewBox reframe of brandbook paths → swap into four locations simultaneously → update the two assertion strings → verify token parity via grep → run mix test → recapture 7 slugs × 3 Playwright projects → restore empty allowlist → hygiene sweep → clean git.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Admin topbar logo display | Frontend Server (Phoenix LiveView) | CDN / Static (served from priv/static) | Logo is an `<img>` tag in the admin shell component; file served as static asset |
| Installer template delivery | Library (priv/templates) | — | Installer copies templates into host app's priv/static; library owns the source |
| Test assertions | ExUnit (library + example app) | — | Two test files guard structural invariants; planner must update both |
| Playwright baseline capture | Static artifact (test/example/priv/playwright) | CI harness | baselines committed to repo; recapture gate is the approval mechanism |
| CSS token parity | Example app CSS + installer CSS | brandbook/tokens.json | Three surfaces must agree; palette held so verify-only this phase |

---

## Unknown 1: Producing the Admin-Cropped Path-Only D4 Lockup

### How the v1 cropped lockup was built

The v1 `sigra-logo-primary.svg` was hand-authored. It combines:
1. A staggered-bars `<g>` (the Rail Accent mark — three-path construction) positioned via `transform="translate(10 7)"`
2. A wordmark `<g>` with five `<path>` elements from `outline-wordmark.mjs` output, positioned via `transform="translate(75 55)"` at Inter Display pixel-scale coordinates
3. `viewBox="20 12 188 54"` — a pixel-scale tight crop sized for the 54px admin topbar `<img>` slot (aspect 3.48:1)

The v1 coordinate scale was approximately 1 SVG unit = 1 pixel (paths span from about x=0–130, y=0–55 at full scale).

### The D4 brandbook coordinate scale

The D4 `brandbook/logo-primary.svg` uses Space Grotesk UPM-scale coordinates (font units per em ≈ 1000, paths span x=42–2361, y=246–1200). Key elements:

- `viewBox="0 220 2410 1026"` — full lockup with generous padding
- `<g id="glyphs" fill="#151515">` — five path elements `g-0` through `g-4`, NO transforms, absolute coords
- `<rect id="rail-tittle" x="557" y="246" width="200" height="200" fill="#c2410c">` — the integrated ember block (the D4 mark — NOT the v1 staggered bars)
- No `<text>` elements, no `font-family` — D4 is path-only just like v1 ✓

### Derivation recipe for the admin lockup (pure viewBox reframe)

The D4 admin lockup is produced by copying the brandbook `logo-primary.svg` verbatim and changing exactly three things: `viewBox`, `<title>`, and `<desc>`. No path data changes. No script invocation needed.

**Step 1: Compute the tight-crop viewBox from path bounds**

| Element | Leftmost x | Rightmost x | Top y | Bottom y |
|---------|-----------|------------|-------|----------|
| `<rect id="rail-tittle">` | 557 | 757 | **246** | 446 |
| `g-0` (S glyph) | **42** | 484 | 490 | 1014 |
| `g-1` (i glyph) | 594 | 720 | 504 | 1000 |
| `g-2` (g glyph) | 557† | 1358 | 490 | **1200** |
| `g-3` (r glyph) | 1498 | 1796 | 502 | 1000 |
| `g-4` (a glyph) | ~1843 | **2361** | 490 | 1014 |

†g-2 tail bracket: `L557 1200` is the extended g-tail hitting x=557 at y=1200 (the design's bracketing rail system)

Content bounding box: x=[42, 2361], y=[246, 1200]

With ~20-unit margin on each side:
- `minX` = 20 (42 − 22 = 20)
- `minY` = 220 (brandbook already starts here, gives 26 units above tittle top at y=246)
- `maxX` = 2381 (2361 + 20)
- `maxY` = 1220 (1200 + 20)
- `width` = 2381 − 20 = **2361**
- `height` = 1220 − 220 = **1000**

**Tight-crop viewBox: `"20 220 2361 1000"` (aspect 2.361:1)**

At 54px height render (admin topbar `<img>`): width ≈ 54 × 2.361 = 127.5px. This fits the topbar slot cleanly — narrower than v1's 188px width at 54px height but proportionally correct for D4's aspect ratio.

**Step 2: Title and desc for the admin lockup**

```xml
<!-- Light variant -->
<title id="title">Sigra primary logo</title>
<desc id="desc">
  The Sigra D4 Linked Rail tight lockup for light surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0.
</desc>

<!-- Dark variant -->
<title id="title">Sigra primary logo for dark surfaces</title>
<desc id="desc">
  The Sigra D4 Linked Rail tight lockup with a light wordmark for dark surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0.
</desc>
```

The `<desc>` MUST contain the substring `"Space Grotesk v2.0"` — this is exactly what the updated test assertion will check.

**Step 3: Light vs dark differences**

| Element | Light variant | Dark variant |
|---------|--------------|-------------|
| `<g id="glyphs">` fill | `#151515` | `#f4f1eb` |
| `<rect id="rail-tittle">` fill | `#c2410c` (ember-700) | `#fdba74` (ember-300) |
| `<title>` | "Sigra primary logo" | "Sigra primary logo for dark surfaces" |
| Path data (g-0 through g-4) | **identical** | **identical** |
| viewBox | `"20 220 2361 1000"` | `"20 220 2361 1000"` |

**Step 4: Path-only invariant check**

D4 `brandbook/logo-primary.svg` confirmed to have zero `<text>` elements and zero `font-family` references. [VERIFIED: grepped live file] The updated test assertions `refute source =~ "<text"` and `refute source =~ "font-family"` remain valid for D4 without any changes to those assertion lines.

### Companion marks: rail-accent-mark{,-dark}.svg

[VERIFIED: grepped repo] These files are referenced in two locations:
1. `test/example/lib/example/demo/branding.ex` lines 73, 88 — `logo_url:` field in `@rail_accent_light` and `@rail_accent_dark` demo brand profiles
2. `test/example/priv/playwright/tests/demo-showcase.spec.ts` line 639 — asserts `toHaveAttribute("src", "/images/rail-accent-mark-dark.svg")`

The Playwright assertion checks the `src` attribute only (filename), NOT the SVG content. No ExUnit test asserts the content of these files. Therefore: **content-swap under the same filenames is safe** — no test updates needed.

The D4 mark (`brandbook/logo-mark.svg`) has a CSS `@media (prefers-color-scheme: dark)` auto-switch block. The companion marks are separate light/dark files (no CSS), so derive two explicit variants:

- `rail-accent-mark.svg` (light): logo-mark.svg geometry with CSS removed, explicit `fill="#151515"` on the `<g id="glyphs">` and `fill="#c2410c"` on `<rect id="rail-block">`, same `viewBox="-70 -60 1040 1040"`, accessible `<title>`/`<desc>`
- `rail-accent-mark-dark.svg` (dark): same geometry, `fill="#f4f1eb"` on glyphs, `fill="#fdba74"` on rail-block

Size comparison: `logo-mark.svg` is 843 bytes; companion marks will be ~650–750 bytes (slightly larger than v1's 611/625 due to added title/desc, slightly smaller from removing CSS media query).

---

## Unknown 2: Exact Test Assertion Changes

### File 1: `test/example/test/example_web/admin_shell_test.exs`

Location: `test "ships cropped path-only Sigra lockup assets"` at line 72–85.

**Current assertion block (lines 79–80):**
```elixir
assert source =~ ~s(viewBox="20 12 188 54")
assert source =~ "Inter Display Black v4.1."
```

**New assertion block after Phase 183:**
```elixir
assert source =~ ~s(viewBox="20 220 2361 1000")
assert source =~ "Space Grotesk v2.0"
```

Lines 81–84 remain UNCHANGED:
```elixir
assert source =~ "<path"
refute source =~ "<text"
refute source =~ "font-family"
```

### File 2: `test/sigra/install/features/admin_test.exs`

Location: `test "admin logo templates are cropped path-only lockups"` at line 245–258.

**Current assertion block (lines 252–253):**
```elixir
assert source =~ ~s(viewBox="20 12 188 54")
assert source =~ "Inter Display Black v4.1."
```

**New assertion block after Phase 183:**
```elixir
assert source =~ ~s(viewBox="20 220 2361 1000")
assert source =~ "Space Grotesk v2.0"
```

Lines 254–257 remain UNCHANGED:
```elixir
assert source =~ "<path"
refute source =~ "<text"
refute source =~ "font-family"
```

### Complete list of ALL tests that assert logo content or dimensions

[VERIFIED: grepped test/ tree for "Inter Display", "20 12 188 54", "sigra-logo", "viewBox", "Rail Accent"]

| File | Line | Assertion type | Action required |
|------|------|---------------|-----------------|
| `test/example/test/example_web/admin_shell_test.exs` | 79–80 | v1 viewBox + font provenance | UPDATE (2 lines) |
| `test/example/test/example_web/admin_shell_test.exs` | 26–27 | `src=` filenames (unchanged) | NO CHANGE |
| `test/sigra/install/features/admin_test.exs` | 252–253 | v1 viewBox + font provenance | UPDATE (2 lines) |
| `test/sigra/install/features/admin_test.exs` | 26–29 | Template filenames in install manifest | NO CHANGE |
| `test/sigra/install/features/admin_test.exs` | 213–214 | `~p"/images/sigra-logo-primary..."` in shell template | NO CHANGE |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts` | 639 | `src="/images/rail-accent-mark-dark.svg"` (filename only) | NO CHANGE |
| `test/fixtures/install_golden/tree/...` | 56, 64 | `~p"/images/sigra-logo-primary..."` (filename) | NO CHANGE |

**Total required test file edits: 2 files, 2 lines each = 4 lines changed.**

No test file currently asserts `"Rail Accent"` as a LOGO content string (those references in `branding.ex` are demo brand profile names, not logo file content assertions).

---

## Unknown 3: Playwright Baseline Recapture Mechanics

### Scripts and port

- **Recapture gate:** `scripts/ci/snapshot-recapture-gate.sh` — usage: `snapshot-recapture-gate.sh <slug>...`
- **Canary guard:** `scripts/ci/snapshot-canary-guard.sh` — checks committed/untracked PNGs against allowlist
- **Default URL:** `SIGRA_EXAMPLE_URL="${SIGRA_EXAMPLE_URL:-http://localhost:4011}"` [VERIFIED: read script line 18]
- **Playwright config default:** `baseURL: process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000'` — the `4011` default in the gate script overrides the `4000` default in `playwright.config.ts`
- **Port 4000 conflict:** Rulestead Docker container holds port 4000 — ALWAYS use port 4011 for Phase 183

### What the gate script does (all 3 steps)

```
(a) compare-mode admin-checkpoints.spec.ts across 3 projects:
    npx playwright test tests/admin-checkpoints.spec.ts
      --project=admin-checkpoints-chromium
      --project=admin-checkpoints-mobile
      --project=admin-checkpoints-dark
    (in compare mode, NOT --update-snapshots)

(b) canary guard with --require-all:
    scripts/ci/snapshot-canary-guard.sh --base HEAD --require-all --allow <slug>...
    (verifies: each declared slug DID change, no undeclared slugs changed,
     canary 'impersonation-banner' did NOT change)

(c) ExUnit component byte-goldens:
    MIX_ENV=test mix test test/sigra/admin/components_test.exs
```

### Full slug list for Phase 183 recapture

8 total slugs (3 projects each = 24 PNGs), but `impersonation-banner` is the canary:

| Slug | Recapture | Reason |
|------|-----------|--------|
| `global-overview` | YES | Admin topbar visible |
| `org-overview` | YES | Admin topbar visible |
| `global-user-index` | YES | Admin topbar visible |
| `user-detail` | YES | Admin topbar visible |
| `org-scoped-admin` | YES | Admin topbar visible |
| `user-audit` | YES | Admin topbar visible |
| `audit-explorer` | YES | Admin topbar visible |
| `impersonation-banner` | **NO (canary)** | Captures `/organizations/:slug/members` — non-admin page, no admin topbar, logo NOT visible |

[VERIFIED: `admin-checkpoints.spec.ts` impersonation-banner captures `/organizations/${orgSlug}/members` — the regular org members page, not an admin page]

### snapshot-allowlist: current state vs what Phase 183 needs

**Current state (NOT empty — 4 slugs carried over from a prior phase):**
```
global-overview
org-overview
user-audit
user-detail
```

**Phase 183 needs all 7 slugs declared.** The 3 missing ones (`audit-explorer`, `global-user-index`, `org-scoped-admin`) must be added BEFORE running `--update-snapshots=all` so the canary guard's `--require-all` check passes.

**Final steady-state (after gate passes):** reset the allowlist to comments-only (empty steady state). The file header explains: "STEADY STATE: this file is empty (comments only)."

### Exact recapture procedure

**Prerequisites:**
- Postgres running at localhost:5432 (postgres/postgres) — confirmed scout-verified
- All SVG file edits and test assertion updates committed (or staged) before booting dev server — do NOT run `mix test` or modify library code with the example server running (code-reload will crash it)
- Pre-compile the example app to prevent code-reload crash on first request

**Step-by-step:**

```bash
# 1. Update snapshot-allowlist to include all 7 non-canary slugs
# (edit file to add audit-explorer, global-user-index, org-scoped-admin)

# 2. Pre-compile example app (prevents code-reload crash)
cd /path/to/sigra/test/example && mix compile

# 3. Boot example dev server on port 4011 (NOT 4000 — Rulestead holds 4000)
cd test/example
PORT=4011 PHX_SERVER=true MIX_ENV=dev mix phx.server &
SERVER_PID=$!

# 4. Wait for server ready, warm the admin routes
sleep 5
curl -sf http://localhost:4011/admin > /dev/null

# 5. Run --update-snapshots=all to force re-record ALL 24 baselines
cd test/example/priv/playwright
SIGRA_EXAMPLE_URL=http://localhost:4011 \
  npx playwright test tests/admin-checkpoints.spec.ts \
    --project=admin-checkpoints-chromium \
    --project=admin-checkpoints-mobile \
    --project=admin-checkpoints-dark \
    --update-snapshots=all

# 6. CRITICAL: restore the impersonation-banner canary (it MUST be unchanged)
git checkout -- \
  test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-chromium.png \
  test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-mobile.png \
  test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-dark.png

# 7. Kill dev server
kill $SERVER_PID

# 8. Run the approval gate (compares all 3 projects, verifies canary, runs ExUnit goldens)
scripts/ci/snapshot-recapture-gate.sh \
  audit-explorer global-overview global-user-index \
  org-overview org-scoped-admin user-audit user-detail

# 9. If gate passes: reset snapshot-allowlist to empty steady state
# (remove all 7 slug lines, keep only comment block)
```

### Baseline PNG count and location

- **24 baseline PNGs** in `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/`
- 8 slugs × 3 projects (chromium, mobile, dark)
- After `--update-snapshots=all` + canary restore: 21 PNGs changed, 3 unchanged (impersonation-banner)

### Known gotchas from prior phases

- `--update-snapshots` (without `=all`) uses `changed` preset — will NOT rewrite a baseline whose render is within tolerance. ALWAYS use `=all` for a deliberate full logo change.
- `admin-checkpoints.spec.ts-snapshots/` uses a custom `pathTemplate` in playwright.config.ts that omits the OS suffix — baselines are compatible across macOS and Linux CI.
- The `notice/1` component wraps its slot in `<p class="sg-text-sm">` — pass inline content only (no block children). This is a pre-existing constraint, not new for Phase 183.
- `maxDiffPixels` thresholds are intentionally generous (30k–200k depending on project/CI) so the recapture gate will pass on first compare run.

### Artifacts directory (do NOT confuse with spec-snapshots)

`test/example/priv/playwright/artifacts/` contains stale `.png` files with hash-suffixed names — these are Playwright test-run artifacts, NOT the committed baselines. The canary guard and recapture gate both operate on `tests/admin-checkpoints.spec.ts-snapshots/` (no `artifacts/` subdirectory). The `artifacts/` directory is gitignored and irrelevant to Phase 183.

---

## Unknown 4: Token Parity Verification (BRAND2-12)

### Three-surface parity check

[VERIFIED: grepped live files]

| Surface | File | Key tokens | Values found |
|---------|------|-----------|-------------|
| Brandbook source | `brandbook/tokens.json` | `ember-700`, `ember-300` | `"#c2410c"`, `"#fdba74"` |
| Admin sg-* (light) | `test/example/priv/static/assets/css/app.css` | `--sg-color-brand`, `--sg-logo-rail-ember`, `--sg-logo-rail-accent` | `#c2410c`, `#c2410c`, `#fdba74` |
| Admin sg-* (dark) | same file (dark media query) | `--sg-logo-rail-ember` override | `#f97316` (on dark, different — intentional) |
| Auth CSS | `priv/templates/sigra.install/core/sigra_auth.css` | `--sigra-auth-light-accent` fallback | `#c2410c` |
| Admin design contract | `guides/reference/admin-design-contract.md` | Mention of `#fdba74` in WCAG note | `#fdba74` (in Phase 160 note, informational) |

**Conclusion: VERIFY-UNCHANGED. No value edits needed.** The palette was confirmed unchanged in Phase 181 STATE.md: "#c2410c / #fdba74 ratified, no micro-tuning."

### Grep-based parity check (planner should encode as verification step)

```bash
# Confirm brandbook ember-700 = #c2410c
grep '"ember-700"' brandbook/tokens.json | grep -q '#c2410c' && echo "OK: brandbook ember-700=#c2410c" || echo "FAIL"

# Confirm admin CSS --sg-color-brand = #c2410c
grep 'sg-color-brand:' test/example/priv/static/assets/css/app.css | grep -q '#c2410c' && echo "OK: admin sg-color-brand=#c2410c" || echo "FAIL"

# Confirm admin CSS --sg-logo-rail-accent = #fdba74
grep 'sg-logo-rail-accent:' test/example/priv/static/assets/css/app.css | grep -q '#fdba74' && echo "OK: admin rail-accent=#fdba74" || echo "FAIL"

# Confirm auth CSS default accent = #c2410c
grep 'sigra-auth-light-accent' priv/templates/sigra.install/core/sigra_auth.css | grep -q '#c2410c' && echo "OK: auth accent=#c2410c" || echo "FAIL"
```

All four should pass with no file edits. If any fail, a token divergence was introduced somewhere between Phase 182 and now (would be surprising given palette is unchanged).

---

## Unknown 5: Full Gate Sequence and mix test Scope

### Recommended execution order

```
Phase 183 gate sequence:
1. Produce D4 admin lockup SVGs (viewBox reframe of brandbook paths)
2. Write installer templates: priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg
3. Copy to example: test/example/priv/static/images/sigra-logo-primary{,-dark}.svg
   (byte-identical to installer — verify with cmp)
4. Produce D4 companion marks (logo-mark.svg geometry, explicit fills, no CSS media query)
5. Write: test/example/priv/static/images/rail-accent-mark{,-dark}.svg
6. Update 2 test files (4 lines total):
   - test/example/test/example_web/admin_shell_test.exs lines 79-80
   - test/sigra/install/features/admin_test.exs lines 252-253
7. Verify token parity (4 greps — should all pass with no edits)
8. Run: mix test (from repo root) — covers test/sigra/install/features/admin_test.exs
9. Run: cd test/example && mix test — covers example_web/admin_shell_test.exs
10. Verify byte-identical: cmp priv/templates/.../sigra-logo-primary.svg test/example/.../sigra-logo-primary.svg
11. Update snapshot-allowlist (add 3 missing slugs to existing 4)
12. Pre-compile example app: cd test/example && mix compile
13. Boot example dev server on port 4011
14. Run --update-snapshots=all on all 3 Playwright projects
15. git checkout -- the 3 impersonation-banner PNGs (restore canary)
16. Kill dev server
17. Run snapshot-recapture-gate.sh with all 7 non-canary slugs
18. Reset snapshot-allowlist to empty (comments only)
19. Hygiene sweep (SVG parseability, binary check, brandbook size)
20. Final: mix test (root) + cd test/example && mix test — confirm still green
21. git status -- confirm clean
```

### mix test scope clarification

| Command | Covers | Phase 183 relevance |
|---------|--------|-------------------|
| `mix test` (from repo root) | `test/sigra/**_test.exs` including `test/sigra/install/features/admin_test.exs` | YES — updates installer logo + test assertions |
| `cd test/example && mix test` | `test/example/test/**_test.exs` including `admin_shell_test.exs` | YES — updates example logo + test assertions |
| Playwright `snapshot-recapture-gate.sh` | `admin-checkpoints.spec.ts` × 3 projects + ExUnit goldens | YES — baseline recapture |

Both `mix test` and `cd test/example && mix test` require Postgres at localhost:5432 (postgres/postgres). Use `SIGRA_TEST_PG_*` env vars to override if credentials differ.

### Estimated runtime

| Step | Estimated time |
|------|---------------|
| SVG authoring (4 lockups + 2 marks) | 10–15 min |
| Test assertion edits (4 lines) | 2 min |
| `mix test` (root) | ~2–3 min |
| `cd test/example && mix test` | ~3–5 min |
| Pre-compile + server boot | ~2 min |
| Playwright `--update-snapshots=all` (3 projects) | ~5–8 min |
| `snapshot-recapture-gate.sh` (compare run) | ~3–5 min |
| Hygiene sweep + git cleanup | ~5 min |
| **Total** | **~35–45 min** |

---

## Standard Stack

No new library dependencies in Phase 183. Pure file editing and test execution.

| Tool | Purpose | Notes |
|------|---------|-------|
| SVG editor / text editor | Produce admin lockup files | Pure viewBox reframe — no script needed |
| `mix test` | Run ExUnit suite | Requires Postgres at localhost:5432 |
| `npx playwright test --update-snapshots=all` | Recapture baselines | Run from `test/example/priv/playwright/` |
| `scripts/ci/snapshot-recapture-gate.sh` | Approval gate | 7 slugs as arguments |
| `cmp` | Byte-identical verification | Installer == example lockup files |

---

## Package Legitimacy Audit

No packages are installed in Phase 183. Section not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
brandbook/logo-primary{,-dark}.svg
  (D4 full lockup, viewBox="0 220 2410 1026")
         |
         | viewBox reframe only (no path changes)
         v
admin-lockup-d4.svg production
  viewBox="20 220 2361 1000"
  paths verbatim, fills adjusted for light/dark
         |
    +----|------------------------------+
    |    |                             |
    v    v                             v
priv/templates/sigra.install/    test/example/priv/static/images/
  admin/sigra-logo-primary.svg     sigra-logo-primary.svg
  admin/sigra-logo-primary-dark.svg  sigra-logo-primary-dark.svg
    (installer source of truth)        (mirror — byte-identical)
         |
         | cmp verifies byte-identical
         v
ExUnit assertions (4 files × 2 assertions)
  → viewBox="20 220 2361 1000"
  → "Space Grotesk v2.0"

brandbook/logo-mark.svg
  (D4 abstract mark, CSS auto dark)
         |
         | Extract geometry, remove CSS, explicit fills
         v
test/example/priv/static/images/
  rail-accent-mark.svg      (light fills)
  rail-accent-mark-dark.svg (dark fills)
         |
         | filename asserted in demo-showcase.spec.ts
         | (content NOT asserted)
         v
Demo branding profiles (no test changes needed)
```

### Project file changes

```
priv/templates/sigra.install/admin/
├── sigra-logo-primary.svg         (REPLACE — D4 admin lockup, light)
└── sigra-logo-primary-dark.svg    (REPLACE — D4 admin lockup, dark)

test/example/priv/static/images/
├── sigra-logo-primary.svg         (REPLACE — byte-identical to installer)
├── sigra-logo-primary-dark.svg    (REPLACE — byte-identical to installer)
├── rail-accent-mark.svg           (REPLACE — D4 abstract mark, light)
└── rail-accent-mark-dark.svg      (REPLACE — D4 abstract mark, dark)

test/example/test/example_web/
└── admin_shell_test.exs           (UPDATE — 2 assertion strings, lines 79-80)

test/sigra/install/features/
└── admin_test.exs                 (UPDATE — 2 assertion strings, lines 252-253)

test/example/priv/playwright/
├── snapshot-allowlist             (UPDATE before recapture; RESET to empty after)
└── tests/admin-checkpoints.spec.ts-snapshots/
    └── *.png                      (RECAPTURE — 21 of 24 changed; 3 canary restored)
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Tight-crop viewBox computation | Custom SVG transform script | Pure `viewBox` attribute edit — SVG browsers scale-to-fit |
| Dark mode variant | CSS media queries in single file | Two explicit SVG files with hardcoded fills (matching current pattern) |
| Playwright approval | Human HTML report review | `scripts/ci/snapshot-recapture-gate.sh` (already built) |
| Binary detection in hygiene | Custom file type scanner | `git diff --name-only --diff-filter=A HEAD -- ':!test/example/priv/playwright/**/*.png'` piped to `file` |

**Key insight:** The most common trap is over-engineering the SVG production. The D4 admin lockup is a 3-attribute edit of the brandbook file (viewBox, title text, desc text). No scripting, no Node.js, no font tools needed — the paths are already committed in `brandbook/logo-primary{,-dark}.svg`.

---

## Common Pitfalls

### Pitfall 1: Copying brandbook viewBox instead of cropping
**What goes wrong:** Using `viewBox="0 220 2410 1026"` (brandbook full lockup) produces an SVG with excessive left and right whitespace — the wordmark renders too small in the 54px topbar slot.
**Why it happens:** The brandbook full lockup includes padding for clearspace rules; the admin topbar needs a tight crop.
**How to avoid:** Use `viewBox="20 220 2361 1000"` as computed from path bounds.
**Warning signs:** Rendered logo appears smaller than expected with visible whitespace on left/right.

### Pitfall 2: Forgetting the g-tail descender in the crop
**What goes wrong:** Using a crop that excludes the g-tail extension (e.g., cropping to y=1000 instead of 1200) clips the bottom of the 'g' glyph — the extended rail tail that is the design's signature feature is cut off.
**Why it happens:** The D4 'g' descender extends to y=1200, which is 174 units BELOW what a naive cap-height crop (y ≈ 1026) would include.
**How to avoid:** Ensure `minY + height >= 1220` so bottom is at y=1220 (1200 + 20 margin). The computed viewBox `"20 220 2361 1000"` satisfies this: bottom = 220 + 1000 = 1220. ✓
**Warning signs:** The 'g' appears to have no visible descender or the tail is clipped.

### Pitfall 3: Using --update-snapshots without =all
**What goes wrong:** `--update-snapshots` (bare flag) uses the `changed` preset — it only rewrites baselines whose new render EXCEEDS the tolerance threshold. The logo change may be within tolerance for some slugs (e.g., small logo in corner of a complex page), resulting in stale baselines that show the old v1 logo.
**Why it happens:** Playwright's default `--update-snapshots=changed` is designed for minor rendering differences, not deliberate content swaps.
**How to avoid:** Always use `--update-snapshots=all` for a deliberate full logo replacement.
**Warning signs:** Gate compare run passes but some baselines still show the old staggered-bars mark.

### Pitfall 4: Forgetting to restore the impersonation-banner canary
**What goes wrong:** After `--update-snapshots=all`, ALL 24 PNGs are rewritten including the 3 impersonation-banner PNGs. If not restored, the canary guard fails with "canary snapshot changed: 'impersonation-banner' must stay byte-green."
**Why it happens:** `--update-snapshots=all` is unconditional.
**How to avoid:** Immediately after the update run, `git checkout --` the 3 impersonation-banner PNGs before running the gate.
**Warning signs:** `snapshot-recapture-gate.sh` fails at step (b) with canary failure message.

### Pitfall 5: Running mix test while the example dev server is running
**What goes wrong:** `mix test` from the repo root recompiles the `sigra` library dep, invalidating the running example server's module cache → code-reload crash on next request → subsequent Playwright requests get `ERR_CONNECTION_REFUSED`.
**Why it happens:** Phoenix `code_reloader: true` in dev means a recompile event terminates the running beam process.
**How to avoid:** Always kill the dev server before running `mix test`. Restart and pre-compile cleanly before the Playwright pass.

### Pitfall 6: Adding impersonation-banner to the snapshot allowlist
**What goes wrong:** The canary guard immediately fails because the canary is a special case: it must NEVER appear in the allowlist. The guard has a hard-coded check that fails if the canary appears.
**Why it happens:** Easy mistake when adding "all slugs" to the allowlist.
**How to avoid:** The allowlist for Phase 183 must contain exactly 7 slugs: all non-canary admin-checkpoints slugs. Never add `impersonation-banner`.

---

## Runtime State Inventory

No rename/migration phase. Section not applicable. [SKIPPED — greenfield propagation, no string rename]

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Root test config | `test/test_helper.exs` |
| Example test config | `test/example/test/test_helper.exs` |
| Quick run command | `mix test test/sigra/install/features/admin_test.exs` |
| Full suite command | `mix test` (root) + `cd test/example && mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BRAND2-11 | Installer templates are D4 cropped path-only lockups | unit | `mix test test/sigra/install/features/admin_test.exs -k "cropped"` | ✅ (assertion update needed) |
| BRAND2-11 | Example app ships D4 cropped lockup assets | unit | `cd test/example && mix test test/example_web/admin_shell_test.exs -k "cropped"` | ✅ (assertion update needed) |
| BRAND2-11 | Installer == example SVG files byte-identical | smoke | `cmp priv/templates/sigra.install/admin/sigra-logo-primary.svg test/example/priv/static/images/sigra-logo-primary.svg` | n/a (command) |
| BRAND2-12 | sg-* token hex values unchanged | smoke | grep-based parity check (4 greps, see Unknown 4) | n/a (greps) |
| BRAND2-13 | Admin Playwright baselines reflect D4 logo | visual | `scripts/ci/snapshot-recapture-gate.sh audit-explorer global-overview global-user-index org-overview org-scoped-admin user-audit user-detail` | ✅ scripts exist |
| BRAND2-13 | Snapshot canary (impersonation-banner) unchanged | guard | included in snapshot-recapture-gate.sh step (b) | ✅ |
| BRAND2-13 | snapshot-allowlist returned to empty steady state | hygiene | `grep -v '^#' snapshot-allowlist \| grep -v '^$' \| wc -l` → must be 0 | n/a (grep) |
| BRAND2-14 | Admin SVGs parse as valid XML | smoke | `xmllint --noout <files>` for all 4 lockup SVGs | n/a (command) |
| BRAND2-14 | No stray binary files committed | smoke | `git diff --name-only --diff-filter=A HEAD -- ':!test/example/priv/playwright/**' \| xargs file \| grep -i binary` | n/a (command) |
| BRAND2-14 | mix test exits 0 | unit | `mix test` (root) | ✅ |
| BRAND2-14 | example mix test exits 0 | unit | `cd test/example && mix test` | ✅ |
| BRAND2-14 | git status clean | hygiene | `git status --short \| grep -v '.png'` → must be empty | n/a (command) |

### Wave 0 Gaps

None — existing test infrastructure covers all phase requirements. No new test files needed.

### Machine-verifiable checks (VALIDATION.md pattern)

```bash
# 1. Installer byte-identical to example (both light and dark)
cmp priv/templates/sigra.install/admin/sigra-logo-primary.svg \
    test/example/priv/static/images/sigra-logo-primary.svg && echo "OK: light identical"
cmp priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg \
    test/example/priv/static/images/sigra-logo-primary-dark.svg && echo "OK: dark identical"

# 2. Admin lockups are D4 crop (viewBox and provenance)
for f in priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg; do
  grep -q 'viewBox="20 220 2361 1000"' "$f" && echo "OK: $f viewBox" || echo "FAIL: $f viewBox"
  grep -q 'Space Grotesk v2.0' "$f" && echo "OK: $f provenance" || echo "FAIL: $f provenance"
  grep -q '<path' "$f" && echo "OK: $f has path" || echo "FAIL: $f no path"
  grep -qv '<text' "$f" && echo "OK: $f no text" || echo "FAIL: $f has text"
  grep -qv 'font-family' "$f" && echo "OK: $f no font-family" || echo "FAIL: $f has font-family"
done

# 3. Token parity (4 greps)
grep -q '"ember-700".*"#c2410c"' brandbook/tokens.json && echo "OK: brandbook ember-700"
grep 'sg-color-brand:' test/example/priv/static/assets/css/app.css | grep -q '#c2410c' && echo "OK: sg-color-brand"
grep 'sg-logo-rail-accent:' test/example/priv/static/assets/css/app.css | grep -q '#fdba74' && echo "OK: sg-logo-rail-accent"
grep 'sigra-auth-light-accent' priv/templates/sigra.install/core/sigra_auth.css | grep -q '#c2410c' && echo "OK: auth accent"

# 4. SVG parseability (xmllint)
for f in priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg \
          test/example/priv/static/images/sigra-logo-primary{,-dark}.svg \
          test/example/priv/static/images/rail-accent-mark{,-dark}.svg; do
  xmllint --noout "$f" 2>/dev/null && echo "OK: $f parses" || echo "FAIL: $f"
done

# 5. No stray binary files (outside Playwright baseline dir)
STRAY=$(git diff --name-only --diff-filter=A HEAD \
  -- ':!test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/*.png' \
  | xargs -I{} file {} 2>/dev/null | grep -i binary | wc -l)
[ "$STRAY" -eq 0 ] && echo "OK: no stray binaries" || echo "FAIL: $STRAY stray binary files"

# 6. Snapshot allowlist empty (steady state)
ACTIVE=$(grep -v '^#' test/example/priv/playwright/snapshot-allowlist | grep -v '^$' | wc -l)
[ "$ACTIVE" -eq 0 ] && echo "OK: allowlist empty" || echo "FAIL: allowlist has $ACTIVE active slugs"

# 7. mix test green
mix test && echo "OK: mix test"
( cd test/example && mix test ) && echo "OK: example mix test"

# 8. git status clean
DIRTY=$(git status --short | wc -l)
[ "$DIRTY" -eq 0 ] && echo "OK: git clean" || echo "FAIL: $DIRTY uncommitted files"
```

---

## Security Domain

Section not applicable to Phase 183 (no auth code changes, no new endpoints, no cryptographic operations). This phase modifies only static SVG assets, test assertions, and Playwright baselines.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Postgres 5432 | mix test (root + example) | ✓ | Scout-confirmed at localhost:5432 | — |
| Node.js + npx | Playwright recapture | Check: `node --version` | n/a | `npm ci` in playwright dir |
| xmllint | SVG parseability check | Check: `xmllint --version` | n/a | `python3 -c "import xml.etree.ElementTree; xml.etree.ElementTree.parse('file.svg')"` |
| Port 4011 | Example dev server | Not held (4000 is Rulestead) | n/a | Use any alt port, set SIGRA_EXAMPLE_URL |

---

## Open Questions (RESOLVED)

1. **What is the exact tight-crop viewBox for the D4 admin lockup?**
   - **RESOLVED:** `"20 220 2361 1000"` — computed from D4 path bounds (leftmost S at x=42, rightmost a at x=2361, rail-tittle top at y=246 within frame, g-tail bottom at y=1200 within frame). Full derivation in Unknown 1.

2. **What provenance substring should the new test assertion check?**
   - **RESOLVED:** `"Space Grotesk v2.0"` — this substring appears in the `<desc>` of both brandbook D4 SVGs. The admin lockup `<desc>` must also contain this substring. The test checks for substring containment so the full desc text can be admin-specific as long as it includes this substring.

3. **Does the impersonation-banner canary get affected by the logo change?**
   - **RESOLVED:** NO. The impersonation-banner snapshot captures `/organizations/:slug/members` — the regular org members page, not an admin page. The sigra admin shell logo is only rendered at `/admin/*` routes. The canary stays byte-identical and MUST NOT be in the allowlist.

4. **Does the snapshot-allowlist need all 7 slugs or just the 3 missing ones?**
   - **RESOLVED:** The allowlist already has 4 slugs (global-overview, org-overview, user-audit, user-detail) from a prior phase. Phase 183 must add the 3 missing ones (audit-explorer, global-user-index, org-scoped-admin). After gate passes, reset ALL 7 to empty.

5. **Do the rail-accent-mark files need content updates?**
   - **RESOLVED:** YES — the v1 Rail Accent staggered-bars mark has been superseded by the D4 abstract rail glyph. Content-swap under same filenames. No test assertions check the file content (only the src attribute is checked). No reference churn needed.

6. **Should the D4 admin lockup SVG carry the Playwright `captureAndVerify` ID attributes (g-0, g-1, etc.)?**
   - **RESOLVED:** No specific requirement — the `captureAndVerify` function in admin-checkpoints.spec.ts takes a screenshot, it does not inspect SVG element IDs. Keeping the `id="glyphs"` and `id="rail-tittle"` from brandbook is fine; stripping them is also fine. Keep them for provenance traceability.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | g-2 path leftmost x coordinate is x=557 (from `L557 1200`) | Unknown 1 viewBox derivation | ViewBox might clip left edge of g-tail; add more left margin if visual inspection shows clipping |
| A2 | Bezier curves in g-0 (S glyph) don't extend further left than x=42 anchor | Unknown 1 viewBox derivation | S left edge could be slightly clipped; minimal risk given 22-unit left margin |
| A3 | The impersonation-banner page (/organizations/:slug/members) does not render the admin shell topbar | Unknown 3 canary analysis | If wrong, changing the admin logo WOULD affect the canary and Phase 183 cannot use impersonation-banner as a canary — would need to choose a different canary slug |

---

## Sources

### Primary (HIGH confidence)
- Live repo files read directly: `brandbook/logo-primary{,-dark}.svg`, `brandbook/logo-mark.svg`, `priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg`, both test files, `scripts/ci/snapshot-recapture-gate.sh`, `scripts/ci/snapshot-canary-guard.sh`, `test/example/priv/playwright/snapshot-allowlist`, `test/example/priv/playwright/playwright.config.ts`, `test/example/priv/static/assets/css/app.css`, `priv/templates/sigra.install/core/sigra_auth.css`, `brandbook/tokens.json`
- `183-CONTEXT.md` — phase decisions and central reality
- `.planning/STATE.md` — Phase 181/182 outcomes, palette confirmation
- `181-VERIFICATION.md` — D4 geometry spot-checks and path bounds confirmation
- `.claude/projects/.../memory/reference_admin_checkpoint_playwright.md` — Playwright recapture procedure
- `.claude/projects/.../memory/reference_admin_baseline_auto_gate.md` — Canary guard details

### Secondary (MEDIUM confidence)
- Computed viewBox `"20 220 2361 1000"` — derived from path coordinate analysis; planner should visually verify at 54px render height before committing

---

## Metadata

**Confidence breakdown:**
- D4 admin lockup derivation recipe: HIGH — path data read directly from brandbook SVGs; viewBox computed from anchor coordinates
- Test assertion changes: HIGH — current assertions read from live test files; new assertions derived from brandbook SVG desc content
- Playwright recapture mechanics: HIGH — scripts read directly; procedure cross-checked with memory references
- Token parity: HIGH — hex values grepped directly from live CSS and tokens.json
- Companion mark recipe: MEDIUM — D4 logo-mark.svg geometry read; explicit fill extraction is straightforward but not battle-tested in this session

**Research date:** 2026-06-13
**Valid until:** 2026-07-13 (30 days; stable domain)
