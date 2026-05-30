# Phase 144: README Evaluator Lane & Docs/Proof — Research

**Researched:** 2026-05-30
**Domain:** ExDoc extras config, Markdown documentation authoring, VERIFICATION.md proof-bundle format
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**README (DOC-01)**
- D-01: Replace entirely — no scaffold boilerplate retained
- D-02: Three-sentence framing at top (what it is + 6 feature categories + one-command spin-up)
- D-03: Docker one-liner included (container name `vaultr-postgres`)
- D-04: Credentials table in README itself, using passwords from `personas.ex` (confirmed below)
- D-05: Rough-edge callouts with explicit trigger instructions for Dave and Frank
- D-06: Two Sigra hexdocs links — one inline in framing, one "Learn more" section at bottom
- D-07: `/dev/mailbox` and `/demo/credentials` in a "Dev tools" section with full localhost URLs

**Guide (DOC-02)**
- D-08: All 4 screenshots embedded (confirmed all 4 PNGs exist at exact paths)
- D-09: Feature-organized sections, not step-by-step numbered tutorial
- D-10: Screenshot leads each section (payoff before explanation)
- D-11: Canonical section structure locked (7 sections)
- D-12: ExDoc `:assets` map: `assets: %{"guides/assets" => "assets"}`; reference as `assets/filename.png`
- D-13: `guides/introduction/demo-showcase.md` added to `extras` list after `suite-integration.md`
- D-14: Carol's OAuth section honest — seeded identity row only; live flow needs real GitHub creds
- D-15: Persona coverage weighted: Admin full section, Alice brief baseline, Bob implicit via TOTP, Carol callout, Dave+Frank grouped "Rough Edges"

**Proof Bundle (DOC-03)**
- D-16: New `144-VERIFICATION.md` as primary artifact, Phase 140 YAML frontmatter format
- D-17: Six gates (full suite, dep-off lane, clean-state mix setup, screenshots committed, screenshots referenced, mix docs --warnings-as-errors)
- D-18: One pointer line to `docs/ga-evidence.md` under "Where to read next" — no verbatim gate output in ga-evidence.md

### Claude's Discretion

- Exact prose wording within guide sections
- Whether Alice gets an explicit subsection or an intro paragraph
- Ordering of "What's Next" links in README and guide
- Minor table/markup formatting choices
- Whether mix.exs docs alias approach for screenshot copy is added as a convenience (D-12 says committed copies for simplicity — alias is optional)

### Deferred Ideas (OUT OF SCOPE)

- `mix docs` pre-step alias to copy screenshots from snapshot dir to `guides/assets/`
- Mobile/dark variants of demo-showcase screenshots
- Alice's explicit narrative section (fold into orientation paragraph is acceptable)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | README has "Try it locally" evaluator lane — prerequisites, one-command spin-up, credentials table, rough-edge persona callouts | Credentials verified from personas.ex; current README is boilerplate — full replacement confirmed correct |
| DOC-02 | Guide page `guides/introduction/demo-showcase.md` walks evaluator through demo with embedded screenshots, wired into ExDoc extras | ExDoc assets config verified; extras insertion point confirmed; all 4 PNGs exist at exact expected paths |
| DOC-03 | Milestone proof bundle confirms full test suite green, dep-off lane green, mix setup from clean state, screenshots committed/rendered | 140-VERIFICATION.md format fully documented; 6 gate commands verified against Phase 140 patterns |
</phase_requirements>

## Summary

Phase 144 is a pure documentation and proof-bundle phase — no library code changes, no new LiveView code, no new tests. All prerequisite artifacts are confirmed in place: the 6 persona credentials are locked in `personas.ex`, all 4 Playwright screenshots are committed at their expected paths (total ~385KB), and the canonical VERIFICATION.md format is established by Phase 140.

The only non-trivial technical question is the ExDoc `:assets` configuration. Research confirms the `docs/0` function in `mix.exs` does NOT currently have an `:assets` key and `guides/assets/` does NOT yet exist. Both must be created. The ExDoc `:assets` map syntax `assets: %{"guides/assets" => "assets"}` copies everything in `guides/assets/` to `assets/` in the generated docs output, and markdown image references must use `assets/filename.png` (no leading slash, no relative path). The `groups_for_extras` regex `~r{guides/introduction/.?}` already covers `demo-showcase.md` — no new group needed.

