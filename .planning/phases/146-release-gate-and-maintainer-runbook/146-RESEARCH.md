# Phase 146: Release Gate And Maintainer Runbook - Research

**Researched:** 2026-05-31  
**Domain:** Elixir/Hex release engineering, GitHub Actions release gates, maintainer operations  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Release gates must run against the immutable release ref wherever automation can do so: `v*` tag or exact release SHA, not a floating `main` checkout.
- **D-02:** The release runbook must cross-check `mix.exs @version`, Release Please outputs, `.release-please-manifest.json`, GitHub release/tag, Hex version, and HexDocs `source_ref` so the package, docs, and source links all point at the same release.
- **D-03:** Any gate that cannot run against the release ref must be explicitly labeled manual or pre-merge, with required evidence captured in the runbook.
- **D-04:** Reuse existing CI contracts as the canonical gate evidence instead of inventing a parallel release-only test stack.
- **D-05:** The gate matrix must cover, at minimum, library tests, install golden/idempotency, fresh install smoke, example/browser smoke, dep-off lane, docs warnings, Hex dry-run, package inspection, post-publish Hex visibility, and HexDocs/source-link checks.
- **D-06:** Release-time instructions should point maintainers to the specific existing jobs, scripts, commands, and evidence links they need to inspect or rerun.
- **D-07:** Failed dry-run or publish recovery should standardize on the existing `Hex publish (manual recovery)` workflow with tag/SHA and expected version inputs as the primary no-invention recovery path.
- **D-08:** Local trusted-machine publish is fallback only, not the default recovery path, and must preserve the same release-ref/version checks as automation.
- **D-09:** Recovery wording must reflect Hex's current package semantics: docs are automatically published with the package and can be republished later; public package replacement/revert has tight time windows, so the runbook must tell maintainers when to replace/revert versus cut a follow-up patch.
- **D-10:** Create a dedicated Phase 146 release-runbook/policy doc as the canonical home for the release gate matrix, dry-run/package inspection, recovery branches, post-publish checks, and first-14-day hotfix triage policy.
- **D-11:** Keep `MAINTAINING.md` as the stable maintainer entry point and pointer to the dedicated runbook; do not duplicate the full release gate matrix there.
- **D-12:** Add a concrete first-14-day post-1.0 hotfix policy before publish, including severity/triage expectations, patch decision boundaries, evidence expectations, and communication posture.
- **D-13:** The hotfix policy should prioritize release-blocking and adopter-blocking regressions in install, compile, docs/source links, generated-host boot, security-sensitive auth behavior, and package metadata truth. It should not reopen deferred feature scope.
- **D-14:** Treat cleanup of the one-time `release-as: "1.0.0"` override as a release-gate/runbook item. After the 1.0 Release PR merges and cuts the release, remove or update that override so future releases return to conventional-commit-derived SemVer.

### the agent's Discretion
Planning agents may choose exact file names, section ordering, whether to add helper scripts, and whether to tighten GitHub workflow steps, provided the output keeps the runbook deterministic and evidence-backed. Prefer documentation plus narrow automation improvements over a broad new workflow unless existing CI cannot satisfy a required gate.

### Deferred Ideas (OUT OF SCOPE)
None -- analysis stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL1-02 | Maintainer can run a 1.0 release gate matrix that blocks publish unless required lanes are green or waived with evidence. | Existing CI and release workflows already provide all listed lanes; research maps each lane to an existing job/script and defines release-ref evidence policy. [VERIFIED: codebase grep] |
| REL1-03 | Maintainer can follow deterministic 1.0 runbook covering publish + recovery + hotfix policy. | Existing Release Please + manual recovery workflow + official Hex revert/replace semantics support deterministic runbook branches and explicit recovery timing. [VERIFIED: codebase grep] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |
</phase_requirements>

## Summary

