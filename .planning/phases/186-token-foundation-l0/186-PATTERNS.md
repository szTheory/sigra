# Phase 186: Token Foundation (L0) - Pattern Map

**Mapped:** 2026-06-14
**Files analyzed:** 4 new/modified files
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `guides/reference/admin-token-reference.md` | documentation / reference | transform (CSS → rationale table) | `guides/reference/admin-quality-ledger.md` + `guides/reference/admin-fractal-scorecard.md` | role-match |
| `guides/reference/admin-quality-ledger.md` (add L0 row) | documentation / machine-parseable record | transform (audit result → tier row) | existing rows in same file (`stat`, `mg-1-metric-strip`, `index-live`) | exact |
| `test/sigra/install/features/admin_test.exs` (add D-11 describe block) | test / parity assertion | file-I/O (read CSS → compare extracted sets) | lines 317–328 of same file (DIST-05 byte-parity test) | exact |
| `test/example/priv/playwright/tests/admin-theme.spec.ts` (extend contrastRatio assertions) | test / browser E2E | request-response (Playwright → computed styles → assertion) | lines 500–576 of same file (notice_link contrastRatio assertions) | exact |

---

## Pattern Assignments

### `guides/reference/admin-token-reference.md` (NEW — documentation, transform)

**Closest analogs:** `guides/reference/admin-quality-ledger.md` (structure/heading conventions) and `guides/reference/admin-fractal-scorecard.md` (table columns, dimension rows, cross-reference footers).

**Heading and preamble pattern** (from `admin-quality-ledger.md` lines 1–18):
```markdown
# Admin Quality Ledger

Machine-parseable quality tier record for Sigra's admin UI surfaces. Updated by phases
186-192 as fractal quality audits progress.

## Tier Vocabulary

| Tier | Name | Description |
|------|------|-------------|
| 0 | Drift | ... |
```

Apply the same conventions for `admin-token-reference.md`:
- `#` H1 = document title, one sentence role statement
- `##` H2 = one section per token category (Color, Type Scale, Spacing, Radius, Control Heights, Elevation/Shadow, Motion, Focus Ring, Z-Index, Layout)
- Cross-reference footer matching the scorecard's: `Cross-reference: admin-design-contract.md, brandbook/tokens.json`

**Table column pattern** (from `admin-fractal-scorecard.md` lines 24–36):
```markdown
| dimension | description | pass criteria | score | evidence |
|-----------|-------------|---------------|-------|----------|
| D1 Brand color | Admin surfaces use the Rail Accent palette... | No raw hex values... | | |
```

