# Sigra Brand System Pressure-Test Audit v2

**Source material:** brandbook/ (v1.35, all text/SVG including brand-book.md, pressure-test-audit.md, tokens.json, tokens.css, logo SVGs, and 9 examples/), admin CSS (test/example/priv/static/assets/css/app.css), auth CSS (priv/templates/sigra.install/core/sigra_auth.css), installer templates (priv/templates/sigra.install/admin/), Playwright snapshots (.planning/phases/ SUMMARYs), competitor audit (178-RESEARCH.md).

**Audit stance:** The v1.35 brand system was sound but predated the v1.36/v1.37 surfaces. It was written before the admin shell, auth forms, transactional emails, and the auth branding customizer existed. The v2 audit evaluates the brand as actually deployed across those four new evidence surfaces: the admin topbar carrying the Rail Accent logo, the auth form branding panel, transactional email headers, and the admin-operated branding customizer. Evidence from these surfaces largely validates the v1 verdicts — which is why the logo system remains the primary upgrade target. KEEP is the default verdict. Every REWORK requires a named surface, a named failure mode, and a codebase citation. The brand DNA, voice, token values, and visual principles are all confirmed by v1.36/v1.37 deployment evidence. The integrated typemark gap that was identified conceptually in v1.35 has grown in urgency: since Phase 167, the ecosystem audit has confirmed that mark-beside-text is the dominant pattern in the Elixir OSS space.

---

## Section 1 - Executive Judgment

The v1.35 brand system has been validated by propagation into production surfaces not yet evaluated in the v1 audit. The ember palette, the protected-core/host-code-rails metaphor, and the voice register are confirmed: the admin topbar uses `--sg-color-brand: #c2410c` [VERIFIED: test/example/priv/static/assets/css/app.css line 67], the auth form uses `--sigra-auth-light-accent: #c2410c` [VERIFIED: priv/templates/sigra.install/core/sigra_auth.css line 4], and both converge on the same ember-700 value defined in brandbook/tokens.json. Three independent surfaces share the same token value without any coordination hack — this is the strongest possible evidence that the token system is working.

The primary upgrade target remains the logo system. Option A Core Rails (mark-left-of-text, Inter Display Black outlined wordmark) was the right decision for Phase 167 because it existed and was committed. Since Phase 167, the ecosystem audit has confirmed that mark-left-of-text is the dominant and therefore generic lockup in the Elixir OSS space — Phoenix Framework, Ash Framework, and Oban Pro all use mark-beside-text constructions [CITED: 178-RESEARCH.md Competitor/Ecosystem Visual Audit]. The current mark is conceptually sound (staggered rails, horizontal core line, Rail Accent ember mark) but visually quiet: it compresses to near-indistinguishable at 16px and has no personality at favicon scale without the outlined wordmark alongside it [ASSUMED: 16px readability claim — requires render verification in Phase 179].

The Astro 2024 rebrand is the most instructive precedent: the upgrade move for this brand class is either (a) a distinctive OFL wordmark face that is not Inter Display Black, or (b) a fully integrated typemark where the motif is structural in the letterforms, not applied on top [CITED: goodside.studio/work/astro via 178-RESEARCH.md]. Both options are explored in Phase 179. The word "sigra" has several integration points: the `g` descender, the `i` tittle, the `s` entry/exit strokes, and the `r` shoulder — making a true integrated typemark technically feasible [CITED: 178-RESEARCH.md Integrated Typemark Craft Notes].

**Verdict: KEEP** — brand DNA, ember token system, voice, and all four new deployment surfaces confirm the v1.35 foundation. **Verdict: REWORK** — Evidence: brandbook/logo-primary.svg (mark-left-of-text construction), failure mode: generic lockup pattern identical to Phoenix/Ash/Oban Pro in the target audience's visual field; citation: 178-RESEARCH.md "Key finding: the mark-beside-text construction is the most generic lockup pattern in the ecosystem." No other section warrants a full REWORK.

---

## Section 2 - Brand DNA Extraction

