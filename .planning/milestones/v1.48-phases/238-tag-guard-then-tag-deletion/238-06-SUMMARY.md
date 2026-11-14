---
phase: 238-tag-guard-then-tag-deletion
plan: 06
subsystem: infra
tags: [github-rulesets, git-tags, adr, requirements, release-hygiene, documentation]

requires:
  - phase: 238-02
    provides: the live Tier-2 `tag-namespace` ruleset and its committed snapshot, whose rule type this plan reads
  - phase: 238-03
    provides: the red-proven `p19` contract guard and the ledger grammar it enforces
  - phase: 238-04
    provides: the committed 39-row allowlist and the deletion script the runbook cites
  - phase: 238-05
    provides: the executed deletion, its date, and the two capture slots this plan cross-references
provides:
  - two MAINTAINING.md subsections: the live tag ruleset (with the operator-side bypass check) and the planning-tag deletion procedure
  - a dated in-place ADR 003 amendment that retracts guardrail 3's false claim rather than layering on it
  - a dated REL-01 supersession naming CONTEXT D-04 and ROADMAP SC-1, triggered by the landed rule type
  - the Phase 238 evidence ledger closed — 10 of 10 slots captured, none pending, pinned to a named head
affects: [242, 245]

actuals:
  tokens: 9500
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns:
    - "Supersession recorded in two halves that travel together: the durable half in the ADR, the requirements half in REQUIREMENTS.md, both dated and in the same commit range"
    - "Obligation triggered by the landed artifact (rule type read from the committed snapshot) rather than by a plan's or requirement's wording"

key-files:
  created:
    - .planning/phases/238-tag-guard-then-tag-deletion/238-06-SUMMARY.md
  modified:
    - MAINTAINING.md
    - .planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md
    - .planning/REQUIREMENTS.md
    - .planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md
    - .gitignore

key-decisions:
  - "Retracted guardrail 3's false sentence at its source with a strikethrough and a dated correction, so the amendment does not sit beside a claim it contradicts"
  - "Kept the ADR amendment heading at the ruleset's live date (2026-09-16) as the plan's acceptance criterion specifies, and dated every factual claim inside it explicitly"
  - "Gitignored .planning/milestone.lock so a clean working tree was reachable for the ledger head pin"
  - "Recorded the live HexDocs 404 on the stray 1.20.0 build in the ledger rather than omitting it, with the proof that it predates the deletion"

patterns-established:
  - "An ADR correction retracts at the source and explains in the amendment; the two are one edit, not two readings"
  - "A ledger pin names the parent of its own commit and says so, because a file cannot carry the hash of the commit that introduces it"

requirements-completed: [REL-01, REL-02]

coverage:
  - id: D1
    description: "MAINTAINING.md documents the live `tag-namespace` ruleset — a by-name operator read command, the operator-side bypass_actors check the CI guard cannot make, the do-not-break warning, and the observer-lane default-branch caveat"
    requirement: REL-01
    verification:
      - kind: other
        ref: "bash: grep for `tag-namespace`, a `gh api repos/szTheory/sigra/rulesets` line selecting by name, and the default-branch caveat in MAINTAINING.md"
        status: pass
    human_judgment: false
  - id: D2
    description: "MAINTAINING.md documents the four-invocation deletion procedure by citing the committed script and allowlist, without enumerating the delete set"
    requirement: REL-02
    verification:
      - kind: other
        ref: "bash: grep for both paths in MAINTAINING.md; assert zero bare `vX.Y` lines"
        status: pass
    human_judgment: false
  - id: D3
    description: "ADR 003 carries a dated in-place amendment: guardrail 3's false claim retracted and corrected with both post-ADR tags and their dates, the 2026-09-17 deletion date, the allowlist path, the milestone/ and proof/ namespaces, an explicit non-coverage statement, and the guardrail-2 no-regression note"
    requirement: REL-01
    verification:
      - kind: other
        ref: "bash: exact amendment heading, unchanged `**Status:** Accepted`, section-scoped greps for 003-tag-delete-list.tsv / milestone/ / proof/ / v1.47 / v1.48, >150 words, a `does not (cover|prevent|guarantee)` statement"
        status: pass
    human_judgment: false
  - id: D4
    description: "The D-04 and ROADMAP SC-1 supersessions are recorded in both the ADR amendment and REQUIREMENTS.md, dated, triggered by the `creation` rule type read from the committed snapshot"
    requirement: REL-01
    verification:
      - kind: other
        ref: "bash: jq .rules[].type on .github/rulesets/tag-namespace.json -> creation; then assert D-04, SC-1, `supersed` and a date in both files"
        status: pass
    human_judgment: false
  - id: D5
    description: "The Phase 238 evidence ledger is closed: 10 of 10 slots captured, table status column reconciled with the slot bodies, AFTER-RELEASE-SURFACE filled from the live REST releases route and a resolved HexDocs source link"
    requirement: REL-02
    verification:
      - kind: other
        ref: "bash: slot count == captured count == 10; `^Observed at commit: <sha>` present; node --test scripts/ci/prohibitions/*.test.mjs -> 90/90 pass (p19 reads this ledger)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The evidence ledger's head pin resolves to a real commit on a clean working tree"
    verification:
      - kind: other
        ref: "Verified on 2026-09-25: evidence commit f7a987528d3ec1a9e0ba196461bbc39170c97bd4 has parent 31380c75a77a3044ebb644e7b3f15537ca7fb281 matching the ledger pin; the commit changes only 238-EVIDENCE.md; detached checkout at the evidence commit has empty git status"
        status: pass
    human_judgment: false

