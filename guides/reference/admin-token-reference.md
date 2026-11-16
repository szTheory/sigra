# Admin Token Reference

Per-token rationale and brand reference for every `--sg-*` custom property in the `sigra_admin.css` `:root` layer — the canonical source for understanding why each value exists, not just what it is.

---

## Color — Neutrals

Light-mode values from `:root`. Dark-mode overrides noted inline. The Brand Ref column names paths in `brand/tokens.json` (the Kiln brand book, v2.0); a row marked "kept, no book equivalent" keeps its pre-Kiln value because the book has no token for it.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-ink` | `#1F1A17` (light) / `#F3EEE8` (dark) | Primary text: Soot on light, Chalk on dark; maximum contrast on the page and panel grounds | `color.light.soot` / `color.dark.chalk` |
| `--sg-color-muted` | `#5F554D` (light) / `#B8ABA0` (dark) | Secondary and supporting text; meets WCAG AA on the page, panel and selected-row grounds | `color.secondary.muted-soot` / `color.secondary.muted-chalk` |
| `--sg-color-subtle` | `#F7F3EE` (light) / `#17120F` (dark) | Page canvas background: Paper on light, Char on dark; the warm tint differentiates admin from plain white hosts | `color.light.paper` / `color.dark.char` |
| `--sg-color-panel` | `#ffffff` (light) / `#221B17` (dark) | Card, form field and table surface, on top of the page background: White on light, Char Surface on dark | `color.light.white` / `color.dark.char-surface` |
| `--sg-color-panel-alt` | `#fbfaf7` (light) / `#25221e` (dark) | Alternating row and nested-section surface; slight warm shift from panel | kept, no book equivalent |
| `--sg-color-line` | `#DDD3C8` (light) / `#3A2F28` (dark) | Default divider and card edge: Paper Line on light, Char Line on dark; opaque (it was an alpha value). Never the only edge of a control: a control's edge is `--sg-color-control-edge` | `color.light.paper-line` / `color.dark.char-line` |
| `--sg-color-line-strong` | `rgba(21, 21, 21, 0.16)` (light) / `rgba(255, 255, 255, 0.16)` (dark) | Emphasis border (selected controls); slightly stronger than line; alpha-based so it composites on any background | kept, no book equivalent |

---

## Color — Brand

Light-mode values from `:root`. Dark overrides noted. See the dark AA remediation note below.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-brand` | `#c2410c` (light) / `#F08A55` (dark) | Primary accent: Kiln on light, Kiln Bright on dark. Reserved for the one main button per screen and the logo square; the label on it is `--sg-color-on-brand` | `color.light.kiln` / `color.dark.kiln-bright` |
| `--sg-color-brand-strong` | `#9a3412` (light) / `#F08A55` (dark) | Text-grade accent: links, the focus ring and the current tab label. Kiln Deep on light, Kiln Bright on dark; never raw Kiln as small text on Char. See the dark AA note below | `color.secondary.kiln-deep` / `color.dark.kiln-bright` |
| `--sg-color-brand-solid` | `#9a3412` (light) / `#F08A55` (dark) | Solid filled badge and chip foreground; same value as brand-strong in both themes | `color.secondary.kiln-deep` / `color.dark.kiln-bright` |
| `--sg-color-brand-fill-hover` | `#c74712` (light) / `#F4A27C` (dark) | Hover fill for brand-colored surfaces. Light is kept (white on it is 4.84:1). Dark is forced: Char on the previous dark fill was 3.84:1, and Char on the lighter Kiln tone is 9.12:1 | light: kept, no book equivalent / dark: `color.code.keyword-dark` |
| `--sg-color-brand-fill-active` | `#9a3412` (light) / `#E07A45` (dark) | Active and pressed fill. Light is kept (white on it is 7.31:1). Dark is forced: Char on the previous dark fill was 2.54:1, and Char on a darker Kiln Bright is 6.23:1 | light: kept, no book equivalent / dark: derived, a darker Kiln Bright with no tokens.json entry |
| `--sg-color-brand-soft` | `#fff0e8` (light) / `rgba(243, 90, 16, 0.16)` (dark) | Low-saturation tint for selected rows, chips, and soft callouts; preserves legibility at low contrast ratios | kept, no book equivalent |
| `--sg-color-on-brand` | `#ffffff` (light) / `#17120F` (dark) | Text and icons on `--sg-color-brand`: white on Kiln (5.18:1), Char on Kiln Bright (7.50:1). White on Kiln Bright is 2.48:1, which is why dark flips to Char | `color.dark.char` (dark); white on light |
| `--sg-color-on-brand-solid` | `#ffffff` (light) / `#17120F` (dark) | Text on solid-brand badges; Char in dark because dark brand-solid is Kiln Bright | `color.dark.char` (dark); white on light |
| `--sg-logo-rail-accent` | `#fdba74` | Fills the theme-switch active segment and its glow; the same light orange in Light and Dark | kept, no book equivalent |
| `--sg-logo-rail-ember` | `#c2410c` (light) / `#F08A55` (dark) | The logo's square colour (Kiln on light, Kiln Bright on dark); no CSS consumer, the name is kept | `color.logo.kiln` / `color.logo.kiln-bright` |
| `--sg-logo-core` | `#1F1A17` (light) / `#F3EEE8` (dark) | The logo's letter colour (Soot on light, Chalk on dark); no CSS consumer, the name is kept | `color.light.soot` / `color.dark.chalk` |

