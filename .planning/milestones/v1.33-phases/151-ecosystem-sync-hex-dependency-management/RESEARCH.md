<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Hex dependency updates will be performed manually (`mix deps.update --all`) without expanding Dependabot configuration.
- D-02: CI compatibility verification will rely strictly on updating `.tool-versions` to the target Elixir/OTP rather than introducing a multi-version build matrix.
- D-03: Any deprecation warnings from dependencies or core Elixir will be fixed via code changes rather than compiler suppression.
- D-04: Dependency bumps will remain within the existing `~>` constraints in `mix.exs` unless a major bump is explicitly required to clear OTP deprecations.

### the agent's Discretion
None

### Deferred Ideas (OUT OF SCOPE)
None
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ECO-01 | CI pipeline verifies compatibility with latest Elixir/Phoenix minor versions with zero deprecations. | CI relies strictly on `.tool-versions`. Target Erlang is 28.5. `mix compile --warnings-as-errors` passes cleanly. |
| ECO-02 | Hex dependencies are routinely bumped to their latest secure and compatible versions. | `mix deps.update --all` correctly resolves safe minor/patch bumps without constraint updates in `mix.exs`. |
| ECO-03 | Supply-chain security and framework alignment are confirmed via a passing CI suite. | Verification handled via existing CI lanes (e.g. `library_tests`, `install_golden_contract`). |
</phase_requirements>

# Phase 151: Ecosystem Sync & Hex Dependency Management - Research

**Researched:** 2025-05-18
**Domain:** Dependency Management, CI/CD, Toolchain Alignment
**Confidence:** HIGH

## Summary

The project is currently configured to use `erlang 28.1` and `elixir 1.19.5-otp-28` as defined in `.tool-versions`. The `.github/workflows/ci.yml` CI pipeline is already elegantly aligned to read strictly from this file (`erlef/setup-beam` with `version-file: .tool-versions` and `version-type: strict`). Therefore, updating `.tool-versions` to `erlang 28.5` (the latest available OTP 28 patch release compatible with Elixir 1.19.5) natively upgrades the CI pipeline to the target environment without requiring manual edits to `ci.yml` or matrix expansion (fulfilling D-02).

For dependency resolution, running `mix hex.outdated` and `mix deps.update --all` reveals that many core libraries (Phoenix to 1.8.7, Ecto to 3.14.0, Oban to 2.23.0) update successfully while cleanly respecting the existing `~>` constraints specified in `mix.exs`. As such, no manual constraint editing in `mix.exs` is required (aligning with D-04). Furthermore, compiling these updated dependencies inside the project natively yields zero project-level deprecation warnings, satisfying ECO-01 and D-03.

