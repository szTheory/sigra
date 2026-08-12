# Phase 237: Canonical B2C Generator Contract - Research

**Researched:** 2026-08-04  
**Domain:** Phoenix fresh-host generator contract and deterministic smoke verification  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** The canonical command is `mix sigra.install Accounts User users --no-admin --no-organizations --no-passkeys --yes`; it retains the installer’s standard email/password and magic-link experience.
- **D-02:** Add the required direct `cloak_ecto` dependency, then run `mix sigra.gen.oauth --providers google`; prove generated identity, encrypted vault, OAuth controller/routes/templates, provider configuration injection, and OAuth migration artifacts.
- **D-03:** Prove B2C-03 from the generated application—not only flags—by checking routes, files, dependencies/assets, and configuration for the absence of admin, organization, and passkey residue.
- **D-04:** The acceptance smoke scaffolds an assets-enabled Phoenix app, installs the profile, generates Google OAuth, builds assets, compiles with warnings as errors, creates/migrates Postgres, and proves a root HTTP response. It uses no provider or email credentials and does not add browser-runtime coverage.

### the agent's Discretion
- Extend the existing fresh-host script and install-contract tests in the smallest repo-consistent way, choosing precise stable absence assertions that cover the optional features’ actual ownership surfaces.
- Keep the local path dependency, dummy non-secret `CLOAK_KEY`, isolated temporary app/database handling, and bounded boot probe patterns already used by the repository.

### Deferred Ideas (OUT OF SCOPE)
None — analysis stayed within phase scope.

