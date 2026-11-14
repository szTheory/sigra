# Requirements: Sigra v1.51 BRAND-IDENTITY-ADOPTION

**Defined:** 2026-11-13
**Core value:** Authentication that works out of the box with great DX on the happy path and the rough edges.
**Milestone goal:** Adopt brand book v2.0 ("Kiln", accent kept at `#C2410C`) across generated output, admin/auth UI and public package surfaces without breaking any public API.
**Source:** `.planning/research/v1.51-brand/SUMMARY.md` (and STACK/FEATURES/ARCHITECTURE/PITFALLS beside it). Prefix note: `BRAND-` is taken by the v1.38 requirements, so this milestone uses `BPOL/BCOPY/BGEN/BTOK/BOPS/BAUTH/BPUB/BREL`.

Priority: **M** must, **S** should (cut first if capacity is short). Net-new dependencies: none.

## v1 Requirements

### Compatibility policy and source of truth (BPOL) — Phase 1
- [ ] **BPOL-01** (M): Compatibility policy (ADR + section in `guides/introduction/contract.md` + `guides/reference/brand-compatibility.md`): frozen list, add-only list, ownership-lane table (library-owned / generated / host-owned), SemVer treatment of copy and visual changes, surface map (brand owner per surface: Sigra or host).
- [ ] **BPOL-02** (M): Consumed subset of the brand book vendored in `brand/` with a root `brand.sha256` manifest, one ExUnit drift test, `.gitattributes` `brand/** -text`; `brandbook/` untouched; every imported file scanned for personal names, emails, home paths and SVG/PDF metadata.
- [ ] **BPOL-03** (M): Add-only ratchet test: CSS custom-property names, `sg-*`/`sigra-auth-*` classes, `Profile` keys and defaults, config keys, routes/helpers, Gettext domain, `data-testid`s, logo filenames; legacy Branding profiles (explicit, partial, defaults) render byte-identically.
- [ ] **BPOL-04** (M): Name-clearance record titled "search log, not clearance" (includes the same-name `crosswake_sigra` Hex package), claims register, decisions on logo-use statement and clear-space authority. No trademark claim.
- [ ] **BPOL-05** (M): Decision records: `Profile` defaults frozen; fonts via additive tokens only; SemVer level minor (`feat`/`fix`/`docs`, no `!`/BREAKING); msgid renames targeted with a rename table; Suspended/unlock/seven-day rule out of scope; status labels (keep "Deletion scheduled"); PNG-lane policy.
- [ ] **BPOL-06** (M): Instruction-file pointer fix (`CLAUDE.md`, `AGENTS.md`, admin guides still direct executors to the retired `brandbook/` Rail assets). Minimal edit; **owner approval granted 2026-11-13** (pointers to the new `brand/` book).
- [ ] **BPOL-07** (S): Upgrade-note skeleton (which lane auto-updates, what hosts re-copy).

