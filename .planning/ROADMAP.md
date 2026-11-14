# Roadmap: Sigra

## Milestones

- 🚧 **v1.51 BRAND-IDENTITY-ADOPTION** — Phases 259–263 (in progress; opened 2026-11-13). Adopt brand book v2.0 ("Kiln", accent kept at `#C2410C`) across generated output, admin/auth UI and public package surfaces without breaking any public API.
- ⚠️ **v1.50 CI-SPEED-AND-RELIABILITY** — closed 2026-11-10 as a partial internal closeout (`override_closeout`); 4 requirements satisfied, 1 adjusted, 4 deferred; 2/8 phases currently verified. [Full closeout and roadmap](milestones/v1.50-ROADMAP.md) · [requirements](milestones/v1.50-REQUIREMENTS.md) · [audit](milestones/v1.50-MILESTONE-AUDIT.md)
- ⚠️ **v1.49 RELEASE-1.6.0** — Phases 246–251 (closed 2026-10-12 with one known failed readiness check; 8/9 requirements proved) · full record in [milestones/v1.49-ROADMAP.md](milestones/v1.49-ROADMAP.md)
- ⚠️ **v1.48 CLEAN-BASELINE** — Phases 236–245; 21/27 requirements satisfied, four partial, two unsatisfied; seven stale verification reports and Phase 245 gaps_found. [Full roadmap](milestones/v1.48-ROADMAP.md) · [requirements](milestones/v1.48-REQUIREMENTS.md) · [audit](milestones/v1.48-MILESTONE-AUDIT.md)
- ⚠️ **v1.47 CI-EFFICIENCY** — Phases 230-235 (shipped 2026-09-15 · `override_closeout`, 21/24 requirements, TEST-01/TEST-02 unsatisfied, 46 artifacts acknowledged) · full detail in milestones/v1.47-ROADMAP.md
- ✅ **v1.46 ADOPTER-EXPERIENCE** — Phases 224-229 (shipped 2026-07-27 · `override_closeout`, 15/15 requirements, 8 audit findings deferred) · full detail in milestones/v1.46-ROADMAP.md
- ⚠️ **v1.45 RELEASE-CURRENCY** — Phases 221-223 (shipped 2026-07-11 · `override_closeout`, Phase 223 deferred) · full detail in milestones/v1.45-ROADMAP.md
- ✅ **v1.44 ADMIN-UX-RATCHET** — Phases 216-220 (shipped 2026-07-10) · full detail in milestones/v1.44-ROADMAP.md
- ✅ **v1.43 STABILIZE** — Phases 213-215 (shipped 2026-07-03) · full detail in milestones/v1.43-ROADMAP.md
- ✅ **v1.42 ADMIN-DS-ELEVATION** — Phases 205-212 (shipped 2026-07-02) · full detail in milestones/v1.42-ROADMAP.md
- ✅ **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (shipped 2026-06-27)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## Overview

v1.51 is a words-and-visuals milestone, not a feature milestone. Sigra's output reaches adopters through three lanes with different update rules: library-owned admin LiveViews and components (every adopter, immediately, on `mix deps.update`), generated templates (new installs only), and host-owned CSS and logos (copied once, never refreshed). The roadmap therefore moves in a strict order: first decide what may not change and pin the source (Phase 259), then make the output deterministic and photograph the "before" (Phase 260), then change visual values once (Phase 261), then change words and layout starting with one operator job (Phase 262), and only then touch the public package surfaces and the announcement draft (Phase 263).

Governing rules, from the milestone research (`.planning/research/v1.51-brand/SUMMARY.md`):

- Public module names, config keys, `--sg-*` / `--sigra-auth-*` token names, classes, routes, helpers and logo filenames are frozen. Only values and on-screen words change. SemVer level is minor.
- Verify, do not generate: no brand generator, marker-region CSS builder or new Mix task.
- Net-new dependencies: none.
- Nothing is pushed, merged, released, tagged or announced without explicit owner approval.
- The deferred v1.50 CI requirements (CISPEED-01/02, CIREL-01, CIDX-02) stay out of scope.

Phase numbering continues from v1.50 (last phase 258, plus 255.1). Phases are strictly sequential: 259 → 260 → 261 → 262 → 263.

## Milestone-Wide Gates

These are cross-cutting criteria. Each phase lists the ones that apply to it inside its own success criteria; they are collected here so the contract is visible in one place.

