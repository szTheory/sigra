---
phase: 236-flake-root-cause-reproduce-name-fix
plan: 01
subsystem: testing
tags: [playwright, liveview, flake, ci, admin-audit]

requires: []
provides:
  - "A captured, falsifiable RED for `admin-generated.spec.ts:459` (`toHaveURL(actor=...)`), recorded with both a real CI run ID and a local, openable trace.zip"
  - "A written differential diagnosis naming the cause as a product race in `AuditIndexLive`'s filter form, with the D-05 branch call resolved to (a)"
  - "Developer confirmation of branch (a), unblocking plan 236-02's fix shape exactly as written and authorizing plan 236-03 to proceed"
affects: [236-02, 236-03, 236-04]

actuals:
  tokens: 78000
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Evidence-ledger BEFORE-*/AFTER-* slot format (`parseEvidenceSlots`) reused for a single-slot local+CI reproduction record"
    - "Real, unprompted CI failure treated as primary SC-1 evidence when it occurs during evidence-gathering, corroborated by a local from-scratch reproduction rather than accepted alone"

key-files:
  created:
    - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md
    - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-DIAGNOSIS.md
    - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-SUMMARY.md
  modified: []

key-decisions:
  - "D-05 branch call: (a) — `actor=` is absent from the URL entirely (not present-and-empty) in both the real CI failure (run 35004420339) and the local reproduction, confirming D-01's product-race hypothesis and authorizing plan 236-02 to proceed exactly as written."
  - "A real, unprompted CI failure discovered mid-session (run 35004420339, a `push` to `main`) was adopted as the primary SC-1 evidence rather than relying solely on a synthetic local repro, because it independently corroborates the identical received-URL signature on the real production topology."
  - "Local reproduction required genuine host-OS CPU contention (17 concurrent `yes` processes), not CDP-level network/CPU throttling, to manifest the race — recorded in `236-EVIDENCE.md`'s Discarded Attempts section so the difficulty is visible rather than papered over."
  - "Tasks 1 and 2 landed in a single commit (`f400fa15`) rather than two: the RED capture and the ledger/diagnosis write-up were produced as one continuous investigative pass once the real CI failure was found, and splitting them post hoc would have meant committing an intermediate ledger stub that was never actually the working state."

requirements-completed: [GREEN-01]

coverage:
  - id: D1
    description: "A falsifiable RED for the flaky assertion is captured with a real CI run ID and a real, openable local trace.zip, recorded in a machine-parseable evidence ledger"
    requirement: "GREEN-01"
    verification:
      - kind: other
        ref: "node -e \"parseEvidenceSlots(...)\" against 236-EVIDENCE.md — BEFORE-FLAKE-RED slot parses"
        status: pass
      - kind: other
        ref: "node --test scripts/ci/prohibitions/p12-run-id-provenance.test.mjs"
        status: pass
      - kind: manual_procedural
        ref: "npx playwright show-trace .gsd/scratch/phase236-evidence/trace.zip"
        status: pass
    human_judgment: false
  - id: D2
    description: "A written differential diagnosis names the cause as exactly one of harness race / DB collision / product race, rules out the other two with cited observations, and records the D-05 branch call"
    requirement: "GREEN-01"
    verification:
      - kind: other
        ref: "grep-based acceptance criteria in 236-01-PLAN.md Task 2 (named-cause count, unload() line citations, zero-hit phrasing, branch-call line) — all re-run and passing"
        status: pass
    human_judgment: true
    rationale: "The diagnosis's technical correctness (whether the cited unload()/destroyAllViews() mechanism genuinely explains the observed race) is a judgment call about a novel-to-this-repo LiveView JS code path, not something a grep can fully validate. The developer independently re-read live_socket.js:247-260 and :1181-1198 and confirmed the mechanism matches before approving the checkpoint."
  - id: D3
    description: "Developer confirms the D-05 branch letter, authorizing (or halting) downstream plans"
    verification:
      - kind: manual_procedural
        ref: "Checkpoint:decision — developer confirmed branch (a) via the orchestrator, citing independent re-verification of commit f400fa15, git status on lib/ and playwright.config.ts/tests/, trace.zip size, audit_index_live.ex:76 source, and live_socket.js:247-260/:1181-1198"
        status: pass
    human_judgment: true
    rationale: "This is precisely the kind of decision `checkpoint:decision` exists for — branches (b)/(c) would have invalidated the already-written plan 236-02, so auto-selection was never appropriate regardless of how strong the evidence looked."

duration: 2h 15min
completed: 2026-09-15
status: complete
---

# Phase 236 Plan 01: Reproduce, Name, Fix (Task 1-2) Summary

**Reproduced the `admin-generated.spec.ts:459` flake two independent ways — a real, unprompted CI failure and a local, openable trace.zip — and named the cause as a product race in LiveView's `unload()` one-way latch racing a plain `<form method="get">`'s native submit; developer confirmed D-05 branch (a).**

## Performance

