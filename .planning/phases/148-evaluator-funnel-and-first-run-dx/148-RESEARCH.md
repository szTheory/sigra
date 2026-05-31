# Phase 148: Evaluator Funnel And First-Run DX - Research

**Researched:** 2026-05-31  
**Domain:** Evaluator onboarding funnel, docs routing consistency, demo proof surfaces, first-run diagnostics  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Canonical First Path
- **D-01:** Make `guides/introduction/demo-showcase.md` the canonical evaluator-first path, then route README, Hex package text/metadata, ExDoc, `doc/llms.txt`, and `test/example/README.md` to that same path.
- **D-02:** The first path must be explicitly runnable in 10 minutes or less using existing demo commands, with README/HexDocs/test-example surfaces agreeing on the command sequence and destination.

### Demo Persona Map
- **D-03:** Use the existing six-persona data as the source of truth; improve explanation and routing, not persona shape or seeded behavior.
- **D-04:** The persona map must explain what each seeded account proves, including admin, happy-path, TOTP/MFA, OAuth-linked identity, locked/unconfirmed rough edge, scheduled-deletion lifecycle, passkey display, and multi-org states.

### Screenshot Grid And Proof Boundaries
- **D-05:** Reuse the four existing committed demo screenshots as the screenshot grid: credentials, admin user list, admin user detail, and audit explorer.
- **D-06:** Keep limitation language honest: screenshots and demo showcase are evaluator proof and inspection aids, not production certification or compliance evidence.

### Doctor / First-Run Verification
- **D-07:** Thread `mix sigra.doctor` into first-run guidance as the immediate post-install verification step.
- **D-08:** Show expected success and common failure output using the existing doctor task states and exit-code contract, especially optional-dependency wiring failures after install.

### Scope Boundary
- **D-09:** Keep this phase to docs, assets, routing, and proof alignment. Do not add new auth primitives, live OAuth credential setup, broad generated-host UI redesign, or the deferred in-app per-persona explainer banner.

### the agent's Discretion

Planning agents may choose the exact section order, headings, link text, and whether to add narrow doc-contract tests, provided the final funnel is visibly unified from README, HexDocs/ExDoc, package metadata, `doc/llms.txt`, and `test/example/README.md`.

### Deferred Ideas (OUT OF SCOPE)

- DEMO-03, the in-app per-persona explainer banner, remains future scope.
- Phase 149 owns the launch announcement package, alternatives comparison, compact evidence bundle, and release-note audience guidance.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADOPT-01 | New evaluator can find one canonical first path from README, Hex package text, ExDoc, and `test/example/README.md` to run the demo and see meaningful auth flows in 10 minutes or less. | Canonical-router plan across README, `mix.exs` metadata/ExDoc extras, `doc/llms.txt`, `guides/introduction/demo-showcase.md`, and `test/example/README.md`. [VERIFIED: codebase grep] |
| ADOPT-02 | Evaluator can use a persona intent map and screenshot grid to understand what each seeded demo account proves, including rough-edge states and explicit demo limitations. | `Example.Demo.Personas` + existing four committed screenshots + existing Playwright demo-showcase spec form a stable proof basis. [VERIFIED: codebase grep] |
| ADOPT-03 | Developer can choose between greenfield, existing-app, migration, and advanced-control adoption lanes from the top-level docs without reading the whole guide set first. | README lane table already exists; phase should tighten evaluator entry while preserving lane routing and link consistency. [VERIFIED: codebase grep] |
| ADOPT-04 | Developer can run `mix sigra.doctor` or equivalent documented verification immediately after install and understand expected success/failure output for common first-run mistakes. | Doctor task output states and exit contract are already explicit in `Mix.Tasks.Sigra.Doctor`; troubleshooting docs need first-run examples wired in. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 148 is a docs/routing alignment phase with no new auth behavior, no new personas, and no new screenshot generation required. [VERIFIED: codebase grep]  
The implementation should make `guides/introduction/demo-showcase.md` the canonical evaluator path and force every evaluator-facing entry surface to route into it consistently. [VERIFIED: codebase grep]

The underlying proof assets already exist: six canonical personas from `test/example/lib/example/demo/personas.ex`, a dev-only live credentials surface at `/demo/credentials`, a Playwright demo-showcase spec asserting persona presence and capturing baseline screenshots, and four committed PNG assets in `guides/assets`. [VERIFIED: codebase grep]

Doctor guidance is also already implemented at task level; the missing piece is first-run adoption positioning with expected success/failure output in install troubleshooting and evaluator flow docs. [VERIFIED: codebase grep]

