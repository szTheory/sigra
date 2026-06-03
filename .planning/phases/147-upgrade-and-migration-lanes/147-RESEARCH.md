# Phase 147: Upgrade And Migration Lanes - Research

**Researched:** 2026-05-31
**Domain:** Elixir/Phoenix upgrade and migration documentation + CI smoke validation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Upgrade Guide Shape And Location
- **D-01:** Add a new public guide at `guides/introduction/upgrading-to-v1.0.md`.
- **D-02:** Follow the existing operational upgrade-guide style: branch/backup preflight, exact dependency update steps, generated-file review strategy, migration/schema impact, rollback notes, and verification commands.
- **D-03:** Treat the guide as the adopter-facing truth for upgrading from latest published `0.3.x` to the selected direct Hex `1.0.0` line. Keep the planning-milestone-vs-Hex-version distinction from Phase 145 intact.

### Consumer Upgrade Smoke Contract
- **D-04:** Add a dedicated consumer-upgrade smoke lane that starts from the latest published `0.3.x` posture and then points the consumer app at the local `1.0.0` candidate source.
- **D-05:** The smoke must prove the upgraded consumer app can fetch deps, compile, migrate, and run at least a minimal runtime/boot check without unexpected regressions.
- **D-06:** Do not rely on existing fresh-install smoke or existing upgrade tests alone for UPGRADE-02. Those remain useful adjacent evidence, but they do not exercise the published-consumer-to-candidate path.

### Migration Lanes
- **D-07:** Make the `phx.gen.auth` migration lane comparative and boundary-first: when to migrate, when not to migrate, how Phoenix 1.8 scopes/session/token/magic-link/sudo-mode concepts map to Sigra, and what generated-host review is required.
- **D-08:** Make the Pow/Guardian/Ueberauth lane comparative and boundary-first: cutover options, session/token/OAuth ownership differences, migration risk, and explicit non-goals.
- **D-09:** Do not add new auth primitives, compatibility shims, or library-owned migration engines for these ecosystems in Phase 147. The deliverable is executable guidance plus smoke proof, not feature expansion.

### Linking And Discovery
- **D-10:** Wire the upgrade and migration docs into README navigation, ExDoc extras/groups, release/evidence routing docs, and `doc/llms.txt`.
- **D-11:** Keep migration docs discoverable from the same public entry surfaces that evaluators and AI-consumption tools already use, rather than burying them as standalone guides.

### the agent's Discretion

Planning agents may choose exact file names for migration guides, whether to use one combined migration guide or separate ecosystem-specific guides, and exact CI/script naming for the consumer upgrade smoke. Prefer small, reproducible scripts and clear docs over a broad new workflow unless the existing CI structure cannot host the required evidence.

### Deferred Ideas (OUT OF SCOPE)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPGRADE-01 | Existing `0.3.x` adopter can follow an `upgrading-to-v1.0.md` guide with breaking-change table, generated-file review strategy, migration/schema impact, rollback notes, and verification commands. | Upgrade guide structure, reusable template from existing `upgrading-to-v1.1.md`, and required validation commands. |
| UPGRADE-02 | Maintainer can run an automated consumer upgrade smoke from latest `0.3.x` posture to `1.0.0`-candidate source and fail the release on unexpected compile/install/runtime regressions. | Dedicated CI/script lane recommendation, command contract, and release-gate integration pattern. |
| MIGRATE-01 | Phoenix developer using `phx.gen.auth` can evaluate a migration lane that compares scope/session/token models, adoption sequence, risks, and when not to migrate. | Official Phoenix auth/scopes docs + Sigra ownership-boundary mapping guidance. |
| MIGRATE-02 | Developer using Pow, Guardian, Ueberauth, or composed auth stacks can evaluate a migration lane that explains cutover options, session/token/OAuth ownership differences, and migration risk. | Official Guardian/Ueberauth/Pow posture + Sigra boundary-first cutover framing. |
</phase_requirements>

## Summary

Phase 147 is a docs-and-proof phase, not a feature phase: ship one operational `0.3.x -> 1.0.0` upgrade guide, ship migration-lane guidance for `phx.gen.auth` and Pow/Guardian/Ueberauth users, and prove the path with a dedicated automated consumer upgrade smoke lane. [VERIFIED: codebase grep]