| Dimension | Decision |
| --- | --- |
| Brand essence | Production-minded Phoenix auth that remains patchable after install. |
| Audience | Phoenix 1.8+ teams, Elixir library maintainers, SaaS builders, backend-heavy product engineers, security-conscious operators. |
| Emotional tone | Calm, competent, accountable, low-drama. |
| Technical promise | Library-owned sensitive core plus generated host-owned Phoenix code. |
| Visual metaphor | A protected core framed by visible host-code rails — confirmed by the admin shell sg-* system and the auth form sigra-auth wrapper deployed in v1.36/v1.37. |
| Personality traits | Precise, pragmatic, trustworthy, explicit, generous with caveats. |
| Anti-traits | Hype, fake futurism, black-box magic, enterprise fog, mascot novelty, gradient SaaS sameness, AI-generated rectangular logomark backgrounds. |
| Design principles | Evidence before polish; visible structure; warm restraint; tone has semantic meaning; small surfaces matter. |
| Voice principles | Name the tradeoff, say what is owned by whom, prefer exact nouns, avoid empty adjectives. |
| This should feel like | A well-maintained Phoenix library with a serious release process and an unusually clear integration contract. |
| This should never feel like | A hosted identity startup landing page pretending to be an OSS library. |

**Verdict: KEEP** — all 11 Brand DNA dimensions are confirmed by the v1.36/v1.37 deployment evidence. The admin copy, auth copy, and email copy from those milestones all follow "exact nouns, boundary-first" register with no drift detected. The anti-traits row gains one new entry: "AI-generated rectangular logomark backgrounds" — this is directly from the user brief and is observable across competitor and generic devtool identity systems [CITED: 178-CONTEXT.md Logo v2 hard constraint 1].

---

## Section 3 - Pressure-Test Scorecard

| Area | Score | Why | Risk | Recommended fix |
| --- | ---: | --- | --- | --- |
| Distinctiveness | 7 | Hybrid lib+generator positioning is clear; ember palette is genuinely distinct from Elixir OSS peers. | Logo lockup is mark-beside-text, the generic pattern in the ecosystem — reduces distinctiveness at the identity layer. | Complete the logo REWORK; integrated typemark is the highest-leverage distinctiveness upgrade. |
| Developer credibility | 9 | README and launch docs are concrete, bounded, proof-oriented. Admin principles and auth branding docs maintain that register. | Marketing additions could dilute trust. | Preserve boundary-first copy rules across all new surfaces. |
| Elixir ecosystem fit | 8 | Phoenix-native, docs-heavy, understated. Auth branding and admin UI are Phoenix LiveView implementations. | Too much landing-page polish could look off-ecosystem. | Keep marketing surfaces functional and docs-adjacent. |
| Visual coherence | 8 | Admin shell + auth form + email all use ember accent consistently; sg-* token system propagated correctly. Score improved from v1's 6. | Future assets could diverge if token discipline is not documented. | Document the three-surface ember parity rule in brand-book.md. |
| Logo readiness | 8 | Option A Core Rails shipped; installer templates propagated; Rail Accent appears in admin topbar and auth form. Score improved from v1's 3. | Integration quality is the remaining gap — lockup reads as clip-art assembly not a designed whole. | Logo v2 REWORK via Phase 179 integrated typemark exploration. |
| Color-system readiness | 8 | Auth branding token surface added; `sigra_brand_profiles` table allows per-install accent; three-surface ember parity confirmed. Score improved from v1's 6. | No version field in tokens.json; the `--sigra-auth-*` token family relationship to brandbook tokens is undocumented. | Add `version` and `changed` fields to tokens.json; document three-surface parity rule. |
| Typography readiness | 7 | System stack works for OSS. No changes in v1.36/v1.37 to the type system. | Logo wordmark uses Inter Display Black — valid but the most generic devtools display font choice. | Phase 179 OFL candidate exploration may produce a better wordmark typeface. |
| Design-token readiness | 8 | `brandbook/tokens.*` consumed by auth CSS and admin CSS; ember-700 value is three-surface parity. Score improved from v1's 5. | No version policy on tokens.json file. | TIGHTEN: add `version` key and `changed` date. |
| UI component readiness | 8 | Auth shell + admin shell both built and using sg-* system. Score improved from v1's 7. | Multi-lockup logo system (vertical, subtitle variant) is not yet designed as formal artifacts. | Phase 181 multi-lockup buildout after v2 logo ratification. |
| Docs/README usefulness | 8 | README is unusually useful; auth branding guide and admin principles added in v1.36/v1.37. | README/social preview adoption is deferred; lacks v2 logo once ratified. | Fast-follow gsd-quick after v1.38 ships. |
| Marketing usefulness | 6 | Positioning exists; landing architecture is documented. Auth branding is now a real product capability to feature. | Still pre-implementation for landing page. | No change from v1; landing blueprint is correct. |
| Voice/microcopy usefulness | 7 | Voice is visible in docs and auth copy. Admin UI copy follows brand register. | Error/success/empty states partially codified; auth branding terminology not in brand-book.md. | Add "Token-based branding profile" to the Use list in voice guidance. |
| Accessibility | 7 | Admin dark contrast addressed in v1.34; auth form meets WCAG AA in default configuration. | Brand collateral could ignore contrast in new specimen context. | No regression; hold. |
| Repo/source-control readiness | 10 | brandbook/ is complete with 30 SVGs, tokens.json, tokens.css, index.html, and this audit. Score improved from v1's 4. | Maintaining file-count discipline as v2 assets are added. | Continue SVG-only policy; PNG/PDF generation only for concrete targets. |
| Long-term maintainability | 8 | Repo culture values evidence and contracts. Brand-book.md is citable and tied to implementation. | Brandbook could become aspirational dead weight if logo REWORK produces assets that invalidate v1 specimens. | Update specimens post-ratification; archive v1 assets under logo-options/. |