### Copy contract (BCOPY) — Phase 1
- [ ] **BCOPY-01** (M): Reconciled vocabulary table (book key terms x `admin-glossary.md`) with rulings tied to product truth (Active, Unconfirmed, Locked, "Deletion scheduled"; "Admin" not "Admin (operator)"; "Review users").
- [ ] **BCOPY-02** (M): Drift test extended: banned terms and the book's do-not-say lexicon over admin files, generated templates (own list) and lexicon-only over README/top guides; shrink-only baseline.
- [ ] **BCOPY-03** (M): Enumeration-boundary contract: public-surface registry and existing-vs-unknown identity parity tests (sign-in, reset, magic link, resend, registration, invitation, MFA, passkey) with a **positive control** (a deliberately leaky string turns the test red once).
- [ ] **BCOPY-04** (M): Committed copy inventory per ownership lane so every copy change is a reviewable diff.
- [ ] **BCOPY-05** (M): Three-segment install-snippet test: `{:sigra, "~> x.y.z"}` with all segments equal across README, guides, docs and templates (the book's `~> 1.7` resolves to the retired stray 1.20.0).
- [ ] **BCOPY-06** (M): Test-only `loginSubmit` Playwright helper replacing the "Log in" text locators in eight specs.
- [ ] **BCOPY-07** (S): Honest-claims pass: docs and tests do not claim enumeration safety beyond what is proven (timing-oracle todo cited).

### Deterministic output, latent-defect repair, before catalog (BGEN) — Phase 2
- [ ] **BGEN-01** (M): Template/example/golden parity: refresh example `sigra_auth.css` (903 diff lines of drift) and add a parity test for every copied asset.
- [ ] **BGEN-02** (M): Determinism: double install byte-identical; `mix sigra.fixture.rebless_golden --check` clean under pinned `phx_new 1.8.8`.
- [ ] **BGEN-03** (M): Before catalog, text: normalized rendered-HTML snapshots per in-scope screen x state x theme on seeded `.test` personas (three tiers: inventory, pure render, page render), captured at a pinned SHA while output is byte-identical to main. Auth pages rendered from the **template** CSS. No new PNG baselines.
- [ ] **BGEN-04** (M): Latent defect L1: move `.sg-brand-mark*` and explicit Light/Dark rules into shipped `sigra_admin.css`, drop `app.css` duplicates, verify in a real generated host; add a CSS version stamp comment.
- [ ] **BGEN-05** (M): Latent defect L2: wire `admin-css-conformance.sh` and `admin-token-completeness.sh` into `mix ci`/`fast_checks` (or retire explicitly).
- [ ] **BGEN-06** (M): Park PR (separate, small, not a brand PR): demote PNG-compare lanes (`admin_checkpoints`, `demo_showcase`, design_gallery `@snapshot`) to dispatch; keep real-login and generated-host smoke, axe, golden install and behavior specs. Canary never allowlisted; no darwin recapture. Merges before Phase 3 starts.
- [ ] **BGEN-07** (S): Before/after text-diff report script.
- [ ] **BGEN-08** (S): Extend `DesignGalleryLive` with auth-page, email and status-mark states (dev-only; no new framework).

### Tokens, type, logo, favicon, contrast (BTOK) — Phase 3
- [ ] **BTOK-01** (M): Token value migration table (old → new, light and dark) from `brand/tokens.json` applied by hand to admin CSS; names unchanged; Kiln Bright dark accent; explicit dark `--sg-color-on-brand` = Char (white on Kiln Bright is 2.48:1); `sigra_auth.css` host-default fallbacks untouched; one golden rebless.
- [ ] **BTOK-02** (M): Contrast pair test: 30 pairs from `brand.json` over the implemented CSS using `Sigra.Branding.Contrast`, light and dark plus hover/focus/disabled; a deliberately bad color fails.
- [ ] **BTOK-03** (M): Real-DOM contrast and a11y: existing axe gate over the catalog in both themes, plus a ~20-line non-text helper (focus ring, control edge, logo square); axe `incomplete` count recorded, never counted as pass.
- [ ] **BTOK-04** (M): Logo: v2 lockup light/dark replaces rail SVGs under the **same filenames** (`admin/sigra-logo-primary{,-dark}.svg`) with alt/title; `admin_shell.ex` markup; stray rail files removed from the example.
- [ ] **BTOK-05** (M): Favicon assets from the book for Sigra-owned surfaces; 16/32 px render check; **human gate** for logo distinctness and 16-24 px legibility.
- [ ] **BTOK-06** (M): Fonts: additive `--sg-font-sans`/`--sg-font-mono` tokens (host-inherited by default; book stack documented opt-in); Sigra-owned surfaces self-host the two woff2 + OFL texts; no installer binary kind.
- [ ] **BTOK-07** (M): Pinned assertions (~10) rewritten to read from source; `admin-token-reference.md` re-pointed at `brand/tokens.json` names.
- [ ] **BTOK-08** (S): Additive status, selected-row and current-tab tokens.

### Operator UI (BOPS) — Phase 4 (4a, 4b)
- [ ] **BOPS-01** (M): Operator slice 4a "find a user who can't sign in and see why": Users list, user detail, user sessions, end to end, with a hard gate (before/after normalized-HTML diff in both themes, contrast + axe green, enumeration + lexicon tests green, old-CSS render test green, copy baseline shrinks). 4b/4c do not start until it passes.
- [ ] **BOPS-02** (M): `status_mark` component beside `sg-status-pill` with one-status-per-user precedence from existing columns (Deleting, Locked, Unconfirmed, Active); word always rendered; Suspended drawn in the catalog only.
- [ ] **BOPS-03** (M): One time helper rendering the zone on the same line ("2:07 PM UTC").
- [ ] **BOPS-04** (M): Destructive-confirm, empty and error copy per rubric, naming the user and consequence; correct "unlock below" to the truth.
- [ ] **BOPS-05** (M): Label rulings applied across the slice.
- [ ] **BOPS-06** (M): Doctor check and CSS stamp: `mix sigra.doctor` warns when generated CSS is older than the library markup needs; new lib markup renders acceptably against the previous release's CSS.
- [ ] **BOPS-07** (M): 4b remaining admin: per-user audit first, then overview, audit index, organizations, branding workbench ("Sign-in preview"), shell; each with before/after catalog entry.
- [ ] **BOPS-08** (S): Selected-row 2 px rule and current-tab square (additive CSS).

### Generated auth pages and email (BAUTH) — Phase 4 (4c)
- [ ] **BAUTH-01** (M): SEED-010 residue: `organizations/**` and `org_switcher` converted to neutral `sigra-auth-*` classes (never `vt-*`, never Kiln-ified); demo pages (17 literals); `lib/sigra/admin/components.ex:1099` fixed additively; record the a/b/c decision.
- [ ] **BAUTH-02** (M): Brand-lane refute test: no Sigra name or logo in rendered host-user screens or emails (opt-in plain-text footer excepted); literal "Sigra" lint under `priv/templates/sigra.install/core`.
- [ ] **BAUTH-03** (M): "Sign in" vocabulary per surface across templates and emails; route paths, helpers and function names untouched; rename table; golden rebless.
- [ ] **BAUTH-04** (M): SEED-003 audit and ratchet: inventory raw user-facing literals, allowlist that may only shrink; no runtime copy map.
- [ ] **BAUTH-05** (M): Passkey relying-party default name: literal "Sigra" → resolved product name (generated template, new installs only).
- [ ] **BAUTH-06** (S): Wrap core raw literals in `dgettext("sigra", ...)`; document `mix gettext.extract`/`merge`.
- [ ] **BAUTH-07** (S): Email copy pass (action first, then what happens if ignored).

### Public surfaces (BPUB) — Phase 5
- [ ] **BPUB-01** (M): README header (`<picture>` with light `<img>` fallback), tagline, descriptor; demo name Vaultr → Tasklane; absolute asset URLs pinned to a tag/SHA; lexicon lint passes.
- [ ] **BPUB-02** (M): ExDoc: favicon, corrected stylesheet through the head hook (light and dark), **no typemark `logo:`**; keep pinned mermaid head block; rewrite the pinned favicon contract test once; verified in a real `mix docs --warnings-as-errors` build.
- [ ] **BPUB-03** (M): Hex package `description`/links use approved text; `files:` unchanged; `mix hex.build --unpack` shows no `brand/` and no TTFs.
- [ ] **BPUB-04** (M): Brand assets and refreshed screenshots through ExDoc `assets:`; social card referenced (GitHub social preview is a manual operator step); `brandbook/` retired last (retarget `axe-brandbook.mjs`).
- [ ] **BPUB-05** (M): README/guide `~>` pins bumped to the latest published minor in one commit with the contract test (verify 1.7.1 vs 1.7.2 first).
- [ ] **BPUB-06** (S): Vocabulary pass on primary-path guides.

### Release narrative (BREL) — Phase 5
- [ ] **BREL-01** (M): Upgrade guide: lane table, msgid rename table, token value table; conventional-commit scopes so release-please writes the changelog; nothing hand-added under CHANGELOG "Unreleased".
- [ ] **BREL-02** (M): Announcement **draft only**, written last; approved descriptions only; passes the lexicon lint; no trademark symbol. Publishing needs explicit owner approval.

## Future Requirements (deferred)
- Suspended/unsuspend/admin-unlock actions, Suspended state, "Needs an admin" panel and seven-day unconfirmed rule (new product capability; file a seed).
- Storybook-style catalog framework and cutting old UI-process jobs on main (MILESTONE-ARC item 3).
- Moving `Profile` defaults to the book's neutrals.
- Admin-managed copy, locale-aware routing, RTL, per-organization wording, organization-template i18n, dark transactional email, `<.button type>` forward-compat (SEED-004).
- Full guide sweep and historical launch docs.
- Trademark claim, look-alike and register search.
- Repo-wide personal-name/home-path guard (own todo); retiring stray Hex 1.20.0 (interactive auth).

## Out of Scope
| Item | Reason |
|------|--------|
| Renaming modules, config keys, `--sg-*`/`--sigra-auth-*` tokens, classes, routes | Public SemVer API; only values and on-screen words change |
| Deferred v1.50 CI requirements (CISPEED-01/02, CIREL-01, CIDX-02) | Separate scope; need fresh authorization |
| A brand generator / marker-region CSS builder / new Mix task | Research resolved: verify, don't generate; avoids machinery regrowth |
| New PNG baselines, evidence ledgers, receipts, hermetic fakes of external services | The cut UI-process machinery must not regrow |
| Font binaries shipped by the installer | Installer only understands `{:eex, ...}`; hosts own their typeface |
| Sigra brand or defaults on host-user screens | Brand-lane rule from the book |
| Re-skinning the Tasklane demo | Demo is the host-brand exemplar |
| Any push, merge, release, tag or announcement publish without explicit approval | Standing constraint |

## Traceability
Filled by the roadmapper 2026-11-13. Every v1 requirement maps to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BPOL-01 | Phase 259 | Pending |
| BPOL-02 | Phase 259 | Pending |
| BPOL-03 | Phase 259 | Pending |
| BPOL-04 | Phase 259 | Pending |
| BPOL-05 | Phase 259 | Pending |
| BPOL-06 | Phase 259 | Pending |
| BPOL-07 | Phase 259 | Pending |
| BCOPY-01 | Phase 259 | Pending |
| BCOPY-02 | Phase 259 | Pending |
| BCOPY-03 | Phase 259 | Pending |
| BCOPY-04 | Phase 259 | Pending |
| BCOPY-05 | Phase 259 | Pending |
| BCOPY-06 | Phase 259 | Pending |
| BCOPY-07 | Phase 259 | Pending |
| BGEN-01 | Phase 260 | Pending |
| BGEN-02 | Phase 260 | Pending |
| BGEN-03 | Phase 260 | Pending |
| BGEN-04 | Phase 260 | Pending |
| BGEN-05 | Phase 260 | Pending |
| BGEN-06 | Phase 260 | Pending |
| BGEN-07 | Phase 260 | Pending |
| BGEN-08 | Phase 260 | Pending |
| BTOK-01 | Phase 261 | Pending |
| BTOK-02 | Phase 261 | Pending |
| BTOK-03 | Phase 261 | Pending |
| BTOK-04 | Phase 261 | Pending |
| BTOK-05 | Phase 261 | Pending |
| BTOK-06 | Phase 261 | Pending |
| BTOK-07 | Phase 261 | Pending |
| BTOK-08 | Phase 261 | Pending |
| BOPS-01 | Phase 262 | Pending |
| BOPS-02 | Phase 262 | Pending |
| BOPS-03 | Phase 262 | Pending |
| BOPS-04 | Phase 262 | Pending |
| BOPS-05 | Phase 262 | Pending |
| BOPS-06 | Phase 262 | Pending |
| BOPS-07 | Phase 262 | Pending |
| BOPS-08 | Phase 262 | Pending |
| BAUTH-01 | Phase 262 | Pending |
| BAUTH-02 | Phase 262 | Pending |
| BAUTH-03 | Phase 262 | Pending |
| BAUTH-04 | Phase 262 | Pending |
| BAUTH-05 | Phase 262 | Pending |
| BAUTH-06 | Phase 262 | Pending |
| BAUTH-07 | Phase 262 | Pending |
| BPUB-01 | Phase 263 | Pending |
| BPUB-02 | Phase 263 | Pending |
| BPUB-03 | Phase 263 | Pending |
| BPUB-04 | Phase 263 | Pending |
| BPUB-05 | Phase 263 | Pending |
| BPUB-06 | Phase 263 | Pending |
| BREL-01 | Phase 263 | Pending |
| BREL-02 | Phase 263 | Pending |

**Coverage:** 53/53 v1 requirements mapped (259: 14, 260: 8, 261: 8, 262: 15, 263: 8).

---
*Requirements defined: 2026-11-13*
