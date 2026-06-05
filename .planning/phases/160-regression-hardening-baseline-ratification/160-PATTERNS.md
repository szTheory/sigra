# Phase 160: Regression Hardening + Baseline Ratification — Pattern Map

**Mapped:** 2026-06-05
**Files analyzed:** 4 (2 code-change files + 1 shared-helper extraction + 1 new doc)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/priv/static/assets/css/app.css` | config/style | transform | `app.css:885–894` chip dark fix (same file) | exact |
| `lib/sigra/admin/live/index_live.ex` | LiveView | request-response | `lib/sigra/admin/live/organization_live.ex:67` | exact |
| `lib/sigra/admin/live/organization_live.ex` | LiveView | request-response | `lib/sigra/admin/live/index_live.ex:56` | exact |
| `.planning/milestones/v1.34-MILESTONE-AUDIT.md` | doc | — | `.planning/milestones/v1.33-MILESTONE-AUDIT.md` | exact |

---

## Pattern Assignments

### `test/example/priv/static/assets/css/app.css` (D-06 dark override)

**Role:** style / token-layer config  
**Data flow:** transform (CSS token cascade)  
**Analog:** same file, chip dark contrast fix block

#### Light-mode definition to stay unchanged (lines 66–69):
```css
/* Color — brand (burnt orange) */
--sg-color-brand: #c2410c;
--sg-color-brand-strong: #9a3412;
--sg-color-brand-soft: #fff0e8;
```

#### Dark `:root` block that needs the new override (lines 160–185):
```css
@media (prefers-color-scheme: dark) {
  :root {
    --sg-color-ink: #f4f1eb;
    --sg-color-muted: #bdb5aa;
    --sg-color-subtle: #171614;
    --sg-color-panel: #1f1d1a;
    --sg-color-panel-alt: #25221e;
    --sg-color-line: rgba(255, 255, 255, 0.1);
    --sg-color-line-strong: rgba(255, 255, 255, 0.16);
    --sg-color-brand-soft: rgba(243, 90, 16, 0.16);
    /* Lighten tone text + backgrounds for dark mode so pills/rows keep WCAG AA
     * contrast (dark-mode tinted backgrounds need light tone text). */
    --sg-color-ok: #5dd1a0;
    --sg-color-warn: #f5c451;
    --sg-color-risk: #f8a39c;
    --sg-color-info: #9db8f5;
    --sg-color-risk-soft: rgba(248, 113, 113, 0.16);
    --sg-color-warn-soft: rgba(245, 196, 81, 0.16);
    --sg-color-ok-soft: rgba(52, 211, 153, 0.16);
    --sg-color-info-soft: rgba(120, 150, 245, 0.16);
    --sg-elev-inset: inset 0 0 0 1px var(--sg-color-line);
    --sg-elev-1: 0 0 0 1px rgba(255, 255, 255, 0.09);
    --sg-elev-2: 0 0 0 1px rgba(255, 255, 255, 0.15);
    --sg-elev-3: 0 0 0 1px rgba(255, 255, 255, 0.18), 0 24px 60px -28px rgba(0, 0, 0, 0.8);
  }
}
```
**The `--sg-color-brand-strong` override must be added here** (or inside a scoped `@layer sg-components` dark block if a global `:root` override is undesirable). Prefer `:root` to fix all surfaces in one token; the chip block at 890–893 is a scoped per-selector workaround written because the global fix was deferred — D-06 is that global fix.

#### Exact chip precedent to mirror (lines 885–894):
```css
/* Dark mode: the brand-strong foreground (#9a3412) is unreadable on the dark
 * brand-soft tint (WCAG AA fail, ~1.88:1). Lighten the active-chip text to a
 * brand orange that clears 4.5:1 — mirrors the tone-text lightening at L170.
 * Scoped to the chip; the global --sg-color-brand-strong dark gap is tracked
 * separately (it affects other brand-soft surfaces too). */
@media (prefers-color-scheme: dark) {
  .sg-filter-chip:has(input:checked) {
    color: #fdba74;
  }
}
```

**Copy pattern:** The comment structure, the `@media (prefers-color-scheme: dark)` wrapper, and the `#fdba74`-family lightened-brand value. For the global `:root` override the comment should note that this supersedes the chip scoped fix (the chip block at L890–893 can then be removed to avoid duplication).

**All brand-soft+brand-strong combo surfaces needing dark override** (executor must allowlist dark baselines for these):
- `app.css:360–361` — scope-pill background+color
- `app.css:409–410` — scope-switch active
- `app.css:450` — `.sg-badge--brand`
- `app.css:517–518` — nav-link `aria-current`
- `app.css:612–613` — another nav/breadcrumb surface
- `app.css:882` — filter chip (chip scoped override will be superseded)
- `app.css:903–904` — applied filter chip
- `app.css:1372–1373` — additional brand surface