| Gate | Testable form | Applies to |
|------|---------------|------------|
| Frozen-surface ratchet | The frozen-surface snapshot only grows; legacy `Branding` profiles (explicit, partial, defaults) render byte-identically; `Profile` defaults, `data-testid`s, routes, installer targets and logo filenames are unchanged | Every phase |
| Enumeration parity | Existing-vs-unknown identity responses are identical across sign-in, reset, magic link, resend, registration, invitation, MFA and passkey; a deliberately leaky string turns the test red once (positive control); no enumeration-safety claim beyond what is proven | 259 (build), 262 (re-run on touched pre-auth slices) |
| Privacy grep | Pushed-diff grep (including binaries and SVG/PDF metadata) finds no personal names, emails, home paths or the brand book's authoring origin; a planted-failure control proves the grep fires; provenance reads "brand book v2.0 (2026-11-13)"; catalog data uses seeded `.test` addresses | Every gate |
| Process budget | `git diff --stat .github scripts` stays within the budget stated in the phase plan; no new workflow, receipt, ledger or hermetic fake of an external service; progress is counted in merged PRs, not plans; two failed attempts on the same step means change the prerequisite, not retry | Every phase |
| One golden rebless per phase | At most one reviewed golden rebless per phase, reviewed per directory, mechanical changes in separate commits, under pinned `phx_new 1.8.8`; template, golden and example stay byte-parity | 260, 261, 262 |
| CI-gate deadlock avoidance | The PNG park PR merges before the first visual value change; `ci-gate` is green on the first token-only PR; the `impersonation-banner` canary is never allowlisted; no darwin recapture | 260 exit, 261 |
| Fresh-host proof | One real run: `phx_new 1.8.8`, `mix sigra.install`, boot, real login, admin in Light/Dark/System, looked at; `MIX_ENV=test mix ci` green | 260, 261, 262 |
| Owner approval | Nothing pushed, merged, released, tagged or announced without explicit approval; no `!` / BREAKING footer; nothing hand-added under CHANGELOG "Unreleased" | Every phase |

## Phases

- [ ] **Phase 259: Compatibility Policy, Pinned Source and Copy Contract** - Decide what may not change, pin the brand book, and put the copy and enumeration contracts under test; zero shipped bytes change
- [ ] **Phase 260: Deterministic Output, Before Catalog and PNG Park** - Make generated output byte-stable, repair latent CSS defects, capture the "before" catalog, and park the PNG-compare lanes
- [ ] **Phase 261: Tokens, Type, Logo, Favicon and Contrast** - Change visual values once, from one reviewed table, with names frozen and contrast proven in the real DOM
- [ ] **Phase 262: Words and Layout** - Operator job first, then every admin screen, then generated auth pages and email, delivered as three merged PRs (4a, 4b, 4c)
- [ ] **Phase 263: Public Surfaces and Release Narrative** - README, HexDocs, Hex package assets, upgrade guide, and an announcement draft written last

## Phase Details

### Phase 259: Compatibility Policy, Pinned Source and Copy Contract
**Goal**: A maintainer can state, and a test enforces, exactly what the rebrand may and may not change: the policy is written, the brand book is pinned in-repo, and the copy and enumeration-safety contracts are under test before any visible change is made.
**Depends on**: Nothing (first phase of v1.51)
**Requirements**: BPOL-01, BPOL-02, BPOL-03, BPOL-04, BPOL-05, BPOL-06, BPOL-07, BCOPY-01, BCOPY-02, BCOPY-03, BCOPY-04, BCOPY-05, BCOPY-06, BCOPY-07
**Success Criteria** (what must be TRUE):
  1. A maintainer can open the ADR, the `contract.md` section and `guides/reference/brand-compatibility.md` and find the frozen list, add-only list, ownership-lane table (library-owned / generated / host-owned), the surface map naming the brand owner of each surface, and the recorded decisions (`Profile` defaults frozen, additive font tokens only, minor SemVer with no `!`/BREAKING, targeted msgid renames with a rename table, Suspended/unlock/seven-day rule out of scope, "Deletion scheduled" kept, PNG-lane policy) plus an upgrade-note skeleton.
  2. The consumed brand-book subset sits in `brand/` with a root `brand.sha256`; editing any vendored byte turns the single ExUnit drift test red; every imported file (including SVG/PDF metadata) passes the privacy scan; `brandbook/` is untouched; and `git diff --stat -- lib priv` is empty for the whole phase (zero shipped bytes).
  3. The frozen-surface ratchet test (CSS custom properties, `sg-*`/`sigra-auth-*` classes, `Profile` keys and defaults, config keys, routes/helpers, Gettext domain, `data-testid`s, logo filenames) is green, can only grow, and legacy Branding profiles render byte-identically.
  4. The reconciled vocabulary table, per-lane copy inventory, banned-term/lexicon drift test with shrink-only baseline, and three-segment install-snippet test (all segments equal across README, guides, docs, templates) all pass; the enumeration-parity tests pass for every pre-auth surface and go red exactly once when a deliberately leaky string is injected; the eight "Log in" Playwright locators are replaced by the test-only `loginSubmit` helper; docs and tests claim no enumeration safety beyond what is proven.
  5. The name-clearance record exists, titled "search log, not clearance", listing the same-name `crosswake_sigra` Hex package, with a claims register and decisions on logo-use statement and clear-space authority and no trademark claim; the instruction-file pointer fix (`CLAUDE.md`, `AGENTS.md`, admin guides) lands only after explicit owner approval; the privacy grep and process budget hold.