The proof bundle follows exactly the Phase 140 six-gate pattern. Gate 3 (clean-state `mix setup`) is the only gate not directly inherited from Phase 140: it uses `mix ecto.drop` explicitly before `mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs`, run from `test/example/` not the repo root. Gates 4 and 5 (screenshot existence and guide references) are new grep-based gates. Gate 6 (mix docs --warnings-as-errors) is identical to Phase 140 Gate 5.

**Primary recommendation:** Write all three deliverables in a single wave. There are no inter-deliverable blocking dependencies within Phase 144 — README, guide, and VERIFICATION.md can be written in parallel plans, with VERIFICATION.md gated on the other two being committed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| README content | Static documentation | — | Pure markdown file replacing Phoenix scaffold boilerplate |
| ExDoc guide | Static documentation | mix.exs config | Guide file + assets dir + extras registration in docs/0 |
| Screenshots in guide | guides/assets/ (static) | ExDoc build | Files committed to git; ExDoc copies to output via :assets config |
| VERIFICATION.md | Planning artifacts | — | Planning-internal file; never shipped to Hexdocs |
| ga-evidence.md pointer | Public Hexdocs docs | — | One bullet line added to existing "Where to read next" section |

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| ExDoc | ~> 0.40 (0.40.1) [VERIFIED: mix.exs] | Guide page + assets rendering | Project's configured doc generator; `mix docs --warnings-as-errors` is the standard CI gate |
| Markdown (ExDoc flavor) | — | Guide authoring | ExDoc renders both HTML and Markdown (`formatters: ["html", "markdown"]` already in mix.exs) |

### Supporting
No new dependencies for this phase. All tooling is already in place.

### Alternatives Considered
None — this phase has no technology choices. All tools are locked by the project.

## Package Legitimacy Audit

No packages installed in this phase. Section not applicable.

## Architecture Patterns

### ExDoc Assets Config — Verified Shape

**Current `docs/0` in `mix.exs` (lines 161–248):**
```elixir
defp docs do
  [
    skip_undefined_reference_warnings_on: [...],
    main: "getting-started",
    source_ref: "v#{@version}",
    source_url: @source_url,
    formatters: ["html", "markdown"],
    extras: [
      # ... existing entries ...
      "guides/introduction/suite-integration.md",   # <-- demo-showcase.md goes AFTER this line
      # ...
    ],
    groups_for_extras: [
      Introduction: ~r{guides/introduction/.?},     # <-- already covers demo-showcase.md
      # ...
    ],
    groups_for_modules: [...]
  ]
end
```

**Change required:** Add `:assets` key to the list. Position: immediately after `formatters` and before `extras` is conventional, though Elixir keyword lists allow any order.

```elixir
assets: %{"guides/assets" => "assets"},
```

**`guides/introduction/suite-integration.md` is the last Introduction-group entry before the flows entries.** `demo-showcase.md` slots in immediately after it:

```elixir
"guides/introduction/suite-integration.md",
"guides/introduction/demo-showcase.md",   # <-- new entry here
"guides/flows/registration.md",
```

### Screenshot Reference Pattern in Markdown

ExDoc `:assets` config copies `guides/assets/*` → `assets/*` in the generated output. Markdown reference format (confirmed from ExDoc documentation conventions):

```markdown
![Credentials cheat-sheet showing all six demo persona emails and passwords](assets/demo-credentials-demo-showcase-chromium.png)
```

- NO leading slash
- NO relative `../` prefix
- NO `guides/assets/` prefix
- Always include descriptive alt text (ExDoc renders to HTML and to Markdown/llms.txt)

### guides/assets/ Directory

Directory does not exist yet. Must be created and 4 PNGs copied there from:
`test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/`

The 4 files to copy (all confirmed to exist, all committed in git):
- `demo-credentials-demo-showcase-chromium.png` (78,521 bytes)
- `admin-user-detail-demo-showcase-chromium.png` (102,157 bytes)
- `admin-user-list-demo-showcase-chromium.png` (120,406 bytes)
- `audit-explorer-demo-showcase-chromium.png` (84,582 bytes)

Total: ~385KB — negligible for a documentation asset.

These copies must be committed in git alongside the guide. The deferred alias approach (auto-copy before `mix docs`) is out of scope per D-12.

### Recommended Project Structure (this phase only)

