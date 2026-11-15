# ADR 005: Brand adoption compatibility policy

**Status:** Accepted (policy shape). Every recorded decision is confirmed: decision #12 on 2026-11-13, and decisions 1-9, 11 and 14 as recommended by the owner on 2026-11-15.
**Date:** 2026-11-13
**Context:** Phase 259 (v1.51 brand identity adoption). The visual source is brand book v2.0 (2026-11-13), vendored read-only in `brand/`. This record states what the rebrand may and may not change before any visible change is made.

## The problem

Sigra is a hybrid library plus generator with a public SemVer surface on Hex. Adopting a new brand book touches colors, type, logos and wording, and all of those reach adopters through three different channels: library code that updates with `mix deps.update`, templates that are generated into the host once, and host-owned files that nobody refreshes. A rebrand that treats those channels alike would either break hosts that built on today's names or silently change screens that hosts already customized.

The policy below separates the channels (ownership lanes), names what is frozen and what may only grow, records the SemVer treatment, and lists the decisions that later phases (260 to 263) inherit. Nothing in this record changes shipped bytes: Phase 259 is docs and tests only.

## Owner decision table

Numbering follows the milestone owner-decision list. Decisions #10 and #13 belong to later phases (organizations styling in Phase 262, orphaned CSS guards in Phase 260) and are not recorded here.

| # | Decision | Recommended default | Status |
|---|----------|---------------------|--------|
| 1 | `Profile` defaults versus the book's neutrals | Freeze the defaults. The accent already equals the book's accent; the neutrals differ, and moving them is a deferred future requirement. | Confirmed as recommended by owner, 2026-11-15 |
| 2 | Admin typeface | Record additive `--sg-font-sans` and `--sg-font-mono` tokens only, host-inherited by default; Sigra-owned surfaces self-host two woff2 files in Phase 261. | Confirmed as recommended by owner, 2026-11-15 |
| 3 | SemVer level | Minor release; `feat`, `fix` and `docs` commit types only; no `!` marker; no BREAKING footer; a "Visual and copy changes" changelog section; nothing hand-added under CHANGELOG "Unreleased". | Confirmed as recommended by owner, 2026-11-15 |
| 4 | Changed msgids | Targeted renames per surface with an old-to-new rename table; tier-1 strings, route paths, helpers and the `sigra` domain untouched. | Confirmed as recommended by owner, 2026-11-15 |
| 5 | Suspended, unlock and seven-day rule | Out of scope; a seed is filed by the milestone owner, nothing is built here. | Confirmed as recommended by owner, 2026-11-15 |
| 6 | Status labels | Adopt Active, Unconfirmed and Locked; keep "Deletion scheduled" because it names a reversible grace period. | Confirmed as recommended by owner, 2026-11-15 |
| 7 | PNG-lane policy | Park: demote the two PNG-compare lanes from PR-blocking to dispatch at the end of Phase 260. | Confirmed as recommended by owner, 2026-11-15 |
| 8 | Vendoring scope and pin | Pin the whole tracked `brand/` tree (72 files) with one root manifest; document the consumed subset as a table. | Confirmed as recommended by owner, 2026-11-15 |
| 9 | Generate versus verify | Verify only: no builder, no new Mix task. | Confirmed as recommended by owner, 2026-11-15 |
| 11 | Install-pin shape | A test enforces the three-segment shape and equality now; the value bump happens in Phase 263. | Confirmed as recommended by owner, 2026-11-15 |
| 12 | Instruction-file pointer fix | Minimal pointer edit to `CLAUDE.md`, `AGENTS.md` and the two admin guides, pointing at the new `brand/` book. | Owner-approved, confirmed 2026-11-13 |
| 14 | Name and trademark posture; clear-space and logo-use authority | No trademark claim; record the same-name Hex package; clear-space authority recommended as the book's prose rule of 2 T; detailed in ADR 006. | Confirmed as recommended by owner, 2026-11-15 |

## Frozen list

Frozen means: the name may not be removed or renamed, and a default value may not change in a way that alters what an existing host renders. Counts were measured on 2026-11-13 against the repository (each by a grep or a short script over the named source).

| Category | Measured 2026-11-13 | Source of truth |
|----------|---------------------|-----------------|
| `--sg-*` custom properties (names) | 100 distinct | the generated admin stylesheet template |
| `--sigra-auth-*` custom properties (names) | 35 distinct | the generated auth stylesheet template |
| `sg-*` classes | 112 selectors in the stylesheet; 142 distinct names in markup | admin stylesheet plus admin markup |
| `sigra-auth*` classes | 66 selectors in the stylesheet | auth stylesheet plus generated markup |
| `Sigra.Branding.Profile` keys and default values | 25 keys | `Sigra.Branding.Profile.defaults/0` |
| Config keys and nested option paths | 33 top-level keys, 170 option paths | the `@schema` in `Sigra.Config` |
| Route lines and verified-route helpers | 73 route-DSL lines (54 route lines, 19 scope lines) in the golden install router; 54 distinct `~p` helper literals | golden router fixture and installer templates |
| Gettext domain and msgids | one domain, `sigra`; 344 `dgettext` calls; 180 distinct msgids | installer templates |
| `data-testid` values | 25 | library admin and installer templates |
| Logo filenames and installer targets | `priv/static/images/sigra-logo-primary.svg`, `priv/static/images/sigra-logo-primary-dark.svg`, `priv/static/assets/sigra_admin.css`, `priv/static/assets/sigra_auth.css` | `Sigra.Install.Features.Admin.files/1` and `Core.files/1` |

