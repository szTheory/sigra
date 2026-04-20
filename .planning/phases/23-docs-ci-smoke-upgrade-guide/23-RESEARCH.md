# Phase 23: Docs, CI Smoke, Upgrade Guide - Research

**Researched:** 2026-04-16
**Domain:** HexDocs DX, generated test helpers, upgrade-path documentation, and Playwright CI smoke for organizations + passkeys [VERIFIED: codebase grep]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Documentation shape

- **D-01:** Keep the existing HexDocs taxonomy instead of inventing a new one for Phase 23.

  The repo already groups extras under `guides/introduction/`, `guides/flows/`, and `guides/recipes/` in `mix.exs`. Phase 23 should fit into that structure:
  - `guides/introduction/getting-started.md` gets the new organizations + passkeys walkthrough section
  - `guides/introduction/upgrading-to-v1.1.md` is the upgrade guide
  - roadmap "how-to" guides land under `guides/recipes/` to match the existing sidebar grouping rather than creating a parallel `guides/how-to/` tree

- **D-02:** `getting-started.md` remains a fast happy-path guide, not a full reference dump.

  The current guide is explicitly budgeted for under 30 minutes. Extend it with one coherent "Organizations & Passkeys" continuation after the baseline auth flow instead of rewriting the whole page into a kitchen-sink reference. Keep the narrative runnable against generated scaffolding and preserve the current "do this, see that" structure.

- **D-03:** The new docs must describe the default-on product posture explicitly.

  Organizations and passkeys are the default install path. Docs should treat `mix sigra.install` as the mainline and mention `--no-organizations` / `--no-passkeys` as opt-outs where relevant, not as the primary story.

### Upgrade guide posture

- **D-04:** The v1.0 -> v1.1 guide is operational, not promotional.

  It must cover:
  - prerequisite backup / branch expectations
  - both organization backfill paths
  - passkeys as new generated surface
  - exact upgrade command/test sequence
  - known no-breaking-schema assumptions only if verified in code/tests

  The guide should read like something an engineer can execute in a terminal, not marketing copy.

- **D-05:** Upgrade docs and upgrade automation stay aligned with the actual tested path.

  If the docs prescribe commands, those commands should be exercised by the existing upgrade tests or by a new focused automation path added in this phase. Do not document a "recommended" sequence that the repo never executes.

### Testing helpers

- **D-06:** Extend the generated fixture surface in the existing generated fixtures module pattern rather than fragmenting the API unnecessarily.

  The generated host app already has `auth_fixtures.ex` and imports it broadly. Phase 23 should add the org/passkey helpers there unless a second file is clearly required for readability. The important contract is the helper names and ergonomics, not multiplying files.

- **D-07:** Library-side assertions belong in `Sigra.Testing` and follow the existing narrow-helper style.

  `assert_scope_has_org/2`, `assert_membership/3`, and `assert_audit_logged_for_org/2` should be small, purpose-built assertions consistent with the existing `assert_*` helpers rather than a generic assertion DSL.

- **D-08:** The new helpers are unit/integration accelerators, not substitutes for real route coverage.

  Keep the same line the repo already uses:
  - helpers make tests shorter
  - real auth/organization/passkey gates still need route-backed tests
  - helper docs must say when they bypass real controller/LiveView/session behavior

### Browser and CI smoke

- **D-09:** Reuse the existing example-app Playwright harness and extend it with focused specs instead of building a second E2E framework.

  The canonical browser surface already lives under `test/example/priv/playwright/` and is wired into `.github/workflows/ci.yml`. Phase 23 should extend that harness with org + passkey scenarios and keep the current real-server, real-route posture from the later Phase 21 fixes.

- **D-10:** Keep browser smoke focused on a few load-bearing user journeys.

  Required journeys:
  - organization switcher happy path
  - invitation accept for new-signup path
  - invitation accept for already-authenticated user path
  - passkey registration
  - passkey authentication

  Avoid turning Phase 23 into a giant matrix of browser permutations. The goal is strong regression signal on the main cross-feature workflows.

- **D-11:** Preserve the current split between install/compile smoke and browser smoke.

  The combinatorial install matrix added in earlier phases should stay separate from the browser coverage. Playwright remains the passkey-enabled/org-enabled happy-path guard, not a replacement for generator matrix automation.

### Docs quality gate