The strongest local pattern is to reuse existing operational guide structure (`guides/introduction/upgrading-to-v1.1.md`) and existing CI smoke harness style (`scripts/ci/install-smoke.sh`), but implement a separate upgrade smoke lane so UPGRADE-02 is independently measurable. [VERIFIED: codebase grep]

**Primary recommendation:** Implement one upgrade guide + two migration-lane docs (or one split-by-section migration guide), then add a dedicated consumer-upgrade smoke script/job wired into CI and discovery surfaces (README, ExDoc extras/groups, `doc/llms.txt`, release evidence docs). [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Upgrade/migration guidance authoring | Frontend Server (SSR docs) | — | HexDocs/README/docs pages are the user-facing source of truth. |
| Consumer upgrade smoke execution | API / Backend | CI/Automation | Validates Mix deps/compile/migrations/runtime behavior in generated Phoenix app. |
| ExDoc surfacing of guides | Frontend Server (SSR docs) | — | `mix.exs` extras/groups control published docs navigation. |
| Release evidence linkage | Frontend Server (SSR docs) | CI/Automation | Evidence pages route maintainers/evaluators to verification artifacts. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix `mix phx.gen.auth` docs | v1.8.7 | Baseline auth model comparison (scopes, magic links, sudo mode) | Required for MIGRATE-01 comparisons. [CITED: https://hexdocs.pm/phoenix/mix_phx_gen_auth.html] |
| Guardian | v2.4.0 docs | Token-based auth baseline for migration boundary mapping | Canonical Guardian scope is token creation/verification. [CITED: https://hexdocs.pm/guardian/introduction-overview.html] |
| Ueberauth | GitHub README | OAuth challenge-layer baseline and ownership boundaries | Officially positions itself as challenge phase only, not per-request auth. [CITED: https://github.com/ueberauth/ueberauth] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pow | current site docs | Compare Plug/Phoenix auth ownership posture | For Pow migration lane risk framing. [CITED: https://powauth.com/] |
| Existing Sigra CI/doc stack | current repo | Reuse scripts/workflows/extras patterns | For low-risk implementation in this phase. [VERIFIED: codebase grep] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated consumer-upgrade smoke lane | Reuse existing install smoke only | Misses published-consumer-to-candidate upgrade contract (fails UPGRADE-02 intent). [VERIFIED: codebase grep] |

**Installation:** No new package installation required for this phase’s recommended implementation. [VERIFIED: codebase grep]

## Architecture Patterns

### System Architecture Diagram

```text
Maintainer edits docs/scripts
  -> Upgrade guide (`guides/introduction/upgrading-to-v1.0.md`)
  -> Migration lane docs (`guides/introduction/...`)
  -> ExDoc nav (`mix.exs` extras/groups)
  -> Discovery links (README, docs/ga-evidence.md, doc/llms.txt)
  -> CI upgrade smoke script + workflow job
      -> create tmp consumer app from latest 0.3.x posture
      -> switch dep to local 1.0.0 candidate source
      -> deps.get -> compile -> ecto.migrate -> minimal runtime/boot check
      -> pass/fail gate in CI
```

### Recommended Project Structure
```text
guides/introduction/
├── upgrading-to-v1.0.md         # new operational upgrade guide
├── migration-from-phx-gen-auth.md (or combined migration guide section)
└── migration-from-pow-guardian-ueberauth.md (or combined migration guide section)

scripts/ci/
└── upgrade-smoke.sh             # dedicated published-consumer upgrade lane
```

### Pattern 1: Operational Upgrade Guide Contract
**What:** Mirror the existing v1.1 guide shape: preflight, exact commands, generated-file review, migration impact, rollback, verification. [VERIFIED: codebase grep]  
**When to use:** Any Sigra major/minor upgrade guide that must be executable by adopters.  
**Example:**
```markdown
## Before you start
## 1. Update dependency
## 2. Run Sigra upgrade task
## 3. Run migrations + compile
## 4. Review generated files + ownership boundaries
## 5. Verify with test/ci commands
## 6. Rollback notes
```

### Pattern 2: Dedicated Consumer Upgrade Smoke Lane
**What:** Separate script/job proving published consumer posture can upgrade to candidate source. [VERIFIED: codebase grep]  
**When to use:** Release/adoption phases with explicit upgrade reliability requirements.  
**Example:**
```bash
mix deps.get
mix compile --warnings-as-errors
mix ecto.create
mix ecto.migrate
mix phx.server # or equivalent minimal boot assertion
```

### Anti-Patterns to Avoid
- **Conflating install smoke with upgrade smoke:** Fresh install success does not prove upgrade safety from existing consumer posture. [VERIFIED: codebase grep]
- **Feature creep in migration docs:** Do not add compatibility engines/primitives in this phase. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OAuth provider challenge flow | Custom OAuth challenge framework | Ueberauth/Assent patterns already used in ecosystem | Provider edge cases and callback semantics are complex. [CITED: https://github.com/ueberauth/ueberauth] |
| Token auth core | Custom token format + validator | Guardian/JWT standard patterns for comparison and cutover framing | Reinventing token lifecycle/security is risky. [CITED: https://hexdocs.pm/guardian/introduction-overview.html] |

**Key insight:** This phase should hand-roll only documentation and smoke orchestration glue, not new authentication engines. [VERIFIED: codebase grep]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None found for this phase scope (docs + CI smoke only). | None |
| Live service config | None required; no external dashboard/service migration is in scope. | None |
| OS-registered state | None required. | None |
| Secrets/env vars | Existing CI DB/env assumptions (`PGUSER/PGPASSWORD/PGHOST`) already used by smoke scripts. [VERIFIED: codebase grep] | Reuse existing env contract in new upgrade smoke lane. |
| Build artifacts | Tmp generated app artifacts under `/tmp` in smoke scripts. [VERIFIED: codebase grep] | Keep cleanup/recreate behavior in script. |

## Common Pitfalls

### Pitfall 1: Version-axis confusion (`0.3.x` published vs `1.0.0` candidate)
**What goes wrong:** Docs/tests mix planning milestone language with installable Hex package language.  
**Why it happens:** Multiple version axes in release/adoption phases.  
**How to avoid:** Keep explicit “latest published `0.3.x` -> candidate `1.0.0` source” wording in guide and smoke steps. [VERIFIED: codebase grep]  
**Warning signs:** Ambiguous “upgrade to latest” language without concrete source/posture.

### Pitfall 2: Overclaiming migration automation
**What goes wrong:** Docs imply drop-in migration with no generated-host review.  
**Why it happens:** Treating auth libraries as equivalent by feature list only.  
**How to avoid:** Boundary-first guidance: session/token/OAuth ownership and non-goals per lane. [CITED: https://hexdocs.pm/phoenix/mix_phx_gen_auth.html] [CITED: https://hexdocs.pm/guardian/introduction-overview.html] [CITED: https://github.com/ueberauth/ueberauth]  
**Warning signs:** Missing “when not to migrate” section.

## Code Examples

### Consumer upgrade smoke lane skeleton
```bash
#!/usr/bin/env bash
set -euo pipefail
# 1) Scaffold or prepare consumer app at latest published 0.3.x posture
# 2) Switch dependency to local 1.0.0 candidate source
mix deps.get
mix compile --warnings-as-errors
mix ecto.create
mix ecto.migrate
# 3) Minimal runtime/boot assertion
```

### Migration lane structure skeleton
```markdown
## Who should migrate now
## Who should not migrate yet
## Model mapping (scope/session/token/OAuth)
## Cutover options
## Risks and rollback posture
## Generated-host review checklist
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Auth generator docs without scopes/magic-link/sudo emphasis | Phoenix v1.8 auth docs emphasize scopes, magic links, and sudo mode | Phoenix 1.8 era docs | Migration guidance must account for these concepts explicitly. [CITED: https://hexdocs.pm/phoenix/mix_phx_gen_auth.html] |

**Deprecated/outdated:**
- Treating Ueberauth as full request-auth solution is outdated; official docs position it as challenge-phase framework. [CITED: https://github.com/ueberauth/ueberauth]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Pow docs site alone is sufficient to characterize Pow migration boundaries for this phase. | Standard Stack / Pitfalls | Medium: migration lane could miss nuance from deeper Pow docs. |

## Open Questions (RESOLVED)

1. **Exact smoke start posture for “latest `0.3.x`”**
   - Resolution: The upgrade smoke lane should resolve the latest published `0.3.x` release from Hex at runtime, record the selected version in a variable/log line, support an optional deterministic override for reruns, and fail if no published `0.3.x` exists. This satisfies D-04 through D-06 without silently collapsing to a stale pin. [VERIFIED: checker revision instruction + codebase decisions]

2. **Single migration guide vs split guides**
   - Resolution: Keep split guides. `147-02-PLAN.md` already assigns separate migration surfaces for `phx.gen.auth` and Pow/Guardian/Ueberauth, which is the better fit for the different boundary models and preserves the context decision to keep those comparisons readable. [VERIFIED: plan review + D-07/D-08]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | docs build + smoke scripts | ✓ | 1.19.5 | — |
| Mix | compile/migrate/smoke | ✓ | 1.19.5 | — |
| `phx_new` archive | temp consumer app generation | ✓ | available (`mix help phx.new`) | document manual install if missing |
| PostgreSQL local service | smoke migrate/runtime checks | ✓ | `pg_isready` accepting connections | use CI postgres service if local missing |
| Node/npm | existing CI/example flows (adjacent) | ✓ | Node 22.14.0 / npm 11.1.0 | not required for core phase deliverables |

**Missing dependencies with no fallback:**
- None.

**Missing dependencies with fallback:**
- None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Mix test) [VERIFIED: codebase grep] |
| Config file | `mix.exs` test config / filters [VERIFIED: codebase grep] |
| Quick run command | `mix test test/upgrade_test.exs -x` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UPGRADE-01 | Upgrade guide is operational + verifiable | docs + smoke/manual | `mix docs --warnings-as-errors` plus guide-listed commands | ✅ |
| UPGRADE-02 | Published-consumer upgrade to candidate source is gated | integration smoke | `bash scripts/ci/upgrade-smoke.sh` (new) in CI | ❌ Wave 0 |
| MIGRATE-01 | `phx.gen.auth` migration lane published and linked | docs verification | `mix docs --warnings-as-errors` + link checks | ❌ Wave 0 |
| MIGRATE-02 | Pow/Guardian/Ueberauth lane published and linked | docs verification | `mix docs --warnings-as-errors` + link checks | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix docs --warnings-as-errors`
- **Per wave merge:** `mix test` + targeted smoke script
- **Phase gate:** Full suite green and upgrade smoke passing before `$gsd-verify-work`

### Wave 0 Gaps
- [ ] `scripts/ci/upgrade-smoke.sh` — covers UPGRADE-02
- [ ] CI workflow wiring for dedicated upgrade smoke lane — covers UPGRADE-02
- [ ] New docs pages + ExDoc extras/groups entries — covers UPGRADE-01/MIGRATE-01/MIGRATE-02

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Boundary-accurate docs on auth model ownership and migration risk |
| V3 Session Management | yes | Explicit session ownership/cutover notes in migration lanes |
| V4 Access Control | yes | “When not to migrate” and non-goals to prevent unsafe assumptions |
| V5 Input Validation | no | Phase is docs/CI lane, no new input-validation code planned |
| V6 Cryptography | yes | Do not change cryptographic primitives; document ownership boundaries |

### Known Threat Patterns for Elixir/Phoenix Auth Migration Guidance

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overstated migration equivalence | Tampering | Comparative mapping + explicit non-goals in each lane |
| Incomplete upgrade verification | Repudiation | Dedicated CI smoke evidence for compile/migrate/runtime |
| Token/session boundary confusion | Elevation of privilege | Clear ownership boundary tables per lane |

## Sources

### Primary (HIGH confidence)
- Local codebase documents/scripts/workflows (`guides/introduction/upgrading-to-v1.1.md`, `README.md`, `mix.exs`, `doc/llms.txt`, `.github/workflows/ci.yml`, `scripts/ci/install-smoke.sh`, `test/upgrade_test.exs`) — patterns and current integration points. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)
- Phoenix `mix phx.gen.auth` guide (v1.8.7): https://hexdocs.pm/phoenix/mix_phx_gen_auth.html
- Phoenix `Mix.Tasks.Phx.Gen.Auth`: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Auth.html
- Guardian overview (v2.4.0): https://hexdocs.pm/guardian/introduction-overview.html
- Ueberauth official README: https://github.com/ueberauth/ueberauth
- Pow official site: https://powauth.com/

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - mostly local-stack reuse plus official docs for migration comparisons.
- Architecture: HIGH - phase constraints are explicit and locked in `147-CONTEXT.md`.
- Pitfalls: MEDIUM - migration-lane pitfalls rely on synthesis across multiple ecosystems.

**Research date:** 2026-05-31  
**Valid until:** 2026-06-30
