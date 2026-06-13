# Sigra Brand Book

Sigra's brand is not a costume layered on top of the library. It is the public shape of the product contract: a Phoenix authentication library that keeps sensitive behavior updateable while leaving generated application code visible and reviewable.

## Brand Core

**Essence:** Auth you can keep patching after install.

**Positioning:** Sigra is production-minded authentication for Phoenix 1.8+: library-owned security-sensitive behavior plus generated host-owned Phoenix code.

**Audience:** Phoenix and Elixir teams that want more than one-time scaffolding but do not want a hosted identity product.

**Promise:** Ship auth faster without hiding security, policy, routes, schemas, or generated UI from the host application.

**Non-promise:** Sigra is not hosted auth, compliance certification, an authorization engine, SCIM, or a zero-review migration tool.

## Design Principles

- **Proof over mood:** Every visual claim should point back to a real capability, doc, command, or evidence surface.
- **Visible structure:** Diagrams, examples, and layouts should make ownership boundaries legible.
- **Warm restraint:** Use the ember accent and warm neutrals sparingly. Avoid blue-purple SaaS sameness.
- **Semantic tone:** Success, warning, error, and info colors must carry real status and never be the only signal.
- **Small surfaces count:** Favicon, package avatars, badges, code snippets, and docs sidebars matter more than ornamental hero art.

## Visual System

### Color

Use `brandbook/tokens.json` and `brandbook/tokens.css` as the brand token source of truth.

Primary palette:

- Ink: `#151515`
- Warm background: `#f6f5f2`
- Surface: `#ffffff`
- Accent ember: `#c2410c`
- Accent strong: `#9a3412`
- Accent soft: `#fff0e8`
- Dark accent strong: `#fdba74`

Semantic tones:

- Success: `#176b43` on `#ecfdf3`
- Warning: `#a15c00` on `#fff7e6`
- Error: `#b42318` on `#fff1f0`
- Info: `#1d4ed8` on `#eef2ff`

Usage rules:

- Ember is for Sigra identity, primary CTAs, selected states, and ownership-boundary highlights.
- Do not use accent color for every icon or heading.
- Dark mode must use the lightened accent-strong token (`#fdba74`) for text on dark ember-soft surfaces.
- Status color must be paired with text, icon, border, or label.

### Typography

Use system stacks only:

- Sans: `ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`
- Mono: `ui-monospace, "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace`

Rules:

- No web font dependency.
- No negative letter spacing.
- Use mono for commands, package names, paths, and code.
- Marketing headlines can be large, but docs and compact panels should stay dense and readable.

### Layout

- Use an 8px visual rhythm derived from the 4px token scale.
- Prefer full-width bands and constrained inner content over nested cards.
- Cards are for repeated items, examples, and framed tools.
- Docs and README surfaces should prioritize scanning over drama.
- Landing surfaces may use a strong hero, but the actual product signal must be first-viewport visible: install command, architecture diagram, or real docs/product state.

### Logo System

Sigra uses the **Rail Accent tight lockup** as its primary identity system. The mark keeps the host-rail metaphor while reading as a clean, wordmark-led developer brand.

Files:

- Primary light lockup: `logo-primary.svg`
- Primary dark lockup: `logo-primary-dark.svg`
- Subtitle variant lockup: `logo-primary-subtitle.svg`
- Free-standing mark: `logo-mark.svg`
- Monochrome mark: `logo-monochrome.svg`
- Favicon source: `favicon.svg`
- Social card (light): `social-card.svg`
- Social card (dark): `social-card-dark.svg`

Concept: visible host-code rails around a patchable core. The mark represents Sigra's central architecture without diagramming it too literally: library-owned sensitive behavior stays updateable while generated Phoenix code remains visible to the host application.

Rules:

- Use the primary lockup for brandbook, landing, README visuals, and presentation openings.
- Use `logo-primary.svg` on light surfaces and `logo-primary-dark.svg` on dark surfaces.
- The lockup wordmark is outlined from Space Grotesk v2.0 (OFL) wght=700, using opentype.js 2.0.0. Do not recreate the logo as live SVG text or runtime web-font text.
- Use the free-standing mark for UI accents where a tile would feel too heavy.
- Use `favicon.svg` for browser favicon; it uses the same Rail Accent geometry as `logo-mark.svg`.
- Use the free-standing mark for package avatars, social avatars, and compact cards unless a platform requires a separate filled-square export.
- Use monochrome where print, low-color, or restricted-color contexts require it.
- Minimum mark size: 16px favicon, 24px UI, 40px marketing.
- Clearspace: at least one quarter of the mark width.
- Do not rotate, bevel, shadow, gradient-fill, or mascot-extend the mark.
- Do not put the black-wordmark light lockup on a dark surface.
- Preserve the Rail Accent metaphor when creating future variants; active production assets live in the files listed above.