- **D-12:** `mix docs --warnings-as-errors` remains a hard gate and the source of truth for sidebar/extras wiring.

  If new guides are added, Phase 23 must update `mix.exs` extras/grouping in the same change so docs generation stays clean and the new pages are actually shipped.

### the agent's Discretion

- Exact section titles and local ordering inside each guide, provided the existing docs voice and structure stay intact.
- Whether the new Playwright coverage extends `organizations.spec.ts` / `passkey-login.spec.ts` or introduces additional focused spec files, provided the resulting suite stays readable.
- Whether generated fixture helpers live in one file or a very small number of files, provided the public helper names and imports stay straightforward.
- Exact assertion wording and helper argument shape inside `Sigra.Testing`, provided it matches the existing helper style.

### Deferred Ideas

- Broader visual/doc UX review of the full HexDocs site beyond `mix docs --warnings-as-errors`
- Additional long-tail Playwright permutations for every org/passkey edge case
- Any redesign of the public docs taxonomy beyond the minimum needed to ship the new guides cleanly
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-01 | Generated org/passkey fixtures | Extend the existing generated `auth_fixtures.ex` pattern and keep route-backed smoke separate. [VERIFIED: codebase grep] |
| DX-02 | `Sigra.Testing` org-aware assertions | Follow the current narrow `assert_*` helper style already used in `lib/sigra/testing.ex`. [VERIFIED: codebase grep] |
| DX-03 | `getting-started.md` org + passkey continuation | Keep the existing 30-minute guide structure and expand the current DX budget/test discipline. [VERIFIED: codebase grep] |
| DX-04 | Operational v1.0 -> v1.1 upgrade guide | Mirror the exercised path in `test/upgrade_test.exs` and `test/support/install_fixture.ex`. [VERIFIED: codebase grep] |
| DX-05 | Multi-tenancy guide | Replace the pre-v1.1 "not first-class" recipe posture with the shipped org model and `for_org/2` discipline. [VERIFIED: codebase grep] |
| DX-06 | Passkeys guide | Document the shipped enrollment/primary-mode/runtime-config posture from Phases 20-22 and the RP ID/origin playbook. [VERIFIED: codebase grep] |
| DX-07 | Browser smoke for org + passkey flows | Reuse the existing Playwright job and focused specs under `test/example/priv/playwright/tests/`. [VERIFIED: codebase grep] |
| DX-08 | Docs build stays clean | `mix docs --warnings-as-errors` is already a CI gate in `library_tests`. [VERIFIED: codebase grep] |
| DX-09 | Tenant-scope enforcement spike | Repo has documented `for_org/2` discipline in `CONVENTIONS.md`, but no tenant-scope Credo check was found; planner must treat this as an explicit audit/decision item. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 23 should be planned as an in-place extension of four existing surfaces, not as new infrastructure: the HexDocs extras tree in `mix.exs`, the generated `auth_fixtures.ex` module, `Sigra.Testing`, and the example-app Playwright harness already wired into CI. [VERIFIED: codebase grep] The repo already contains an upgrade integration test (`test/upgrade_test.exs`), a docs quality gate (`mix docs --warnings-as-errors`), focused organization/passkey Playwright specs, and a guide-budget test for `getting-started.md`; the missing work is to align those surfaces with the now-shipped organizations + passkeys product posture. [VERIFIED: codebase grep]

The highest-leverage planning rule is mechanical alignment: every command in the upgrade guide should map to a path already exercised by `test/upgrade_test.exs` or a new focused automation path in this phase, and every new doc promise should be backed by either generated-host smoke, library tests, or Playwright route coverage. [VERIFIED: codebase grep] The current `guides/recipes/multi-tenant.md` still describes multi-tenancy as not first-class, which is now stale relative to shipped v1.1 organization features and `CONVENTIONS.md`'s `for_org/2` discipline. [VERIFIED: codebase grep]

The only scope area that still needs an explicit planning decision is `DX-09`: the repo documents tenant-scope discipline in `CONVENTIONS.md`, but a code search did not find a custom Credo check enforcing it. [VERIFIED: codebase grep] Plan this either as a small scoped spike during the phase or as a documented "already fell back to conventions + integration enforcement" closeout, but do not leave it implicit. [VERIFIED: codebase grep]