**Constraint:** All new CSS must stay inside `@layer sg-components { }`. No unlayered rules. Light-mode values must not change.

---

### `lib/sigra/admin/live/index_live.ex` (D-07 link fix + dedup)

**Role:** LiveView (admin orientation surface)  
**Data flow:** request-response  
**Analog:** `lib/sigra/admin/live/organization_live.ex` — byte-identical `needs_review/1` and link pattern

#### Current broken link in index_live.ex (lines 54–57):
```elixir
<%= if @needs_review > 0 do %>
  {@needs_review} accounts need review —
  <a href="/admin/users?locked=true">Review now</a>
<% else %>
```
The `?locked=true` deep-link only reaches locked accounts; deleted accounts (`:deleted` in the count) are excluded. Fix to `?needs_review=true` (or equivalent OR-filter URL) so the link destination matches the count.

#### Also at index_live.ex line 78 (capability card deep-link, same mismatch):
```elixir
href="/admin/users?locked=true"
```
This capability card href also only reaches locked accounts. Must be updated to the same "needs review" filter target.

#### current `needs_review/1` in index_live.ex (lines 157–159):
```elixir
defp needs_review(counts) do
  Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)
end
```

#### Identical definition in organization_live.ex (lines 215–217):
```elixir
defp needs_review(counts) do
  Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)
end
```

**Dedup target:** Extract to a shared `Sigra.Admin` helper module. There is currently no `lib/sigra/admin.ex` — the executor must create it. Pattern the module header after `lib/sigra/admin/authorizer.ex` (lines 1–14):
```elixir
defmodule Sigra.Admin.Authorizer do
  @moduledoc """
  Direct-path admin authorization helpers for exports, mutations, and queries.
  ...
  """
```
New module: `Sigra.Admin` with a `@moduledoc` describing it as shared admin utility helpers, and `def needs_review(counts)` as a public function.

