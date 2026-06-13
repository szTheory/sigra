# Phase 183: Propagation, Parity + Verification — Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 8 new/modified files + 1 process artifact (snapshot-allowlist)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/templates/sigra.install/admin/sigra-logo-primary.svg` | static-asset (SVG) | file-I/O | `brandbook/logo-primary.svg` (D4 path geometry) + current installer SVG (header/title/desc structure) | exact (viewBox reframe only) |
| `priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg` | static-asset (SVG) | file-I/O | `brandbook/logo-primary-dark.svg` + current installer dark SVG | exact (viewBox reframe only) |
| `test/example/priv/static/images/sigra-logo-primary.svg` | static-asset (SVG) | file-I/O | installer template `priv/templates/sigra.install/admin/sigra-logo-primary.svg` | exact (byte-identical copy) |
| `test/example/priv/static/images/sigra-logo-primary-dark.svg` | static-asset (SVG) | file-I/O | installer template `priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg` | exact (byte-identical copy) |
| `test/example/priv/static/images/rail-accent-mark.svg` | static-asset (SVG) | file-I/O | `brandbook/logo-mark.svg` (geometry) + current `rail-accent-mark.svg` (file structure) | role-match (content swap, CSS removed, explicit fills) |
| `test/example/priv/static/images/rail-accent-mark-dark.svg` | static-asset (SVG) | file-I/O | `brandbook/logo-mark.svg` (geometry) + current `rail-accent-mark-dark.svg` (file structure) | role-match (content swap, explicit dark fills) |
| `test/example/test/example_web/admin_shell_test.exs` | test | request-response | self (current file, lines 79–80 only change) | exact (2-line string update) |
| `test/sigra/install/features/admin_test.exs` | test | file-I/O | self (current file, lines 252–253 only change) | exact (2-line string update) |
| `test/example/priv/playwright/snapshot-allowlist` | config | batch | self (current file — add 3 slugs pre-recapture, reset to empty post-gate) | exact |

---

## Pattern Assignments

### `priv/templates/sigra.install/admin/sigra-logo-primary.svg` (static-asset SVG, file-I/O)

**Primary analog (path geometry):** `brandbook/logo-primary.svg`
**Secondary analog (outer structure/title/desc convention):** current `priv/templates/sigra.install/admin/sigra-logo-primary.svg` (v1, being replaced)

**Current installer SVG header/title/desc structure** (lines 1–11 of v1 file):
```xml
<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="20 12 188 54"
  role="img"
  aria-labelledby="title desc"
>
  <title id="title">Sigra primary logo</title>
  <desc id="desc">
    The Sigra Rail Accent tight lockup for light surfaces. Wordmark outlined
    from Inter Display Black v4.1.
  </desc>
```