### Dark AA Remediation Note

In the dark override block (`@media (prefers-color-scheme: dark)`, and the explicit Dark shell block that mirrors it), `--sg-color-brand-strong` and `--sg-color-brand-solid` are Kiln Bright `#F08A55`. The value `#fdba74`, which v1.34 introduced to clear WCAG AA on the dark `brand-soft` tint (`rgba(243, 90, 16, 0.16)` over `#1f1d1a` measured about 1.88:1 with the original `#9a3412`), is retired. Kiln Bright clears 4.5:1 on the dark grounds and on that tint (5.59:1 over Char Surface).

The dark label on a Kiln Bright fill is Char `#17120F` (`--sg-color-on-brand`, 7.50:1). White on Kiln Bright is 2.48:1, so dark `--sg-color-on-brand` and `--sg-color-on-brand-solid` are Char, and the explicit Light block restates `--sg-color-brand` and `--sg-color-on-brand` so a Light choice on a dark OS keeps Kiln with a white label. The dark hover and active fills are forced for the same reason: Char on the previous dark fills (`#c74712`, `#9a3412`) is 3.84:1 and 2.54:1.

---

## Color — Kiln Additions

Added by the Kiln migration. Each is a literal hex declared in all four token blocks (light `:root`, dark `@media`, explicit Light, explicit Dark), never a `var()` alias, so it survives an explicit theme. Two already have consumers: `--sg-color-sunken` is the table-header ground and `--sg-color-control-edge` is the edge of interactive controls (secondary and danger buttons, filter chips and the theme switch). The other eight are defined and tested token to token only, and their consumers arrive in Phase 262.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-status-active` | `#1D6B3C` (light) / `#86C99B` (dark) | Status word, Active (a green text colour, never the only way to tell a status) | `color.status.active-text-light` / `color.status.active-text-dark` |
| `--sg-status-unconfirmed` | `#7A5F00` (light) / `#D6B957` (dark) | Status word, Unconfirmed (ochre) | `color.status.unconfirmed-text-light` / `color.status.unconfirmed-text-dark` |
| `--sg-status-locked` | `#7A5F00` (light) / `#D6B957` (dark) | Status word, Locked (ochre) | `color.status.locked-text-light` / `color.status.locked-text-dark` |
| `--sg-status-deleting` | `#7A5F00` (light) / `#D6B957` (dark) | Status word, Deleting (ochre) | `color.status.deleting-text-light` / `color.status.deleting-text-dark` |
| `--sg-status-suspended` | `#5F554D` (light) / `#B8ABA0` (dark) | Status word, Suspended (muted) | `color.status.suspended-text-light` / `color.status.suspended-text-dark` |
| `--sg-color-selected` | `#EADFD2` (light) / `#33281F` (dark) | Ground of the selected row, darker than the page so the row is plainly picked out | `color.secondary.selected-paper` (light); dark from `brand.json` `contrastPairs[selected-row]` (tokens.json has no entry) |
| `--sg-color-selected-edge` | `#C2410C` (light) / `#F08A55` (dark) | The 2px rule on the selected row and the 8px square before the current tab's name | `color.light.kiln` / `color.dark.kiln-bright` |
| `--sg-color-current-tab` | `#9A3412` (light) / `#F08A55` (dark) | Current-tab label; text-grade accent | `color.secondary.kiln-deep` / `color.dark.kiln-bright` |
| `--sg-color-sunken` | `#EFE9E1` (light) / `#120E0C` (dark) | Table-header ground; opaque so a sticky header stays solid over scrolling rows | `color.secondary.sunken-paper` / `color.code.ground-dark` |
| `--sg-color-control-edge` | `#857569` (light) / `#8B7D72` (dark) | Border of an input or button; 3:1 or more against the panel. Dividers keep `--sg-color-line` | `color.secondary.control-edge` (light); dark from `BRAND.md` (tokens.json has no entry) |