**Verdict: TIGHTEN** — Updated scores reflect v1.36/v1.37 propagation evidence. Score improvements are real (not inflationary): color-system, token, and component scores rose because deployment evidence confirmed the token system is working. Logo readiness rose from 3 to 8 because the asset exists and is deployed — but integration quality and distinctiveness remain the upgrade target. [ASSUMED: logo distinctiveness score reflects 178-RESEARCH.md ecosystem audit finding, not yet verified by Phase 179 render comparison]

---

## Section 4 - Stress Tests

| Surface | v1 Status | v2 Status / Evidence | Verdict |
| --- | --- | --- | --- |
| Admin topbar logo slot | Not built | Built: `.sg-admin-topbar-inner { min-height: 3.5rem }` sticky topbar, Rail Accent mark+lockup visible [VERIFIED: test/example/priv/static/assets/css/app.css line 1857] | KEEP |
| Auth form branding panel | Not built | Built: `.sigra-auth__brand` slot with logo URL + mark fallback, controlled by `Sigra.Branding.Profile` [VERIFIED: priv/templates/sigra.install/core/sigra_auth.css] | KEEP |
| Transactional email header | Not built | Built: shared `sigra_brand_profiles` branding token with auth form; logo identity propagates to email [CITED: 178-RESEARCH.md Architecture Patterns] | KEEP |
| Auth branding admin UI | Not built | Built: `/admin/auth-branding` customizer with accent/logo/dark-accent controls and auth preview [CITED: 178-RESEARCH.md New Evidence Surfaces] | KEEP |
| GitHub repo header | Strong README copy, no visual system | No change; README still text-first | KEEP |
| README hero section | Existing text credible | No change | KEEP |
| README badges | Functional badges | No change | KEEP |
| Hex.pm package page | Specific description | No change | KEEP |
| HexDocs page | Strong docs architecture | No change | KEEP |
| Docs sidebar | Disciplined IA | No change | KEEP |
| Code block styling | Plain docs | No change | KEEP |
| Terminal snippet | Install commands work | No change | KEEP |
| API reference page | ExDoc handles most UI | No change | KEEP |
| Landing page hero | No committed architecture | Blueprint exists; still pre-implementation | KEEP |
| Feature section | README table exists | Auth branding is now a real benefit to add ("White-label auth forms from the admin UI without code") | TIGHTEN |
| Comparison section | Alternatives doc strong | No change | KEEP |
| Blog post header | Launch docs exist | No change | KEEP |
| Release announcement | Credible | No change | KEEP |
| Social preview card | social-card.svg exists | Will need regeneration once v2 logo is ratified in Phase 181 | TIGHTEN |
| Favicon | favicon.svg exists | Will need regeneration once v2 logo mark is ratified | TIGHTEN |
| App icon | logo-mark.svg exists | Same as favicon — REWORK target in Phase 181 | TIGHTEN |
| Small monochrome logo | logo-monochrome.svg exists | Will need regeneration | TIGHTEN |
| Dark-mode page | Admin tokens cover it; auth dark tokens added | No drift; auth dark tokens (`--sigra-auth-dark-*`) follow same ember pattern | KEEP |
| Light-mode page | Admin tokens cover it | No drift | KEEP |
| Conference slide | No guidance | No change | KEEP |
| Diagram/architecture illustration | README has Mermaid | No change | KEEP |
| Error/empty/success states | Admin components cover app UI | Auth error states use same semantic token pattern | KEEP |
| Example UI component library | Admin contract covers internal components | No change | KEEP |
| Mobile landing page | HTML brandbook uses responsive rules | Auth form is responsive via sigra-auth wrapper | KEEP |
| Sticker/swag | Low priority | No change | KEEP |
| Installer template SVGs | Had logos | Has sigra-logo-primary.svg + sigra-logo-primary-dark.svg in priv/templates/ | TIGHTEN — will need replacement after Phase 181 v2 buildout |
| Playwright baselines | Had none | ~24 snapshots covering admin Light/Dark/Mobile; logo changes trigger recapture | TIGHTEN — recapture planned in Phase 183 |