**Plans**: TBD
**Research at planning**: Standard patterns (only the name-clearance search needs a fresh lookup).
**Owner decisions needed**: #1 `Profile` defaults frozen; #2 admin typeface (record); #3 SemVer level; #4 changed msgid policy; #5 Suspended/unlock out of scope; #6 status labels; #7 PNG-lane policy (decide); #8 vendoring scope and pin; #9 verify-not-generate; #11 install-pin shape; #12 instruction-file pointer fix (explicit approval); #14 name/trademark posture and clear-space/logo-use authority.

### Phase 260: Deterministic Output, Before Catalog and PNG Park
**Goal**: Generated output is byte-stable and verifiably in sync with its sources, the latent CSS defects are repaired, the "before" state of every in-scope screen is captured while output is still byte-identical to main, and the PNG-compare lanes are parked so later visual changes can merge.
**Depends on**: Phase 259
**Requirements**: BGEN-01, BGEN-02, BGEN-03, BGEN-04, BGEN-05, BGEN-06, BGEN-07, BGEN-08
**Success Criteria** (what must be TRUE):
  1. A maintainer can read a committed "before" catalog (normalized rendered-HTML snapshots per in-scope screen × state × theme, three tiers: inventory, pure render, page render) captured at a pinned SHA on seeded `.test` personas while output was byte-identical to main, with auth pages rendered from the template CSS, no new PNG baselines, and a committed manifest plus copy inventory (full HTML as a CI artifact).
  2. Installing twice yields byte-identical output; `mix sigra.fixture.rebless_golden --check` is clean under pinned `phx_new 1.8.8`; every copied asset (including the refreshed example `sigra_auth.css`) has a template/example/golden parity test.
  3. In a real generated host, the brand mark and explicit Light/Dark theme rules render from the shipped `sigra_admin.css` alone (the `app.css` duplicates are gone), the CSS carries a version-stamp comment, and `admin-css-conformance.sh` and `admin-token-completeness.sh` run in `mix ci`/`fast_checks` (or are explicitly retired).
  4. The park PR (separate, small, not a brand PR) has demoted the PNG-compare lanes (`admin_checkpoints`, `demo_showcase`, design_gallery `@snapshot`) to dispatch while real-login and generated-host smoke, axe, golden install and behavior specs stay on the PR path; the canary is not allowlisted; nothing was recaptured on darwin; and it is merged, with explicit owner approval, before Phase 261 starts.
  5. No token value, logo, copy, `Components` markup or `Profile` key changed in this phase; the frozen-surface ratchet, privacy grep and process budget (no new workflow/receipt/ledger beyond the park PR) hold; at most one golden rebless; the fresh-host run is green.
**Plans**: TBD
**UI hint**: yes
**Research at planning**: Moderate (tier-2 normalization, LiveView `render/1` purity, live `ci.yml` PNG-lane behavior on PRs — read the live file before planning the park PR).
**Owner decisions needed**: #7 PNG lanes (execute: park PR merge approval); #13 orphaned CSS guards (wire or retire).

