# Phase 184: Distribution & Parity - Research

**Researched:** 2026-06-14
**Domain:** Installer asset distribution, CSS extraction, byte-parity testing, Playwright styled-host proof
**Confidence:** HIGH — all findings verified directly against the live codebase with file:line citations.

## Summary

Phase 184 extracts the admin `sg-*` design system from `test/example/priv/static/assets/css/app.css`
(3,848 lines / 107,242 bytes) into a canonical installer template `sigra_admin.css`, ships it to
generated hosts via the `admin.ex` `files/1` list, links it in `layouts_admin_injection.ex`, and
enforces two-level byte-parity: template ≡ example (new, stronger guarantee) plus template ≡
install-golden-fixture (existing golden-diff mechanism). The extraction is clean: the three
`@layer sg-*` blocks contain zero `--vt-*` token references in `sg-*` selectors and zero daisyUI
CSS variable references — the VAULTR subsection that lives inside `@layer sg-components` begins
at line 351 and is bounded entirely by `.vt-*` selectors. All decisions are locked (D-01 through
D-11); this research confirms the code-level facts the planner depends on.

**Primary recommendation:** Follow the v1.37 `sigra_auth.css` pattern exactly for DIST-02 and
DIST-03, with the additional DIST-05 example≡template byte-compare added in
`test/sigra/install/features/admin_test.exs` (the natural home given existing `files/1` tests
already live there).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CSS template extraction | Build artifact (priv/templates) | — | Canonical file lives in the library; hosts receive it via installer |
| Installer asset delivery | Library (features/admin.ex files/1) | — | Mirrors sigra_auth.css pattern; `:eex` tuple ships file verbatim |
| Admin layout link injection | Library (layouts_admin_injection.ex) | Host layouts.ex (injection target) | Body-level link follows established Sigra pattern |
| Example canonical consumption | Example app (test/example) | — | Checked-in copy, byte-guarded by new test |
| Byte-parity enforcement | ExUnit (test/sigra/install/) | CI merge gate | Two levels: example≡template + fixture≡template |
| Styled-host proof | Playwright (admin-generated project) | CI (generated_admin_playwright_smoke) | Extends existing spec; no new lane |

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Template at `priv/templates/sigra.install/admin/sigra_admin.css`; carry over: `@layer sg-base, sg-components, sg-overrides;` declaration, "layer order matters" header comment, all `--sg-*` `:root` custom properties, all three `@layer sg-*{}` rule blocks.
- **D-02:** Drop all `--vt-*` `:root` tokens and every `.vt-*` rule (including the "VAULTR HOST APP" subsection inside `@layer sg-components`). After extraction, `app.css` retains only vt-*/Vaultr material.
- **D-03:** MANDATORY D-03 dependency audit: confirm every extracted `sg-*` rule depends only on `var(--sg-*)` tokens. (Research confirms this is clean — see Verification Target 1.)
- **D-04:** Example consumes the canonical file by linking `/assets/sigra_admin.css` from a checked-in `test/example/priv/static/assets/sigra_admin.css` that is byte-guarded identical to the template.
- **D-05:** Example≡template byte-identity is a STRONGER guarantee than the auth precedent. Do not reproduce the stale auth-copy wart.
- **D-06:** DIST-05 = new merge-blocking ExUnit byte-compare (template ≡ example copy) + install-golden fixture registration (fixture ≡ template, existing mechanism).
- **D-07:** DIST-06 = extend the EXISTING `generated_admin_playwright_smoke` job and `admin-generated.spec.ts` with a styled assertion. NOT a new CI lane.
- **D-08:** DIST-02 — add `{:eex, "admin/sigra_admin.css", Path.join(["priv","static","assets","sigra_admin.css"])}` to `lib/sigra/install/features/admin.ex` `files/1`.
- **D-09:** DIST-03 — add `<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />` inside `def admin/1` in `priv/templates/sigra.install/admin/layouts_admin_injection.ex`.
- **D-10:** Canonical paths: template `priv/templates/sigra.install/admin/sigra_admin.css`; host target `priv/static/assets/sigra_admin.css`; example copy `test/example/priv/static/assets/sigra_admin.css`; install-golden fixture `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`.
- **D-11:** Extraction is expected to be a visual no-op for the example; snapshot canary must stay green; cascade-layer load order must be preserved.

### Claude's Discretion
- Exact ExUnit test module/location for the DIST-05 byte-compare.
- Precise selector for the DIST-06 "styled" Playwright assertion.
- Whether the example still needs a thin non-`sg-*` glue block in `app.css` beyond `vt-*`.

