# Phase 149: Launch Evidence And Announcement Pack - Research

**Researched:** 2026-06-01
**Domain:** Release-launch documentation architecture, evidence routing, and AI-consumption indexing for Sigra 1.0
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Create a repo-resident canonical 1.0 launch pack under `docs/launch/v1.0/` and route the GitHub Release body, README/HexDocs entry points, changelog guidance, and AI-consumption index to that pack.
- **D-02:** The launch pack should be docs-first and evidence-first, not blog-first. External blog/social copy can quote or point to the pack later, but the repo-owned pack is the source of truth.
- **D-03:** The core narrative is: Sigra 1.0 is a stability and trust release for Phoenix 1.8+ auth; the product moat is the hybrid library plus generator model; security-sensitive primitives stay updateable in the library while generated host code remains inspectable and host-owned.
- **D-04:** The announcement artifact must include problem framing, core differentiators, explicit non-goals, proof links, upgrade/migration guidance, and "who should upgrade now vs wait" guidance.
- **D-05:** Add a public Sigra-vs-alternatives comparison page or launch-pack section that compares by ownership model, scope coverage, migration/cutover risk, operational burden, and upgrade ergonomics.
- **D-06:** Compare Sigra against four categories: Phoenix `mix phx.gen.auth`, Pow plus Guardian plus Ueberauth-style composition, hosted auth providers, and Sigra's own hybrid model.
- **D-07:** Position Sigra as a boundary-first Phoenix-native hybrid, not as "better at everything." The comparison must say when not to choose Sigra.
- **D-08:** Preserve exact scope boundaries from prior phases: `phx.gen.auth` is the official minimal/generated baseline; Ueberauth is challenge/provider oriented; Guardian is token-toolkit oriented; Pow-style stacks may be valid for existing stable apps but carry Phoenix 1.8 compatibility and composition concerns; hosted auth is valid when managed operations matter more than in-repo control.
- **D-09:** The alternatives page must avoid overclaiming ecosystem equivalence, automatic migration, hosted-auth replacement, provider certification, or compliance outcomes.
- **D-10:** Create a compact attachable evidence bundle page, preferably `docs/launch/v1.0/evidence.md` or `docs/launch-evidence-v1-0.md`, that links to canonical proof instead of duplicating the full release runbook or UAT matrix.
- **D-11:** Include evidence rows for release gate status, docs warnings-as-errors, UAT-to-CI mapping, upgrade smoke, demo screenshot proof, known limitations, post-publish Hex visibility, HexDocs/source-link truth, and any waivers.
- **D-12:** Use live-release placeholders only for facts that cannot exist before the real release, such as final Hex visibility, final HexDocs page, final GitHub Release URL, and release-ref CI run URLs.
- **D-13:** Use pinned tag URLs for release proof outside the Hex tarball. Do not use `main` blob links for release evidence.
- **D-14:** The evidence bundle must explicitly state what the proof does not prove: no compliance certification, no live provider certification, no host deployment warranty, no hosted control plane, and no guarantee that generated-host local modifications are covered.
- **D-15:** Add or prepare a release-note/adopter-guidance section that clearly says who should upgrade now, who can wait, and what first-14-day adopter triage looks like.
- **D-16:** Keep release notes human-curated and version-clear under the existing Keep-a-Changelog style. Do not scatter upgrade-now/wait guidance across multiple competing docs.
- **D-17:** Link release-note guidance to the 1.0 contract, upgrade guide, migration lanes, demo showcase, launch evidence bundle, and Phase 146 release runbook/hotfix policy.
- **D-18:** Preserve the planning-milestone-vs-Hex-SemVer distinction in every launch surface. Public launch copy should headline Hex `1.0.0`, not internal v1.32 milestone labels.
- **D-19:** Keep `doc/llms.txt` as the generated ExDoc AI-consumption map and make it route first to installation, the 1.0 contract, ownership boundaries, security/non-goals, migration lanes, demo showcase, launch evidence, and release-note guidance.
- **D-20:** Add a top-level `llms.txt` mirror or equivalent package/root pointer if it improves discoverability without creating a second source of truth. If added, it must point to the same canonical docs and avoid a separate policy vocabulary.
- **D-21:** Do not create separate adopter and maintainer AI indices unless planning can enforce ownership. A single curated hub is the least surprising path for Phase 149.
- **D-22:** Keep implementation to docs, evidence packaging, release/announcement copy, routing, and narrow docs-contract tests if needed.
- **D-23:** Verification should prove link presence, ExDoc inclusion, AI-index routing, changelog/release-note routing, evidence-bundle boundaries, and absence of stale/misleading claims. It should not require live Hex publish proof before the real release.