**Primary recommendation:** Keep all work on the existing docs/testing/CI rails, and make the upgrade guide, helper APIs, and Playwright journeys prove the same shipped behavior. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HexDocs navigation and guide publishing | Library/docs config | CI | `mix.exs` owns extras/groups while CI enforces `mix docs --warnings-as-errors`. [VERIFIED: codebase grep] |
| Getting-started and upgrade walkthroughs | Library/docs content | Generated host app | Guides document the generated scaffold, so planner should treat docs as consumer-facing explanations of generated behavior rather than library internals. [VERIFIED: codebase grep] |
| Generated org/passkey test fixtures | Generated host app templates | Example app runtime tests | The public helper surface is emitted from `priv/templates/sigra.install/core/auth_fixtures.ex`, then exercised in generated/example suites. [VERIFIED: codebase grep] |
| `Sigra.Testing` org-aware assertions | Library | Example app / library tests | Assertion helpers live in `lib/sigra/testing.ex` and are proven by library tests, not by Playwright. [VERIFIED: codebase grep] |
| Upgrade path proof | Library tmp-app harness | Docs | `test/upgrade_test.exs` and `test/support/install_fixture.ex` already own the executable upgrade contract that docs should mirror. [VERIFIED: codebase grep] |
| Browser regression coverage for org/passkey journeys | Example app Playwright harness | GitHub Actions CI | Real browser flows run against `test/example` and are invoked from `.github/workflows/ci.yml`. [VERIFIED: codebase grep] |
| Tenant-scope discipline messaging | Docs + conventions | Static analysis / tests | `CONVENTIONS.md` already defines the `for_org/2` rule; no tenant-scope Credo check was found in repo code, so planner should decide whether to add one or explicitly close on documentation + tests. [VERIFIED: codebase grep] |

## Project Constraints (from CLAUDE.md)

- Phoenix 1.8+ and Ecto 3.x remain the blessed framework path. [CITED: /Users/jon/projects/sigra/CLAUDE.md]
- PostgreSQL is the primary database and local test runs expect a live Postgres at `localhost:5432` with `postgres/postgres`. [CITED: /Users/jon/projects/sigra/CLAUDE.md]
- Security posture stays aligned with OWASP-style controls, with controller-owned login/logout mutations and no casual weakening of auth boundaries. [CITED: /Users/jon/projects/sigra/CLAUDE.md]
- Tests should stay comprehensive on happy path, main error cases, and boundary conditions, using flat self-contained AAA style. [CITED: /Users/jon/projects/sigra/CLAUDE.md]
- Repo edits should happen through the existing GSD workflow; for this phase that means planning for `/gsd-execute-phase`, not ad hoc refactors. [CITED: /Users/jon/projects/sigra/CLAUDE.md]

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExDoc | 0.40.1 (published 2026-01-31) [VERIFIED: hex.pm API] | Build HexDocs with extras/groups and warnings gate | Repo already depends on `{:ex_doc, "~> 0.40"}` and CI already treats `mix docs --warnings-as-errors` as release-gate behavior. [VERIFIED: codebase grep] |
| Phoenix + ExUnit | Phoenix 1.8.5 current release 2026-03-05; ExUnit from Elixir toolchain [VERIFIED: hex.pm API] | Library tests, example smoke, tmp-app upgrade harness | All current docs, upgrade harness, and example smoke paths are Mix/ExUnit driven; planner should not introduce another test runner for these responsibilities. [VERIFIED: codebase grep] |
| `@playwright/test` | 1.59.1 current npm release as of 2026-04-16 [VERIFIED: npm registry] | Browser regression coverage against real server routes | Existing harness, config, and CI job already use Playwright under `test/example/priv/playwright`. [VERIFIED: codebase grep] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `otplib` | 13.4.0 current npm release as of 2026-03-19 [VERIFIED: npm registry] | Playwright-side TOTP helpers | Keep only for browser/test support; do not invent browser-side auth math. [VERIFIED: codebase grep] |
| GitHub Actions `erlef/setup-beam` | v1 action pinned to SHA in workflow [VERIFIED: codebase grep] | Deterministic Elixir/OTP setup in CI | Reuse the current job pattern instead of inventing a second CI lane. [VERIFIED: codebase grep] |
| GitHub Actions `actions/setup-node` | v4 action pinned to SHA in workflow [VERIFIED: codebase grep] | Node runtime for Playwright smoke | Keep the current Node-backed Playwright job; CI currently uses Node 20 for the example Playwright lane. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing Playwright harness | Second E2E framework or separate app | Locked decision D-09 rejects this; the current harness already has WebAuthn and mailbox helpers. [VERIFIED: codebase grep] |
| Extending generated `auth_fixtures.ex` | Separate org/passkey generated fixture files | Possible only if readability genuinely breaks down; current locked posture prefers one familiar helper surface. [VERIFIED: codebase grep] |
| `Sigra.Testing` narrow assertions | Generic assertion DSL | The repo already favors small targeted helpers and has no generic assertion framework. [VERIFIED: codebase grep] |