### Deferred Ideas (OUT OF SCOPE)
- Retroactively byte-guarding the example `sigra_auth.css` copy against its template (the auth-side wart this phase reveals).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-01 | Extract admin `sg-*` CSS into `priv/templates/sigra.install/admin/sigra_admin.css`; leave `vt-*` in example | Extraction boundary confirmed: VAULTR section starts at app.css:351, all `--vt-*` refs are isolated to `.vt-*` selectors; `@layer sg-*` blocks are clean |
| DIST-02 | Ship via `admin.ex` `files/1` → host `priv/static/assets/sigra_admin.css` | Exact tuple shape confirmed from `core.ex:256`; `admin.ex` `files/1` currently ships no CSS (confirmed) |
| DIST-03 | Generated admin layout links stylesheet via `<link>` in `def admin/1` | `layouts_admin_injection.ex` confirmed to have no link today; injection point is the rendered body content; `sigra_auth_components.ex:27` is the exact pattern to replicate |
| DIST-04 | Example consumes the same canonical CSS; no divergent copy | app.css confirmed to contain all `sg-*` rules today; after extraction, example must link new file and have the copy; the example currently links `app.css` not `sigra_admin.css` |
| DIST-05 | Merge-blocking parity test proves example≡template byte-identity + install-golden fixture registration | Golden-diff mechanism confirmed; `admin_test.exs` is the natural location for the new byte-compare; `core_test.exs:293` pattern for targets assertion update |
| DIST-06 | Freshly generated host renders styled admin UI, proven by existing `generated_admin_playwright_smoke` | CI job confirmed at `ci.yml:952`; `admin-generated.spec.ts` confirmed — currently asserts shell/scope/denial only, no styled assertion; spec extension is the correct mechanism |
</phase_requirements>

## Verification Target 1: Extraction Source (`test/example/priv/static/assets/css/app.css`)

**File:** `test/example/priv/static/assets/css/app.css` — 3,848 lines / 107,242 bytes [VERIFIED: codebase grep]

### Layer declaration and header
- **Line 1–13:** Header comment beginning `/* Vaultr/Sigra demo design layer.` — carries the "layer order matters" rationale.
- **Line 15:** `@layer sg-base, sg-components, sg-overrides;` — the cascade-layer ordering declaration. **Must be carried into `sigra_admin.css`.**

### `:root` token block (lines 20–188)
- **Lines 20–154:** All `--sg-*` custom properties (spacing scale, type scale, color, brand, semantic status, elevation, motion, layout, component sizing). All must be extracted.
- **Lines 156–177:** `--vt-*` token block (`/* Vaultr host-app tokens */`). **Must NOT be extracted.**
- **Lines 179–185:** Trailing `--sg-*` component sizing tokens (`--sg-pill-h`, `--sg-pill-gap`, etc.) — these come after the `--vt-*` block and must be extracted.
- **Line 187:** `color-scheme: light;` — belongs in extracted file (inside `:root`).
- **Line 188:** `:root` closes.

**Landmine:** The `--vt-*` tokens are interleaved within the single `:root {}` block (lines 156–177), not in a separate block. Extraction is a selective copy, not a line-range cut (per D-01). The planner must make this explicit in the task description.

### Dark-mode `:root` block (lines 190–244)
- **Lines 190–224:** `@media (prefers-color-scheme: dark) { :root { --sg-* ... }` — all `--sg-*` dark overrides. Must be extracted.
- **Lines 225–242:** `--vt-*` dark overrides inside the same `@media` block. **Must NOT be extracted.**

**Landmine:** Same interleaving problem in dark-mode block. Selective property extraction required.

### `@layer sg-base` (lines 249–260) — [VERIFIED: codebase grep]
- Contains only `html { ... }` and `:where(a) { ... }` using only `--sg-*` tokens.
- Zero `--vt-*` references. Clean extraction.

### `@layer sg-components` (lines 262–3790) — [VERIFIED: codebase grep]
- Lines 262–349: All `sg-*` component rules. Zero `--vt-*` references confirmed by Python analysis.
- **Lines 351–3789: "VAULTR HOST APP" subsection** — begins at line 351 with comment `/* VAULTR HOST APP — separate fictional app brand, powered by Sigra */`, first selector `.vt-home, .vt-auth, .vt-app-main` at line 354. This entire section is `.vt-*` selectors only. **Must NOT be extracted.**
- The `@layer sg-components {}` block closes at line 3790.

**VAULTR section boundaries:** line 351 (comment) through line 3789 (last rule before closing `}`). The `sg-*` rules live only in lines 262–349.

### `@layer sg-overrides` (lines 3795–3824) — [VERIFIED: codebase grep]
- Small-screen tweaks targeting `sg-*` selectors only. Zero `--vt-*` references confirmed. Clean extraction.

### `prefers-reduced-motion` block (lines 3831–3848)
- Uses `--sg-motion-fast` token only. Must be extracted.

### D-03 Dependency Audit Result — [VERIFIED: Python analysis]

