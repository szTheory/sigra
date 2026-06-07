# Sigra Brand System Pressure-Test Audit

**Source material:** repository evidence only: README, package metadata, launch docs, SECURITY, Sigra 1.0 contract, admin design contract, and v1.34 admin UI tokens.

**Audit stance:** The current repo has a strong product/voice posture but did not have a complete committed brand book. This audit treats the existing repo voice and admin UI system as the inherited brand system, then identifies what needed to become explicit.

## Section 1 - Executive Judgment

The current Sigra brand is strong enough to build from strategically, but it was not implementation-ready before this milestone. The repo already communicates the right product truth: Phoenix-native authentication, library-owned sensitive behavior, generated host code, explicit non-goals, and proof over hype. That is a credible OSS/devtools center.

It is distinct enough in voice and positioning. It is less distinct visually because the public surfaces had no committed logo, tokenized brand palette, social card, or reproducible landing/docs examples. The admin UI had a mature component/token discipline, but that discipline lived inside the example app and admin contract rather than a public brand system.

The system was under-specified, not over-designed. The highest-leverage improvement is not a redesign; it is extracting the existing credible posture into a buildable package: semantic tokens, SVG logo system, microcopy rules, source-controlled specimens, and an HTML review surface.

What should not change: Sigra's blunt technical honesty. The boundary-first README and launch docs are the brand's strongest asset. Do not replace them with generic "secure, seamless, powerful" product language.

## Section 2 - Brand DNA Extraction

| Dimension | Decision |
| --- | --- |
| Brand essence | Production-minded Phoenix auth that remains patchable after install. |
| Audience | Phoenix 1.8+ teams, Elixir library maintainers, SaaS builders, backend-heavy product engineers, security-conscious operators. |
| Emotional tone | Calm, competent, accountable, low-drama. |
| Technical promise | Library-owned sensitive core plus generated host-owned Phoenix code. |
| Visual metaphor | A protected core framed by visible host-code rails. |
| Personality traits | Precise, pragmatic, trustworthy, explicit, generous with caveats. |
| Anti-traits | Hype, fake futurism, black-box magic, enterprise fog, mascot novelty, gradient SaaS sameness. |
| Design principles | Evidence before polish; visible structure; warm restraint; tone has semantic meaning; small surfaces matter. |
| Voice principles | Name the tradeoff, say what is owned by whom, prefer exact nouns, avoid empty adjectives. |
| This should feel like | A well-maintained Phoenix library with a serious release process and an unusually clear integration contract. |
| This should never feel like | A hosted identity startup landing page pretending to be an OSS library. |

## Section 3 - Pressure-Test Scorecard

| Area | Score | Why | Risk | Recommended fix |
| --- | ---: | --- | --- | --- |
| Distinctiveness | 7 | Hybrid lib+generator positioning is clear and unusual. | Visual system could still look like generic devtool UI if not constrained. | Keep the protected-core/code-rails metaphor and warm restrained palette. |
| Developer credibility | 9 | README and launch docs are concrete, bounded, and proof-oriented. | Marketing additions could dilute trust. | Preserve boundary-first copy rules. |
| Elixir ecosystem fit | 8 | Phoenix-native, docs-heavy, understated. | Too much landing-page polish could look off-ecosystem. | Keep marketing surfaces functional and docs-adjacent. |
| Visual coherence | 6 | Admin UI tokens are coherent. Public brand assets were missing. | Future assets could diverge from admin UI. | Commit brand tokens and examples. |
| Logo readiness | 3 | No committed mark existed. | Ad hoc avatars or badges would appear. | Use the simple SVG system now committed. |
| Color-system readiness | 6 | Admin palette is strong and accessibility-tested in places. | Raw colors alone are not enough for docs/marketing. | Add semantic token roles and light/dark guidance. |
| Typography readiness | 7 | Practical system stack works for OSS. | No hierarchy guidance for marketing/docs. | Define type roles and examples. |
| Design-token readiness | 5 | Admin has tokens; brand did not. | Duplicate or incompatible token names. | Use `brandbook/tokens.*` as brand collateral SOT. |
| UI component readiness | 7 | Admin contract is excellent for app UI. | Marketing/docs components were implicit. | Add button, callout, code, terminal, docs and README examples. |
| Docs/README usefulness | 8 | Current README is unusually useful. | Header/social treatment lacked assets. | Add README/header specimen and copy blocks. |
| Marketing usefulness | 6 | Positioning exists, landing architecture did not. | Vague claims during launch work. | Add landing blueprint and approved copy. |
| Voice/microcopy usefulness | 7 | Voice is visible in docs. | Error/success/empty state tone not codified. | Add microcopy patterns. |
| Accessibility | 7 | Admin dark contrast issue was already found and fixed in v1.34. | Brand collateral could ignore contrast. | Add semantic contrast rules and monochrome logo. |
| Repo/source-control readiness | 4 | No brand directory existed. | Binary asset sprawl. | Keep `brandbook/` text/SVG-first. |
| Long-term maintainability | 8 | Repo culture values evidence and contracts. | Brandbook could become aspirational dead weight. | Keep artifacts small, citable, and tied to implementation. |

