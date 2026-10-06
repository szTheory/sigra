---
phase: 236-flake-root-cause-reproduce-name-fix
plan: 04
subsystem: testing
tags: [ci, playwright, evidence-ledger, todo-triage, admin-audit]

requires:
  - phase: 236-flake-root-cause-reproduce-name-fix (plan 01)
    provides: "The exact Path-A reproduction recipe (16 concurrent yes processes, --repeat-each=50, --project=admin-generated) that this plan re-ran unchanged against the fix"
  - phase: 236-flake-root-cause-reproduce-name-fix (plan 02)
    provides: "The lib/ fix (push_patch/<.link patch> ownership on audit_index_live.ex) whose repetition-durability this plan proves"
  - phase: 236-flake-root-cause-reproduce-name-fix (plan 03)
    provides: "The p17 prohibition guard whose RED/GREEN exit codes this plan's AFTER-FIX-GREEN slot cross-references"
provides:
  - "SC-3's GREEN evidence: five sequential pull_request CI runs, all Generated admin Playwright smoke = success, plus a 50/50-pass non-reproducing re-run of the 236-01 repro against the fixed code"
  - "A named deferral (audit_user_live.ex:98, users_index_live.ex:126, plus /admin/audit's own residual chip-remove/pagination anchors) so the phase's scope boundary survives past plan archival"
  - "Two already-resolved todos closed with fresh evidence"
affects: [240, 241]

actuals:
  tokens: 6000
  raw_tokens: 6000
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns:
    - "Reused the already-scaffolded generated host from 236-01 (/tmp/sigra_admin_smoke_236) rather than re-scaffolding — mix deps.compile sigra --force to pick up the path-dependency fix, then reboot"
    - "Chunked a 50-repeat Playwright sweep into 5x10 batches with --reporter=line for harness-liveness streaming, without changing any repro parameter (retry-notice requirement)"

key-files:
  created:
    - .planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md
    - .planning/todos/resolved/2026-07-18-admin-audit-impersonation-filter-not-applying.md
    - .planning/todos/resolved/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md
  modified:
    - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md

key-decisions:
  - "BEFORE-FLAKE-RED's Status was already settled by 236-01 (a real, unprompted CI failure, run 35004420339, discovered mid-session) — this plan's anticipated 'pending vs promote' choice was moot; verified the run still resolves via gh run view and left the slot untouched."
  - "Reused the /tmp/sigra_admin_smoke_236 scaffold from 236-01 rather than re-running mix phx.new/mix sigra.install — the app already carries the SIGRA_REPO path dependency, so mix deps.compile sigra --force picked up the fix with no re-scaffold needed. Faster and proves the exact same host/DB fixture that produced the original 41/50 RED."
  - "Independently re-verified the orchestrator's already-harvested SC-3 run ids and per-job conclusions via a second, separate gh run view/list invocation (not just trusting the orchestrator's report) before writing them into the ledger, since the plan's own verification_discipline forbids trusting a claim without positive re-confirmation."

requirements-completed: [GREEN-01, GREEN-02]