**Finding: All three `@layer sg-*` blocks are clean.**

- `@layer sg-base`: **NO `--vt-*` references** (zero).
- `@layer sg-components` (sg-* selectors only, before VAULTR line 351): **NO `--vt-*` references** (zero).
- `@layer sg-overrides`: **NO `--vt-*` references** (zero).
- **daisyUI CSS vars** (`--b1`, `--bc`, `--p`, etc.): **None found in any `@layer sg-*` block** (zero).

The only `--vt-*` references in `@layer sg-components` are inside `.vt-*` selectors in the VAULTR subsection — which is excluded by D-02. **No residual dependency problem exists.** The D-03 mandatory audit task can verify this with `grep -n "var(--vt-" <extracted_file>` and expect zero matches.

### What stays in `app.css` after extraction
After extraction, `app.css` retains:
- The `--vt-*` `:root` token block (lines 156–177 in light, lines 225–242 in dark)
- The "VAULTR HOST APP" `.vt-*` subsection within `@layer sg-components` (lines 351–3789)
- Any example-specific glue not using `sg-*` tokens

The example still needs `app.css` for its `vt-*` brand — that file shrinks dramatically but is not deleted.

## Verification Target 2: v1.37 Auth Precedent (the pattern to copy)

### `core.ex` `files/1` tuple for `sigra_auth.css` — [VERIFIED: codebase grep]

**File:** `lib/sigra/install/features/core.ex:256` [VERIFIED: codebase grep]

```elixir
{:eex, "core/sigra_auth.css", Path.join(["priv", "static", "assets", "sigra_auth.css"])}
```

**DIST-02 analog for admin:**
```elixir
{:eex, "admin/sigra_admin.css", Path.join(["priv", "static", "assets", "sigra_admin.css"])}
```
This tuple is added to `lib/sigra/install/features/admin.ex` `files/1` (currently ships no CSS).

### `sigra_auth_components.ex` body-level `<link>` — [VERIFIED: codebase grep]

**File:** `priv/templates/sigra.install/core/sigra_auth_components.ex:27` [VERIFIED: codebase grep]

```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_auth.css"} />
```

**DIST-03 analog for admin** (goes inside `def admin/1` in `layouts_admin_injection.ex`):
```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />
```

### `admin.ex` `files/1` current shape — [VERIFIED: codebase grep]

**File:** `lib/sigra/install/features/admin.ex:26–43` [VERIFIED: codebase grep]

Currently ships six files: `admin/policy.ex`, `admin/components/admin_shell.ex`, two SVG logos, `admin/impersonation_controller.ex`, `admin/audit_export_controller.ex`. **No CSS file is currently shipped.** The new tuple for `sigra_admin.css` is appended to this list.

### `layouts_admin_injection.ex` `def admin/1` — [VERIFIED: codebase grep]

**File:** `priv/templates/sigra.install/admin/layouts_admin_injection.ex` [VERIFIED: codebase grep]

Full current content (22 lines):
```heex
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :current_scope, :map, default: nil
  attr :admin_scope, :map, default: nil
  attr :page_title, :string, default: nil
  attr :admin_breadcrumbs, :list, default: nil
  attr :inner_content, :any, default: nil

  def admin(assigns) do
    ~H"""
    <.admin_shell
      admin_scope={@admin_scope}
      current_scope={@current_scope}
      page_title={@page_title}
      admin_breadcrumbs={@admin_breadcrumbs}
    >
      {@inner_content}
    </.admin_shell>

    <.flash_group flash={@flash} />
    """
  end
```

The `<link>` tag goes inside the `~H"""` heredoc, before `<.admin_shell>`. This injection renders body-level content — the host `<head>` is in `root.html.heex` (confirmed at `test/example/lib/example_web/components/layouts/root.html.heex`).

**`root.html.heex` current link order:**
```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/default.css"} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
```
`default.css` loads before `app.css`. After Phase 184, the example links `sigra_admin.css` in the admin layout body (not in `root.html.heex`), so the head order is unchanged for the example. Generated hosts will have `sigra_admin.css` linked in the admin layout body, which is rendered in the document body after the `<head>` has already been parsed. The cascade-layer `@layer sg-base, sg-components, sg-overrides;` declaration inside `sigra_admin.css` ensures `sg-*` outranks daisyUI `default.css` regardless of load position.

**Landmine:** The `@layer` declaration in `sigra_admin.css` establishes its cascade-layer priority within the file's own cascade; the body-vs-head load position does not break layer priority in CSS. No fragility here.

## Verification Target 3: Parity Test Surfaces (DIST-05)

### `golden_diff_test.exs` mechanism — [VERIFIED: codebase grep]

**File:** `test/sigra/install/golden_diff_test.exs` [VERIFIED: codebase grep]