- **Duration:** 2h 15min
- **Tasks:** 3 (2 auto/tracer tasks committed together, 1 checkpoint:decision resolved by the developer)
- **Files created:** 3 (`236-EVIDENCE.md`, `236-DIAGNOSIS.md`, this SUMMARY)

## Accomplishments

- Captured a genuine RED for GREEN-01/SC-1: the exact `toHaveURL(actor=...)` assertion at `admin-generated.spec.ts:459` failed with an identical received-URL signature (`actor=` completely absent) in both a real, unprompted GitHub Actions CI run (`35004420339`, job `104500542292`, a `push` to `main` discovered mid-session) and a from-scratch local reproduction that produced a real, openable `trace.zip` (41/50 failures under genuine host CPU contention, after 60-80+ throttled attempts at normal/CDP-throttled load produced zero failures — see "Reproduction difficulty" below).
- Wrote `236-EVIDENCE.md`: a single `BEFORE-FLAKE-RED` slot recording both captures, parsing cleanly under `parseEvidenceSlots` and passing `p12-run-id-provenance`'s enforced status grammar and command-provenance checks.
- Wrote `236-DIAGNOSIS.md`: named the cause as a **product race** — LiveView's global `submit` listener (`live_socket.js:1181-1198`) calls the one-way-latch `unload()` (`live_socket.js:247-260`, via `destroyAllViews()`) whenever a form has no `phx-submit` binding, which is exactly `AuditIndexLive`'s filter form (`audit_index_live.ex:76`); under host CPU contention this teardown races the browser's own pending native GET-submission and wins, silently dropping the navigation entirely. Ruled out harness race, DB collision, and connect-patch value-wipe each with a cited observation. Stated both plan-mandated honesty constraints verbatim (the `admin-audit.spec.ts` control drives a different LiveView with a button-click and explicit readiness wait, not an Enter-press; `push_patch` is 0-hit in `lib/` but `<.link patch>` is not, per `branding_live.ex:128,136,144`).
- Developer confirmed D-05 branch **(a)** at the Task 3 checkpoint, after the orchestrator independently re-verified: commit `f400fa15`'s existence, `git status --porcelain lib/` clean against a positive control, `playwright.config.ts`/`tests/` byte-unchanged vs the dispatch base `160de093`, the trace.zip's exact byte size, `audit_index_live.ex:76`'s zero `phx-*` bindings against a positive control, and the `live_socket.js` mechanism read verbatim. Wave 2 (plans 236-02, 236-03) is unblocked.

## Task Commits

1. **Tasks 1+2: Capture the RED and write 236-EVIDENCE.md / 236-DIAGNOSIS.md** — `f400fa15` (docs) — see "Deviations" for why these two tasks share one commit.
2. **Task 3: Branch call checkpoint** — no commit (a `checkpoint:decision`; the decision itself is recorded in this SUMMARY's frontmatter and body, not as a separate code/doc commit).

**Plan metadata:** committed alongside this SUMMARY (see below).

## Files Created/Modified

- `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md` — evidence ledger with the `BEFORE-FLAKE-RED` slot (real CI run + local trace.zip)
- `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-DIAGNOSIS.md` — differential diagnosis naming the product race and recording the D-05 branch call
- `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-SUMMARY.md` — this file

No files under `lib/` were modified (verified `git status --porcelain lib/` clean before and after all work, per the plan's hard prohibition), and `test/example/priv/playwright/playwright.config.ts` plus every `tests/*.spec.ts` file are byte-unchanged (Path A was used throughout; no temporary `trace: 'on'` edit to the config was needed).

## Decisions Made

See `key-decisions` in frontmatter. The most consequential: the D-05 branch call is **(a)**, confirmed independently by both the automated evidence and the developer's explicit checkpoint confirmation, which unblocks plan 236-02 exactly as written and means the SC-5 quarantine contingency (`<sc5_contingency_design>` in plan 236-04) is **not** built — that path is reserved for branch (c) only, which was not observed.

## Reproduction difficulty (recorded for honesty, not a deviation)

Task 1's local reproduction was substantially harder than the plan anticipated. 30 attempts on a
cold (asset-compiling) host produced 10 failures, but all were `waitForLiveViewReady` timeouts at
line 433 (a boot-warmup artifact) — correctly discarded per the plan's own "do not record a
passing run as the RED" instruction, extended here to "do not record a differently-located
failure as the RED" either. Subsequent 40/60/80-attempt sweeps on a warm host, including under
CDP-level CPU throttling (up to 12x) and network latency (up to 400ms) and a `page.routeWebSocket`
delay forcing LiveView's `longPollFallbackMs` fallback, produced **zero** failures of the target
assertion. The race only manifested once genuine host-OS CPU contention was introduced (17
concurrent `yes > /dev/null` processes on an 18-core machine), which is when a real, unprompted CI
failure of the identical assertion was also independently observed on `main` — both discovered in
the same working session. This is recorded in `236-EVIDENCE.md`'s "Discarded attempts" section so
a future reader does not assume the race reproduces trivially with `--repeat-each=30` alone, as
D-21's phrasing might suggest.

## Deviations from Plan

### Auto-fixed / Process Deviations

**1. [Process — not a Rule 1-4 deviation] Tasks 1 and 2 committed together as `f400fa15` instead of two separate commits.**
- **Found during:** Task 2, after the real CI failure was discovered mid-Task-1.
- **Reason:** Task 1's deliverable (the captured RED — an absolute trace path, repeat index, and
  received URL "in hand") and Task 2's deliverable (the same facts written into a parseable
  ledger plus the diagnosis) became a single continuous write once the CI evidence was found;
  there was no meaningful intermediate "ledger stub" state to commit separately, and manufacturing
  one post hoc would have meant committing a file that was never the actual working state.
