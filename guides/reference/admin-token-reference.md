# Admin Token Reference

Per-token rationale and brand reference for every `--sg-*` custom property in the `sigra_admin.css` `:root` layer — the canonical source for understanding why each value exists, not just what it is.

---

## Color — Neutrals

Light-mode values from `:root`. Dark-mode overrides noted inline.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-ink` | `#151515` (light) / `#f4f1eb` (dark) | Primary text; maximum contrast on panel and page backgrounds | `raw.color.ink` / `raw.color.dark-text` |
| `--sg-color-muted` | `#686868` (light) / `#bdb5aa` (dark) | Secondary and supporting text; meets WCAG AA on light panel backgrounds | `raw.color.warm-700` / `raw.color.dark-muted` |
| `--sg-color-subtle` | `#f6f5f2` (light) / `#171614` (dark) | Page canvas background; warm tint differentiates admin from plain white hosts | `semantic.light.color.bg` / `semantic.dark.color.bg` |
| `--sg-color-panel` | `#ffffff` (light) / `#1f1d1a` (dark) | Card and modal surface; on top of the subtle page background | `semantic.light.color.surface` / `semantic.dark.color.surface` |
| `--sg-color-panel-alt` | `#fbfaf7` (light) / `#25221e` (dark) | Alternating row and nested-section surface; slight warm shift from panel | `semantic.light.color.surface-alt` / `semantic.dark.color.surface-alt` |
| `--sg-color-line` | `rgba(21, 21, 21, 0.1)` (light) / `rgba(255, 255, 255, 0.1)` (dark) | Default divider and subtle border; alpha-based so it composites correctly on any background | `semantic.light.color.border` / `semantic.dark.color.border` |
| `--sg-color-line-strong` | `rgba(21, 21, 21, 0.16)` (light) / `rgba(255, 255, 255, 0.16)` (dark) | Emphasis border (table headers, selected controls); slightly stronger than line | `semantic.light.color.border-strong` / `semantic.dark.color.border-strong` |

---

## Color — Brand

Light-mode values from `:root`. Dark overrides noted. See the dark AA remediation note below.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-brand` | `#c2410c` | Primary ember accent; used on interactive element labels, ownership emphasis, and focus indicators | `semantic.light.color.accent` (`raw.color.ember-700`) |
| `--sg-color-brand-strong` | `#9a3412` (light) / `#fdba74` (dark) | Pressed and active states for brand elements; dark override lightened to meet WCAG AA — see dark AA note below | `semantic.light.color.accent-strong` (`raw.color.ember-800`) / `semantic.dark.color.accent-strong` (`raw.color.ember-300`) |
| `--sg-color-brand-solid` | `#9a3412` (light) / `#fdba74` (dark) | Solid filled badge and chip foreground; same hue as brand-strong, ensures sufficient contrast on soft fill | `raw.color.ember-800` / `raw.color.ember-300` |
| `--sg-color-brand-fill-hover` | `#c74712` | Hover fill for brand-colored interactive surfaces; brighter than the base brand to signal pointer entry | `raw.color.ember-700` (variant step, no dedicated tokens.json entry) |
| `--sg-color-brand-fill-active` | `#9a3412` | Active/pressed fill; matches brand-strong to create a clear pressed-down visual | `raw.color.ember-800` |
| `--sg-color-brand-soft` | `#fff0e8` (light) / `rgba(243, 90, 16, 0.16)` (dark) | Low-saturation tint for selected rows, chips, and soft callouts; preserves legibility at low contrast ratios | `semantic.light.color.accent-soft` (`raw.color.ember-050`) / `semantic.dark.color.accent-soft` |
| `--sg-color-on-brand` | `#ffffff` | Text and icons on brand-colored interactive elements; white maximises contrast on ember hues | `semantic.light.color.on-accent` (`raw.color.paper`) |
| `--sg-color-on-brand-solid` | `#ffffff` (light) / `#151515` (dark) | Text on solid-brand badges in dark mode; flipped to near-black because dark brand-solid is the light ember-300 | `raw.color.paper` / `raw.color.ink` |
| `--sg-logo-rail-accent` | `#fdba74` | Rail accent mark fill in the logo lockup; the lighter ember tone gives the diagonal rail visual lift on dark and light surfaces | `raw.color.ember-300` |
| `--sg-logo-rail-ember` | `#c2410c` (light) / `#f97316` (dark) | Ember fill for the primary rail rail element; dark mode shifts slightly warmer for visual consistency against dark backgrounds | `raw.color.ember-700` / `raw.color.ember-600` (adjacent palette step) |
| `--sg-logo-core` | `#9a3412` (light) / `#f4f1eb` (dark) | Logo wordmark text fill; dark mode reverses to near-white warm ink so the wordmark reads on dark panels | `raw.color.ember-800` / `raw.color.dark-text` |