The golden-diff test does a whole-tree byte comparison: it runs the installer against a temp app, collects every generated file, normalizes migration timestamp prefixes (`TIMESTAMP_*`), and asserts byte-identity against the committed `test/fixtures/install_golden/tree/` directory. Any file in the fixture tree but not generated (or vice versa) fails with a clear set-diff message. Any content divergence fails with a Myers-diff excerpt.

**Current fixture for `sigra_auth.css`:**
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css` — 19,379 bytes [VERIFIED: codebase grep]
- This file is byte-identical to `priv/templates/sigra.install/core/sigra_auth.css` (19,379 bytes each) [VERIFIED: codebase grep]
- The example copy `test/example/priv/static/assets/sigra_auth.css` is **12,281 bytes** — stale/divergent. The golden-diff only guards template↔fixture, not template↔example.

**What must be added for DIST-05:**
1. `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — byte-identical copy of the template. The golden-diff will then automatically verify template↔fixture parity on every run.
2. The template itself (`priv/templates/sigra.install/admin/sigra_admin.css`) must exist as a new file.

### `core_test.exs` manifest assertions — [VERIFIED: codebase grep]

**File:** `test/sigra/install/features/core_test.exs`

- **Line 155:** `assert "core/sigra_auth.css" in sources` — asserts `sigra_auth.css` source path in `core.ex` `files/1`.
- **Line 293:** `assert "priv/static/assets/sigra_auth.css" in targets` — asserts the target path.

**Analog for DIST-05 in `admin_test.exs`:**
The new assertion belongs in `test/sigra/install/features/admin_test.exs` (the `files/1` test at line 18). Two assertions:
```elixir
assert {:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"} in files
```
Or, following the `core_test.exs` pattern with separate sources/targets lists. The `admin_test.exs` file currently does not enumerate sources/targets — the planner may choose either the direct tuple assertion (simpler) or the sources/targets pattern (mirrors core).

### `templates_layout_test.exs` file-count assertion — [VERIFIED: codebase grep]

**File:** `test/sigra/install/templates_layout_test.exs:74` [VERIFIED: codebase grep]

```elixir
assert length(core_files) == 52
```

This asserts the count of files in `priv/templates/sigra.install/core/`. The new `sigra_admin.css` goes in `priv/templates/sigra.install/admin/`, not `core/`. **This assertion does NOT need updating.** The test at line 78 asserts no files directly in `@top_dir` (only subdirectories allowed) — also unaffected.

**Conclusion:** `templates_layout_test.exs` requires no changes for Phase 184.

### Recommended module for the DIST-05 example≡template byte-compare