Custom-property names are frozen; a change of a token's value is a visual change and follows the SemVer treatment in decision 3. `Profile` keys and their default values are frozen as a pair (decision 1). Every msgid is frozen unless it appears as a row in the rename table (decision 4).

The machine-readable baseline for this list is `test/fixtures/brand/frozen-surface.json`, written and owned by Plan 259-05 together with the ratchet test. This record states the policy; the fixture states the current names.

## Add-only list

These surfaces may grow. Additions pass the ratchet; removals and renames fail it.

- New custom properties, for example `--sg-font-sans` and `--sg-font-mono`, and additive status, selected-row and current-tab tokens.
- New `sg-*` and `sigra-auth-*` classes.
- New routes and new verified-route helpers.
- New msgids, including the new side of a rename-table row.
- New `data-testid` values.
- New configuration options and `Profile` keys, with defaults that keep current output.

A rename is never an addition in disguise: the old name stays frozen, and a rename-table row records the pair.

## Ownership lanes

| Lane | What lives there | How a change reaches a host | What an existing host does |
|------|------------------|-----------------------------|----------------------------|
| Library-owned | Admin LiveViews and components, `Sigra.Branding` functions, error messages | Updates with `mix deps.update` | Review the release notes; nothing to copy |
| Generated | Auth LiveViews, controllers, emails, locale files and templates emitted at install | New installs only; an existing host never receives the change on its own | Compare the new template with the local file and adopt what fits; do not overwrite customized files |
| Host-owned | Stylesheets and logo files copied into the host application | Copied once at install and never refreshed | Edit locally; re-copy only on purpose, after comparing |

## Surface map

The "Brand owner" column names who decides the visual identity once a surface ships: `Sigra` for surfaces Sigra itself presents, `host` for surfaces a host application owns, where Sigra only supplies defaults.

| Surface | Brand owner | Visual decision source |
|---------|-------------|------------------------|
| Library admin chrome | Sigra | `brand/BRAND.md` and `brand/tokens.json`; applied in Phases 261 and 262 |
| Generated auth screens | host | Neutral defaults supplied through `Sigra.Branding`; wording in Phase 262 |
| Generated emails | host | The host's `Sigra.Branding` profile; wording in Phase 262 |
| Generated CSS and logo files | host | Copied once at install; default values and logo files from Phase 261 |
| Demo host Tasklane | host | The demo's own mini-brand, separate from the Sigra book (decision #15, Phase 261) |
| ExDoc | Sigra | `brand/assets/docs` and Phase 263 |
| Hex package page | Sigra | Phase 263 |
| README | Sigra | Phase 263 |
| `brand/` book | Sigra | `brand/BRAND.md` itself, brand book v2.0 (2026-11-13) |

## Recorded decisions

Each decision below was proposed as a recommended default and confirmed as recommended by the owner on 2026-11-15 (decision 12 on 2026-11-13).

### Decision 1: Profile defaults frozen

`Sigra.Branding.Profile` keys and default values do not change in v1.51. The default accent already equals the book's accent (`#c2410c`); the default neutrals differ from the book's (for example background `#f7f4ee` versus the book's paper tone, text `#171717` versus the book's soot tone). Moving the defaults to the book's neutrals would change what every host without an explicit profile renders, so it is a deferred future requirement.

Reversibility: cheap. Unfreezing later is an additive decision with its own release note.

### Decision 2: additive font tokens

The admin typeface is recorded as two additive tokens, `--sg-font-sans` and `--sg-font-mono`. They default to the host's typeface (host-inherited); the book's stack is documented as opt-in. Sigra-owned surfaces self-host the two woff2 files with their licence texts in Phase 261. The installer ships no font binaries. No existing token is renamed.

Reversibility: cheap while unreleased; a released token name stays frozen.

### Decision 3: minor release, no breaking marker

v1.51 ships as a minor release. Commits use the `feat`, `fix` and `docs` types only, with no `!` marker and no BREAKING footer. The release notes carry a "Visual and copy changes" section, produced from conventional-commit scopes (Phase 262). Nothing is hand-added under CHANGELOG "Unreleased": release-please owns that block, and a hand-written note there ships inside the released package.

Reasoning: every frozen name stays, so no documented API breaks; visual and wording changes are changes to rendered output, which the contract treats as compatible additions for library-owned surfaces and as opt-in comparisons for generated and host-owned ones.

Reversibility: costly. The SemVer level and the commit footers are fixed at release; undoing it afterwards means a coordinated changelog and documentation correction.

### Decision 4: targeted msgid renames with a rename table