### Dark AA Remediation Note

In the dark override block (`@media (prefers-color-scheme: dark)`), `--sg-color-brand-strong` is lightened from `#9a3412` to `#fdba74`. The original dark value produced a contrast ratio of approximately 1.88:1 against the dark `brand-soft` tint (`rgba(243, 90, 16, 0.16)` composited on `#1f1d1a`), failing WCAG AA (4.5:1 for normal text). The `#fdba74` (`ember-300`) override achieves ≥4.5:1 on the composited soft background. This remediation was applied in v1.34 and is recorded in `admin-design-contract.md` ~line 207.

---

## Color — Semantic Status

Light-mode values from `:root`. Dark overrides noted.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-risk` | `#b42318` (light) / `#f8a39c` (dark) | Destructive actions, error states, and risk alerts; red hue triggers immediate attention | `semantic.light.color.error` (`raw.color.red-700`) / `semantic.dark.color.error` |
| `--sg-color-risk-soft` | `#fff1f0` (light) / `rgba(248, 113, 113, 0.16)` (dark) | Background tint for risk callouts and invalid form fields; low saturation prevents alarm fatigue | `semantic.light.color.error-soft` (`raw.color.red-050`) / `semantic.dark.color.error-soft` |
| `--sg-color-warn` | `#a15c00` (light) / `#f5c451` (dark) | Caution states, pending review, and advisory notices; amber hue signals attention without urgency | `semantic.light.color.warning` (`raw.color.yellow-700`) / `semantic.dark.color.warning` |
| `--sg-color-warn-soft` | `#fff7e6` (light) / `rgba(245, 196, 81, 0.16)` (dark) | Background tint for warning callouts; warm wash without the severity of risk-soft | `semantic.light.color.warning-soft` (`raw.color.yellow-050`) / `semantic.dark.color.warning-soft` |
| `--sg-color-ok` | `#176b43` (light) / `#5dd1a0` (dark) | Success confirmations, active/verified states, and positive health indicators | `semantic.light.color.success` (`raw.color.green-700`) / `semantic.dark.color.success` |
| `--sg-color-ok-soft` | `#ecfdf3` (light) / `rgba(52, 211, 153, 0.16)` (dark) | Background tint for success callouts and confirmed-action rows | `semantic.light.color.success-soft` (`raw.color.green-050`) / `semantic.dark.color.success-soft` |
| `--sg-color-info` | `#1d4ed8` (light) / `#9db8f5` (dark) | Informational notices, contextual help, and neutral status indicators | `semantic.light.color.info` (`raw.color.blue-700`) / `semantic.dark.color.info` |
| `--sg-color-info-soft` | `#eef2ff` (light) / `rgba(120, 150, 245, 0.16)` (dark) | Background tint for info callouts; cooler wash distinguishes informational from actionable states | `semantic.light.color.info-soft` (`raw.color.blue-050`) / `semantic.dark.color.info-soft` |

---

## Spacing

