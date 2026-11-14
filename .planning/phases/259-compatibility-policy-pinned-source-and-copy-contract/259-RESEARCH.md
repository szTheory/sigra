# Phase 259: Compatibility Policy, Pinned Source and Copy Contract - Research

**Researched:** 2026-11-13
**Domain:** Docs-and-tests-only guardrail phase for a brand-book adoption in a hybrid library + generator (Elixir/Phoenix, public SemVer API on Hex)
**Confidence:** HIGH on repo facts, commands and mechanisms (read or run this session); MEDIUM on ExDoc link behavior and the Playwright selector (not run); the owner-decision defaults are recommendations, not confirmed decisions

<user_constraints>
## User Constraints (from CONTEXT.md)

No `259-CONTEXT.md` exists for this phase; the user chose to continue without it. Per the orchestrator brief, the ROADMAP success criteria and REQUIREMENTS text are treated as the locked decisions. Nothing below was invented by discuss-phase.

### Locked Decisions
Copied from `.planning/ROADMAP.md` (Phase 259) and `.planning/REQUIREMENTS.md` (BPOL-01..07, BCOPY-01..07):

- **Goal:** "A maintainer can state, and a test enforces, exactly what the rebrand may and may not change: the policy is written, the brand book is pinned in-repo, and the copy and enumeration-safety contracts are under test before any visible change is made."
- **SC-1:** ADR, `contract.md` section and `guides/reference/brand-compatibility.md` contain the frozen list, add-only list, ownership-lane table (library-owned / generated / host-owned), the surface map naming the brand owner of each surface, the recorded decisions (`Profile` defaults frozen, additive font tokens only, minor SemVer with no `!`/BREAKING, targeted msgid renames with a rename table, Suspended/unlock/seven-day rule out of scope, "Deletion scheduled" kept, PNG-lane policy) plus an upgrade-note skeleton.
- **SC-2:** The consumed brand-book subset sits in `brand/` with a root `brand.sha256`; editing any vendored byte turns the single ExUnit drift test red; every imported file (including SVG/PDF metadata) passes the privacy scan; `brandbook/` is untouched; `git diff --stat -- lib priv` is empty for the whole phase (zero shipped bytes).
- **SC-3:** Frozen-surface ratchet test (CSS custom properties, `sg-*`/`sigra-auth-*` classes, `Profile` keys and defaults, config keys, routes/helpers, Gettext domain, `data-testid`s, logo filenames) is green, can only grow, and legacy Branding profiles render byte-identically.
- **SC-4:** Reconciled vocabulary table, per-lane copy inventory, banned-term/lexicon drift test with shrink-only baseline, and three-segment install-snippet test all pass; enumeration-parity tests pass for every pre-auth surface and go red exactly once when a deliberately leaky string is injected; the eight "Log in" Playwright locators are replaced by the test-only `loginSubmit` helper; docs and tests claim no enumeration safety beyond what is proven.
- **SC-5:** Name-clearance record titled "search log, not clearance" listing the same-name `crosswake_sigra` Hex package, with a claims register and decisions on logo-use statement and clear-space authority and no trademark claim; the instruction-file pointer fix (`CLAUDE.md`, `AGENTS.md`, admin guides) lands only after explicit owner approval (BPOL-06 records approval granted 2026-11-13, "pointers to the new `brand/` book"); the privacy grep and process budget hold.
- **Milestone-wide gates that apply here** (`.planning/ROADMAP.md`): frozen-surface ratchet, enumeration parity, privacy grep, process budget, owner approval (nothing pushed/merged/released/tagged without explicit approval; no `!`/BREAKING footer; nothing hand-added under CHANGELOG "Unreleased").
- **Owner decisions needed per ROADMAP:** #1 `Profile` defaults frozen; #2 admin typeface (record); #3 SemVer level; #4 changed msgid policy; #5 Suspended/unlock out of scope; #6 status labels; #7 PNG-lane policy (decide); #8 vendoring scope and pin; #9 verify-not-generate; #11 install-pin shape; #12 instruction-file pointer fix (approved); #14 name/trademark posture and clear-space/logo-use authority. Recommended defaults for each are in "Owner-Decision Defaults" below; only #12 is confirmed.

### Claude's Discretion
No CONTEXT.md, so there is no explicit discretion list. Implementation shape (file names, helper modules, extraction method for the copy inventory, how the parity harness is structured, how the ADR is numbered) is research-recommended below and flagged `[ASSUMED]` where it is a design choice rather than a repo fact.

