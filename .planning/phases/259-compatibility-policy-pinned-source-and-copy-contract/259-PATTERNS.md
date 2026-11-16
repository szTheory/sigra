# Phase 259: Compatibility Policy, Pinned Source and Copy Contract - Pattern Map

**Mapped:** 2026-11-13
**Files analyzed:** 44 (24 new, 20 modified; each file counted once, including 7 prose-edit docs and 6 Playwright files)
**Analogs found:** 35 / 44 (`brand.sha256` and `.gitattributes` have none; the 7 honest-claims prose edits have only located claim sites, no code analog; see "No Analog Found")
**Source of truth for scope:** `259-RESEARCH.md` (no CONTEXT.md; ROADMAP Phase 259 SC-1..5 and REQUIREMENTS BPOL-*/BCOPY-* act as locked decisions)
**Hard rule for every plan:** `git diff --stat -- lib priv brandbook` stays empty for the whole phase. Every analog below is READ-ONLY input; nothing under `lib/` or `priv/` is edited. Pre-existing leaks become asserted `known_divergence` rows plus todos, never code fixes.

All analog paths were verified git-TRACKED (`git ls-files`); none is a gitignored mirror.

## Phase-wide discovery and gate quirks the planner must honor

These are repo mechanics verified this session. They decide where new files go and what they must not trip.

| Mechanic | Evidence | Consequence for plans |
|----------|----------|-----------------------|
| Root test loading is `test_load_filters: [~r"^test/(?!example/\|fixtures/)"]`; `test_ignore_filters` skips `test/example/` and `test/fixtures/` | `mix.exs:17-35` | `test/sigra/brand/*_test.exs` load; JSON/TSV under `test/fixtures/brand/` are inert data (never compiled, never format-checked). The parity test under `test/example/` is NOT run by root `mix test` (run `cd test/example && MIX_ENV=test mix test --include example_app`). |
| `elixirc_paths(:test)` is `["lib", "test/support"]` | `mix.exs:55` | `test/support/brand/copy_scan.ex` (note `.ex`) compiles under `compile --warnings-as-errors` in `mix ci`: no unused functions, no unused aliases. `.exs` files in `test/support/` are NOT compiled. |
| `.formatter.exs` inputs include `test/{sigra,support,mix}/**/*.{ex,exs}` and `test/example/{lib,config,test,priv}/**/*.{ex,exs}` | `.formatter.exs` | Every new `.ex/.exs` must pass `mix format --check-formatted` (first leg of `mix ci`). |
| `mix ci` = format, deps checks, `compile --warnings-as-errors`, `test --exclude scaffold`, `ci.install_golden`, `sigra.dep_off` | `mix.exs:149-157` | New root tests run automatically. Do NOT tag any new module `@moduletag :scaffold`: `phase_233_library_economics_contract_test.exs:262-266` live-scans `test/**/*_test.exs` for that tag and compares to a fixed set. |
| `Sigra.CI.LibraryTestPartitions` validates the test-file universe against evidence JSON, but nothing calls it except a text read of its `@scaffold_paths` | grep: only `test/support/ci/library_test_partitions.exs` and `phase_233_...contract_test.exs:254` reference it; `ci.yml` has no partition use | New test files need NO registration. (ADR 004 records the single-owner `mix ci` topology.) |
| Playwright ownership inventory contract globs `tests/*.spec.ts` only | `phase_234_playwright_inventory_contract_test.exs:392-396` | `helpers/loginSubmit.ts` is not a spec, so `spec-ownership.json` is untouched. Editing existing specs does not change the inventory. |
| `phase_242_shift_left_contract_test.exs` pins `{:sigra, "~> 1.5.0"}` in 10 files | `phase_242...:4-26` | The new install-snippet test must assert SHAPE and equality, not value; do not bump pins in this phase (BPUB-05 owns it). |
| `mix.exs` still names `favicon: "brandbook/favicon.svg"` and `architecture_guides_contract_test.exs:6,218` asserts it | `mix.exs:210` | Another reason `brandbook/` stays byte-untouched. Do not "fix" this pointer in 259 (Phase 263). |
| `doc/llms.txt` is tracked and CI-compared; ExDoc `extras` list lives in `mix.exs:215-` | `scripts/ci/check-docs-index.sh`, `mix.exs` | Do NOT add `brand-compatibility.md` to `extras`; do NOT change any extra's H1. Editing section bodies of `contract.md` / admin guides is safe. Reference the new guide from `contract.md` by backticked path, not a link (repo convention; only 3 of 18 `guides/reference/` files are extras). |
| Root tests resolve repo files two ways: cwd-relative (`File.read!("priv/templates/...")`) or `Path.expand("../../..", __DIR__)` from `test/sigra/<dir>/` | `generated_impersonation_parity_test.exs:6-9`, `phase_242...:17` | Use the `__DIR__` form in the new tests so they work from any cwd. From `test/sigra/brand/`, repo root is `Path.expand("../../..", __DIR__)` and fixtures are `Path.expand("../../fixtures/brand", __DIR__)` (same shape as `golden_diff_test.exs:42`). |
| Root `mix test` needs live Postgres even for pure-file tests | `test/test_helper.exs` starts `Sigra.Test.PostgresRepo` | Per-task command: `scripts/db/up.sh; source tmp/db.env; mix test test/sigra/brand`. |

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.planning/decisions/005-brand-adoption-compatibility-policy.md` | ADR (doc) | static record | `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md` (+ `003-...` amendment style) | exact |
| `.planning/decisions/006-name-clearance-search-log-and-claims-register.md` | ADR/record (doc) | static record | `.planning/decisions/004-...` (table + revisit-triggers shape) | role-match |
| `guides/reference/brand-compatibility.md` | reference guide (doc) | static reference | `guides/reference/admin-design-contract.md` (+ `guides/introduction/upgrading-to-v1.46.md` for upgrade-note skeleton) | role-match |
| `guides/introduction/contract.md` (modify: add section) | public contract guide | static reference | itself, `## Ownership Boundaries` table (lines 27-33) | exact |
| `guides/reference/admin-glossary.md` (modify: add reconciliation section) | glossary table | static reference | itself, `## Canonical Terms` table (lines 9-39) | exact |
| `CLAUDE.md:230`, `AGENTS.md:8`, `guides/reference/admin-ui-principles.md:3,30,37`, `guides/reference/admin-design-contract.md:9,11,12`, `test/example/AGENTS.md:7` (modify: pointers) | instruction/config docs | static pointer | the lines themselves | exact |
| `README.md:177`, `guides/flows/{registration,password-reset,login-and-logout}.md`, `guides/introduction/{getting-started,architecture,code-walkthrough}.md` (modify: honest-claims pass) | docs prose | static claim | none (prose rewording); claim sites located below | partial |
| `.planning/todos/pending/2026-11-13-*.md` (new, ~3: passkey options oracle, lockout/rate-limit channel, lib moduledoc over-claims) | todo | static record | `.planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md` | exact |
| `brand.sha256` | manifest | file-I/O (hash) | none in repo (stock `shasum -c` line format) | none |
| `.gitattributes` | config | n/a | none (file absent today) | none |
| `test/sigra/brand/source_pin_test.exs` | test | file-I/O + transform | `test/sigra/install/design_gallery_isolation_test.exs` (pure-filesystem, non-vacuous) + `golden_diff_test.exs` (committed-vs-actual, diff message) | exact |
| `test/sigra/brand/frozen_surface_test.exs` | test | transform (extract + subset compare) | `test/sigra/install/auth_ui_contract_test.exs` + `test/sigra/templates/generator_emission_audit_test.exs` + `test/sigra/install/features/admin_test.exs` | role-match |
| `test/sigra/brand/legacy_profiles_test.exs` | test | transform (pure functions) | `test/sigra/branding_test.exs` | exact |
| `test/sigra/brand/copy_contract_test.exs` | test | transform (scan + baseline) | `test/sigra/admin/glossary_test.exs` | exact |
| `test/support/brand/copy_scan.ex` | test-support utility | transform | `test/support/planning_paths.ex` (module shape) + `glossary_test.exs` private helpers (logic to adapt, not move) | role-match |
| `test/sigra/brand/install_snippet_test.exs` | test | file-I/O (regex scan) | `test/sigra/planning/phase_242_shift_left_contract_test.exs` + `design_gallery_isolation_test.exs` precondition | exact |
| `test/sigra/brand/policy_docs_test.exs` | test | file-I/O (headings/terms) | `test/sigra/architecture_guides_contract_test.exs` (+ `phase_249_release_docs_contract_test.exs` helpers) | exact |
| `test/fixtures/brand/frozen-surface.json`, `legacy-profiles.json`, `copy-baseline.json`, `public-surfaces.json` | fixture (committed expected) | static data | `test/example/priv/playwright/spec-ownership.json` (schema_version registry read via `JSON.decode!`) | role-match |
| `test/fixtures/brand/copy-inventory/{library,generated,host}.tsv` | fixture (committed expected) | static data | `.planning/decisions/003-tag-delete-list.tsv` (TSV with header comments) | role-match |
| `test/example/test/example_web/enumeration_parity_test.exs` | test | request-response (ConnTest + LiveViewTest) | `test/example/test/example_web/controllers/session_controller_test.exs` + `live/registration_live_test.exs` + `controllers/passkey_session_controller_test.exs` | role-match |
| `test/example/priv/playwright/helpers/loginSubmit.ts` | test helper (TS) | request-response (locator factory) | `test/example/priv/playwright/helpers/adminUsersIndex.ts` (+ `helpers/fixtures.ts` test-only header) | exact |
| `test/example/priv/playwright/{tests/organizations,ga-uat-shift-left,demo-showcase,golden-path,passkey-options}.spec.ts`, `helpers/adminFlows.ts` (modify: 11 call sites) | test | request-response | the existing call sites | exact |

