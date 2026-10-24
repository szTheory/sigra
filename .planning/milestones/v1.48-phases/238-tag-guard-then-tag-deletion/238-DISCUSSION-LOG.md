# Phase 238: Tag Guard, Then Tag Deletion - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-09-16
**Phase:** 238-tag-guard-then-tag-deletion
**Mode:** assumptions
**Calibration tier:** `minimal_decisive` (USER-PROFILE.md → Vendor Choices/Philosophy: opinionated)
**Areas analyzed:** Feasibility gate · Ruleset shape · Ordering/delete-deadlock · Contract test ·
Delete list and destructive procedure · Evidence and ADR amendment

## Assumptions Presented

### Feasibility gate

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `tag_name_pattern` may be plan-gated to Enterprise; probe before planning anything else | Confident (that a probe is required) / Unclear (the outcome) | docs.github.com "Available rules for rulesets" routes metadata rules to GHEC docs; `gh api repos/szTheory/sigra` → User-owned public, `plan: null` |

### Ruleset shape

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `target: tag`, `refs/tags/v*` condition, single `tag_name_pattern` regex rule, `negate: false`, anchored `^v…$` | Confident | REST "Repository rules" parameter schema; `github/ruleset-recipes` `tag-defaults.json` |
| No `creation` and no `deletion` rule | Confident | `creation` is name-scoped → would block release-please; UI wizard defaults "Restrict deletions" on, API does not |
| `bypass_actors: []` is safe for release-please | Confident | `release-please.yml:92` actor; `v1.5.1` matches the pattern; rulesets have no implicit admin bypass |
| Non-`v` tags out of scope via fnmatch `FNM_PATHNAME` | Confident | REST conditions docs; `*` does not cross `/` |

### Ordering

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Whether `tag_name_pattern` blocks `git push --delete` is **undocumented**; resolve empirically via the scratch-tag cleanup | Confident (that it is undocumented) | No authoritative GitHub source either way; metadata-restriction prose is framed around pushed commits, which a delete has none of |
| If blocked, flip `enforcement` to `disabled` for the delete window, then back | Confident | `enforcement` is a mutable field; API/web-UI delete route is equally evaluated, so it is not a workaround |

### Contract test

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `p19-tag-namespace-ruleset.test.mjs`, wired via the existing glob, never in `mix ci`, not in `release_ref_guard` | Confident | `p01`–`p17` on disk; `REQUIREMENTS.md:37` reserves `p18`; `ci.yml:392` glob; `ci.yml:62` short-circuits; ROADMAP SC-1 forbids |
| PR-lane half offline over a committed snapshot + known-bad fixture | Confident | `p12-run-id-provenance.test.mjs:8-14`; `_lib.mjs:11-22, 33-38` |
| Live drift read belongs in `ci-observe.yml` | Likely | `ci-observe.yml:1-31` off-gate design, `GH_TOKEN` at `:53`; caveat at `:23` (default-branch-only) |

### Delete list / procedure

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Allowlist TSV at `.planning/decisions/003-tag-delete-list.tsv`, not phase-local | Confident | Phase dirs move at close (`_lib.mjs:42-48` `archiveAwareRelPath`); SC-5 requires ADR 003 to cite a durable path |
| Committed dry-run-default script **and** a `MAINTAINING.md` runbook, not either alone | Confident | `scripts/maintainers/planning-audit-hygiene.sh`; `MAINTAINING.md:72` runbook convention |
| Set-equality asserted per side, regex-derived, no hardcoded counts | Confident | Measured local/remote asymmetry (52/33; 28 vs 10 `v1.NN`; `archive/*` local-only) |

### Evidence / ADR

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `238-EVIDENCE.md` must use the machine-parsed slot grammar | Confident | `_lib.mjs:257-262`; `p12` hard-fails malformed ledgers; `237-EVIDENCE.md` model |
| Pre-change `238-TAG-RULESET-RECORD.md` committed before ruleset creation | Confident | `237-PAGES-SETTING-RECORD.md:1-50` precedent |
| ADR 003 amended in place, dated, `Status: Accepted` retained | Confident | No superseding-ADR precedent exists in `.planning/decisions/` (001, 002, 003 only) |

## Corrections Made

No user corrections. The operator directed "auto follow ur recs", stating a single standing
bias: **automation and DevOps shift-left, if and only if the value recurs.** Applied in CONTEXT.md
as the split recorded in `<specifics>` — build the two recurring guards (`p19` per-PR, the
`ci-observe` drift read per-push-to-main); keep the one-shot deletion as a dry-run-default
committed script rather than a CI job, since it runs once and its value is auditability.
This bias also decided the open item in "Claude's Discretion": recommend the `pre-push` hook
even in the success case, because the GSD close flow is the recurring source of the junk tags.