duration: 41min
completed: 2026-09-17
status: complete
---

# Phase 238 Plan 06: Runbook, ADR Amendment, Supersession, Ledger Close Summary

**The phase is now legible from the repository alone: an operator runbook for the live `tag-namespace` ruleset and the deletion procedure, an ADR that retracts its own false claim about the recurrence it governs, a dated supersession that names every locked artifact the landed `creation` rule departed from, and an evidence ledger with zero pending slots.**

## Performance

- **Duration:** ~41 min
- **Completed:** 2026-09-17
- **Tasks:** 3
- **Files modified:** 5 (1 created)

## The question this plan had to answer correctly

**Which rule type actually landed?** Read from the committed snapshot
`.github/rulesets/tag-namespace.json`, not from memory and not from any plan's wording:

```bash
$ jq -r '.rules[].type' .github/rulesets/tag-namespace.json | sort -u
creation
```

**Landed tier:** Tier 2 (`creation` rule + `ref_name.exclude`), as 238-02-SUMMARY records. Tier 1
(`tag_name_pattern`) was rejected by live probe with `HTTP 422 — Invalid rule 'tag_name_pattern'`;
it is enterprise-gated on this Free-tier repository.

**A `creation` rule therefore obliged a dated, explicit supersession**, and it was recorded in both
required places:

| Artifact superseded | Where recorded | What it says |
|---|---|---|
| **CONTEXT D-04**, clause 1 ("no `creation` rule, ever") | ADR amendment + REQUIREMENTS.md | A `creation` rule is exactly what landed. D-04's objection — that it would block release automation's own tag push — dissolves because `ref_name.exclude: ["refs/tags/v*.*.*"]` takes every three-segment release name out of the ruleset's **scope**, proven by live probe. Cost: it constrains creation of in-scope names rather than validating a version string. |
| **CONTEXT D-04**, clause 2 ("no `deletion` rule, ever") | ADR amendment + REQUIREMENTS.md | **Untouched.** No `deletion` rule was built; the delete-deadlock D-06 exists to avoid is still avoided. |
| **ROADMAP SC-1's named mechanism** (RE2 `tag_name_pattern`) | ADR amendment + REQUIREMENTS.md | Mechanism clause **superseded** — false as written. Observable outcome **still satisfied**: a two-component name carries one dot, is not covered by the three-dot-segment exclusion, and its creation is refused. The two are recorded as separate claims so the satisfied one cannot launder the superseded one. |
| **REL-01's implied granularity** | REQUIREMENTS.md, original wording left unedited | "Server-side", "paired contract test", "demonstrated RED", "before any deletion" are all satisfied verbatim. What is narrower is the granularity: server-side prevention at coarser granularity than a version pattern. |

## Accomplishments