4px base grid. All values in `rem` so they scale with the root font size.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-space-1` | `0.25rem` | 4px — micro gap between icon and label, pill padding | `space.1` |
| `--sg-space-2` | `0.5rem` | 8px — tight intra-component gap (e.g. button icon-to-text) | `space.2` |
| `--sg-space-3` | `0.75rem` | 12px — compact padding within list rows and small cards | `space.3` |
| `--sg-space-4` | `1rem` | 16px — standard section padding and card internal spacing | `space.4` |
| `--sg-space-5` | `1.25rem` | 20px — comfortable spacing between sibling controls | `space.5` |
| `--sg-space-6` | `1.5rem` | 24px — major intra-section gap; separator between heading and content | `space.6` |
| `--sg-space-7` | `1.75rem` | 28px — generous top/bottom padding on large sections (no direct tokens.json match) | `admin-layer decision` |
| `--sg-space-8` | `2rem` | 32px — between major page sections | `space.8` |
| `--sg-space-10` | `2.5rem` | 40px — between grouped top-level sections | `space.10` |
| `--sg-space-12` | `3rem` | 48px — page top padding and hero-level gaps | `space.12` |

---

## Type Scale

Sizes follow a ~1.2 minor-third modular scale. Weights map exactly to the brand weight vocabulary.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-text-2xs` | `0.6875rem` | 11px — legal footnotes, timestamps in dense audit rows | `admin-layer decision` |
| `--sg-text-xs` | `0.75rem` | 12px — captions, filter chip labels | `typography.size.xs` |
| `--sg-text-sm` | `0.875rem` | 14px — body text in secondary content areas, table cells | `typography.size.sm` |
| `--sg-text-base` | `1rem` | 16px — default body text | `typography.size.base` |
| `--sg-text-md` | `1.125rem` | 18px — card headings and prominent labels | `typography.size.md` |
| `--sg-text-lg` | `1.45rem` | ~23px — page section headings (H2) | `typography.size.lg` |
| `--sg-text-xl` | `1.875rem` | 30px — page title (H1) | `typography.size.xl` |
| `--sg-text-2xl` | `clamp(1.6rem, 2.3vw, 2.4rem)` | Fluid display heading for dashboards; clamp constrains to readable range | `admin-layer decision` |
| `--sg-weight-regular` | `450` | Default text weight; slightly above 400 for legibility on variable-font axes | `typography.weight.regular` |
| `--sg-weight-medium` | `600` | Strong body emphasis and table headers | `typography.weight.medium` |
| `--sg-weight-semibold` | `700` | Section headings and active navigation labels | `typography.weight.semibold` |
| `--sg-weight-bold` | `800` | Display/hero numbers and page titles | `typography.weight.bold` |
| `--sg-leading-tight` | `1.1` | Dense display text; headings benefit from tighter leading | `typography.lineHeight.tight` |
| `--sg-leading-snug` | `1.3` | Condensed body — audit rows, chip labels | `typography.lineHeight.snug` |
| `--sg-leading-normal` | `1.5` | Default body line height for comfortable reading | `typography.lineHeight.normal` |
| `--sg-leading-relaxed` | `1.6` | Prose paragraphs and instructional copy | `typography.lineHeight.relaxed` |
| `--sg-tracking-tight` | `0` | No extra tracking; default for most body text | `admin-layer decision` |
| `--sg-tracking-wide` | `0.04em` | Label and kicker text; slight spacing improves legibility at small sizes | `admin-layer decision` |
| `--sg-tracking-wider` | `0.08em` | ALL-CAPS labels and overline elements | `admin-layer decision` |

---