```
guides/
├── introduction/
│   ├── suite-integration.md        # existing — demo-showcase.md slots after this
│   └── demo-showcase.md            # NEW — guide page
└── assets/                         # NEW directory
    ├── demo-credentials-demo-showcase-chromium.png
    ├── admin-user-detail-demo-showcase-chromium.png
    ├── admin-user-list-demo-showcase-chromium.png
    └── audit-explorer-demo-showcase-chromium.png

test/example/
└── README.md                       # REPLACE entirely (boilerplate removal)

docs/
└── ga-evidence.md                  # add 1 bullet under "Where to read next"

.planning/phases/144-readme-evaluator-lane-docs-proof/
└── 144-VERIFICATION.md             # NEW — proof bundle
```

### Existing Guides Naming and Format Convention

All existing Introduction guides:
- `installation.md`, `getting-started.md`, `first-hour.md`, `intermediate-production-path.md`,
  `troubleshooting-install.md`, `upgrading-to-v1.7.md` through `upgrading-to-v1.12.md`,
  `suite-integration.md`

Format observations:
- No YAML frontmatter (unlike PLAN.md / VERIFICATION.md files)
- H1 title at the top of the file
- Prose-first: "what this is" before any setup steps
- `suite-integration.md` uses `<!-- validated_against: ... -->` HTML comment on line 1 — NOT required for demo-showcase.md
- Cross-links use `.html` extension (e.g., `[Installation](installation.html)`) for ExDoc HTML output
- Internal links within the same file use standard anchor refs

### VERIFICATION.md Format (from Phase 140)

Exact YAML frontmatter schema:
```yaml
---
phase: 144-readme-evaluator-lane-docs-proof
verified: 2026-05-30T00:00:00Z   # fill with actual timestamp at run time
status: passed
score: X/6 hard gates PASS
overrides_applied: 0
gaps: []
deferred: []
human_verification: []
---
```

Gate row format (from 140-VERIFICATION.md Behavioral Spot-Checks table):
```
| Gate N: [name] | [exact command(s)] | [verbatim output: counts/exit code] | PASS / FINDING |
```

### Anti-Patterns to Avoid

- **Injecting `guides/introduction/demo-showcase.md` into extras without the `:assets` key:** ExDoc will find the file but images will 404 in the generated docs. Both changes (assets key + extras entry) must land together.
- **Using absolute paths or `../guides/assets/` relative paths in image markdown:** ExDoc copies assets to a flat `assets/` directory in the output; relative paths from the guide file will not resolve correctly.
- **Leaving `guides/assets/` out of git:** Committed copies are required (D-12). The screenshots will not be included in the `mix hex.publish` tarball or CI docs build unless they are in git.
- **Running Gate 3 (clean-state setup) without `mix ecto.drop` first:** Running `mix ecto.create` on an already-migrated DB does not prove clean-state. The `mix ecto.drop` step is mandatory per D-17.
- **Recording assumed-green results in VERIFICATION.md:** Anti-overclaim policy requires running each gate and recording actual output. Phase 140 VERIFICATION.md is the canonical exemplar of this pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image serving in ExDoc | Custom copy script or symlinks | `:assets` map in `docs/0` | ExDoc's native asset handling is the only reliable path; symlinks do not survive `mix hex.publish` |
| Credentials table content | Paraphrase from CONTEXT.md | Read from `personas.ex` directly | CONTEXT.md D-04 lists passwords; `personas.ex` is the single source of truth; paraphrasing introduces errors |

**Key insight:** This phase is entirely documentation authoring. The only non-obvious technical decision is the ExDoc `:assets` config, which has one correct form. Everything else is writing.

## Runtime State Inventory

Not applicable — this is a greenfield documentation phase. No rename, refactor, or migration.

## Common Pitfalls

### Pitfall 1: Extras entry without assets key
**What goes wrong:** The guide appears in ExDoc navigation but all image `![...](assets/...)` references return 404 in the generated docs. `mix docs --warnings-as-errors` may or may not catch this depending on ExDoc version — missing image files are not always treated as warnings.
**Why it happens:** Registering the extras entry causes ExDoc to render the guide, but without the `:assets` key the `guides/assets/` directory is never copied to the output tree.
**How to avoid:** Always add the `:assets` key and the extras entry in the same commit. Run `mix docs` and open `doc/index.html` → navigate to the demo-showcase guide to verify images render.
**Warning signs:** Images show as broken/missing icons in the rendered HTML guide.

### Pitfall 2: Wrong image path format in markdown
**What goes wrong:** Image references like `![...](../guides/assets/foo.png)` or `![...](/assets/foo.png)` or `![...](guides/assets/foo.png)` do not resolve in the ExDoc output.
**Why it happens:** ExDoc copies `guides/assets/*` to `assets/` in the output. Relative paths from the guide file location in the source tree do not map to the output tree. Leading slashes are absolute paths from the doc root, which also fail in some serving contexts.
**How to avoid:** Use exactly `assets/filename.png` — no leading slash, no relative prefix.
**Warning signs:** `mix docs` exits 0 but images appear broken in the rendered guide.