**Recommendation (Claude's Discretion):** Add the byte-compare test to `test/sigra/install/features/admin_test.exs` in a new `describe "DIST-05 example≡template parity"` block. This follows the convention that feature-specific assertions live in `features/admin_test.exs`.

Example shape:
```elixir
describe "DIST-05 example≡template byte-parity (sigra_admin.css)" do
  test "example copy is byte-identical to the installer template" do
    template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
    example  = File.read!("test/example/priv/static/assets/sigra_admin.css")

    assert byte_size(template) == byte_size(example),
           "size mismatch: template #{byte_size(template)}B, example #{byte_size(example)}B — " <>
           "run: cp priv/templates/sigra.install/admin/sigra_admin.css " <>
           "test/example/priv/static/assets/sigra_admin.css"

    assert template == example,
           "content mismatch — example copy has diverged from the installer template"
  end
end
```

This test is merge-blocking (runs in the standard `mix test` suite, no tag exclusion).

## Verification Target 4: Styled-Host Proof (DIST-06)

### `generated_admin_playwright_smoke` CI job — [VERIFIED: codebase grep]

**File:** `.github/workflows/ci.yml:952` [VERIFIED: codebase grep]

Job name: `generated_admin_playwright_smoke`. Runs on `ubuntu-latest`, timeout 60 minutes, PostgreSQL service. Invokes `scripts/ci/admin-acceptance-smoke.sh --test all`.

**Note on `RUN_PARITY=1`:** This flag does NOT currently exist in `admin-acceptance-smoke.sh`. The CONTEXT.md's mention of `RUN_PARITY=1` is a description of the job's intent (parity lane), not an actual env var. The script does not use this variable. The planner should not add or depend on `RUN_PARITY=1` — DIST-06 extends the existing `--test all` target.

### `admin-acceptance-smoke.sh` — [VERIFIED: codebase grep]

**File:** `scripts/ci/admin-acceptance-smoke.sh` [VERIFIED: codebase grep]

The script scaffolds a fresh `phx.new` app, installs Sigra via `mix sigra.install --yes Accounts User users --no-passkeys`, runs `mix compile --warnings-as-errors`, boots the server on port 4017, runs HTTP parity probes, then runs Playwright against `tests/admin-generated.spec.ts`. DIST-02 and DIST-03 ensure the generated host receives `priv/static/assets/sigra_admin.css` and the admin layout links it — DIST-06 then just needs a Playwright assertion that the stylesheet actually applied.

### `admin-generated.spec.ts` current assertions — [VERIFIED: codebase grep]

**File:** `test/example/priv/playwright/tests/admin-generated.spec.ts` [VERIFIED: codebase grep]

Currently asserts:
- Shell renders on desktop and mobile (scope labels, nav presence, checkpoint screenshots)
- Admin denial responses show explicit copy (403/404 status codes + body text)
- Global users index lists users for platform admin
- Bounded enterprise surface renders
- Audit CSV export returns stable columns
- Impersonation start flow works

**No styled assertion exists today.** The generated host currently links no admin CSS (DIST-03 is not yet implemented), so adding a styled assertion now would fail until DIST-02+DIST-03 land.

### Recommended styled assertion (Claude's Discretion)

**Recommendation:** Add a computed-style assertion to the existing `"generated host admin shell renders on desktop and mobile"` test, after the `await page.goto("/admin")` that confirms shell render. The most stable, semantically meaningful signal is checking that the `.sg-admin-topbar` element has a non-transparent background color (proving `sg-components` layer rules applied):

```typescript
// DIST-06: prove sigra_admin.css loaded and sg-* rules applied
const topbar = page.locator('.sg-admin-topbar').first();
await expect(topbar).toBeVisible();
const bgColor = await topbar.evaluate(
  (el) => window.getComputedStyle(el).getPropertyValue('background-color')
);
// sg-admin-topbar has a non-transparent background from sg-* tokens;
// if CSS failed to load, background-color would be rgba(0,0,0,0)
expect(bgColor).not.toBe('rgba(0, 0, 0, 0)');
expect(bgColor).not.toBe('transparent');
```

Alternative (more explicit): assert the `--sg-color-brand` CSS custom property is defined on `html`:
```typescript
const brandColor = await page.evaluate(
  () => getComputedStyle(document.documentElement)
         .getPropertyValue('--sg-color-brand').trim()
);
expect(brandColor).toBe('#c2410c');
```

The CSS-custom-property approach is the most brittle-resistant: it directly proves the `:root` token block from `sigra_admin.css` was parsed, with no dependency on element layout. The `--sg-color-brand` value `#c2410c` is stable (not expected to change in Phase 184).

## Verification Target 5: Snapshot Canary (D-11)

### `snapshot-canary-guard.sh` steady-state — [VERIFIED: codebase grep]

**File:** `scripts/ci/snapshot-canary-guard.sh` [VERIFIED: codebase grep]

The allowlist at `test/example/priv/playwright/snapshot-allowlist` is currently **empty** (comments only). The canary slug is `impersonation-banner`. On an ordinary PR:
- Any PNG under `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` that changed and is not in the allowlist → `FAIL`.
- If the canary slug changed → immediate `FAIL` (hard fail, not counted as a violation).

**For Phase 184:** The extraction is expected to be a visual no-op for the example (same `sg-*` rules, relocated). If the canary stays green, no allowlist entry is needed. If any snapshot drifts (e.g., due to CSS load-order change), the PR must add the slug to the allowlist in the same diff.

### Cascade-layer load order and `root.html.heex` — [VERIFIED: codebase grep]

**File:** `test/example/lib/example_web/components/layouts/root.html.heex` [VERIFIED: codebase grep]

Current `<head>` link order:
```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/default.css"} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
```

After Phase 184, the example admin layout body will include:
```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />
```

**`sg-*` priority is maintained by the `@layer` declaration, not by stylesheet load order.** The `@layer sg-base, sg-components, sg-overrides;` at the top of `sigra_admin.css` establishes cascade-layer priority. CSS cascade layers outrank unlayered styles (daisyUI `default.css` is unlayered), regardless of which `<link>` tag appears first in the document. No load-order fragility exists here.

**What would break the canary:** if any `sg-*` token value changed (no change in Phase 184), or if an `sg-*` selector was accidentally dropped during extraction. The D-03 audit task and the DIST-05 byte-compare both guard against this.

## Architecture Patterns

### v1.37 Auth CSS Distribution Pipeline (the exact template)

```
priv/templates/sigra.install/core/sigra_auth.css
  → core.ex files/1 tuple {:eex, "core/sigra_auth.css", "priv/static/assets/sigra_auth.css"}
  → mix sigra.install → host priv/static/assets/sigra_auth.css
  → sigra_auth_components.ex:27 <link phx-track-static ...>
  → test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css (byte-guarded by golden_diff_test)
  → core_test.exs:155 (source assert) + :293 (target assert)
```

**Phase 184 admin analog (all six steps):**
```
priv/templates/sigra.install/admin/sigra_admin.css  [NEW — DIST-01]
  → admin.ex files/1 tuple {:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"}  [NEW — DIST-02]
  → mix sigra.install → host priv/static/assets/sigra_admin.css  [automatic]
  → layouts_admin_injection.ex def admin/1 <link phx-track-static ...>  [NEW — DIST-03]
  → test/example/priv/static/assets/sigra_admin.css  [NEW — DIST-04, checked in]
  → test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css  [NEW — DIST-05 part 1]
  → admin_test.exs byte-compare test (template ≡ example)  [NEW — DIST-05 part 2]
  → admin-generated.spec.ts styled assertion  [NEW — DIST-06]
```

### Recommended Project Structure (new files)

```
priv/templates/sigra.install/admin/
  ├── sigra_admin.css          [NEW — canonical template]
  └── layouts_admin_injection.ex  [MODIFIED — add <link> tag]

lib/sigra/install/features/
  └── admin.ex                 [MODIFIED — add files/1 tuple]

test/example/priv/static/assets/
  └── sigra_admin.css          [NEW — byte-guarded example copy]

test/fixtures/install_golden/tree/priv/static/assets/
  └── sigra_admin.css          [NEW — byte-guarded fixture copy]

test/sigra/install/features/
  └── admin_test.exs           [MODIFIED — add DIST-05 byte-compare + files/1 assertion]

test/example/priv/playwright/tests/
  └── admin-generated.spec.ts  [MODIFIED — add DIST-06 styled assertion]
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CSS byte-parity | Custom byte comparison logic | `File.read!` + `assert ==` (ExUnit) | Already proven by sigra_auth.css pattern; File.read! returns exact bytes |
| Installer asset delivery | Custom copy mechanism | `:eex` tuple in `files/1` | Proven pattern; handles verbatim copy when no EEX markers present |
| Cascade-layer priority | `!important` overrides | `@layer` declaration at top of CSS file | Already in the file; move it wholesale |
| Styled-host proof | New Playwright project | Extend `admin-generated.spec.ts` | Job already boots a fresh host; adding one assertion is sufficient |

## Common Pitfalls

### Pitfall 1: Contiguous line-range cut
**What goes wrong:** Extracting `app.css` as a single line-range (e.g., "lines 1–350 + 3791–3848") misses that `--vt-*` tokens are interleaved inside the single `:root {}` block (lines 156–177 light, 225–242 dark).
**Why it happens:** It looks like the `--sg-*` tokens are a contiguous block from the top.
**How to avoid:** D-01 is explicit: "selector/token-aware re-section." Extract properties by prefix (`--sg-*`), not by line range.
**Warning signs:** `grep "var(--vt-" sigra_admin.css` returns matches.

### Pitfall 2: Missing trailing `--sg-*` tokens in `:root`
**What goes wrong:** Stopping the `:root` extraction at line 155 (`--sg-measure`) and missing the trailing component-sizing tokens (lines 179–185: `--sg-pill-h`, `--sg-pill-gap`, etc.) that come after the `--vt-*` block.
**Why it happens:** The `--vt-*` block creates a visual break that looks like the end of sg-* tokens.
**How to avoid:** Grep the extracted file for all `--sg-` custom property declarations and compare count against the source.

### Pitfall 3: Forgetting the dark-mode `:root` block
**What goes wrong:** Extracting only the light-mode `:root` block and not the `@media (prefers-color-scheme: dark) { :root { --sg-* } }` dark overrides.
**Why it happens:** The dark-mode block is separate and visually distant from the light-mode `:root`.
**How to avoid:** The dark-mode `sg-*` overrides (lines 190–224) are critical for System theme support. Verify by checking `--sg-color-ink` is defined twice in the extracted file.

### Pitfall 4: Missing `prefers-reduced-motion` block
**What goes wrong:** The `@media (prefers-reduced-motion: reduce)` block at lines 3831–3848 is outside all `@layer sg-*` blocks. It could be missed since it is after the closing `}` of `@layer sg-overrides`.
**Why it happens:** It's at the very end of the file and outside the `@layer` blocks.
**How to avoid:** Include it in the extraction. It uses `--sg-motion-fast` and targets `sg-admin-loading-bar`, so it belongs in `sigra_admin.css`.

### Pitfall 5: Golden-diff fixture requires regeneration
**What goes wrong:** Adding `sigra_admin.css` to `admin.ex` `files/1` causes the golden-diff test to fail because the fixture tree does not yet include `sigra_admin.css`.
**Why it happens:** `golden_diff_test.exs` checks that generated output matches the committed fixture tree. A new shipped file is "extra" output.
**How to avoid:** Add `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (byte-identical to the template) in the same commit. This is a manual copy, not an auto-generated capture.