Gettext msgids change only per surface, through an old-to-new rename table. The table starts with a header and no rows; Phase 262 appends rows. Any msgid not listed stays frozen. Pre-auth public-surface strings stay unchanged unless a row carries parity evidence from the surface registry that Plan 259-07 builds. The `sigra` Gettext domain, route paths and route helpers are never renamed.

Reversibility: costly once released, because hosts carry translated catalogs keyed by msgid.

### Decision 5: Suspended, unlock and the seven-day rule are out of scope

No Suspended state, unlock action or seven-day rule is built in v1.51. The milestone owner files a seed for them. Wording that promises a control which does not exist is corrected in Phase 262 rather than built.

Reversibility: cheap. It is a scoping decision.

### Decision 6: status labels

The status labels adopt Active, Unconfirmed and Locked. "Deletion scheduled" is kept, because it names a reversible grace period; a label that reads as immediate deletion would misdescribe it. A Suspended state appears in the catalog only, never in the product.

Reversibility: cheap.

### Decision 7: PNG-lane policy is park

The PNG-compare lanes are parked in a separate small pull request at the end of Phase 260: `admin_checkpoints` (27 PNGs) and `demo_showcase` (4 PNGs) move from PR-blocking to dispatch. The real sign-in and generated-host smoke, axe, golden install and behavior specs stay on the PR path. The impersonation-banner canary is never allowlisted, and no baseline is ever recaptured on darwin. Merging that pull request needs explicit owner approval and happens before Phase 261 starts.

Reversibility: cheap. A lane can return to PR-blocking by reverting the park pull request.

### Related decisions

- **#8 vendoring scope.** The manifest pins the whole tracked `brand/` tree. Pruning would leave the book's own index and manifest pointing at removed files, so "consumed subset" is documented as a table in the public guide, not enforced by deletion.
- **#9 verify only.** Generated output is checked against its sources by tests; no builder, marker-region CSS generator or new Mix task is introduced.
- **#11 install-pin shape.** Documented dependency snippets use a three-segment requirement. The shape and equality across README, guides, docs and templates are enforced now; the value is bumped in Phase 263 together with its contract test.
- **#14 name and clear space.** No trademark claim is made. The clear-space authority is the book's prose rule (2 T, twice the square's side), confirmed 2026-11-15. The book's JSON carries a second, shorter rule that disagrees with it; ADR 006, written by Plan 259-11, records the measurement and the choice.

## Hex install-pin note

Verified on 2026-11-13 with a scratch project against live Hex:

- A two-segment requirement (`~> 1.7`) still resolves to the retired stray 1.20.0 release; Hex prints it as retired, but retirement is advisory and 1.20.0 remains the latest stable version.
- A three-segment requirement (`~> 1.7.0`) resolved 1.7.1.
- The retirement message on 1.20.0 itself recommends the supported `~> 1.5.0` requirement, so a later bump to a `~> 1.7.0` snippet leaves a stale message to revisit.

Decision #11 follows from this: the shape (three segments, all equal) is enforced now; the value moves in Phase 263.

## Consequences

- Later phases cite this record instead of re-deciding: Phase 260 executes the park, Phase 261 applies tokens and type, Phase 262 appends rename-table rows, Phase 263 bumps the install pin and publishes the upgrade guide.
- A maintainer can answer "may I rename this?" from the frozen and add-only lists, and "who updates this for an existing host?" from the lane table.
- The ratchet (Plan 259-05), the lexicon and inventory tests (Plans 259-06 and 259-08) and the doc-contract test for this record make the policy executable rather than advisory.
- All recorded decisions are confirmed. A later change to any of them is a dated in-place amendment to this record.

## Revisit triggers

Revisit this decision if the owner declines a recommended default, if a phase needs to rename a frozen name, if the release-please configuration changes how sections or footers are produced, or if the Hex retirement state of the stray 1.20.0 release changes. Amendments follow the dated, in-place retraction style established by ADR 003; this record is not silently rewritten.

## Amendment 2026-11-15: owner confirmation and the SC-4 reading

**A. Owner confirmation.** On 2026-11-15 the owner confirmed decisions 1-9, 11 and 14 as recommended ("follow your recs"), together with the two decisions in ADR 006 (clear-space and logo-use). No decision text changed; only the status of each row moved from a recommended default to confirmed.

**B. The SC-4 reading.** SC-4 means "every pre-auth surface has an asserted, honest state". It does not mean every listed surface is identical. Registration and passkey sign-in options stay registered as known divergences: the registry asserts that they still differ, and the public docs list them as not covered.

Both divergences are real account-existence leaks, and a phase that ships zero changed bytes cannot fix them. The owner's direction is that they are fixed as shipped-byte work before Phase 262. Two todos track them:

- `.planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md` covers registration. It handles the timing oracle and notes that the auto-sign-in versus flash difference is inherent to signing a new account in, so the fix does not promise that part becomes identical.
- `.planning/todos/pending/2026-11-13-passkey-options-email-existence-oracle.md` covers passkey sign-in options.

Two further todos name generated-host fixes that go with the same shipped-byte work before Phase 262:

- `.planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` covers the generated confirmation routes.
- `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md` covers the generated reset request page.