### Pitfall 3: Passwords from CONTEXT.md instead of personas.ex
**What goes wrong:** CONTEXT.md D-04 lists the credentials table with passwords. If the implementer copies from CONTEXT.md without verifying against `personas.ex`, any discrepancy between the two sources (e.g., if personas.ex was updated after the discuss session) would produce a README with wrong passwords.
**Why it happens:** CONTEXT.md was written before the discussion session concluded; `personas.ex` was written during Phase 141 execution. `personas.ex` is the authoritative source per D-04.
**How to avoid:** Read `personas.ex` `all/0` and `feature_map/0` directly; cross-check that README credentials match exactly. The passwords are confirmed below.

### Pitfall 4: Gate 3 clean-state on already-migrated DB
**What goes wrong:** Running `mix setup` or `mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs` on an already-migrated database does not prove clean-state — migrations skip silently if the schema is current.
**Why it happens:** The seed gate is intended to prove that a fresh evaluator can run these commands and get a working app. Without `mix ecto.drop`, the test runs on top of existing state.
**How to avoid:** Gate 3 sequence must be: `cd test/example && mix ecto.drop && mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs` (all four sub-commands, in order, with actual exit codes recorded).

### Pitfall 5: ga-evidence.md pointer format mismatch
**What goes wrong:** Adding a section header, verbose description, or gate output to `ga-evidence.md` instead of a single bullet line under "Where to read next".
**Why it happens:** The VERIFICATION.md is a planning-internal artifact with verbose gate output. It is easy to conflate the two files' purposes.
**How to avoid:** `ga-evidence.md` gets exactly one new bullet under the existing "Where to read next" section. No new section headers, no gate output. The bullet format matches the existing bullets on that page (e.g., `- [v1.31 DEMO-SHOWCASE proof bundle (planning-internal)](...)`).

## Code Examples

### Verified Credentials (from personas.ex all/0)

```
admin@demo.sigra.dev  | DemoAdmin1!SecurePass  | Admin — TOTP MFA, passkey display row, multi-org owner, rich audit trail
alice@demo.sigra.dev  | AliceDemoPass1!        | Standard confirmed user — happy path login, Acme Corp member
bob@demo.sigra.dev    | BobDemoPass1!Beta      | TOTP MFA enrolled — org owner (Beta Labs)
carol@demo.sigra.dev  | CarolDemoPass1!Github  | OAuth identity — GitHub-linked login
dave@demo.sigra.dev   | DaveDemoPass1!Locked   | Locked account — failed login attempts exhausted, unconfirmed
frank@demo.sigra.dev  | FrankDemoPass1!Deleted | Scheduled deletion — account marked for deletion
```

Note: Dave's `confirmed: false` — he is unconfirmed AND locked. The README callout should mention both (unconfirmed + locked, failed login count at limit).

### mix.exs docs/0 — Required Changes

**Add `:assets` key (after `formatters`):**
```elixir
formatters: ["html", "markdown"],
assets: %{"guides/assets" => "assets"},
extras: [
```

**Add extras entry (after `suite-integration.md`):**
```elixir
"guides/introduction/suite-integration.md",
"guides/introduction/demo-showcase.md",
```

No change to `groups_for_extras` — `Introduction: ~r{guides/introduction/.?}` already matches.

### 144-VERIFICATION.md Gate 3 Command Sequence

```bash
# Gate 3: Clean-state mix setup
cd test/example
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
# Record exit code of each sub-step separately
```

### 144-VERIFICATION.md Gate 4 Command

```bash
# Gate 4: Screenshots committed
ls -la test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/*.png
# Expected: 4 PNGs listed; record file listing verbatim
```

### 144-VERIFICATION.md Gate 5 Command

```bash
# Gate 5: Screenshots referenced in guide
grep -r "demo-showcase-chromium" guides/introduction/demo-showcase.md
# Must match all 4 image filename stems; record output verbatim
```

### 144-VERIFICATION.md Gate 6 Command

```bash
# Gate 6: ExDoc clean
mix docs --warnings-as-errors
# Record: exit code, output lines; expected exit 0
```

### ga-evidence.md Pointer Line