coverage:
  - id: D1
    description: "Five sequential pull_request CI runs on the fix branch, each with Generated admin Playwright smoke = success, none cancelled, harvested from the GitHub Actions API"
    requirement: GREEN-01
    verification:
      - kind: other
        ref: "gh run list --workflow CI --branch gsd/phase-236-flake-root-cause --event pull_request + gh run view <id> --json jobs (independently re-run, bash -c)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The plan 236-01 Path-A reproduction, re-run with byte-identical parameters against the fixed code, produces zero failures of the :459 assertion"
    requirement: GREEN-01
    verification:
      - kind: e2e
        ref: "npx playwright test tests/admin-generated.spec.ts -g \"generated audit presets...\" --project=admin-generated --repeat-each=50 (5x10 batches) --workers=1 --retries=0 --trace=on, under 16-process yes contention — 50 passed, 0 failed"
        status: pass
    human_judgment: false
  - id: D3
    description: "236-EVIDENCE.md carries a parseable AFTER-FIX-GREEN slot in the p12 grammar, with a fenced block invoking a committed instrument, and BEFORE-FLAKE-RED remains correctly captured"
    requirement: GREEN-01
    verification:
      - kind: other
        ref: "node -e parseEvidenceSlots(...) against 236-EVIDENCE.md — both slots parse, captured=true, statusRunIds has 5 ids, hasCommand=true, each id occurs >=2x in body"
        status: pass
      - kind: unit
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs"
        status: pass
    human_judgment: false
  - id: D4
    description: "The GET-form-in-LiveView race deferral is named (not silent), covering both audit_user_live.ex/users_index_live.ex AND /admin/audit's own residual chip-remove/pagination anchors"
    requirement: GREEN-02
    verification:
      - kind: manual_procedural
        ref: ".planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md — file existence + content greps for both file:line pairs and the residual-anchor sentence"
        status: pass
    human_judgment: false
  - id: D5
    description: "Two already-resolved todos closed with file:line evidence; the Phase-240-owned todo left untouched"
    requirement: GREEN-02
    verification:
      - kind: other
        ref: "ls checks on all four todo paths (two resolved present, two pending absent from pending/, Phase-240 todo unchanged)"
        status: pass
    human_judgment: false
  - id: D6
    description: "mix ci and the example test suite are green for this plan's own file scope (planning-only diff)"
    verification:
      - kind: other
        ref: "MIX_ENV=test mix ci (see Known Pre-existing Failure below); (cd test/example && MIX_ENV=test mix test --include example_app) — 334/334 pass"
        status: fail
    human_judgment: true
    rationale: "mix ci's aggregate exit code is non-zero solely because of the same 3 pre-existing phase_235_fast_01_* contract-test failures already documented and filed as a todo by 236-02/236-03 (v1.48 REQUIREMENTS.md rollover predates this phase entirely). Verified this plan's own diff touches only .planning/. A human should confirm this repeat diagnosis is accepted rather than the executor unilaterally judging its own gate green."

duration: ~50min
completed: 2026-09-15
status: complete
---

# Phase 236 Plan 04: Prove Repetition-Durability, Close Bookkeeping Summary

**SC-3's GREEN half is in hand: five sequential pull_request CI runs all pass `Generated admin Playwright smoke`, and the plan 236-01 repro re-run unchanged against the fix produced 50/50 passes (was 41/50 failures pre-fix) — plus a named GET-form-race deferral and two todos closed with fresh evidence.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-09-15 (continuing from a prior stalled attempt that produced no commits)
- **Completed:** 2026-09-15
- **Tasks:** 3 (all `type="auto"`)
- **Files created:** 3 (one new pending todo, two resolved todos)
- **Files modified:** 1 (`236-EVIDENCE.md`)

## Accomplishments