### the agent's Discretion

Planning agents may choose exact filenames and section ordering, provided the canonical pack is easy to attach to the release/announcement and all public paths converge. Prefer a small number of durable docs over many tiny pages. Prefer link-based evidence aggregation over copied matrices.

### Deferred Ideas (OUT OF SCOPE)

- External blog/site/social launch copy is deferred until the repo-owned pack is stable.
- Machine-generated evidence artifacts are deferred; useful later if Sigra starts recurring audited release attestations.
- Separate adopter/maintainer AI indices are deferred unless the single curated hub proves insufficient.
- Public RC train remains fallback only if a concrete release blocker appears.
- New auth primitives, SCIM, hosted control plane, compatibility shims, and broad generated-host UI redesign remain out of scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LAUNCH-01 | Publish-ready 1.0 announcement pack | Canonical launch pack layout + release-note routing + non-goal/proof boundaries |
| LAUNCH-02 | Honest alternatives comparison | Official-source capability boundaries for `phx.gen.auth`, Pow, Guardian, Ueberauth + anti-overclaim guardrails |
| LAUNCH-03 | Compact evidence bundle | Existing runbook + UAT/CI + demo screenshot + gate sources identified for link aggregation |
| LAUNCH-04 | AI-consumption index coherence | Existing `doc/llms.txt` routing and ExDoc integration path verified |
</phase_requirements>

## Summary

Phase 149 should be planned as a **documentation integration phase**, not a feature phase: the repo already contains the required truth surfaces (release runbook, evidence router, UAT/CI map, migration guides, contract, demo showcase, and `doc/llms.txt`) and the main work is converging them into one canonical launch pack with strict anti-overclaim language. [VERIFIED: repo grep]

The planning risk is not missing content; it is divergence and claim drift across surfaces (`README`, `CHANGELOG`, ExDoc extras, release body, and AI index). The plan should therefore prioritize link-proof and absence-check verification over prose volume. [VERIFIED: repo grep]