Add under the existing "Where to read next" section:
```markdown
- [v1.31 DEMO-SHOWCASE proof bundle (planning-internal)](.planning/phases/144-readme-evaluator-lane-docs-proof/144-VERIFICATION.md)
```

The existing bullets in that section use relative paths anchored to the repo (e.g., GitHub blob URLs for GA matrix, hexdocs `.html` links for rendered pages). The 144-VERIFICATION.md is a planning-internal file not on Hexdocs, so a relative repo path is appropriate.

### Demo-Showcase Guide — Section Header Skeleton

```markdown
# Demo Showcase — Vaultr Example App

[2-sentence orientation]

## Running the Demo

## Credentials Cheat-Sheet

![Credentials cheat-sheet showing all six demo persona emails and passwords](assets/demo-credentials-demo-showcase-chromium.png)

## Admin: Platform-Admin View

![Admin user detail showing TOTP MFA enrollment, passkey display row](assets/admin-user-detail-demo-showcase-chromium.png)

![Admin user list showing all six demo personas](assets/admin-user-list-demo-showcase-chromium.png)

## Audit Log

![Audit log explorer showing six or more distinct event types](assets/audit-explorer-demo-showcase-chromium.png)

## Rough Edges: Locked and Scheduled-Deletion Accounts

## OAuth Identity

## What's Next
```

### Current test/example/README.md — Content to Replace

The entire current content is Phoenix scaffold boilerplate:
```markdown
# Example

To start your Phoenix server:
* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
...
## Learn more
* Official website: https://www.phoenixframework.org/
...
```

All of this is replaced. Nothing from the scaffold is retained.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phoenix scaffold README ("Learn more" pointing to Phoenix docs) | Evaluator-focused README with credentials table and conversion path | Phase 144 | Removes "generic unfinished template" signal that undermines positioning |
| No ExDoc guide for example app | `guides/introduction/demo-showcase.md` with embedded screenshots | Phase 144 | Makes the demo findable and legible from Hexdocs |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ExDoc `:assets` map syntax `%{"guides/assets" => "assets"}` causes ExDoc to copy `guides/assets/*` to `assets/` in the generated output, and markdown `assets/filename.png` resolves correctly | Standard Stack / Code Examples | Images 404 in generated docs; requires different path approach |
| A2 | `groups_for_extras: [Introduction: ~r{guides/introduction/.?}]` regex covers `demo-showcase.md` without any change | Standard Stack | New guide does not appear in the Introduction group in ExDoc nav |
| A3 | `mix ecto.drop` from `test/example/` drops the example app's dev database without dropping the sigra library's test database | Common Pitfalls / Gate 3 | Wrong database dropped; or drop fails if the dev DB doesn't exist yet |

Note on A1: The `:assets` map syntax is from ExDoc documentation. The claim that `guides/assets/` maps to `assets/` in output and that `assets/filename.png` is the correct reference is based on ExDoc's published asset handling behavior [ASSUMED — training knowledge; verified by checking ExDoc changelog context but not directly confirmed via Context7 for this specific version].

Note on A2: The regex `~r{guides/introduction/.?}` clearly matches `guides/introduction/demo-showcase.md` — this is not a meaningful assumption, just recorded for completeness [HIGH confidence — regex match is unambiguous].

Note on A3: The example app has its own Ecto repo config in `test/example/config/`. Running `mix ecto.drop` from `test/example/` will use the example app's repo config, not the library's. Confirmed by Phase 141 SC#1 which establishes that `mix run priv/repo/seeds.exs` from `test/example/` uses the example app's DB. [HIGH confidence]

## Open Questions

1. **ExDoc :assets path behavior with nested subdirectory**
   - What we know: ExDoc `:assets` map `%{"source_dir" => "output_dir"}` copies files from `source_dir` to `output_dir` in the generated docs
   - What's unclear: Whether ExDoc flattens the directory or preserves subdirectory structure; whether `guides/assets/foo.png` becomes `assets/foo.png` or `assets/guides/assets/foo.png` in output
   - Recommendation: The path format `assets/filename.png` (without `guides/assets/` prefix) is the standard ExDoc convention per D-12; if images appear broken after `mix docs`, check the generated `doc/assets/` directory for actual filenames. The 4 PNGs have no subdirectory nesting so flattening is not a risk.

