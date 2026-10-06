---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 06
subsystem: ci
tags: [evidence-ledger, ratchet-baseline, todos, mix-ci, dep-off]

requires:
  - phase: 237-01
    provides: reachable doc/llms.txt negation, regenerated docs index
  - phase: 237-02
    provides: GitHub Pages repointed to gh-pages, built and serving 200
  - phase: 237-03
    provides: 1 live worktree, 6 stashes untouched, SC-3 stash half recorded unmet (D-09)
  - phase: 237-04
    provides: regex-class rationale-preservation check, 4 dead lib/ doc refs removed
  - phase: 237-05
    provides: 3 dead guide links fixed, suppression list 9->7
provides:
  - "237-EVIDENCE.md: one parseable ledger re-observing all five phase requirements at final committed HEAD"
  - "237-RATCHET-BASELINE.md: 337/254/69 docs-attribute baseline + 52-line security-rationale count, with a committed reproducible scanner"
  - "2 required todos filed (Phase 239 SC-5 dead marker, doc/llms.txt staleness) plus 2 newly discovered ones (upgrade_test.exs never runs; dep-off restore leaves threadline a no-op)"
  - "a clean MIX_ENV=test mix ci at final HEAD, disclosed honestly across 7 diagnostic runs"
affects: [238, 239, 240, 241, 242]

actuals:
  tokens: 13762
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "evidence ledger with BEFORE-/AFTER- named slots, each Status-lined and fenced, validated via the shared parseEvidenceSlots helper called directly rather than the phase-230-pinned p12 guard"
    - "absence claims paired with a same-block positive control, including a non-literal reconstructed-at-check-time synthetic path to avoid the ledger itself tripping its own sanitization scan"
    - "fresh _build/test rebuild before accepting a mix ci result, after diagnosing a real dep-off recompile bug through repeated runs rather than retrying blindly"

key-files:
  created:
    - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-EVIDENCE.md
    - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-RATCHET-BASELINE.md
    - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py
    - .planning/todos/pending/2026-09-16-phase-239-sc5-names-a-comment-marker-that-does-not-exist.md
    - .planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md
    - .planning/todos/pending/2026-09-16-upgrade-test-never-runs-anywhere-wrong-mix-task-name.md
    - .planning/todos/pending/2026-09-16-dep-off-restore-leaves-threadline-forwarder-a-noop-until-forced-recompile.md
  modified: []

key-decisions:
  - "Installed the CLAUDE.md-pinned phx_new 1.8.8 archive to satisfy Task 3's stated precondition (local archive was 1.8.13) — this is the documented remediation, not a foreign-package install, so it does not trigger the package-legitimacy checkpoint"
  - "The Task 2 verify command's pathspec ':(exclude,glob):/.planning/**' errors with 'fatal: Invalid path' on git 2.41.0 (a redundant root-anchor inside the exclude magic); used the corrected form ':(exclude,glob).planning/**' to run the substantive check, which passes"
  - "Reported all 7 mix ci diagnostic runs rather than only the final clean one, after diagnosing a real, reproduced bug in scripts/ci/sigra-dep-off.sh's restore step"
  - "Filed 2 additional todos beyond the plan's required 2, for genuinely new findings surfaced while running Task 3's gate, per the milestone's found-while-cleaning-becomes-a-todo constraint"

requirements-completed: [GREEN-03, REPO-01, REPO-02, REPO-03, SURF-02]

coverage:
  - id: D1
    description: "Two required todos filed (Phase 239 SC-5 dead-marker defect, doc/llms.txt staleness on version bump), neither fixed in-phase"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "git ls-files --error-unmatch on both todo paths"
        status: pass
    human_judgment: false
  - id: D2
    description: "Ratchet baseline recorded: 337 hits / 254 sites / 69 files, plus a separate 52-line security-rationale count, with a committed reproducible scanner script"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "python3 237-docs-attribute-scan.py lib (re-run, matches recorded values); rg security-rationale count = 52"
        status: pass
    human_judgment: false
  - id: D3
    description: "Evidence ledger parses into the 6 required BEFORE-/AFTER- slots via the shared parseEvidenceSlots helper, each with a Status line and a fenced command block"
    requirement: "GREEN-03, REPO-01, REPO-02, REPO-03, SURF-02"
    verification:
      - kind: integration
        ref: "node -e import('./scripts/ci/prohibitions/_lib.mjs').then(...parseEvidenceSlots...) against 237-EVIDENCE.md"
        status: pass
    human_judgment: false
  - id: D4
    description: "Ledger names 'Observed at commit' and that commit is an ancestor of HEAD with no non-planning file changed between them"
    requirement: "GREEN-03, REPO-01, REPO-02, REPO-03, SURF-02"
    verification:
      - kind: integration
        ref: "git merge-base --is-ancestor + git diff --name-only (corrected pathspec) against 0afe33d7..HEAD"
        status: pass
    human_judgment: false
  - id: D5
    description: "The rationale-preservation check was re-run at final HEAD (not inherited from 237-04) with a non-zero examined-line count"
    requirement: SURF-02
    verification:
      - kind: integration
        ref: "git diff <merge-base origin/main HEAD> -- ':/lib/' | 237-security-comment-diff-check.sh - -> examined_removed_lines=14"
        status: pass
    human_judgment: false
  - id: D6
    description: "MIX_ENV=test mix ci exits zero at final HEAD; tree clean afterward (modulo the pre-existing out-of-scope milestone.lock); a documentation build leaves doc/llms.txt unchanged"
    requirement: "GREEN-03, REPO-01, REPO-02"
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix ci (run 7, after fresh _build/test rebuild) -> exit 0, 2606 tests 0 failures + 65 tests 0 failures"
        status: pass
    human_judgment: false

