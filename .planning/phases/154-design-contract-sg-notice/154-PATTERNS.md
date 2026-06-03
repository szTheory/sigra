# Phase 154: Design Contract + sg-notice — Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 3 (1 create, 2 modify)
**Analogs found:** 3 / 3

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/reference/admin-design-contract.md` | documentation/reference | static artifact | `guides/reference/generator-options.md` | exact |
| `mix.exs` (extras: edit) | config | build-time transform | existing `"guides/reference/generator-options.md"` entry at line 198 | exact |
| `test/example/priv/static/assets/css/app.css` (insert after line 967) | stylesheet | static asset | `.sg-list-row[data-tone]` block at lines 945–967 | exact |

---

## Pattern Assignments

---

### `guides/reference/admin-design-contract.md` (documentation, static artifact)

**Analog:** `guides/reference/generator-options.md`

**Document shape pattern** (lines 1–16 of analog):
```markdown
# Generator and install options

This page is the **canonical human index** for `mix sigra.install` switches. Exhaustive machine truth lives in **`mix help sigra.install`** and in the HexDocs module page for **`Mix.Tasks.Sigra.Install`**.

| Flag | Default | One-line effect | See also |
|------|---------|-----------------|----------|
| `--live` / `--no-live` | true | Generate LiveView-based auth pages vs a slimmer controller-only surface. | [Getting started](../introduction/getting-started.html) |
...
```

**Structural pattern to copy:**
- Opening paragraph: one-sentence statement of what the page is and its authority scope.
- Primary content organized in heading sections with Markdown tables — not prose lists.
- Cross-reference links use relative `.html` paths (not `.md`) for ExDoc rendering.
- No front-matter YAML block — ExDoc infers title from the first `# H1`.
- File lives in `guides/reference/` — the `Reference: ~r{guides/reference/.?}` group regex at `mix.exs:243` matches it automatically; no `groups_for_extras:` change needed.

**Content structure for this file (per D-03):**

```markdown
# Sigra Admin Design Contract

(opening paragraph — canonical authority statement citing REQUIREMENTS.md COMP-03)

## Job → Component Mapping

### <ComponentName>

| Property | Value |
|----------|-------|
| Job | ... |
| Winning markup | ... |
| ARIA role(s) | ... |
| Motion spec | ... |
| When NOT to use | ... |

(×10 components: stat_link, stat, task_card, summary_chip, applied_chip,
 empty_state, page_back, scope_ribbon, notice, skeleton)

## Page Archetypes

### Overview Archetype
(component composition)

### List Archetype
(component composition)

### Detail Archetype
(component composition)
```

**Key authoring rules (from D-07, D-08, UI-SPEC):**
- Document current reality and already-locked winners — do not invent new design calls.
- Header winner (open `sg-page-header`) is locked by COHR-02 — cite as locked, do not re-decide.
- `stat` and chip variants are markup-consolidation targets — note "executable form deferred to Phase 155 (COMP-01)", do not invent a `.sg-stat` CSS class.
- Motion spec entries MUST include explicit "not animated" items for keyboard-frequent interactions (seeds Phase 159 GATE-03 audit).
- `stat` component: no dedicated markup exists yet — document `sg-metric-link` as the closest analog and explicitly mark canonical form as deferred to Phase 155.

---

### `mix.exs` — ExDoc `extras:` list (config, build-time transform)

**Analog:** Existing `"guides/reference/generator-options.md"` entry at `mix.exs:198`.

**Exact surrounding context** (lines 186–200):
```elixir
      extras: [
        "README.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "MAINTAINING.md",
        "LICENSE",
        "CHANGELOG.md",
        "guides/introduction/installation.md",
        "guides/introduction/getting-started.md",
        "guides/introduction/contract.md",
        "guides/introduction/first-hour.md",
        "guides/introduction/intermediate-production-path.md",
        "guides/reference/generator-options.md",      # ← existing reference entry (line 198)
        "guides/introduction/troubleshooting-install.md",
        ...
      ],
```

**Edit pattern — add exactly one line immediately after line 198:**
```elixir
        "guides/reference/generator-options.md",
        "guides/reference/admin-design-contract.md",   # ← INSERT THIS LINE
```

**Why no other changes are needed:**

The `groups_for_extras:` block at `mix.exs:241–248`:
```elixir
      groups_for_extras: [
        Introduction: ~r{guides/introduction/.?},
        Reference: ~r{guides/reference/.?},            # ← already matches new path
        Flows: ~r{guides/flows/.?},
        "Companion Libraries": ~r{guides/recipes/companion-libs/.?},
        Recipes: ~r{guides/recipes/[^/]+\.md$},
        Docs: ~r{^docs/|^SECURITY\.md$}
      ],
```

`Reference: ~r{guides/reference/.?}` already matches any file under `guides/reference/`. The new entry is a plain string (no options map) — same form as all other entries. No other `mix.exs` changes.

---

### `test/example/priv/static/assets/css/app.css` — `sg-notice` CSS (stylesheet, static asset)

**Analog:** `.sg-list-row[data-tone]` block at lines 945–967.