- **Independently re-verified** the orchestrator-harvested SC-3 evidence (part of Task 1 was already dispatched by the orchestrator as a deliberate deviation — see below) via a second, separate `gh run view`/`gh run list` invocation run through `bash -c`: five `pull_request` runs on the fix branch, `Generated admin Playwright smoke` = `success` on all five, none `cancelled`, fifth run's `headSha` (`620991620d9dc93dd0ec2115e92eff67f26885b7`) equal to the then-current committed HEAD on a tree with no uncommitted tracked-file changes.
- **Re-ran the plan 236-01 Path-A reproduction unchanged** against the fixed code — reused the already-scaffolded generated host from 236-01 (`/tmp/sigra_admin_smoke_236`), `mix deps.compile sigra --force` to pick up the fix, rebooted on port 4017, then ran the exact same test/`-g`/`--project`/`--workers`/`--retries`/`--trace` invocation as the RED, chunked into five `--repeat-each=10` batches (streaming liveness accommodation only, per the retry notice — not a parameter change) under the same 16-concurrent-`yes` host CPU contention. **Result: 50 passed, 0 failed, 50 total** — the identical assertion and contention profile that produced 41/50 failures pre-fix now produces zero.
- Added the `AFTER-FIX-GREEN` slot to `236-EVIDENCE.md`: both halves of SC-3 (the five run ids with per-job conclusions, and the non-reproducing repro), plus a positive re-verification that `BEFORE-FLAKE-RED`'s existing `Status: captured (run \`35004420339\`)` was already correctly settled by 236-01 and needed no change. Confirmed the ledger parses via a direct `parseEvidenceSlots` invocation (not `p12`, which is pinned to phase 230's ledger per the verification-discipline note) — both slots `captured`, all five run ids present in the `AFTER-FIX-GREEN` Status line and each occurring ≥2× in the slot body, ≥1 fenced block invoking `gh run`.
- Filed `.planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md`: names the identical GET-form-in-LiveView race on `audit_user_live.ex:98` and `users_index_live.ex:126`, cites the `live_socket.js:1181-1187`/`:247-260` mechanism, the shared-component constraint (`applied_chip` at `components.ex:372`, `audit_pagination_nav` at `:827`), the `users_index_live.ex` `toggle_filters`/`<.quick_filter>` entanglement, AND states plainly, in its own sentence, that `/admin/audit` itself still has three unconverted plain `<a href>` anchors of its own (chip-remove `components.ex:378-380`, prev/next pagination `:841`/`:859`).
- Closed two already-resolved todos with fresh, re-verified evidence: `2026-07-18-admin-audit-impersonation-filter-not-applying.md` (the duplicate-`action_prefix` checkbox chip it describes is gone — `grep -c sg-filter-chip` on the audit surface is `0`, and `admin-generated.spec.ts:444-445` is now that bug's own regression test) and `2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md` (the stale `head_ref` gate it describes is already deleted — `ci.yml:1401-1421` has no `if:` at all). Left `2026-07-30-admin-generated-audit-presets-actor-filter-race.md` untouched in `pending/`, per Phase 240 SC-4's explicit ownership.
- **Did NOT build** the SC-5 quarantine schema amendment — branch (a), not (c), per 236-01's confirmed D-05 call; the `<sc5_contingency_design>` stays specified-only, exactly as the plan's prohibitions require.

## Task Commits

Each task was committed atomically (Task 1's CI-repeat half was pre-committed by the orchestrator; see Deviations):

1. **Task 1 (orchestrator-dispatched half): five empty commits producing the five sequential `pull_request` CI runs** — `8a8dd4d8`, `5aa89630`, `b428e320`, `62099162` (chore) — plus the branch's initial PR-opening commit (not separately re-listed here; see Deviations for full accounting).
2. **Task 1 (executor half) + Task 2: re-run the 236-01 repro unchanged, write the `AFTER-FIX-GREEN` evidence slot** — `19d900fa` (docs)
3. **Task 3: file the deferral todo, close two resolved todos** — `63d01d3e` (docs)

**Plan metadata:** committed alongside this SUMMARY (see below).

## Files Created/Modified

- `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md` — added the `AFTER-FIX-GREEN` slot
- `.planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md` — new named deferral (D-30)
- `.planning/todos/resolved/2026-07-18-admin-audit-impersonation-filter-not-applying.md` — closed (D-31)
- `.planning/todos/resolved/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md` — closed (D-19)

## Decisions Made

See `key-decisions` in frontmatter. Most consequential: reusing the exact `/tmp/sigra_admin_smoke_236` scaffold from 236-01 rather than re-scaffolding a fresh host — this both saved significant time and, more importantly, proves the fix against the literal same fixture (DB, seed data, port, browser projects) that produced the original 41/50 RED, which is a stronger repetition-durability claim than a freshly re-scaffolded host would have been.

## Deviations from Plan

### Process Deviations (recorded per the orchestrator's own `<orchestrator_deviation_READ_FIRST>` instruction)

**1. [Process — orchestrator-driven, not executor deviation] The five sequential `pull_request` CI runs required by SC-3 were driven by the orchestrator before this executor was dispatched.**
- **Found during:** Plan dispatch (documented in the prompt's `<orchestrator_deviation_READ_FIRST>` block).
- **Reason:** Creating a branch, opening PR #242, and pushing five empty commits is outward-facing work the orchestrator owns; an executor looping on multi-minute CI waits burns tokens with no benefit.
- **What was pre-done:** Branch `gsd/phase-236-flake-root-cause` pushed, PR #242 open, five empty commits (`git commit --allow-empty`) producing five sequential `pull_request` CI runs (`35029916498`, `35030710957`, `35031404780`, `35032086557`, `35034938082`), `Generated admin Playwright smoke` = `success` on all five, zero cancellations, final committed HEAD `620991620d9dc93dd0ec2115e92eff67f26885b7` matching run 5's `headSha` on a clean tree.
- **What remained mine:** the second half of SC-3 (the 236-01 repro re-run) and writing the `AFTER-FIX-GREEN` evidence slot (both in Task 2), plus all of Task 3.
- **Verification I performed independently before accepting the orchestrator's claim:** re-ran `gh run list`/`gh run view` myself via `bash -c` (not trusting the orchestrator's report at face value, per this plan's `<verification_discipline>` rule 1) — confirmed the same five run ids, the same `success` conclusions, and the same `headSha`/HEAD match.
- **Impact:** None on plan outcomes. No scope creep — this is exactly the split the orchestrator's own deviation note describes, and my independent re-verification closes the gap between "trusting a report" and "the ledger's own evidence."

**2. [Process — retry notice compliance] A prior executor attempt on this plan stalled with zero progress and produced zero commits/SUMMARY.**
- **Found during:** Plan dispatch (documented in the prompt's `<retry_notice>`).
- **Reason:** A stream-liveness watchdog fired during the prior attempt's initial verification reads, before any commit was made. The orchestrator reconciled the repo to a clean state before dispatching this attempt — nothing was half-done.
- **Fix applied in this attempt:** chunked the 50-repeat Playwright reproduction sweep into five `--repeat-each=10` batches with `--reporter=line`, echoing a progress summary between each batch, exactly as the retry notice specified. Reproduction parameters (test, `-g` filter, `--project`, `--workers`, `--retries`, `--trace`, the 16-process `yes` contention) were kept byte-identical to 236-01's — only the invocation was chunked for harness liveness, never the parameters themselves.
- **Impact:** None on evidence validity — five separately-invoked 10-repeat batches under continuous, unbroken CPU contention are the same 50-attempt sweep the RED used, just observed in five slices instead of one.

**3. [Rule 1 - Bug, environmental] Stale threadline compile artifact caused 9 spurious test failures on the first `mix ci` attempt.**
- **Found during:** Task 3's `MIX_ENV=test mix ci` run.
- **Issue:** Identical to the issue already documented in 236-02's and 236-03's SUMMARYs — the conditionally-compiled `Threadline` module had gone stale in `_build/test` relative to the `threadline` dependency, producing `UndefinedFunctionError` on `Sigra.Audit.Forwarders.Threadline.attach/1` in unrelated tests.
- **Fix:** `MIX_ENV=test mix deps.compile threadline --force && MIX_ENV=test mix compile --force`, matching the documented resolution. No source change.
- **Files modified:** none (build artifact only).
- **Verification:** Re-ran `mix ci`; the threadline failures did not recur (dropped from 9 to the expected 3 pre-existing failures below).

No Rule 2/4 deviations occurred — this plan produces planning/evidence artifacts only, no application code.

---

**Total deviations:** 2 process deviations (orchestrator-driven CI harvest, chunked-sweep liveness accommodation), 1 environmental Rule 1 fix (threadline recompile), 0 Rule 2/4 deviations.
**Impact on plan:** None on scope or evidentiary strength — all task-level acceptance criteria were independently re-verified regardless of who ran the CI harvest.

## Known Pre-existing Failure (out of scope, documented not fixed — third consecutive plan to hit this)

`MIX_ENV=test mix ci`'s aggregate exit code is non-zero because of the same 3 pre-existing, unrelated failures already documented by 236-02 and 236-03: `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` and `phase_235_fast_01_gap_closure_contract_test.exs` assert `.planning/REQUIREMENTS.md` marks `FAST-01`/`GATE-05` (v1.47 CI-EFFICIENCY IDs) as `[x]` complete, but `REQUIREMENTS.md` was replaced wholesale for v1.48 at `cc6f17e4`, well before this plan or Phase 236 began.

**Confirmed pre-existing and unrelated to this plan's diff:**
- `git log --oneline -1 -- test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` → `cc4835c5` (v1.47 close-out) — unchanged by this plan.
- `git log --oneline -1 -- .planning/REQUIREMENTS.md` → `206c1209` (236-03's own p17/p18 renumber, not this plan).
- This plan's own diff touches only `.planning/` (`todos/` moves and `236-EVIDENCE.md`), verified via `git status --short` after every commit.

**Not fixed here:** already tracked at `.planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md`, filed by 236-02. Fixing it here would be an in-phase found-while-cleaning fix, which standing constraint 4 forbids — the phase's single pre-authorized exception was already spent on the `lib/` product race.

**Everything else in `mix ci` passes:** `format --check-formatted`, `deps.get --check-locked`, `deps.unlock --check-unused`, `compile --warnings-as-errors`, the full ExUnit suite except those 3 (2606 total, 3 failures, 12 skipped, 22 excluded), `ci.install_golden` (65/65 pass). `test/example`'s ExUnit suite: 334/334 pass.

## Issues Encountered

None beyond the two documented items above (both resolved before proceeding, neither left open).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- ROADMAP SC-3 is satisfied at the stated n=5: `Generated admin Playwright smoke` passed every repeat, and the Criterion-1 reproduction no longer reproduces, both observed from the GitHub Actions API and a byte-identical local re-run.
- SC-5's contingency remains specified-only, not built — branch (c) was never observed across any of plans 01-04.
- Every deferral in the phase is now named: the `audit_user_live.ex`/`users_index_live.ex` GET-form race, plus `/admin/audit`'s own residual chip-remove/pagination anchors, in one todo that will survive plan archival.
- Phase 240 (GREEN-04/GREEN-05) can proceed on its n≥20 green-main proof — its owned todo (`2026-07-30-...`) is untouched.
- Phase 241 (`p18`-renamed SURF-04, `.github/ci-skip-manifest.tsv` schema) has a moving target no longer at risk — SC-5 was not built speculatively.
- **Open item carried forward from 236-02/236-03, now confirmed a third time:** `main`'s literal `mix ci` gate is red for a reason no plan in Phase 236 owns (the v1.48 `REQUIREMENTS.md` rollover). This is worth surfacing before the milestone's GREEN objective is declared closed, even though it did not block any of this phase's four plans.
- PR #242 (branch `gsd/phase-236-flake-root-cause`) carries all of Phase 236's work and is ready for the orchestrator's next action (push these commits, then human/ship review).

## Self-Check: PASSED

- `test -f .planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md` → FOUND
- `test -f .planning/todos/resolved/2026-07-18-admin-audit-impersonation-filter-not-applying.md` → FOUND
- `test -f .planning/todos/resolved/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md` → FOUND
- `git log --oneline --all | grep -q 19d900fa` → FOUND
- `git log --oneline --all | grep -q 63d01d3e` → FOUND
- `node -e "parseEvidenceSlots(...)"` against `236-EVIDENCE.md` → `BEFORE-FLAKE-RED,AFTER-P17-GUARD-OBSERVED,AFTER-FIX-GREEN` all parse; `AFTER-FIX-GREEN` carries 5 distinct run ids, each occurring ≥2× in body, ≥1 fenced `gh run` block
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` → 71/71 pass
- `gh run view 35029916498/35030710957/35031404780/35032086557/35034938082 --json jobs` → all 5 `Generated admin Playwright smoke` = `success` (independently re-verified via `bash -c`)
- `git status --short` (post Task 3 commit) → clean except pre-existing untracked `.gsd/`, `.planning/milestone.lock`
- `(cd test/example && MIX_ENV=test mix test --include example_app)` → 334/334 pass
- `ls .planning/todos/pending/ | grep -E '2026-07-18-admin-audit-impersonation|2026-07-28-generated-host-parity'` → exit 1, no match (both correctly absent from `pending/`)
- `ls .planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md` → FOUND, unchanged

---
*Phase: 236-flake-root-cause-reproduce-name-fix*
*Completed: 2026-09-15*
