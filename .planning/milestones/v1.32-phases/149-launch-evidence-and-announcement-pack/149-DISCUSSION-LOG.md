# Phase 149: Launch Evidence And Announcement Pack - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md -- this log preserves the analysis.

**Date:** 2026-05-31
**Phase:** 149-launch-evidence-and-announcement-pack
**Mode:** assumptions with subagent research
**Areas analyzed:** Launch Package, Alternatives Comparison, Evidence Bundle, AI Index And Release Notes, Scope Boundary

## Assumptions Presented

### Launch Package

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 149 should create a canonical repo-resident 1.0 launch pack that is mirrored by the GitHub Release body and routed from README/HexDocs. | Confident | `.planning/ROADMAP.md`; `.planning/REQUIREMENTS.md`; `.planning/research/SUMMARY.md`; `.planning/research/ADOPTION-DX.md`; subagent launch package research |

### Alternatives Comparison

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The public comparison should cover `phx.gen.auth`, Pow/Guardian/Ueberauth composition, hosted auth, and Sigra hybrid by ownership, scope, migration risk, operational burden, and upgrade ergonomics. | Confident | `.planning/research/ECOSYSTEM-BENCHMARKS.md`; `guides/introduction/migrating-from-phx-gen-auth.md`; `guides/introduction/migrating-from-pow-guardian-ueberauth.md`; Phoenix/Pow/Guardian/Ueberauth official docs and READMEs; subagent alternatives research |

### Evidence Bundle

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 149 should add a compact attachable evidence bundle page that links to canonical release/UAT/demo proof and states known limitations instead of duplicating the full release gate matrix. | Confident | `docs/release-runbook-v1-0.md`; `docs/ga-evidence.md`; `docs/uat-ci-coverage.md`; `guides/introduction/demo-showcase.md`; demo screenshot assets; subagent evidence research |

### AI Index And Release Notes

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `doc/llms.txt` should remain the single curated AI index, with optional top-level mirror, and release-note guidance should route through one version-clear CHANGELOG/release-note surface. | Likely | `doc/llms.txt`; `CHANGELOG.md`; `mix.exs`; `https://llmstxt.org/`; Keep a Changelog and SemVer references; subagent AI routing research |

### Scope Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 149 should stay docs/evidence/routing only, with no new auth primitives, generated-host UI redesign, public RC train, SCIM, hosted-control-plane claims, compatibility shims, or broad automation. | Confident | `.planning/PROJECT.md`; `.planning/REQUIREMENTS.md`; prior Phase 145-148 context files; `.planning/research/LOCAL-PROMPT-SYNTHESIS.md`; prompt corpus |

## Corrections Made

The user requested a deeper one-shot pass before proceeding:

- Research every assumption with subagents.
- Compare pros, cons, and tradeoffs.
- Consider idiomatic Elixir, Plug, Ecto, and Phoenix posture.
- Learn from successful auth libraries, hosted auth products, and other ecosystems.
- Emphasize developer ergonomics, user friendliness, software architecture, principle of least surprise, and cohesive movement toward Sigra's project vision.
- Include applicable information from `prompts/`.

The final CONTEXT.md updates reflect that correction: the initial broad assumptions were refined into a canonical launch pack, honest alternatives comparison, compact evidence bundle, curated AI/release-note routing, and explicit docs-only scope boundary.

## Subagent Research Summary

### Launch Package

Recommendation: canonical `docs/launch/v1.0/` launch pack plus GitHub Release body as distribution surface.

Tradeoff considered:
- Canonical launch pack gives one source of truth and strong link hygiene.
- Blog-first launch has better top-of-funnel reach but higher drift and overclaim risk.
- Changelog-only is cheapest but too weak for LAUNCH-01 through LAUNCH-04.

### Alternatives Comparison

Recommendation: compare by ownership model, scope coverage, migration/cutover risk, operational burden, and upgrade ergonomics.

Tradeoff considered:
- `phx.gen.auth` is the official minimal/generated baseline.
- Pow/Guardian/Ueberauth composition can remain right for stable existing apps but carries composition tax and Phoenix 1.8 compatibility concerns.
- Hosted auth is right when managed operations matter more than self-hosted control.
- Sigra should position itself as boundary-first hybrid, not as a universal replacement.

### Evidence Bundle

Recommendation: compact evidence page that links to canonical proof and includes live-release placeholders for final facts.

Tradeoff considered:
- A single bundle page is attachable and readable.
- Reusing only the existing router is too fragmented for external evaluators.
- Machine-generated evidence artifacts are stronger long-term but too much automation for Phase 149.

### AI Index And Release Notes

Recommendation: canonical hub routing through `doc/llms.txt`, optional top-level mirror, and one release-note/adopter-triage surface.

Tradeoff considered:
- Single curated hub minimizes AI drift.
- Minimal pointer model is lower maintenance but less precise.
- Audience-split indices add clarity but increase divergence risk.

## External Research

- Phoenix 1.8 `mix phx.gen.auth` and scopes docs: official generator and scope posture for comparison categories.
- Pow README and package posture: modular Phoenix/Plug auth library and compatibility caveat.
- Guardian docs: token-toolkit positioning.
- Ueberauth README: challenge/provider-scope boundary.
- `llmstxt.org`: structured Markdown link-map convention for AI-consumption docs.
- Keep a Changelog and SemVer: version-clear release-note and changelog structure.

## Auto-Resolved

Not applicable.