## Radii

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-radius-xs` | `0.375rem` | 6px — tight rounding for badges, inline chips, and code blocks | `radius.xs` |
| `--sg-radius-sm` | `0.5rem` | 8px — standard button and input rounding | `radius.sm` |
| `--sg-radius-md` | `0.75rem` | 12px — card and modal corner radius | `radius.md` |
| `--sg-radius-lg` | `1rem` | 16px — large panel and drawer rounding | `admin-layer decision` |
| `--sg-radius-full` | `999px` | Pill/tag shape; high value ensures a full capsule regardless of element height | `radius.full` |

---

## Control Heights

Fixed heights for interactive form controls. No equivalent in `brandbook/tokens.json`; sized by admin UX requirements only.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-control-xs` | `1.75rem` | 28px — compact inline action in dense table rows | `admin-layer decision` |
| `--sg-control-sm` | `2.25rem` | 36px — secondary button and small input | `admin-layer decision` |
| `--sg-control-md` | `2.75rem` | 44px — primary button and standard input; meets WCAG 2.5.8 minimum target size | `admin-layer decision` |
| `--sg-control-lg` | `3rem` | 48px — large call-to-action; generous touch target on mobile | `admin-layer decision` |

---

## Elevation / Shadow

Light-mode values. Dark overrides simplify to outline-only rings to avoid halos on dark backgrounds.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-elev-inset` | `inset 0 0 0 1px var(--sg-color-line)` | 1px inset ring; separates content surfaces without adding depth | `shadow.inset` (partial — references `--sg-color-line` rather than a static value) |
| `--sg-elev-1` | Three-layer box-shadow (0/1px/10px rings) | Floating card depth; three layered rings create natural depth without harsh edges | `shadow.panel` |
| `--sg-elev-2` | Three-layer box-shadow (0/3px/18px rings) | Modal and popover depth; more pronounced lift for overlaying layers | `shadow.lift` |
| `--sg-elev-3` | Three-layer box-shadow (0/12px/30px rings, dark: 1-ring + spread) | Highest depth tier for command palette and critical dialogs; dark override strips soft layers | `admin-layer decision` |

---

## Motion

Five duration tokens and four easing curves validated against emilkowal.ski's research on micro-interaction timing. Three composed transition shorthands for the most common animation patterns.

**Motion budget verdict: ALIGNED, Tier 1 Ratified.**

### Duration Tokens

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-motion-press` | `120ms` | Button press and tap feedback; emilkowal.ski cites 100–160ms as the "feels instantaneous" range for pointer-down responses — ALIGNED | `admin-layer decision` |
| `--sg-motion-pop` | `180ms` | Tooltip and dropdown entrance; emilkowal.ski specifically cites 180ms as the sweet spot for dropdowns that feel snappy without jarring — ALIGNED | `motion.medium` (closest; tokens.json does not have a dedicated pop entry) |
| `--sg-motion-fast` | `140ms` | Tone-swap and hover color transitions; emilkowal.ski places "micro-interactions" in the 100–200ms range — ALIGNED | `motion.fast` |
| `--sg-motion-medium` | `220ms` | Panel slides and card expansions; emilkowal.ski's 150–250ms dropdown range includes 220ms — ALIGNED | `motion.medium` |
| `--sg-motion-slow` | `300ms` | Full-overlay enter (command palette, modal); emilkowal.ski's "under 300ms" ceiling for user-perceived instant — ALIGNED/MARGINAL at ceiling; acceptable for full modal overlays; exit-asymmetry refinement deferred to Phase 187 per D-09 | `admin-layer decision` |

### Easing Tokens

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-ease` | `cubic-bezier(0.2, 0, 0, 1)` | Default easing for hover/tone swaps; fast initial burst then gentle landing — appropriate for state changes where the end state is the goal | `motion.ease` |
| `--sg-ease-out` | `cubic-bezier(0.23, 1, 0.32, 1)` | Enter animation easing; per emilkowal.ski, `ease-out` for enters ensures the content arrives quickly and settles — never use `ease-in` for enters | `motion.ease-out` |
| `--sg-ease-in` | `cubic-bezier(0.4, 0, 1, 1)` | Exit animation easing only; elements accelerate out of the viewport — acceptable exit easing but never used for UI entry per emilkowal.ski guidance | `admin-layer decision` |
| `--sg-ease-spring` | `cubic-bezier(0.34, 1.4, 0.64, 1)` | Pointer-gated micro-delight (e.g. logo bounce, icon pop); overshoots slightly then settles — pointer-only so reduced-motion browsers never see it | `admin-layer decision` |

### Composed Transition Shorthands

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-transition-press` | `transform var(--sg-motion-fast) var(--sg-ease)` | Button scale-down on press; fast + default ease gives a crisp physical click feel | `admin-layer decision` |
| `--sg-transition-tone` | `color, background-color, box-shadow — all at fast + ease` | Hover state color swap; groups the three most common interactive-element properties so they animate in unison without cascade drift | `admin-layer decision` |
| `--sg-transition-enter` | `opacity + transform at medium + ease-out` | Element entrance (slides, reveals); opacity fade combined with slight position shift is the canonical "enter" pattern per emilkowal.ski | `admin-layer decision` |