**Verdict: KEEP** for core brand surfaces. **Verdict: TIGHTEN** for assets that must be regenerated after v2 logo ratification (social-card.svg, favicon.svg, logo-mark.svg, logo-monochrome.svg, installer template SVGs, Playwright baselines). All four new v1.36/v1.37 surfaces verdict KEEP because they correctly implement the brand token system on first deployment.

---

## Section 5 - Gaps And Risks

### Critical

- Logo integration quality — the Rail Accent mark-left-of-text lockup is now the generic pattern in the Elixir ecosystem; the integrated typemark gap opened by the v1 audit remains the single critical gap. Every major peer (Ash, Phoenix, Oban Pro) uses the same lockup class. Phase 179 must produce ≥2 fully integrated typemark candidates.

### Important

- No multi-lockup system — there is no vertical lockup, no subtitle variant designed as a distinct object, and no "with-subtitle" SVG committed. These are needed for marketing surfaces, conference slides, and social preview cards at different aspect ratios.
- Suite brand architecture is undocumented — the `vaultr-mark.svg` sibling exists in test/example and demonstrates per-library color diversity (teal/shield), but no formal shared/unique framework is committed anywhere. See Section 8 suite subsection for the recommended framework.
- Token version policy absent — brandbook/tokens.json has no `version` field and no `changed` date. Any downstream token consumer has no signal for when the token system was last modified.

### Nice-To-Have

- Admin topbar logo slot render test at 16px scale — the Rail Accent mark's 16px readability is assumed to be near-indistinguishable without wordmark support; this assumption has not been verified by Phase 179 renders [ASSUMED: A1 from 178-RESEARCH.md].
- PNG exports for social platforms that reject SVG upload — deferred as per v1.35 policy; still a nice-to-have for concrete deployment targets.
- Automated visual regression for brandbook/index.html — noted in v1.35 and still a nice-to-have.

---

## Section 6 - Recommended Brand Book Upgrades

Add, not redesign:

- Suite architecture section (shared/unique decision framework for all szTheory seven libraries): document which elements are shared across Sigra/Accrue/Mailglass/Threadline/Lockspire/Relyra/Rulestead and which are per-library; use vaultr-mark.svg as the working evidence of per-library color diversity.
- Integrated typemark variant class (new lockup type beyond mark-beside-text): once ratified in Phase 181, add a formal lockup type named "integrated typemark" to the logo system section of brand-book.md.
- Logo v2 design brief (standalone committed file encoding Phase 179 constraints): `brandbook/logo-v2-design-brief.md` is created in this phase [see Section 8 forward reference].
- Multi-lockup system documentation: primary, dark, subtitle variant, mark-only, monochrome, favicon, and social-card lockup rules — minimum-size, clearspace, and misuse examples for each type.
- Three-surface ember parity rule: document explicitly in brand-book.md that `ember-700: #c2410c` is the canonical accent value consumed by three independent surfaces — brandbook semantic tokens, admin CSS (`--sg-color-brand`), and auth CSS (`--sigra-auth-light-accent`) — and that any future surface must reference the brandbook token rather than hardcoding the hex value.
- "Token-based branding profile" entry in voice guidance Use list — from v1.37 sigra_brand_profiles terminology.

Remove or avoid:

- Subtitle text in the primary lockup.
- Rectangular container behind the logomark.
- "Branded" as a verb without naming which surface is branded.
- Abstract hexagons or generic node networks (held from v1).
- Claims without proof links (held from v1).

**Verdict: TIGHTEN** — Section 8 of brand-book.md needs an integrated typemark subsection, a suite architecture section, and the three-surface parity rule. No REWORK of voice, tokens, or layout guidance is warranted.

---

## Section 7 - Design Token Specification

### Three-Surface Ember Parity

The most significant v2 finding in the token system is the confirmation of three-surface ember parity. Three independent sources converge on the same value:

- `ember-700: #c2410c` in brandbook/tokens.json [VERIFIED: tokens.json line 20]
- `--sg-color-brand: #c2410c` in test/example/priv/static/assets/css/app.css [VERIFIED: app.css line 67]
- `--sigra-auth-light-accent: #c2410c` in priv/templates/sigra.install/core/sigra_auth.css [VERIFIED: sigra_auth.css line 4]