**Primary recommendation:** Plan Phase 148 as a documentation contract pass with explicit cross-surface consistency checks, persona-map clarity, screenshot-grid limitation language, and a first-run `mix sigra.doctor` success/failure transcript block. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical evaluator routing (README/ExDoc/llms/example README) | Frontend Server (SSR docs) | — | These are static docs surfaces rendered/read by humans and tooling. [VERIFIED: codebase grep] |
| Demo persona truth | API / Backend | Frontend Server (SSR docs) | Persona truth is code data (`Example.Demo.Personas`); docs should consume/explain it. [VERIFIED: codebase grep] |
| Screenshot proof grid | CDN / Static | Frontend Server (SSR docs) | PNG assets are committed static files consumed in guide pages. [VERIFIED: codebase grep] |
| First-run doctor output explanation | API / Backend | Frontend Server (SSR docs) | Diagnostic semantics live in task/module code; docs should mirror those semantics. [VERIFIED: codebase grep] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExDoc extras/groups (`mix.exs`) | project local | Canonical docs IA and published guide routing | Current project already uses this for all public doc lanes. [VERIFIED: codebase grep] |
| Mix task `mix sigra.doctor` | project local | First-run optional-dep wiring verification and failure gate | Existing task defines output states + exit codes used by maintainers/operators. [VERIFIED: codebase grep] |
| Demo showcase guide + example app docs | project local | Evaluator-first runnable flow and persona map narrative | Phase context explicitly locks this as canonical path target. [VERIFIED: codebase grep] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Playwright demo-showcase spec | project local | Structural proof that demo personas/screenshots remain valid | Use as regression signal when touching persona/screenshot narrative. [VERIFIED: codebase grep] |
| `doc/llms.txt` index | project local | AI-consumption routing consistency with human docs | Update when canonical lane shifts to avoid split AI guidance. [VERIFIED: codebase grep] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single canonical path in demo-showcase guide | Keep multiple parallel evaluator routes in README/example README | Increases drift risk and breaks ADOPT-01 consistency criterion. [VERIFIED: codebase grep] |

**Installation:** No new external package installation is required for Phase 148 scope. [VERIFIED: codebase grep]

## Package Legitimacy Audit

No new external packages are recommended or required in this phase; Package Legitimacy Gate is not applicable. [VERIFIED: codebase grep]