- **Two MAINTAINING.md subsections**, siblings of the existing branch-ruleset subsection and following its shape. The first names the live `tag-namespace` ruleset, gives a single-line operator read command that selects **by name** (the id is minted at creation and is not a constant a document can carry, unlike the branch ruleset addressed by its id), carries the bolded do-not-break warning, documents the operator-side `bypass_actors` check and states why the CI guard deliberately cannot make it, and records the observer-lane caveat. The second documents the deletion procedure by citing `scripts/maintainers/delete-planning-tags.sh` and `.planning/decisions/003-tag-delete-list.tsv` and naming the four invocations in order — **the delete set is never enumerated in prose**, asserted by a verify that rejects bare `vX.Y` lines in the file.
- **ADR 003's guardrail 3 retracted at its source, then explained.** The false sentence — "Milestone tagging was stopped after `v1.35`" — now carries a strikethrough and a dated retraction pointing at the amendment, so the correct and incorrect claims do not stand side by side. The amendment records why: `v1.47` (2026-08-04, local only) and `v1.48` (2026-08-12, reached origin) were both minted **after the ADR's own date of 2026-07-11**. The lesson recorded is not that anyone misbehaved but that guardrail 3 was prose with no enforcement, which is exactly what the server-side rule replaces.
- **The amendment also carries** the 2026-09-17 deletion date, the allowlist path (cited, never restated) with `pre_delete_sha` described as the single dereferenced-commit column it actually is, the prescribed `milestone/` and `proof/` namespaces with the reason the second exists, an explicit non-coverage statement bounded by the live conditions, and the note that nothing in the phase adds a tag-triggered publish path so guardrail 2 is unchanged.
- **The evidence ledger is closed.** `AFTER-RELEASE-SURFACE` captured at a named head on a clean tree: 12 published releases, 0 drafts, the same 12 tags, read from `GET /repos/:owner/:repo/releases` (the same instrument `AFTER-REMOTE-DELETE` used, so the two are comparable) and cross-referencing rather than duplicating that slot's before/after window. The source link was resolved end to end from published documentation — `hexdocs.pm/sigra/1.5.0/Sigra.html` renders `blob/v1.5.0/lib/sigra.ex`, which serves 200. The table's status column was also reconciled with the slot bodies: `AFTER-P19-RED` had been captured by 238-03 but still read `pending` in the table.
- **One live 404 recorded rather than omitted.** The *default* HexDocs page for this package is still the stray `1.20.0` build and its "View source" link 404s. Proven not to be this phase's doing: no tag named `v1.20.0` has ever existed on this repository (`git ls-remote --tags origin 'refs/tags/v1.20*'` is empty, and the allowlist has zero matching rows) — the phantom was published from the two-component `v1.20` tag, normalised by the old pipeline. It is REL-04's subject, Phase 242.

## Task Commits

1. **Task 1: Two maintainer runbook subsections** — `4d608c87` (docs)
2. **Task 2: ADR 003 amendment** — `9f3d5750` (docs)
3. **Task 3: supersession + ledger close** — `bcca2697` (chore, gitignore), `b60fbff6` (docs, REQUIREMENTS), `31380c75` (chore, STATE drift), `f7a98752` (docs, ledger)

`plan_head_before:` `b5a5db2f`. Measured: `git rev-list --count b5a5db2f..HEAD` = **6** at SUMMARY-write time.

**The evidence ledger is pinned to `31380c75a77a3044ebb644e7b3f15537ca7fb281`** — the last commit before the ledger's own commit, and the head at which its final observations were taken on a clean tree.

## Verification Results