## Section 4 - Stress Tests

| Surface | Current guidance before this milestone | Needed addition |
| --- | --- | --- |
| GitHub repo header | Strong README copy, no visual system. | Primary logo, README specimen, concise copy. |
| README hero section | Existing text is credible. | Optional visual header that does not replace technical TL;DR. |
| README badges | Existing badges are fine. | Keep functional badges; avoid decorative badge pile. |
| Hex.pm package page | Package description is specific. | Short description variants. |
| HexDocs page | Strong docs architecture. | Tokenized docs visuals and logo usage. |
| Docs sidebar | Admin contract suggests disciplined IA. | Sidebar specimen and hierarchy rules. |
| Code block styling | Existing docs are plain. | Code/terminal tokens. |
| Terminal snippet | Existing install commands work. | Terminal specimen and command-copy style. |
| API reference page | ExDoc handles most UI. | Voice rule: API docs stay exact, not promotional. |
| Landing page hero | No committed architecture. | Hero copy and SVG specimen. |
| Feature section | README table exists. | Three benefit blurbs tied to actual surfaces. |
| Comparison section | Alternatives doc is strong. | "Why not just..." blueprint. |
| Blog post header | Launch docs exist. | Social card and copy pattern. |
| Release announcement | Existing announcement is credible. | Release note voice rules. |
| Social preview card | Missing. | SVG source card. |
| Favicon | Missing. | `favicon.svg`. |
| App icon | Missing. | Icon-only mark. |
| Small monochrome logo | Missing. | `logo-monochrome.svg`. |
| Dark-mode page | Admin tokens cover it. | Brand dark semantic tokens. |
| Light-mode page | Admin tokens cover it. | Brand light semantic tokens. |
| Conference slide | No guidance. | Use social-card composition; no fake screenshots. |
| Diagram/architecture illustration | README has Mermaid. | SVG diagram style. |
| Error/empty/success states | Admin components cover app UI. | Microcopy examples for docs/marketing. |
| Example UI component library | Admin contract covers internal components. | Brandbook component specimen for docs/landing. |
| Mobile landing page | Not specified. | HTML brand book and hero specimen use responsive rules. |
| Sticker/swag | Low priority. | Monochrome mark only; no extra swag set now. |

## Section 5 - Gaps And Risks

### Critical

- No committed brand home existed. Without `brandbook/`, future assets would scatter through docs, guides, and generated templates.
- No logo/favicon/social preview source existed. This blocks credible package/repo presentation.
- No semantic brand tokens existed outside admin CSS. Raw colors alone would cause inconsistent landing/docs work.

### Important

- Voice guidelines were implicit. Good writers could preserve the tone; contributors would not have enough rules.
- Marketing architecture was missing. A landing page could drift into generic SaaS copy despite strong repo positioning.
- Visual examples were missing. Engineers would have to infer layout, code block, diagram, and terminal treatments.