**Packages removed due to slopcheck [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
Evaluator starts at README / HexDocs / Hex package text / test/example README / llms.txt
  -> canonical link target: guides/introduction/demo-showcase.md
    -> run demo commands: cd test/example && mix setup && mix phx.server
      -> open /demo/credentials for persona table
      -> log in as personas and inspect admin/audit surfaces
      -> compare to committed screenshot grid
    -> run mix sigra.doctor after install for wiring verification
      -> OK output means configured features wired
      -> ERROR output means configured-but-broken optional-dep wiring
```

### Recommended Project Structure
```text
README.md                                      # top-level evaluator lane router
mix.exs                                        # package description + ExDoc extras/groups
doc/llms.txt                                   # AI-consumption route map
guides/introduction/demo-showcase.md           # canonical evaluator-first guide
guides/introduction/troubleshooting-install.md # doctor-first troubleshooting
test/example/README.md                         # runnable local demo instructions
test/example/lib/example/demo/personas.ex      # canonical persona map truth
guides/assets/*.png                            # committed screenshot proof grid
```

### Pattern 1: Canonical Link Fan-In
**What:** Multiple entry surfaces link to one evaluator guide, not multiple competing paths. [VERIFIED: codebase grep]  
**When to use:** Any public onboarding funnel where drift is costly.  
**Example:**
```markdown
README -> Demo Showcase guide
test/example/README -> Demo Showcase guide
llms.txt Introduction section -> Demo Showcase guide
ExDoc extras include Demo Showcase guide
```

### Pattern 2: Persona Truth From Source, Not Handwritten Duplication
**What:** Treat `Example.Demo.Personas` + `feature_map/0` as source-of-truth for persona meaning text and rough-edge states. [VERIFIED: codebase grep]  
**When to use:** Any persona map table in docs.  
**Example:**
```elixir
Example.Demo.Personas.all()
Example.Demo.Personas.feature_map()
```

### Pattern 3: Honest Proof Boundary Language
**What:** Keep screenshot/demo language as inspectable evaluator evidence, never production certification. [VERIFIED: codebase grep]  
**When to use:** Screenshot grids, release evidence links, evaluator guides.  
**Example:**
```markdown
These screenshots demonstrate demo behavior and seeded proof paths.
They are not compliance or production certification artifacts.
```

### Anti-Patterns to Avoid
- **Parallel first paths:** README/example README/HexDocs each inventing a different start sequence. [VERIFIED: codebase grep]
- **Persona drift:** Docs describe persona states not present in `personas.ex`. [VERIFIED: codebase grep]
- **Doctor vocabulary fork:** Docs invent new status terms instead of reusing `missing`, `available`, `loaded`, `misconfigured` semantics from the task output. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Demo persona state source | Separate doc-only persona registry | `Example.Demo.Personas` and `feature_map/0` | Prevents behavior/docs drift and duplicate truth sources. [VERIFIED: codebase grep] |
| First-run wiring diagnosis | New ad-hoc checker or shell script | `mix sigra.doctor` and `Sigra.Doctor` result model | Existing task already enforces wiring semantics and exit codes. [VERIFIED: codebase grep] |
| Screenshot proof generation contract | New bespoke screenshot pipeline | Existing Playwright `demo-showcase.spec.ts` plus committed guide assets | Existing lane already validates/produces evaluator screenshot shapes. [VERIFIED: codebase grep] |

**Key insight:** Phase 148 should integrate and route existing evaluator assets, not produce new operational primitives. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Evaluator Lane Fragmentation
**What goes wrong:** Different docs surfaces point to different first commands or goals. [VERIFIED: codebase grep]  
**Why it happens:** README, ExDoc extras, package description, llms index, and example README are edited independently. [VERIFIED: codebase grep]  
**How to avoid:** Add a link-contract checklist covering all five surfaces in one plan step. [VERIFIED: codebase grep]  
**Warning signs:** Inconsistent first command block or inconsistent target guide names.

### Pitfall 2: Persona Semantics Drift
**What goes wrong:** Persona map prose stops matching seeded states (locked/unconfirmed, scheduled deletion, OAuth-linked, TOTP/passkey/admin). [VERIFIED: codebase grep]  
**Why it happens:** Hand-edited tables diverge from `feature_map/0`. [VERIFIED: codebase grep]  
**How to avoid:** Derive wording from current `feature_map/0` and validate each persona explicitly in docs QA. [VERIFIED: codebase grep]  
**Warning signs:** Any persona claim that cannot be found in `personas.ex` or screenshot/test proofs.

### Pitfall 3: Doctor Guidance Too Abstract
**What goes wrong:** Docs say “run doctor” but do not show expected success/failure shape. [VERIFIED: codebase grep]  
**Why it happens:** Troubleshooting docs focus on install commands only. [VERIFIED: codebase grep]  
**How to avoid:** Include one success snippet and one misconfigured snippet matching task vocabulary and exit-code behavior. [VERIFIED: codebase grep]  
**Warning signs:** Evaluators ask what `[~] available` or `[!] misconfigured` means.

## Code Examples

Verified patterns from local source:

### Canonical Demo Run Command
```bash
cd test/example
mix setup && mix phx.server
```
Source: `guides/introduction/demo-showcase.md`, `test/example/README.md` [VERIFIED: codebase grep]

### Doctor Verification Command
```bash
mix sigra.doctor
mix sigra.doctor --quiet
```
Source: `lib/mix/tasks/sigra.doctor.ex`, `guides/recipes/deployment.md` [VERIFIED: codebase grep]

### Persona Truth Contract
```elixir
Example.Demo.Personas.all()
Example.Demo.Personas.feature_map()
```
Source: `test/example/lib/example/demo/personas.ex` [VERIFIED: codebase grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| README-only evaluator lane with scattered depth links | Canonical guide fan-in using `demo-showcase.md` + screenshot assets + test/example runnable lane | v1.31 era docs/demo phases | Better evaluator inspectability and lower doc drift when consistently routed. [VERIFIED: codebase grep] |

**Deprecated/outdated:**
- Treating demo screenshots as certification artifacts is out of scope and explicitly disallowed by current requirement posture. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A “10 minutes or less” target can be validated via documented command sequence and evaluator timing spot-check without adding automated timer instrumentation. [ASSUMED] | Summary / Validation Architecture | Medium: planner may need explicit manual timing evidence task. |

## Open Questions

1. **Where should the doctor output snippet live as canonical text?**
   - What we know: `troubleshooting-install.md` exists and already covers install failures, while `deployment.md` already references doctor. [VERIFIED: codebase grep]
   - What's unclear: Whether to make troubleshooting page canonical and link from demo-showcase/README, or duplicate snippets.
   - Recommendation: Keep one canonical snippet block in `guides/introduction/troubleshooting-install.md`, link from README/demo-showcase/test/example README. [VERIFIED: codebase grep]

2. **Do we need a doc-contract test for routing consistency?**
   - What we know: Prior phases used targeted doc assertions in scripts/tests for drift-sensitive lanes. [VERIFIED: codebase grep]
   - What's unclear: Whether existing CI checks already cover this exact cross-file routing contract.
   - Recommendation: Add a narrow grep-based contract script or test only if current checks do not assert these links. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | docs/test command verification | ✓ | 1.19.5 | — |
| Mix | `mix docs`, `mix sigra.doctor`, test/example commands | ✓ | 1.19.5 | — |
| Node.js | Playwright doc-proof lane (if rerun) | ✓ | v22.14.0 | — |
| npm | Playwright dependency install (if rerun) | ✓ | 11.1.0 | — |
| Docker | local disposable Postgres for evaluator onboarding | ✓ | 29.5.2 | use local Postgres service |
| PostgreSQL readiness | demo/example + tests | ✓ | `pg_isready` accepting connections | Docker one-liner from example README |

**Missing dependencies with no fallback:**
- None.

**Missing dependencies with fallback:**
- None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + docs build + Playwright smoke lanes [VERIFIED: codebase grep] |
| Config file | `mix.exs`, `.github/workflows/ci.yml`, `test/example/priv/playwright` config/specs [VERIFIED: codebase grep] |
| Quick run command | `mix docs --warnings-as-errors` |
| Full suite command | `mix test` plus Playwright lane when doc proof assets are touched |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADOPT-01 | Single canonical evaluator path across README/HexDocs/example docs | docs contract + docs build | `mix docs --warnings-as-errors` + `rg` link-contract assertions across target files | ❌ Wave 0 |
| ADOPT-02 | Persona intent map + screenshot grid + limitation language | docs contract + asset presence | `rg` persona/state terms + `ls guides/assets/*demo-showcase*.png` | ✅ |
| ADOPT-03 | Lane routing discoverable from top-level docs | docs navigation check | `rg` lane links in README + llms + demo showcase | ❌ Wave 0 |
| ADOPT-04 | First-run doctor guidance includes success/failure understanding | command + docs snippet check | `mix sigra.doctor --quiet` (non-failing case) + `rg` expected status vocabulary in docs | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix docs --warnings-as-errors`
- **Per wave merge:** `mix test`
- **Phase gate:** docs build green + cross-surface routing assertions + asset presence checks

### Wave 0 Gaps
- [ ] Add a narrow docs routing-contract assertion script/test for README/mix.exs/llms/demo-showcase/example README cohesion.
- [ ] Add explicit doctor output snippet checks in docs validation (status words + failure guidance).
- [ ] Add manual stopwatch UAT step proving first evaluator path is <= 10 minutes using documented commands.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth behavior changes in this phase; docs-only routing/proof alignment. [VERIFIED: codebase grep] |
| V3 Session Management | no | No session logic changes. [VERIFIED: codebase grep] |
| V4 Access Control | no | No authz/policy code changes. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Validate doc claims against source-of-truth persona/task code to prevent unsafe operator guidance drift. [VERIFIED: codebase grep] |
| V6 Cryptography | no | No cryptography behavior changes. [VERIFIED: codebase grep] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Misleading operational guidance (false “healthy” interpretation) | Tampering | Reuse doctor task status vocabulary and exit semantics exactly in docs. [VERIFIED: codebase grep] |
| Overclaiming demo proof as compliance certification | Repudiation | Explicit limitation language in screenshot/demo docs and evidence routers. [VERIFIED: codebase grep] |
| Persona info drift causing incorrect evaluator trust decisions | Integrity | Keep persona map sourced from `Example.Demo.Personas` and verify against Playwright assertions/assets. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)
- `/.planning/phases/148-evaluator-funnel-and-first-run-dx/148-CONTEXT.md` - locked decisions and scope boundaries.
- `/.planning/REQUIREMENTS.md` - ADOPT-01..ADOPT-04 requirement text.
- `/README.md` - top-level lane routing and evaluator entry posture.
- `/mix.exs` - package metadata, ExDoc extras/groups, docs topology.
- `/doc/llms.txt` - AI-consumption route map.
- `/guides/introduction/demo-showcase.md` - current canonical candidate evaluator guide.
- `/test/example/README.md` - runnable evaluator app instructions and persona table.
- `/test/example/lib/example/demo/personas.ex` - canonical persona definitions and feature map.
- `/test/example/lib/example_web/live/demo/credentials_live.ex` - live credentials surface contract.
- `/test/example/priv/playwright/tests/demo-showcase.spec.ts` - screenshot + structural proof harness.
- `/guides/assets/*demo-showcase-chromium.png` - committed screenshot grid assets.
- `/lib/mix/tasks/sigra.doctor.ex` and `/lib/sigra/doctor.ex` - doctor output and exit semantics.
- `/guides/introduction/troubleshooting-install.md` and `/guides/recipes/deployment.md` - current troubleshooting/doctor docs surfaces.
- `/.github/workflows/ci.yml` - existing docs/test/playwright validation lanes.

### Secondary (MEDIUM confidence)
- None.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components are existing local project surfaces with direct code/docs verification.
- Architecture: HIGH - capability ownership aligns to static docs + existing backend truth modules.
- Pitfalls: HIGH - based on current phase constraints and validated local drift vectors.

**Research date:** 2026-05-31  
**Valid until:** 2026-06-30