### Pitfall 6: Admin test assertion for files/1 uses tuple membership test
**What goes wrong:** The existing `admin_test.exs` uses `in files` for tuple membership but may need exact path form — `Path.join(["priv","static","assets","sigra_admin.css"])` evaluates to `"priv/static/assets/sigra_admin.css"` at compile time.
**Why it happens:** `Path.join/1` is evaluated at compile time in test files.
**How to avoid:** Assert the tuple with the string literal: `{:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"}`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Auth CSS was example-only | `sigra_auth.css` shipped via installer (v1.37) | Phase 173-177 | Template → `files/1` → golden-diff pipeline exists and proven |
| Example `sigra_auth.css` is stale divergent copy (12,281 B vs template 19,379 B) | **This wart exists today** — Phase 184 must NOT reproduce it for admin | — | Phase 184 adds example≡template byte-compare to prevent recurrence |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

**If this table is empty:** All claims in this research were verified against the live codebase with file:line citations — no assumed knowledge used.

## Open Questions

1. **Does the `prefers-reduced-motion` block reference `--sg-motion-fast`?**
   - What we know: Line 3840 uses `transition-duration: var(--sg-motion-fast) !important;` — `--sg-motion-fast` is defined in `:root`. The block also targets `.sg-admin-loading-bar`.
   - What's unclear: None — it clearly belongs in the extracted admin CSS.
   - Recommendation: Include in extraction.

