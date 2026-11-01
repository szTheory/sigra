---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 13
subsystem: testing
tags: [closure-evidence, generated-app, v3-vocabulary, hex-tarball, ci-gate, surf-03]
status: complete

requires:
  - phase: 239-priv-templates-sweep-one-batched-re-bless
    provides: "239-v3-vocabulary-check.sh + 239-v3-allowlist.tsv (frozen, D-16/D-30), the three frozen tier file lists, D-27's SC-2 scope, D-31's re-based T-239-12-03 observation, D-32's created-or-modified generated-app scope, D-33's (basename, literal) exclusion"
provides:
  - "239-EVIDENCE.md § BATCH-3-CLOSURE-OUTCOME — every closure claim re-observed live at the final committed HEAD with its command, its output and its paired control"
  - "239-EVIDENCE.md § HONEST-CLAIMS (plan-239-13 extension) — five named deferrals, each with an owner"
  - "SURF-03 re-checked to [x] with a Complete roll-up row, flipped last and alone"
affects: [phase-239-close, phase-241-SURF-04]

actuals:
  tokens: 5000   # chars/4 over the realized diff (19,976 chars added across 2 files)
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Criterion re-observation over criterion inheritance: every number re-made at the final committed HEAD on a clean tree, with the command recorded next to its output"
    - "Created-or-modified scoping computed by its own mechanism — a bare phx.new baseline app scaffolded with identical name and flags, then per-path `cmp -s` — rather than from a pattern list"
    - "Stale-_build red diagnosed against a documented signature and recovered with `mix deps.compile <dep> --force && mix compile --force`, proven zero-source-change by `git diff --name-only`"

key-files:
  created: []
  modified:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
    - .planning/REQUIREMENTS.md

key-decisions:
  - "The example tier's zero is recorded only with its D-30 scoping and the live-re-measured 482-line / 157-file remainder, owned by Phase 241 SURF-04 — never as a claim about all of test/example/"
  - "Pre-existing gitignored sigra-0.1.0.tar / sigra-0.2.0.tar (April, not authored by this plan) reported rather than deleted; deleting untracked files outside the plan's scope is not a cleanup this plan owns"
  - "The install-smoke probe test is classified as script-authored rather than counted as installer output, so the T-239-12-03 discharge rests on sigra_admin_policy_test.exs by name and not on a bare count of 5"

requirements-completed: [SURF-03]

metrics:
  duration: ~55m
  completed: 2026-09-18
---

# Phase 239 Plan 13: Closure Re-Observation and the SURF-03 Re-check — Summary

Re-proved every criterion the 239-09 … 239-16 closure touched, live at the final committed HEAD
`3230d212` on a clean tree, then re-checked SURF-03 in a commit that carries nothing else.

## What happened

Three tasks, all green, no checkpoint, no deviation that required a decision. This plan had halted
twice before (once on the false `generates no tests` moduledoc claim, once on the unmeetable
generated-app V3 criterion); both defects were repaired by plans 239-14/15 and 239-16 respectively,
and this third run passed every gate on the first attempt except the gate that was expected to be
fragile — `mix ci`, which came back red from a stale `_build` exactly as plan 239-08 had documented
and recovered with zero source changes.

### Task 1 — three tiers, live controls, and the generated app

- **Three-tier V3, GREEN with live controls:** `priv-templates` raw `hits=1` / `allowlisted=1` /
  outside **0** / `control_defmodule=98` / 119 files; `example` 0/0/**0**/2/2; `golden`
  0/0/**0**/78/84. All exit 0. Plan 239-09 demonstrated **outside=2, exit 1** on each of those same
  tiers under the same definition, file lists and allowlist, so the RED/GREEN pair is complete per
  tier. The one raw hit is the allowlisted SVG-coordinate false positive, reported inline.
- **The `example` tier's zero is recorded with its scope in the same sentence.** It is SC-4's two
  mirrored counterparts and nothing else. The remainder was **re-measured live** rather than
  restated: 482 V3-matching lines across 157 files over 344 scanned files — identical to the ledger
  — owned by Phase 241 SURF-04.
- **All eight per-alternation controls re-fired live and non-zero** (4, 11, 2, 3, 4, 6, 13, 1). Two
  read higher than plan 239-09's because `239-CONTEXT.md` and the ROADMAP have grown; reported, not
  smoothed. No alternation is dead, so no instrument regression is reported.
- **SC-1, falsified without any regex this phase put on trial.** `scripts/ci/install-smoke.sh` exit
  0 end-to-end (phx.new 1.8.8, `mix sigra.install`, `--warnings-as-errors`, ecto create+migrate,
  `mix sigra.gen.oauth`, 3/0 probe tests). Fixed-string `grep -rnF` over the generated app's `lib/`
  and `priv/`: sentence 1 → **0**, sentence 2 → **0**, the D-31-retracted `generates no tests` →
  **0**, with a `defmodule` control of **94** and a second control showing the replacement prose
  present at `lib/<web>/live/invitation_accept_live.ex:21`.
- **D-32 scope computed live:** 108 files under `lib/`+`priv/` → **88 in scope**, **20 excluded**,
  by byte comparison against a bare `phx.new` baseline scaffolded with identical name and flags. All
  20 excluded paths enumerated; their 5 V3 hits are exactly the predicted class (4 in
  `page_html/home.html.heex`, 1 in `priv/static/images/logo.svg`). **Halt clause evaluated:**
  `excluded_paths_touched_by_installer=0`, so it does not trip.
