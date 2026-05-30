# Phase 144: README Evaluator Lane & Docs/Proof — Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 6
**Analogs found:** 5 / 6 (guides/assets/ is a new directory with no existing analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/example/README.md` | documentation | static | `guides/introduction/getting-started.md` | role-match |
| `guides/introduction/demo-showcase.md` | documentation/guide | static | `guides/introduction/suite-integration.md` | exact |
| `guides/assets/` (new dir + 4 PNGs) | static-assets | file-I/O | none | no-analog |
| `mix.exs` docs/0 function | config | transform | `mix.exs` lines 161–248 (current docs/0) | exact |
| `docs/ga-evidence.md` | documentation | static | `docs/ga-evidence.md` (self — one-line append) | exact |
| `.planning/phases/144-.../144-VERIFICATION.md` | proof-bundle | static | `.planning/phases/140-.../140-VERIFICATION.md` | exact |

---

## Pattern Assignments

### `test/example/README.md` (documentation, static — full replacement)

**Analog:** `guides/introduction/getting-started.md`

**Framing pattern** (getting-started.md lines 1–7) — prose-first, answer "what is this" before setup:
```markdown
# Getting Started

This guide takes you from a fresh Phoenix app with Sigra installed to a working auth
experience: register a user, log in, protect a route, log out, request a password reset,
click the reset link, and log in again with the new password. **Budget: under 30 minutes
of reading.** Every code block here runs against the scaffolding `mix sigra.install` generates.

If you have not installed Sigra yet, read [Installation](installation.html) first.
```

**Key structural decisions for README (from CONTEXT.md D-01 through D-07):**
- Replace all Phoenix scaffold boilerplate (current 19-line README is entirely boilerplate)
- Three-sentence framing block first (what Vaultr is + link `[Sigra](https://hexdocs.pm/sigra)` + 6 feature categories + one-command spin-up)
- Docker one-liner: container name `vaultr-postgres` (distinct from `sigra-test-postgres`)
- Credentials table in-line (not just a pointer to /demo/credentials)
- "Dev tools" section with full localhost URLs for /dev/mailbox and /demo/credentials
- Rough-edge callouts for Dave and Frank with explicit trigger instructions
- "Learn more about Sigra" section at bottom replaces Phoenix "Learn more"

**Credentials table — exact values from `test/example/lib/example/demo/personas.ex` `all/0` and `feature_map/0`:**

| Email | Password | Feature demonstrated |
|---|---|---|
| admin@demo.sigra.dev | DemoAdmin1!SecurePass | Admin — TOTP MFA, passkey display row, multi-org owner, rich audit trail |
| alice@demo.sigra.dev | AliceDemoPass1! | Standard confirmed user — happy path login, Acme Corp member |
| bob@demo.sigra.dev | BobDemoPass1!Beta | TOTP MFA enrolled — org owner (Beta Labs) |
| carol@demo.sigra.dev | CarolDemoPass1!Github | OAuth identity — GitHub-linked login |
| dave@demo.sigra.dev | DaveDemoPass1!Locked | Locked account — failed login attempts exhausted, unconfirmed |
| frank@demo.sigra.dev | FrankDemoPass1!Deleted | Scheduled deletion — account marked for deletion |

**Dave callout pattern (D-05):** Account is locked AND unconfirmed (`confirmed: false`, `locked: true` from personas.ex line 96-98). Callout must say: "account locked and unconfirmed — try the wrong password to see the enumeration-resistant response; unlock via /admin/users as admin."

**Frank callout pattern (D-05):** `scheduled_deletion: true` in personas.ex line 111. Callout must say: "scheduled_deletion_at is set — account is still active; inspect via /admin/users as admin."

**Cross-link format:** Full localhost URLs in Dev tools section (e.g., `http://localhost:4000/dev/mailbox`, `http://localhost:4000/demo/credentials`). Hexdocs links using full absolute URLs (not `.html` relative) since this README is not served by ExDoc.

---

### `guides/introduction/demo-showcase.md` (documentation/guide, static — new file)

**Analog:** `guides/introduction/suite-integration.md`

**File header pattern** (suite-integration.md lines 1–9) — note: demo-showcase.md does NOT use the `<!-- validated_against: -->` HTML comment (RESEARCH.md confirms this is not required for demo-showcase.md):
```markdown
# Suite Integration

Last validated: 2026-05-27.

> **Sigra works fully standalone.** Threadline...
```

**For demo-showcase.md, open with H1 + 2-sentence orientation, no HTML comments, no "Last validated" line.**

**Section structure pattern** (D-11, locked) — copy this skeleton exactly:
```markdown
# Demo Showcase — Vaultr Example App

[2-sentence orientation: Vaultr is Sigra's seeded showcase; what you'll see]

## Running the Demo

## Credentials Cheat-Sheet

![Credentials cheat-sheet showing all six demo persona emails and passwords](assets/demo-credentials-demo-showcase-chromium.png)

## Admin: Platform-Admin View

![Admin user detail showing TOTP MFA enrollment and passkey display row](assets/admin-user-detail-demo-showcase-chromium.png)

![Admin user list showing all six demo personas](assets/admin-user-list-demo-showcase-chromium.png)

## Audit Log

![Audit log explorer showing six or more distinct event types](assets/audit-explorer-demo-showcase-chromium.png)

## Rough Edges: Locked and Scheduled-Deletion Accounts

## OAuth Identity

## What's Next
```

**Image reference pattern** (D-12, RESEARCH.md Architecture Patterns) — exact format, no deviation:
```markdown
![Descriptive alt text](assets/filename.png)
```
- NO leading slash
- NO `../guides/assets/` prefix
- NO `guides/assets/` prefix
- Alt text describes what the screenshot shows

**Cross-link format in guide** (suite-integration.md lines 73–79) — use `.html` extension for ExDoc-rendered links:
```markdown
[Getting started](./getting-started.html)
[Installation](installation.html)
[Threadline recipe](../recipes/companion-libs/threadline.html)
```

**Carol's OAuth section pattern (D-14):** Be explicit that the seeded GitHub identity row is display-only; the live OAuth flow requires real GitHub credentials. Do not imply end-to-end OAuth works in the demo.

**"What's Next" section pattern** (suite-integration.md lines 132–147) — bullet list of named links with `.html` extension:
```markdown
- **[Installation](installation.html)** — ...
- **[Getting started](getting-started.html)** — ...
- **[MFA guide](../flows/mfa.html)** — ...
```

---

### `guides/assets/` (new directory + 4 PNG copies — no existing analog)

**No analog in codebase.** `guides/assets/` does not yet exist (confirmed: `ls /Users/jon/projects/sigra/guides/assets` → "No such file or directory").

**Action for planner:** Create the directory and copy all 4 PNGs from their source location. The 4 files to copy (all confirmed present at source):

| Source path | Destination |
|---|---|
| `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/demo-credentials-demo-showcase-chromium.png` | `guides/assets/demo-credentials-demo-showcase-chromium.png` |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-detail-demo-showcase-chromium.png` | `guides/assets/admin-user-detail-demo-showcase-chromium.png` |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-list-demo-showcase-chromium.png` | `guides/assets/admin-user-list-demo-showcase-chromium.png` |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/audit-explorer-demo-showcase-chromium.png` | `guides/assets/audit-explorer-demo-showcase-chromium.png` |

Files must be committed in git (not gitignored). No alias needed per D-12.

---

### `mix.exs` docs/0 function (config — two targeted additions)

**Analog:** `mix.exs` lines 161–248 (current docs/0 function — read in full above)

**Current state (lines 184–205):**
```elixir
formatters: ["html", "markdown"],
extras: [
  "README.md",
  ...
  "guides/introduction/suite-integration.md",
  "guides/flows/registration.md",
  ...
```

**Change 1 — add `:assets` key** immediately after `formatters:` line (line 184), before `extras:`:
```elixir
formatters: ["html", "markdown"],
assets: %{"guides/assets" => "assets"},
extras: [
```

**Change 2 — add extras entry** after `"guides/introduction/suite-integration.md"` (currently line 204), before `"guides/flows/registration.md"` (currently line 205):
```elixir
"guides/introduction/suite-integration.md",
"guides/introduction/demo-showcase.md",
"guides/flows/registration.md",
```

**No change needed to `groups_for_extras`** — the existing regex on line 233 already covers it:
```elixir
Introduction: ~r{guides/introduction/.?},
```

**Anti-pattern:** Do not add the extras entry without the `:assets` key in the same commit — images will 404 in generated docs if the key is absent.

---

### `docs/ga-evidence.md` (documentation — one-line append)

**Analog:** `docs/ga-evidence.md` (self — the existing "Where to read next" section)

**Current "Where to read next" section** (lines 9–19 of ga-evidence.md):
```markdown
## Where to read next

- [UAT ↔ CI coverage — OA-01 / OA-02 machine baseline (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/docs/uat-ci-coverage.md)
- [v1.4 GA / UAT matrix (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/v1.4-GA-UAT.md)
- [v1.4 requirements closure (tag snapshot)](https://github.com/sztheory/sigra/blob/v0.2.0/.planning/milestones/v1.4-REQUIREMENTS.md)
- [UAT ↔ CI coverage](uat-ci-coverage.html)
- [Audit semantics](audit-semantics.html)
- [Maintaining & releasing](maintaining.html)
- [Contributing](contributing.html)
- [Security policy](security.html)
```

**One line to append at end of that bullet list** (D-18):
```markdown
- [v1.31 DEMO-SHOWCASE proof bundle (planning-internal)](.planning/phases/144-readme-evaluator-lane-docs-proof/144-VERIFICATION.md)
```

**Pattern rules (from D-18 and RESEARCH.md Pitfall 5):**
- No new section header
- No verbatim gate output
- No milestone summary
- Exactly one bullet line
- Use a relative repo path (not a hexdocs `.html` link) since 144-VERIFICATION.md is planning-internal and not shipped to Hexdocs

---

### `.planning/phases/144-readme-evaluator-lane-docs-proof/144-VERIFICATION.md` (proof-bundle — new file)

**Analog:** `.planning/phases/140-deprecation-hygiene-verification-docs-close/140-VERIFICATION.md` (read in full above)

**YAML frontmatter pattern** (140-VERIFICATION.md lines 1–12 — copy this schema exactly):
```yaml
---
phase: 144-readme-evaluator-lane-docs-proof
verified: 2026-05-30T00:00:00Z   # fill with actual timestamp when gates are run
status: passed
score: X/6 hard gates PASS
overrides_applied: 0
gaps: []
deferred: []
human_verification: []
---
```

**Gate table pattern** (140-VERIFICATION.md Behavioral Spot-Checks section, lines 44–58):
```markdown
## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Gate 1: Full suite | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` | [verbatim: N tests, N failures; exit code X] | PASS / FINDING |
| Gate 2: Dep-off — unlock | `mix deps.unlock threadline` | Unlocked deps: threadline; exit 0 | PASS |
| Gate 2: Dep-off — clean | `mix deps.clean threadline --build` | Cleaning threadline; exit 0 | PASS |
| Gate 2: Dep-off — compile | `MIX_ENV=test mix compile --warnings-as-errors --no-deps-check` | exit 0; no warnings | PASS |
| Gate 2: Dep-off — test | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --exclude requires_threadline --no-deps-check` | [verbatim output] | PASS / FINDING |
| Gate 2: Dep restore | `mix deps.get` | threadline X.X.X restored; exit 0 | PASS |
| Gate 3: Clean-state — drop | `cd test/example && mix ecto.drop` | [verbatim output]; exit 0 | PASS |
| Gate 3: Clean-state — create | `mix ecto.create` | [verbatim output]; exit 0 | PASS |
| Gate 3: Clean-state — migrate | `mix ecto.migrate` | [verbatim output]; exit 0 | PASS |
| Gate 3: Clean-state — seeds | `mix run priv/repo/seeds.exs` | [verbatim output]; exit 0 | PASS |
| Gate 4: Screenshots committed | `ls -la test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/*.png` | [verbatim file listing — 4 PNGs] | PASS |
| Gate 5: Screenshots referenced | `grep -r "demo-showcase-chromium" guides/introduction/demo-showcase.md` | [verbatim grep output — 4 matches] | PASS |
| Gate 6: ExDoc clean | `mix docs --warnings-as-errors` | exit code 0; "View html docs at `doc/index.html`" | PASS |
```

**Anti-overclaim policy** (140-VERIFICATION.md lines 71–80): Run each gate and record actual verbatim output. Do not record assumed-green results. Pre-existing environment findings are recorded verbatim and labeled FINDING (non-blocking) rather than suppressed or labeled PASS.

**Gate 3 ordering constraint (D-17, RESEARCH.md Common Pitfalls):** `mix ecto.drop` MUST come before `mix ecto.create`. Running against an already-migrated DB does not prove clean-state. All four sub-commands must be run from `test/example/` (not repo root).

**File location:** `.planning/phases/144-readme-evaluator-lane-docs-proof/144-VERIFICATION.md` (planning-internal, not wired into ExDoc extras, not shipped to Hexdocs).

---

## Shared Patterns

### ExDoc link format
**Source:** All existing `guides/introduction/*.md` files
**Apply to:** `guides/introduction/demo-showcase.md`

Use `.html` extension for all cross-links to other guide pages rendered by ExDoc:
```markdown
[Installation](installation.html)
[Getting started](getting-started.html)
[MFA guide](../flows/mfa.html)
```
Use full absolute URLs (`https://hexdocs.pm/sigra`) for external library references. Do NOT use relative `.md` paths in guide cross-links — they resolve in a text editor but break in the ExDoc-generated HTML output.

### Prose-first structure
**Source:** `guides/introduction/getting-started.md` lines 1–7, `guides/introduction/suite-integration.md` lines 9–13
**Apply to:** `test/example/README.md`, `guides/introduction/demo-showcase.md`

Pattern: H1 title → orientation sentence(s) → what you'll see or do → prerequisite callout → then steps/sections. Never lead with a numbered step list before the reader knows what the document is for.

### Anti-overclaim / verbatim output recording
**Source:** `.planning/phases/140-deprecation-hygiene-verification-docs-close/140-VERIFICATION.md` lines 71–80
**Apply to:** `144-VERIFICATION.md`

Never record assumed-green results. Run every gate. Record exit codes and output verbatim. Pre-existing failures are labeled FINDING with explanation rather than suppressed.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `guides/assets/` (directory + PNGs) | static-assets | file-I/O | No existing `guides/assets/` directory or any other assets directory in the guides tree; this is the first ExDoc assets directory in the project |

---

## Metadata

**Analog search scope:** `guides/introduction/`, `docs/`, `.planning/phases/140-*/`, `test/example/`, `mix.exs` lines 155–248
**Files read:** 8 (140-VERIFICATION.md, mix.exs docs/0 section, docs/ga-evidence.md, test/example/README.md, guides/introduction/suite-integration.md, guides/introduction/getting-started.md, test/example/lib/example/demo/personas.ex, 144-CONTEXT.md + 144-RESEARCH.md)
**Pattern extraction date:** 2026-05-30