**Primary recommendation:** Build `docs/launch/v1.0/{announcement,alternatives,evidence}.md`, wire all existing entry points to these docs, and add docs-contract tests for routing + forbidden-claim phrases. [VERIFIED: repo grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Announcement narrative | Docs content layer | ExDoc build layer | Canonical truth is in markdown docs shipped via ExDoc extras. [VERIFIED: repo grep] |
| Alternatives comparison | Docs content layer | External reference layer | Comparison claims rely on curated prose plus official ecosystem docs. [CITED: https://phoenix.hexdocs.pm/Mix.Tasks.Phx.Gen.Auth.html] |
| Evidence bundle assembly | Docs content layer | CI/release metadata layer | Bundle links existing CI/runbook evidence rather than generating new runtime data. [VERIFIED: repo grep] |
| AI-consumption routing | ExDoc output (`doc/llms.txt`) | Root pointer file (optional) | Current AI index is generated in docs output and should remain single-source. [VERIFIED: repo grep] |
| Link/absence verification | Test/CI layer | Docs content layer | Automated grep/link checks prevent stale or overclaiming launch copy. [VERIFIED: repo grep] |

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| ExDoc (via `mix docs`) | `~> 0.40` | Publish docs/extras and generate `doc/llms.txt` | Existing docs pipeline and launch docs must integrate here. [VERIFIED: repo grep] |
| GitHub Actions CI workflow | `.github/workflows/ci.yml` (current repo workflow) | Release-evidence gates and docs warnings-as-errors proof links | Existing release-evidence contract already maps gates + ref rules. [VERIFIED: repo grep] |
| Markdown docs under `docs/` + `guides/` | repo-native | Canonical launch pack and comparison/evidence pages | Current evidence/router/contract surfaces already live here. [VERIFIED: repo grep] |

### Supporting
| Library/Tool | Version | Purpose | When to Use |
|--------------|---------|---------|-------------|
| Keep a Changelog format | 1.1.0 spec | Release-note structure for human-curated updates | For upgrade-now/wait and hotfix-window guidance sections. [CITED: https://keepachangelog.com/en/1.1.0/] |
| Semantic Versioning | 2.0.0 spec | Version-axis clarity in launch narrative | For enforcing Hex SemVer truth over milestone labels. [CITED: https://semver.org/spec/v2.0.0.html] |
| `llms.txt` convention | llmstxt.org current spec | AI-consumption routing structure | For optional top-level pointer and doc index consistency. [CITED: https://llmstxt.org/] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Repo-owned launch pack | External blog as canonical source | Breaks traceable evidence and increases drift risk vs versioned docs. [VERIFIED: repo grep] |
| Single `doc/llms.txt` hub | Separate maintainer/adopter indices | Higher maintenance risk and split policy vocabulary. [VERIFIED: repo grep] |

## Architecture Patterns

### System Architecture Diagram

```text
Inputs
  README / CHANGELOG / GitHub Release body / doc/llms.txt
      |
      v
Canonical launch docs (docs/launch/v1.0/*)
  - announcement.md
  - alternatives.md
  - evidence.md
      |
      +--> links to existing proof sources
      |      - docs/release-runbook-v1-0.md
      |      - docs/ga-evidence.md
      |      - docs/uat-ci-coverage.md
      |      - migration/upgrade/demo guides
      |
      v
ExDoc build (mix docs --warnings-as-errors)
      |
      v
Published docs + AI index (doc/llms.txt, optional root llms.txt pointer)
```

### Recommended Project Structure
```text
docs/
└── launch/
    └── v1.0/
        ├── announcement.md
        ├── alternatives.md
        └── evidence.md
```

### Pattern 1: Link-Aggregator Evidence Page
**What:** Keep evidence compact by linking canonical proof pages, not duplicating matrices. [VERIFIED: repo grep]  
**When to use:** Any release announcement that must remain stable as proofs update. [VERIFIED: repo grep]

### Pattern 2: Boundary-First Comparison Table
**What:** Compare ownership/scope/risk/operational burden, then explicitly list “when not to choose Sigra.” [VERIFIED: repo grep]  
**When to use:** Public alternatives page where overclaiming risk is high. [VERIFIED: repo grep]

### Anti-Patterns to Avoid
- **Claiming equivalence or automatic migration:** Violates locked constraints and creates support/compliance risk. [VERIFIED: repo grep]
- **Using `main` proof links for release evidence:** Must use pinned tag URLs. [VERIFIED: repo grep]
- **Scattering upgrade-now/wait guidance across many docs:** Requires one canonical release-note path. [VERIFIED: repo grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Changelog format | Custom prose-only release format | Keep a Changelog sections in `CHANGELOG.md` | Established human-readable structure and versioned deltas. [CITED: https://keepachangelog.com/en/1.1.0/] |
| Versioning rules | Ad-hoc version labels | SemVer rules for public package claims | Prevents milestone-vs-package confusion. [CITED: https://semver.org/spec/v2.0.0.html] |
| AI index schema | Custom proprietary index format | `llms.txt`-compatible structure and pointers | Aligns with emerging interoperable agent consumption pattern. [CITED: https://llmstxt.org/] |

## Common Pitfalls

### Pitfall 1: Overclaiming alternative parity
**What goes wrong:** Launch copy implies full drop-in compatibility or provider/compliance guarantees. [VERIFIED: repo grep]  
**Why it happens:** Marketing framing outpaces boundary docs. [ASSUMED]  
**How to avoid:** Add explicit “does not prove / not provided” blocks in announcement and evidence pages. [VERIFIED: repo grep]  
**Warning signs:** Phrases like “drop-in replacement,” “certified,” “fully equivalent.” [ASSUMED]

### Pitfall 2: Drift across launch surfaces
**What goes wrong:** README/CHANGELOG/release body/`llms.txt` point to different canonical docs. [VERIFIED: repo grep]  
**How to avoid:** Treat `docs/launch/v1.0/*` as source of truth and test link presence centrally. [VERIFIED: repo grep]

### Pitfall 3: Pre-publish evidence pretending post-publish truth
**What goes wrong:** Docs claim final Hex/HexDocs/release URLs before publish exists. [VERIFIED: repo grep]  
**How to avoid:** Use placeholders for post-publish-only facts and verify after release. [VERIFIED: repo grep]

## Code Examples

### Example: Existing ExDoc extras wiring pattern (extend for launch docs)
```elixir
# Source: mix.exs docs.extras
extras: [
  "docs/uat-ci-coverage.md",
  "docs/ga-evidence.md",
  "docs/release-runbook-v1-0.md"
]
```
[VERIFIED: repo grep]

### Example: Existing release evidence routing policy language
```markdown
For release proof hosted outside the Hex package tarball ... use pinned `v<version>` links.
Do not use `main` blob URLs for release evidence.
```
Source: `docs/ga-evidence.md` [VERIFIED: repo grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Human UAT-heavy release narrative | CI-first evidence + explicit residual boundaries | Established by existing `docs/uat-ci-coverage.md` posture | Launch pack should aggregate proof links, not restate test matrices. [VERIFIED: repo grep] |
| Single-surface release note assumptions | Multi-surface routing with canonical docs contract | Prior phases 145–148 | Phase 149 must converge entry points to one launch pack. [VERIFIED: repo grep] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Overclaim warning phrases should include “drop-in replacement / certified / fully equivalent” | Common Pitfalls | May miss some risky wording variants in checks |
| A2 | Marketing framing is the primary cause of comparison overclaim drift | Common Pitfalls | Could underweight other drift sources (e.g., rushed maintenance edits) |

## Open Questions

1. **Should a root `llms.txt` be added now or deferred?**
   - What we know: `doc/llms.txt` already exists and is routed in ExDoc output. [VERIFIED: repo grep]
   - What's unclear: Whether root-level discovery materially improves external agent behavior for this project.
   - Recommendation: Plan as optional task with strict “pointer-only, no second vocabulary” guardrail.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix`/Elixir toolchain | Docs build + verification commands | ✓ | Elixir 1.19.5 printed; command exits non-zero in this shell session | Use CI docs gate as authoritative until local shell issue is resolved |
| `gh` CLI | Release evidence command examples | ✓ | 2.93.0 | GitHub web UI manual runs |
| `rg` | Link/claim grep checks | ✓ | 15.1.0 | `grep` |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + docs-contract shell checks in CI [VERIFIED: repo grep] |
| Config file | `mix.exs` + `.github/workflows/ci.yml` [VERIFIED: repo grep] |
| Quick run command | `mix docs --warnings-as-errors` |
| Full suite command | `mix test && mix docs --warnings-as-errors` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LAUNCH-01 | Announcement contains required sections + guidance | docs-contract | `rg -n "<required headings/policies>" docs/launch/v1.0/announcement.md` | ❌ Wave 0 |
| LAUNCH-02 | Honest alternatives with bounded claims | docs-contract | `rg -n "phx.gen.auth|Pow|Guardian|Ueberauth|hosted"` + forbidden-phrase grep | ❌ Wave 0 |
| LAUNCH-03 | Evidence bundle routes to canonical proof and limitations | docs-contract | `rg -n "release-runbook|uat-ci-coverage|demo-showcase|limitations"` | ❌ Wave 0 |
| LAUNCH-04 | AI index points to canonical install/ownership/migration/security/demo/launch docs | docs-contract | `rg -n "installation|contract|security|migrating|demo-showcase|launch"` doc/llms.txt | ✅ |

### Sampling Rate
- **Per task commit:** `mix docs --warnings-as-errors`
- **Per wave merge:** `mix docs --warnings-as-errors` + phase-specific grep checks
- **Phase gate:** all launch docs routes + forbidden-claim checks pass

### Wave 0 Gaps
- [ ] Add phase-specific docs-contract test script for launch pack routing/absence checks
- [ ] Add launch docs into `mix.exs` `docs.extras` once files exist

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth-runtime code changes in this phase; docs-only scope |
| V3 Session Management | no | No session-runtime code changes in this phase |
| V4 Access Control | no | No access-control-runtime code changes in this phase |
| V5 Input Validation | yes | Verify claim boundaries via deterministic grep/docs-contract checks |
| V6 Cryptography | no | No cryptographic implementation changes |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Misleading security/compliance claims in launch copy | Repudiation / Information Disclosure | Explicit non-goals + “does not prove” section + forbidden-phrase checks |
| Stale/unpinned evidence links | Tampering | Require pinned tag URLs for release proof links |

## Sources

### Primary (HIGH confidence)
- Repository sources (`mix.exs`, `README.md`, `CHANGELOG.md`, `docs/release-runbook-v1-0.md`, `docs/ga-evidence.md`, `docs/uat-ci-coverage.md`, `guides/introduction/*`, `.github/workflows/ci.yml`) — integration points and existing proof surfaces. [VERIFIED: repo grep]
- Phoenix `mix phx.gen.auth` docs: https://phoenix.hexdocs.pm/Mix.Tasks.Phx.Gen.Auth.html
- Phoenix `mix phx.gen.auth` guide: https://phoenix.hexdocs.pm/mix_phx_gen_auth.html
- Guardian overview: https://guardian.hexdocs.pm/introduction-overview.html
- Pow official repo: https://github.com/pow-auth/pow
- Ueberauth official repo: https://github.com/ueberauth/ueberauth

### Secondary (MEDIUM confidence)
- Keep a Changelog 1.1.0: https://keepachangelog.com/en/1.1.0/
- Semantic Versioning 2.0.0: https://semver.org/spec/v2.0.0.html
- llms.txt reference: https://llmstxt.org/

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - repository already defines docs/CI stack and launch surfaces.
- Architecture: HIGH - phase is docs-integration with clear existing ownership boundaries.
- Pitfalls: MEDIUM - root causes of drift phrasing are partly inferred.

**Research date:** 2026-06-01  
**Valid until:** 2026-07-01