### Reviewed Todos (not folded)
- “Harden app.css corruption guard against mid-block orphan values” — unrelated CSS integrity work.
- Phase 234 PR/evidence follow-ups — CI evidence closeout, not B2C generator behavior.
- Schema-helper and runtime auth-prefix override — separate installer/config capabilities.
- Remaining low-score CI, release, security, and admin-UI todo matches — keyword-only matches with no Phase 237 scope connection.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM system, Rail Accent assets, and Light/Dark/System support only if this phase touches admin UI; it should not. [VERIFIED: AGENTS.md]
- Any Playwright/admin UI test must use deterministic role selectors, stable hooks, LiveView readiness, and no sleeps; Phase 237 deliberately adds no browser coverage. [VERIFIED: AGENTS.md]
- Use deterministic automation and durable machine-readable evidence; retry a transient automated failure once, and do not waive missing proof. [VERIFIED: AGENTS.md]
- Follow the repository’s one-watcher/rate-limit rules only if CI is dispatched; this phase’s local verification does not require GitHub polling. [VERIFIED: AGENTS.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| B2C-01 | Fresh Phoenix app installs the opted-out profile, migrates, builds assets, compiles warning-free, and boots. | Existing assets-enabled `passkeys-opt-out-smoke.sh` already performs the lifecycle; retain its isolated app, Postgres, free-port, and bounded curl probe. [VERIFIED: repository code] |
| B2C-02 | That app generates Google OAuth with routes, controller, identity, vault, and migration artifacts. | Add explicit post-generator checks for every generated ownership surface rather than relying on only a router marker. [VERIFIED: `lib/mix/tasks/sigra.gen.oauth.ex`] |
| B2C-03 | The profile has no admin, organization, or passkey routes/assets/configuration. | Expand the existing B2C leg’s absence contract across each optional feature’s files, migrations, markers/routes, assets/dependencies, and config. [VERIFIED: feature modules and current opt-out test] |
</phase_requirements>

## Summary

Phase 237 is a contract-tightening phase, not a generator redesign. The canonical B2C leg already exists in `scripts/ci/passkeys-opt-out-smoke.sh`: it creates an assets-enabled Postgres Phoenix host, inserts the local Sigra path dependency, invokes the exact opt-out command, adds `cloak_ecto`, invokes Google OAuth generation, builds, migrates, and boots via a free local port. [VERIFIED: `scripts/ci/passkeys-opt-out-smoke.sh`]

The gap is proof precision. The script currently checks passkey absence comprehensively, but the B2C-only admin and organization checks are mostly router strings plus one file each. The fixture-backed `generator_passkeys_opt_out_test.exs` similarly proves broad passkey residue and only a thin admin/organization surface. The plan should extend those two existing artifacts with stable, feature-owned sentinels, not add a second generator harness. [VERIFIED: current smoke and test]

**Primary recommendation:** Extend the existing B2C smoke leg and its fixture contract test with explicit OAuth-positive and feature-ownership-negative assertions; retain the established full fresh-host lifecycle unchanged.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Generate canonical B2C source tree | Build tooling / generator | Filesystem | `mix sigra.install` conditionally activates isolated install features and writes host-owned artifacts. [VERIFIED: `Sigra.Install.Runner` and install task] |
| Generate Google OAuth support | Build tooling / generator | Host configuration | `mix sigra.gen.oauth` writes identity/vault/controller/templates/migration and injects routes, config, and supervision. [VERIFIED: OAuth task] |
| Compile, build assets, and migrate fresh host | Build tooling | Database | The smoke’s `mix compile`, `mix assets.deploy`, and Ecto lifecycle prove the emitted application can be built and migrated. [VERIFIED: smoke script] |
| Root HTTP boot proof | Phoenix server | Browser/client only as HTTP consumer | The bounded `curl` probe proves server startup without claiming browser or OAuth callback behavior. [VERIFIED: smoke script] |
| Optional-feature absence | Generated filesystem/configuration | Router/assets | The feature modules own files, migrations, injections, and asset/dependency additions; assertions must inspect their emitted surfaces. [VERIFIED: optional feature modules] |

## Standard Stack

### Core

| Library/tool | Version | Purpose | Why standard |
|---|---:|---|---|
| Phoenix / `phx_new` | CI pins `1.8.8`; installed project lock is `1.8.7` | Scaffold an assets-enabled PostgreSQL host | Phoenix documents `--database postgres`, `--no-dashboard`, and `--no-install`; the CI lane pins the archive to control scaffold drift. [CITED: https://phoenix.hexdocs.pm/Mix.Tasks.Phx.New.html] [VERIFIED: `.github/workflows/ci.yml`] |
| Sigra installer and OAuth generator | in-tree local path dependency | Emit the B2C application contract | This phase must test the checkout under change rather than a released package. [VERIFIED: smoke script] |
| `cloak_ecto` | `~> 1.3` (Hex 1.3.0, released 2024-04-06) | Required encrypted Ecto field support for generated OAuth identities | The OAuth generator fails before generation when the dependency is absent and instructs this exact dependency. [CITED: https://hex.pm/packages/cloak_ecto] [VERIFIED: OAuth task] |
| PostgreSQL | CI service; local probe unavailable | Generated-host migrations | The canonical smoke is deliberately PostgreSQL-backed and runs `ecto.create`/`ecto.migrate`. [VERIFIED: smoke script and CI workflow] |

### Supporting

| Tool | Purpose | When to use |
|---|---|---|
| `scripts/ci/lib/free-port.sh` | Allocates an ephemeral loopback port | Use for the boot proof; do not bind a fixed port. [VERIFIED: repository source] |
| `curl -sf` | Makes the root readiness assertion | Use inside the existing 30-attempt bounded probe. [VERIFIED: smoke script] |
| `rg` | Tests deterministic absence of feature routes/config/dependencies | Use only against explicit known files/patterns, then emit diagnostic matches on failure. [VERIFIED: smoke script] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Extend current smoke | New dedicated B2C shell script | Duplicates fragile Phoenix scaffold, path-dependency, DB, and boot code without stronger evidence. [VERIFIED: current script already owns this lifecycle] |
| Fixture contract extension | Only inspect feature modules statically | Static ownership tests cannot prove an actual fresh host omits the generated residue. [VERIFIED: requirement B2C-03 and current fixture pattern] |
| Bounded root probe | Browser/OAuth callback test | Browser and provider-callback behavior are explicitly Phase 238 and staging scope, respectively. [VERIFIED: CONTEXT.md] |

**Installation in generated host:**

```bash
# Preserve the existing scripted mix.exs insertion, then:
mix deps.get
MIX_ENV=dev mix sigra.gen.oauth --providers google
```

## Package Legitimacy Audit

| Package | Registry | Age/download signal | Source Repo | Verdict | Disposition |
|---|---|---|---|---|---|
| `cloak_ecto` | Hex | 1.3.0 released 2024-04-06; 53,223 downloads in the latest seven-day registry window | `github.com/danielberkompas/cloak_ecto` | Cited official package | Approved for the generated host. [CITED: https://hex.pm/packages/cloak_ecto] |

**Gate note:** the supplied package-legitimacy seam accepts only npm, PyPI, and crates, so it cannot produce an `OK`/`SUS`/`SLOP` verdict for Hex. The package was instead confirmed in the official Hex registry and is a locked generator prerequisite; do not introduce another package. [VERIFIED: package-legitimacy command usage and OAuth task]

**Packages removed due to [SLOP] verdict:** none.  
**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```text
mix phx.new (assets + PostgreSQL, isolated tmp app)
  -> patch generated mix.exs with local :sigra path dependency
  -> mix deps.get
  -> mix sigra.install Accounts User users --no-admin --no-organizations --no-passkeys --yes
  -> absence assertions (passkeys + organizations + admin)
  -> add direct :cloak_ecto host dependency -> mix deps.get
  -> mix sigra.gen.oauth --providers google
  -> OAuth artifact and injection assertions
  -> mix compile --warnings-as-errors -> mix assets.deploy
  -> mix ecto.drop/create/migrate (PostgreSQL)
  -> PHX_SERVER=true mix phx.server on free port -> curl / -> success/failure diagnostics
```

### Recommended Project Structure

```text
scripts/ci/passkeys-opt-out-smoke.sh                  # authoritative fresh-host B2C lifecycle
scripts/ci/lib/free-port.sh                            # shared ephemeral port allocation
test/sigra/install/generator_passkeys_opt_out_test.exs # fast fixture-backed contract coverage
lib/sigra/install/features/{admin,organizations,passkeys}.ex
lib/mix/tasks/sigra.gen.oauth.ex                       # asserted generator ownership
```

### Pattern 1: Feature-owned negative contract

**What:** Choose absence assertions from artifacts owned directly by each disabled feature: route marker/path, representative generated file, migration basename, dependency/asset/config marker where the feature owns one. [VERIFIED: feature modules]

**When to use:** Apply only to the B2C case, after the canonical installer invocation and before OAuth generation. Keep shared no-passkeys legs focused on passkeys. [VERIFIED: existing test matrix]

**Recommended stable assertion set:**

| Feature | Routes/marker | Files/migration | Assets/dependencies/config |
|---|---|---|---|
| Passkeys | `# Sigra passkeys`; three passkey route paths | `user_passkey.ex`, `*_create_user_passkeys.exs` | passkey JS, `@simplewebauthn/browser`, `{:wax_, "~> 0.7"}`, `passkeys:` config. [VERIFIED: passkeys feature and current test] |
| Organizations | `# Sigra organizations` and `/organizations` | `accounts/organization.ex`, `organizations.ex`, `*_create_organizations.exs` | assert the organization marker/routes and representative owned files/migrations; this feature adds no standalone JS dependency/config injection. [VERIFIED: organizations feature] |
| Admin | `# Sigra admin` and `/admin` | `admin_shell.ex`, `sigra_admin_access.ex`, `*_create_platform_admin_grants.exs` | `priv/static/assets/sigra_admin.css` and `priv/static/images/sigra-logo-primary.svg`; no feature-specific dependency/config injection exists. [VERIFIED: admin feature] |

### Pattern 2: Positive OAuth emission contract

**What:** After `mix sigra.gen.oauth --providers google`, verify host-owned generated artifacts and injections rather than checking only a comment marker. [VERIFIED: OAuth task]

**Required positive surfaces:**

- `lib/<app>/accounts/user_identity.ex`, `lib/<app>/vault.ex`, and `lib/<app>/encrypted/binary.ex`. [VERIFIED: OAuth task]
- `lib/<app>_web/controllers/oauth_controller.ex`, `oauth_html.ex`, and `oauth_buttons.html.heex`. [VERIFIED: OAuth task]
- `priv/repo/migrations/*_create_user_identities.exs`. [VERIFIED: OAuth task]
- Router contains `# Sigra OAuth` and Google request/callback routes; `config/config.exs` contains the Sigra OAuth providers stanza and `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` references. [VERIFIED: OAuth task]
- `lib/<app>/application.ex` contains the generated vault supervision injection. [VERIFIED: OAuth task]

### Anti-Patterns to Avoid

- **Flag-only proof:** do not treat `--no-*` appearing in a command as B2C-03 evidence; inspect the generated host. [VERIFIED: B2C-03]
- **Whole-tree generic string bans for `admin`/`organization`:** the core feature can legitimately contain generic vocabulary and organizational comments; assert feature-owned paths and markers to avoid false failures. [VERIFIED: feature ownership boundaries]
- **Real Google credentials/callbacks:** do not add secrets, provider calls, email delivery, or browser tests to this phase. [VERIFIED: CONTEXT.md]
- **Fixed port or unbounded server wait:** preserve free-port allocation, log capture, cleanup, and the existing 30-second bounded readiness loop. [VERIFIED: smoke and free-port helper]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Fresh Phoenix host lifecycle | A new custom Elixir harness | Existing `passkeys-opt-out-smoke.sh` | It already handles path dependency patching, PostgreSQL lifecycle, cleanup, assets, and server readiness. [VERIFIED: smoke script] |
| Test host setup | A separate app fixture | `Sigra.Test.InstallFixture` | Existing fixture creates isolated temporary hosts and offers installer/compile helpers. [VERIFIED: `test/support/install_fixture.ex`] |
| Port selection | Static port or sleep-only readiness | `find_free_port` plus bounded curl retry | Avoids cross-run collisions while preserving actionable server-log diagnostics. [VERIFIED: helper and smoke script] |
| OAuth encryption | Custom token field crypto | Generated Cloak vault and `Cloak.Ecto.Binary` | The generator requires `cloak_ecto` and emits its vault/encrypted type contract. [VERIFIED: OAuth task and templates] |

**Key insight:** this phase proves the composition of existing generator features; its durable value is deterministic generated-host evidence, not a new abstraction. [VERIFIED: CONTEXT.md and repository patterns]

## Common Pitfalls

### Pitfall 1: B2C checks only routes

**What goes wrong:** admin and organizations may leave migrations, files, static assets, or injections even if route strings are absent. [VERIFIED: admin and organizations feature ownership]

**How to avoid:** assert the feature-owned sentinel matrix above in both the fixture test and B2C smoke leg. Keep assertions specific to real ownership surfaces. [VERIFIED: feature modules]

### Pitfall 2: OAuth positive proof is too shallow

**What goes wrong:** a `# Sigra OAuth` router marker can exist while a generated vault, identity migration, provider config, or template is missing. [VERIFIED: OAuth generator writes all of these independently]

**How to avoid:** assert every required artifact and each injection target immediately after generation, then compile and migrate the same host. [VERIFIED: OAuth task]

### Pitfall 3: Fresh-host scaffold drift

**What goes wrong:** changing Phoenix output can invalidate the script’s `mix.exs` insertion anchor or asset assumptions. [VERIFIED: smoke script anchors a literal `{:phoenix,` line; CI pins `phx_new`]

**How to avoid:** preserve the current CI archive pin and anchor failure diagnostic; do not replace it with an unverified broad text rewrite. [VERIFIED: CI workflow and smoke script]

### Pitfall 4: Local false confidence from missing PostgreSQL

**What goes wrong:** compile-only verification cannot prove `ecto.create`, migration, or boot. The local availability audit found no PostgreSQL response at the configured local endpoint. [VERIFIED: `pg_isready` probe]

**How to avoid:** run the full smoke in the CI service environment or start the documented local database before using its result as B2C-01 evidence. [VERIFIED: CI workflow and smoke script]

## Code Examples

### Canonical execution order

```bash
MIX_ENV=dev mix sigra.install Accounts User users --no-admin --no-organizations --no-passkeys --yes
# Insert {:cloak_ecto, "~> 1.3"} as a direct generated-host dependency.
mix deps.get
MIX_ENV=dev mix sigra.gen.oauth --providers google
MIX_ENV=dev mix compile --warnings-as-errors
MIX_ENV=dev mix assets.deploy
MIX_ENV=dev mix ecto.create
MIX_ENV=dev mix ecto.migrate
```

Source: [VERIFIED: locked CONTEXT.md and current smoke script].

### Deterministic validation commands

```bash
# Fast fixture contract (scaffolds temporary Phoenix hosts; tagged :scaffold)
MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs

# Full assets-enabled, PostgreSQL fresh-host contract
GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh
```

Source: [VERIFIED: test module, smoke script, and `mix.exs` alias].

## State of the Art

| Old Approach | Current Approach | Impact |
|---|---|---|
| Optional features were often validated by option presence or one route check | Feature modules now expose separate file/migration/injection ownership and the repository has generated-host smoke infrastructure | Use ownership-surface assertions to detect partial opt-out residue. [VERIFIED: feature modules and current smoke] |
| Fixture hosts omit assets for speed | The acceptance smoke intentionally keeps assets enabled | B2C-01’s asset build must stay in the shell smoke; fixture coverage complements rather than replaces it. [VERIFIED: fixture and smoke script] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No additional package is required beyond the locked generated-host `cloak_ecto` dependency. | Package Legitimacy Audit | A newly discovered generator prerequisite would need its own provenance and host installation proof. |

## Open Questions (RESOLVED)

1. **Which exact B2C assertions are currently missing?**
   - What we know: the source shows incomplete admin/organization negative coverage and shallow OAuth-positive coverage. [VERIFIED: current smoke/test]
   - **RESOLVED:** Use the feature-owned sentinel matrix in both existing artifacts to close the assertion gap; no product decision is outstanding.

2. **Can the full smoke run locally now?**
   - What we know: PostgreSQL did not respond at the configured local endpoint. [VERIFIED: `pg_isready` probe]
   - **RESOLVED:** When local PostgreSQL is unavailable, require CI PostgreSQL smoke evidence from the exact implementation commit; do not weaken the migration/boot gate.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir / Mix | generator, tests, smoke | ✓ | Elixir 1.19.5 / OTP 28 | — [VERIFIED: local probe] |
| `phx_new` archive | fresh Phoenix scaffold | ✓ | local help available; CI pins 1.8.8 | CI archive install is authoritative. [VERIFIED: local `mix help phx.new`, CI workflow] |
| Node/npm | assets build | ✓ | Node 22.14.0 / npm 11.1.0 | — [VERIFIED: local probe] |
| PostgreSQL | migration and boot proof | ✗ locally | `pg_isready` reported no response | CI PostgreSQL service. [VERIFIED: local probe and CI workflow] |
| Docker | optional local database support | ✓ | 29.5.2 | Use only if project-local DB instructions authorize it. [VERIFIED: local probe] |
| curl | root HTTP probe | ✓ | 8.7.1 | — [VERIFIED: local probe] |

**Missing dependencies with no fallback:** none; CI provides PostgreSQL.  
**Missing dependencies with fallback:** local PostgreSQL; use CI service rather than claiming a local full-smoke pass.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (project-native) [VERIFIED: `test/test_helper.exs` and test module] |
| Config file | `test/test_helper.exs` [VERIFIED: repository tree] |
| Quick run command | `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs` [VERIFIED: target module] |
| Full phase command | `GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` with PostgreSQL available [VERIFIED: smoke script] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| B2C-01 | assets-enabled host installs, compiles warning-free, builds assets, migrates, boots | integration/smoke | `GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` | ✅ extend existing |
| B2C-02 | Google OAuth generated files/routes/config/vault/migration exist | fixture contract + smoke | target ExUnit command plus full smoke | ✅ extend existing |
| B2C-03 | no admin/org/passkey routes, files, migrations, assets/deps/config | fixture contract + smoke | target ExUnit command plus full smoke | ✅ extend existing |

### Sampling Rate

- **Per task commit:** `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs`
- **Per wave merge:** run the full `scripts/ci/passkeys-opt-out-smoke.sh` when PostgreSQL is available.
- **Phase gate:** full smoke passes with its migrated host answering root HTTP.

### Wave 0 Gaps

None — extend the existing fixture contract and existing full smoke; no new framework, config, or test file is needed. [VERIFIED: repository test infrastructure]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | yes | Generated email/password, magic-link, and OAuth source is compiled and booted; callback behavior is Phase 238. [VERIFIED: CONTEXT.md] |
| V3 Session Management | yes | Root boot only; do not claim session-flow proof in this phase. [VERIFIED: phase boundary] |
| V4 Access Control | yes | B2C profile omits generated admin and organization entry points/artifacts. [VERIFIED: B2C-03] |
| V5 Input Validation | no new input surface | Generator options are fixed literals in the smoke and validated by existing task parsing. [VERIFIED: install task and smoke] |
| V6 Cryptography | yes | Generated `Cloak.Vault` obtains its key from `CLOAK_KEY`; smoke uses an existing dummy non-secret key only to boot. [VERIFIED: OAuth vault template and CONTEXT.md] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| OAuth tokens written unencrypted | Information disclosure | Require `cloak_ecto`; generate vault/encrypted type and compile the host. [VERIFIED: OAuth task/templates] |
| Optional privileged/multi-tenant surface accidentally emitted | Elevation of privilege | Assert admin and organization feature-owned routes/files/migrations/assets are absent from the generated B2C host. [VERIFIED: B2C-03 and feature modules] |
| Secrets leaked by automation | Information disclosure | Do not provide Google/email credentials; retain dummy `CLOAK_KEY` and do not print secrets. [VERIFIED: CONTEXT.md and smoke script] |

## Sources

### Primary (HIGH confidence)

- Repository source: `scripts/ci/passkeys-opt-out-smoke.sh`, `test/sigra/install/generator_passkeys_opt_out_test.exs`, `test/support/install_fixture.ex`, feature modules, and Mix tasks — implementation ownership and existing validation patterns. [VERIFIED: repository code]
- `.planning/phases/237-canonical-b2c-generator-contract/237-CONTEXT.md` — locked scope and boundary. [VERIFIED: phase context]

### Secondary (MEDIUM confidence)

- [Phoenix `mix phx.new` documentation](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.New.html) — current scaffold options. [CITED: https://phoenix.hexdocs.pm/Mix.Tasks.Phx.New.html]
- [Hex `cloak_ecto` package page](https://hex.pm/packages/cloak_ecto) — package release, publishing, and registry metadata. [CITED: https://hex.pm/packages/cloak_ecto]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — generator/task source and the current official Phoenix/Hex documentation were checked.
- Architecture: HIGH — all recommended edits extend existing files with direct ownership evidence.
- Pitfalls: HIGH — each derives from actual existing smoke/test gaps or generator ownership.

**Research date:** 2026-08-04  
**Valid until:** 2026-09-03; recheck the Phoenix archive pin and Hex package release if planning occurs later.