#### Filter composition context — users_index_live.ex (lines 14, 405–426):
```elixir
@quick_filter_keys ~w(confirmed mfa passkeys locked deleted)
```
```elixir
defp any_filter_active?(params) do
  Enum.any?(@quick_filter_keys, &param_true?(params, &1)) or
  Enum.any?(@more_filter_keys, &present_param?(params, &1))
end
```
The filter system is AND-composed: each active `?key=true` narrows the result independently. `?locked=true&deleted=true` therefore returns the INTERSECTION (users who are both locked AND deletion-scheduled), not the UNION. A "needs review" OR-filter must be a new filter key (`needs_review`) routed through `apply_filter/3` in `query.ex`, or a URL-level redirect that constructs the correct Flop OR filter. The executor must choose the shape (see Claude's Discretion in CONTEXT.md) and reference the filter application pattern in `query.ex:299–310`:

```elixir
defp apply_filter(query, %Flop.Filter{field: :locked, value: value}, _helpers) do
  case value do
    true -> where(query, [user: user], not is_nil(user.locked_at))
    false -> where(query, [user: user], is_nil(user.locked_at))
  end
end

defp apply_filter(query, %Flop.Filter{field: :deleted, value: value}, _helpers) do
  case value do
    true -> where(query, [user: user], not is_nil(user.deleted_at))
    false -> where(query, [user: user], is_nil(user.deleted_at))
  end
end
```
A `needs_review` filter would use `or_where` / `dynamic` to OR the two conditions.

---

### `lib/sigra/admin/live/organization_live.ex` (D-07 link fix + dedup)

**Role:** LiveView (org-scoped admin overview)  
**Data flow:** request-response  
**Analog:** `lib/sigra/admin/live/index_live.ex` (same pattern, see above)

#### Current broken link in organization_live.ex (line 67):
```elixir
{@needs_review} {if @needs_review == 1, do: "account needs", else: "accounts need"} review — <a href={users_path(@admin_scope) <> "?locked=true"}>Review now</a>
```
Same mismatch as index_live.ex: `?locked=true` only reaches locked accounts. Fix to `?needs_review=true` (or equivalent), identical treatment to index_live.ex.

#### Also at organization_live.ex line 114 (stat card deep-link):
```elixir
href={users_path(@admin_scope) <> "?locked=true"}
```
This stat-card href also deep-links only to locked. Note: the adjacent `:deleted` stat card at line ~120 correctly links `?deleted=true` for the deleted-only view — that is fine. Only the "needs review" notice link and the alarm card link need the OR-filter fix.

**After dedup:** Remove `defp needs_review/1` from both files; call `Sigra.Admin.needs_review/1` instead.

---

### `.planning/milestones/v1.34-MILESTONE-AUDIT.md` (D-09 new doc)

**Role:** doc (milestone proof bundle)  
**Data flow:** —  
**Analog:** `.planning/milestones/v1.33-MILESTONE-AUDIT.md` (most recent passing audit)

#### YAML frontmatter to mirror (v1.33, lines 1–28):
```yaml
---
milestone: v1.33
milestone_name: POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS
audited: 2026-06-02T06:18:27Z
status: passed
scores:
  requirements: 10/10
  phases: 4/4 complete, 4/4 verification-passed, 0/4 human_needed
  integration: 3/3
  flows: 3/3 wired
gaps:
  requirements: []
  integration: []
  flows: []
tech_debt:
  - phase: "153"
    items:
      - "..."
nyquist:
  compliant_phases: []
  partial_phases: [...]
  missing_phases: [...]
  overall: "partial"
---
```
For v1.34: set `milestone: v1.34`, `milestone_name: ADMIN-UI-COHERENCE`, `audited: <ISO timestamp>`, `status: passed`, requirements = 4/4 (COMP-01..04), phases = 7/7 (154–160), gates GATE-01/GATE-02/GATE-03 all Complete.

#### Section headings to include (v1.33 structure):
1. `# v1.34 ADMIN-UI-COHERENCE Milestone Audit` + **Status** / **Score** / **Audited** intro
2. `## Verdict` — narrative summary of what closed and what the headline proof is
3. `## Requirements Coverage` — table: Requirement | Phase | Requirements.md | Verification | Summary frontmatter | Final status | Evidence
4. `## Phase Coverage` — table: Phase | Roadmap status | Verification status | Final status | Notes (phases 154–160)
5. `## Integration Findings` — table: Finding | Severity | Requirements | Evidence
6. `## End-to-End Flows` — table: Flow | Requirements | Status | Gap
7. `## Nyquist Discovery` — validation artifact completeness note
8. `## Tech Debt And Warnings` — any known non-blocking items
9. `## Next Action` — `Proceed with $gsd-complete-milestone v1.34`

**Key evidence to cite in the Verdict / Requirements Coverage:**
- `snapshot-recapture-gate.sh` 3-project compare-mode green run (criterion 1)
- `snapshot-canary-guard.sh --require-all` green (zero unintended re-records)
- `admin-acceptance-smoke.sh` parity lane green (GATE-02 / criterion 2)
- ExUnit component byte-golden suite green
- D-06 dark `--sg-color-brand-strong` fix + axe WCAG-AA dark confirmation (criterion 1 — no latent AA gap)
- D-07 needs-review link/count reconciliation (criterion 1 — behavior correctness)
- `guides/reference/admin-design-contract.md` ratified (criterion 4)
- Per-phase 154–159 VERIFICATION.md set (criteria 1–4 traceability)

---

## Shared Patterns

### Module structure for new `lib/sigra/admin.ex`
**Source:** `lib/sigra/admin/authorizer.ex` lines 1–14
**Apply to:** The new shared helper module hosting `needs_review/1`
```elixir
defmodule Sigra.Admin do
  @moduledoc """
  Shared admin utility helpers used across admin LiveView surfaces.
  """

  @doc """
  Returns the count of accounts that need admin review.
  Counts locked + deletion-scheduled accounts.
  """
  def needs_review(counts) do
    Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)
  end
end
```

### CSS dark-mode override pattern
**Source:** `test/example/priv/static/assets/css/app.css` lines 160–184 (dark `:root` block) and lines 885–894 (chip precedent)
**Apply to:** D-06 `--sg-color-brand-strong` global dark override
**Constraint:** Place inside the existing dark `:root` block in the `@media (prefers-color-scheme: dark)` rule (lines 160–184). Comment must name the AA ratio target and reference the chip scoped fix it supersedes.

### Milestone audit document format
**Source:** `.planning/milestones/v1.33-MILESTONE-AUDIT.md`
**Apply to:** `.planning/milestones/v1.34-MILESTONE-AUDIT.md`
Mirror YAML frontmatter structure exactly; populate sections 1–9 as listed above.

---

## No Analog Found

None. All four artifacts have direct analogs in the codebase.

---

## Metadata

**Analog search scope:** `test/example/priv/static/assets/css/`, `lib/sigra/admin/live/`, `lib/sigra/admin/`, `.planning/milestones/`
**Files scanned:** 8 source files + CSS file read
**Pattern extraction date:** 2026-06-05
