# Project Research Summary: v1.51 BRAND-IDENTITY-ADOPTION

**Project:** Sigra (hybrid library + generator auth for Elixir/Phoenix, public SemVer API on Hex)
**Domain:** Adopting a signed-off brand book (v2.0, "Kiln", accent kept at `#C2410C`) in an existing library whose output reaches adopters through three lanes
**Researched:** 2026-11-13
**Confidence:** HIGH on sequencing, blast radius and stack (read from the repo, measured in real builds); MEDIUM on external-platform behavior (hex.pm README rendering, Safari, CI lane behavior on PRs)

Detail lives beside this file: `STACK.md`, `FEATURES.md`, `ARCHITECTURE.md`, `PITFALLS.md`. "The brand book" means the signed-off v2.0 reference copy (`BRAND.md`, `brand.json`, `tokens.json`, `assets/`), reference-only in `brand/` (PR #379). Call this work "brand book v2.0 (Kiln)" everywhere: "brand v2" already means the v1.38 Linked Rail logo, and the `BRAND-` requirement prefix is taken (use `BPOL`, `BCOPY`, `BGEN`, `BTOK`, `BOPS`, `BAUTH`, `BPUB`, `BREL`).

## Executive Summary

A words-and-visuals milestone, not a feature milestone. Output reaches adopters through three lanes with different update rules: library-owned admin LiveViews and components (every adopter, immediately, on `mix deps.update`), generated templates (new installs only), and host-owned CSS/logos (copied once, never refreshed, never detected as stale). Comparable systems (Keycloak, Clerk, Ory, Devise) survive a rebrand by freezing public names and changing values, and by keeping the host's identity the host's. The book itself says sign-in, registration, 2FA and email screens wear the host's brand; Sigra's name and logo live only on Sigra's own pages. **Net-new dependencies: zero.** The repo already has the contrast math (`Sigra.Branding.Contrast`, 30/30 against the book), axe 4.13.0 in Playwright, ExDoc 0.40.3 hooks, and stdlib `JSON`/`:crypto`.

**Recommendation: keep the five proposed phases in the proposed order, with seven amendments:**
1. Decide the PNG-baseline policy in Phase 1; execute it as a small separate "park" PR at the end of Phase 2. Phase 3 must not start before it merges (the immutable `impersonation-banner` canary rule makes the first visual commit un-mergeable).
2. Phase 2 = parity, determinism, repair of three latent defects, and the "before" catalog captured first. **No brand generator: verify, don't generate.**
3. Phase 1 also owns the instruction-file pointer fix (owner approval), the three-segment install-snippet test (the book's `~> 1.7` resolves to the retired stray 1.20.0), the enumeration-parity harness with a positive control, the surface map, and the `loginSubmit` Playwright helper.
4. All `mix.exs`/ExDoc wiring is in Phase 5 so pinned contract tests are rewritten once.
5. Operator slice = Users list, user detail, sessions. Excludes the book's "Needs an admin" panel and seven-day rule (new product capability). Per-user audit leads 4b.
6. Stale-CSS stamp (Phase 2) and doctor check (Phase 4a) are must-haves.
7. The announcement is a draft only.

**Risks that should shape every success criterion:** (1) library markup updating while host CSS does not; (2) "just wording" that is API, incl. enumeration-safe error text a specific brand voice would leak; (3) 115 PNG baselines + immutable canary rule; (4) re-growing the evidence machinery the previous milestone cut; (5) Sigra brand/defaults leaking onto host users, and personal paths or the book's authoring origin leaking into a public repo; (6) the book's `~> 1.7` snippet resolving to retired 1.20.0, and claims (trademark, "cleared", "first") made before a name-clearance record exists.

## Key decisions from the stack research (STACK.md)

- Hash pin: root `brand.sha256` in `shasum -a 256 -c` format, one ExUnit test, `.gitattributes` `brand/** -text linguist-vendored`. No receipts.
- WCAG 2.2 only, no APCA. axe cannot see non-text contrast (SC 1.4.11) and reports gradients/pseudo-elements as `incomplete`: a ~20-line helper covers focus ring, control edge, logo square.
- Fonts: two trimmed woff2 (36.8 KB, SIL OFL 1.1). Self-host only; never a CDN, never base64. Generated admin/auth ship no binaries.
- Do NOT use the book's `sigra-exdoc.css` (passes 8/24 theme checks in a real ExDoc build; corrected `:is(body, body.dark)` stylesheet passes 24/24). Do NOT set ExDoc `logo:` with the typemark. Favicon: book's files unchanged.
- Hex package `files:` unchanged (~0.56 MB). Packaging all of `brand/` would add 3.4 MB.

## Implications for Roadmap

Phase numbers are the roadmapper's to assign. Dependency chain strictly P1 → P2 → P3 → P4 → P5.

### Phase 1: Compatibility policy, pinned source, copy contract, name-clearance record (docs and tests only)
Changes zero shipped bytes (`git diff --stat -- lib priv` stays empty).
- Policy (ADR, section in `guides/introduction/contract.md`, `guides/reference/brand-compatibility.md`): frozen list, add-only list, ownership-lane table, SemVer treatment, surface map (brand owner per surface: Sigra or host).
- `brand/` vendored (consumed subset + `BRAND.md`, `brand.json`, `tokens.json`), root manifest, ExUnit pin test, `.gitattributes`, PII scan of every imported file (incl. SVG/PDF metadata).
- Frozen-surface ratchet test and legacy-profile byte-identity fixtures.
- Copy contract: three tiers, vocabulary map tied to product truth (Active, Unconfirmed, Locked, "Deletion scheduled"; Suspended drawn but unwired), banned-term lint with shrink-only baseline, public-surface registry with enumeration-parity tests (positive control), committed copy inventory.
- Three-segment `{:sigra, "~> x.y.z"}` shape test.
- Name-clearance record titled "search log, not clearance" (include same-name `crosswake_sigra` Hex package), claims register, decisions on logo-use statement and clear-space authority (book's markdown vs JSON disagree: 1/4 typemark height vs 2 T).
- Test-only `loginSubmit` Playwright helper replacing "Log in" text locators in eight specs.
- Instruction-file fix: `CLAUDE.md`, `AGENTS.md`, admin guides still say to use Rail Accent assets from `brandbook/`. Minimal pointer edit, owner approval required.
- PNG-lane decision recorded; upgrade-note skeleton (should-have).
**Addresses:** BPOL-01..05, BCOPY-01..04.

### Phase 2: Deterministic generated output, latent-defect repair, before-screen catalog, PNG park
Mechanism before paint: changes no token value, logo, copy, `Components` markup or `Profile` key. In order:
1. Pin the "before" SHA; build the catalog harness (tier 0 inventory, tier 1 pure render, tier 2 page render for the operator job and generated auth flows using existing seeded personas); capture "before" while output is byte-identical to main. Render auth pages from the **template** CSS, not the stale example copy. Commit manifest + copy inventory; full HTML as CI artifact. No PNG baselines.
2. W-2 parity gate, then refresh example `sigra_auth.css`; parity test for every copied asset; double-install byte-identical; `rebless_golden --check` clean under pinned `phx_new 1.8.8`.
3. L1 repair: move `.sg-brand-mark*` and explicit Light/Dark rules into shipped `sigra_admin.css`, delete `app.css` duplicates; verify in a real generated host; add CSS version stamp comment. Behavior fix for generated hosts: changelog it.
4. L2: wire the two orphaned CSS guards into `mix ci`/`fast_checks` (or retire explicitly).
5. **Park PR** (separate, small, not a brand PR): demote PNG-compare lanes (`admin_checkpoints`, `demo_showcase`, design_gallery `@snapshot`) to dispatch; keep real-login and generated-host smoke, axe, golden install, behavior specs. Phase 3 does not start until it merges.
**Addresses:** BGEN-01..05 (BGEN-06 should-have).

### Phase 3: Tokens, type, logo, favicon assets, contrast
Values only, one reviewed table, one golden rebless, names frozen.
- Token value migration table (old → new, light and dark) applied by hand, guarded by tests; Kiln Bright dark accent; explicit dark `--sg-color-on-brand` = Char (shared `#ffffff` fails at 2.48:1); additive `--sg-status-*`, `--sg-font-sans`/`--sg-font-mono`; weight tokens aligned to 400/600/700; `sigra_auth.css` host-default fallbacks untouched.
- Logo SVGs replaced under the **same file names** (`admin/sigra-logo-primary{,-dark}.svg`) with alt/title; `admin_shell.ex` typemark markup; retired Rail/Ember vocabulary in docs only (`--sg-logo-rail-*` names stay).
- Sigra-owned surfaces (example app, gallery) self-host the two woff2 + OFL texts; no installer `{:copy, ...}` kind.
- Contrast in three layers: ExUnit pair test (30 book pairs, thin-margin printout), axe per color scheme, small non-text helper. Known first-red: dark button label.
- ~10 pinned assertions rewritten to read from source; `admin-token-reference.md` re-pointed at `brand/tokens.json`.
- Only human gate: logo distinctness and 16-24 px favicon legibility.
**Not here:** `mix.exs` favicon/ExDoc (Phase 5), `Profile`/`Config` defaults, `--sigra-auth-*`.
**Addresses:** BTOK-01..06, BTOK-08.

### Phase 4: Words and layout, one operator job first, delivered as three merged PRs
- **4a operator slice** ("a user says they can't sign in"): Users list, user detail, user sessions + shared helpers: `status_mark` component beside `sg-status-pill`, one time helper rendering the zone on the same line, empty/error/destructive-confirm copy naming the user and consequence, correction of "unlock below", label rulings. CSS stamp + doctor warning ship here. Changelog "Visual and copy changes" section. **Gate:** before/after normalized-HTML diff reviewed in both themes, contrast + axe green, enumeration + lexicon tests green, old-CSS render test green, copy baseline shrinks. 4b/4c do not start until it passes.
- **4b rest of admin:** per-user audit first, then overview, audit index, organizations, branding workbench ("Sign-in preview"), shell.
- **4c generated auth and email** (parallel to 4b): "Log in" → "Sign in" per surface, never route paths/helpers/function names, with a rename table; SEED-010 residue (`organizations/**`, `org_switcher`, 17 demo-page literals, `lib/sigra/admin/components.ex:1099`); brand-lane refute test; passkey relying-party default from literal "Sigra" to the resolved product name; SEED-003 audit + shrink-only ratchet (no runtime copy map); email copy pass (should-have).
**Cut order if short:** should-haves first (BAUTH-05/06, BOPS-07); never the slice; never BAUTH-03.
**Addresses:** BOPS-01..06, BAUTH-01..04.

### Phase 5: README, HexDocs, Hex assets; announcement last
All `mix.exs`/ExDoc wiring here. README header (absolute URLs; light drawing as `<img>` fallback since hex.pm may strip `<picture>`); tagline/descriptor via substring contract test; `mix.exs` description, favicon, head hook (corrected stylesheet, no typemark `logo:`), keeping pinned mermaid head block and pinned "Evaluating first?" sentence; rewrite `architecture_guides_contract_test` favicon pin; retire `brandbook/` last (retarget `axe-brandbook.mjs`); demo name Vaultr → Tasklane in README/launch docs; refreshed docs screenshots; upgrade guide (lane table, rename table, token value table); README/guide `~>` pins; social card as manual operator step; verify with `mix docs --warnings-as-errors` read in light and dark, plus `mix hex.build --unpack`. **Announcement: draft only.**
**Addresses:** BPUB-01..04, BREL-01..02.

### Research flags
Needs research at planning: P2 (moderate: tier-2 normalization, LiveView `render/1` purity, live `ci.yml` PNG-lane behavior), P3 (yes), P4 (yes, largest), P5 (moderate). P1 is standard patterns (only the name-clearance search needs a fresh lookup).

## Open Owner Decisions (recommended default for each)

| # | Decision | Recommended default | Needed by |
|---|----------|---------------------|-----------|
| 1 | `Sigra.Branding.Profile` defaults vs the book's neutrals | **Freeze.** Accent already equals Kiln; moving neutrals re-skins every default-token adopter. | P1 |
| 2 | Admin typeface in generated CSS | No font binaries via installer. Additive `--sg-font-*` tokens, host-inherited by default; book stack is the opt-in. Sigra-owned surfaces self-host the two woff2 + OFL. | P1 record, P3 apply |
| 3 | SemVer level | **Minor**; `feat`/`fix`/`docs` only (no `!`, no BREAKING footer); "Visual and copy changes" changelog section; upgrade note | P1 |
| 4 | Changed generated strings/msgids | Targeted per surface, never bulk; old→new rename table; tier-1 strings, route paths, helpers, `sigra` domain untouched | P1 |
| 5 | Suspended / unlock / unsuspend / seven-day rule / "Needs an admin" panel | **Out of scope.** Render only states the model can produce; fix over-promising copy; file a seed | P1 |
| 6 | Status labels | Adopt Active, Unconfirmed, Locked; **keep "Deletion scheduled"**; Suspended drawn in the catalog only | P1 |
| 7 | PNG baseline lanes | **Park** (separate PR at end of P2); never allowlist the canary; never recapture on darwin | P1 decide, P2 execute |
| 8 | Vendoring scope and pin | Consumed subset + `BRAND.md`/`brand.json`/`tokens.json`; no PDF/previews/static TTFs; manifest at repo root outside `brand/`; ExUnit test; `.gitattributes -text`; no receipts | P1 |
| 9 | Generate vs verify tokens | **Verify only.** No builder, no marker regions, no new Mix task in `lib/` | P1 |
| 10 | `organizations/**` daisyUI residue (SEED-010) | Convert to neutral `sigra-auth-*` layer; never `vt-*`, never Kiln-ify; fix `components.ex:1099` additively | P4c |
| 11 | README/guide `~>` pins | P1 test enforces shape (three segments, all equal); bump to latest published minor in P5 (verify 1.7.1 vs 1.7.2 first) | P1, P5 |
| 12 | Instruction files (`CLAUDE.md`, `AGENTS.md`, admin guides) | Minimal pointer fix in P1, with explicit owner approval | P1 |
| 13 | Orphaned CSS guards | Wire both into `mix ci`/`fast_checks` | P2 |
| 14 | Name and trademark | "Search log, not clearance"; record `crosswake_sigra`; no TM/registered/"cleared"/"first"/"only"/"best"; pick authority for clear space and logo-use statement | P1, gate P5 |
| 15 | Demo identity and favicon | Tasklane keeps its own identity on host-facing pages; Sigra icon on HexDocs/gallery only | P3 |
| 16 | Passkey relying-party default name | Change literal "Sigra" to resolved product name (new installs only; display-only) | P4c |
| 17 | Human sign-off | Single gate: logo distinctness and 16-24 px favicon legibility | P3 |
| 18 | Announcement and Hex currency | **Draft only.** Publishing needs explicit approval and either retiring stray 1.20.0 (needs interactive auth) or accepting hex.pm landing page won't show the brand | P5 |
| 19 | Name/home-path guard | Don't absorb the repo-wide guard (own todo). Pushed-diff grep incl. binaries and SVG/PDF metadata at every gate, with a planted-failure control | every gate |
| 20 | Deferred | Dark transactional email, runtime copy map, RTL, full guide sweep, `Profile` default move, trademark claim | none |

## Contradictions between the reports (resolution used above)

1. **Generate vs verify** (ARCHITECTURE builder vs STACK/PITFALLS): verify. Lockstep fixed by moving L1 rules into shipped CSS + byte-parity/golden tests.
2. **Font binaries** (PITFALLS emits woff2 vs STACK/ARCHITECTURE installer can't ship binaries): no binaries in generator; OFL/tarball cautions apply to Sigra-owned surfaces.
3. **Admin font token default** (three values): host-inherited; book stack opt-in.
4. **Vendor scope / pin location:** consumed subset + three source files; manifest outside `brand/`.
5. **PNG lanes** (ride vs park): park, in a separate non-brand PR; confirm live lane behavior first.
6. **Operator slice scope:** Users list, detail, sessions; per-user audit leads 4b.
7. **Stale-CSS stamp / doctor:** stamp in P2, doctor check must-have in 4a.
8. **Vocabulary enforcement:** both, by purpose (scanner + shrink-only baseline; exact-match tier-1 lists; rendered enumeration parity).
9. **msgid changes:** targeted rename per surface + rename table; never bulk; tier 1 untouched.
10. **Are CSS guards live?** No caller anywhere (ARCHITECTURE grep + local run); wire them.
11. **ExDoc `logo:`:** don't set with the typemark.
12. **Book's `sigra-exdoc.css`:** use STACK's corrected stylesheet; keep pinned mermaid head block.
13. **Instruction-file timing:** Phase 1.
14. **Favicon timing / demo:** assets in P3; `mix.exs`/ExDoc in P5; demo keeps its identity.
15. **Facts to reconcile (immaterial):** repo version 1.7.2 vs latest published 1.7.1; Hex size caps; daisyUI and `dgettext` counts.

## Cross-cutting risks → success-criterion shapes

| Risk | Testable criterion | Gate |
|------|--------------------|------|
| Compatibility breakage | Frozen-surface snapshot only grows; legacy Branding profiles render byte-identically; `Profile` defaults unchanged; `data-testid`s, routes, installer targets, logo filenames stable | every phase |
| Library/host skew | New lib markup renders acceptably against previous release's CSS; CSS stamp + doctor warning; word-first marks; no new `sg-*` class without a degraded path | P2, P4a |
| Wording as API / enumeration | Tier-1 exact list unchanged; existing-vs-unknown identity responses identical across sign-in, reset, magic link, resend, registration, invitation, MFA, passkey, **with a deliberately leaky string turning the test red once**; no enumeration-safety claim beyond proof | P1, P4 pre-auth slices |
| Brand ownership | Refute test: no Sigra name/logo in rendered host-user screens/emails; literal "Sigra" lint under `priv/templates/sigra.install/core`; admin typeface not imposed | P1, P3, P4c |
| Generated-output churn | One golden rebless per phase, reviewed per directory; mechanical changes in separate commits; filenames stable; pinned `phx_new 1.8.8`; template/golden/example byte-parity | P2, P3, P4 |
| CI-gate deadlock | Park PR merged before first value change; `ci-gate` green on a token-only PR; canary never allowlisted; no darwin recapture | P2 exit |
| Process regrowth | `git diff --stat .github scripts` within stated budget; no new workflow/receipt/ledger/hermetic fake of an external service; count merged PRs not plans; two failed attempts → change the prerequisite | every phase |
| Contrast / dark mode | Pair test over implemented CSS for all 30 pair ids in light and dark plus hover/focus/disabled; deliberately bad color fails; axe `incomplete` recorded, never counted as pass; dark button label is Char | P3, P4a |
| Privacy | Pushed-diff grep finds no home paths, personal names or the book's authoring origin; provenance reads "brand book v2.0 (2026-11-13)"; catalog data is seeded `.test` addresses | every gate |
| Claims and clearance | No TM/"cleared"/"first/only/best"; every public claim sourced in the claims register; re-check the README "Pow does not support Phoenix 1.8+" line (LOW) | P1, P5 |
| Install snippets and Hex | Three-segment requirement test; scratch `mix deps.get` resolves a non-retired release; `mix hex.build --unpack` shows no `brand/` and no TTFs; README images absolute and pinned to tag/SHA | P1, P5 |
| Scope creep | No migration/query in a brand PR; no UI for a state the model can't produce; SEED-003 bounded to audit/ratchet/docs | P4 |
| Release mechanics | No `!`/BREAKING footer; no hand notes under CHANGELOG "Unreleased"; nothing pushed/merged/released/tagged without approval | every phase |
| Fresh-host proof | One real run: `phx_new 1.8.8`, `mix sigra.install`, boot, real login, admin in light/dark/system, looked at; `MIX_ENV=test mix ci` | P2, P3, P4 |

## Latent defects found (change the plan)

- **L1:** shipped `sigra_admin.css` lacks `.sg-brand-mark*` and explicit Light/Dark rules (exist only in example `app.css`) (MEDIUM, inferred; confirm with generated-host smoke).
- **L2:** `scripts/ci/admin-css-conformance.sh` and `admin-token-completeness.sh` have no CI caller (HIGH).
- **L3:** example `sigra_auth.css` 13.9 KB vs 32 KB template, no parity gate (todo W-2).
- **L4:** eight Playwright specs locate the sign-in button by the text "Log in".
- Book assumes a Suspended state and unlock actions that don't exist; `user_show_live.ex` already says "unlock below" with no such control.

## Gaps to address
PNG lane behavior on PRs (read live `ci.yml` at P2 planning); hex.pm `<picture>`/external image rendering (post-publish check, not a gate); favicon at 16-24 px and logo distinctness (human, P3); glyph coverage for `·` and `✓`; axe `incomplete` volume on `color-mix()` surfaces; registration timing oracle (keep registration/reset copy-neutral); book-internal conflicts (clear space, logo licence); generated sign-in, 2FA and email screens never viewed running; repo version vs latest published (1.7.2 vs 1.7.1).

---
*Research completed: 2026-11-13*
*Ready for roadmap: yes*