### Nice-To-Have

- Automated visual regression for `brandbook/index.html`.
- PNG exports for social platforms that reject SVG.
- Optional slide template if conference talks become a real use case.

## Section 6 - Recommended Brand Book Upgrades

Add, not redesign:

- Positioning: "Production-minded authentication for Phoenix 1.8+."
- Visual principles: warm restraint, visible structure, semantic status, no decorative gradients/orbs.
- Logo system: primary wordmark, mark, monochrome mark, favicon, social card.
- Token system: raw palette plus semantic roles, states, code blocks, callouts, focus, disabled, selected.
- Voice and microcopy: say/not-say rules, error/success/warning/empty examples.
- Landing/docs blueprint: sections, copy roles, examples, comparison pattern.
- Repo policy: all brand files under `brandbook/`, SVG-first, no binary exports by default.

Remove or avoid:

- Mascots.
- Abstract hexagons or generic node networks.
- Claims like "seamless", "next-generation", "enterprise-grade" unless a specific proof link follows.
- Decorative screenshots that do not explain real implementation choices.

## Section 7 - Design Token Specification

Committed files:

- `brandbook/tokens.json`
- `brandbook/tokens.css`

Token groups:

- Raw palette: ink, paper, warm neutrals, ember accent, semantic tone families, dark neutrals.
- Semantic colors: bg, surface, surface-alt, text, muted, border, accent, success, warning, error, info, code, disabled, selected, focus.
- Typography: system sans and mono stacks; practical OSS-safe hierarchy.
- Spacing: 4px base scale.
- Radius: restrained 6-12px defaults; no pill overuse except badges.
- Border/elevation: light outlines and minimal shadows only where hierarchy needs it.
- States: default, hover, active, focus, disabled, selected, success, warning, error, info, subtle, muted.

## Section 8 - Logo And Mark System

Sigra should use a combination lockup plus icon-only mark. It does not need a mascot. It should not rely on a text-only wordmark because favicons, social avatars, and package cards need a compact mark.

Recommended system:

- Primary logo: `brandbook/logo-primary.svg`
- Icon-only mark: `brandbook/logo-mark.svg`
- Monochrome mark: `brandbook/logo-monochrome.svg`
- Dark/light use: same SVGs on transparent background; use monochrome when contrast or print requires it.
- Favicon: `brandbook/favicon.svg`
- Social avatar: icon-only mark on ember or warm surface.
- Minimum size: mark 16px only for favicon; 24px for UI; 40px for marketing.
- Clearspace: at least one quarter of mark width.
- Misuse: do not add shadows, gradients, bevels, mascot additions, or rotate the rails.

## Section 9 - Visual Examples And Screenshot Guidance

| Artifact | Purpose | Path | Worth creating now |
| --- | --- | --- | --- |
| Palette specimen | Verify color roles visually. | `examples/palette.svg` | Yes |
| Typography specimen | Lock type hierarchy and font policy. | `examples/typography.svg` | Yes |
| Button/card examples | Component state guidance. | `examples/component-states.svg` | Yes |
| Code block example | Docs/landing snippets. | `examples/code-block.svg` | Yes |
| Terminal screenshot style | Install command presentation. | `examples/terminal.svg` | Yes |
| README header mock | Repo presentation. | `examples/readme-header.svg` | Yes |
| Landing hero mock | Future website direction. | `examples/landing-hero.svg` | Yes |
| Docs page mock | HexDocs/docs structure guidance. | `examples/docs-page.svg` | Yes |
| Social card | Share preview source. | `social-card.svg` | Yes |
| Architecture diagram | Hybrid model visual. | `examples/architecture-diagram.svg` | Yes |
| PNG screenshots | Platform-specific exports. | not committed by default | No |

## Section 10 - Brand Voice And Microcopy

Voice principles:

