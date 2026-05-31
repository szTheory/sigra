---
phase: 146
slug: release-gate-and-maintainer-runbook
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-31
---

# Phase 146 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Maintainer dispatch -> GitHub Actions workflow inputs | Manual dispatch or recovery inputs can select the wrong ref or version unless validated. | Release refs, version strings, workflow dispatch inputs |
| Release Please outputs -> checked-out source tree | The workflow must prove the checked-out tag, manifest, and `mix.exs` version describe the same release. | Release tag, version, manifest contents, package source |
| GitHub Actions secrets -> workflow logs | `HEX_API_KEY` must stay in secret-backed env vars and never be echoed or transformed into artifact output. | Hex publish token |
| Workflow logs -> release evidence | Release evidence is only trustworthy if the workflows run the canonical gates and keep stable job identities. | CI logs, gate evidence, release decisions |
| Workflow evidence -> maintainer decisions | The runbook must translate workflow logs into publish/no-publish decisions without ambiguity. | Workflow/job status, reviewer evidence, waiver rows |
| Public registry/docs state -> recovery actions | Recovery decisions depend on current Hex and HexDocs behavior and timing windows, not maintainer memory. | Hex.pm API state, HexDocs/source-link state |
| Maintainer index pages -> canonical runbook | Router docs must not contradict or duplicate the release matrix, or evidence becomes fragmented. | Maintainer documentation and release-evidence routes |
| Hotfix reports -> patch/revert/replace decisions | The first-14-day policy must separate release blockers from deferred feature requests under pressure. | Incident reports, severity labels, workaround status |

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-146-01 | Tampering | `.github/workflows/release-please.yml` | mitigate | Release workflow checks `@version`, verifies `tag_name == v<version>`, verifies `.release-please-manifest.json`, verifies `source_ref: "v#{@version}"`, and checks out the Release Please tag before publish. Evidence: `.github/workflows/release-please.yml` lines 65, 101-132. | closed |
| T-146-02 | Tampering | `.github/workflows/hex-publish.yml` | mitigate | Manual recovery validates `release_version`, accepts only matching `v<release_version>` tags or commit SHAs, proves SHA/tag provenance, then verifies `@version`, manifest, and `source_ref` before publish. Evidence: `.github/workflows/hex-publish.yml` lines 40-80 and 107-127. | closed |
| T-146-03 | Information Disclosure | `HEX_API_KEY` usage in publish jobs | mitigate | Publish token appears only as step-level `env: HEX_API_KEY: ${{ secrets.HEX_API_KEY }}` for dry-run/publish steps; no commands echo it, no environment dumps are present, and package inspection does not upload artifacts. Evidence: `.github/workflows/release-please.yml` lines 159-166 and `.github/workflows/hex-publish.yml` lines 160-167. | closed |
| T-146-04 | Repudiation | `.github/workflows/ci.yml` release evidence | mitigate | CI has a release-ref `workflow_dispatch` path, a `release_ref_guard`, and canonical gate jobs depend on that guard while retaining stable job ids. Evidence: `.github/workflows/ci.yml` lines 3-7, 24-42, 79-82, 146-149, 195-198, 295-300, 567-570, 632-635, and 890-893. | closed |
| T-146-05 | Repudiation | package inspection / dry-run evidence | mitigate | Both publish paths run docs with warnings as errors, unpack package contents, assert required files, exclude `.planning`, dry-run publish, real publish, and Hex visibility polling. Evidence: `.github/workflows/release-please.yml` lines 143-174 and `.github/workflows/hex-publish.yml` lines 144-175. | closed |
| T-146-06 | Repudiation | `docs/release-runbook-v1-0.md` evidence checklist | mitigate | Runbook requires gate rows and an evidence checklist with `Gate`, `Workflow/job or command`, `Release ref`, `Evidence URL or log`, `Reviewer`, `Waiver?`, and `Notes`. Evidence: `docs/release-runbook-v1-0.md` lines 7-58. | closed |
| T-146-07 | Tampering | recovery decision tree | mitigate | Recovery tree covers dry-run failure, publish failure before visibility, docs/source-link issues, `replace`, `revert`, follow-up patches, and Hex timing windows. Evidence: `docs/release-runbook-v1-0.md` lines 94-111. | closed |
| T-146-08 | Information Disclosure | local trusted-machine fallback guidance | mitigate | Runbook and manual router make GitHub Actions the primary recovery path and local trusted-machine publish fallback only, with no token-copying shortcut. Evidence: `docs/release-runbook-v1-0.md` lines 74-82 and `docs/NEXT-STEPS-MANUAL.md` lines 24-28. | closed |
| T-146-09 | Repudiation | stale router docs | mitigate | Maintainer and release-evidence router docs point to the canonical runbook, and `docs/ga-evidence.md` requires pinned `v<version>` proof links instead of `main` blob URLs. Evidence: `MAINTAINING.md` lines 144-147, `docs/NEXT-STEPS-MANUAL.md` lines 5-7, and `docs/ga-evidence.md` lines 1-19. | closed |
| T-146-10 | Denial of Service | hotfix triage process | mitigate | First-14-day policy defines P0-P3 severity, triage timing, minimum evidence, patch boundaries, and excludes deferred feature ideas. Evidence: `docs/release-runbook-v1-0.md` lines 113-144. | closed |

## Summary Threat Flags

No additional `## Threat Flags` entries were present in `146-01-SUMMARY.md` or `146-02-SUMMARY.md`.

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-31 | 10 | 10 | 0 | Codex |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-31