## Corrections Applied to Subagent Findings (orchestrator-level)

Two codebase-analyzer assumptions were **overridden** by the external research before being
written into CONTEXT.md:

- **`bypass_actors` assertion.** The analyzer proposed the contract test assert
  `bypass_actors == []`. Rejected: GitHub omits `bypass_actors` entirely from callers without
  write access to the ruleset, so at CI permission level absence is indistinguishable from
  empty — the assertion would be a vacuous green, the precise failure mode this repo's
  prohibition lane exists to prevent. Moved to the operator-side check (D-10/D-11).
- **Live-read permissions.** The analyzer assumed a live ruleset read needed a PAT and was
  therefore expensive. Research showed `GET /rulesets` needs only Metadata:read and works
  unauthenticated on a public repo — which made the `ci-observe` drift check cheap enough to
  adopt (D-11). The list→by-id two-step was added because the list endpoint omits `rules`.

A third analyzer citation was **verified and kept but re-framed**: `ci-observe.yml:23`'s
default-branch-only caveat means the live check cannot be proven from a PR branch, so
CONTEXT.md requires that limitation be stated rather than the check claimed as proven in-phase.

## Auto-Resolved

Not applicable — this was not an `--auto` run. The operator delegated recommendation authority
explicitly in-conversation; every decision is recorded with its evidence in CONTEXT.md.

## Blocked During Discussion

The D-01 feasibility probe (`POST /rulesets` with `enforcement: "disabled"`, then `DELETE`)
could not be executed: the harness permission classifier denied the repo-settings write, both
for the research subagent and for the orchestrator. It is therefore carried into planning as
plan 238-01's opening execution step with a recorded fallback (D-02), rather than guessed at.

## External Research

- **Metadata-restriction plan gating.** Dotcom "Available rules for rulesets" no longer lists
  a Metadata restrictions section; "About rulesets" routes commit-metadata rules to the GHEC
  docs — GitHub Docs' standard higher-plan marker. Repo is GitHub Free.
  (https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- **Rule semantics.** `negate: false` = "must match"; `operator` ∈ `starts_with|ends_with|contains|regex`;
  regex is **RE2** — no lookarounds (`?!` explicitly unsupported), no backreferences; pattern
  matches the bare tag name, not the full ref.
  (https://docs.github.com/en/rest/repos/rules)
- **Deletion.** Governed by the `deletion` rule, which is not implied by `tag_name_pattern`.
  Whether `tag_name_pattern` itself evaluates on a delete push is **undocumented** — hence D-06's
  empirical probe. API/web-UI ref deletion is equally ruleset-evaluated, so it is no workaround.
- **Release-please.** Rulesets bind GitHub Apps and Actions tokens alike; there is **no implicit
  admin bypass**. `v1.5.1` matches the pattern, so `bypass_actors: []` is safe — provided no
  `creation` rule is added.
  (https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
- **Reading rulesets.** `GET /rulesets` returns summary fields only (no `rules`); `GET /rulesets/{id}`
  returns `target`/`conditions`/`rules` inline. Both need only Metadata:read and work
  unauthenticated on public repos. `bypass_actors` is returned only to callers with write access.
- **Rule suites.** `GET /rulesets/rule-suites` (+ `/{id}` for `rule_evaluations[]`) captures
  `enforcement: active` rejections with `result: "fail"` and a `details` string — a citable RED
  proof by id. Requires Administration:read, which an Actions `GITHUB_TOKEN` cannot hold, and
  is bounded by `time_period` (default `day`, max `month`).
  (https://docs.github.com/en/rest/repos/rule-suites)

## Live Repo Observations Recorded During Discussion

- `git tag` → 52 local; `git ls-remote --tags origin` → 33 remote. Partition verified with zero
  unclassified tags on both sides.
- `gh release list` → 12 releases, 0 drafts; no release backed by a non-SemVer tag.
- `gh api repos/szTheory/sigra/rulesets` → exactly one ruleset (`main`, `14941512`, `target: branch`).
- All 11 `phase-238-*` tags unreachable from `origin/main`, held by branch
  `gsd/238-generated-auth-runtime-proof-evidence` (local + origin).
- `mix.exs:208` → `source_ref: "v1.5.0"`.