---

## Color — Semantic Status

Light-mode values from `:root`. Dark overrides noted. All eight tones are kept as they were: the book has no equivalent, `sigra_auth.css` carries the same ember fallbacks and a test pins admin `risk`, `warn` and `ok` equal to them, and they already clear WCAG AA on the Kiln grounds. The book's own status colours ship as the Kiln additions above.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-risk` | `#b42318` (light) / `#f8a39c` (dark) | Destructive actions, error states, and risk alerts; red hue triggers immediate attention | kept, no book equivalent |
| `--sg-color-risk-soft` | `#fff1f0` (light) / `rgba(248, 113, 113, 0.16)` (dark) | Background tint for risk callouts and invalid form fields; low saturation prevents alarm fatigue | kept, no book equivalent |
| `--sg-color-warn` | `#a15c00` (light) / `#f5c451` (dark) | Caution states, pending review, and advisory notices; amber hue signals attention without urgency | kept, no book equivalent |
| `--sg-color-warn-soft` | `#fff7e6` (light) / `rgba(245, 196, 81, 0.16)` (dark) | Background tint for warning callouts; warm wash without the severity of risk-soft | kept, no book equivalent |
| `--sg-color-ok` | `#176b43` (light) / `#5dd1a0` (dark) | Success confirmations, active/verified states, and positive health indicators | kept, no book equivalent |
| `--sg-color-ok-soft` | `#ecfdf3` (light) / `rgba(52, 211, 153, 0.16)` (dark) | Background tint for success callouts and confirmed-action rows | kept, no book equivalent |
| `--sg-color-info` | `#1d4ed8` (light) / `#9db8f5` (dark) | Informational notices, contextual help, and neutral status indicators | kept, no book equivalent |
| `--sg-color-info-soft` | `#eef2ff` (light) / `rgba(120, 150, 245, 0.16)` (dark) | Background tint for info callouts; cooler wash distinguishes informational from actionable states | kept, no book equivalent |

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