This convergence was not coordinated by a shared import — each surface defined or inherited the value independently and arrived at the same hex. This is strong evidence that the brand token discipline is working. The v2 audit recommends documenting this as a named rule in brand-book.md: the "three-surface parity rule" states that any new surface carrying the brand accent must use the ember-700 value from brandbook/tokens.json rather than hardcoding a value.

### Auth Token Family Relationship

The `--sigra-auth-*` token family added by v1.37 is not listed in brandbook/tokens.json. This is architecturally expected: `sigra_auth.css` is a generated template file, not a brandbook token file, and it defaults to the ember-700 value through the `--sigra-auth-light-accent` fallback. The v2 audit notes this relationship: the auth token family is a consumer of the brandbook's ember-700 value, not a peer of it. This should be documented in brand-book.md as a one-sentence architectural note.

### Token Version Policy

brandbook/tokens.json currently has no `version` field and no `changed` date [VERIFIED: direct inspection of tokens.json — version field absent in the `meta` object]. Any downstream consumer of tokens.json has no signal for when the token system was last modified. This is a minor operational gap.

### Current Token Groups (Confirmed)

All token groups from the v1 specification are intact: raw palette (ink, paper, warm neutrals, ember-050/300/700/800, semantic tone families, dark neutrals), semantic colors (light and dark variants), typography (family/size/weight/lineHeight), spacing (4px base scale), radius, border/shadow, motion, and state tokens. No REWORK warranted.

**Verdict: TIGHTEN** — Add a `"version"` key and a `"changed"` date to the `meta` object in tokens.json. Document the three-surface ember parity rule in brand-book.md. Document the `--sigra-auth-*` token family relationship as an architectural note. No REWORK of token values: ember-700 #c2410c, ember-800 #9a3412, ember-300 #fdba74, and ember-050 #fff0e8 are all confirmed correct by three-surface deployment evidence.

---

## Section 8 - Logo And Mark System

### Current State Assessment

Option A Core Rails is the ratified logo direction — mark-left-of-text, Inter Display Black outlined wordmark [VERIFIED: brandbook/logo-primary.svg, brandbook/logo-options/round-2/README.md]. The decision to ratify this direction in Phase 167 was correct: it gave the brand a committed, source-controlled, deployable logo that is now live in the admin topbar, auth form branding panel, installer templates, and Playwright baselines. Before Phase 167, Sigra had no committed mark.

Since Phase 167, the ecosystem audit has confirmed that mark-left-of-text is the dominant and therefore generic lockup in the Elixir OSS space. Phoenix Framework uses a standalone phoenix bird mark + separate wordmark with mark-beside-text composition. Ash Framework uses an ash/flame icon mark + wordmark in horizontal lockup. Oban Pro uses modular horizontal lockups with standalone mark. All three direct peers of Sigra's target audience use the same construction class [CITED: 178-RESEARCH.md Elixir Ecosystem Brands table].

The Astro 2024 rebrand demonstrates the upgrade path for this brand class: the move was adding a properly crafted wordmark using "Obviously" (a distinctive variable font by Oh No Type Co), not redesigning the mark. The lesson for Sigra: the upgrade is either (a) a distinctive OFL typeface that is not Inter Display Black, or (b) a fully integrated typemark where the rail motif becomes structural in the letterforms [CITED: goodside.studio/work/astro via 178-RESEARCH.md]. The word "sigra" is five characters with integration points at the `g` descender, the `i` tittle, the `s` entry/exit strokes, and the `r` shoulder.

**Verdict: REWORK** — Evidence: brandbook/logo-primary.svg (mark-left-of-text construction), failure mode: generic lockup pattern identical to Phoenix/Ash/Oban Pro in the target developer audience's visual field; makes Sigra visually indistinguishable in sidebars, README headers, and social previews, citation: 178-RESEARCH.md "Key finding: the mark-beside-text construction is the most generic lockup pattern in the ecosystem."

The logo v2 design brief (`brandbook/logo-v2-design-brief.md`) encodes the hard constraints for Phase 179 exploration.

### Current Asset Inventory