**Exact analog to copy** (lines 945–967 — direct source read):
```css
  .sg-list-row {
    border-radius: var(--sg-radius-sm);
    background: var(--sg-color-panel-alt);
    box-shadow: var(--sg-elev-inset);
    padding: var(--sg-space-4);
    transition: var(--sg-transition-tone);
  }
  .sg-list-row[data-tone="ok"] {
    background: color-mix(in oklab, var(--sg-color-ok-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-ok), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-ok) 18%, transparent);
  }
  .sg-list-row[data-tone="warn"] {
    background: color-mix(in oklab, var(--sg-color-warn-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-warn), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-warn) 20%, transparent);
  }
  .sg-list-row[data-tone="risk"] {
    background: color-mix(in oklab, var(--sg-color-risk-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-risk), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-risk) 20%, transparent);
  }
  .sg-list-row[data-tone="info"] {
    background: color-mix(in oklab, var(--sg-color-info-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-info), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-info) 20%, transparent);
  }
```

**Insertion point:** After line 967 (the closing `}` of `.sg-list-row[data-tone="info"]`), before `.sg-kv` at line 969. The `@layer sg-components { }` block does not close until line 1418 — the insertion at line 968 is safely inside the layer.

**Exact CSS to insert** (replace `.sg-list-row` selector with `.sg-notice`, identical token set):
```css

  /* NOTICE — behavior-preserving consolidation of sg-list-row[data-tone] alert pattern.
   * Phase 156 (COHR-05) migrates call sites to <.notice>. Source: Phase 154 COMP-04. */
  .sg-notice {
    border-radius: var(--sg-radius-sm);
    background: var(--sg-color-panel-alt);
    box-shadow: var(--sg-elev-inset);
    padding: var(--sg-space-4);
    transition: var(--sg-transition-tone);
  }
  .sg-notice[data-tone="ok"] {
    background: color-mix(in oklab, var(--sg-color-ok-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-ok), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-ok) 18%, transparent);
  }
  .sg-notice[data-tone="warn"] {
    background: color-mix(in oklab, var(--sg-color-warn-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-warn), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-warn) 20%, transparent);
  }
  .sg-notice[data-tone="risk"] {
    background: color-mix(in oklab, var(--sg-color-risk-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-risk), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-risk) 20%, transparent);
  }
  .sg-notice[data-tone="info"] {
    background: color-mix(in oklab, var(--sg-color-info-soft) 62%, var(--sg-color-panel));
    box-shadow: inset 3px 0 0 0 var(--sg-color-info), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-info) 20%, transparent);
  }
```

**Critical asymmetry to preserve:** `ok` tone uses `18%` ring opacity; `warn`/`risk`/`info` use `20%`. This matches the `sg-list-row` source exactly — copy verbatim.

**CSS layer context pattern** (line 15 for reference):
```css
@layer sg-base, sg-components, sg-overrides;
```

`sg-notice` goes inside `@layer sg-components { }` (opens line 203, closes line 1418). Insertion at line 968 is well inside the block.

**Reduced-motion and dark-mode:** Both are inherited automatically — no additional rules needed:
- Dark-mode: `@media (prefers-color-scheme: dark)` at lines 160–185 already overrides all tone tokens (`--sg-color-ok`, etc.). `sg-notice` inherits them.
- Reduced-motion: Universal `@media (prefers-reduced-motion: reduce)` at lines 1437–1447 handles all transitions. `color`, `background-color`, `box-shadow` are listed in the override `transition-property` — `sg-notice` is fully covered.

---

## Shared Patterns

### Layer boundary enforcement
**Source:** `test/example/priv/static/assets/css/app.css` line 203 (`@layer sg-components {`) and line 1418 (closing `}`)
**Apply to:** The CSS edit
**Rule:** All new CSS must be inserted between lines 203 and 1418, inside `@layer sg-components`. Insertion at line 968 satisfies this. Verify with `grep -n "@layer" app.css` after editing.

### No `!important` invariant
**Source:** `test/example/priv/static/assets/css/app.css` lines 1437–1447
**Apply to:** The CSS edit
**Rule:** The only `!important` in the file is the `prefers-reduced-motion` block. `sg-notice` introduces no specificity conflict and requires no `!important`.

### ExDoc plain-string extras entry
**Source:** `mix.exs` lines 187–239
**Apply to:** The mix.exs edit
**Rule:** All `extras:` entries are bare strings (not maps with `:title` keys). The new entry follows this form: `"guides/reference/admin-design-contract.md"`.

### No LiveView edits
**Source:** CONTEXT.md D-04, RESEARCH.md hard constraints
**Apply to:** All execution in this phase
**Rule:** Zero changes to any file under `lib/sigra/admin/live/`. `sg-notice` CSS is a class definition only — no call site uses `.sg-notice` until Phase 156 (COHR-05).

---

## No Analog Found

None. All three files have direct analogs in the codebase.

---

## Metadata

**Analog search scope:** `guides/reference/`, `test/example/priv/static/assets/css/`, `mix.exs`
**Files scanned:** 4 (`guides/reference/generator-options.md`, `test/example/priv/static/assets/css/app.css` lines 940–975, `mix.exs` lines 186–250, `154-RESEARCH.md`)
**Pattern extraction date:** 2026-06-03