### Phase 261: Tokens, Type, Logo, Favicon and Contrast
**Goal**: Sigra's own surfaces carry the Kiln visual identity (values, type, logo, favicon) in Light and Dark, with every token name unchanged and contrast proven over the implemented CSS and the real DOM.
**Depends on**: Phase 260 (including the merged park PR)
**Requirements**: BTOK-01, BTOK-02, BTOK-03, BTOK-04, BTOK-05, BTOK-06, BTOK-07, BTOK-08
**Success Criteria** (what must be TRUE):
  1. The admin renders the new token values in both themes from one reviewed old→new migration table applied by hand: token names unchanged, Kiln Bright dark accent, dark `--sg-color-on-brand` = Char, `sigra_auth.css` host-default fallbacks untouched, additive status/selected-row/current-tab tokens present, exactly one golden rebless, and `ci-gate` green on the first token-only PR (no deadlock).
  2. The 30 brand-book contrast pairs pass over the implemented CSS in light and dark plus hover/focus/disabled states using `Sigra.Branding.Contrast`, a deliberately bad color fails the test, the existing axe gate is green over the catalog in both themes with its `incomplete` count recorded (never counted as pass), and a non-text helper confirms focus ring, control edge and logo square.
  3. The v2 lockup (light/dark) renders under the same filenames (`admin/sigra-logo-primary{,-dark}.svg`) with alt/title, stray rail files are gone from the example, favicon assets render at 16/32 px, and the owner has signed off on logo distinctness and 16–24 px legibility (the single human gate).
  4. Additive `--sg-font-sans`/`--sg-font-mono` tokens default to the host's typeface (book stack documented as opt-in); Sigra-owned surfaces self-host the two woff2 files with OFL texts; the installer ships no font binaries; the ~10 pinned assertions read from source and `admin-token-reference.md` points at `brand/tokens.json` names.
  5. Frozen-surface ratchet, privacy grep and process budget hold; the fresh-host run (install, boot, real login, admin Light/Dark/System) is green and was looked at; no `mix.exs`/ExDoc favicon wiring and no `Profile`/`Config` default or `--sigra-auth-*` change was made (those belong to Phase 263 or are frozen).
**Plans**: TBD
**UI hint**: yes
**Research at planning**: Yes (token migration table, `color-mix()` surfaces and axe `incomplete` volume, glyph coverage, favicon rendering).
**Owner decisions needed**: #2 admin typeface (apply); #15 demo identity and favicon scope; #17 human sign-off on logo distinctness and favicon legibility.

### Phase 262: Words and Layout
**Goal**: Every operator and adopter-facing screen speaks the book's vocabulary and uses its layout, starting with one operator job end to end ("a user says they can't sign in"), then the rest of the admin, then generated auth pages and email, without touching a route, helper or message the contracts freeze.
**Depends on**: Phase 261
**Requirements**: BOPS-01, BOPS-02, BOPS-03, BOPS-04, BOPS-05, BOPS-06, BOPS-07, BOPS-08, BAUTH-01, BAUTH-02, BAUTH-03, BAUTH-04, BAUTH-05, BAUTH-06, BAUTH-07
**Success Criteria** (what must be TRUE):
  1. (4a operator slice) An operator can open Users list, user detail and user sessions and find why someone cannot sign in: each user shows one status (Deleting, Locked, Unconfirmed, Active) as a `status_mark` with the word always rendered, times show the zone on the same line, destructive confirms name the user and consequence, empty and error states follow the rubric, and "unlock below" no longer promises a control that does not exist. 4b and 4c do not start until the slice's hard gate passes: before/after normalized-HTML diff reviewed in both themes, contrast + axe green, enumeration + lexicon tests green, old-CSS render test green, copy baseline shrinks.
  2. New library markup renders acceptably against the previous release's CSS, and `mix sigra.doctor` warns when generated CSS is older than the library markup needs.
  3. (4b) Per-user audit, overview, audit index, organizations, branding workbench ("Sign-in preview") and shell each have a before/after catalog entry and apply the label rulings; per-user audit goes first, and the selected-row and current-tab rules are additive CSS only.
  4. (4c) Generated auth and email screens say "Sign in" per the rename table with route paths, helpers and function names untouched and tier-1 exact strings unchanged; `organizations/**` and `org_switcher` use neutral `sigra-auth-*` classes (never `vt-*`, never Kiln-styled) with the a/b/c decision recorded; the brand-lane refute test shows no Sigra name or logo on rendered host-user screens or emails and the literal-"Sigra" lint under `priv/templates/sigra.install/core` is green; new installs resolve the passkey relying-party default to the product name; the SEED-003 literal inventory exists with a shrink-only allowlist and no runtime copy map.
  5. The phase lands as three merged PRs (4a, 4b, 4c), each with explicit owner approval, with at most one golden rebless (reviewed per directory, mechanical changes in separate commits); no migration or query appears in a brand PR and no UI is drawn for a state the model cannot produce; the changelog gets a "Visual and copy changes" section via conventional-commit scopes; enumeration parity re-runs green on touched pre-auth slices; frozen-surface ratchet, privacy grep, process budget and the fresh-host run hold.