| Check | Result |
|---|---|
| Task 1 verify A (ruleset named, script + allowlist cited, by-name read command) | PASS |
| Task 1 verify B (no delete-set names in prose; default-branch caveat present) | PASS (after one fix — see Deviations) |
| Task 2 verify A (exact amendment heading, status unchanged, all five required strings in-section) | PASS |
| Task 2 verify B (amendment 1163 words > 150; a non-coverage statement; a date) | PASS |
| Task 2 verify C (landed rule type `creation` → D-04 + SC-1 + `supersed` in amendment) | PASS — `rule types landed: creation` |
| Task 3 verify A — `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | PASS — **90/90, 0 fail, 0 `not ok`** |
| Task 3 verify B (10 slots, 10 captured, head-pin line present) | PASS — `slots=10 captured=10` |
| Task 3 verify C (tier read from 238-02 → supersession present) | PASS — `tier=Tier 2` |
| Task 3 verify D (rule type → D-04 + SC-1 + date in REQUIREMENTS.md) | PASS — `rule types landed: creation` |
| Task 3 verify E (clean tree + pin resolves) | **Substituted** — clean tree PASS; pin == `HEAD^` PASS; the literal `pin == HEAD` form is unsatisfiable, see Deviations |
| `MIX_ENV=test mix ci` (the standing quality alias) | **exit 0** — `2606 tests, 0 failures, 12 skipped` |

## Deviations from Plan

**1. [Rule 3 - Blocking] The ledger head-pin check is self-referentially unsatisfiable as written.**

- **Found during:** Task 3.
- **Issue:** the verify asserts a clean tree AND `Observed at commit: $(git rev-parse HEAD)`. A file cannot contain the hash of the commit that introduces it: committing the pin changes HEAD, and amending changes it again. No fixpoint is reachable.
- **Resolution:** pinned to `31380c75` — the head at which the final slot's observations were taken, on a clean tree, with every artifact the ledger observes already committed. The ledger states the constraint in its own header rather than hiding it. Ran the substitute check (`clean tree` AND `pin == HEAD^`): PASS. **The literal check fails and is reported as failing** — it is not claimed as met.
- **Verification:** `git status --porcelain` empty; `git rev-parse --short HEAD^` = `31380c75` = the pinned value.

**2. [Rule 3 - Blocking] `.planning/milestone.lock` made a clean tree unreachable.**

- **Found during:** Task 3.
- **Issue:** the running orchestrator writes an untracked `.planning/milestone.lock` (pid + session id). It is process state, not planning state, and it kept `git status --porcelain` permanently non-empty — which the head-pin check requires to be empty.
- **Fix:** added to `.gitignore` (the executor protocol's prescribed handling for generated/runtime output), not committed and not deleted.
- **Committed in:** `bcca2697`.

**3. [deviation] Phase-start STATE drift committed mid-plan.**

- 18 lines of `.planning/STATE.md` and one of `state.json` had sat uncommitted since 238-01. They were committed in `31380c75` so the tree could be clean at the pin, rather than being carried into the final metadata commit after the pin.

**4. [deviation] The default-branch caveat grep failed once on a line wrap.** Task 1's verify B greps for the literal string `default branch`; the first draft wrapped it across two lines. Reflowed, re-verified. Recorded because a wrapped assertion string is a recurring way a real claim reads as absent.

**5. [deviation] Executed directly on `main`.** The orchestrator pinned isolation to `none` and instructed execution on `main` in the pinned root. `.planning/config.json` sets `git.branching_strategy: "none"` and every prior 238 commit is on `main`, so this matches the phase's existing shape. Nothing was pushed.

---

**Total deviations:** 2 auto-fixed blockers, 3 recorded. **Impact:** no scope creep; both auto-fixes were preconditions for the plan's own verification, not new work.

## Issues Encountered

**The standing quality alias failed once, on stale build residue — not on this plan's changes.** The
first `MIX_ENV=test mix ci` exited 2 with 6 failures, all in
`Sigra.Audit.Forwarders.ThreadlineTest`, all `UndefinedFunctionError … module is not available`. A
previous local `mix sigra.dep_off` run (the alias's own last step unlocks and cleans `threadline`)
had left `_build/test` holding a `sigra` build compiled without the optional dep, so the conditional
forwarder module was never generated and `mix compile` saw nothing to redo. Diagnosed by
`MIX_ENV=test mix compile --force` followed by the single test file: **6 tests, 0 failures**. The
full alias then re-ran clean: **exit 0, 2606 tests, 0 failures**. This plan changed only Markdown and
`.gitignore` and cannot affect Elixir modules; nothing was "fixed" beyond forcing a recompile.

## Assertions deliberately NOT made

- **The `tag_ruleset_drift` observer job in `.github/workflows/ci-observe.yml` has never executed.** A `workflow_run` lane only ever runs the default-branch copy of its file, and nothing here is pushed. The runbook says so in those words. It is **not** proven working, and no artifact in this phase claims it is.
- **The guard is a shape guard, not a SemVer validator.** `exclude: refs/tags/v*.*.*` admits `v1.2.3.4`, `v1.a.b`, `v1..` and `v...` — all carry two dots and are excluded from scope. This weakness is quoted in the runbook, the ADR amendment and the requirements note.
- **The guard covers only what the live `conditions` select.** fnmatch with `FNM_PATHNAME` means `*` does not cross `/`, so `archive/`, `milestone/` and `proof/` are outside it entirely. **It does not prevent a future `phase-NNN-*` junk tag.**
- **`mix ci`'s `ci.install_golden` step emitted no separate test summary** in either run (the main `mix test` had already run in the same Mix session). The alias exited 0; this SUMMARY claims exactly that and does not claim an independently observed install-golden run.

## User Setup Required

None.

## Next Phase Readiness

- SC-5 holds: ADR 003 records the deletion date, the delete-list path and the prescribed namespaces, and guardrail 3 is factually correct.
- REL-01 and REL-02 are complete, REL-01 with its supersession recorded in both halves.
- Every evidence slot is captured; none is pending.
- **Still standing for Phase 245:** no `git gc`, no reflog expiry, no prune in this repository — `pre_delete_sha` in the allowlist is the only handle on the deleted objects. None was run in this plan.
- **Forwarded to Phase 242 (REL-04):** the live HexDocs 404 on the stray `1.20.0` build's View-source link, with the proof in `AFTER-RELEASE-SURFACE` that it predates this phase.

---
*Phase: 238-tag-guard-then-tag-deletion*
*Completed: 2026-09-17*

## Self-Check: PASSED

- All 5 key files exist on disk (`[ -f ]`).
- All 6 task commits resolve in `git log --oneline --all`.
- Public-repo scrub over the full plan diff plus this SUMMARY: zero `/Users/…`, `/private/tmp/…`
  or `/home/…` prefixes and zero token-shaped strings.