### Integrated Typemark Anatomy

The D4 Linked Rail mark uses two functionally distinct visual elements:

- **Rail-block tittle:** An ember-colored rect (`fill: #c2410c` on light surfaces, `fill: #fdba74` on dark surfaces) positioned above the `i` stem, replacing the conventional dot with a solid brand-colored block.
- **Extended `g` tail:** The `g` descender is extended and aligned under the rail-block tittle, so that the two elements bracket the wordmark horizontally — the tittle at the upper right, the `g` tail at the lower left.

Together they form a single rail system across the wordmark. These elements are functional, not decorative: they encode the "protected core framed by visible host-code rails" metaphor directly in the letterforms. The visual reading is a track or guide rail — an implicit frame around patchable behavior.

The integrated typemark is a formal lockup class distinct from mark-beside-text. It should appear as a complete unit; do not use the rail-block tittle in isolation without the full wordmark.

### Three-Surface Ember Parity Rule

`ember-700: #c2410c` is the canonical Sigra brand accent, consumed by three independent surfaces:

1. `brandbook/tokens.json` — the semantic `accent` token under `semantic.light.color`
2. Admin CSS — `--sg-color-brand: #c2410c` in the generated admin shell
3. Auth CSS — `--sigra-auth-light-accent: #c2410c` in the generated auth form styles

Any new surface carrying the Sigra brand accent must reference the brandbook token rather than hardcoding `#c2410c`. When the token value changes (a major version bump per the Token Change Policy in README.md), all three surfaces must be updated atomically in the same PR.

The `--sigra-auth-*` token family is a consumer of the brandbook's `ember-700` value — it defaults to that value through `--sigra-auth-light-accent`. It is architecturally downstream of the brandbook, not a peer of it.

## Suite Architecture

Sigra is one of seven szTheory OSS libraries that share a coherent visual system: Sigra, Accrue, Mailglass, Threadline, Lockspire, Relyra, and Rulestead.

### Shared vs Per-Library Elements

| Element | Shared across suite | Per-library |
|---------|---------------------|-------------|
| Wordmark typeface | Yes — Space Grotesk v2.0 (OFL) wght=700 | No |
| Design vocabulary | Yes — precision, explicitable contracts, host-owned behavior | No |
| Voice register | Yes — maintainer-grade technical | No |
| Token naming convention | Yes — `--sg-*` namespace established | No |
| Documentation layout | Yes — same docs layout and badge style | No |
| Mark / glyph | No | Yes — distinct per library domain |
| Accent color | No | Yes — unique hue, ≥15° from any sibling on color wheel |
| Domain metaphor in mark | No | Yes — see library list below |

### Library Domain Metaphors

| Library | Domain metaphor | Notes |
|---------|-----------------|-------|
| Sigra | Rails — protected core framed by host-code rails | Ember accent (~15° hue) |
| Accrue | Ledger — accumulation, precision | — |
| Mailglass | Transparency — visible delivery | — |
| Threadline | Trace | — |
| Lockspire | Lock/spire | — |
| Relyra | Reliability | — |
| Rulestead | Governance | — |

### New Library Onboarding Rules

When creating a new szTheory library brandbook:

1. **Inherit the ratified suite wordmark typeface:** Space Grotesk v2.0, wght=700, OFL license. Outline using opentype.js 2.0.0 before committing.
2. **Adopt a unique mark reflecting the library's domain metaphor.** The mark should communicate the domain without diagramming it too literally.
3. **Select an accent hue at least 15° from any existing sibling's accent on the color wheel.** Sigra uses ember (~15°); a new library should occupy a distinct hue region to maintain visual differentiation across the suite.

No other shared-element constraint applies. The library owns its own brandbook and token system.

## UI And Component Guidance

Use brand tokens for docs and marketing components:

- Buttons: primary ember, secondary white/surface with strong border, ghost only for low-priority actions.
- Cards: white or warm-alt surface, 8-12px radius, light border/shadow, no nested card stacks.
- Alerts/callouts: semantic tones with left border or text label. Avoid color-only meaning.
- Code blocks: ink/dark background, warm text, mono font, clear command copy.
- Terminal blocks: show real commands and real outputs; no fake matrix effects.
- Badges: functional metadata only. Do not create decorative badge noise.
- Diagrams: use boxes, rails, arrows, and labels. No meaningless network graphs.

## Voice System

### Voice Principles

- Precise: name the exact surface.
- Honest: pair promises with boundaries.
- Useful: make the next step obvious.
- Calm: avoid urgency and hype.
- Maintainer-grade: write as if a serious adopter will audit the sentence.