2. **Does the example `app.css` need a glue block after extraction?**
   - What we know: The `vt-*` rules use only `--vt-*` tokens (no `--sg-*` deps). The example links both `default.css` and `app.css` in `root.html.heex`. After extraction, `app.css` will contain only `vt-*` material.
   - What's unclear: Whether there are any example-specific non-`sg-*` non-`vt-*` rules that don't belong in either file.
   - Recommendation: Check `app.css` for any rules that are neither `.sg-*` nor `.vt-*` after extraction. The header comment, `@layer` declaration, and `:root` block all need careful handling.

## Environment Availability

Step 2.6: SKIPPED — Phase 184 is a code/CSS file modification phase. No external tools beyond the existing Elixir/Phoenix toolchain are required. The `generated_admin_playwright_smoke` CI job already has all required dependencies (Playwright, phx_new, PostgreSQL) confirmed in the existing CI job at `ci.yml:952`.

## Validation Architecture

> `nyquist_validation: true` in `.planning/config.json` — section REQUIRED.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/sigra/install/features/admin_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DIST-01 | Template file exists at `priv/templates/sigra.install/admin/sigra_admin.css`; contains `@layer sg-base, sg-components, sg-overrides;`; zero `--vt-*` references | unit | `mix test test/sigra/install/features/admin_test.exs -r "template ownership"` + `grep "var(--vt-" priv/templates/sigra.install/admin/sigra_admin.css; echo "exit: $?"` | ❌ Wave 0 (new template + test) |
| DIST-02 | `admin.ex` `files/1` includes `{:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"}` | unit | `mix test test/sigra/install/features/admin_test.exs -r "files/1"` | ❌ Wave 0 (new assertion) |
| DIST-03 | `layouts_admin_injection.ex` `def admin/1` contains `<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />` | unit | `mix test test/sigra/install/features/admin_test.exs -r "layouts_admin"` | ❌ Wave 0 (new assertion in admin_test.exs) |
| DIST-04 | `test/example/priv/static/assets/sigra_admin.css` exists and `app.css` no longer has `sg-*` rules | integration | `mix test test/sigra/install/features/admin_test.exs -r "DIST-05"` (the byte-compare proves DIST-04 by implication) | ❌ Wave 0 (new file + test) |
| DIST-05 (template≡example) | `priv/templates/sigra.install/admin/sigra_admin.css` byte-identical to `test/example/priv/static/assets/sigra_admin.css` | unit | `mix test test/sigra/install/features/admin_test.exs -r "DIST-05"` | ❌ Wave 0 (new test in admin_test.exs) |
| DIST-05 (template≡fixture) | `priv/templates/sigra.install/admin/sigra_admin.css` byte-identical to `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (via golden-diff) | integration | `mix test test/sigra/install/golden_diff_test.exs --only golden` | ❌ Wave 0 (new fixture file) |
| DIST-06 | Freshly generated host renders styled admin UI (sigra_admin.css applied) | E2E | CI: `scripts/ci/admin-acceptance-smoke.sh --test all` (includes Playwright) | ❌ Wave 0 (new assertion in admin-generated.spec.ts) |

### Merge-Blocking Gates

| Gate | Signal | Command | Merge-Blocking |
|------|--------|---------|----------------|
| DIST-01 D-03 dependency audit | `grep "var(--vt-" priv/templates/sigra.install/admin/sigra_admin.css` exits 1 (no matches) | `grep -c "var(--vt-" priv/templates/sigra.install/admin/sigra_admin.css || true` | YES (run in CI) |
| DIST-02 files/1 assertion | `admin_test.exs` files/1 test green | `mix test test/sigra/install/features/admin_test.exs` | YES |
| DIST-03 layout injection assertion | `admin_test.exs` injection content test green | `mix test test/sigra/install/features/admin_test.exs` | YES |
| DIST-05 template≡example | New byte-compare test in `admin_test.exs` | `mix test test/sigra/install/features/admin_test.exs -r "DIST-05"` | YES |
| DIST-05 template≡fixture | `golden_diff_test.exs` green | `mix test test/sigra/install/golden_diff_test.exs --only golden` | YES (`:golden` / `:integration` tag) |
| DIST-06 styled-host | `admin-generated.spec.ts` styled assertion green | `scripts/ci/admin-acceptance-smoke.sh --test all` (CI job) | YES (CI gate) |
| D-11 snapshot canary | `snapshot-canary-guard.sh` PASS (empty allowlist) | `scripts/ci/snapshot-canary-guard.sh` | YES (called in CI) |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/install/features/admin_test.exs` — fast, unit-only
- **Per wave merge:** `mix test` — full ExUnit suite including golden-diff
- **Phase gate:** Full suite green + CI Playwright job green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `priv/templates/sigra.install/admin/sigra_admin.css` — the extracted template (DIST-01)
- [ ] `test/example/priv/static/assets/sigra_admin.css` — example copy (DIST-04)
- [ ] `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` — golden fixture copy (DIST-05)
- [ ] New `describe "DIST-05 example≡template byte-parity"` test in `test/sigra/install/features/admin_test.exs`
- [ ] New `files/1` tuple assertion in `test/sigra/install/features/admin_test.exs`
- [ ] `<link>` tag in `priv/templates/sigra.install/admin/layouts_admin_injection.ex`
- [ ] Styled assertion in `test/example/priv/playwright/tests/admin-generated.spec.ts`