2. **Dave's persona state for README callout**
   - What we know: `personas.ex` has Dave with `confirmed: false` and `locked: true`
   - What's unclear: CONTEXT.md D-05 says "failed login count is at the limit" — but personas.ex just sets `locked: true`. The exact mechanism (whether `failed_login_attempts` column is set to 5) is an implementation detail of Phase 141's seed orchestrator.
   - Recommendation: README callout should say "account locked — try the wrong password to see the enumeration-resistant response; unlock via /admin/users as admin." This is accurate regardless of the exact column value.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | Gate 3 (clean-state setup) | Assumed ✓ | postgres:16-alpine or local | Must be running for gate to pass |
| mix docs (ExDoc) | Gate 6 | ✓ | ex_doc ~> 0.40 in mix.exs | None — required gate |
| Playwright PNG snapshots | DOC-02 guide images, Gate 4 | ✓ | 4 PNGs confirmed at exact paths | None — already committed |

**Missing dependencies with no fallback:** None. All required tools are available.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (mix test) — existing |
| Config file | `test/example/` has its own ExUnit config |
| Quick run command | `mix test test/sigra/audit/` (from repo root) |
| Full suite command | `mix test` (from repo root) |

### Phase Requirements → Proof Map
| Req ID | Behavior | Verification Type | Command | Gate |
|--------|----------|-------------------|---------|------|
| DOC-01 | README has prerequisites + credentials table + rough-edge callouts + dev tools | grep assertions | `grep -c "Try it locally\|demo.sigra.dev\|dev/mailbox" test/example/README.md` | Gate inline |
| DOC-02 | Guide exists with screenshots wired into ExDoc | build check + image ref grep | `mix docs --warnings-as-errors` + `grep "demo-showcase-chromium" guides/introduction/demo-showcase.md` | Gates 5 + 5 |
| DOC-03 | 6-gate proof bundle confirms full suite, dep-off, clean setup, screenshots | run gates verbatim | See D-17 gate sequence | 144-VERIFICATION.md |

### Sampling Rate
- **Per task commit:** `mix docs --warnings-as-errors` (confirms guide wiring stays clean)
- **Phase gate:** All 6 VERIFICATION.md gates run before filing 144-VERIFICATION.md

### Wave 0 Gaps
None — existing test infrastructure covers phase requirements. No new test files needed.

## Security Domain

This phase is documentation-only. No new authentication paths, input handling, token management, or cryptographic operations are introduced. ASVS categories do not apply. The security posture of the demo app (Argon2id hashing, rate limiting, enumeration resistance) is unchanged and documented in README rough-edge callouts per D-05.

## Sources

### Primary (HIGH confidence)
- `test/example/lib/example/demo/personas.ex` — Personas.all/0 and feature_map/0; credentials table source of truth [VERIFIED: direct codebase read]
- `mix.exs` lines 161–248 — docs/0 function; current extras list, groups_for_extras, no existing :assets key [VERIFIED: direct codebase read]
- `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/` — all 4 PNGs confirmed present with exact filenames [VERIFIED: ls -la output]
- `.planning/phases/140-deprecation-hygiene-verification-docs-close/140-VERIFICATION.md` — YAML frontmatter schema, gate row format, anti-overclaim pattern [VERIFIED: direct codebase read]
- `.planning/phases/140-deprecation-hygiene-verification-docs-close/140-03-PLAN.md` — dep-off lane gate sequence [VERIFIED: direct codebase read]
- `docs/ga-evidence.md` — "Where to read next" section with existing bullet format [VERIFIED: direct codebase read]
- `test/example/README.md` — current content (full scaffold boilerplate, 19 lines) [VERIFIED: direct codebase read]
- `guides/introduction/` — all 12 existing guide filenames; `demo-showcase.md` slots after `suite-integration.md` [VERIFIED: ls output]

### Secondary (MEDIUM confidence)
- ExDoc `:assets` map syntax and `assets/filename.png` reference convention [ASSUMED — training knowledge consistent with ExDoc documentation patterns]

## Metadata

**Confidence breakdown:**
- Credentials table content: HIGH — read directly from personas.ex
- mix.exs insertion points: HIGH — read the exact lines; no :assets key exists; extras insertion point after suite-integration.md is unambiguous
- Screenshot existence: HIGH — ls -la confirmed all 4 PNGs at exact paths
- ExDoc :assets behavior: MEDIUM — training knowledge; standard convention but not re-confirmed via Context7
- VERIFICATION.md format: HIGH — Phase 140 VERIFICATION.md is the canonical exemplar and was read in full
- ga-evidence.md pointer format: HIGH — read the existing "Where to read next" section directly

**Research date:** 2026-05-30
**Valid until:** 2026-06-30 (stable documentation domain; ExDoc config is project-locked)