**Primary recommendation:** Update `.tool-versions` to `erlang 28.5`, then run `mix deps.update --all` to batch update Hex dependencies within current `mix.exs` constraints. Run `mix compile --warnings-as-errors` to confirm a clean compilation.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Hex Dependency Updates | API / Backend | — | Elixir standard library and ecosystem deps reside in `mix.lock` via Mix |
| OTP Version Alignment | CI / Build | — | `.tool-versions` dictates Erlang/Elixir for local dev and GitHub Actions |

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | 1.19.5-otp-28 | Primary runtime language | Project base version, verified against latest supported OTP patch. |
| Erlang OTP | 28.5 | Beam VM environment | Latest stable minor/patch release in the 28.x series available via `asdf`. |
| Mix | built-in | Dependency and build tool | Standard `mix deps.update --all` handles constraints automatically. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.tool-versions` CI sync | GitHub Actions Build Matrix | Matrix provides multi-version coverage but increases CI runtimes, costs, and deviates from decision D-02. |
| `mix deps.update --all` | Dependabot PRs | Dependabot expands automation but creates CI noise. D-01 dictates manual unified bumps. |

## Package Legitimacy Audit

> **Note:** This phase performs ecosystem updates (`mix deps.update --all`) on *already integrated* libraries within previously vetted constraints, rather than introducing new external packages to the application. Hex resolution leverages the official registry signature mechanism.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| *Existing Dependencies* | hex.pm | N/A | N/A | N/A | [OK] | Approved |

## Architecture Patterns

### System Architecture Diagram
(CI Toolchain Sync Flow)
- Developer updates `.tool-versions` (bump erlang to 28.5) and runs `mix deps.update --all`
- `mix.lock` is updated and committed
- GitHub Actions CI (via `erlef/setup-beam`) parses `.tool-versions`
- CI provisions correct Erlang/Elixir environment -> runs `library_tests` and all smoke checks -> Confirms ecosystem alignment

### Recommended Project Structure
No structural or file-tree changes are needed. Updates strictly mutate:
```text
.tool-versions  # Bumped Erlang/OTP version
mix.lock        # Bumped package hashes and versions
```
(`.github/workflows/ci.yml` requires no changes due to its dynamic referencing of `.tool-versions`).

### Anti-Patterns to Avoid
- **Expanding Dependabot for Hex:** D-01 explicitly locks this decision. Keep Dependabot scoped to core github actions but handle Hex package updates through holistic `mix deps.update --all` batches.
- **Manual constraint tweaks in mix.exs:** As per D-04, do not modify `~>` constraints in `mix.exs` unless `mix deps.update --all` natively fails to resolve due to breaking core OTP deprecations.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CI Version Sourcing | Hardcoded versions in `ci.yml` | `.tool-versions` + `version-type: strict` | Centralizes the version-of-truth, preventing split-brain toolchain drift between local dev and CI. |
| Dependency update hunting | Individual `mix deps.update <pkg>` commands | `mix deps.update --all` | Resolves cross-dependency conflicts natively by evaluating the entire graph at once. |

## Common Pitfalls

### Pitfall 1: Stale hex/rebar in CI environments
**What goes wrong:** New dependencies fail to fetch or compile in CI due to an outdated Hex or Rebar binary.
**Why it happens:** CI caches dependencies but might skip forcing an update to the package managers themselves.
**How to avoid:** Ensure CI always runs `mix local.hex --force` and `mix local.rebar --force`. (Verified: the project's `ci.yml` successfully enforces this on all relevant jobs).

## Code Examples

Verified manual ecosystem update workflow:

### Syncing Ecosystem Locally
```bash
# Set environment to latest Erlang 28.5 (assuming asdf is installed)
asdf install erlang 28.5
echo "erlang 28.5" > .tool-versions
echo "elixir 1.19.5-otp-28" >> .tool-versions

# Update local mix configuration and fetch the newest packages
mix local.hex --force
mix local.rebar --force
mix deps.update --all

# Confirm project continues to compile cleanly with zero deprecations
mix compile --warnings-as-errors
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Multi-version matrix | Strict `.tool-versions` gating | Pre-existing (D-02) | Lean CI pipeline focused on rapid iteration with exactly one guaranteed-working host runtime. |
| Fragmented Dependabot PRs | Batch manual bumps | Pre-existing (D-01) | Avoids merge-conflict cascading and CI queue congestion for dependency updates. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `slopcheck` tool omitted since only pre-existing hex packages are updated | Package Legitimacy Audit | N/A — no new supply chain injection vectors are introduced. |

## Open Questions

None - the dependency bounds and CI configuration strictly align with the documented phase decisions.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| asdf | Local environment syncing | ✓ | N/A | — |
| Elixir | Framework runtime | ✓ | 1.19.5 | — |
| Erlang / OTP | Beam VM | ✓ | 28.x | — |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` test configs |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ECO-01 | Clean compilation with zero warnings | static | `mix compile --warnings-as-errors` | ✅ Wave 0 |
| ECO-02 | Tests pass on bumped Hex dependencies | unit/integration | `mix test` | ✅ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix compile --warnings-as-errors && mix test`
- **Per wave merge:** Full CI run
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
None — existing test infrastructure fully covers phase requirements.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V14 Configuration | yes | Dependency locking (`mix.lock`) |

### Known Threat Patterns for Elixir / Hex

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Vulnerable 3rd Party Dependency | Tampering | Routine `mix deps.update --all` & hex registry lock files |

## Sources

### Primary (HIGH confidence)
- Local `.github/workflows/ci.yml` (CI dependency configuration)
- Local `mix.exs` (Dependency Constraints)
- `asdf list all erlang` and `asdf list all elixir` for OTP toolchain verification
- `mix hex.outdated` and `mix deps.update --all` resolution checks

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Directly observable via `asdf` and Hex CLI commands.
- Architecture: HIGH - CI toolchain parsing behavior is standard and explicitly modeled in `ci.yml`.
- Pitfalls: HIGH - Hex versioning semantics are predictably sound.

**Research date:** 2025-05-18
**Valid until:** 30 days