- Lead with the technical tradeoff.
- Use exact nouns: library, generator, generated host code, security core, seam, policy, audit row.
- Put boundaries beside promises.
- Write like maintainers, not sales.
- Keep CTAs plain: "Read the docs", "View GitHub", "Run the installer".

Use:

- "Generated host code"
- "Library-owned security-sensitive behavior"
- "Reviewable Phoenix modules"
- "Explicit non-goals"
- "Host-owned policy"

Avoid:

- "Seamless"
- "Magic"
- "Next-generation"
- "Enterprise-grade" without a proof link
- "Secure by default" without naming the default

Examples:

- One-line: "Production-minded authentication for Phoenix 1.8+."
- 140-character: "Sigra pairs an updateable auth core with generated Phoenix code your team can review, edit, and ship."
- GitHub: "Authentication for Phoenix 1.8+: sessions, MFA, passkeys, OAuth, audit seams, and generated host-owned code."
- Error: "The token is expired. Request a new link to continue."
- Empty: "No audit rows yet. Authentication events appear here after users sign in or change account settings."
- Success: "Session revoked. The user will need to sign in again on that device."

## Section 11 - Landing Page And Docs Blueprint

Landing page:

1. Hero: name, one-line promise, install snippet, docs/GitHub CTAs.
2. Problem: scaffolds age; auth edges keep changing.
3. Solution: library-owned sensitive core plus generated host code.
4. Minimal example: dependency, installer, migration.
5. Benefits: patchable core, reviewable app code, explicit seams.
6. How it works: diagram of Hex package -> host repo.
7. Use cases: greenfield Phoenix, migration evaluation, SaaS auth baseline.
8. Why not just: phx.gen.auth, hosted auth, composed legacy libraries.
9. Proof: CI, docs, launch evidence, security posture.
10. Footer: docs, GitHub, disclosure, license.

Docs/README:

1. Opening promise.
2. Installation.
3. Quickstart.
4. Example.
5. Concepts.
6. API overview.
7. Recipes.
8. Troubleshooting.
9. Design rationale.
10. Contribution and license.

## Section 12 - Repo-Ready Artifact Plan

Commit:

- All files under `brandbook/`.
- SVG sources, not raster exports.
- `tokens.json` and `tokens.css`.
- Static `index.html`.

Generate but do not commit by default:

- PNG exports for social platforms.
- PDF exports.
- Screenshot captures of `index.html`.

Manual review needed:

- Any public README/HexDocs visual replacement.
- Any trademark/legal decision beyond the internal Sigra mark.
- Any future use of third-party imagery or font files.

## Section 13 - Prioritized Action Plan

Do now:

- Commit `brandbook/` with audit, brand book, tokens, logo SVGs, examples, and static HTML.
- Keep the system self-contained and source-control friendly.

Do next:

- If a public landing page is built, start from `brandbook/examples/landing-hero.svg` and `brandbook/brand-book.md`.
- Export `social-card.svg` to PNG only for a concrete target.

Defer:

- Slide templates.
- Stickers or swag.
- Automated visual regression for the brandbook.

Do not do:

- Full redesign of README voice.
- Mascot.
- Decorative gradients/orbs/node networks.
- Binary-heavy asset packs.

## Section 14 - Final Quality Gate

- Could a designer build from this? Yes: visual principles, tokens, logo rules, and specimens are explicit.
- Could an engineer implement from this? Yes: tokens, CSS variables, SVGs, and HTML are source-controlled.
- Could a maintainer keep it consistent? Yes: rules are small and tied to repo posture.
- Could a contributor understand it? Yes: README and brand book explain intent and file use.
- Could it support marketing without becoming cheesy? Yes, if copy stays boundary-first.
- Could it survive dark mode, small sizes, docs pages, and social previews? Yes, with committed dark tokens, favicon, monochrome mark, and social card.
- Does it feel specific to Sigra? Yes: the protected-core/code-rails metaphor and voice map to Sigra's actual architecture.
- Does it avoid unnecessary brand thrash? Yes: it preserves the existing product truth and makes it buildable.