- **Impact:** None on plan outcomes — both tasks' acceptance criteria were independently verified
  (see Task Commits and Accomplishments above) before the single commit was made. No scope creep.

No Rule 1-4 deviations (bugs, missing critical functionality, blocking issues, or architectural
changes) occurred — this plan produces planning/evidence artifacts only, no application code.

---

**Total deviations:** 1 process deviation (commit granularity), 0 Rule 1-4 deviations.
**Impact on plan:** None — all task-level acceptance criteria were verified independently
regardless of commit boundaries.

## Scratch artifact disposition (housekeeping)

All reproduction driver scripts and captured attempt data are **disposable local scratch, not
durable instruments**, and none are committed:

- Three throwaway Node/Playwright driver scripts (`repro-driver.mjs`, a second CDP-throttling
  variant, and a debug script) were created transiently under
  `test/example/priv/playwright/` during Task 1 to experiment with CDP throttling and
  `page.routeWebSocket` delays. **All three were deleted** before Task 1's commit
  (`git status --porcelain test/example/priv/playwright/` is clean; confirmed again now). None of
  them produced the winning reproduction — genuine host-OS CPU contention via a plain shell loop
  (`for i in $(seq 1 16); do yes > /dev/null & done`) did, using the **already-existing**,
  uncommitted-infrastructure-required `npx playwright test ... --repeat-each --trace=on` invocation
  (Path A). No new committed harness was built or is needed, consistent with this milestone's
  standing guidance not to build new repeat-run machinery.
- `.gsd/scratch/` contains the boot script used to scaffold the generated host
  (`boot_host.sh`), captured logs, the 200+ individual local reproduction attempt directories
  (traces/screenshots/videos from the throttling experiments), and the persisted copy of the one
  winning `trace.zip` + `error-context.md` cited in `236-EVIDENCE.md`. This directory is untracked
  (matches the pre-existing `.gsd/` harness-state convention already present before this plan
  started) and is **not intended to be committed** — it is working-session scratch, not a project
  artifact. If plan 236-04 needs a durable, re-runnable instrument to cite (rather than the
  local trace.zip path), that would be new work for 236-04 to scope explicitly — nothing here is a
  candidate to promote as-is, since these are one-off experiments (most of which failed to
  reproduce the race) rather than a designed tool.
- Downloaded CI artifacts (`generated-admin-failure-diagnostics`, `generated-admin-report` for run
  `35004420339`) are cached locally under `.gsd/scratch/ci-artifacts/` for convenience; the durable
  copy of this evidence is the GitHub Actions run itself (`35004420339`), which `236-EVIDENCE.md`
  cites by run ID and job ID, not by local path.

## Issues Encountered

None beyond the reproduction difficulty documented above, which was resolved (not left open).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 236-02 (the `lib/` fix: `<.link patch>` conversions + `phx-submit="apply_filters"` +
  `handle_event/3` → `push_patch/2`) is unblocked and authorized to proceed exactly as written —
  branch (a) confirmed, D-08 through D-14 all apply unmodified.
- Plan 236-03 (the `p17` prohibition guard + dead `PLAYWRIGHT_RETRIES` env var deletion) is
  unblocked and branch-independent, as it always was.
- The SC-5 quarantine contingency (`<sc5_contingency_design>`, plan 236-04) is **not** built —
  branch (c) was not observed, and building it speculatively would hand plan 241 a moving target
  per the plan's own closed-question rationale.
- No blockers for wave 2.

## Self-Check: PASSED

- `test -f .planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md` → FOUND
- `test -f .planning/phases/236-flake-root-cause-reproduce-name-fix/236-DIAGNOSIS.md` → FOUND
- `git log --oneline --all | grep -q f400fa15` → FOUND
- `node -e "parseEvidenceSlots(...)"` against `236-EVIDENCE.md` → `BEFORE-FLAKE-RED` slot parses
- `node --test scripts/ci/prohibitions/p12-run-id-provenance.test.mjs` → 6/6 pass
- `git status --porcelain lib/ test/example/priv/playwright/playwright.config.ts` → clean
- `npx playwright show-trace .gsd/scratch/phase236-evidence/trace.zip` → opens (2,005,798 bytes, non-empty)

---
*Phase: 236-flake-root-cause-reproduce-name-fix*
*Completed: 2026-09-15*