**Installation:**
```bash
mix deps.get
cd test/example/priv/playwright
npm ci
npx playwright install --with-deps chromium
```

**Version verification:** `ex_doc` `0.40.1` was published on 2026-01-31, Phoenix `1.8.5` on 2026-03-05, and `@playwright/test` `1.59.1` is the current npm release as of 2026-04-16. [VERIFIED: hex.pm API] [VERIFIED: npm registry]

## Architecture Patterns

### System Architecture Diagram

```text
Developer/Contributor
  -> guides/*.md edits
  -> mix.exs docs extras/groups
  -> generated fixture template edits
  -> lib/sigra/testing.ex edits
  -> Playwright spec edits

Guides
  -> mix docs --warnings-as-errors
  -> HexDocs output / sidebar wiring

Upgrade guide commands
  -> test/upgrade_test.exs
  -> test/support/install_fixture.ex
  -> tmp Phoenix app
  -> mix sigra.install / mix sigra.upgrade / mix ecto.migrate

Generated fixture template
  -> generated host app
  -> example app fixture behavior
  -> ExUnit helper tests

Playwright specs
  -> example app server (MIX_ENV=dev)
  -> real routes + LiveView + mailbox + WebAuthn CDP session
  -> GitHub Actions example_playwright_smoke job
```

### Recommended Project Structure

```text
guides/
├── introduction/   # getting-started + upgrade guide
├── flows/          # existing auth flows kept intact
└── recipes/        # org/passkey operational guides per locked taxonomy

lib/
└── sigra/testing.ex # narrow library-side assertions

priv/templates/sigra.install/core/
└── auth_fixtures.ex # generated helper surface

test/
├── sigra/          # library/helper/docs tests
├── support/        # tmp-app and shared fixtures
└── example/priv/playwright/tests/ # browser smoke journeys
```

### Pattern 1: Extend the Existing Docs Taxonomy, Then Wire `mix.exs` in the Same Change
**What:** Add or move guides only through the current `extras` and `groups_for_extras` wiring in `mix.exs`. [VERIFIED: codebase grep]
**When to use:** Any Phase 23 guide addition, rename, or sidebar move. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: repo mix.exs docs config
docs: [
  extras: [
    "guides/introduction/getting-started.md",
    "guides/recipes/testing.md"
  ],
  groups_for_extras: [
    Introduction: ~r{guides/introduction/.?},
    Recipes: ~r{guides/recipes/.?}
  ]
]
```

### Pattern 2: Keep Upgrade Docs Mechanically Tied to the Tmp-App Upgrade Harness
**What:** Document only the install/upgrade/migrate/test sequence the repo can already execute or can add a focused automated proof for. [VERIFIED: codebase grep]
**When to use:** `upgrading-to-v1.1.md`, release notes, or any terminal walkthrough for v1.0 -> v1.1. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: repo test/support/install_fixture.ex + test/upgrade_test.exs
{:ok, %{app_dir: app_dir}} = InstallFixture.setup_tmp_app_without_install()
{:ok, _} = InstallFixture.run_sigra_install(app_dir, ["--no-organizations"])
{:ok, _} = InstallFixture.run_sigra_upgrade(app_dir, ["--backfill-personal-orgs"])
```

### Pattern 3: Keep Generated Helper Growth Inside `auth_fixtures.ex`
**What:** Extend the generated helper module that downstream tests already import broadly. [VERIFIED: codebase grep]
**When to use:** New org/passkey helper APIs required by DX-01. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: repo priv/templates/sigra.install/core/auth_fixtures.ex
def authenticated_fixture(attrs \\ %{}) do
  user = user_fixture(attrs)
  session = session_fixture(user)
  %{user: user, session: session, conn: log_in_user(build_conn(), user)}
end
```

### Pattern 4: Keep Browser Smoke on Real Server Responses
**What:** Use Playwright against the example app with real route responses, mailbox extraction, and Chromium virtual authenticators. [VERIFIED: codebase grep]
**When to use:** Org switcher, invitation acceptance, passkey registration, and passkey login journeys. [VERIFIED: codebase grep]
**Example:**
```ts
// Source: repo test/example/priv/playwright/tests/passkey-login.spec.ts
const client = await page.context().newCDPSession(page)
await client.send("WebAuthn.enable")
await client.send("WebAuthn.addVirtualAuthenticator", { options: { protocol: "ctap2" } })
```

### Anti-Patterns to Avoid

- **New docs taxonomy:** Locked decision D-01 says stay on `introduction/flows/recipes`, so do not create `guides/how-to/` even though the requirement prose says "how-to". [VERIFIED: codebase grep]
- **Unexercised upgrade prose:** If the guide recommends a command sequence that no test runs, the docs will drift first and fail last. [VERIFIED: codebase grep]
- **Fixture abstraction split for its own sake:** A second generated fixture module is only justified if `auth_fixtures.ex` becomes unreadable. [VERIFIED: codebase grep]
- **Browser matrix explosion:** The install matrix and browser smoke are intentionally separate concerns in current CI. [VERIFIED: codebase grep]
- **Treating `DX-09` as done without checking:** `CONVENTIONS.md` exists, but no tenant-scope Credo check was found. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser E2E framework | Second bespoke browser harness | Existing Playwright setup under `test/example/priv/playwright` | It already covers LiveView readiness, mailbox parsing, and virtual WebAuthn devices. [VERIFIED: codebase grep] |
| Upgrade proof harness | Ad hoc shell script docs validation | `test/upgrade_test.exs` + `InstallFixture` tmp-app flow | Existing harness already proves install/upgrade/migrate semantics in real Phoenix apps. [VERIFIED: codebase grep] |
| Org assertion DSL | Generic matcher framework | Small `Sigra.Testing.assert_*` helpers | Current repo style is narrow helpers with clear failure messages. [VERIFIED: codebase grep] |
| Passkey ceremony simulation in docs/tests | Fake browser success responses | Existing controller/route-backed Playwright and example fixtures | Locked decisions from prior phases explicitly favor real route behavior over interception shortcuts. [VERIFIED: codebase grep] |
| Multi-tenant doctrine from scratch | New tenancy model explainer detached from shipped code | `for_org/2` + `CONVENTIONS.md` + current org library surfaces | The old recipe is stale; the new guide should teach the shipped logical-org model, not invent another one. [VERIFIED: codebase grep] |

**Key insight:** Most Phase 23 risk comes from drift between docs, generated templates, and CI, so reuse the repo's existing executable seams instead of inventing new ones. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Updating Guides Without Updating `mix.exs` Extras
**What goes wrong:** The guide file exists in git but is missing from the published docs sidebar or breaks `mix docs --warnings-as-errors`. [VERIFIED: codebase grep]
**Why it happens:** HexDocs publication is explicitly wired through `mix.exs` extras/groups. [VERIFIED: codebase grep]
**How to avoid:** Treat guide file changes and `mix.exs` docs config changes as one task. [VERIFIED: codebase grep]
**Warning signs:** CI fails only on the docs step or the new page is not in the generated sidebar. [VERIFIED: codebase grep]

### Pitfall 2: Letting the Upgrade Guide Outrun the Upgrade Tests
**What goes wrong:** Docs describe a "recommended" branch/command/test sequence that the repo never executes. [VERIFIED: codebase grep]
**Why it happens:** Upgrade prose is easy to edit independently from tmp-app tests. [VERIFIED: codebase grep]
**How to avoid:** Base the guide on `test/upgrade_test.exs` and add focused automation for any extra step the guide requires. [VERIFIED: codebase grep]
**Warning signs:** Guide includes commands or flags that are absent from upgrade tests and `InstallFixture`. [VERIFIED: codebase grep]

### Pitfall 3: Rewriting the Old Multi-Tenant Recipe Incrementally Instead of Reframing It
**What goes wrong:** The docs keep contradictory messages such as "Sigra does not ship multi-tenancy as a first-class feature" after organizations are already shipped. [VERIFIED: codebase grep]
**Why it happens:** `guides/recipes/multi-tenant.md` predates the v1.1 org implementation and still documents row/schema tenancy models generically. [VERIFIED: codebase grep]
**How to avoid:** Replace the guide posture around the shipped logical-org model and `for_org/2` discipline, then explain schema-per-tenant as rejected/out-of-scope. [VERIFIED: codebase grep]
**Warning signs:** The guide still talks about "future Sigra release" for org membership. [VERIFIED: codebase grep]

### Pitfall 4: Over-abstracting Fixture Helpers
**What goes wrong:** Helper APIs become harder to read than the tests they were supposed to shorten. [VERIFIED: codebase grep]
**Why it happens:** Phase 23 adds cross-cutting org + passkey cases, which tempts a generic fixture DSL. [VERIFIED: codebase grep]
**How to avoid:** Follow D-06/D-07 and add purpose-built helpers with route-backed tests still covering true auth boundaries. [VERIFIED: codebase grep]
**Warning signs:** New helpers require callers to pass large option maps or fake session internals directly. [VERIFIED: codebase grep]

### Pitfall 5: Expanding Browser Smoke Into a Feature Matrix
**What goes wrong:** CI gets slower and flakier without improving regression signal. [VERIFIED: codebase grep]
**Why it happens:** Organizations and passkeys each have many edge paths, but current CI already separates install matrix coverage from browser journeys. [VERIFIED: codebase grep]
**How to avoid:** Keep Playwright to the required load-bearing flows and leave combinatorial install coverage to the existing install matrix. [VERIFIED: codebase grep]
**Warning signs:** New Playwright plans start duplicating install combinations or add route-fulfillment shortcuts. [VERIFIED: codebase grep]

### Pitfall 6: Assuming `DX-09` Is Already Closed
**What goes wrong:** Phase closes without a recorded answer on whether the tenant-scope Credo spike shipped or intentionally fell back to conventions/tests. [VERIFIED: codebase grep]
**Why it happens:** `CONVENTIONS.md` exists, which can mask the absence of a corresponding custom Credo check. [VERIFIED: codebase grep]
**How to avoid:** Make `DX-09` a deliberate plan item with a success/fallback criterion. [VERIFIED: codebase grep]
**Warning signs:** There is no code change or explicit note addressing the Credo-spike decision. [VERIFIED: codebase grep]

## Code Examples

Verified repo patterns to copy:

### Docs Gate in CI
```yaml
# Source: repo .github/workflows/ci.yml
- name: Check docs build cleanly
  run: mix docs --warnings-as-errors
```

### Generated Fixture Style
```elixir
# Source: repo priv/templates/sigra.install/core/auth_fixtures.ex
def authenticated_fixture(attrs \\ %{}) do
  user = user_fixture(attrs)
  session = session_fixture(user)
  %{user: user, session: session, conn: log_in_user(build_conn(), user)}
end
```

### Playwright Virtual Authenticator Pattern
```ts
// Source: repo test/example/priv/playwright/tests/passkey-login.spec.ts
const client = await page.context().newCDPSession(page)
await client.send("WebAuthn.enable")
await client.send("WebAuthn.addVirtualAuthenticator", {
  options: { protocol: "ctap2", transport: "internal" }
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual docs walkthrough trust | Structural docs verification plus CI docs build | Already present before Phase 23 via `guides_dx02_test.exs` and CI docs step. [VERIFIED: codebase grep] | Planner should extend existing docs-proof tests instead of adding only prose. [VERIFIED: codebase grep] |
| Generic "Sigra does not ship multi-tenancy first-class" recipe | Shipped organizations model with `for_org/2` discipline and active-org session loading | v1.1 org phases 12-18 plus current `CONVENTIONS.md`. [VERIFIED: codebase grep] | Multi-tenancy docs now need reframing, not minor edits. [VERIFIED: codebase grep] |
| Browser smoke centered on golden path only | Browser smoke already includes org and passkey-focused specs in the existing harness | Phases 16, 20, and 21 added these spec files and CI job wiring. [VERIFIED: codebase grep] | Phase 23 should consolidate/finish required journeys, not bootstrap browser automation. [VERIFIED: codebase grep] |
| Upgrade prose as a likely manual release note | Tmp-app upgrade integration harness with backfill-on/backfill-off proof | Phase 18 created `test/upgrade_test.exs`. [VERIFIED: codebase grep] | Upgrade guide can be operational and test-backed now. [VERIFIED: codebase grep] |

**Deprecated/outdated:**
- The current `guides/recipes/multi-tenant.md` posture is outdated for v1.1 because it says multi-tenancy is not first-class and still teaches row/schema tenancy generically. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | All substantial claims in this research were verified from the codebase, local environment, package registries, or official docs. [VERIFIED: codebase grep] | — | — |

## Open Questions (RESOLVED)

1. **DX-09 disposition**
   - Resolution: Phase 23 will treat DX-09 as an explicit spike-or-fallback deliverable, not an implicit omission. Plan `23-04` owns the decision and requires an automated proof for either branch: ship a narrow custom Credo rule if it stays within the locked 300-line budget, otherwise record the fallback to conventions plus integration enforcement in `CONVENTIONS.md`.

2. **`guides/recipes/multi-tenant.md` handling**
   - Resolution: Rewrite the existing file in place. Locked decision D-01 keeps the current HexDocs taxonomy, and the current path is still semantically correct once the stale pre-v1.1 posture is replaced with the shipped logical multi-tenancy model and `for_org/2` discipline.

3. **Docs follow-along smoke**
   - Resolution: No separate docs-followalong harness is required at planning time. The phase will rely on the existing guide regression checks, upgrade automation, and example-app/browser flows. A new executable smoke is only justified if implementation introduces a command path not already covered by those existing rails.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | docs build, library tests, upgrade harness | ✓ [VERIFIED: local command] | Elixir 1.19.5 / Mix 1.19.5 [VERIFIED: local command] | none |
| Node / npm / npx | Playwright smoke | ✓ [VERIFIED: local command] | Node 22.14.0 / npm 11.1.0 / npx 11.1.0 [VERIFIED: local command] | none |
| Playwright CLI global install | Local convenience only | ✗ [VERIFIED: local command] | — | use `npm ci && npx playwright ...` in `test/example/priv/playwright`. [VERIFIED: codebase grep] |
| Docker | local Postgres bootstrap from CLAUDE instructions | ✓ [VERIFIED: local command] | 29.3.1 [VERIFIED: local command] | use any existing local Postgres on `localhost:5432`. [CITED: /Users/jon/projects/sigra/CLAUDE.md] |
| PostgreSQL client tools | local/CI DB checks | ✓ [VERIFIED: local command] | `psql` 14.17 and `pg_isready` present [VERIFIED: local command] | none |

**Missing dependencies with no fallback:**
- None found for planning. [VERIFIED: local command]

**Missing dependencies with fallback:**
- Global Playwright CLI is missing locally, but the repo already uses local `npx playwright` invocations. [VERIFIED: local command] [VERIFIED: codebase grep]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit for library/example tests plus Playwright for browser smoke. [VERIFIED: codebase grep] |
| Config file | No top-level custom ExUnit config file detected; Playwright config is `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/sigra/upgrade_test.exs` or targeted helper tests for the touched module. [VERIFIED: codebase grep] |
| Full suite command | `mix test` plus `cd test/example/priv/playwright && npx playwright test` for browser coverage. [VERIFIED: codebase grep] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-01 | Generated org/passkey helpers exist and behave | template + example integration | `mix test test/example/test/example/fixtures_test.exs` plus new generated-helper tests | ❌ Wave 0 |
| DX-02 | `Sigra.Testing` org assertions behave | unit | `mix test test/sigra/testing* test/sigra/behaviours_test.exs` plus new focused assertion tests | ❌ Wave 0 |
| DX-03 | `getting-started.md` stays structurally sound and time-bounded | docs verification | `mix test test/sigra/guides_dx02_test.exs` | ✅ |
| DX-04 | Upgrade guide matches executable upgrade path | tmp-app integration | `mix test test/upgrade_test.exs` | ✅ |
| DX-05 | Multi-tenancy guide matches shipped org model | docs verification | add focused guide-content regression test or extend `guides_dx02_test.exs` | ❌ Wave 0 |
| DX-06 | Passkeys guide reflects shipped config/runtime posture | docs verification | add focused guide-content regression test | ❌ Wave 0 |
| DX-07 | Org switcher, invite accept, passkey register, passkey auth all regress in browser | browser smoke | `cd test/example/priv/playwright && npx playwright test` | ✅ partial |
| DX-08 | Docs build remains clean | docs build | `mix docs --warnings-as-errors` | ✅ |
| DX-09 | Tenant-scope enforcement decision is explicit | unit/docs/spike | targeted Credo/convention check task if chosen | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** targeted ExUnit file plus `mix docs --warnings-as-errors` when docs config changes. [VERIFIED: codebase grep]
- **Per wave merge:** `mix test` and, for browser-work waves, `cd test/example/priv/playwright && npx playwright test`. [VERIFIED: codebase grep]
- **Phase gate:** full suite green plus Playwright smoke green before `/gsd-verify-work`. [VERIFIED: codebase grep]

### Wave 0 Gaps

- [ ] Add focused tests for the new generated org/passkey fixture helpers required by DX-01. [VERIFIED: codebase grep]
- [ ] Add focused tests for `assert_scope_has_org/2` and `assert_membership/3`; current repo already has `assert_audit_logged` coverage but not the org-helper names required by DX-02. [VERIFIED: codebase grep]
- [ ] Add guide regression checks for the new upgrade, passkeys, and multi-tenancy pages or extend the existing guide test. [VERIFIED: codebase grep]
- [ ] Confirm whether DX-09 needs a custom Credo spike or only an explicit documented fallback note. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: codebase grep] | Passkey/login docs and smoke must preserve controller-owned auth completion and fallback guidance from current passkey flows. [VERIFIED: codebase grep] |
| V3 Session Management | yes [VERIFIED: codebase grep] | Example/browser coverage should keep exercising real session creation/rotation boundaries rather than fake callbacks. [VERIFIED: codebase grep] |
| V4 Access Control | yes [VERIFIED: codebase grep] | Multi-tenancy docs must teach `for_org/2` and org-scoped discipline consistent with `CONVENTIONS.md`. [VERIFIED: codebase grep] |
| V5 Input Validation | yes [VERIFIED: codebase grep] | Upgrade docs must document only validated, exercised command paths; helper APIs should stay narrow and explicit. [VERIFIED: codebase grep] |
| V6 Cryptography | yes [VERIFIED: codebase grep] | Passkeys guide must document RP ID/origin/runtime-config posture and recovery without inventing new crypto behavior. [VERIFIED: codebase grep] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant data leakage | Information Disclosure | Keep `for_org/2` discipline explicit in docs/tests and, if chosen, add the Credo spike for defense-in-depth. [VERIFIED: codebase grep] |
| Session/auth boundary bypass in browser tests | Elevation of Privilege | Use real controller routes and real responses, not Playwright fulfillment shortcuts. [VERIFIED: codebase grep] |
| Upgrade drift causing unsafe operator steps | Tampering | Tie guide commands to the tmp-app upgrade harness and executable tests. [VERIFIED: codebase grep] |
| Passkey recovery lockout from bad docs | Denial of Service | Keep recovery and fallback guidance explicit in the passkeys guide, matching shipped passkey-primary posture. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- Repo codebase scans of `mix.exs`, `guides/**`, `lib/sigra/testing.ex`, `priv/templates/sigra.install/core/auth_fixtures.ex`, `test/upgrade_test.exs`, `test/support/install_fixture.ex`, `test/example/priv/playwright/**`, `.github/workflows/ci.yml`, and `CONVENTIONS.md`. [VERIFIED: codebase grep]
- Hex package API for ExDoc `0.40.1` and Phoenix `1.8.5`. [VERIFIED: hex.pm API]
- npm registry for `@playwright/test` `1.59.1` and `otplib` `13.4.0`. [VERIFIED: npm registry]

### Secondary (MEDIUM confidence)

- Playwright CI guidance on retries and CI execution. [CITED: https://playwright.dev/docs/ci]
- Playwright retries behavior reference. [CITED: https://playwright.dev/docs/test-retries]
- ExDoc README / docs landing page for current docs tooling context. [CITED: https://hexdocs.pm/ex_doc/readme.html]

### Tertiary (LOW confidence)

- None. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions were verified against registries and the repo already uses this stack. [VERIFIED: hex.pm API] [VERIFIED: npm registry] [VERIFIED: codebase grep]
- Architecture: HIGH - all recommended patterns are already present in code, workflow, or locked phase context. [VERIFIED: codebase grep]
- Pitfalls: HIGH - each pitfall is grounded in current repo structure or explicit stale docs/tests surfaces. [VERIFIED: codebase grep]

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 for codebase findings; re-check npm/hex package versions if planning slips past that date. [VERIFIED: npm registry] [VERIFIED: hex.pm API]