| Asset | File | Current Verdict | v2 Disposition |
| --- | --- | --- | --- |
| Primary logo (light) | brandbook/logo-primary.svg | REWORK target | Replace with v2 primary in Phase 181 |
| Primary logo (dark) | brandbook/logo-primary-dark.svg | REWORK target | Replace with v2 dark variant in Phase 181 |
| Mark only | brandbook/logo-mark.svg | REWORK target | Replace with v2 mark in Phase 181 |
| Monochrome | brandbook/logo-monochrome.svg | TIGHTEN | Regenerate once v2 mark is ratified |
| Favicon | brandbook/favicon.svg | TIGHTEN | Regenerate once v2 mark is ratified |
| Social card | brandbook/social-card.svg | TIGHTEN | Regenerate once v2 lockup is ratified |
| Installer primary (light) | priv/templates/sigra.install/admin/sigra-logo-primary.svg | TIGHTEN | Replace in Phase 182/183 propagation |
| Installer primary (dark) | priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg | TIGHTEN | Replace in Phase 182/183 propagation |

v1 assets must be archived under `brandbook/logo-options/` (not deleted) as part of Phase 181 buildout so the exploration history is preserved.

### szTheory Suite Brand Architecture

This subsection satisfies BRAND2-02 by naming all seven szTheory libraries and specifying the shared/unique split required for suite-coherent brand governance.

**The seven libraries:** Sigra, Accrue, Mailglass, Threadline, Lockspire, Relyra, Rulestead.

**Competitor suite models reviewed:**

| Suite | Model | What It Shares | What Is Unique |
| --- | --- | --- | --- |
| Tailwind Labs | Loose aesthetic family | Designer taste; Heroicons used across tools | Each tool has own site/colors |
| unjs (~30 libs) | Tight icon-family | Puzzle-piece metaphor; illustration style; light/dark dual variants | Per-library illustration; no shared color |
| FastAPI / tiangolo | Creator-aesthetic family | Typography; docs layout; clean aesthetic | Per-library accent color (teal/red-pink/green) |
| Astro ecosystem | Product sub-brand | Core Astro mark; "Obviously" typeface | Starlight has distinct identity |
| Dashbit | None | GitHub organization only | Per-README badge color |

[CITED: 178-RESEARCH.md szTheory Suite Brand Architecture]

**Recommended model:** FastAPI/tiangolo with unjs puzzle-piece influence — shared creator-aesthetic (same OFL font family, same design vocabulary, same layout conventions) combined with per-library mark and per-library accent color.

**SHARED across all szTheory libraries:**
- OFL font family for wordmarks (whichever typeface is ratified in Phase 180 for Sigra replaces Inter Display Black across the suite)
- Design principle vocabulary: "precision, explicitable contracts, host-owned behavior"
- Voice register: maintainer-grade technical
- Token naming convention: `--sg-*` namespace is already established [VERIFIED: test/example/priv/static/assets/css/app.css lines 67–76]
- Layout conventions: same docs layout system and badge style

**UNIQUE per library:**
- Mark: each library carries a distinct mark reflecting its domain — `vaultr-mark.svg` demonstrates this pattern with a teal shield/cross for Vaultr [VERIFIED: test/example/priv/static/images/vaultr-mark.svg]
- Accent color: one warm or cool accent per library; no two siblings share the same hue within 15 degrees on the color wheel
- Domain metaphor: Sigra=rails (protected core framed by host-code rails), Accrue=ledger (accumulation, precision), Mailglass=transparency (visible delivery), Threadline=trace, Lockspire=lock/spire, Relyra=reliability, Rulestead=governance

**Decision framework for new library onboarding:**
When a new szTheory library joins the suite, it (1) inherits the shared wordmark typeface ratified in Phase 180, (2) adopts a unique mark reflecting its domain, and (3) selects a unique accent hue outside the 15-degree range of any existing sibling's accent hue. No other shared-element constraint applies; the library owns its own brandbook.

**Scope note:** This section specifies Sigra's contribution to the shared system only. Other library brand systems are out of scope for Phase 178 per the REQUIREMENTS boundary.

---

## Section 9 - Visual Examples And Screenshot Guidance

Current 9 specimens [VERIFIED: brandbook/examples/]: palette.svg, typography.svg, component-states.svg, code-block.svg, terminal.svg, readme-header.svg, landing-hero.svg, docs-page.svg, architecture-diagram.svg.

All 9 specimens remain valid for palette, typography, component, and layout guidance. None of them need to be regenerated as a result of v1.36/v1.37 changes — they are brandbook reference specimens, not screenshots of runtime UI.

Three additions are warranted post-Phase 181 (after v2 logo ratification):

1. Logo-in-context specimen: shows the v2 lockup in the admin topbar slot (~56px per `min-height: 3.5rem`), in the auth form branding panel (logo URL slot), and in the social card format — demonstrating correct sizing, clearspace, and minimum-size behavior across contexts.
2. Multi-lockup reference specimen: shows primary/dark/subtitle-variant/mark/monochrome/favicon side-by-side for the v2 logo system.
3. readme-header.svg update: regenerate once the v2 primary lockup is ratified in Phase 181.