*(All are new artifacts, not missing from an existing test infrastructure.)*

## Security Domain

`security_enforcement` is not explicitly set in `.planning/config.json` — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 184 is CSS distribution only |
| V3 Session Management | no | CSS distribution only |
| V4 Access Control | no | CSS distribution only |
| V5 Input Validation | no | No user input processed |
| V6 Cryptography | no | No cryptographic operations |

No ASVS category applies to CSS asset distribution. The only security-relevant concern is that the extracted `sigra_admin.css` must not contain application secrets or configuration embedded during the extraction — which is not a risk here since the source is a pure CSS design system.

## Sources

### Primary (HIGH confidence)
- `test/example/priv/static/assets/css/app.css` — Python analysis for extraction boundary (lines cited throughout)
- `lib/sigra/install/features/core.ex:256` — `sigra_auth.css` files/1 tuple pattern
- `priv/templates/sigra.install/core/sigra_auth_components.ex:27` — body-level link pattern
- `lib/sigra/install/features/admin.ex:26–43` — current admin files/1 shape
- `priv/templates/sigra.install/admin/layouts_admin_injection.ex:1–21` — full current def admin/1
- `test/example/lib/example_web/components/layouts/root.html.heex` — link order
- `test/sigra/install/golden_diff_test.exs` — whole-tree byte-compare mechanism
- `test/sigra/install/features/core_test.exs:155,293` — sources/targets assertion pattern
- `test/sigra/install/templates_layout_test.exs:74` — core file count (unaffected)
- `test/sigra/install/features/admin_test.exs` — existing admin files/1 tests
- `.github/workflows/ci.yml:952` — `generated_admin_playwright_smoke` job
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host install + boot script
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — current Playwright assertions
- `scripts/ci/snapshot-canary-guard.sh` — canary mechanism and allowlist behavior
- `test/example/priv/playwright/snapshot-allowlist` — confirmed empty (comments only)

## Metadata

**Confidence breakdown:**
- Extraction boundary: HIGH — Python analysis confirmed all three `@layer sg-*` blocks are clean, `--vt-*` is isolated to `.vt-*` selectors
- Auth precedent pattern: HIGH — code read directly, line numbers cited
- Parity test surfaces: HIGH — golden_diff mechanism read, admin_test.exs read, templates_layout_test count confirmed unaffected
- Styled-host proof: HIGH — CI job and spec read; note on RUN_PARITY=1 non-existence is a correction of the CONTEXT.md assumption
- Snapshot canary: HIGH — script and allowlist read; cascade-layer analysis confirms no fragility

**Research date:** 2026-06-14
**Valid until:** 2026-07-14 (CSS file is stable; installer pipeline changes rarely)