Sizes follow a ~1.2 minor-third modular scale. The book allows weights 400, 600 and 700 only, so the four weight tokens take those three values (`--sg-weight-semibold` and `--sg-weight-bold` share 700 and both names are kept). The two font tokens at the end of the table are theme-invariant: they are declared in the light `:root` only and never restated in a theme block. By default Sigra brings no typeface of its own; the book stack is opt-in.

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
| `--sg-weight-regular` | `400` | Default text weight; the book allows 400, 600 and 700 only (it was 450) | book type rules; no weight token in `brand/tokens.json` |
| `--sg-weight-medium` | `600` | Strong body emphasis and table headers | `typography.weight.medium` |
| `--sg-weight-semibold` | `700` | Section headings and active navigation labels | `typography.weight.semibold` |
| `--sg-weight-bold` | `700` | Display/hero numbers, page titles and labels; shares 700 with semibold and both names are kept (it was 800) | book type rules; no weight token in `brand/tokens.json` |
| `--sg-leading-tight` | `1.1` | Dense display text; headings benefit from tighter leading | `typography.lineHeight.tight` |
| `--sg-leading-snug` | `1.3` | Condensed body — audit rows, chip labels | `typography.lineHeight.snug` |
| `--sg-leading-normal` | `1.5` | Default body line height for comfortable reading | `typography.lineHeight.normal` |
| `--sg-leading-relaxed` | `1.6` | Prose paragraphs and instructional copy | `typography.lineHeight.relaxed` |
| `--sg-tracking-tight` | `0` | No extra tracking; default for most body text | `admin-layer decision` |
| `--sg-tracking-wide` | `0.04em` | Label and kicker text; slight spacing improves legibility at small sizes | `admin-layer decision` |
| `--sg-tracking-wider` | `0.08em` | ALL-CAPS labels and overline elements | `admin-layer decision` |
| `--sg-font-sans` | `inherit` | Default: the host's own typeface. A custom property set to `inherit` is unset at the root, so `.sg-admin-shell` falls back to inheriting the host's family, and form controls inherit it from the shell. Opt-in: `'Instrument Sans', system-ui, -apple-system, 'Segoe UI', sans-serif`, the book stack, enabled by self-hosting the Instrument Sans woff2 file and setting this token on the admin shell. The installer ships no font binary and `sigra_admin.css` has no font-face rule | `font.sans` |
| `--sg-font-mono` | `ui-monospace, 'SF Mono', Consolas, monospace` | Default: a system monospace stack for `.sg-code` and `code` in the admin, with ligatures off and a slashed zero where the face has one (this replaces the inherited sans those elements used before, a visible change covered by the minor-release policy). Opt-in: `'Red Hat Mono', ui-monospace, 'SF Mono', Consolas, monospace`, the book stack, enabled by self-hosting the Red Hat Mono woff2 file and setting this token on the admin shell. The installer ships no font binary and `sigra_admin.css` has no font-face rule. Red Hat Mono has no arrow glyphs, so no arrow appears inside code | `font.mono` |

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

Seven duration tokens and four easing curves validated against emilkowal.ski's research on micro-interaction timing. Five composed transition shorthands for the most common animation patterns.

**Motion budget verdict: ALIGNED, Tier 1 Ratified.**

