# Phase 242: Hex Retire + Docs Revert + Pinned-Install ADR + Cut 1.5.1 - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `242-CONTEXT.md` are authoritative.

**Date:** 2026-09-20
**Phase:** 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
**Mode:** assumptions
**Areas analyzed:** Hex remediation and evidence, install constraint and documentation truth, durable ADR ownership, 1.5.1 release provenance

## Assumptions Presented

### Hex remediation and evidence

| Assumption | Confidence | Evidence |
| --- | --- | --- |
| A dedicated dispatch-only remediation lane should mutate the fixed bad release, retain least privilege, and record public state at each causal boundary. | Likely | `.github/workflows/hex-publish.yml`; `.planning/ROADMAP.md` §Phase 242; `.planning/research/SUMMARY.md` |

### Install constraint and documentation truth

| Assumption | Confidence | Evidence |
| --- | --- | --- |
| The safe 1.5 install constraint is `~> 1.5.0`, not `~> 1.5`. | Confident | `guides/introduction/installation.md`; `https://elixir.hexdocs.pm/1.18.4/Version.html` |

### Durable record ownership

| Assumption | Confidence | Evidence |
| --- | --- | --- |
| ADR 005, not ADR 004, should record pinned-install and retirement-resolution truth. | Confident | `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`; `.planning/decisions/004-test-01-02-superseded-by-single-owner-mix-ci.md` |

### 1.5.1 cut and existing guarantees

| Assumption | Confidence | Evidence |
| --- | --- | --- |
| 1.5.1 must follow remediation and docs work, fold Unreleased before merge, prove the exact release SHA green, and retain post-publish verification. | Confident | `.github/workflows/release-please.yml`; `.github/workflows/hex-publish.yml`; `CHANGELOG.md`; `scripts/ci/release-post-publish-verify.sh` |

## Corrections Made

The user confirmed the cohesive recommendation set. One factual correction is incorporated as
a decision: the requirement/roadmap's literal `~> 1.5` is not safe against `1.20.0`; the
implementation and ADR must use `~> 1.5.0`.

## External Research

- Elixir pessimistic requirements: two segments constrain only the major (`~> 1.5` admits
  `1.20.0`); three segments constrain the minor (`~> 1.5.0` excludes it).
  Source: https://elixir.hexdocs.pm/1.18.4/Version.html
- Hex retirement: `mix hex.retire sigra 1.20.0 invalid --message "…"` is the supported
  noninteractive API-key path; package releases remain resolvable with a retirement warning.
  Source: https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html
- Hex docs: `mix hex.publish docs --revert 1.20.0` reverses the independently attached docs;
  docs have no update/revert time limit, unlike package release reversion. Source:
  https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html
- Package API evidence: public package state exposes `latest_stable_version` and a
  `retirements` map; latest/root-doc effects stay empirical rather than assumed. Source:
  https://raw.githubusercontent.com/hexpm/specifications/main/apiary.apib