### Say / Do Not Say

| Say                                           | Do not say                   |
| --------------------------------------------- | ---------------------------- |
| "Library-owned security-sensitive behavior"   | "Military-grade security"    |
| "Generated host-owned Phoenix code"           | "Seamless integration"       |
| "Review generated diffs before rollout"       | "Zero-effort migration"      |
| "Host-owned authorization and product policy" | "Complete identity platform" |
| "Use `mix sigra.doctor` to inspect wiring"    | "It just works"              |

### Tone By Context

- Marketing: concise promise, one proof point, one boundary.
- README: fast orientation, exact commands, links to depth.
- Docs: explain the contract, then show code.
- Errors: what failed, why it matters, next action.
- Success: what changed and what the user can rely on.
- Warnings: concrete risk and how to reduce it.
- Release notes: changed behavior, compatibility, migration, proof.

## Ready-To-Use Copy

**One-line project description:** Production-minded authentication for Phoenix 1.8+.

**140-character description:** Sigra pairs an updateable auth core with generated Phoenix code your team can review, edit, and ship.

**GitHub repo description:** Authentication for Phoenix 1.8+: sessions, MFA, passkeys, OAuth, audit seams, and generated host-owned code.

**Hex.pm package description:** Phoenix authentication library with hardened primitives, generators for host-owned code, and explicit seams for MFA, passkeys, OAuth, audit, mail, and admin workflows.

**README opening paragraph:** Sigra gives Phoenix teams an updateable authentication core while keeping generated application code visible in the host repo. You get sessions, password flows, MFA, passkeys, OAuth, audit seams, and optional admin tooling without treating sensitive auth behavior as one-time scaffolding.

**Landing hero headline:** Auth you can keep patching after install.

**Landing subheadline:** Sigra pairs library-owned security-sensitive behavior with generated Phoenix code your team can review, adapt, and operate.

**Primary CTA:** Read the docs

**Secondary CTA:** View GitHub

**Feature blurbs:**

- **Update the sensitive core:** Crypto, token, MFA, passkey, plug, and behavior fixes can arrive through dependency updates.
- **Keep host code visible:** Schemas, routes, LiveViews, mailers, policy, and deployment choices stay in your application.
- **Operate with boundaries:** Sigra names what it owns, what the host owns, and where optional integrations begin.

**Why this exists:**

- Scaffolds age, but authentication requirements keep moving.
- Hosted auth is not the right ownership tradeoff for every Phoenix team.
- Combining four auth libraries leaves too many seams unexplained.

**Error:** The reset link is expired. Request a new link to continue.

**Empty state:** No audit rows yet. Authentication events appear here after users sign in, change credentials, or trigger admin actions.

**Success:** Session revoked. The user will need to sign in again on that device.

**Release announcement:** Sigra now ships a source-controlled brand system: pressure-test audit, tokens, SVG logo assets, visual specimens, voice rules, and a static HTML brand book under `brandbook/`. No runtime code or generated templates changed.

## Landing Page Blueprint

1. Hero: Sigra name, promise, subheadline, install snippet, docs/GitHub CTAs.
2. Problem: generated auth starts useful but sensitive behavior keeps changing.
3. Solution: library-owned core plus generated host code.
4. Install: dependency, installer, migration, run.
5. Minimal example: one flow from generated host code into library function.
6. Core benefits: patchable core, reviewable host code, explicit seams.
7. How it works: architecture diagram.
8. Use cases: greenfield Phoenix, migration evaluation, SaaS baseline, audit/admin needs.
9. Why not just: `phx.gen.auth`, hosted auth, composed legacy libraries.
10. Proof: CI, launch evidence, security posture, docs.
11. CTAs: docs, GitHub, contribution, disclosure.
12. Footer: license, package links, security policy.

## Docs And README Blueprint

1. Opening promise.
2. Installation.
3. Quickstart.
4. Minimal example.
5. Concepts and ownership boundaries.
6. API overview.
7. Common recipes.
8. Troubleshooting.
9. Design rationale.
10. Contributing and license.

## Accessibility And Durability

- Text/background contrast must target WCAG AA.
- Color cannot be the only status cue.
- SVGs must have `title` and `desc` where they communicate meaning.
- Logo must work on transparent, light, dark, and monochrome contexts.
- No web font files, embedded raster images, or opaque design-tool exports.
- Motion should be minimal; keyboard-frequent interactions should not animate.

## Repo Policy

- Keep this system under `brandbook/`.
- Prefer text, CSS, JSON, HTML, and SVG.
- Do not commit generated PNG/PDF exports by default.
- If public README/HexDocs surfaces adopt these assets, do that in a separate focused change.