---

## Focus Ring

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-focus-ring` | `0 0 0 3px color-mix(in oklab, var(--sg-color-brand) 35%, transparent)` | 3px brand-tinted halo; 35% opacity keeps the ring visible without overwhelming surrounding UI; `oklab` perceptual color space ensures consistent luminance across brand hues | `semantic.light.color.focus` |
| `--sg-focus-ring-offset` | `2px` | 2px clearance between the element border and the focus ring; ensures ring does not bleed into adjacent elements or get clipped by overflow:hidden parents | `admin-layer decision` |

---

## Z-Index Ladder

Fixed integer steps for layering contexts. No equivalent in `brandbook/tokens.json`; admin-layer decisions throughout.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-z-base` | `0` | Baseline stacking for in-flow content; explicit zero anchors the ladder | `admin-layer decision` |
| `--sg-z-nav` | `30` | Sticky sidebar and header navigation; must stay above content scroll layers | `admin-layer decision` |
| `--sg-z-dropdown` | `40` | Popover and dropdown menus; must clear nav chrome | `admin-layer decision` |
| `--sg-z-modal` | `50` | Reserved for the Cmd-K command palette and modal dialogs; above dropdowns so palette can overlay open menus | `admin-layer decision` |
| `--sg-z-toast` | `60` | Toast notification layer; must always read above all other content including modals | `admin-layer decision` |

---

## Layout

Container and breakpoint tokens. No equivalent in `brandbook/tokens.json`; admin-layer decisions throughout.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-container-max` | `80rem` | 1280px — max content width; wide enough for admin tables, narrow enough to prevent excessive line lengths on large monitors | `admin-layer decision` |
| `--sg-breakpoint-lg` | `1024px` | Tablet-to-desktop breakpoint; below this, the sidebar collapses and single-column layout activates | `admin-layer decision` |
| `--sg-measure` | `68ch` | Prose measure cap; 65–75ch is the typographic sweet spot for comfortable line length in instructional copy | `admin-layer decision` |

---

## Component Sizing

Small named-value tokens for components that do not fit the regular spacing scale.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-pill-h` | `1.625rem` | Fixed pill/tag height; 26px sits between space-6 (24px) and space-7 (28px) — a deliberate between-scale value | `admin-layer decision` |
| `--sg-pill-gap` | `0.3rem` | Gap between pill icon and label; tighter than space-1 (4px) because pills are compact | `admin-layer decision` |
| `--sg-pill-pad-y` | `0.1875rem` | 3px vertical padding inside pill; combined with fixed height produces consistent pill shape | `admin-layer decision` |
| `--sg-pill-pad-x` | `0.625rem` | 10px horizontal padding inside pill; generous enough for legibility, compact enough for dense tag lists | `admin-layer decision` |
| `--sg-bottom-nav-gap` | `0.125rem` | 2px gap in bottom navigation items; micro-spacing not present in the standard scale | `admin-layer decision` |
| `--sg-code-pad-y` | `0.0625rem` | 1px vertical padding on inline code; just enough lift without disrupting line height | `admin-layer decision` |

---

Cross-reference: `admin-design-contract.md` (dark AA resolution note ~line 207), `brandbook/tokens.json` (brand source of truth), `guides/reference/admin-quality-ledger.md` (L0 row).