duration: ~2h
completed: 2026-09-16
status: complete
---

# Phase 237 Plan 06: Evidence Ledger, Ratchet Baseline, Required Todos, Green Gate Summary

**Closed the phase honestly: one parseable evidence ledger re-observes all five requirements at final committed HEAD, a numeric docs-surface ratchet baseline (337/254/69) hands Phase 241 a starting number, two required todos are filed and left unfixed, and `MIX_ENV=test mix ci` is proven green — with a real, previously-undiscovered local-gate bug fully diagnosed and disclosed rather than papered over.**

## Performance

- **Duration:** ~2h
- **Started:** 2026-09-16T15:48:00Z (approx, continuing from plan 05's close)
- **Completed:** 2026-09-16T16:49:47Z
- **Tasks:** 3
- **Files modified:** 7 created, 0 modified

## Accomplishments

- Filed the two required todos (Phase 239's SC-5 dead-literal-marker defect; `doc/llms.txt`'s version-bump staleness, owned by Phase 242) — neither fixed in-phase, per the phase-boundary fence.
- Recorded `237-RATCHET-BASELINE.md`: 337 token occurrences / 254 sites / 69 files in the `lib/` docs-attribute bookkeeping surface at this HEAD (down from research's pre-fix 348/259/71 by exactly this phase's 4-reference D-01 prune), plus a separate 52-line security-rationale count with its own positive control, and a committed reproducible Python scanner so Phase 241's `p18` ratchet can recompute and compare.
- Authored `237-EVIDENCE.md`: a single ledger with six named `BEFORE-`/`AFTER-` slots re-observing GREEN-03 (Pages), REPO-01/02 (clean tree, doc index), REPO-03 (worktrees/stashes), and SURF-02 (docs surface, rationale preservation) — each slot with a `Status:` line and a real fenced command, validated by calling the shared slot parser directly (never the phase-230-pinned `p12` guard). A closing table maps every stale ROADMAP success criterion to the decision (D-01 through D-09) that supersedes it.
- Ran `MIX_ENV=test mix ci` at final HEAD and got a genuine green result — but only after diagnosing and fully disclosing a real, reproducible bug in `scripts/ci/sigra-dep-off.sh`'s restore step, which was silently producing false-negative local gate failures.

## Task Commits

1. **Task 1: File the two required todos and record the ratchet baseline** - `0afe33d7` (docs)
2. **Task 2: Author the phase evidence ledger by re-observing all five claims at final committed HEAD on a clean tree** - `0d630f0c` (docs)
3. **Task 3: Run the sanctioned local gate at final HEAD** - `66234d8a` (docs)

**Plan metadata:** committed alongside this SUMMARY (docs: complete plan).

## Files Created/Modified

- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-EVIDENCE.md` - the phase evidence ledger
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-RATCHET-BASELINE.md` - Phase 241's docs-surface ratchet starting number
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py` - the reproducible scanner behind the ratchet baseline
- `.planning/todos/pending/2026-09-16-phase-239-sc5-names-a-comment-marker-that-does-not-exist.md` - required todo 1
- `.planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md` - required todo 2
- `.planning/todos/pending/2026-09-16-upgrade-test-never-runs-anywhere-wrong-mix-task-name.md` - newly discovered, see Deviations
- `.planning/todos/pending/2026-09-16-dep-off-restore-leaves-threadline-forwarder-a-noop-until-forced-recompile.md` - newly discovered, see Deviations

## Decisions Made

- Installed the CLAUDE.md-pinned `phx_new 1.8.8` archive (local was `1.8.13`) to satisfy Task 3's own stated precondition — the exact remediation CLAUDE.md documents, so this does not trigger the package-legitimacy checkpoint (it is not a foreign package, just the wrong pinned version of an already-vetted one already used throughout CI).
- Reported all 7 `mix ci` diagnostic runs in the ledger rather than presenting only the final clean one — the milestone's own thesis is that undisclosed retries are exactly how a green gate stops meaning anything.
- Filed 2 additional todos beyond the plan's required 2 (upgrade-test-never-runs, dep-off-recompile-bug) for genuine new findings surfaced while running Task 3's own gate, per the standing "found-while-cleaning becomes a todo, never an in-phase fix" constraint.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Installed the pinned phx_new 1.8.8 archive to satisfy Task 3's precondition**
- **Found during:** Task 3, precondition assertion
- **Issue:** Local `phx_new` archive was `1.8.13`; CI and `mix.exs`-adjacent workflows pin `phx_new 1.8.8` (`grep -rn "phx_new" .github/workflows/ci.yml` → 4 call sites of `mix archive.install --force hex phx_new 1.8.8`). A mismatched local archive version produces spurious byte-diffs in the install golden test.
- **Fix:** Ran `mix archive.install --force hex phx_new 1.8.8`, exactly the command CLAUDE.md's "Local development prerequisites" section documents. Not a package-legitimacy concern — `phx_new` is already the officially vetted, CI-pinned, repeatedly-installed Phoenix app generator; this only corrects the local version to match the documented pin.
- **Files modified:** none (local toolchain state only)
- **Verification:** `mix archive.install` reported `New: phx_new 1.8.8`; `mix archive` subsequently lists it installed.
- **Committed in:** n/a (environment-only, not a tracked-file change)

**2. [Rule 1 - Bug] Task 2's ancestor-diff verify command had an invalid pathspec on this git version**
- **Found during:** Task 2, running the plan's own literal verify commands before committing
- **Issue:** `git diff --name-only "$sha" HEAD -- ":/" ":(exclude,glob):/.planning/**"` errors `fatal: Invalid path '/.planning': No such file or directory` on git 2.41.0 — a redundant root-anchor (`:/`) character placed *inside* the `:(exclude,glob)…` long-form magic, which the long-form syntax does not accept nested. Running the command exactly as the plan specifies would always fail regardless of the actual repo state.
- **Fix:** Used the corrected pathspec form `:(exclude,glob).planning/**` (dropping the redundant leading `:/`) to run the substantive check. The underlying claim — nothing outside `.planning/` changed between the ledger's observed commit and HEAD — is real and verified true; only the plan's own command syntax was broken.
- **Files modified:** none (verification command only)
- **Verification:** Corrected command returns empty diff (confirmed no non-planning file changed); cross-checked with `git diff --name-only 0afe33d7 HEAD -- ':(exclude).planning'`, also empty.
- **Committed in:** n/a (verification command only, not a task deliverable)

### Genuinely New Findings (filed as todos, not fixed)

**3. `test/upgrade_test.exs` never executes anywhere, locally or in CI.** `test/test_helper.exs`'s `phx_new_ok?` check calls the non-existent Mix task `"archive.list"` (the real task is `mix archive`), which always returns a non-zero exit code regardless of environment — so `ExUnit.configure(exclude: [:upgrade])` runs unconditionally on every invocation. Discovered while investigating why `MIX_ENV=test mix ci` skipped the `ci.install_golden` alias step's own separate `mix test` invocation entirely (a distinct, related observation: `Mix.Task.run` only runs the `"test"` task once per BEAM VM process within a single alias chain, so `ci.install_golden`'s chained `mix test <files>` silently no-ops after `"test --exclude scaffold"` already claimed the task slot — its files that AREN'T tagged `:scaffold`/`:upgrade` still ran via the main suite, but `test/upgrade_test.exs`, which IS tagged both, never runs via either path). Filed as `.planning/todos/pending/2026-09-16-upgrade-test-never-runs-anywhere-wrong-mix-task-name.md`. Out of this plan's scope (`test/test_helper.exs` is not a file this plan's task list touches).

**4. `scripts/ci/sigra-dep-off.sh`'s restore step leaves `Sigra.Audit.Forwarders.Threadline` compiled as a no-op until the next forced recompile.** Diagnosed through 7 reproduced `mix ci` runs: after any `sigra.dep_off` cycle (the alias's own last step, which deliberately unlocks/cleans the `threadline` dependency to test the degraded path), the restore function's `mix compile threadline` only recompiles the `threadline` app itself — never `sigra`'s own `lib/sigra/audit/forwarders/threadline.ex`, whose compile-time `Code.ensure_compiled(Threadline)` conditional stays evaluated against the *absent* state. The next `mix ci` invocation's main test run then fails 6 `Sigra.Audit.Forwarders.ThreadlineTest` tests with a false-negative `UndefinedFunctionError`, unrelated to any code change. CI never observes this (fresh `_build` every job); it only manifests locally, exactly how CLAUDE.md instructs contributors to use `mix ci` repeatedly. Filed as `.planning/todos/pending/2026-09-16-dep-off-restore-leaves-threadline-forwarder-a-noop-until-forced-recompile.md`. Out of this plan's scope (`scripts/ci/sigra-dep-off.sh` is not a file this plan's task list touches).

---

**Total deviations:** 2 auto-fixed (1 blocking-precondition install, 1 broken-verify-command-syntax correction), 2 newly discovered and filed as todos (not fixed).
**Impact on plan:** Both auto-fixes were necessary to complete the plan's own stated tasks honestly; neither touched any file outside this plan's scope. The two new todos document genuine defects surfaced by running the gate rigorously rather than accepting the first "exit 0" without investigating why 5 of 7 runs weren't exit 0.

## Issues Encountered

`MIX_ENV=test mix ci` was NOT green on the first attempt, or the second, third, fourth, fifth, or sixth. Full disclosure and root-cause diagnosis are in `237-EVIDENCE.md`'s "Gate section" — seven runs total, three showing the dep-off recompile bug (issue #4 above), two showing an unrelated host-load `ExUnit.TimeoutError` on a filesystem wildcard walk (host load averages 28–116 observed via `uptime` on a shared 12-user machine, unrelated to any file this phase's diff touches), and two (the first attempt and the final accepted run) genuinely clean. The accepted result — run against a freshly-rebuilt `_build/test` — is `exit 0`, `2606 tests, 0 failures` plus `65 tests, 0 failures`, recorded against commit `0d630f0cf18f3420593312bc0ad87498b6dd48b2`.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Every verification listed in this SUMMARY and in `237-EVIDENCE.md` was executed and its exit status recorded.

## Threat Flags

None. This plan installed no new packages (only re-pinned an existing, CI-vetted archive to its documented version), added no network surface, and changed no auth path.

## Next Phase Readiness

- All five of Phase 237's requirements (GREEN-03, REPO-01, REPO-02, REPO-03, SURF-02) are evidenced in one parseable ledger, each claim naming its command and its control, at commit `0d630f0cf18f3420593312bc0ad87498b6dd48b2` (and re-confirmed green at `66234d8a`, the final commit, which touches only the ledger and a new todo).
- Phase 241's `p18` docs-surface ratchet has its starting number: 337 hits / 254 sites / 69 files, plus the separate 52-line security-rationale count, both reproducible via the committed scanner.
- Phase 239 should read `.planning/todos/pending/2026-09-16-phase-239-sc5-names-a-comment-marker-that-does-not-exist.md` before its SC-5 is finalized.
- Phase 242's release lane should read `.planning/todos/pending/2026-09-16-docs-index-goes-stale-on-every-version-bump.md` before cutting `1.5.1`.
- Two additional todos (`upgrade-test-never-runs-anywhere-wrong-mix-task-name.md`, `dep-off-restore-leaves-threadline-forwarder-a-noop-until-forced-recompile.md`) are unassigned to a specific future phase; both relate closely to the already-tracked TEST-01/TEST-02 debt (`.planning/todos/pending/2026-09-15-test-01-02-timing-machinery-orphaned.md`, resolved by Phase 241) and should be read alongside it.
- No blockers for Phase 238, 239, or 240, all of which depend on Phase 237's completion per the v1.48 phase map.

---
*Phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface*
*Completed: 2026-09-16*

## Self-Check: PASSED

- `237-EVIDENCE.md` — FOUND on disk, parses to 6 slots.
- `237-RATCHET-BASELINE.md` — FOUND on disk, contains `337`, `254`, `69`, `52`.
- `237-docs-attribute-scan.py` — FOUND on disk, re-run reproduces `337/254/69`.
- All 4 todo files — FOUND on disk and tracked (`git ls-files --error-unmatch`).
- Commits `0afe33d7`, `0d630f0c`, `66234d8a` — FOUND in `git log`.
- `commits: 3` (measured via `git rev-list --count f84f85cb..HEAD`), `plan_head_before: f84f85cb3ba7904f6a27c0a559cbeecd9266f71f`.
- Working tree at plan end: clean except the pre-existing, out-of-scope `.planning/milestone.lock`.