Phase 146 should be delivered primarily as documentation and evidence-routing, not net-new release machinery. The repo already has the required gate surface in `.github/workflows/ci.yml`, release execution in `.github/workflows/release-please.yml`, and deterministic fallback in `.github/workflows/hex-publish.yml`. [VERIFIED: codebase grep]

The critical planning move is to define a single release gate matrix that maps each required gate to a specific existing job/command and a required evidence artifact (workflow URL, run ID, or command log) against the release ref (`v*` tag/SHA). For any gate that cannot run post-tag, the runbook must explicitly classify it as pre-merge/manual and require recorded waiver evidence. [VERIFIED: codebase grep]

Recovery policy must align with current Hex semantics: docs are auto-published with package publish; docs can be republished independently; public package replace/revert windows are limited (1 hour for existing package version replace/revert, 24 hours for brand-new package). [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] [CITED: https://hex.pm/docs/publish]

**Primary recommendation:** Implement a dedicated Phase-146 runbook/policy document that links to existing CI/release workflows as the source of truth, with release-ref evidence requirements, explicit recovery decision tree, and a 14-day hotfix triage protocol. [VERIFIED: codebase grep]

## Project Constraints (from AGENTS.md)

`AGENTS.md` was not present at project root during research; no project-specific overrides were discovered from that file. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Release PR + tag creation | Frontend Server (GitHub Actions control plane) | API / Backend (GitHub API) | Release Please action owns changelog/version PR and tag/release creation via GitHub workflows/API. [VERIFIED: codebase grep] [CITED: https://github.com/googleapis/release-please-action] |
| Release gate execution | Frontend Server (GitHub Actions runners) | Database / Storage (artifacts/log retention) | CI workflows execute tests/smokes/docs checks and persist evidence in workflow runs/artifacts. [VERIFIED: codebase grep] |
| Hex package publish | Frontend Server (GitHub Actions runners) | External package registry (Hex.pm) | Release workflow publishes with `mix hex.publish` using `HEX_API_KEY`; Hex is external release registry. [VERIFIED: codebase grep] [CITED: https://hex.pm/docs/publish] |
| Post-publish verification | Frontend Server (GitHub Actions + maintainer manual checks) | External docs/registry services | Workflow polls Hex API; runbook must validate HexDocs/source-link truth after publish. [VERIFIED: codebase grep] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |
| Publish recovery | Frontend Server (manual GitHub workflow dispatch) | Local trusted machine fallback | `hex-publish.yml` supports tag/SHA + expected-version recovery; local publish remains fallback branch. [VERIFIED: codebase grep] |

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GitHub Actions workflows (`release-please.yml`, `ci.yml`, `hex-publish.yml`) | repo-defined | Canonical gate + publish execution path | Already implemented and aligned to phase constraints; avoids parallel release stack. [VERIFIED: codebase grep] |
| `googleapis/release-please-action` | `v4` | Release PR/tag/release automation | Official release-please action supports manifest/config files already used in repo. [VERIFIED: codebase grep] [CITED: https://github.com/googleapis/release-please-action] |
| Hex Mix tasks (`mix hex.publish`, `mix hex.build`) | Hex v2.2.1 docs current | Dry-run, publish, revert/replace, package inspection flow | Official Hex release mechanics and recovery semantics. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |

### Supporting
| Library/Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `.release-please-manifest.json` + `release-please-config.json` | repo-defined | Version tracking and one-time `release-as: "1.0.0"` override management | Required for current one-time 1.0 cut and post-cut cleanup. [VERIFIED: codebase grep] [CITED: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md] |
| `mix docs --warnings-as-errors` | repo-defined command | Docs-warning gate | Use as release blocker in matrix via existing CI lane. [VERIFIED: codebase grep] |
| `mix hex.build --unpack` | Hex task | Inspect publish artifact contents pre-publish | Use in runbook dry-run branch before final publish. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Reusing existing CI gates | New dedicated release-only test workflow | Adds duplication and divergence risk; contradicts locked decision D-04 unless evidence gap is proven. [VERIFIED: codebase grep] |
| Manual local publish as primary | Fully manual release process | Less deterministic/auditable; keep as explicit fallback only. [VERIFIED: codebase grep] |

## Architecture Patterns

### System Architecture Diagram

```text
Conventional commits on main
        |
        v
Release Please workflow (release-please.yml)
        |-- creates/updates Release PR (mix.exs/changelog/manifest alignment)
        |-- on merge + release_created=true -> checkout release tag
        v
Publish-to-Hex job on release ref
        |-- compile/tests/docs checks
        |-- hex dry-run + package inspection
        |-- hex publish
        |-- hex visibility poll
        v
Post-publish maintainer checks
        |-- HexDocs/source_ref/tag consistency
        |-- recovery branch (hex-publish.yml) if failure
        v
14-day hotfix triage policy execution
```

### Recommended Project Structure
```text
docs/
├── release-runbook-v1-0.md   # new canonical Phase 146 runbook/policy surface
└── ga-evidence.md            # pointer surface; keep concise routing
MAINTAINING.md                # stable entry point -> pointer to runbook
.github/workflows/
├── ci.yml                    # gate evidence jobs
├── release-please.yml        # default publish path
└── hex-publish.yml           # manual recovery path
```

### Pattern 1: Release-Ref Gate Matrix
**What:** Gate table mapping each required criterion to specific workflow job/command plus evidence requirement at tag/SHA. [VERIFIED: codebase grep]  
**When to use:** Every 1.0 publish candidate and every hotfix release. [ASSUMED]

**Example:**
```markdown
| Gate | Source | Ref Rule | Evidence |
|------|--------|----------|----------|
| Library tests | ci.yml: library_tests | Must run on release tag SHA | Workflow URL + run id |
| Hex dry-run | release-please.yml: Dry run Hex publish | Must run on release tag | Step log showing --dry-run --yes |
| Hex visibility | release-please.yml: Verify version on Hex.pm | Post-publish only | API response capture |
```

### Pattern 2: Deterministic Recovery Branching
**What:** Explicit branch: dry-run failure vs publish failure vs post-publish defect, each with no-invention actions. [VERIFIED: codebase grep] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]  
**When to use:** Any failed release attempt or first-14-day release regression. [VERIFIED: codebase grep]

### Anti-Patterns to Avoid
- **Release from floating `main`:** breaks evidence determinism for REL1-02/REL1-03; use tag/SHA. [VERIFIED: codebase grep]
- **Unlabeled manual gates:** creates unverifiable release quality; every manual gate must carry explicit waiver evidence. [VERIFIED: codebase grep]
- **Inventing recovery under pressure:** runbook must predefine revert/replace/new-patch decision points. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Release PR/tag/version orchestration | Custom in-repo release bot | Release Please action + manifest/config | Already integrated; official support for manifest and `release-as`. [VERIFIED: codebase grep] [CITED: https://github.com/googleapis/release-please-action] |
| Package publish/recovery semantics | Custom scripts around Hex API semantics | `mix hex.publish` flags (`--dry-run`, `--revert`, `--replace`) | Officially defined behavior and timing windows. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |
| Duplicate release test suite | Separate release-only test harness | Existing `ci.yml` lanes + release-ref evidence matrix | Avoids drift and contradictory pass/fail criteria. [VERIFIED: codebase grep] |

**Key insight:** Most phase value is in deterministic orchestration and evidence policy, not new tooling. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Version-source mismatch
**What goes wrong:** `mix.exs @version`, tag, release-please outputs, manifest, Hex, and `source_ref` diverge. [VERIFIED: codebase grep]  
**Why it happens:** Multiple truth surfaces updated at different times. [VERIFIED: codebase grep]  
**How to avoid:** Mandatory runbook cross-check table before and after publish. [VERIFIED: codebase grep]  
**Warning signs:** HexDocs source links point to wrong/nonexistent tag. [VERIFIED: codebase grep]

### Pitfall 2: Misusing Hex recovery window
**What goes wrong:** Team attempts replace/revert after allowed window and improvises remediation. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]  
**Why it happens:** Window semantics not encoded into runbook branching. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]  
**How to avoid:** Explicit clock-based branch: replace/revert if in-window; cut follow-up patch if out-of-window. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]  
**Warning signs:** Manual discussion starts with “can we overwrite this release?” without timestamp evidence. [ASSUMED]

## Code Examples

### Release ref enforcement in publish workflow
```yaml
# Source: .github/workflows/release-please.yml
- uses: actions/checkout@...
  with:
    ref: ${{ needs.release-please.outputs.tag_name }}
```
[VERIFIED: codebase grep]

### Manual recovery with explicit ref + expected version
```yaml
# Source: .github/workflows/hex-publish.yml
on:
  workflow_dispatch:
    inputs:
      tag: { required: true }
      release_version: { required: true }
```
[VERIFIED: codebase grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-cut releases from local machine by default | CI-driven Release Please + automated Hex publish with explicit manual recovery workflow | Already present in current repo state | Higher determinism and auditable release trail. [VERIFIED: codebase grep] |
| Ambiguous docs publish assumptions | Hex explicitly documents docs auto-publish + standalone docs republish | Current Hex docs (crawled 2026-05) | Runbook can treat docs correction separately from package correction. [CITED: https://hex.pm/docs/publish] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |

**Deprecated/outdated:**
- Assuming `.release-please-manifest.json` should be manually edited after bootstrap in normal operation; release-please docs say manual edits are only appropriate during bootstrap. [CITED: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 14-day policy should apply uniformly to every post-1.0 release, not only initial `1.0.0`. | Architecture Patterns | Minor policy overreach; can be narrowed to “first 14 days after 1.0.0 publish”. |
| A2 | “Unlabeled manual gate” is currently a real team risk pattern. | Common Pitfalls | Low; mainly impacts documentation emphasis. |

## Open Questions (RESOLVED)

1. **Should all required CI lanes be rerun on the release tag, or can pre-merge `main` evidence be accepted for some long-running lanes?**
   - What we know: Existing workflows include all required gates, but not every lane is currently wired to release-tag execution. [VERIFIED: codebase grep]
   - Resolution: Phase 146 planning chose the release-tag rerun as the default evidence policy. Plan `146-01` makes the existing `CI` workflow manually dispatchable on the release tag via `gh workflow run "CI" --ref v1.0.0`; plan `146-02` requires the runbook gate matrix to classify each row as `release tag`, `pre-merge main evidence`, or `manual post-publish`.
   - Final decision: Gates should run against the release tag when technically possible. Any gate that cannot run against the release ref must be explicitly labeled manual or pre-merge and must include waiver fields `gate`, `reason`, `approver`, `evidence URL`, and `expiry`.

2. **Where should the dedicated runbook live (`docs/` vs `guides/`), and how should `MAINTAINING.md` link to it?**
   - What we know: D-10/D-11 require dedicated surface + MAINTAINING pointer. [VERIFIED: codebase grep]
   - Resolution: Phase 146 planning selected `docs/release-runbook-v1-0.md` as the canonical runbook path.
   - Final decision: `MAINTAINING.md` remains the stable maintainer entry point and links to `docs/release-runbook-v1-0.md`; it must not duplicate the full release gate matrix.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Hex publish/dry-run/docs/test commands | ✓ | Erlang/OTP 28 runtime shown by `mix --version` | — |
| `elixir` | release verification commands | ✓ | Elixir 1.19.5 | — |
| `node`/`npm`/`npx` | Playwright/browser smoke lanes in CI parity checks | ✓ | node v22.14.0 / npm+npx 11.1.0 | Manual CI-only verification if local node toolchain unavailable |
| `gh` | Maintainer runbook examples for workflow dispatch/evidence retrieval | ✓ | 2.93.0 | GitHub web UI |
| `curl` | Hex visibility checks (mirrors workflow behavior) | ✓ | 8.7.1 | Browser/manual API fetch |

**Missing dependencies with no fallback:**
- None. [VERIFIED: codebase grep]

**Missing dependencies with fallback:**
- None. [VERIFIED: codebase grep]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + GitHub Actions CI workflows [VERIFIED: codebase grep] |
| Config file | `mix.exs` (aliases/test filters) + `.github/workflows/ci.yml` [VERIFIED: codebase grep] |
| Quick run command | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` [VERIFIED: codebase grep] |
| Full suite command | `MIX_ENV=test PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && mix docs --warnings-as-errors` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REL1-02 | Gate matrix lanes are green/waived with evidence | integration/ci-orchestration | `gh run view <run-id> --log` (or Actions UI links) for mapped jobs in `ci.yml` + `release-please.yml` | ✅ |
| REL1-03 | Deterministic runbook and recovery path | workflow + documentation verification | `gh workflow run "Hex publish (manual recovery)" -f tag=vX.Y.Z -f release_version=X.Y.Z` (dry-run path) + runbook checklist review | ✅ |

### Sampling Rate
- **Per task commit:** targeted lane command for edited gate/runbook surfaces.
- **Per wave merge:** relevant CI jobs and docs warnings lane.
- **Phase gate:** evidence-complete dry-run checklist + publish/recovery branch walkthrough.

### Wave 0 Gaps
- [ ] Add explicit runbook checklist artifact template (gate, evidence URL, ref, reviewer).
- [ ] Add/confirm command snippets for release-ref reruns and evidence retrieval.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | GitHub Actions auth via repo/org permissions and `HEX_API_KEY` secret management. [VERIFIED: codebase grep] |
| V3 Session Management | no | Not a runtime app session phase; release operations domain. [VERIFIED: codebase grep] |
| V4 Access Control | yes | Restrict release workflow dispatch/merge rights to maintainers; evidence in GitHub run history. [ASSUMED] |
| V5 Input Validation | yes | Validate tag/SHA and expected version inputs in manual recovery workflow. [VERIFIED: codebase grep] |
| V6 Cryptography | yes | Use Hex API keys/secrets handling; avoid custom crypto in release tooling. [CITED: https://hex.pm/docs/publish] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Publishing wrong commit/tag | Tampering | Enforce release-ref checkout (`ref: tag_name` / manual `tag` input) and version grep checks. [VERIFIED: codebase grep] |
| Secret misuse or leakage (`HEX_API_KEY`) | Information Disclosure | GitHub Actions secrets only; do not echo tokens in logs; least-privilege repo permissions. [VERIFIED: codebase grep] |
| Incomplete release evidence | Repudiation | Require runbook evidence links per gate and explicit waivers with approver. [ASSUMED] |

## Sources

### Primary (HIGH confidence)
- Repo workflows/docs (`.github/workflows/ci.yml`, `.github/workflows/release-please.yml`, `.github/workflows/hex-publish.yml`, `MAINTAINING.md`, `mix.exs`, `.release-please-manifest.json`, `release-please-config.json`) — gate/publish/ref/recovery reality. [VERIFIED: codebase grep]
- Hex Mix task docs — publish, dry-run, revert/replace windows, docs publish behavior: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html
- Hex publish docs — package/docs publish semantics and post-publish guidance: https://hex.pm/docs/publish

### Secondary (MEDIUM confidence)
- Release Please manifest documentation: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md
- Release Please Action inputs/behavior: https://github.com/googleapis/release-please-action

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Existing repo implementation + official upstream docs agree.
- Architecture: HIGH - Phase is orchestration/documentation around already-implemented workflow topology.
- Pitfalls: MEDIUM - Two pitfalls include operational assumptions requiring maintainer confirmation.

**Research date:** 2026-05-31  
**Valid until:** 2026-06-30 (re-check if Hex or release-please docs change materially sooner)