**Plans**: TBD
**UI hint**: yes
**Research at planning**: Yes (largest phase: slice rubric, `status_mark` precedence from existing columns, time helper, old-CSS render test, SEED-003 literal inventory).
**Owner decisions needed**: #10 `organizations/**` daisyUI residue (convert to neutral `sigra-auth-*`); #16 passkey relying-party default name; approval of each of the three PRs. Cut order if short: should-haves first (BAUTH-05/06, BOPS-07 detail, BAUTH-07, BOPS-08); never the 4a slice; never BAUTH-03.

### Phase 263: Public Surfaces and Release Narrative
**Goal**: The README, HexDocs and Hex package present the new identity accurately and without over-claiming, an adopter has an upgrade guide, and the announcement exists only as a draft written last.
**Depends on**: Phase 262
**Requirements**: BPUB-01, BPUB-02, BPUB-03, BPUB-04, BPUB-05, BPUB-06, BREL-01, BREL-02
**Success Criteria** (what must be TRUE):
  1. The README shows the new header (`<picture>` with light `<img>` fallback, absolute asset URLs pinned to a tag/SHA), tagline and descriptor, names the demo Tasklane (not Vaultr), passes the lexicon lint, and every `~>` pin in README and guides is a three-segment requirement bumped to the latest published minor in one commit with its contract test (1.7.1 vs 1.7.2 verified first), with a scratch `mix deps.get` resolving a non-retired release.
  2. A real `mix docs --warnings-as-errors` build renders the favicon and corrected stylesheet in light and dark with no typemark `logo:` and the pinned mermaid head block intact; the pinned favicon contract test is rewritten once; `mix.exs` description and links use approved text.
  3. `mix hex.build --unpack` shows `files:` unchanged, no `brand/` and no TTFs; brand assets and refreshed screenshots ship through ExDoc `assets:`; the social card is referenced (GitHub social preview recorded as a manual operator step); `brandbook/` is retired last with `axe-brandbook.mjs` retargeted.
  4. An adopter can read the upgrade guide (lane table, msgid rename table, token value table) and the primary-path guides use the new vocabulary; no `!`/BREAKING footer is used and nothing is hand-added under CHANGELOG "Unreleased".
  5. The announcement exists as a draft only, written last, using approved descriptions, passing the lexicon lint, with no trademark symbol and no claim missing from the claims register; nothing is pushed, merged, released, tagged or published without explicit owner approval; the privacy grep and process budget hold.
**Plans**: TBD
**Research at planning**: Moderate (hex.pm `<picture>`/external image rendering is a post-publish check, not a gate; ExDoc head hook; Hex build contents).
**Owner decisions needed**: #11 pin bump; #14 name/claims gate before any public text; #18 announcement and Hex currency (publishing requires explicit approval and either retiring stray 1.20.0, which needs interactive auth, or accepting that the hex.pm landing page will not show the brand).

## Progress

**Execution order:** 259 → 260 → 261 → 262 → 263 (strictly sequential).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 259. Compatibility Policy, Pinned Source and Copy Contract | 0/TBD | Not started | - |
| 260. Deterministic Output, Before Catalog and PNG Park | 0/TBD | Not started | - |
| 261. Tokens, Type, Logo, Favicon and Contrast | 0/TBD | Not started | - |
| 262. Words and Layout | 0/TBD | Not started | - |
| 263. Public Surfaces and Release Narrative | 0/TBD | Not started | - |

## Previous Milestone

**v1.50 record:** [Closeout roadmap](milestones/v1.50-ROADMAP.md) · [requirements and outcomes](milestones/v1.50-REQUIREMENTS.md) · [audit](milestones/v1.50-MILESTONE-AUDIT.md) · [phase archive](milestones/v1.50-phases/)

v1.50 closed as a partial internal milestone with deferred requirements (CISPEED-01/02, CIREL-01, CIDX-02). Those stay out of scope for v1.51; any retry needs fresh scope and authorization. Main CI run `42756400672` is green on `970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d`; the working tree remains dirty and is outside that tested source.