The new token-reference table uses four columns instead of five:
```markdown
| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-brand` | `#c2410c` | Primary ember accent; interactive elements + ownership emphasis | `brandbook/tokens.json` → `semantic.light.color.accent` |
```

**Key table conventions to copy:**
- Token column: backtick-wrapped CSS custom property name
- Value column: backtick-wrapped hex/CSS value (or range for composed values)
- Rationale column: one sentence explaining design intent + emilkowal.ski citation for motion tokens
- Brand Ref column: `brandbook/tokens.json` JSON path, or `admin-layer decision` if not present in tokens.json (control heights, z-index ladder, layout tokens, component sizing are not in tokens.json per RESEARCH.md)

**Document footer cross-reference pattern** (from `admin-fractal-scorecard.md` line 125):
```markdown
Cross-reference: `admin-design-contract.md`, `admin-ui-principles.md`
```

Apply the same footer for admin-token-reference.md:
```markdown
Cross-reference: `admin-design-contract.md` (dark AA resolution note ~line 207), `brandbook/tokens.json` (brand source of truth), `guides/reference/admin-quality-ledger.md` (L0 row).
```

---

### `guides/reference/admin-quality-ledger.md` (MODIFY — add L0 row)

**Analog:** Existing rows in the same file (`guides/reference/admin-quality-ledger.md` lines 36–59).

**Existing L1 row pattern** (lines 36–38):
```markdown
| Item | Level | Tier | Evidence |
|------|-------|------|----------|
| stat | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
```

**Existing L2 row pattern** (line 49):
```markdown
| mg-1-metric-strip | L2 | 1 | [admin-design.spec.ts board-mg-1](#) |
```

**Existing L3 row pattern** (line 54):
```markdown
| index-live | L3 | 1 | [admin-checkpoints: global-overview](#) |
```

**L0 row to add** (insert above the L1 rows — before line 36):
```markdown
| token-layer | L0 | 1 | [admin-token-reference.md](admin-token-reference.md) |
```

**Critical parsing rules** (from `scripts/ci/quality-ledger-monotonic.sh` — verified in RESEARCH.md):
- Column 4 (1-indexed in `|`-delimited rows) = tier cell. Must be a bare `0`, `1`, or `2`. No text, no asterisks, no parens.
- Column 2 = item slug. Must start with a lowercase letter for the awk to parse it (`tier ~ /^[012]$/`).
- `L0` goes in column 3 (Level column). `1` (Ratified) goes in column 4.
- Evidence link (column 5) is where explanatory text goes — not in the tier column.

**Verification command** (from RESEARCH.md Pitfall 1):
```bash
grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md | awk -F'|' '{print $4}'
```
Must print a bare `1` for the `token-layer` row (no surrounding whitespace or decorators after trim).

---

### `test/sigra/install/features/admin_test.exs` (MODIFY — add D-11 describe block)

**Analog:** DIST-05 test in the same file, lines 317–328.

**Module header and use pattern** (lines 1–4):
```elixir
defmodule Sigra.Install.Features.AdminTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Admin
```

**DIST-05 byte-parity pattern** (lines 317–328 — the exact analog to copy structure from):
```elixir
describe "DIST-05 example≡template byte-parity (sigra_admin.css)" do
  test "example copy is byte-identical to the installer template" do
    template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
    example = File.read!("test/example/priv/static/assets/sigra_admin.css")

    assert byte_size(template) == byte_size(example),
           "size mismatch — resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"

    assert template == example,
           "content mismatch — example copy has diverged from the installer template; resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"
  end
end
```

**Existing private helpers** (lines 330–349 — available for reuse or reference in D-11):
```elixir
defp source_fragment(source, needle, len) do
  case :binary.match(source, needle) do
    {start, _} -> binary_part(source, start, min(len, byte_size(source) - start))
    :nomatch -> ""
  end
end

defp source_offset(source, needle) do
  case :binary.match(source, needle) do
    {offset, _} -> offset
    :nomatch -> nil
  end
end
```

**D-11 describe block pattern to add** (after the DIST-05 describe block, before the closing `end` of the module, i.e. after line 328):

The D-11 describe block follows the DIST-05 pattern with these differences:
- Uses value-equivalence (not byte-equality) because the two blocks differ in selector and indentation
- Extracts `--sg-*` lines from each block, trims whitespace, sorts, and compares the sorted lists
- The `source_fragment/3` helper already in the file can find block content by anchor string — extend this pattern for block extraction

The dark block anchors (verified in RESEARCH.md):
- Surface 1: `priv/templates/sigra.install/admin/sigra_admin.css` — anchor `"@media (prefers-color-scheme: dark)"`, inner content at lines 167–204
- Surface 2: `test/example/priv/static/assets/css/app.css` — anchor `"html[data-sg-admin-theme=\"dark\"] .sg-admin-shell"`, block at lines 1512–1543

**Anti-pattern to avoid:** Do NOT use `assert template_block == app_block` (byte equality) — the two blocks differ in selector, indentation, and presence of comments. Compare only extracted/sorted `--sg-*` declarations.

---

### `test/example/priv/playwright/tests/admin-theme.spec.ts` (MODIFY — extend contrastRatio)

**Analog:** Existing notice_link contrastRatio assertions, lines 500–576 of the same file.

**File imports and constants** (lines 1–7 — copy for any new test functions):
```typescript
import AxeBuilder from "@axe-core/playwright";
import { test, expect, type Page } from "@playwright/test";
import { TEST_PASSWORD } from "../helpers/fixtures";

const DESKTOP_VIEWPORT = { width: 1280, height: 900 };
const MOBILE_VIEWPORT = { width: 390, height: 844 };
```

**contrastRatio helper definition** (lines 183–190 — do not re-define, reference directly):
```typescript
function contrastRatio(foreground: string, background: string) {
  const foregroundLuminance = relativeLuminance(rgbChannels(foreground));
  const backgroundLuminance = relativeLuminance(rgbChannels(background));
  const lighter = Math.max(foregroundLuminance, backgroundLuminance);
  const darker = Math.min(foregroundLuminance, backgroundLuminance);

  return (lighter + 0.05) / (darker + 0.05);
}
```

**Computed-style read + contrastRatio assertion pattern** (lines 500–521 — the exact template for new tone-soft assertions):
```typescript
// Read computed styles via .evaluate()
const styles = await page.locator(".sg-notice[data-tone='ok']").evaluate((el) => {
  const textEl = el.querySelector(".sg-notice__body") as HTMLElement;
  return {
    color: getComputedStyle(textEl).color,
    background: getComputedStyle(el).backgroundColor,
  };
});

// Assert with expect.poll for reliability across theme switches
await expect
  .poll(async () => {
    const styles = await readStyles();
    return contrastRatio(styles.color, styles.noticeBackground);
  })
  .toBeGreaterThanOrEqual(4.5);
```

**Theme-switch pattern** (lines 545–556 — used to assert both light and dark in one test):
```typescript
await page.getByRole("radio", { name: "Dark" }).click();
await expect(page.locator(".sg-admin-shell")).toHaveAttribute("data-theme", "dark");

await expect
  .poll(async () => {
    const styles = await readStyles();
    return contrastRatio(styles.color, styles.noticeBackground);
  })
  .toBeGreaterThanOrEqual(4.5);
```

**sg-summary-chip metric contrast pattern** (lines 662–677 — the per-element evaluate pattern):
```typescript
const metricContrast = async () =>
  metric.evaluate((el) => {
    const value = el.querySelector(".sg-metric__value") as HTMLElement;
    const styles = getComputedStyle(value);
    return {
      color: styles.color,
      background: getComputedStyle(el).backgroundColor,
    };
  });

await expect
  .poll(async () => {
    const styles = await metricContrast();
    return contrastRatio(styles.color, styles.background);
  })
  .toBeGreaterThanOrEqual(4.5);
```

**Navigation to design gallery** — new tone-soft tests should navigate to `/admin/_design` (the gallery board that renders all tones) rather than live admin pages, to test all four tones (ok, warn, risk, info) together.

**Pairs to cover** (from RESEARCH.md Pattern 3 — axe misses these due to alpha-composited rgba/color-mix backgrounds):
- `.sg-notice[data-tone="ok"]` text on composited ok-soft background — light and dark
- `.sg-notice[data-tone="warn"]` text on composited warn-soft background — light and dark
- `.sg-notice[data-tone="risk"]` text on composited risk-soft background — light and dark
- `.sg-notice[data-tone="info"]` text on composited info-soft background — light and dark
- `.sg-summary-chip` with brand-strong text on brand-soft background — dark only (dark brand-strong `#fdba74` on rgba soft bg)

---

## Shared Patterns

### File.read! for CSS content (ExUnit)

**Source:** `test/sigra/install/features/admin_test.exs` lines 317–328
**Apply to:** D-11 parity describe block

```elixir
admin_css = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
app_css = File.read!("test/example/priv/static/assets/css/app.css")
```

Paths are relative to the mix project root (same working directory that `mix test` uses). No `Path.join(__DIR__, ...)` needed — DIST-05 uses bare string paths and they work.

### expect.poll for computed-style assertions (Playwright)

**Source:** `test/example/priv/playwright/tests/admin-theme.spec.ts` lines 516–521
**Apply to:** All new tone-soft contrastRatio assertions

```typescript
await expect
  .poll(async () => {
    const styles = await readStyles();
    return contrastRatio(styles.color, styles.noticeBackground);
  })
  .toBeGreaterThanOrEqual(4.5);
```

Use `expect.poll` (not a direct `expect(value)`) for computed-style contrast assertions so Playwright retries while CSS re-renders after theme switches. The existing notice_link tests use this pattern consistently.

### waitForLiveViewReady before DOM reads (Playwright)

**Source:** `test/example/priv/playwright/tests/admin-theme.spec.ts` lines 8–12
**Apply to:** Any new test that navigates to `/admin/_design`

```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector("[data-phx-session].phx-connected", {
    state: "attached",
  });
}
```

Call `await waitForLiveViewReady(page)` after every `page.goto()` before reading computed styles.

---

## No Analog Found

All four files have close analogs. No gaps.

---

## Metadata

**Analog search scope:** `guides/reference/`, `test/sigra/install/features/`, `test/example/priv/playwright/tests/`
**Files scanned:** 6 (admin-quality-ledger.md, admin-fractal-scorecard.md, admin-design-contract.md, admin-ui-principles.md, admin_test.exs, admin-theme.spec.ts)
**Pattern extraction date:** 2026-06-14