### Duration Tokens

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-motion-press` | `120ms` | Button press and tap feedback; emilkowal.ski cites 100–160ms as the "feels instantaneous" range for pointer-down responses — ALIGNED | `admin-layer decision` |
| `--sg-motion-pop` | `180ms` | Tooltip and dropdown entrance; emilkowal.ski specifically cites 180ms as the sweet spot for dropdowns that feel snappy without jarring — ALIGNED | `motion.medium` (closest; tokens.json does not have a dedicated pop entry) |
| `--sg-motion-fast` | `140ms` | Tone-swap and hover color transitions; emilkowal.ski places "micro-interactions" in the 100–200ms range — ALIGNED | `motion.fast` |
| `--sg-motion-medium` | `220ms` | Panel slides and card expansions; emilkowal.ski's 150–250ms dropdown range includes 220ms — ALIGNED | `motion.medium` |
| `--sg-motion-slow` | `300ms` | Full-overlay enter (command palette, modal); emilkowal.ski's "under 300ms" ceiling for user-perceived instant — ALIGNED/MARGINAL at ceiling; acceptable for full modal overlays; exit-asymmetry refinement deferred to Phase 187 per D-09 | `admin-layer decision` |
| `--sg-motion-exit` | `160ms` | Phase 187 D-06 additive exit asymmetry; exits complete faster than medium enters while preserving all Phase 186 duration values | `admin-layer decision` |
| `--sg-motion-tooltip` | `180ms` | Phase 187 D-06 tooltip-specific timing; keeps tooltip reveal timing explicit without retuning the Phase 186 `--sg-motion-pop` value | `admin-layer decision` |

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
| `--sg-transition-exit` | `opacity + transform at exit + ease-in` | Phase 187 D-06 exit asymmetry; accelerates disappearing surfaces without altering the locked Phase 186 enter and slow-overlay durations | `admin-layer decision` |
| `--sg-transition-tooltip` | `opacity + transform at tooltip + ease-out` | Phase 187 D-06 tooltip-specific timing; gives tooltip/help surfaces a named shorthand while preserving the Phase 186 value lock | `admin-layer decision` |

---

## Focus Ring

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-focus-ring` | `0 0 0 var(--sg-focus-ring-offset) var(--sg-color-subtle), 0 0 0 calc(var(--sg-focus-ring-offset) + 2px) var(--sg-color-brand-strong)` | Two layers: a page-ground gap of `--sg-focus-ring-offset`, then a 2px ring in `--sg-color-brand-strong` (Kiln Deep on light, Kiln Bright on dark; 6.61:1 and 7.50:1 on the page). The gap keeps the ring apart from a Kiln-filled button. The previous 35% halo was 1.67:1 on Paper and failed the book's 3:1 focus pair. It uses theme-variant tokens, so it is declared in all four token blocks | `brand.json` `contrastPairs[focus]` |
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

## Token Conformance (COMP-03)

The `--sg-*` token set in this document is kept complete by automated CI guards (Phase 207 D-06 / D-07, PATH A):

**Token completeness (D-06):** `scripts/ci/admin-token-completeness.sh` diffs the `--sg-*` custom properties defined in `:root` blocks of `sigra_admin.css` (both light and dark `@media (prefers-color-scheme: dark)`) against the backtick token names documented in this file. The guard fails CI on any divergence — undocumented token or stale doc row — making the documentation self-enforcing. Verified baseline: **112 unique `--sg-*` tokens** across both `:root` blocks exactly match the 112 documented backtick tokens.

**Raw-hex conformance (CHECK 2):** `scripts/ci/admin-css-conformance.sh` CHECK 2 verifies that no raw hex colour literal appears outside a `:root` block. Fails CI on any violation.

**Raw-px conformance (CHECK 3, D-07 PATH A):** `scripts/ci/admin-css-conformance.sh` CHECK 3 verifies that no raw pixel value appears in token-eligible property contexts (`font-size`, `gap`, `row-gap`, `column-gap`, `margin`, `width`, `height`, etc.) outside a `:root` block. The check excludes provably non-token-candidate values: negative margins (e.g. `margin: -1px`), `1px`/`0px` terminal values used in visually-hidden clip patterns (`clip: rect(0,0,0,0)` context), and `:root` blocks themselves. All three checks exit 0 on the current `sigra_admin.css` — zero violations. The legitimate raw-px idioms present in the CSS (media-query breakpoints, 1px hairline borders, box-shadow geometry, micro transform nudges, `border-radius: 999px` pill, accessibility clip) are all excluded by the CHECK 3 filters and do not bypass the `--sg-space-*` / `--sg-text-*` token scales.

---

Cross-reference: `admin-design-contract.md` (dark AA resolution note ~line 207), `brandbook/tokens.json` (brand source of truth), `guides/reference/admin-quality-ledger.md` (L0 row).