**D4 brandbook full-lockup SVG structure** (lines 1–3 of `brandbook/logo-primary.svg`):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 220 2410 1026" role="img" aria-labelledby="title desc">
  <title id="title">Sigra primary logo</title>
  <desc id="desc">The Sigra D4 Linked Rail typemark for light surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0. Ember-700 (#c2410c) rail tittle and g-tail bracket. See brandbook/README.md for usage rules.</desc>
```

**D4 brandbook path body — light fills** (lines 4–11 of `brandbook/logo-primary.svg`):
```xml
  <g id="glyphs" fill="#151515">
    <path id="g-0" d="M276 1014Q179 1014 117 972Q55 930 42 852L158 822Q...276 1014" />
    <path id="g-1" d="M720 1000L594 1000L594 504L720 504L720 1000" />
    <path id="g-2" d="M836 754L836 738Q...1098 892" />
    <path id="g-3" d="M1624 1000L1498 1000L1498 504L1622 504L1622 560L...1624 718" />
    <path id="g-4" d="M2029 1014Q...2051 912" />
  </g>
  <rect id="rail-tittle" x="557" y="246" width="200" height="200" fill="#c2410c" />
```

**What diverges in the admin lockup (the 3-attribute edit):**

| Attribute | Brandbook value | Admin lockup value | Reason |
|-----------|----------------|-------------------|--------|
| `viewBox` | `"0 220 2410 1026"` | `"20 220 2361 1000"` | Tight crop: margin 20 left, cut right padding, descender-inclusive bottom at y=1220 |
| `<title>` text | "Sigra primary logo" | "Sigra primary logo" | Same — no change needed |
| `<desc>` text | full brandbook provenance with "See brandbook/README.md" | Admin-specific: must contain substring `"Space Grotesk v2.0"` | Test asserts this substring; strip brandbook-internal notes |

**Required desc for the admin light lockup:**
```xml
  <desc id="desc">
    The Sigra D4 Linked Rail tight lockup for light surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0.
  </desc>
```

**Path data and `<rect id="rail-tittle">` are copied verbatim from `brandbook/logo-primary.svg`. No path edits.**

**SVG outer element attributes to preserve from v1 installer:**
- `role="img"` — accessibility role
- `aria-labelledby="title desc"` — accessibility reference
- Attribute order: `xmlns`, `viewBox`, `role`, `aria-labelledby` (can follow brandbook's single-line style or v1's multi-line style — either is valid XML)

---

### `priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg` (static-asset SVG, file-I/O)

**Primary analog:** `brandbook/logo-primary-dark.svg`
**Secondary analog:** current `priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg` (v1)

**D4 brandbook dark SVG structure** (lines 1–3 of `brandbook/logo-primary-dark.svg`):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 220 2410 1026" role="img" aria-labelledby="title desc">
  <title id="title">Sigra primary logo for dark surfaces</title>
  <desc id="desc">The Sigra D4 Linked Rail typemark for dark surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0. Ember-300 (#fdba74) rail tittle on dark. See brandbook/README.md for usage rules.</desc>
```

**What diverges from brandbook in the admin dark lockup:**

| Attribute | Brandbook value | Admin lockup value |
|-----------|----------------|-------------------|
| `viewBox` | `"0 220 2410 1026"` | `"20 220 2361 1000"` |
| `<title>` text | "Sigra primary logo for dark surfaces" | "Sigra primary logo for dark surfaces" (same) |
| `<desc>` text | full brandbook provenance | Must contain `"Space Grotesk v2.0"` |
| `<g id="glyphs">` fill | `#f4f1eb` | `#f4f1eb` (same) |
| `<rect id="rail-tittle">` fill | `#fdba74` | `#fdba74` (same) |

**Required desc for the admin dark lockup:**
```xml
  <desc id="desc">
    The Sigra D4 Linked Rail tight lockup with a light wordmark for dark surfaces. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0.
  </desc>
```

**Path data is byte-identical to `brandbook/logo-primary-dark.svg` lines 5–11.**

---

### `test/example/priv/static/images/sigra-logo-primary.svg` + `sigra-logo-primary-dark.svg` (static-asset, file-I/O)

**Analog:** The installer templates they mirror. These files are byte-identical copies of the installer templates. After authoring the installer templates, copy them with:

```bash
cp priv/templates/sigra.install/admin/sigra-logo-primary.svg \
   test/example/priv/static/images/sigra-logo-primary.svg
cp priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg \
   test/example/priv/static/images/sigra-logo-primary-dark.svg
```

Verify byte-identity with:
```bash
cmp priv/templates/sigra.install/admin/sigra-logo-primary.svg \
    test/example/priv/static/images/sigra-logo-primary.svg && echo "OK: light identical"
cmp priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg \
    test/example/priv/static/images/sigra-logo-primary-dark.svg && echo "OK: dark identical"
```

No independent editing of the example files — the installer is the source of truth.

---

### `test/example/priv/static/images/rail-accent-mark.svg` (static-asset SVG, file-I/O)

**Primary analog (geometry):** `brandbook/logo-mark.svg`
**Secondary analog (file structure):** current `test/example/priv/static/images/rail-accent-mark.svg` (v1, being replaced)

**Current v1 rail-accent-mark.svg structure** (full file):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-labelledby="rail-accent-mark-title rail-accent-mark-desc">
  <title id="rail-accent-mark-title">Rail Accent</title>
  <desc id="rail-accent-mark-desc">A Rail Accent mark showing visible host-code rails and a patchable core line.</desc>
  <path d="M17 14v14M32 23v18M47 36v14" fill="none" stroke="#fdba74" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 36v14M47 14v14" fill="none" stroke="#c2410c" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 32h30" fill="none" stroke="#9a3412" stroke-width="4" stroke-linecap="round"/>
</svg>
```

**D4 brandbook logo-mark.svg** (full file — geometry source):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-70 -60 1040 1040" role="img" aria-labelledby="title desc">
  <title id="title">Sigra mark</title>
  <desc id="desc">Sigra D4 Linked Rail free-standing mark. Abstract rail glyph: ink stem, leftward foot, ember-700 (#c2410c) rail block on light; ember-300 (#fdba74) on dark via prefers-color-scheme. Use as UI accent on any surface. Font: Space Grotesk v2.0 (OFL) wght=700, outlined with opentype.js 2.0.0.</desc>
  <style>#glyphs { fill: #151515; } #rail-block { fill: #c2410c; } @media (prefers-color-scheme: dark) { #glyphs { fill: #f4f1eb; } #rail-block { fill: #fdba74; } }</style>
  <g id="glyphs">
    <rect x="540" y="360" width="180" height="580" />
    <rect x="180" y="760" width="540" height="180" />
  </g>
  <rect id="rail-block" x="400" y="-20" width="320" height="320" />
</svg>
```

**What changes: light variant derivation from brandbook/logo-mark.svg:**
- **Remove** the `<style>` block entirely (no CSS media query — companion marks use explicit fills)
- **Add** `fill="#151515"` attribute to `<g id="glyphs">` directly
- **Add** `fill="#c2410c"` attribute to `<rect id="rail-block">` directly
- **Preserve** `viewBox="-70 -60 1040 1040"`, `role="img"`, `aria-labelledby`
- **Update** `<title>` and `<desc>` id attributes to use scoped IDs (companion marks use `rail-accent-mark-title` / `rail-accent-mark-desc` pattern from v1)
- **Keep** the three geometry elements verbatim: `<g id="glyphs">` with two rects, `<rect id="rail-block">`

**Light fills:**
| Element | Fill |
|---------|------|
| `<g id="glyphs">` | `fill="#151515"` |
| `<rect id="rail-block">` | `fill="#c2410c"` (ember-700) |

---

### `test/example/priv/static/images/rail-accent-mark-dark.svg` (static-asset SVG, file-I/O)

**Analog:** Same as light variant but with dark fills. Current v1 dark file:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-labelledby="rail-accent-mark-dark-title rail-accent-mark-dark-desc">
  <title id="rail-accent-mark-dark-title">Rail Accent</title>
  <desc id="rail-accent-mark-dark-desc">A Rail Accent mark tuned for dark surfaces.</desc>
  <path d="M17 14v14M32 23v18M47 36v14" fill="none" stroke="#fdba74" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 36v14M47 14v14" fill="none" stroke="#f97316" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 32h30" fill="none" stroke="#f4f1eb" stroke-width="4" stroke-linecap="round"/>
</svg>
```

**Dark fills for D4 companion mark:**
| Element | Fill |
|---------|------|
| `<g id="glyphs">` | `fill="#f4f1eb"` |
| `<rect id="rail-block">` | `fill="#fdba74"` (ember-300) |

Use scoped IDs `rail-accent-mark-dark-title` / `rail-accent-mark-dark-desc` matching the v1 naming pattern (no test asserts these IDs, but maintaining the convention is good practice).

**Geometry rects are identical to the light variant** — only fills change.

---

### `test/example/test/example_web/admin_shell_test.exs` (test, request-response)

**Analog:** Self — only 2 lines change within the `"ships cropped path-only Sigra lockup assets"` test.

**Current assertion block** (`test/example/test/example_web/admin_shell_test.exs`, lines 79–84):
```elixir
assert source =~ ~s(viewBox="20 12 188 54")
assert source =~ "Inter Display Black v4.1."
assert source =~ "<path"
refute source =~ "<text"
refute source =~ "font-family"
```

**New assertion block after Phase 183 (lines 79–84):**
```elixir
assert source =~ ~s(viewBox="20 220 2361 1000")
assert source =~ "Space Grotesk v2.0"
assert source =~ "<path"
refute source =~ "<text"
refute source =~ "font-family"
```

**Lines that change:** 79 and 80 only. Lines 81–84 are unchanged.

**Full test context** for orientation (lines 72–85):
```elixir
test "ships cropped path-only Sigra lockup assets" do
  for path <- [
        "priv/static/images/sigra-logo-primary.svg",
        "priv/static/images/sigra-logo-primary-dark.svg"
      ] do
    source = File.read!(path)

    assert source =~ ~s(viewBox="20 220 2361 1000")   # WAS: ~s(viewBox="20 12 188 54")
    assert source =~ "Space Grotesk v2.0"              # WAS: "Inter Display Black v4.1."
    assert source =~ "<path"
    refute source =~ "<text"
    refute source =~ "font-family"
  end
end
```

---

### `test/sigra/install/features/admin_test.exs` (test, file-I/O)

**Analog:** Self — only 2 lines change within the `"admin logo templates are cropped path-only lockups"` test.

**Current assertion block** (`test/sigra/install/features/admin_test.exs`, lines 252–257):
```elixir
assert source =~ ~s(viewBox="20 12 188 54")
assert source =~ "Inter Display Black v4.1."
assert source =~ "<path"
refute source =~ "<text"
refute source =~ "font-family"
```

**New assertion block after Phase 183 (lines 252–257):**
```elixir
assert source =~ ~s(viewBox="20 220 2361 1000")
assert source =~ "Space Grotesk v2.0"
assert source =~ "<path"
refute source =~ "<text"
refute source =~ "font-family"
```

**Lines that change:** 252 and 253 only. Lines 254–257 are unchanged.

**Full test context** for orientation (lines 245–258):
```elixir
test "admin logo templates are cropped path-only lockups" do
  for path <- [
        "priv/templates/sigra.install/admin/sigra-logo-primary.svg",
        "priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg"
      ] do
    source = File.read!(path)

    assert source =~ ~s(viewBox="20 220 2361 1000")   # WAS: ~s(viewBox="20 12 188 54")
    assert source =~ "Space Grotesk v2.0"              # WAS: "Inter Display Black v4.1."
    assert source =~ "<path"
    refute source =~ "<text"
    refute source =~ "font-family"
  end
end
```

---

### `test/example/priv/playwright/snapshot-allowlist` (config, process)

**Analog:** Self — current file with 4 slugs already present.

**Current state** (`test/example/priv/playwright/snapshot-allowlist`, lines 14–17):
```
global-overview
org-overview
user-audit
user-detail
```

**Pre-recapture state (Phase 183 — add 3 missing slugs):**
```
global-overview
org-overview
user-audit
user-detail
audit-explorer
global-user-index
org-scoped-admin
```

**Post-gate steady state (reset to comments-only after `snapshot-recapture-gate.sh` passes):**
```
# (all slug lines removed — file contains only the comment block at lines 1–13)
```

**File header comment block** (lines 1–13, NEVER change this):
```
# Intended-delta snapshot slugs for the admin-checkpoints Playwright baselines.
#
# One slug per line. A slug covers all three projects at once
# (chromium / mobile / dark) — e.g. `user-audit` allows
# user-audit-admin-checkpoints-{chromium,mobile,dark}.png to change.
#
# STEADY STATE: this file is empty (comments only). scripts/ci/snapshot-canary-guard.sh
# fails CI if any baseline PNG changes whose slug is not listed here, so a PR that
# deliberately re-records baselines MUST add the slug(s) in the same diff — making
# the intent reviewable. Reset to empty once the re-recording PR merges.
#
# The `impersonation-banner` canary must NEVER appear here.
#
```

**Slug-to-PNG mapping:** Each slug covers 3 files: `<slug>-admin-checkpoints-chromium.png`, `<slug>-admin-checkpoints-mobile.png`, `<slug>-admin-checkpoints-dark.png`. Location: `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/`.

**Canary rule (hard constraint from `snapshot-canary-guard.sh` line 92):** `impersonation-banner` must NEVER be in the allowlist. The script hard-fails if the canary slug changes.

---

## Shared Patterns

### SVG Accessibility Shell Pattern
**Source:** Current installer SVGs `priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg` (v1)
**Apply to:** All four installer/example admin logo SVGs (D4 versions)

Every admin logo SVG uses this accessibility pattern:
```xml
<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="..."
  role="img"
  aria-labelledby="title desc"
>
  <title id="title">...</title>
  <desc id="desc">...</desc>
  <!-- content -->
</svg>
```

The brandbook SVGs use the same pattern (`role="img" aria-labelledby="title desc"`) — no divergence on the outer shell. Either multi-line attribute style (v1 installer) or single-line (brandbook) is acceptable; match whichever is consistent with adjacent files in the same directory.

### Test Assertion Shape Pattern
**Source:** `test/sigra/install/features/admin_test.exs` lines 252–257 and `test/example/test/example_web/admin_shell_test.exs` lines 79–84
**Apply to:** Both test files in this phase

The structural invariant being tested (4 assertions) must remain exactly this shape — only the string values for assertions 1 and 2 change:
1. `assert source =~ ~s(viewBox="...")` — exact viewBox string
2. `assert source =~ "..."` — font provenance substring
3. `assert source =~ "<path"` — has vector path data (UNCHANGED)
4. `refute source =~ "<text"` — no live text elements (UNCHANGED)
5. `refute source =~ "font-family"` — no font references (UNCHANGED)

### Color Token Parity Pattern (verify-unchanged)
**Source:** `brandbook/tokens.json`, `test/example/priv/static/assets/css/app.css` lines 67–77, `priv/templates/sigra.install/core/sigra_auth.css` line 4
**Apply to:** All token parity verification steps in BRAND2-12

The three-surface parity that must be verified (not changed):

| Token | Value | Location |
|-------|-------|----------|
| `ember-700` | `#c2410c` | `brandbook/tokens.json` |
| `--sg-color-brand` | `#c2410c` | `test/example/priv/static/assets/css/app.css` line 67 |
| `--sg-logo-rail-ember` | `#c2410c` | `test/example/priv/static/assets/css/app.css` line 76 |
| `--sg-logo-rail-accent` | `#fdba74` | `test/example/priv/static/assets/css/app.css` line 75 |
| `--sigra-auth-light-accent` fallback | `#c2410c` | `priv/templates/sigra.install/core/sigra_auth.css` line 4 |

### Playwright Recapture Gate Pattern
**Source:** `scripts/ci/snapshot-recapture-gate.sh` (full file), `scripts/ci/snapshot-canary-guard.sh` (full file)
**Apply to:** BRAND2-13 execution

The gate runs three steps in sequence:
1. `npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark` (compare mode, NOT `--update-snapshots`)
2. `scripts/ci/snapshot-canary-guard.sh --base HEAD --require-all --allow <slug>...` (drift/canary check)
3. `MIX_ENV=test mix test test/sigra/admin/components_test.exs` (ExUnit byte-goldens)

Invocation for Phase 183:
```bash
scripts/ci/snapshot-recapture-gate.sh \
  audit-explorer global-overview global-user-index \
  org-overview org-scoped-admin user-audit user-detail
```

**Critical ordering constraint:** `--update-snapshots=all` pass MUST happen before the gate, and the 3 `impersonation-banner` PNGs MUST be restored via `git checkout --` before running the gate.

---

## Light/Dark Fill Reference Table

| Element | Light SVG | Dark SVG |
|---------|-----------|----------|
| Admin lockup `<g id="glyphs">` fill | `#151515` | `#f4f1eb` |
| Admin lockup `<rect id="rail-tittle">` fill | `#c2410c` | `#fdba74` |
| Companion mark `<g id="glyphs">` fill | `#151515` | `#f4f1eb` |
| Companion mark `<rect id="rail-block">` fill | `#c2410c` | `#fdba74` |

---

## No Analog Found

All files have close analogs. No entries needed in this section.

---

## Key Deviations from CONTEXT.md Assumptions

| Deviation | Detail |
|-----------|--------|
| ROADMAP SC1 "without modification to test expectations" | False premise — tests pin content, not just filenames. Updating exactly 2 lines per test file is the correct minimum churn. Documented in CONTEXT.md as intentional. |
| v1 installer SVG structure | v1 used `<g transform="translate(...)">` for mark + wordmark as two separate groups with pixel-scale coordinates. D4 uses absolute UPM-scale coordinates with no transforms — do NOT add transform attributes to the D4 paths. |
| Companion mark file IDs | Current companion marks use `rail-accent-mark-title`/`rail-accent-mark-desc` as scoped ID prefixes. Preserve this pattern in D4 variants so `aria-labelledby` stays internally consistent. |

---

## Metadata

**Analog search scope:** `priv/templates/sigra.install/admin/`, `test/example/priv/static/images/`, `test/example/test/example_web/`, `test/sigra/install/features/`, `brandbook/`, `scripts/ci/`, `test/example/priv/playwright/`
**Files scanned:** 14 files read directly
**Pattern extraction date:** 2026-06-13