### Deferred Ideas (OUT OF SCOPE)
From `.planning/REQUIREMENTS.md` "Future Requirements" and "Out of Scope": Suspended/unsuspend/admin-unlock actions and the seven-day rule (file a seed, do not build); Storybook-style catalog framework; moving `Profile` defaults to the book's neutrals; admin-managed copy, locale-aware routing, RTL, per-organization wording; full guide sweep; trademark claim, look-alike and register search; the repo-wide personal-name/home-path CI guard (own todo); retiring stray Hex 1.20.0; a brand generator / marker-region CSS builder / new Mix task; new PNG baselines, receipts, ledgers, hermetic fakes of external services; renaming any public module, config key, token, class, route; font binaries shipped by the installer; any push, merge, release, tag or announcement without approval.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BPOL-01 | Compatibility policy: ADR + `contract.md` section + `brand-compatibility.md`: frozen list, add-only list, lane table, SemVer treatment, surface map | Frozen/add-only inventories measured (Architecture Patterns, "Frozen-surface inventory"); lane and surface tables drafted; ADR precedent `.planning/decisions/00N-*.md` (next number 005); `contract.md` is not pinned by any test; `doc/llms.txt` index trap (Pitfall 6) |
| BPOL-02 | Brand book vendored in `brand/` with root `brand.sha256`, one ExUnit drift test, `.gitattributes`, `brandbook/` untouched, privacy scan | `brand/` is already tracked (PR #379, 72 files); manifest prototype verified 72/72 with `shasum -a 256 -c`; privacy scan run clean; scope question (prune vs pin all) is the top open question |
| BPOL-03 | Add-only ratchet test + legacy Branding profile byte-identity | Extraction sources identified per category (installer `files/1`, golden router, `Profile.defaults/0`, `@schema` AST walk, CSS regex); 25 `data-testid`s; fixtures design |
| BPOL-04 | Name-clearance record "search log, not clearance", `crosswake_sigra`, claims register, logo-use and clear-space decisions | Fresh lookups run 2026-11-13 (Hex, npm, PyPI, RubyGems, crates, GitHub); clear-space conflict measured from SVGs; claims-register candidates listed |
| BPOL-05 | Decision records | Owner-Decision Defaults table; PNG-lane facts read from live `ci.yml`; Hex retirement state corrected |
| BPOL-06 | Instruction-file pointer fix (approved) | Exact lines located in `CLAUDE.md`, `AGENTS.md`, two admin guides; wording caveat (do not claim token values already align) |
| BPOL-07 | Upgrade-note skeleton | Format precedent `guides/introduction/upgrading-to-v1.46.md`; lives as a section of `brand-compatibility.md` |
| BCOPY-01 | Reconciled vocabulary table | Book terms (`brand.json` `voice.terms`) x `admin-glossary.md`; product-truth anchors with file:line |
| BCOPY-02 | Banned-term/lexicon drift test, shrink-only baseline | `glossary_test.exs` precedent; do-not-say lexicon baseline already contains negation hits; scanner design |
| BCOPY-03 | Enumeration-boundary contract, parity tests, positive control | Surface registry design; **two surfaces will not be parity-green today** (passkey email-keyed options; registration success vs duplicate) plus lockout/rate-limit channels; known-divergence model |
| BCOPY-04 | Committed copy inventory per ownership lane | AST + HEEx extraction prototype sized (about 265 literals and about 400 unique HEEx text lines in the library lane; 180 unique msgids in generated lane) |
| BCOPY-05 | Three-segment install-snippet test | All 11 occurrences enumerated; existing `phase_242` test pins `~> 1.5.0`; live Hex resolution proof for two-segment vs three-segment |
| BCOPY-06 | Test-only `loginSubmit` helper | 11 locators in 6 files (not 8); selector derived from both login button markups; `probe(selector)` needs a string constant too |
| BCOPY-07 | Honest-claims pass | Claim sites located in guides; **lib moduledoc over-claims cannot be edited in this phase (zero `lib/` bytes)** so they become filed todos |
</phase_requirements>

## Summary

Phase 259 is a guardrail phase: ten-ish new test files, a handful of fixtures, three policy documents, one name-clearance record, and small edits to instruction files, guides and Playwright specs. It must change zero bytes under `lib/`, `priv/` and `brandbook/`, add nothing under `.github/`, and add at most a trivial amount under `scripts/` (recommended: nothing). Everything the plan needs already exists in the repo: the brand book is already tracked in `brand/` (PR #379), `Sigra.Branding.Profile.defaults/0` and the installer `files/1` functions are public, the golden fixture contains the real generated router, and the closest test precedents are `test/sigra/admin/glossary_test.exs` (banned-term scanner), `test/sigra/planning/phase_242_shift_left_contract_test.exs` (install-snippet pin) and the example app's ConnTest suites (enumeration-safe flashes).

Four findings change the plan relative to the milestone research and must reach the planner before decomposition. (1) **The enumeration-parity tests cannot all be parity-green on current code**: the email-keyed passkey options endpoint answers `{error: "unavailable"}` for an unknown email and `{options: ...}` for an existing one (template and example), registration returns a different outcome for new vs duplicate, `Lockout.check(nil)` makes lockout a repeat-attempt channel, and `request_magic_link`/`request_password_reset` rate-limit only existing users (masked at the controller today). SC-4 and BCOPY-07 are reconcilable only through a "known divergence" registry state that is asserted (so it shrinks when fixed) and a claims pass that states exactly what is proven; fixing the leaks needs `priv/` bytes and is out of scope. (2) **`brand/` is already vendored in full (72 files)**, so BPOL-02 is "pin and scan what is there", and the "consumed subset" wording forces a prune-vs-pin-all decision that the research recommends settling as pin-all. (3) **There are 11 `Log in` text locators in 6 files**, not 8. (4) **Stray Hex 1.20.0 is already retired** (API 2026-11-13) but still resolves for `~> 1.7`; the retirement message itself recommends `~> 1.5.0`. Also: `crosswake_sigra` links to a repository under the same GitHub owner as this project, which reframes the name-collision record from "third-party conflict" to "own companion package".

**Primary recommendation:** Build the phase as seven small plans over three waves (policy docs, source pin, ratchet + legacy fixtures, copy contract, parity harness + honest claims, `loginSubmit`, name-clearance record) with one shared phase gate (`MIX_ENV=test mix ci` + example suite + the zero-bytes/privacy/budget greps), pin the whole already-tracked `brand/` tree, model non-provable parity as asserted known divergences, and never edit `lib/` or `priv/` to make a test green.

## Project Constraints (from CLAUDE.md)

- **Stack:** Phoenix 1.8+/Ecto 3.x blessed path; minimal transitive deps; "Copy-paste over deps when code is small and stable". No new dependencies in this phase (milestone rule).
- **Security:** OWASP standards throughout; "Enumeration prevention by default"; tokens HMAC-protected. Treat any enumeration claim as security-model documentation.
- **Testing:** "Comprehensive spec coverage — happy path, main error cases, boundary conditions. AAA style, flat, self-contained."
- **Local prerequisites:** `mix test` needs live Postgres (`scripts/db/up.sh`, then `source tmp/db.env`); no `:postgres` tag exclusion; the install golden tests need `phx_new 1.8.8` (`mix archive.install --force hex phx_new 1.8.8`).
- **Admin UI direction:** follow `guides/reference/admin-ui-principles.md` and `admin-design-contract.md`; preserve `sg-*` cascade-layer/BEM; Light/Dark/System; deterministic browser tests. (The "Rail Accent ... `brandbook/`" clause in this very paragraph is the BPOL-06 edit target.)
- **GSD workflow enforcement:** file-changing work goes through a GSD command; no direct repo edits outside it.
- **`AGENTS.md`:** automation-first verification (never waive or auto-approve missing evidence); at most one CI watcher per run, never the 3-second default `gh run watch`; check `gh api rate_limit` before long watches.
- **Project memory constraints relevant here (non-personal):** the repo is public (no adopter PII, no personal names or home paths in commits, docs or fixtures; grep the pushed diff, not memory); `MIX_ENV=test mix ci` is the local gate and root `mix test` misses formatting and `test/example`; squash-merge preference; nothing pushed/merged/released/tagged without approval.

## Architectural Responsibility Map

"Tier" here means ownership lane or surface owner, because this phase has no runtime tiers of its own.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Compatibility policy (frozen/add-only lists, lanes, surface map) | Maintainer docs (`.planning/decisions`, `guides/`) | `guides/introduction/contract.md` (public) | Policy is prose plus tests; no shipped code |
| Brand-book source of truth | Repo-only reference (`brand/`, `brand.sha256`) | ExUnit pin test | Not packaged on Hex (`files:` is `lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md`) |
| Frozen-surface ratchet | ExUnit over library, installer, golden fixture | `test/fixtures/brand/*.json` baselines | Frozen names live in `priv/templates` CSS/markup, `lib/sigra/**`, installer manifests |
| Legacy Branding byte-identity | Library (`Sigra.Branding`, `Sigra.Branding.Profile`) | ExUnit + committed expected strings | Pure functions; no DB needed |
| Vocabulary/lexicon enforcement | ExUnit scanner over library admin files, templates, README/guides | `guides/reference/admin-glossary.md` | Extends the existing admin glossary drift guard |
| Enumeration parity | Example host app ConnTest/LiveViewTest | Library `Sigra.Auth` (decides existence behavior) | Example is the only executable host in the root repo; generated templates are not compiled by root tests |
| `loginSubmit` helper | Playwright subproject (`test/example/priv/playwright`) | CI shards (`example_playwright_shard`) | Test-only; runs against the booted example |
| Name-clearance record, claims register | Maintainer docs (`.planning/decisions`) | Registry/API lookups (web) | Not shipped; gates Phase 263 copy |
| Instruction-file pointers | Repo root agent instruction files (`CLAUDE.md`, `AGENTS.md`) | `guides/reference/admin-*.md` | Executors follow these; approved edit |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExUnit (bundled with Elixir) | Elixir 1.19.5 / OTP 28.5 `[VERIFIED: .tool-versions, elixir --version]` | All new root and example tests | Existing suites use it; `mix ci` runs it |
| Elixir stdlib `:crypto`, `Path`, `File`, `Code.string_to_quoted/2`, `JSON` | same | SHA-256 manifest, file walking, AST extraction, fixture JSON | No dependency; prototypes below were run this session |
| `Phoenix.ConnTest` / `Phoenix.LiveViewTest` | `phoenix_live_view ~> 1.1` in root `mix.exs`; example adds `lazy_html` test-only | Parity tests in the example host | Existing example tests use both |
| Playwright Test | 1.59.1 `[VERIFIED: test/example/priv/playwright/package-lock.json]` | `loginSubmit` helper consumers | Already the browser harness |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `shasum` / `sha256sum` | system | Independent manifest check (`shasum -a 256 -c brand.sha256`) | Human/bare-CI verification; verified 72/72 this session |
| `python3 -I` | 3.14.4 | Optional ad-hoc metadata inspection only | Never in repo tests |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Root-level `brand.sha256` + ExUnit | Git tree OID, subset pin, hex/git dep | OID gives no per-file diff and needs git at test time; the book is data not code |
| Example-host parity tests | Library-only `Sigra.Auth` result-shape tests | Library tests prove existence-independence of return shapes but not flashes/redirects; do both only if cheap (see Pitfall 3) |
| Prune `brand/` to a subset | Pin the whole tracked tree | See Open Question 1; recommended default is pin all |

**Installation:** none. No packages are installed in this phase.

**Version verification:** no recommended package is new. Versions above were read from `.tool-versions`, `elixir --version`, and `test/example/priv/playwright/package-lock.json` (`@playwright/test` 1.59.1, `@axe-core/playwright` 4.13.0).

## Package Legitimacy Audit

Not required: this phase installs no external packages (milestone rule "Net-new dependencies: none"). `crosswake_sigra` is referenced as a name-collision fact only and is never installed.

## Architecture Patterns

### System Architecture Diagram

```
 brand/ (tracked, byte-exact) ----sha256----> brand.sha256 (root manifest)
        |                                           |
        | read-only sources                         v
        |                              test/sigra/brand/source_pin_test.exs
        |                                (drift + privacy scan + control)
        v
 brand.json (voice.terms, messaging "Do not say") -----+
                                                        v
 lib/sigra/admin/** ----+                   test/sigra/brand/copy_contract_test.exs
 priv/templates/** -----+--> scanner -----> copy-baseline.json (shrink-only)
 README + guides --------+                  copy-inventory/{library,generated,host}.tsv
                                            (exact-equality, regenerate on demand)

 Profile.defaults/0, Config @schema (AST), installer files/1, golden router,
 CSS regex, testid regex --> current surface set
                                   |  baseline subset-of current?
                                   v
 test/fixtures/brand/frozen-surface.json --> test/sigra/brand/frozen_surface_test.exs
 test/fixtures/brand/legacy-profiles.json -> legacy_profiles_test.exs (Branding.* byte-identical)

 test/fixtures/brand/public-surfaces.json (registry)
        |                                   
        v                                   
 example host ConnTest/LiveViewTest: probe(existing) vs probe(unknown)
   -> normalize -> compare -> :same | :known_divergence (asserted) | :diff (red)
   + positive control: inject leak into exactly one surface => exactly one :diff

 README/guides/docs/priv templates --regex--> {:sigra, "~> x.y.z"} shape + all-equal test

 test/example/priv/playwright/helpers/loginSubmit.ts --> 6 files, 11 call sites
```

### Recommended Project Structure
```
.planning/decisions/005-brand-adoption-compatibility-policy.md          # ADR: decisions (BPOL-01, BPOL-05)
.planning/decisions/006-name-clearance-search-log-and-claims-register.md # BPOL-04, titled "search log, not clearance"
guides/reference/brand-compatibility.md        # frozen/add-only lists, lane table, surface map, SemVer table, upgrade-note skeleton
guides/introduction/contract.md                # + "## Brand and visual compatibility" section (reference guide by backticked path)
guides/reference/admin-glossary.md             # + "Brand book v2.0 reconciliation" section (BCOPY-01)
brand.sha256                                   # root manifest (outside brand/)
.gitattributes                                 # brand/** -text linguist-vendored   (file does not exist today)
test/sigra/brand/
  source_pin_test.exs                          # drift + privacy scan + planted-failure control (BPOL-02)
  frozen_surface_test.exs                      # ratchet (BPOL-03)
  legacy_profiles_test.exs                     # Branding byte-identity (BPOL-03)
  copy_contract_test.exs                       # lexicon baseline + inventory (BCOPY-02, BCOPY-04)
  install_snippet_test.exs                     # three-segment, all-equal (BCOPY-05)
test/support/brand/                            # Sigra.Test.Brand.* helpers (compiled in :test via elixirc_paths)
test/fixtures/brand/
  frozen-surface.json  legacy-profiles.json  copy-baseline.json  public-surfaces.json
  copy-inventory/{library,generated,host}.tsv
test/example/test/example_web/enumeration_parity_test.exs   # parity harness (BCOPY-03)
test/example/priv/playwright/helpers/loginSubmit.ts         # BCOPY-06
```
`test/fixtures/` is excluded from test discovery by `test_ignore_filters` in root `mix.exs` (so JSON/TSV there is data only). `.formatter.exs` formats `test/{sigra,support,mix}/**/*.{ex,exs}` and `test/example/{lib,config,test,priv}/**/*.{ex,exs}`; every new `.ex/.exs` must pass `mix format --check-formatted` (first step of `mix ci`). `[VERIFIED: mix.exs:30-35 test_ignore_filters; .formatter.exs inputs]`

### Pattern 1: Pin the whole vendored tree with one manifest and one test
**What:** root `brand.sha256` in `shasum -c` format; one ExUnit module regenerates the manifest in memory, diffs it against the committed file, and prints added/removed/changed paths. A second test in the same module mutates one in-memory file and asserts the diff function reports it (positive control).
**Prototype run this session (stdlib only):** produced 72 files / 7,436 bytes; `shasum -a 256 -c` printed 72 `OK`.
```elixir
files =
  Path.wildcard("brand/**/*", match_dot: true)
  |> Enum.filter(&File.regular?/1)
  |> Enum.reject(&(Path.basename(&1) == ".DS_Store"))
  |> Enum.sort()

manifest =
  for f <- files, into: "" do
    "#{Base.encode16(:crypto.hash(:sha256, File.read!(f)), case: :lower)}  #{f}\n"
  end
```
Notes: sort by Elixir binary order (the order `shasum -c` does not care about but diffs do); normalize `\r\n` to `\n` when reading the committed manifest; add `.gitattributes` line `brand/** -text linguist-vendored` (no `.gitattributes` exists today `[VERIFIED: file absent at repo root]`); the test constants `@book_version "2.0"` and the date are asserted against `brand/brand.json` (`"version": "2.0"`, `"date": "November 13, 2026"`). Print the regeneration one-liner in the failure message; no new script is needed (keeps `git diff --stat scripts` empty).
**Privacy scan (same module):** scan every file under `brand/` for home-directory path shapes (`/Users/<x>`, `/home/<x>`, `C:\Users`), emails not ending in `.test`, and, for binaries, PDF `/Author` + `/Creator` + `/Producer`, PNG text chunks (`tEXt`/`iTXt`/`zTXt`/`eXIf`), SVG `<metadata>`/`dc:creator`/`inkscape:`/`sodipodi`. Never embed a personal name in the test: personal-name and home-path checks of the pushed diff are phase-gate shell greps whose patterns are derived at run time from `$HOME` and `id -un` (word-boundary match), plus a planted-failure control. Result of the scan run this session: clean (see Verified Facts).

### Pattern 2: Ratchet = superset check against a committed baseline, extraction from sources of truth
**What:** for each category, extract the current set from its source of truth; assert `baseline ⊆ current`; additions pass (and may print a note). A regeneration flag in the test module may only write a baseline that is a superset of the committed one (refuses to shrink). The pure comparison function gets unit tests: removal => red, addition => green.
Extraction sources (all verified to exist this session):

| Category | Source of truth | How | Measured |
|----------|-----------------|-----|----------|
| CSS custom properties `--sg-*` | `priv/templates/sigra.install/admin/sigra_admin.css` | regex `--sg-[a-z0-9-]+` | 100 distinct |
| CSS custom properties `--sigra-auth-*` | `priv/templates/sigra.install/core/sigra_auth.css` + `Sigra.Branding.css_variables(Profile.default())` | regex + function output | 35 distinct in CSS; 14 emitted by `css_variables/1` |
| `sg-*` classes | CSS class selectors + `class="..."` attrs in `lib/sigra/admin/**` and `priv/templates/sigra.install/admin/**` | union of both sets | 112 selectors; 142 in markup |
| `sigra-auth*` classes | `sigra_auth.css` selectors + `priv/templates/sigra.install/**/*.ex` | union | 66 selectors; 56 in markup |
| `Profile` keys and defaults | `Sigra.Branding.Profile.defaults/0` (public) | `Map.to_list` -> sorted JSON | 25 keys (see quote) |
| Config keys | `lib/sigra/config.ex` `@schema` | `Code.string_to_quoted/1` + recursive walk of `keys:` | 33 top-level, 170 option paths (prototype run) |
| Routes | golden router `test/fixtures/install_golden/tree/lib/*_web/router.ex` | trimmed lines starting `live|get|post|put|patch|delete|forward|scope "` with the tmp app alias normalized | about 50 lines |
| Helpers | `~p"..."` verified-route literals in `priv/templates/sigra.install/**` | regex | 54 distinct |
| Gettext domain | `dgettext("<domain>", ...)` in templates | regex | one domain, `"sigra"`, 344 calls, 180 unique msgids |
| `data-testid`s | lines containing `testid` in `lib/sigra/**` and `priv/templates/sigra.install/**`; quoted strings starting `admin-` or `mfa-` | regex | **25** (not 13: 13 are plain `data-testid="..."`, 3 are `if @active` literals in `preview_pair/1`, 9 are `*_testid=` args from `branding_live.ex`) |
| Logo filenames + installer targets | `Sigra.Install.Features.Admin.files/1` and `Core.files/1` | call with a fixed binding (`otp_app: :my_app`, `web_module: "MyAppWeb"`) | targets quoted below |

Verbatim values the ratchet will freeze (read this session):

- `lib/sigra/branding/profile.ex:42-68` `@defaults` includes `accent_color: "#c2410c"`, `accent_foreground: "#ffffff"`, `background_color: "#f7f4ee"`, `surface_color: "#ffffff"`, `text_color: "#171717"`, `muted_color: "#6b6258"`, `border_color: "#ded8cf"`, `product_name: "Your app"`, `logo_alt: "Application logo"`, `email_from_name: "Your app"`, `theme: :system`, and `nil` for logo/dark/support/privacy/terms/email-address fields. `[VERIFIED: lib/sigra/branding/profile.ex:42-68]`
- `lib/sigra/install/features/admin.ex:52-55,60`: `{:eex, "admin/sigra-logo-primary.svg", Path.join(["priv", "static", "images", "sigra-logo-primary.svg"])}`, `{:eex, "admin/sigra-logo-primary-dark.svg", Path.join(["priv", "static", "images", "sigra-logo-primary-dark.svg"])}`, `{:eex, "admin/sigra_admin.css", Path.join(["priv", "static", "assets", "sigra_admin.css"])}`. `[VERIFIED: lib/sigra/install/features/admin.ex:52-60]`
- `lib/sigra/install/features/core.ex:256`: `{:eex, "core/sigra_auth.css", Path.join(["priv", "static", "assets", "sigra_auth.css"])}`. `[VERIFIED: lib/sigra/install/features/core.ex:256]`

Baseline file lives at `test/fixtures/brand/frozen-surface.json`; because additions pass silently, add a phase-gate check that the baseline file diff has no deleted lines: `git diff <base>..HEAD -- test/fixtures/brand/frozen-surface.json | grep '^-[^-]'` must be empty.

### Pattern 3: Legacy Branding byte-identity = committed expected outputs for three profile shapes
Scope is the `Sigra.Branding` public functions, not admin chrome: for each of three shapes (explicit: all seven light and seven dark colors plus logo URLs; partial: `product_name` + `accent_color` only; defaults: `Profile.default()`), commit the expected string/map for `Branding.css_variables/1`, `Branding.color_tokens/2` (`:light` and `:dark`), `Branding.logo/2` (both themes), `Branding.email_logo/1`, `Branding.dark_accent_source/1` and `Profile.to_map/1`; the test asserts `==` (byte equality for strings). These are pure functions (no DB). Do **not** freeze `preview_pair` HTML or admin copy: Phase 262 intentionally rewords the branding workbench ("Login preview" to "Sign-in preview"), so freezing it would contradict the roadmap. `[VERIFIED: lib/sigra/branding.ex css_variables/1, color_tokens/2 read this session]`

### Pattern 4: Copy contract = three-scope scanner + shrink-only baseline + per-lane inventory
- **Scanner scopes (new module `Sigra.Test.Brand.CopyScan` plus `copy_contract_test.exs`; leave `glossary_test.exs` untouched, it is green and has its own carve-outs):** (a) admin files: the existing nine files plus the shipped admin templates; term list = glossary_test's list plus phrase-level entries; (b) generated templates `priv/templates/sigra.install/**`: own list where "log in/log out/login/logout" as copy is banned but identifiers (`log_in_user`, `/users/log_in`, `[:sigra, :auth, :logout, :stop]`) are not; (c) README + `guides/introduction/*.md` + `guides/flows/*.md`: **lexicon-only** (the book's "Do not say" list from `brand.json` `messaging.boilerplate`: hosted, managed, bank-grade, military-grade, unbreakable, zero trust, seamless, robust, compliant, certified).
- **Baseline:** `test/fixtures/brand/copy-baseline.json` of `{scope, file, normalized line}` entries (no line numbers, so unrelated edits do not churn it). Rules: a hit not in the baseline fails; a baseline entry with no matching hit fails with "remove this entry" (shrink-only). The lexicon baseline starts non-empty because the repo's own negations match: `README.md:13` ("a hosted identity product"), `guides/introduction/contract.md:61` ("A hosted control plane or managed identity service."), `SECURITY.md:27`, `guides/flows/oauth.md:81`, `guides/introduction/installation.md:90` ("managed from the generated admin UI"), `guides/recipes/subdomain-auth.md:12,35`, `guides/introduction/migrating-from-pow-guardian-ueberauth.md:42`. `[VERIFIED: grep run this session]` Baseline them; do not edit prose to make the scan pass. `brand.json` itself says "not hosted auth, not a compliance certificate" so a naive grep fails on the book's own sentences.
- **Template scan size today:** about 64 raw hits for `log in/out/login/logout/signin` in `priv/templates/sigra.install`, most in comments/docs/identifiers; only the copy-bearing ones belong in the baseline (examples: `core/emails.ex:98,100,109,111,118,129,137,324,331,338,344,666,674`, `core/user_auth.ex:329,431`, `core/error_handler.ex:23`, `core/confirmation_live.ex:48,93,99,113`, `core/reset_password_live.ex:41`, `core/registration_live.ex:16`, `core/session_live.ex:95`). `[VERIFIED: grep run this session]`
- **Inventory (BCOPY-04):** three TSVs, one per lane, sorted, `file<TAB>kind<TAB>string`, no line numbers, exact-equality test with an opt-in regeneration flag. Lane contents: *library* = string literals (AST, excluding `@doc/@moduledoc/@spec/@type`) and `~H` text nodes in `lib/sigra/admin/**`, plus `lib/sigra/error.ex` safe messages; *generated* = the 180 unique `dgettext("sigra", ...)` msgids, raw `put_flash` literals, HEEx text and email bodies in `priv/templates/sigra.install/**`; *host* = `Sigra.Branding.Profile` default strings and an explicit "no Sigra copy by design" line (host-owned CSS/logos carry no copy; the example/Tasklane demo is the host exemplar and out of lane). Prototype AST run on the library lane found 265 literals containing whitespace and 32 `~H` blocks yielding about 666 text lines (399 unique) with a naive tag strip; a real extractor must collapse multi-line tags first. `[ASSUMED]` extraction design.

### Pattern 5: Enumeration parity harness with known-divergence states and a positive control
- **Registry** `test/fixtures/brand/public-surfaces.json`: one row per pre-auth surface with `id`, `route`, `kind` (controller/liveview/json), `probe` hints, `compare` dimensions (status, redirect location, flash text, normalized body, email presence/subject), `state` (`parity` | `known_divergence` | `by_design`), and `note`/todo reference. Tests read it via a repo-relative path from `test/example`.
- **Comparator** is a pure function `compare(a, b)` returning `:same | {:diff, details}`; normalize CSRF tokens, request ids, and the echoed email input value. A `known_divergence` row asserts the divergence still exists (so fixing the product forces the registry to be updated, the same shrink-only discipline as the lexicon baseline).
- **Positive control:** `run_all(registry, leak: {surface_id, "No account found for"})` appends a leaky string to the unknown-identity response of exactly one surface; assert exactly one `{:diff, _}` and the rest unchanged. This proves the comparator and the harness can go red once, without putting a leak switch in app code.
- **Where:** `test/example/test/example_web/enumeration_parity_test.exs` with `@moduletag :example_app`, using `ExampleWeb.ConnCase` and `Example.AccountsFixtures` like `session_controller_test.exs`. Verified runnable this session: `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/controllers/session_controller_test.exs` printed `13 tests, 0 failures` after `mix deps.get`, `mix ecto.create`, `mix ecto.migrate`.
- **Surface table (what to expect today; every row was read in source this session unless marked):**

| Surface | Route / code | Expected state today | Evidence |
|---------|--------------|----------------------|----------|
| Sign-in (password) | `POST /users/log_in`; flash "Invalid email or password" | `parity` at one attempt; **repeat-attempt channel**: unknown email never locks (`Lockout.check(nil)` returns `:ok`), existing email locks after the default threshold and then gets "Too many attempts..." | `[VERIFIED: lib/sigra/lockout.ex:57 "def check(nil, _opts), do: :ok"; lib/sigra/error.ex:160-164]` |
| Magic link request | `POST /users/log_in` `_action=magic_link`; generated controller swallows `{:error, :rate_limited}` | `parity` at controller level | `[VERIFIED: grep priv/templates core/session_controller.ex:43 "{:error, :rate_limited} -> :ok"]`; library returns `{:ok, :sent}` for unknown before the rate limiter check (`lib/sigra/auth.ex:627-645`) |
| Password reset request | `ResetPasswordController.create`, `ResetPasswordLive`; same info flash always | `parity` (response); library `request_password_reset` rate-limits only existing users but the controller ignores the result | `[VERIFIED: lib/sigra/auth.ex:1125-1131 is_nil(user) branch precedes rate_limiter; reset_password_controller.ex create/2 always flashes the same text]` |
| Confirmation resend | `ConfirmationLive` `resend` | `parity` only for the signed-in/known context; generated confirmation routes are broken for hosts (blocker todo) so example proves the example only | `[CITED: .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md]` |
| Registration | `RegistrationLive`: success sets `trigger_submit: true` (auto sign-in), duplicate shows an info flash | `known_divergence` (inherent; plus open timing oracle todo) | `[VERIFIED: priv/templates/sigra.install/core/registration_live.ex:134-143]`, `[CITED: .planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md]` |
| Invitation accept | `/invitations/:token/accept` (token states: invalid, expired, revoked, already_accepted, signup, mismatch) | `by_design` capability-URL surface; assert anonymous + valid token renders the same signup branch whether or not the invitee email has an account | `[CITED: test/example/test/example_web/live/invitation_accept_live_test.exs T1-T20]` (identity-parity dimension is `[ASSUMED]`) |
| MFA challenge | `/users/mfa`, invalid TOTP vs invalid backup code | `parity` on message: both map to "Invalid verification code." | `[VERIFIED: lib/sigra/error.ex:181-182]` |
| Passkey sign-in options | `POST /users/log_in/passkey/options` with `user[email]` | **`known_divergence`: real existence oracle** (unknown => `{error: "unavailable"}`, existing => `{options: ...}`), same in template and example; the `"conditional" => "true"` path has no email and is parity | `[VERIFIED: priv/templates/sigra.install/core/session_controller.ex:141-146 and example controller]` |
| Enterprise SSO discovery (not in the BCOPY-03 list) | `POST /users/log_in` `_action=enterprise` | `by_design`: domain match reveals an active enterprise connection for the email domain, not the user | `[CITED: example session_controller_test.exs "_action=enterprise"]` |

Because the passkey endpoint is a genuine pre-existing leak, **do not make the suite green by editing `priv/templates` or `lib`** (zero-bytes rule). File a todo (fast-follow, same cluster as SEED-011) and register the row as `known_divergence`.

### Pattern 6: `loginSubmit` is a selector constant plus a locator factory
Both login button markups were read: the example host renders `<button class={@class} {@rest}>` with no `type` attribute (`test/example/lib/example_web/components/core_components.ex:113`), the generated component renders `<button type={@type} class={@class} disabled={@disabled} {@rest}>` (`priv/templates/sigra.install/core/sigra_auth_components.ex:84`). A selector that works for both and does not depend on text:
```ts
// helpers/loginSubmit.ts (test-only)
import type { Page } from '@playwright/test';
export const LOGIN_SUBMIT_SELECTOR = '#login_form button:not([type="button"])';
export const loginSubmit = (page: Page) => page.locator(LOGIN_SUBMIT_SELECTOR);
```
Export the string constant as well, because `demo-showcase.spec.ts:287` passes a selector string into `probe(...)`. Call sites (11, in 6 files) `[VERIFIED: grep this session]`: `tests/organizations.spec.ts:73,207,483`; `tests/ga-uat-shift-left.spec.ts:44`; `tests/demo-showcase.spec.ts:187,287,603`; `tests/golden-path.spec.ts:66,157`; `tests/passkey-options.spec.ts:26`; `helpers/adminFlows.ts:77`. `admin-flow-org-admin.spec.ts` only has comments containing "Log in" (no locator). Heading assertions such as "Log in to Tasklane" at `demo-showcase.spec.ts:241,496,512,568,590` are the demo host's own copy and are **not** part of BCOPY-06. Acceptance check: `grep -rn 'has-text("Log in")' test/example/priv/playwright` finds nothing outside comments. Playwright is not installed locally (`node_modules` absent) and there is no `tsconfig.json`, so the real proof is the PR's `example_playwright_shard` lanes (the `golden-path`, `ga-uat-shift-left`, `passkey-options`, `organizations`, `demo-showcase` specs run there); `[ASSUMED]` that the selector resolves uniquely on the live DOM (static reasoning from the two markups; not executed).

### Anti-Patterns to Avoid
- **Editing `lib/` or `priv/` to make a new test pass** (breaks SC-2 zero shipped bytes; use known-divergence + todo).
- **Regenerating a baseline wholesale** (defeats shrink-only/add-only). Regeneration must refuse to remove entries.
- **Scanning route paths, function names, atoms or telemetry names as copy** (`/users/log_in`, `log_in_user`, `[:sigra, :auth, :logout, :stop]` are public API).
- **Extending `glossary_test.exs`'s line-marker approach to templates** (PITFALLS C3): add a separate scanner and keep the existing one intact.
- **Adding a workflow, receipt, ledger, controller or hermetic fake** (process budget; v1.50 regrowth).
- **Editing files inside `brand/`** (breaks the pin; change upstream, re-vendor, re-lock).
- **Adding `brand-compatibility.md` to `mix.exs` `extras` in this phase** (changes tracked `doc/llms.txt`; Phase 263 owns `mix.exs`/ExDoc wiring).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hashing and manifest verification | A custom checksum format or script | `:crypto.hash(:sha256, ...)` + `shasum -c` line format | Human and bare-CI verifiable with stock tools; verified 72/72 |
| Config key inventory | Regex over `lib/sigra/config.ex` text | `Code.string_to_quoted/1` walk of `@schema` | Nested `keys:` make regex brittle; prototype yields 170 paths |
| Route inventory | A router DSL parser with scope-prefix math | Trimmed DSL lines from the golden router (real installer output) | Golden is already a CI hard gate (`rebless_golden --check`) |
| Installer target/logo list | Reading template directories | `Sigra.Install.Features.{Admin,Core,Organizations,Passkeys}.files/1` | Public functions; exact `{:eex, source, target}` tuples |
| Contrast, token, font checks | Anything | Out of scope (Phase 261) | n/a |
| Lexicon matching of the book's wording | A new word list invented here | `brand.json` `messaging.boilerplate` "Do not say" and `voice.terms[].avoid` | Single source; version-pinned by the manifest |
| Existing-vs-unknown assertions | Per-test hand-written diffs | One comparator + registry | Positive control needs one choke point |

**Key insight:** every guardrail here is a comparison between a committed baseline and a value extracted from a source of truth that already exists. The only new code is extraction helpers and comparators; anything bigger is process regrowth.

## Common Pitfalls

### Pitfall 1: Pruning `brand/` leaves the book internally dangling
**What goes wrong:** `brand/index.html` links `sigra-brand-book.pdf`, `preview/*.jpg` and a non-vendored `sigra-brand.zip`; `brand/brand.json` `files[]` and `fonts.files[]` name the variable TTFs and OFL texts. Removing the PDFs/previews/static TTFs yields more dangling references, and BPUB-04 later retargets `axe-brandbook.mjs` at `brand/index.html`.
**Why:** PR #379 landed the whole book; the "consumed subset" wording predates that.
**Avoid:** default to pinning the tracked tree as-is; define "consumed subset" as a documented table inside `brand-compatibility.md` (which files tests/surfaces read; the rest is reference-only). If the owner insists on pruning, do it in its own commit before the manifest is generated and never touch `brand.json`/`index.html`.
**Warning signs:** a plan that deletes files and edits `index.html` or `brand.json` in the same task.

### Pitfall 2: Ratchet that cannot go red
**What goes wrong:** a baseline regenerated from the current tree on every run always passes.
**Avoid:** baseline is committed; the test asserts subset; the unit test of the comparator proves a removal goes red; phase-gate grep proves the baseline diff has no deleted lines.

### Pitfall 3: Parity suite that is green because it asserts less than the claim
**What goes wrong:** a single-attempt happy-path comparison passes while lockout, rate-limit and timing channels stay open, and the docs then claim more than was tested.
**Avoid:** each registry row lists the dimensions compared; anything not compared is written into the claims register as "not proven". Parity here proves the **example host**, which is a hand-maintained copy that already drifts from the templates (for example the template reset page says "We couldn't reset your password. Check the highlighted fields and try again." where the example says "Oops, something went wrong! Please check the errors below."); only `install_smoke` proves a real generated host, and the W-3 todo says generated auth runtime coverage is login-only.

### Pitfall 4: Treating `README`'s `~> 1.5.0` as a bug to fix now
**What goes wrong:** bumping pins in Phase 259 breaks `phase_242_shift_left_contract_test.exs`, which pins `{:sigra, "~> 1.5.0"}` in 10 files, and breaks the plan split (BPUB-05 owns the bump with its contract test).
**Avoid:** the new test checks shape (three segments) and equality across files, not the value. It is green on day one (all 11 occurrences are `~> 1.5.0`).

### Pitfall 5: The book's `~> 1.7` still resolves to the retired stray release
**Verified this session** with a scratch project and live Hex: `{:sigra, "~> 1.7"}` printed `sigra 1.20.0 RETIRED!` / `(invalid) Retired: use the supported ~> 1.5.0 requirement instead.` and locked 1.20.0; `{:sigra, "~> 1.7.0"}` locked 1.7.1. Retirement is advisory; `latest_stable_version` is still 1.20.0 `[VERIFIED: hex.pm API 2026-11-13]`. Project notes that call the stray release "unretired" are stale; the retirement message also names `~> 1.5.0`, so a Phase 263 bump to `~> 1.7.0` leaves a stale message to revisit.

### Pitfall 6: `doc/llms.txt` is tracked and CI-compared
`scripts/ci/check-docs-index.sh` runs in `library_tests_dep_off` after `mix docs --warnings-as-errors`. It lists page titles. Adding a page to `extras` or changing an extra's H1 changes the index and needs a regenerated, committed `doc/llms.txt` (header carries the version, currently `v1.7.2`). Editing section bodies of existing extras (`contract.md`, `admin-ui-principles.md`, `admin-design-contract.md`, flow guides) does not. Leave H1s and `mix.exs` alone. `[VERIFIED: ci.yml:697-700; doc/llms.txt header and page list]`

### Pitfall 7: Links from an extra to a non-extra markdown file
Only 3 of the 18 files in `guides/reference/` are extras; the others are cross-referenced by backticked filename, not by link. Whether ExDoc warns on a relative link to a non-extra `.md` was not run here (it would only surface in CI's `--warnings-as-errors` step). Use a backticked path in `contract.md` (`[ASSUMED]` safe; matches repo convention).

### Pitfall 8: Copy-scan false positives from identifiers and docs
`log_in_user`, `/users/log_in`, `login_form`, telemetry atoms, `@doc` text and comments all contain "log in". Scope the scanner to copy: string literals, `~H` text nodes and attribute copy (`aria-label`, `title`, `placeholder`, `label`, `alt`, `action`), not identifiers or comments.

### Pitfall 9: Eight vs eleven locators and heading assertions
The requirement and SC say eight; the repo has eleven locators in six files. Use the grep acceptance check, not the count. Do not touch the "Log in to Tasklane" heading assertions (demo host copy).

### Pitfall 10: Privacy leaks via the verification itself
The privacy gate must not write the maintainer's name into a test, doc or commit message. Derive patterns at run time (`$HOME` basename, `id -un`, matched whole-word so short names do not match inside words like "json") and keep a planted-failure control. Record provenance as "brand book v2.0 (2026-11-13)" only. `brand/index.html:11` contains an `og:image` URL on the project's public GitHub Pages host (`.../sigra-brand/preview/social.jpg`): a public project URL, not personal data, but it names the book's authoring site; it cannot be edited without re-locking (Open Question 3).

### Pitfall 11: `mix test` needs Postgres even for pure-file tests
`test/test_helper.exs` starts `Sigra.Test.PostgresRepo` whenever Postgrex is loaded. All verification commands assume `scripts/db/up.sh` + `source tmp/db.env` (verified: boots on a dynamic port; `mix test test/sigra/admin/glossary_test.exs test/sigra/error_test.exs` printed `27 tests, 0 failures`; first compile took about two minutes).

## Code Examples

### Config option inventory (prototype run; stdlib only)
```elixir
{:ok, ast} = "lib/sigra/config.ex" |> File.read!() |> Code.string_to_quoted()

schema =
  ast
  |> Macro.prewalk(nil, fn
    {:@, _, [{:schema, _, [kw]}]} = n, nil when is_list(kw) -> {n, kw}
    n, acc -> {n, acc}
  end)
  |> elem(1)

collect = fn collect, kw, prefix ->
  Enum.flat_map(kw, fn
    {key, opts} when is_atom(key) and is_list(opts) ->
      path = prefix ++ [key]
      nested = if is_list(opts[:keys]), do: collect.(collect, opts[:keys], path), else: []
      [Enum.join(path, ".") | nested]
    _ -> []
  end)
end
# => 33 top-level keys, 170 option paths (e.g. "branding", "branding.product_name", ...)
```

### The passkey existence oracle the registry must record
```elixir
# priv/templates/sigra.install/core/session_controller.ex:141-146 (verbatim)
def passkey_authentication_options(conn, %{"user" => %{"email" => email}}) do
  config = Sigra.Passkeys.config()

  case Auth.get_user_by_email(email) do
    nil ->
      json(conn, %{error: "unavailable"})
```
The existing-user branch (lines 148-153) returns `%{options: ...}`.

### Install-snippet shape test (design)
```elixir
@snippet ~r/\{:sigra,\s*"([^"]*)"/
# collect {file, requirement} over README.md, guides/**/*.md, docs/**/*.md, priv/templates/**/*
# assert every requirement =~ ~r/^~> \d+\.\d+\.\d+$/   (three segments)
# assert MapSet.size(MapSet.new(requirements)) == 1    (all equal)
# assert at least one occurrence exists in README.md and in guides/ (guards a vacuous green)
```
Today: README.md:76, `guides/introduction/{first-hour.md:24, getting-started.md:15, installation.md:27}`, `guides/recipes/companion-libs/{lockspire.md:37, accrue.md:30, relyra.md:46, threadline.md:49, mailglass.md:35, rulestead.md:36 and :102}` are all `~> 1.5.0`; `docs/` and `priv/templates/` have none. `[VERIFIED: grep this session]`

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Brand source `brandbook/` (Rail Accent, Space Grotesk) | `brand/` book v2.0 "Kiln" (accent `#C2410C`, Instrument Sans + Red Hat Mono) | 2026-11-13 (PR #379, reference-only) | Instruction files and admin guides still point executors at the retired book (BPOL-06) |
| Hex stray `1.20.0` unretired | Retired (`invalid`) but still `latest_stable_version` | observed 2026-11-13 | `~> 1.7` still locks 1.20.0; docs must use three-segment pins |
| `crosswake_sigra` unknown | Hex package v0.1.3 (2026-07-03 first release), Apache-2.0, links to `github.com/szTheory/crosswake` | observed 2026-11-13 | Name record lists it as an own-ecosystem companion, ownership to be confirmed by the maintainer |

**Deprecated/outdated:** the book's `sigra-exdoc.css` (not used as-is; Phase 263), static/variable TTFs (not shipped), `Rail`/`Ember` vocabulary (docs only; token names stay).

## Owner-Decision Defaults

| # | Decision | Recommended default (use in ADR 005) | Evidence | Confirmed? |
|---|----------|--------------------------------------|----------|------------|
| 1 | `Profile` defaults vs the book's neutrals | **Freeze.** Accent already equals Kiln; neutrals differ (`#f7f4ee` vs Paper `#F7F3EE`, `#171717` vs Soot `#1F1A17`, ...) | `profile.ex:42-68`; `brand.json` color roles | No |
| 2 | Admin typeface | Record: additive `--sg-font-sans`/`--sg-font-mono` tokens only, host-inherited by default; Sigra-owned surfaces self-host the two woff2 (Phase 261) | STACK/SUMMARY | No |
| 3 | SemVer level | **Minor**; `feat`/`fix`/`docs` only, no `!`, no BREAKING footer; "Visual and copy changes" changelog section; no hand notes under CHANGELOG "Unreleased". `release-please-config.json` has `release-type: elixir`, default sections | `release-please-config.json` | No |
| 4 | Changed msgids | Targeted per surface with an old-to-new rename table; tier-1 strings, route paths, helpers and the `sigra` domain untouched | PITFALLS C3 | No |
| 5 | Suspended/unlock/seven-day rule | Out of scope; file a seed | `user_show_live.ex:385` already says "unlock below" with no control | No |
| 6 | Status labels | Adopt Active/Unconfirmed/Locked; keep "Deletion scheduled" (reversible grace period; "Deleting" reads irreversible); Suspended drawn in catalog only | `user_show_live.ex:332,336` | No |
| 7 | PNG-lane policy | **Park** (separate small PR at end of Phase 260): demote `admin_checkpoints` (27 PNGs) and `demo_showcase` (4) from PR-blocking to dispatch; keep real-login/generated-host smoke, axe, golden install, behavior specs; never allowlist the `impersonation-banner` canary; never recapture on darwin | `ci.yml:1330-1342` (admin_checkpoints compares on every PR, 3 projects), design_gallery PR lane is `--grep-invert '@snapshot'` (behavior only) `[VERIFIED: ci.yml:1352-1365]` | No |
| 8 | Vendoring scope and pin | **Pin the whole tracked `brand/` tree** (72 files), manifest at repo root, `.gitattributes -text`; document the consumed subset as a table | Pitfall 1 | No (contradicts "subset" wording) |
| 9 | Generate vs verify | Verify only; no builder, no new Mix task | ROADMAP governing rules | Locked in roadmap |
| 11 | Install-pin shape | Test enforces shape + all-equal now; value bump to latest published minor (`~> 1.7.0`, resolves 1.7.1) in Phase 263 | live resolution probe | No |
| 12 | Instruction-file pointer fix | Minimal pointer edit | REQUIREMENTS BPOL-06 | **Yes, 2026-11-13** |
| 14 | Name/trademark posture; clear-space and logo-use authority | No trademark claim; record `crosswake_sigra`; **clear-space authority: BRAND.md prose "2 T"** (stricter); logo-use statement: unchanged use for reference allowed, no endorsement implied, modification needs maintainer approval, reconciled with MIT | measured below | No |

**Clear-space conflict, measured:** `brand/BRAND.md` says "Keep clear space on every side equal to 2 T, twice the square's side" while `brand/brand.json` has both `logo.clear` ("equal to 2 T") and `logo.clearSpace` ("one quarter of the typemark height on every side"). In `brand/assets/logo/sigra-symbol-light.svg` the stem and square are 150 units wide (`594.6` to `744.6`), and `brand/assets/logo/sigra-lockup-light.svg` has `viewBox="16.0 -720.0 2305.3 935.0"`, so 2 T = 300 units while one quarter of the typemark height = 233.75 units (about 1.56 T). They disagree by about 66 units; the JSON disagrees with itself as well. `[VERIFIED: files read this session]`

## Verified Facts Log (this session)

| Fact | Result |
|------|--------|
| `brand/` tracked | 72 files, 3.4 MB; added by `4cf5829ea` (PR #379), reachable from `origin/main` |
| Manifest prototype | 72 files, 7,436 bytes; `shasum -a 256 -c` 72/72 `OK` |
| Privacy scan of `brand/` | No `/Users`, `/home`, `C:\Users`, `/private/var`, `file://`; emails are only `*.tasklane.test`; no SVG metadata markers; PDF `/Creator` is a headless-browser UA, `/Producer` Skia, no `/Author`; PNG chunks none; JPG EXIF none; the only external URLs are font-project and `index.html:11` og:image |
| Hex `sigra` | `latest_stable_version` 1.20.0; real latest 1.7.1; `retirements`: `1.20.0` `{reason: invalid, message: "Retired: use the supported ~> 1.5.0 requirement instead."}`; package version in repo 1.7.2 (unpublished) |
| Live resolution | `~> 1.7` -> 1.20.0 RETIRED; `~> 1.7.0` -> 1.7.1 |
| Hex `crosswake_sigra` | v0.1.3 stable (releases 0.1.1 on 2026-07-03, 0.1.3 on 2026-08-09), 463 downloads, Apache-2.0, description "Sigra auth companion adapter for the Crosswake route-policy system.", links `github.com/szTheory/crosswake`; ownership not stated by the API beyond that link |
| Other registries | npm `sigra` 404; PyPI `sigra` 404; RubyGems `sigra` 404; crates.io `sigra` "does not exist"; GitHub name search returns 279 repositories (for example a bioinformatics project `SiGra`, a PHP "Sistema integral de resultados de aprendizaje", several empty repos) |
| Existing tests probed | `glossary_test.exs` + `error_test.exs`: 27 tests, 0 failures; example `session_controller_test.exs`: 13 tests, 0 failures |
| Worktree after all probes | clean (`git status --short` empty) |

## Runtime State Inventory

Not applicable: this is not a rename/refactor/migration phase. BPOL-06 edits instruction pointers in text only, and no stored data, service config, OS registration, secret or build artifact embeds the retired `brandbook/` path.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / OTP | all tests | yes | 1.19.5 / OTP 28 (`.tool-versions` pins `erlang 28.5`, `elixir 1.19.5-otp-28`) | none |
| Postgres via Docker (`scripts/db/up.sh`) | every `mix test` (root and example) | yes (daemon up; booted and torn down this session) | postgres container on a dynamic port | CI service container |
| `phx_new` 1.8.8 archive | `golden_diff_test`, `mix ci` install leg | yes (`mix archive` lists `phx_new-1.8.8`) | 1.8.8 | `mix archive.install --force hex phx_new 1.8.8` |
| Hex network access | name-clearance lookups, resolution proof | yes | hex.pm API 200 | none needed offline for tests |
| Node | Playwright subproject | yes (v26.10.0) | node_modules **not installed**, no `tsconfig.json` | `npm ci` in `test/example/priv/playwright` + `npx playwright install chromium`, or rely on PR CI shards |
| `shasum` | independent manifest check | yes | system | `sha256sum` |
| GitHub API (unauthenticated search) | name-clearance log | yes (rate limited) | n/a | web search |

**Missing dependencies with no fallback:** none.
**Missing with fallback:** local Playwright (use CI shards for BCOPY-06 proof; optionally run one spec locally per the example Playwright boot recipe in project memory).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5); Playwright Test 1.59.1 for BCOPY-06 only |
| Config file | `test/test_helper.exs` (root), `test/example/test/test_helper.exs`; no tag exclusions in root, `@moduletag :example_app` for example tests |
| Quick run command | `mix test test/sigra/brand` (root, needs Postgres up) |
| Full suite command | `MIX_ENV=test mix ci` (format, deps checks, `compile --warnings-as-errors`, `test --exclude scaffold`, install golden, dep-off) and `cd test/example && MIX_ENV=test mix test --include example_app` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BPOL-01 | ADR, `contract.md` section and guide exist and contain required headings/terms (frozen list, add-only list, lane table, surface map, decisions, upgrade-note skeleton) | doc-contract ExUnit (optional, headings + key terms only) | `mix test test/sigra/brand/policy_docs_test.exs` | No (Wave 0) |
| BPOL-02 | Manifest drift red on one changed byte; privacy scan clean; planted failure red; `.gitattributes` line present | unit | `mix test test/sigra/brand/source_pin_test.exs` | No (Wave 0) |
| BPOL-02 | `brandbook/` untouched; zero bytes in `lib`/`priv` | shell gate | `git diff --stat aeda7273d..HEAD -- lib priv brandbook` (prints nothing) | n/a |
| BPOL-03 | Frozen-surface superset per category; comparator goes red on a removal | unit | `mix test test/sigra/brand/frozen_surface_test.exs` | No (Wave 0) |
| BPOL-03 | Legacy profiles byte-identical (explicit, partial, defaults) | unit | `mix test test/sigra/brand/legacy_profiles_test.exs` | No (Wave 0) |
| BPOL-04 | Record exists, title contains "search log, not clearance", names `crosswake_sigra`, no "cleared"/TM wording | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | No (Wave 0) |
| BPOL-05 | Decisions present in ADR (each of 7) | doc-contract ExUnit | same | No (Wave 0) |
| BPOL-06 | No remaining instruction to use "Rail Accent ... from `brandbook/`" in `CLAUDE.md`, `AGENTS.md`, two admin guides | doc-contract ExUnit (negative grep) | same | No (Wave 0) |
| BPOL-07 | Upgrade-note skeleton section present | doc-contract ExUnit | same | No (Wave 0) |
| BCOPY-01 | Vocabulary table present with the five required rulings | doc-contract ExUnit | same | No (Wave 0) |
| BCOPY-02 | New violations fail; vanished baseline entries fail; scanner unit-tested with a planted term | unit | `mix test test/sigra/brand/copy_contract_test.exs` | No (Wave 0) |
| BCOPY-03 | Parity per surface; known divergences asserted; positive control yields exactly one `:diff` | example ConnTest/LiveViewTest | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs` | No (Wave 0) |
| BCOPY-04 | Inventory files equal extraction for three lanes | unit | `mix test test/sigra/brand/copy_contract_test.exs` | No (Wave 0) |
| BCOPY-05 | Three segments, all equal, non-vacuous | unit | `mix test test/sigra/brand/install_snippet_test.exs` | No (Wave 0) |
| BCOPY-06 | No `has-text("Log in")` outside comments; specs pass in CI shards | grep + CI | `! grep -rn 'has-text("Log in")' test/example/priv/playwright` then PR `example_playwright_shard` | No (Wave 0) |
| BCOPY-07 | Listed claim sites reworded; each registry `known_divergence` row referenced by the claims register | doc-contract ExUnit + review | `mix test test/sigra/brand/policy_docs_test.exs` | No (Wave 0) |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/brand` (a few seconds once compiled; verified single-file runs take about 0.1 s) plus `mix format --check-formatted` on touched files.
- **Per wave merge:** `mix test test/sigra/brand test/sigra/admin/glossary_test.exs test/sigra/error_test.exs test/sigra/branding_test.exs test/sigra/planning/phase_242_shift_left_contract_test.exs test/sigra/architecture_guides_contract_test.exs` and the example parity file.
- **Phase gate:** `MIX_ENV=test mix ci` green, `cd test/example && MIX_ENV=test mix test --include example_app` green, and the gate greps below.

### Phase-gate shell checks (record outputs in the verification report)
```bash
git diff --stat aeda7273d..HEAD -- lib priv brandbook          # must print nothing
git diff --stat aeda7273d..HEAD -- .github scripts              # nothing, or within the budget stated in the plan
git diff aeda7273d..HEAD -- test/fixtures/brand/frozen-surface.json | grep '^-[^-]'   # nothing (ratchet only grew)
git diff aeda7273d..HEAD --text | grep -n -E '/Users/[^/ ]+|/home/[^/ ]+'              # nothing
git diff aeda7273d..HEAD --text | grep -n -i -w -F -e "$(id -un)"                      # nothing (word match; never write the name down)
printf 'x /Users/someone/y\n' | grep -E '/Users/[^/ ]+'                                 # planted-failure control: must print a match
shasum -a 256 -c brand.sha256 | grep -vc ': OK$'                                       # 0
```
Binary files in the diff (PNG/PDF/TTF) need the metadata checks implemented in `source_pin_test.exs`; `git diff --text` does not expose them.

### Wave 0 Gaps
- [ ] `test/sigra/brand/source_pin_test.exs` — BPOL-02
- [ ] `test/sigra/brand/frozen_surface_test.exs` + `test/fixtures/brand/frozen-surface.json` — BPOL-03
- [ ] `test/sigra/brand/legacy_profiles_test.exs` + `test/fixtures/brand/legacy-profiles.json` — BPOL-03
- [ ] `test/sigra/brand/copy_contract_test.exs` + `copy-baseline.json` + `copy-inventory/*.tsv` + `test/support/brand/copy_scan.ex` — BCOPY-02/04
- [ ] `test/sigra/brand/install_snippet_test.exs` — BCOPY-05
- [ ] `test/sigra/brand/policy_docs_test.exs` — BPOL-01/04/05/06/07, BCOPY-01/07 (keep to headings and key terms; do not over-pin prose)
- [ ] `test/example/test/example_web/enumeration_parity_test.exs` + `test/fixtures/brand/public-surfaces.json` — BCOPY-03
- [ ] `test/example/priv/playwright/helpers/loginSubmit.ts` — BCOPY-06
- [ ] Framework install: none (ExUnit and Playwright already present; local Playwright needs `npm ci`)

## Security Domain

`security_enforcement` is not set in `.planning/config.json`, so it is treated as enabled.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (enumeration, lockout, recovery flows are the subject of BCOPY-03/07) | Uniform responses at pre-auth surfaces; claims limited to what the harness proves `[ASSUMED]` category mapping |
| V3 Session Management | no (no session behavior changes) | n/a |
| V4 Access Control | no | n/a |
| V5 Input Validation | yes (scanners parse untrusted-ish repo text; registry/fixture JSON) | Strict regexes, `Code.string_to_quoted` rather than `Code.eval_*`; never evaluate fixture content |
| V6 Cryptography | yes (SHA-256 integrity pin only) | `:crypto.hash(:sha256, ...)`; no custom primitives |
| V8 Data Protection | yes (public repo: no PII in assets, docs, fixtures, commit messages) | Privacy scan + gate greps with planted-failure control |
| V10 Malicious Code / integrity | yes (vendored binary assets, fonts) | Hash pin; metadata scan; `.gitattributes -text` |
| V14 Configuration | partly (`.gitattributes`, no workflow changes) | Process budget |

### Known Threat Patterns for this phase
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Account enumeration through response, redirect, flash, JSON shape (passkey options), lockout/rate-limit state or timing | Information Disclosure | Parity registry with asserted known divergences; fix tracked as todos, not hidden; claims register states what is not proven |
| Silent tampering of vendored brand assets | Tampering | `brand.sha256` + single drift test; planted-byte control |
| Personal name / home path / authoring origin in a public repo | Information Disclosure | Scan + phase-gate grep with planted-failure control; never write the pattern values into the repo |
| Brand copy that leaks account state (specific voice on pre-auth screens) | Information Disclosure | Public-surface registry marks pre-auth strings "voice-exempt: enumeration-safe"; tier-1 exact-match list |
| Over-claiming security properties in docs | Repudiation / trust | BCOPY-07 claims pass; cite the timing todo |
| Agent follows retired instructions (instruction-file drift) | Tampering (of process) | BPOL-06 pointer fix with a negative-grep test |

## Open Questions

1. **Prune `brand/` or pin all 72 files? (owner decision #8)**
   - Known: REQUIREMENTS BPOL-02 and the SUMMARY say "consumed subset"; PR #379 already landed the full tree; `brand/index.html` and `brand/brand.json` reference files a prune would remove; BPUB-04 later retargets an axe script at `brand/index.html`.
   - Unclear: whether the owner wants the repo-weight saving (about 2.2 MB of 3.4 MB would go) at the cost of dangling links.
   - Recommendation: pin all; document the consumed subset as a table. If pruning is chosen, do it first, in its own commit, with exactly: both PDFs, `preview/*.jpg`, `assets/fonts/static/*.ttf`.
2. **What does "existing-vs-unknown identity" mean for MFA, passkey and invitation?**
   - Known: MFA/passkey screens come after identification; invitation is a capability URL.
   - Recommendation: MFA = wrong TOTP vs wrong backup code (same message) and pending vs absent pending-session; passkey = unknown email vs existing email without passkeys vs existing with passkeys, plus the conditional (email-less) flow; invitation = anonymous visitor with a valid token for an email that has an account vs one that does not.
3. **Accept the `og:image` GitHub Pages URL in `brand/index.html:11`?**
   - Recommendation: accept and allowlist it in the privacy scan as a public project URL; editing needs a re-lock and breaks "byte-exact".
4. **Where do lib moduledoc over-claims go?** (`lib/sigra/lockout.ex:13` "Messages are enumeration-safe", `lib/sigra/error.ex:7,138-141`, `lib/sigra/auth.ex:16,132,613,1097`.)
   - Recommendation: file one todo per cluster (they need `lib/` edits, forbidden in this phase) and cite them from the claims register.
5. **Is `crosswake_sigra` a first-party companion?**
   - Known: the Hex metadata links to `github.com/szTheory/crosswake`, the same GitHub owner as this repository's `source_url`.
   - Unclear: Hex ownership is not exposed by the API response used.
   - Recommendation: record as "appears to be the maintainer's own companion; maintainer to confirm", never as a third-party conflict or as clearance.
6. **Instruction-file edit scope.** Approved scope is "pointers to the new `brand/` book". Recommended minimal set: `CLAUDE.md:230`, `AGENTS.md:8`, `guides/reference/admin-ui-principles.md:3,30,37`, `guides/reference/admin-design-contract.md:9,11,12`. Do not claim admin token values already align with `brand/tokens.json` (Phase 261 migrates values); say names stay and values move in the BTOK phase. Leave `admin-token-reference.md`, `admin-graphic-design-lens.md`, `admin-fractal-scorecard.md` (Phase 261 BTOK-07) and `scripts/panel/lenses.mjs` ("slated for cut") alone.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Pin the whole tracked `brand/` tree instead of pruning to a subset | Owner-Decision Defaults #8, Open Q1 | If the owner wants a prune, the manifest and a prior commit change; low cost |
| A2 | ADR files go to `.planning/decisions/005-*.md` and `006-*.md` (next free numbers; 003 has a TSV sibling) | Project Structure | Renumbering only |
| A3 | `brand-compatibility.md` is not added to `mix.exs` extras in this phase, and `contract.md` references it by backticked path | Pitfalls 6-7 | If wanted as an extra now, `doc/llms.txt` must be regenerated and committed and Phase 263's ExDoc wiring reconsidered |
| A4 | The `loginSubmit` selector `#login_form button:not([type="button"])` resolves to exactly one element on both the example and generated login pages | Pattern 6 | Playwright shards fail in CI; adjust selector (no product change) |
| A5 | Interpretation of "identity parity" for MFA/passkey/invitation (Open Q2) | Pattern 5 | Test scope differs from owner intent |
| A6 | Asserted `known_divergence` rows satisfy "tests pass for every pre-auth surface" while honoring "no claims beyond what is proven" | Summary, Pattern 5 | If the owner wants a green parity claim, a `priv/templates` fix and golden rebless must be scheduled in a later phase |
| A7 | Clear-space authority = BRAND.md prose (2 T); logo-use statement wording | Owner-Decision Defaults #14 | Owner may choose the JSON quarter-height rule or different wording |
| A8 | Copy-inventory extraction method (AST literals + collapsed-tag HEEx text) is adequate and stable | Pattern 4 | Noisy or churny inventories; adjust extractor |
| A9 | ASVS category mapping in Security Domain | Security Domain | Documentation only |
| A10 | ExDoc does not warn on a backticked file path (it is not a link) and would be uncertain on a link to a non-extra | Pitfall 7 | CI docs lane could fail if a link is used |

## Sources

### Primary (HIGH confidence)
- Repository files read or run this session: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/research/v1.51-brand/{SUMMARY,STACK,ARCHITECTURE,PITFALLS,FEATURES}.md`, `CLAUDE.md`, `AGENTS.md`, `mix.exs`, `.formatter.exs`, `.github/workflows/ci.yml`, `lib/sigra/branding.ex`, `lib/sigra/branding/profile.ex`, `lib/sigra/config.ex`, `lib/sigra/error.ex`, `lib/sigra/lockout.ex`, `lib/sigra/auth.ex`, `lib/sigra/install/features/{admin,core}.ex`, `priv/templates/sigra.install/core/{session_controller,registration_live,sigra_auth_components,reset_password_controller}.ex`, `test/sigra/admin/glossary_test.exs`, `test/sigra/planning/phase_242_shift_left_contract_test.exs`, `test/fixtures/install_golden/tree/lib/*_web/router.ex`, `test/example/lib/example_web/**`, `test/example/priv/playwright/**`, `brand/BRAND.md`, `brand/brand.json`, `brand/assets/**`, `guides/**`, `.planning/decisions/00{3,4}-*.md`, pending todos cited inline.
- Hex API (`hex.pm/api/packages/sigra`, `.../crosswake_sigra`, search) and a scratch-project `mix deps.get` for both requirements, 2026-11-13.
- npm, PyPI, RubyGems, crates.io, GitHub search API lookups, 2026-11-13.

### Secondary (MEDIUM confidence)
- `.planning/research/v1.51-brand/*` conclusions not re-derived here (Hex size limits, ExDoc theming, contrast), relied on only where Phase 259 scope touches them.

### Tertiary (LOW confidence)
- None used for decisions. ASVS category names and ExDoc non-extra link behavior are `[ASSUMED]`.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, nothing new; versions read from repo files.
- Architecture: HIGH for extraction sources and file placement; MEDIUM for the copy-inventory extractor and the Playwright selector (designed, not executed end to end).
- Pitfalls: HIGH, each tied to a file read or command run this session.

**Research date:** 2026-11-13
**Valid until:** 2026-12-13 for repo facts (branch moves daily; re-check `brand/` file count and `ci.yml` PNG lanes at plan time), 7 days for Hex/registry facts.