---

## Pattern Assignments

### A. Policy and decision documents

#### `.planning/decisions/005-brand-adoption-compatibility-policy.md` (ADR, static)

**Analog:** `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md`; amendment discipline from `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`.

**Header + section skeleton to copy** (004 lines 1-6, then `## The problem`, `## Decision`, `## Replacement guarantee`, a table, `## Consequences`, `## Revisit triggers`):
```markdown
# ADR 004: TEST-01/TEST-02 are superseded by the single-owner `mix ci` topology

**Status:** Accepted
**Date:** 2026-09-19
**Context:** Phase 241 (v1.48 CLEAN-BASELINE) — retiring a formatter and formatter test ...
```
Adapt: `# ADR 005: <title>`, `**Status:** Accepted`, `**Date:** 2026-11-13`, `**Context:** Phase 259 (v1.51 brand identity adoption) ...`. Numbering: next free is 005 (`003` also has a `003-tag-delete-list.tsv` sibling; ADRs 001-004 exist).

**Amendment style** (003, "Amendment — 2026-09-16"): amend in place, dated, status stays `Accepted`; retract false statements explicitly rather than silently rewriting. Copy the closing line of 004: "Amendments follow the dated, in-place retraction style established by ADR 003".

**Required content (from SC-1, BPOL-01/05):** frozen list, add-only list, ownership-lane table (library-owned / generated / host-owned), surface map naming the brand owner per surface, and the seven recorded decisions: `Profile` defaults frozen; additive font tokens only (`--sg-font-sans` / `--sg-font-mono`); minor SemVer with no `!` / no BREAKING footer / nothing hand-added under CHANGELOG "Unreleased"; targeted msgid renames with an old-to-new rename table; Suspended/unlock/seven-day rule out of scope (file a seed); "Deletion scheduled" kept; PNG-lane policy (park `admin_checkpoints` 27 PNGs and `demo_showcase` 4 PNGs from PR-blocking to dispatch, at end of Phase 260; never allowlist the `impersonation-banner` canary; never recapture on darwin). Use the "Owner-Decision Defaults" table in RESEARCH as the content source; mark decisions not yet confirmed as "recommended default, owner to confirm" (only #12 is confirmed, 2026-11-13).

**Do not** write personal names, emails or home paths. Provenance string: "brand book v2.0 (2026-11-13)".

---

#### `.planning/decisions/006-name-clearance-search-log-and-claims-register.md` (record, static)

**Analog:** same ADR 004 shape; table style from 004 "Affected refs" (`| Ref | Affected paths |`).

**Required content (BPOL-04, SC-5):** H1 contains the exact phrase `search log, not clearance`; names `crosswake_sigra` (Hex v0.1.3, first release 2026-07-03, Apache-2.0, links `github.com/szTheory/crosswake`, same GitHub owner as this repo's `source_url`; record as "appears to be the maintainer's own companion; maintainer to confirm", never as clearance or third-party conflict); a lookup table of registries searched (Hex, npm, PyPI, RubyGems, crates.io, GitHub) with date 2026-11-13; a claims register (each public claim -> evidence -> status; every `known_divergence` parity row must be referenced); decisions on logo-use statement and clear-space authority; explicit "no trademark claim, no TM/R symbol". Clear-space decision content: `brand/BRAND.md` prose "2 T" (300 units in `brand/assets/logo/sigra-symbol-light.svg`) vs `brand/brand.json` `logo.clearSpace` "one quarter of the typemark height" (233.75 units) - conflict measured in RESEARCH; recommended authority = BRAND.md prose.

`policy_docs_test.exs` asserts: title contains "search log, not clearance", body contains `crosswake_sigra`, and body does NOT contain "cleared" or a trademark claim.

---

#### `guides/reference/brand-compatibility.md` (public reference doc; NOT an ExDoc extra)

**Analogs:** `guides/reference/admin-design-contract.md` (H1 + addendum + tables + per-item sections; lines 1-20 headings), `guides/introduction/upgrading-to-v1.46.md` (upgrade-note skeleton), `guides/introduction/contract.md` tables.

**Table style to copy** (`contract.md` lines 27-33):
```markdown
## Ownership Boundaries

| Boundary | Owned surface |
|----------|---------------|
| Library-owned | Versioned Hex package code: crypto helpers, token verification ... |
| Generated-host-owned | Schemas, migrations, contexts, routes, LiveViews, templates ... |
| Shared seams | Mail delivery, Oban/background work, OAuth providers ... |
```
Adapt to a three-lane table (library-owned admin LiveViews/components update on `mix deps.update`; generated templates are new installs only; host-owned CSS and logos are copied once, never refreshed) with a "brand owner" column for the surface map.

**Upgrade-note skeleton to copy** (`upgrading-to-v1.46.md` lines 1-9):
```markdown
# Upgrading generated hosts for v1.46 adopter experience

Sigra's generated files belong to the host application. This upgrade is therefore additive and opt-in: update the library normally, then choose which generated UI and first-admin changes to adopt. Do not use `--force` over customized files.

## 1. Upgrade the dependency first

In a dedicated branch with a database backup:

    mix deps.update sigra
    mix compile --warnings-as-errors
    mix test
```
BPOL-07 skeleton = numbered `## N.` steps, indented 4-space command blocks, "compare rather than overwrite" for customized hosts (lines 47-58 of the same file), and a "Visual and copy changes" section. Do not create a separate `upgrading-to-v1.NN.md` (that file would be an ExDoc extra candidate and move `doc/llms.txt`): the skeleton is a section INSIDE this guide.

**Frozen / add-only lists** must come from the measured inventories (see `frozen_surface_test.exs` below): 100 distinct `--sg-*` and 35 `--sigra-auth-*` custom properties, 112 `sg-*` selectors, 66 `sigra-auth*` selectors, 25 `Profile` keys, 33 top-level config keys / 170 option paths, ~50 route lines, 54 verified-route helpers, one Gettext domain `"sigra"`, 25 `data-testid`s, installer targets `priv/static/images/sigra-logo-primary{,-dark}.svg`, `priv/static/assets/sigra_admin.css`, `priv/static/assets/sigra_auth.css`.

**Consumed-subset table (owner decision #8):** document which `brand/` files tests/surfaces read and which are reference-only; the manifest pins the whole tracked tree (72 files).

---

#### `guides/introduction/contract.md` (modify: add `## Brand and visual compatibility`)

**Analog:** the file itself. Existing H2 order: Version Axes, Supported Stack, Ownership Boundaries, SemVer And Deprecation Policy, Security Invariants, Non-Goals (headings at lines 5, 14, 27, 35, 43, 57). Insert the new H2 after `## SemVer And Deprecation Policy` (line 35) so the SemVer treatment sits adjacent. Keep the H1 (`# Sigra 1.0 Contract`, line 1) unchanged (changing an extra's H1 changes `doc/llms.txt`).

**Reference style:** the file links `SECURITY.md` with a relative markdown link (line 45: `[`SECURITY.md`](../../SECURITY.md)`), but for the non-extra reference guide use a backticked path only: "see `guides/reference/brand-compatibility.md`". `architecture_guides_contract_test.exs:8-12` forbids `lib/`, `priv/templates/`, `test/example/` path strings in the architecture/walkthrough guides only (not `contract.md`), but still avoid internal paths in published prose where possible.

---

#### `guides/reference/admin-glossary.md` (modify: add "Brand book v2.0 reconciliation" section, BCOPY-01)

**Analog:** the file itself. Keep the H1 (`# Admin Glossary`, line 1). Existing structure: `## Canonical Terms` table (lines 9-39, columns `Canonical | Banned synonyms | Context rule | Enforcement`), `## Voice Rubric` (line 41), `## Exemplars` (line 106). Add the reconciliation as a new H2 after `## Canonical Terms`' boundary rules and before `## Voice Rubric`, reusing the same four-column table (`Enforcement` = `glossary_test.exs` | `copy_contract_test.exs` | `editorial`).

**Row shape to copy** (line 15):
```markdown
| **sign in** (verb, two words) | log in, login (as verb), signin, sign off | All surfaces: the auth action as a verb. Two words, no hyphen: "the user can sign in". | glossary_test.exs |
```
Rulings the table must contain (BCOPY-01, RESEARCH): the book terms from `brand/brand.json` `voice.terms` x this glossary, with product-truth anchors (file:line), including: sign in/out vs the demo host's "Log in" (host-owned), "Locked" (system) vs "Suspended" (out of scope), "Deletion scheduled" kept (reversible grace period), "revoke" vs "delete", status labels Active/Unconfirmed/Locked.

---

#### Instruction-file pointer edits (BPOL-06, owner approval GRANTED 2026-11-13: "pointers to the new `brand/` book")

Exact lines (verified):

| File | Line(s) | Current text to replace |
|------|---------|-------------------------|
| `CLAUDE.md` | 230 | `... use the Rail Accent brand assets from `brandbook/`, support Light/Dark/System theme behavior ...` |
| `AGENTS.md` | 8 | `- Use the Rail Accent brand assets from `brandbook/`.` |
| `guides/reference/admin-ui-principles.md` | 3, 30, 37 | line 3 "brand source of truth in `brandbook/`"; line 30 "Use brand tokens from `brandbook/tokens.*` as the value reference. Preserve existing `--sg-*` names unless a migration is deliberately planned."; line 37 "Use the Rail Accent mark/lockup from `brandbook/` for Sigra identity." |
| `guides/reference/admin-design-contract.md` | 9, 11, 12 | line 9 "ratified Rail Accent system from `brandbook/`"; line 11 "Token values should stay aligned with `brandbook/tokens.*`"; line 12 "Use Rail Accent mark/lockup assets" |
| `test/example/AGENTS.md` | 7 | "Keep the `sg-*` cascade-layer/BEM design system, Rail Accent brand assets, Light/Dark/System theme support ..." (NOT in RESEARCH's minimal set; it carries the same retired pointer. Flag to the planner: include only if the approval scope "pointers to the new `brand/` book" is read to cover it, else file a todo.) |

**Wording constraints (RESEARCH Open Q6):** point to `brand/` (and `brand/BRAND.md`, `brand/tokens.json`), keep "Preserve the `sg-*` cascade-layer/BEM design system", Light/Dark/System, deterministic tests. Do NOT claim admin token values already align with `brand/tokens.json` (Phase 261 migrates values; names stay, values move in the BTOK phase). Leave alone: `guides/reference/admin-token-reference.md`, `admin-graphic-design-lens.md`, `admin-fractal-scorecard.md` (Phase 261 BTOK-07) and `scripts/panel/lenses.mjs`.

**Test for it** (in `policy_docs_test.exs`): negative grep that none of the edited files still instructs "Rail Accent ... from `brandbook/`". No test file pins these lines (verified: `components_test.exs` only quotes `admin-design-contract.md` inside assertion messages).

---

#### Honest-claims pass (BCOPY-07), docs only

No analog (prose). Claim sites located (verified by grep):

| File:line | Current claim | Action |
|-----------|---------------|--------|
| `README.md:177` | "**Enumeration** | Safer defaults on account discovery flows (details in HexDocs per flow)." | already hedged; keep or tighten to "what is tested" |
| `guides/flows/registration.md:3` | "Sigra ships a complete, enumeration-safe registration flow" | reword: success auto-signs in while duplicate shows only a flash (inherent divergence); cite the timing-oracle todo |
| `guides/flows/registration.md:11,45,47-55` | "enumeration-safe `{:error, :email_taken}`", "enumeration prevention ... handled for you" | same; note line 55 already concedes the tradeoff |
| `guides/flows/password-reset.md:11,28,37,114-121` | "Enumeration-safe: returns `:ok`...", rate-limit "enumeration-safe" | restrict to the proven response parity; library rate-limits only existing users (`lib/sigra/auth.ex:1125-1131`) and controller masks it |
| `guides/flows/login-and-logout.md:10` | "enumeration-safe lookup; returns `nil` for both..." | bound to the lookup return value, not lockout behavior (`Lockout.check(nil)` returns `:ok`, `lib/sigra/lockout.ex:57`) |
| `guides/introduction/getting-started.md:172` | "By design, the form shows the same success message whether or not the email exists ... this prevents enumeration attacks." | restrict to "same message"; do not say "prevents" |
| `guides/introduction/architecture.md:215,334`, `code-walkthrough.md:158` | "public failures remain enumeration-safe", "enumeration-safe public failure" | check against registry rows; hedge divergences |

**Lib moduledoc over-claims cannot be edited in this phase** (zero `lib/` bytes): `lib/sigra/lockout.ex:13`, `lib/sigra/error.ex:7,138-141`, `lib/sigra/auth.ex:16,132,613,1097`. File one todo per cluster; cite them from the claims register (`006`).

---

#### New todos (`.planning/todos/pending/2026-11-13-*.md`)

**Analog:** `.planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md` (frontmatter shape, lines 1-12):
```markdown
---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Duplicate-email registration returns faster than a new email (timing oracle)
area: security
severity: major
source: v1.50 branch triage (product-code review of the enumeration-safe register fix)
files:
  - lib/auth.ex
  - priv/templates/sigra.install
---
```
Copy that frontmatter; add `resolves_phase:` only if the owner assigns one (precedent: `2026-07-28-w2-example-sigra-auth-css-stale-no-parity-gate.md` has `resolves_phase: 260`). Todos to file: (1) passkey email-keyed options existence oracle (same cluster as SEED-011), (2) lockout/rate-limit repeat-attempt channel, (3) lib moduledoc enumeration over-claims, (4) optionally test/example/AGENTS.md pointer if excluded from BPOL-06.

---

### B. Source pin (BPOL-02)

#### `brand.sha256` (manifest) and `.gitattributes`

**No in-repo analog** (no checksum manifest, no `.gitattributes` file exists; verified). Use the stock `shasum -a 256 -c` line format `<64 hex>  <path>\n`, sorted by Elixir binary order, paths relative to repo root (`brand/...`), `.DS_Store` excluded. Prototype verified 72 files / 7,436 bytes, `shasum -a 256 -c brand.sha256` 72/72 OK.

`.gitattributes` content (RESEARCH Pattern 1): `brand/** -text linguist-vendored`. Generating `brand.sha256` is a one-time plan step; per the "no new script" budget, print the regeneration one-liner in the drift-test failure message instead of adding anything under `scripts/`.

---

#### `test/sigra/brand/source_pin_test.exs` (test, file-I/O)

**Analog A:** `test/sigra/install/design_gallery_isolation_test.exs` (pure filesystem, non-vacuous guard). Lines 14-33:
```elixir
  use ExUnit.Case, async: true

  @installer_template_root "priv/templates/sigra.install"

  test "no design gallery artifact exists in installer template tree (D-04)" do
    # Precondition: guard against a false green if the template root is renamed,
    # missing, or the suite runs from the wrong CWD — Path.wildcard would return
    # [] and the assertion below would pass vacuously, silently disabling D-04.
    assert File.dir?(@installer_template_root),
           "installer template root #{@installer_template_root} not found — " <>
             "run from the repo root; D-04 guard cannot verify isolation"

    offenders =
      Path.wildcard("#{@installer_template_root}/**/*")
      |> Enum.filter(&String.contains?(&1, "design"))

    assert offenders == [],
           "Design gallery artifacts found in installer template tree (D-04 violation):\n" <>
             Enum.join(offenders, "\n")
  end
```
Copy: the `assert File.dir?(...)` non-vacuity precondition (assert the manifest is non-empty and `brand/` has >= 1 file before diffing), and the `assert offenders == [], "...:\n" <> Enum.join(...)` shape for the added/removed/changed path report.

**Analog B:** `test/sigra/install/golden_diff_test.exs` lines 42-44 (fixture path via `__DIR__`) and 149-169 (committed-vs-actual with a named "missing / extra" report and a regeneration instruction in the failure text):
```elixir
  @fixture_dir Path.expand("../../fixtures/install_golden", __DIR__)
...
    missing = expected_paths -- actual_paths
    extra = actual_paths -- expected_paths

    if missing != [] or extra != [] do
      flunk("""
      File set differs from golden fixture.
        Missing from generated output (in fixture but not generated):
          #{Enum.join(missing, "\n      ")}
        Extra in generated output (generated but not in fixture):
          #{Enum.join(extra, "\n      ")}
      ...
```
Copy: set-difference reporting (`added`, `removed`, `changed`) plus the one-liner to regenerate.

**Core stdlib (RESEARCH Pattern 1, prototype run; stdlib only):**
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
Compute paths relative to `Path.expand("../../..", __DIR__)` rather than relying on cwd. Normalize `\r\n` to `\n` when reading the committed manifest.

**Tests required in this one module:** (1) manifest drift (regenerated == committed; red with path report); (2) positive control: mutate one in-memory file and assert the pure diff function reports exactly that path; (3) `.gitattributes` contains the `brand/** -text` line; (4) version constants asserted against `brand/brand.json` (`"version": "2.0"`, `"date": "November 13, 2026"`); (5) privacy scan over every file under `brand/` (home-directory path shapes (macOS, Linux and Windows user-profile prefixes, built from fragments in the test so the test source itself does not match); emails not ending `.test`; SVG `<metadata>` / `dc:creator` / `inkscape:` / `sodipodi`; PDF `/Author` `/Creator` `/Producer`; PNG `tEXt`/`iTXt`/`zTXt`/`eXIf`); the scanner has no URL rule, so no og:image allowlist exists (RESEARCH Open Q3, revised); the `file://` shape is flagged only as `file:///` followed by a path (one benign bare `file://` comment exists at `brand/sigra-brand-book.html:687`). (6) planted-failure control for the scan (feed an in-memory string containing a home-path shape, assert it is flagged).

**Never embed a personal name in the test.** Personal-name and home-path checks of the pushed diff are phase-gate shell greps whose patterns derive from `$HOME` / `id -un` at run time (see Phase-gate checks in RESEARCH); the ExUnit scan only uses generic path shapes.

---

### C. Frozen-surface ratchet and legacy byte-identity (BPOL-03)

#### `test/sigra/brand/frozen_surface_test.exs` (test, transform: extract current set, assert `baseline ⊆ current`)

**Analog A (class/token presence):** `test/sigra/install/auth_ui_contract_test.exs` lines 1-5 (path constants) and 24-52 (loop over names, assert present with a message naming the missing item):
```elixir
  @auth_css "priv/templates/sigra.install/core/sigra_auth.css"
...
    for class <- ~w(
      sigra-auth-flow
      sigra-auth-stack
      ...
    ) do
      assert css =~ ".#{class}", "missing semantic auth class #{class}"
    end
```
Copy the shape; the new test replaces the hard-coded list with a committed JSON baseline and a superset assertion: `missing = baseline -- current; assert missing == [], "frozen surface removed: ..."`.

**Analog B (installer targets via public `files/1`):** `test/sigra/install/features/admin_test.exs` lines 18-45:
```elixir
    test "owns the generated admin policy and shell boundary files" do
      files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")
      ...
      assert {:eex, "admin/sigra-logo-primary.svg", "priv/static/images/sigra-logo-primary.svg"} in files

      assert {:eex, "admin/sigra-logo-primary-dark.svg",
              "priv/static/images/sigra-logo-primary-dark.svg"} in files
```
and `generator_emission_audit_test.exs` lines 50-69 + 70-90 (canonical binding and unioning the four features):
```elixir
  defp canonical_binding do
    [
      otp_app: :example,
      app_module: "Example",
      web_module: "ExampleWeb",
      ...
      opts: [live: true, api: false, jwt: false, binary_id: true]
    ]
  end
  ...
    for binding <- [base, expanded, no_live],
        mod <- [Core, Admin, Organizations, Passkeys],
        {:eex, tmpl, _} <- mod.files(binding),
        into: MapSet.new(),
        do: tmpl
```
Copy: call `Sigra.Install.Features.{Admin,Core}.files/1` with a fixed binding to freeze the `{:eex, source, target}` tuples for the logos and the two CSS targets (`lib/sigra/install/features/admin.ex:52-60`, `core.ex:256`). Do not read template directories.

**Analog C (JSON registry via `JSON.decode!`):** `phase_234_playwright_inventory_contract_test.exs` lines 232-238:
```elixir
  defp inventory! do
    @inventory_path
    |> File.read!()
    |> JSON.decode!()
  end
```
Use `JSON.decode!` (Elixir stdlib, precedent in root tests; `jason` is not a direct root dep).

**Extraction sources (verified to exist; counts measured this session):**

| Category | Source | Method | Measured |
|----------|--------|--------|----------|
| `--sg-*` custom properties | `priv/templates/sigra.install/admin/sigra_admin.css` | regex `--sg-[a-z0-9-]+` | 100 distinct |
| `--sigra-auth-*` | `priv/templates/sigra.install/core/sigra_auth.css` | regex `--sigra-auth-[a-z0-9-]+` plus `Sigra.Branding.css_variables(Profile.default())` | 35 distinct in CSS; 14 emitted |
| `sg-*` / `sigra-auth*` classes | CSS selectors + `class="..."` in `lib/sigra/admin/**` and `priv/templates/sigra.install/**` | union of both sets | 112 / 66 selectors |
| `Profile` keys + defaults | `Sigra.Branding.Profile.defaults/0` (public, `lib/sigra/branding/profile.ex:120`) | `Map.to_list` sorted to JSON | 25 keys |
| Config keys | `lib/sigra/config.ex` `@schema` (line 54) | `Code.string_to_quoted/1` + recursive `keys:` walk (prototype in RESEARCH "Code Examples") | 33 top-level / 170 option paths |
| Routes | golden router `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex` | trimmed DSL lines (`live|get|post|put|patch|delete|forward|scope "`), tmp app alias normalized | ~50 lines |
| Helpers | `~p"..."` in `priv/templates/sigra.install/**` | regex | 54 distinct |
| Gettext domain | `dgettext("<domain>", ...)` in templates | regex | one domain `"sigra"`, 344 calls |
| `data-testid`s | lines with `testid` in `lib/sigra/**` and `priv/templates/sigra.install/**`; quoted strings starting `admin-` or `mfa-` | regex | 25 (13 plain `data-testid=`, 3 in `if @active`, 9 `*_testid=` args in `lib/sigra/admin/live/branding_live.ex`) |
| Logo filenames + installer targets | `Admin.files/1`, `Core.files/1` | fixed binding | see above |

**Frozen `Profile` defaults to assert verbatim** (`lib/sigra/branding/profile.ex:42-68`): `product_name: "Your app"`, `logo_alt: "Application logo"`, `accent_color: "#c2410c"`, `accent_foreground: "#ffffff"`, `background_color: "#f7f4ee"`, `surface_color: "#ffffff"`, `text_color: "#171717"`, `muted_color: "#6b6258"`, `border_color: "#ded8cf"`, `email_from_name: "Your app"`, `theme: :system`, `nil` for logo/dark/support/privacy/terms/email-address fields.

**Rules to encode:** additions pass silently; a removal fails with the category and name; the comparator is a pure function with its own unit tests (removal => red, addition => green); an opt-in regeneration path may only write a SUPERSET of the committed baseline and must refuse to shrink it. Phase-gate check (not ExUnit): `git diff <base>..HEAD -- test/fixtures/brand/frozen-surface.json | grep '^-[^-]'` must be empty.

---

#### `test/sigra/brand/legacy_profiles_test.exs` (test, pure-function transform)

**Analog:** `test/sigra/branding_test.exs` (whole file; module header lines 1-21, Profile construction lines 23-58, logo/dark-accent describe blocks lines 129-185). Imports/aliases to copy (lines 1-6):
```elixir
defmodule Sigra.BrandingTest do
  use ExUnit.Case, async: true

  alias Sigra.Branding
  alias Sigra.Branding.Profile
  alias Sigra.Config
```
Core pattern to copy (lines 129-141, constructing a profile then asserting an exact function output):
```elixir
    test "dark prefers dark_logo_url over logo_url" do
      profile = Profile.new!(logo_url: "/positive.svg", dark_logo_url: "/reversed.svg")

      assert Branding.logo(profile, :light) == "/positive.svg"
      assert Branding.logo(profile, :dark) == "/reversed.svg"
    end
```
Adapt: for each of three shapes (explicit: all seven light + seven dark colors plus logo URLs; partial: `product_name` + `accent_color` only; defaults: `Profile.default()`), commit the expected outputs in `test/fixtures/brand/legacy-profiles.json` for `Branding.css_variables/1` (`lib/sigra/branding.ex:284`), `Branding.color_tokens/2` (`:light`, `:dark`; lines 75, 87), `Branding.logo/2` both themes (lines 186-187), `Branding.email_logo/1` (203), `Branding.dark_accent_source/1` (116) and `Profile.to_map/1` (`profile.ex:112`); assert `==` (byte equality for the CSS string).

**Do NOT freeze** `preview_pair` HTML or admin copy (Phase 262 intentionally rewords "Login preview" -> "Sign-in preview"). Pure functions: no DB, `async: true` is fine.

---

### D. Copy contract (BCOPY-02, BCOPY-04, BCOPY-05)

#### `test/sigra/brand/copy_contract_test.exs` + `test/support/brand/copy_scan.ex`

**Analog:** `test/sigra/admin/glossary_test.exs` (leave it UNTOUCHED; it is green and has its own carve-outs). Copy its shape, do not extend it (PITFALLS C3).

**Test layout to copy** (lines 33-47):
```elixir
  describe "admin glossary drift guard" do
    test "no banned synonyms in admin chrome source files" do
      violations =
        @in_scope_files
        |> Enum.flat_map(&check_file/1)

      assert violations == [],
             """
             Banned synonym violations found in admin source files.
             Fix the copy before merging — use the canonical term from guides/reference/admin-glossary.md.

             #{Enum.join(violations, "\n")}
             """
    end
  end
```
**Scanner internals to lift and adapt** into `Sigra.Test.Brand.CopyScan`: `check_file/1` (lines 82-105: split lines, `Enum.with_index(1)`, per-term `Regex.compile!(pattern, [:caseless])`, `Regex.scan`, formatted violation `"file:line — found '...' — use '...' instead (...)"`), `strip_non_copy_lines/1` + `@strip_patterns` (lines 189-226: drop module/def lines, `@` attrs, comments, `data-testid=`, `data-sg-`, `class=` lines unless visible text, `href=`/`phx-*`, `|>`, `~r/`, `inspect(`, etc.), `strip_doc_and_heex_comment_blocks/1` (lines 239-282), and the `banned_terms/0` list shape `{regex, canonical, description}` (lines 304-329):
```elixir
      {"\\blog\\s+in\\b", "sign in", "log in (verb)"},
      {"\\blog\\s+out\\b", "sign out", "log out (verb)"},
      {"\\blogout\\b", "sign out", "logout"},
      {"\\bsignin\\b", "sign in", "signin"},
      {"\\blogin\\b", "sign-in", "login (noun or modifier)"},
```
**Self-test regression to copy** (lines 49-73, "strip_non_copy_lines regression"): a synthetic in-memory line list proves a term is caught with no file I/O. For the new module this is the planted-term unit test required by BCOPY-02.

**Three scopes** (RESEARCH Pattern 4): (a) the nine existing admin files plus shipped admin templates, term list = glossary list + phrase-level entries; (b) `priv/templates/sigra.install/**`: "log in/log out/login/logout" banned as COPY (string literals, `~H` text nodes, `aria-label|title|placeholder|label|alt|action` attributes) but identifiers (`log_in_user`, `/users/log_in`, `[:sigra, :auth, :logout, :stop]`) are not; (c) `README.md` + `guides/introduction/*.md` + `guides/flows/*.md`: lexicon-only (book "Do not say": hosted, managed, bank-grade, military-grade, unbreakable, zero trust, seamless, robust, compliant, certified, read from `brand/brand.json` `messaging.boilerplate`).

**Baseline file** `test/fixtures/brand/copy-baseline.json`: entries `{scope, file, normalized line}` (no line numbers). Rules: a hit not in baseline fails; a baseline entry with no matching hit fails with "remove this entry" (shrink-only). The lexicon baseline starts NON-empty with the repo's own negations: `README.md:13`, `guides/introduction/contract.md:61`, `SECURITY.md:27`, `guides/flows/oauth.md:81`, `guides/introduction/installation.md:90`, `guides/recipes/subdomain-auth.md:12,35`, `guides/introduction/migrating-from-pow-guardian-ueberauth.md:42` (RESEARCH grep). Baseline them; do not edit prose to pass.

**Module shape for the helper** — analog `test/support/planning_paths.ex` (lines 1-30 and 45-60): `defmodule Sigra.Test.PlanningPaths do @moduledoc """...""" @root Path.expand("../..", __DIR__) def root, do: @root`, functions return **repo-relative** paths, `@doc` on each public function. Copy: `defmodule Sigra.Test.Brand.CopyScan do`, `@moduledoc` stating it is test-only, `@root Path.expand("../../..", __DIR__)` (note `test/support/brand/` is one level deeper than `test/support/`), repo-relative returns. Keep every function used (compile is `--warnings-as-errors`).

**Inventory (BCOPY-04):** three TSVs `test/fixtures/brand/copy-inventory/{library,generated,host}.tsv`, sorted, `file<TAB>kind<TAB>string`, no line numbers, exact-equality test, opt-in regeneration flag (env var, default off). Lane contents: library = string literals (AST, excluding `@doc/@moduledoc/@spec/@type`) + `~H` text nodes in `lib/sigra/admin/**` plus `lib/sigra/error.ex` safe messages; generated = the 180 unique `dgettext("sigra", ...)` msgids, raw `put_flash` literals, HEEx text, email bodies in `priv/templates/sigra.install/**`; host = `Sigra.Branding.Profile` default strings plus an explicit "no Sigra copy by design" line. Collapse multi-line tags before stripping tags (naive strip yields ~666 lines / 399 unique for the library lane). TSV header-comment style: `.planning/decisions/003-tag-delete-list.tsv` begins with `# <path> — <purpose>` / `# WHY THIS FILE EXISTS` comment lines; use `#`-prefixed header lines and skip them on read.

**AST extraction precedent:** `Code.string_to_quoted/1` is already used in `architecture_guides_contract_test.exs:153-159` (parse a code block, `{:ok, _ast}` / `{:error, error}` -> `flunk`). Never `Code.eval_*` fixture or repo content (ASVS V5).

---

#### `test/sigra/brand/install_snippet_test.exs` (test, file-I/O regex scan)

**Analog:** `test/sigra/planning/phase_242_shift_left_contract_test.exs` lines 1-26 (file list + `root/0` + `Enum.each` over files with per-file assertion messages) and the non-vacuity precondition from `design_gallery_isolation_test.exs:19-24`:
```elixir
  defp root, do: Path.expand("../../..", __DIR__)

  test "public install snippets use the bounded maintained line" do
    Enum.each(@public_install_files, fn relative_path ->
      content = root() |> Path.join(relative_path) |> File.read!()

      assert content =~ "{:sigra, \"~> 1.5.0\"}", "#{relative_path} lacks the supported tuple"
      refute content =~ "{:sigra, \"~> 1.4.0\"}", "#{relative_path} retains the stale tuple"
    end)
  end
```
Adapt (RESEARCH design): regex `~r/\{:sigra,\s*"([^"]*)"/` over `README.md`, `guides/**/*.md`, `docs/**/*.md`, `priv/templates/**/*`; assert every requirement matches `~r/^~> \d+\.\d+\.\d+$/` (three segments), assert `MapSet.size(...) == 1` (all equal), and assert at least one occurrence in `README.md` and one under `guides/` (guards a vacuous green). Value is NOT pinned. Current state, all `~> 1.5.0`: `README.md:76`; `guides/introduction/{first-hour.md:24, getting-started.md:15, installation.md:27}`; `guides/recipes/companion-libs/{lockspire.md:37, accrue.md:30, relyra.md:46, threadline.md:49, mailglass.md:35, rulestead.md:36 and :102}` (11 occurrences). `guides/introduction/troubleshooting-install.md:37` contains `{:sigra, ...}` with an ellipsis and no quoted requirement, so the regex correctly skips it. `docs/` and `priv/templates/` currently have none. Leave `phase_242...` untouched (it pins the value; BPUB-05 will update both together).

---

#### `test/sigra/brand/policy_docs_test.exs` (test, file-I/O headings and key terms)

**Analog:** `test/sigra/architecture_guides_contract_test.exs`. Heading-presence + order pattern (lines 102-117):
```elixir
  test "architecture keeps the boundary-first narrative order" do
    architecture = File.read!(@architecture)

    indexes =
      Enum.map(@architecture_headings, fn heading ->
        case :binary.match(architecture, heading) do
          {index, _length} -> index
          :nomatch -> flunk("architecture guide is missing essential heading: #{heading}")
        end
      end)

    assert indexes == Enum.sort(indexes), "..."
    assert indexes == Enum.uniq(indexes), "architecture headings must each appear once"
  end
```
and `byte_index!/2` (lines 316-321: `:binary.match` or `flunk("missing expected contract text: ...")`). Helper style from `phase_249_release_docs_contract_test.exs:4-6`: `defp root, do: Path.expand("../../..", __DIR__)` and `defp read!(rel), do: root() |> Path.join(rel) |> File.read!()`.

Scope (keep to headings and key terms; do not over-pin prose): ADR 005 has each of the seven decisions; `contract.md` has the new H2; `brand-compatibility.md` has frozen list / add-only list / lane table / surface map / upgrade-note skeleton headings; ADR 006 title contains "search log, not clearance", names `crosswake_sigra`, and lacks "cleared"/trademark wording; the BPOL-06 negative grep; `admin-glossary.md` has the reconciliation section with the five rulings; each `known_divergence` registry row id is referenced from ADR 006's claims register. Use `File.regular?` assertions (as in architecture test lines 32-33) so a missing file fails by name.

---

### E. Enumeration parity (BCOPY-03)

#### `test/example/test/example_web/enumeration_parity_test.exs` (test, request-response) + `test/fixtures/brand/public-surfaces.json`

**Analog A (ConnTest, enumeration-safe flash):** `test/example/test/example_web/controllers/session_controller_test.exs`. Header + setup (lines 17-33):
```elixir
  use ExampleWeb.ConnCase, async: true
  import Example.AccountsFixtures

  alias Example.Accounts
  ...
  @moduletag :example_app

  setup do
    attrs = valid_user_attributes()
    {:ok, user} = Accounts.register_user(attrs)
    %{user: user, password: attrs.password}
  end
```
Invalid credentials probe (lines 150-162) and magic link probe (lines 193-203):
```elixir
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => "wrong-password"}
        })

      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
  ...
      conn =
        post(conn, ~p"/users/log_in", %{
          "_action" => "magic_link",
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "magic link"
```
The harness runs the SAME request for an existing and an unknown email and compares status, `redirected_to`, flash text, normalized body. Normalize: CSRF tokens, request ids, and the echoed email (the controller does `put_flash(:email, String.slice(email, 0, 160))`, `lib/example_web/controllers/session_controller.ex:133-134`).

**Analog B (LiveView submit, duplicate registration):** `test/example/test/example_web/live/registration_live_test.exs` lines 74-95:
```elixir
      {:ok, view, _html} = live(conn, "/users/register")

      html =
        view
        |> form("#registration_form", user: %{email: email, password: "hello world!!"})
        |> render_submit()

      assert html =~
               "If this email is available, your account has been created. Please check your email."
```
Same for `ResetPasswordLive` (`form("#reset_password_request_form", ...)`, event `send_instructions`; `test/example/lib/example_web/live/reset_password_live.ex:27,168`) and `ConfirmationLive` resend.

**Analog C (JSON options endpoint, passkey):** `test/example/test/example_web/controllers/passkey_session_controller_test.exs` lines 1-10, 60-74, 76-93 and helpers at 362-374 and 406-410:
```elixir
  use ExampleWeb.ConnCase, async: false
  import Example.AccountsFixtures
  setup :ensure_passkey_config_secret
  ...
      conn =
        conn
        |> put_passkey_json_headers()
        |> post(~p"/users/log_in/passkey/options", %{"user" => %{"email" => user.email}})

      options = json_response(conn, 200)["options"]
```
Because the passkey row needs `Application.put_env` and a passkey fixture, the parity module must be `async: false` (this file is `async: false`; `session_controller_test.exs` is `async: true`). Copy `ensure_passkey_config_secret/1` and `put_passkey_json_headers/1` rather than importing them (they are `defp`).

**Fixture helpers:** `Example.AccountsFixtures` lives in `test/example/test/support/fixtures/auth_fixtures.ex` (module name differs from file name): `user_fixture/1`, `valid_user_attributes/1`, `unique_user_email/0`, `valid_user_password/0` (lines 15-32).

**Reading the root fixture from the example project:** `__DIR__` for this file is `<root>/test/example/test/example_web`, so the registry path is `Path.expand("../../../fixtures/brand/public-surfaces.json", __DIR__)` (verified arithmetic: `..`x3 lands on `<root>/test`). Do not use `File.cwd!()`-relative paths for the root fixture (existing example tests use `File.cwd!()` only for example-local files, e.g. `registration_live_test.exs:7`).

**Registry shape (RESEARCH Pattern 5; model on `spec-ownership.json`):** top-level `"schema_version"` (e.g. `"sigra.public-surfaces/v1"`), then `"surfaces": [...]` with `id`, `route`, `kind` (controller|liveview|json), `probe`, `compare` (dimensions), `state` (`parity` | `known_divergence` | `by_design`), `note`/todo ref. `JSON.decode!` as in the 234 analog. Run in the example project: `Path.expand` + `JSON.decode!` (Elixir 1.19 stdlib; the example also has `:jason`).

**Comparator / positive control (no in-repo analog; design in RESEARCH):** `compare(a, b)` returns `:same | {:diff, details}`; `known_divergence` rows ASSERT the divergence still exists (so fixing the product forces the registry to shrink); `run_all(registry, leak: {surface_id, "No account found for"})` appends a leaky string to the unknown-identity response of exactly one surface; assert exactly one `{:diff, _}` and the rest unchanged. No leak switch in app code.

**Expected state per surface today (verified in source; do not "fix"):**

| Surface | Route / code | State |
|---------|--------------|-------|
| Password sign-in | `POST /users/log_in`; flash "Invalid email or password" (`session_controller.ex:128-135`) | `parity` at one attempt; repeat-attempt channel documented (`Lockout.check(nil)` returns `:ok`, `lib/sigra/lockout.ex:57`; `lib/sigra/error.ex:160-164`) |
| Magic link | `_action=magic_link`; controller swallows `{:error, :rate_limited}` (template `core/session_controller.ex:43`; example `session_controller.ex:79-89`) | `parity` at controller level |
| Password reset request | `ResetPasswordController.create` / `ResetPasswordLive` `send_instructions`: same info flash always | `parity` (response); library rate-limits only existing users (`lib/sigra/auth.ex:1125-1131`) |
| Confirmation resend | `ConfirmationLive` `resend` | `parity` for the example only (generated confirm routes broken for hosts; blocker todo `2026-09-15-generated-confirm-routes-unreachable-both-session-states.md`) |
| Registration | `RegistrationLive`: success sets `trigger_submit: true`, duplicate shows an info flash (template `core/registration_live.ex:134-143`) | `known_divergence` (inherent; plus timing-oracle todo) |
| Invitation accept | `/invitations/:token/accept` (`invitation_accept_live_test.exs`) | `by_design` capability URL; identity-parity dimension is `[ASSUMED]` |
| MFA challenge | invalid TOTP vs invalid backup code: both "Invalid verification code." (`lib/sigra/error.ex:181-182`) | `parity` on message |
| Passkey sign-in options | `POST /users/log_in/passkey/options` with `user[email]`: unknown -> `{error: "unavailable"}`, existing -> `{options: ...}` (template `core/session_controller.ex:141-153`, example controller :176, :193) | `known_divergence` (REAL existence oracle); the `"conditional" => "true"` path has no email and is parity |
| Enterprise SSO discovery | `_action=enterprise` | `by_design` (reveals a connection for the email domain, not the user) |

The passkey leak excerpt (template `core/session_controller.ex:141-146`, verbatim):
```elixir
  def passkey_authentication_options(conn, %{"user" => %{"email" => email}}) do
    config = Sigra.Passkeys.config()

    case Auth.get_user_by_email(email) do
      nil ->
        json(conn, %{error: "unavailable"})
```

Needs `cd test/example && mix deps.get && MIX_ENV=test mix ecto.create && mix ecto.migrate` before the first run; command: `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs` (verified: `session_controller_test.exs` 13 tests, 0 failures this way).

---

### F. Playwright `loginSubmit` helper (BCOPY-06)

#### `test/example/priv/playwright/helpers/loginSubmit.ts` (new test helper)

**Analog:** `test/example/priv/playwright/helpers/adminUsersIndex.ts` (lines 1-25; tiny exported locator factory, `import type { Page }`, JSDoc explaining why) and the "test-only" header convention of `helpers/fixtures.ts` (lines 1-12, `// test-only: ...`):
```ts
import type { Page } from '@playwright/test';

/**
 * Locates the user row/card on `/admin/users` for either responsive layout.
 * ...
 */
export function adminUsersEmailLocator(page: Page, email: string) {
  ...
  return page
    .locator('#admin-users-desktop-results tbody tr, #admin-users-mobile-results article')
    ...
}
```
Adapt (RESEARCH Pattern 6; statically verified against both markups this session):
```ts
// test-only: password-form submit locator that does not depend on button text.
import type { Page } from '@playwright/test';
export const LOGIN_SUBMIT_SELECTOR = '#login_form button:not([type="button"])';
export const loginSubmit = (page: Page) => page.locator(LOGIN_SUBMIT_SELECTOR);
```
Markup evidence: the example host login has exactly one `<button>` inside `#login_form` (`test/example/lib/example_web/controllers/session_html.ex:66-102`, `<.button class=...>Log in</.button>`; core component `core_components.ex:113` renders `<button class={@class} {@rest}>` with no `type`); the generated template has exactly one (`priv/templates/sigra.install/core/login_html.ex:110-122`, `<.sigra_auth_button ...>Sign in with password</.sigra_auth_button>`, rendering `<button type={@type} ...>` with `attr :type, default: "submit"`, `sigra_auth_components.ex:75-84`). The passkey `type="button"` control lives in a different form (`#passkey_login_form`). Runtime resolution is `[ASSUMED]` (not executed locally; Playwright `node_modules` absent, no `tsconfig.json`): proof is the PR's `example_playwright_shard` lanes. Export the string constant too: `demo-showcase.spec.ts:287` passes a selector STRING into `probe(...)`.

---

#### Playwright call-site replacements (11 locators in 6 files; requirement text says 8)

Verified by grep (`has-text("Log in")`):

| File:line | Current | Replace with |
|-----------|---------|--------------|
| `tests/organizations.spec.ts:73`, `:207` | `await page.click('#login_form button:has-text("Log in")');` | `await loginSubmit(page).click();` |
| `tests/organizations.spec.ts:483` | `await inviteePage.click('#login_form button:has-text("Log in")');` | `await loginSubmit(inviteePage).click();` (different page variable) |
| `tests/ga-uat-shift-left.spec.ts:44` | `page.click(...)` | `loginSubmit(page).click()` |
| `tests/demo-showcase.spec.ts:187` | `page.click(...)` | `loginSubmit(page).click()` |
| `tests/demo-showcase.spec.ts:287` | `const button = await probe('#login_form button:has-text("Log in")');` | `await probe(LOGIN_SUBMIT_SELECTOR)` (string argument) |
| `tests/demo-showcase.spec.ts:603` | `const loginButton = page.locator('#login_form button:has-text("Log in")');` | `const loginButton = loginSubmit(page);` |
| `tests/golden-path.spec.ts:66`, `:157` | `page.click(...)` | `loginSubmit(page).click()` |
| `tests/passkey-options.spec.ts:26` | `page.click(...)` | `loginSubmit(page).click()` |
| `helpers/adminFlows.ts:77` | `await page.click('#login_form button:has-text("Log in")');` | `await loginSubmit(page).click();` |

**Import paths:** specs import siblings as `'../helpers/fixtures'` / `'../helpers/adminUsersIndex'` (e.g. `tests/admin-audit.spec.ts:3-4`) so use `import { loginSubmit } from '../helpers/loginSubmit';`; `helpers/adminFlows.ts` is in `helpers/` so use `'./loginSubmit'`. Match each file's local quote style (`organizations`, `ga-uat`, `golden-path`, `adminFlows` use single quotes; `demo-showcase` and `passkey-options` use double). `passkey-options.spec.ts` has its own local helper functions; add the import at the top beside `import { test, expect } from "@playwright/test";`.

**Do NOT touch:** the heading assertions "Log in to Tasklane/Meridian Health/Night Ops" at `demo-showcase.spec.ts:241,496,512,568,590` (demo-host copy, not BCOPY-06) or the comment-only mentions at `admin-flow-org-admin.spec.ts:170,340`. Acceptance: `! grep -rn 'has-text("Log in")' test/example/priv/playwright` (excluding comments) and `demo-showcase.spec.ts:156` JSDoc comment is fine.

**Ownership inventory:** no change (`spec-ownership.json`, `phase_234` contract globs `tests/*.spec.ts` only; the helper is not a spec).

---

## Shared Patterns

### Non-vacuous file-system guard (apply to: source_pin, install_snippet, frozen_surface, copy_contract, policy_docs)
**Source:** `test/sigra/install/design_gallery_isolation_test.exs:18-24`. Every scan that walks a directory or globs files first asserts the root/glob is non-empty, with a message that says "run from the repo root".
```elixir
    assert File.dir?(@installer_template_root),
           "installer template root #{@installer_template_root} not found — " <>
             "run from the repo root; D-04 guard cannot verify isolation"
```

### Committed baseline + named-diff failure message (apply to: frozen_surface, copy_contract, source_pin, inventory TSVs)
**Source:** `test/sigra/install/golden_diff_test.exs:149-169` (missing / extra lists, "regenerate per the runbook" instruction in the failure text). Put the exact regeneration command in each failure message; regeneration is opt-in (env var) and, for ratchet baselines, may only add.

### Repo-root resolution (apply to: all new root tests)
**Source:** `test/sigra/planning/phase_242_shift_left_contract_test.exs:17` and `phase_249_release_docs_contract_test.exs:4-6`.
```elixir
  defp root, do: Path.expand("../../..", __DIR__)
  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()
```

### JSON registry/fixture reads (apply to: every `test/fixtures/brand/*.json` consumer)
**Source:** `phase_234_playwright_inventory_contract_test.exs:232-238`: `File.read!() |> JSON.decode!()`; fixtures carry a `schema_version`, as in `test/example/priv/playwright/spec-ownership.json` (`"schema_version": "sigra.playwright-ownership/v1"`). Never `Code.eval_*` fixture content.

### Test-module conventions (apply to: all new ExUnit modules)
`use ExUnit.Case, async: true` for pure-file/pure-function tests (all of `test/sigra/brand/*`); `@moduletag :example_app` and `ExampleWeb.ConnCase` for example tests (`async: false` when touching `Application.put_env`). Namespaces: `Sigra.<Area>.<Name>Test` for root tests (e.g. `Sigra.Install.AuthUIContractTest`), `Sigra.Test.*` for `test/support` helpers (e.g. `Sigra.Test.PlanningPaths`), `ExampleWeb.*Test` for example tests. CLAUDE.md testing rule: AAA style, flat, self-contained.

### Privacy (apply to: every new/edited file, docs, fixtures, commit messages)
Repo is public. No personal names, emails or home paths anywhere, including fixtures and test messages. Test emails use `.test` / `example.com` addresses (`unique_user_email/0` -> `user<n>@example.com`; demo personas `*.demo.tasklane.test`). Provenance string reads "brand book v2.0 (2026-11-13)". Phase-gate greps derive the personal-name pattern at run time from `$HOME` / `id -un` (never written into the repo) with a planted-failure control (RESEARCH "Phase-gate shell checks").

**Self-match gotcha (verified):** the RESEARCH phase-gate grep for home-directory paths run over `git diff aeda7273d..HEAD --text` already matches lines in the committed `259-RESEARCH.md` and the validation doc (they quote the grep pattern and a planted-failure control). Any new file that writes a literal home-path shape, including the privacy-scan regex inside `source_pin_test.exs`, will also trip the gate. Plans must either (a) build such patterns from fragments in test source (e.g. `"/" <> "Users" <> "/"`), and keep prose from spelling a literal `<prefix>/<name>` example, or (b) scope the gate to exclude the phase's own research/validation docs and the planted-control line. Decide this once in the gate definition; do not let an executor "fix" it by weakening the grep.

### Zero shipped bytes (apply to: every plan)
`git diff --stat aeda7273d..HEAD -- lib priv brandbook` prints nothing; `git diff --stat aeda7273d..HEAD -- .github scripts` stays within the stated budget (recommended: nothing). No new workflow, receipt, ledger, controller, hermetic fake, Mix task or dependency.

### Local gate (apply to: every plan's verification)
Per task: `mix test test/sigra/brand` plus `mix format --check-formatted`. Per wave: add `test/sigra/admin/glossary_test.exs test/sigra/error_test.exs test/sigra/branding_test.exs test/sigra/planning/phase_242_shift_left_contract_test.exs test/sigra/architecture_guides_contract_test.exs` and the example parity file. Phase gate: `MIX_ENV=test mix ci`, `cd test/example && MIX_ENV=test mix test --include example_app`, and the shell greps.

---

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `brand.sha256` | manifest | file-I/O (hash) | No checksum manifest exists in the repo; use stock `shasum -a 256 -c` format (RESEARCH Pattern 1, prototype verified 72/72). |
| `.gitattributes` | config | n/a | File does not exist at repo root or tracked anywhere; content `brand/** -text linguist-vendored` from RESEARCH. |
| Enumeration comparator + positive control (inside `enumeration_parity_test.exs`) | test logic | request-response compare | No existing "same request, existing vs unknown identity, compare" harness; the existing ConnTests assert one response at a time. Build from the three request/assert analogs above plus RESEARCH Pattern 5. |
| Privacy scan of binary metadata (PDF `/Author` etc., PNG `tEXt`, SVG `<metadata>`) | test logic | file-I/O (binary scan) | No existing binary/metadata scanner; RESEARCH lists the exact markers and the clean prototype result. |
| Copy-inventory HEEx text extractor (collapsed-tag strip) | test-support logic | transform | Closest is `glossary_test.exs` line-based stripping, which operates per line and cannot handle multi-line tags; design in RESEARCH Pattern 4 (`[ASSUMED]` A8). |

## Metadata

**Analog search scope:** `test/sigra/**`, `test/support/**`, `test/example/test/**`, `test/example/priv/playwright/**`, `test/fixtures/**`, `.planning/decisions/**`, `.planning/todos/pending/**`, `guides/**`, `lib/sigra/{branding,config,install,lockout,error}*`, `priv/templates/sigra.install/core/**`, `mix.exs`, `.formatter.exs`, `CLAUDE.md`, `AGENTS.md`, `test/example/AGENTS.md`.
**Files scanned:** ~75 read or grepped (full reads of the 12 closest analogs; targeted line-range reads for the rest).
**Pattern extraction date:** 2026-11-13
