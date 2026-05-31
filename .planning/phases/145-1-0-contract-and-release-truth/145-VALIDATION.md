---
phase: 145
slug: 1-0-contract-and-release-truth
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-31
---

# Phase 145 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Mix, ExDoc, ripgrep source assertions |
| **Config file** | `mix.exs`, `release-please-config.json`, `.release-please-manifest.json` |
| **Quick run command** | `mix format --check-formatted` |
| **Full suite command** | `mix docs --warnings-as-errors` |
| **Estimated runtime** | ~60-180 seconds |

## Sampling Rate

- **After every task commit:** Run `mix format --check-formatted` and task-specific `rg` assertions.
- **After every plan wave:** Run `mix docs --warnings-as-errors`.
- **Before `$gsd-verify-work`:** `mix format --check-formatted`, `mix docs --warnings-as-errors`, and all plan-level source assertions must be green.
- **Max feedback latency:** 180 seconds for docs build; 15 seconds for source assertions.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 145-01-01 | 01 | 1 | CONTRACT-01, REL1-04 | T-145-01 | Public contract states the stack/version truth without conflating planning milestones and Hex releases. | source/docs | `rg -n "planning milestones|Hex|1\\.0\\.0|Elixir.*1\\.18|Phoenix.*1\\.8|Ecto|Postgres|OptionalDeps|sigra.doctor" README.md CHANGELOG.md guides/introduction/contract.md` | `guides/introduction/contract.md`, `README.md`, `CHANGELOG.md` | pending |
| 145-01-02 | 01 | 1 | CONTRACT-02 | T-145-02 | Contract separates library-owned, generated-host-owned, and shared seam surfaces. | source/docs | `rg -n "Library-owned|Generated-host-owned|Shared seams|host application" guides/introduction/contract.md README.md` | `guides/introduction/contract.md`, `README.md` | pending |
| 145-01-03 | 01 | 1 | CONTRACT-03, CONTRACT-04 | T-145-03 | Security invariants, non-goals, SemVer, and deprecation policy are visible from top-level docs without overclaiming host-owned responsibilities. | source/docs | `rg -n "Security invariants|Non-goals|SemVer|deprecation|authorization|compliance|host" guides/introduction/contract.md SECURITY.md MAINTAINING.md README.md` | `guides/introduction/contract.md`, `SECURITY.md`, `MAINTAINING.md`, `README.md` | pending |
| 145-02-01 | 02 | 1 | REL1-01 | T-145-04 | Release Please is configured for one-time `1.0.0` release PR while the pre-release manifest remains last shipped `0.3.0`. | source/config | `bash -lc 'rg -n "\"release-as\"[[:space:]]*:[[:space:]]*\"1\\.0\\.0\"" release-please-config.json; rg -n "\"\\.\"[[:space:]]*:[[:space:]]*\"0\\.3\\.0\"" .release-please-manifest.json; rg -n "@version \"0\\.3\\.0\"" mix.exs'` | `release-please-config.json`, `.release-please-manifest.json`, `mix.exs` | pending |
| 145-02-02 | 02 | 1 | REL1-04, CONTRACT-01 | T-145-05 | First-path install examples use the selected `~> 1.0` package line and docs explain the transition from `0.3.0` to `1.0.0`. | source/docs | `rg -n "\\{:sigra, \"~> 1\\.0\"\\}|0\\.3\\.0|1\\.0\\.0|planning milestones" README.md guides/introduction/installation.md guides/introduction/getting-started.md guides/introduction/first-hour.md CHANGELOG.md` | `README.md`, `guides/introduction/installation.md`, `guides/introduction/getting-started.md`, `guides/introduction/first-hour.md`, `CHANGELOG.md` | pending |
| 145-02-03 | 02 | 1 | REL1-01, CONTRACT-01, CONTRACT-04 | T-145-06 | Docs build proves ExDoc extras, links, and contract/security pages are warning-clean. | docs build | `mix docs --warnings-as-errors` | `mix.exs`, docs extras | pending |

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Human judgment that public contract wording does not overclaim host deployment/compliance responsibility. | CONTRACT-02, CONTRACT-04 | Automated source assertions can prove presence of boundaries, not reader interpretation. | Read README contract pointer, `guides/introduction/contract.md`, and `SECURITY.md`; confirm they distinguish library guarantees from host-owned deployment, authorization, mail deliverability, and compliance. |

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Feedback latency < 180s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending

