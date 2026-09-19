---
phase: "238"
slug: "tag-guard-then-tag-deletion"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-09-17"
---

# Phase 238 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Register origin: **authored at plan time** — all six `238-0N-PLAN.md` files carried a parseable
`<threat_model>` block, so this audit verifies mitigations rather than building a register
retroactively. No `## Threat Flags` were escalated by any SUMMARY (confirmed with a positive
control: the same grep matches 4× in `238-01-PLAN.md` and 0× across all six SUMMARYs).

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| operator/agent → GitHub repo settings API | A privileged write; the credential is an admin-scoped token | Ruleset create/delete payloads |
| GitHub Settings → the git repo | The ruleset lives server-side only; the repo's sole record is the committed snapshot | `.github/rulesets/tag-namespace.json` |
| any pusher (owner, PAT, Actions token) → `refs/tags/*` on origin | Untrusted ref names; the ruleset is the validator | Tag ref names |
| this repo (public) → the world | Everything committed is world-readable, including embedded API payloads | Home-dir prefixes, token material |
| allowlist row → remote ref delete | The only path by which a name reaches a destructive command | Literal tag names + `pre_delete_sha` |
| pull_request CI lane → external network | The merge-gating guard must not cross this boundary | (none — guard is offline) |
| phase artifacts → future readers | Documentation is where an over-claim survives longest | Coverage and proof claims |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-238-01 | Tampering | ruleset `14941512` (`main` branch ruleset) | critical | mitigate | Never a write target; live list still returns it `branch`/`active` | closed |
| T-238-02 | Denial of Service | probe ruleset left enforcing | high | mitigate | Live list holds exactly 2 entries — no probe survives | closed |
| T-238-03 | Information Disclosure | committed API payloads on a public repo | medium | mitigate | Scan of pushed diff `b6e889c4..6b03af05`: 7 hits, all the scrub's own regexes / synthetic `/Users/example/x` controls; no real prefix or token (positive control returned 2) | closed |
| T-238-04 | Repudiation | settings change with no recorded prior value | high | mitigate | `238-TAG-RULESET-RECORD.md` committed pre-change | closed |
| T-238-05 | Spoofing | a tier claimed from docs rather than observed | medium | mitigate | `238-01-SUMMARY.md:79` records Probe A REJECTED `HTTP 422 Validation Failed` verbatim | closed |
| T-238-06 | Spoofing | the `v*` release namespace | high | mitigate | Live ruleset `23574716` active, `include: refs/tags/v*` | closed |
| T-238-07 | Elevation of Privilege | ruleset bypass actors | high | mitigate | Live read with an admin-scoped token returns `bypass_actors: []` — the operator-side check the CI guard cannot make | closed |
| T-238-08 | Denial of Service | release-please's own tag creation | high | mitigate | `exclude: refs/tags/v*.*.*` keeps three-segment names out of scope | closed |
| T-238-09 | Tampering | silent ruleset removal in Settings | high | mitigate | Committed snapshot is the reference; live drift read landed in 238-03 | closed |
| T-238-10 | Denial of Service | ruleset blocking this phase's own deletions | medium | mitigate | Empirical delete probe; 39 tags deleted successfully | closed |
| T-238-11 | Denial of Service | `gh`/token/5xx on the pull_request critical path | medium | mitigate | `p19` guard is offline and structural; reads a committed file, no network call | closed |
| T-238-12 | Tampering | silent removal or weakening of the ruleset | high | mitigate | Drift job **executed and passed** in observe run `35249205910`: `live tag-namespace ruleset (id 23574716) matches the committed snapshot` | closed |
| T-238-13 | Repudiation | a guard that passes but asserts nothing | high | mitigate | `p19` 19/19 with recorded RED proof; malformed `238-EVIDENCE.md` reddens `fast_checks` repo-wide | closed |
| T-238-14 | Tampering | a malformed evidence ledger passing unnoticed | medium | mitigate | Ledger slot grammar asserted as a secondary artifact | closed |
| T-238-15 | Elevation of Privilege | over-permissioned observer job token | medium | mitigate | `permissions: contents: read` only; `actions: read` deliberately omitted (`ci-observe.yml:194-195`) | closed |
| T-238-16 | Tampering | an unpinned action resolving to a mutable tag | high | mitigate | All three `actions/checkout` uses pinned to `3d3c42e5…` (lines 57, 144, 199) | closed |
| T-238-17 | Denial of Service | a live read flaking the PR critical path | medium | mitigate | Live read is on the non-gating `workflow_run` observer lane | closed |
| T-238-18 | Denial of Service | a release-backing tag destroyed by prefix collision | critical | mitigate | One literal name per invocation from `.planning/decisions/003-tag-delete-list.tsv`; no glob, no prefix | closed |
| T-238-19 | Tampering | an unreviewed delete set | high | mitigate | Committed TSV reviewed in the same diff as the script, one reason per row | closed |
| T-238-20 | Repudiation | objects unreachable with no record of where they were | high | mitigate | `pre_delete_sha` column in the enforced header; no `gc`/`reflog expire`/`prune` run anywhere in this phase | closed |
| T-238-21 | Denial of Service | accidental mutation from a bare invocation | high | mitigate | `APPLY=0` default; `--apply` required; bare run prints `REPORTING ONLY — no ref will be touched` (`:152`) | closed |
| T-238-22 | Repudiation | a suppressed delete failure read as success | high | mitigate | `set -euo pipefail` (`:59`) + `fail()` → named reason, `exit 1` (`:69`) | closed |
| T-238-23 | Spoofing | a vacuous green from two empty listings | high | mitigate | Positive control asserts non-empty listing and keep-set before every comparison | closed |
| T-238-24 | Denial of Service | a release-backing or docs-source tag deleted | critical | mitigate | Every tag in `gh release list` verified present on origin (0 missing; bogus-tag positive control confirmed the check can fail) | closed |
| T-238-25 | Repudiation | irreversible remote mutation with no authorization record | high | mitigate | Operator approved the exact 39-row local / 21-row remote set before any destructive invocation (`238-05-SUMMARY.md:100`) | closed |
| T-238-26 | Repudiation | deleted objects with no record of where they pointed | high | mitigate | Same `pre_delete_sha` capture as T-238-20; forward-feed for Phase 245 | closed |
| T-238-27 | Spoofing | a swallowed tool error reported as a clean draft count | high | mitigate | Draft count read from the REST releases route; before-count must succeed or the task stops | closed |
| T-238-28 | Denial of Service | ruleset blocking deletes, read as a no-op | high | mitigate | Delete exit statuses unsuppressed under `set -euo pipefail` | closed |
| T-238-29 | Elevation of Privilege | weakening the guard to unblock a stuck delete | high | mitigate | Live `bypass_actors: []` confirms no actor was ever added; documented remedy is a recorded enforcement-flip window | closed |
| T-238-30 | Repudiation | a requirement quietly narrowed to match what shipped | high | mitigate | Dated supersession note with original wording left visible (`REQUIREMENTS.md:53-68`) | closed |
| T-238-31 | Spoofing | an over-claim about the guard's coverage | high | mitigate | Shape-guard-not-SemVer-validator weakness stated in runbook, ADR amendment and requirements note (`238-06-SUMMARY.md:223`) | closed |
| T-238-32 | Repudiation | ledger pinned to a head predating the final commit | high | mitigate | `238-EVIDENCE.md:3` `Observed at commit: 31380c75…`, asserted against head on a clean tree | closed |
| T-238-33 | Tampering | delete set restated in prose and drifting from the data | medium | mitigate | Runbook cites the allowlist by path; verify rejects enumerated names (`238-06-SUMMARY.md:169` PASS) | closed |
| T-238-34 | Spoofing | claiming the observer-lane drift read is proven | medium | mitigate | Default-branch caveat recorded in runbook and SUMMARY while unproven; now proven by run `35249205910` and recorded in `238-UAT.md` | closed |
| T-238-SC | Tampering | npm/pip/cargo installs | low | accept | Phase installs zero packages — no `mix.exs`, `package.json` or action-version change | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-238-01 | T-238-SC | Supply-chain checkpoint is not applicable: the phase changes no dependency manifest and pins no new action version. Declared `accept` in all six plans. | operator | 2026-09-17 |

---

## Known Limitations (not threats — tracked)

Two latent defects in the drift job, plus one absent assertion, are filed at
`.planning/todos/pending/2026-09-17-tag-ruleset-drift-observer-has-never-run-and-has-two-latent-defects.md`.
All three fail **closed** (false red or unlabelled red, never false green), so a deleted ruleset is
still caught — they are trust-and-noise items, not security holes:

1. `set -euo pipefail` aborts at `ID=$(…)` before the job's own named `ABSENT` message can print.
2. The ruleset list is fetched unpaginated (breaks past 30 rulesets; the repo has 2).
3. Nothing asserts the job **ran**. Its `workflow_run.event != 'pull_request'` guard skips it on
   PR-triggered observe runs while the run still reports green — two such runs sat at this phase's
   head SHA during UAT. Recorded in `238-UAT.md` as the false-green trap.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-17 | 35 | 35 | 0 | /gsd-secure-phase (orchestrator, ASVS L1 short-circuit) |
| 2026-09-19 | 35 | 35 | 0 | verify-work post-hook refresh; live ruleset diff and observer execution rechecked |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-17