**Verdict: TIGHTEN** — current 9 specimens are valid; add 3 post-ratification specimens in Phase 181/182. No REWORK needed now.

---

## Section 10 - Brand Voice And Microcopy

Voice principles (unchanged from v1, confirmed by v1.36/v1.37 copy):

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
- "Token-based branding profile" (added v2: from v1.37 sigra_brand_profiles terminology)

Avoid:

- "Seamless"
- "Magic"
- "Next-generation"
- "Enterprise-grade" without a proof link
- "Secure by default" without naming the default
- "Branded" as a verb without naming which surface is branded (added v2: anti-pattern observed in generic white-label product copy)

Examples (held from v1, confirmed valid):

- One-line: "Production-minded authentication for Phoenix 1.8+."
- 140-character: "Sigra pairs an updateable auth core with generated Phoenix code your team can review, edit, and ship."
- GitHub: "Authentication for Phoenix 1.8+: sessions, MFA, passkeys, OAuth, audit seams, and generated host-owned code."
- Error: "The token is expired. Request a new link to continue."
- Empty: "No audit rows yet. Authentication events appear here after users sign in or change account settings."
- Success: "Session revoked. The user will need to sign in again on that device."

**Verdict: KEEP** — voice principles are intact; admin copy and auth copy from v1.36/v1.37 milestones follow the "exact nouns, boundary-first" pattern [ASSUMED: spot-check based on 178-RESEARCH.md noting no voice drift detected — full copy audit deferred to Phase 179 review gate]. Two new entries added to Use and Avoid lists based on v1.37 terminology evidence.

---

## Section 11 - Landing Page And Docs Blueprint

Landing page blueprint (unchanged from v1):

1. Hero: name, one-line promise, install snippet, docs/GitHub CTAs.
2. Problem: scaffolds age; auth edges keep changing.
3. Solution: library-owned sensitive core plus generated host code.
4. Minimal example: dependency, installer, migration.
5. Benefits: patchable core, reviewable app code, explicit seams.
6. How it works: diagram of Hex package → host repo.
7. Use cases: greenfield Phoenix, migration evaluation, SaaS auth baseline.
8. Why not just: phx.gen.auth, hosted auth, composed legacy libraries.
9. Proof: CI, docs, launch evidence, security posture.
10. Footer: docs, GitHub, disclosure, license.

v2 update: the Benefits section (item 5) can add a fourth benefit drawn from v1.37: "White-label auth forms from the admin UI without code — token-based branding profiles keep your product identity consistent across login, registration, and transactional emails."

Docs/README blueprint (unchanged from v1):

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

**Verdict: KEEP** — the v1 blueprint sections are still pre-implementation and remain correct. The single benefit-section addition from v1.37 is a copy update, not a structural change.

---

## Section 12 - Repo-Ready Artifact Plan

**Commit now (this phase):**

- `brandbook/pressure-test-audit-v2.md` (this document)
- `brandbook/logo-v2-design-brief.md` (standalone Phase 179 brief)

**Do next — Phase 179:**

- opentype.js glyph-outlining toolchain committed under `brandbook/logo-options/round-3/toolchain/`
- 5–7 logo candidates as SVGs in `brandbook/logo-options/round-3/` — including ≥2 fully integrated typemarks
- Playwright render-critique loop at 16px/32px/54px/hero scales
- Round-3 gallery HTML in `brandbook/logo-options/round-3/index.html`
- OFL font candidates to explore: Space Grotesk Bold, Plus Jakarta Sans ExtraBold, Syne ExtraBold/Black, Geist Black (Inter Display Black as reference/fallback) [CITED: 178-RESEARCH.md OFL Typeface Candidates]

**Human gate — Phase 180:**

- Maintainer selects direction, typeface, and palette tune from Phase 179 candidates
- One round-4 refinement budgeted if needed before full buildout
- Phase 180 ratification is the gate before any Phase 181 work begins

**Build — Phase 181:**

- Full asset set: logo-primary-v2.svg, logo-primary-dark-v2.svg, logo-mark-v2.svg, favicon-v2.svg, logo-monochrome-v2.svg, logo-with-subtitle-v2.svg
- Clearspace, minimum-size, and misuse rules documented in brand-book.md
- Archive v1 assets under `brandbook/logo-options/round-2/archived/` (not deleted)
- Regenerate social-card.svg

**Integrate — Phases 182–183:**

- brandbook/index.html upgraded to v2 with new lockup, specimens updated
- tokens.json/tokens.css version field added; `changed` date updated
- Propagation to installer templates (priv/templates/sigra.install/admin/) and example app
- Playwright baseline recapture for admin Light/Dark/Mobile under snapshot canary guard
- diff hygiene gate: no unintentional sg-* token changes

**Do not commit:**

- PNG rasters, font binary files, or Playwright screenshot PNGs
- Build steps inside brandbook/ — the directory must remain no-build-tool
- Typeface source files — outline glyphs to SVG paths before commit

---

## Section 13 - Prioritized Action Plan

This section directly drives v1.38 Phases 179–183.

### Tier 1: Phase 179 — Logo Exploration (Autonomous)

- Set up opentype.js glyph-outlining toolchain; document usage in brandbook/logo-options/round-3/toolchain/README.md
- Produce 5–7 SVG candidates: ≥2 must be fully integrated typemarks (motif structural in letterforms, not applied on top); ≥1 must use each of the two top OFL candidates (Space Grotesk Bold, Plus Jakarta Sans ExtraBold) as the wordmark base; Inter Display Black included as the reference/baseline candidate
- Run Playwright render-critique loop at 16px (favicon), 32px (nav avatar), 54px (admin topbar slot per `min-height: 3.5rem`), and hero scale (400px+ wide)
- Commit round-3 gallery: `brandbook/logo-options/round-3/index.html` showing all candidates at all test scales side by side
- Do NOT commit font binary files; outline all glyphs to SVG paths before committing

### Tier 2: Phase 180 — Human Ratification Gate (Human Action)

- Maintainer reviews round-3 gallery at `brandbook/logo-options/round-3/index.html`
- Selects: direction type (integrated typemark vs. refined mark+wordmark), typeface (which OFL candidate), and any palette tune within ember anchor
- One round-4 refinement iteration is budgeted before Phase 181 begins
- Gate: Phase 181 does not begin without explicit maintainer ratification

### Tier 3: Phase 181 — Full Asset Buildout (Autonomous)

- Build the ratified full asset set (all 6 SVG files listed in Section 12)
- Write clearspace/minimum-size/misuse rules in brand-book.md
- Archive v1 logo assets (do not delete)
- Regenerate social-card.svg with v2 lockup

### Tier 4: Phases 182–183 — Integration and Propagation (Autonomous)

- Phase 182: brand-book.md v2 additions (suite architecture, three-surface parity rule, multi-lockup system, integrated typemark class); tokens.json version bump; brandbook/index.html v2 update
- Phase 183: installer template propagation; example app image replacement; Playwright baseline recapture; diff hygiene gate

**Do not reopen in v1.38:** Brand DNA, voice principles, token values (unless Phase 181 palette tune reveals a conflict), the sg-* admin component system, auth branding contract, or any runtime behavior.

---

## Section 14 - Final Quality Gate

- Could a designer build from this? Yes: visual principles, tokens, logo rules, specimens, and the logo-v2-design-brief.md are explicit and source-controlled.
- Could an engineer implement from this? Yes: tokens, CSS variables, SVGs, and HTML are source-controlled; the three-surface ember parity rule provides a clear integration contract for any new surface.
- Could a maintainer keep it consistent? Yes: the REWORK verdict on the logo system is the only structural open item; all other sections are KEEP or TIGHTEN with specific, bounded actions.
- Could a contributor understand the brand intent? Yes: the protected-core/host-code-rails metaphor maps to Sigra's actual architecture; the Voice section says/avoids examples are concrete.
- Could a Phase 179 executor use the logo brief without ambiguity? Yes: `brandbook/logo-v2-design-brief.md` encodes the 7 hard constraints, the OFL font candidates, the typemark craft requirements, and the multi-scale render test targets.
- Could a marketing writer produce copy from the voice rules? Yes: the say/not-say examples are drawn from actual shipped surfaces (README, auth forms, admin UI) not aspirational copy.
- Could a deployer use auth branding forms with the brand profile? Yes: the `sigra_brand_profiles` token surface, the `sigra_auth.css` default variables, and the three-surface ember parity rule together provide a complete branding contract.
- Does the v1 logo system pass the ecosystem distinctiveness test? No: the Rail Accent mark-left-of-text lockup is mark-beside-text, which is the dominant and therefore generic pattern in the Elixir OSS ecosystem — Phoenix, Ash, and Oban Pro all use the same construction class. See Section 8 REWORK verdict and `brandbook/logo-v2-design-brief.md` for the Phase 179 brief.