- **D-33 grading:** V3 over the 88 in-scope paths gives `hits=1`, `hits_outside_allowlist=1`,
  `control_defmodule=83`. The transcribed `(basename, literal)` derivation, run verbatim against the
  unmodified allowlist with an `awk -F'\t' 'NF>=2'` parse control of 2, yields
  `EXCLUDED oauth_html.ex:54` / `excluded=1 surviving=0`. **Criterion met.** No survivor, so no halt.
- **`T-239-12-03` DISCHARGED** on that generated app: 5 `_test.exs` files (**>= 1**),
  `test/tmp_app/sigra_admin_policy_test.exs` present by name, `*.exs` control **6**. All five are
  enumerated and attributed, so the discharge rests on the installer-authored file rather than on a
  bare count. T19's subject re-confirmed to be the **template** path, read in place at
  `test/example/test/example_web/live/invitation_accept_live_test.exs:581-595`.

### Task 2 — tarball, gate, SC-5

- **Tarball, SC-2 as amended by D-27:** 0 `.planning/` under `lib/`+`priv/` with controls of 258
  `defmodule`-bearing files and 282 files total. Out-of-scope hits enumerated per file: CHANGELOG 43,
  uat-ci-coverage 7, ga-evidence 3, nyquist 3, audit-semantics 1, README 1 — **58 occurrences / 32
  matching lines / 6 files**, reproducing D-27's figure exactly, with both labels kept distinct.
  Owners named (Phase 241 SURF-04 + the plan-239-10 todo). Unpacked tree deleted; tree clean.
- **`MIX_ENV=test mix ci`:** run 1 RED (`rc=2`, six `ThreadlineTest` `attach/1 is undefined`
  failures) — the documented plan-239-08 stale-`_build` signature. Recovered with
  `mix deps.compile threadline --force && mix compile --force`; `git diff --name-only` → **0** source
  changes. Run 2 **exit 0**: 2606 tests / 0 failures, plus the threadline_guard lane 65 / 0.
- **SC-5 at two bases:** `origin/main` (the criterion's, now **89** commits behind local `main` — the
  VERIFICATION's 37 is stale and is reported as such) and `d65e6eb8` (plan-239-08 HEAD, the
  closure's). Both give 0 changed `.github/` paths and 0 moved `name:` lines, each paired with a
  non-empty overall diff control (189 and 40 paths) and a 14-file `.github` pathspec control.
  `237-security-comment-diff-check.sh` over `d65e6eb8..HEAD` exits **0** with
  `examined_removed_lines=15`; the script is byte-unchanged.

### Task 3 — record, then re-check

Evidence committed first (`f6ab7c92`, path-scoped to `239-EVIDENCE.md`, append-only: `525/0` numstat,
zero `-` lines), then SURF-03 flipped to `[x]` with its roll-up row returned to `Complete` in a commit
listing exactly `.planning/REQUIREMENTS.md` (`62a4e10c`). SURF-01 left `[x]`, SURF-04 left `[ ]` /
Phase 241 / Pending.

## Deviations from Plan

**None requiring a rule.** Two things worth recording because they differ from the plan's expectation:

1. **`mix ci` run 1 was RED.** Handled exactly as the plan's SAFETY RULESET prescribes — diagnosed as
   the documented stale-`_build` signature, recovered by forced recompilation, zero source edits, both
   runs captured. Not a deviation; a rehearsed contingency that fired.
2. **Two pre-existing `sigra-*.tar` archives (April, gitignored) sit in the repo root.** Not created
   or touched by this plan. Reported in the evidence with their `git check-ignore` proof and dates
   rather than deleted — removing untracked files this plan did not author is outside its scope, and
   being gitignored they cannot reach a commit, which is what REPO-01 protects against. The task-2
   verify's literal `ls -d sigra-*.tar sigra-*/` clause passes, but only because the non-matching
   `sigra-*/` glob makes `ls` exit non-zero; that pass is explicitly **not** cited as the evidence.

**Ordering note.** The plan's Task 3 criterion required the SURF-03 flip to be the last commit of
the plan, and it was — `CLOSURE_PROVEN` was evaluated with that flip at HEAD, listing exactly
`.planning/REQUIREMENTS.md`. The GSD per-plan metadata commit (this SUMMARY plus STATE/ROADMAP)
necessarily follows it. That commit carries no checkbox and no criterion, so the property the
ordering rule protects — no commit asserting a state that had not yet been observed — is intact.

## Known Stubs

None. This plan wrote no code; its artifacts are an evidence record and a checkbox.

## Deferrals left behind (all named with an owner in § HONEST-CLAIMS)

1. `install_golden_contract` Actions clause — ship-time deferral; nothing pushed, no verdict read.
2. Tarball `lib/` bookkeeping baseline (475 lines / 84 files) — Phase 241 SURF-04's ratchet.
3. Packaged-docs `.planning/` surface (58/32/6) — D-27, Phase 241 SURF-04 + todo.
4. `test/example/` remainder (482/157) incl. IN-06 — D-30, Phase 241 SURF-04 + todo.
5. FUT-01 template↔example parity guard — filed and unbuilt.

Plus, unchanged and not touched by this plan: SURF-02 is `[x]` while not holding at HEAD (Phase
237's; todo filed).

## Self-Check: PASSED

- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md` — FOUND,
  contains `## BATCH-3-CLOSURE-OUTCOME` and the plan-239-13 `## HONEST-CLAIMS` extension.
- `.planning/REQUIREMENTS.md` — FOUND, `- [x] **SURF-03**` and `| SURF-03 | Phase 239 | Complete |`.
- Commit `f6ab7c92` — FOUND (evidence, one path).
- Commit `62a4e10c` — FOUND (SURF-03 re-check, one path, HEAD).
- `git status --porcelain` empty; the plan's Task 3 verify block printed `CLOSURE_PROVEN`.
