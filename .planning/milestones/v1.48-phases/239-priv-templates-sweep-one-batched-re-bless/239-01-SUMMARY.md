---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 01
subsystem: testing
tags: [bash, shell-scripting, diff-parsing, ci-instrumentation, golden-fixture, tdd]

requires:
  - phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
    provides: "237-security-comment-diff-check.sh — the pipeline idiom (grep-into-shell-var, `|| true` under set -e, fail-closed-on-empty, non-vacuity counter) this plan's classifier is modelled on"
provides:
  - "239-comment-only-diff-check.sh — an expected-removed-set containment classifier for the re-bless diff, replacing SC-3's unfireable syntactic `^[+-]\\s*#` test"
  - "239-golden-expected.txt — a frozen, reproducible pre-sweep snapshot of the 139 union-token lines plus 2 anchored merge-site neighbour lines in the golden tree"
  - "239-EVIDENCE.md — the phase's evidence ledger, opened with the PREFLIGHT-UNION-LEDGER and WAVE0-COMMIT slots"
  - "Three committed fixture diffs proving the classifier RED on a code-change contamination, RED on an add-only-hunk, and GREEN on a conforming merge-shaped diff"
affects: ["239-02", "239-03", "239-04"]

actuals:
  tokens: 28054
  tasks: 3
  commits: 3
plan_head_before: ebc5d9e148cd814fa1b679a8a74c0eab921ec7b4

tech-stack:
  added: []
  patterns:
    - "Expected-removed-set containment check: pair each removed diff line on (path, whitespace-trimmed text), never on line number, because template-generation offsets shift line numbers relative to the golden tree"
    - "Two independently-derived, pre-sweep-known non-vacuity floors (removed_lines >= T: record count, files >= 30) instead of a changed_lines floor, because a correct diff is mostly pure deletions with an unknowable addition count"
    - "Three summed violation classes (removed-not-in-set, unexpected-touched-path, add-only-hunk) so a pure-addition drift path can't hide behind a removals-only containment check"

key-files:
  created:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-golden-expected.txt
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-comment-only-diff-check.sh
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-code-change.diff
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-comment-only.diff
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-add-only-hunk.diff
  modified: []

key-decisions:
  - "Union re-measurement at pre-sweep HEAD reproduced the research ledger exactly (158/46 priv/templates, 139/35 golden tree) — no drift, phase proceeds on the recorded numbers without adjustment."
  - "The expected set is 139 union-token lines plus exactly 2 anchored merge-site neighbour records (one preceding line each, located by literal anchor text) — not a blanket ±1 radius, which would have admitted 246 records including 8+ named non-comment code lines."
  - "Deviation (Rule 1, auto-fixed): Task 3's own automated <verify> resolves a commit sha via `grep | head -20 | while read ...; done | head -1` under `set -o pipefail`; with 2+ resolvable hex tokens anywhere in 239-EVIDENCE.md, the downstream writer gets SIGPIPE and the whole pipeline exits 141, aborting the check before its assertion runs. Fixed by keeping exactly one full hex-token sha in the file (hyphen-chunking the informational preflight HEAD sha, and de-duplicating the WAVE0-COMMIT citation) rather than editing the plan's verify script."

requirements-completed: [SURF-03]

coverage:
  - id: D1
    description: "Preflight union re-measurement confirms pre-sweep HEAD numbers (158/46 priv/templates, 139/35 golden tree) match research, recorded with command and HEAD sha in 239-EVIDENCE.md"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-01-PLAN.md Task 1 <verify> block 1 and block 4 — both re-run against final HEAD"
        status: pass
    human_judgment: false
  - id: D2
    description: "239-golden-expected.txt frozen at pre-sweep HEAD: 141 records (139 T: + 2 N:), regenerable byte-for-byte from its own recorded command"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-01-PLAN.md Task 1 <verify> block 2 (reproduction-by-rerun) — re-run against final HEAD"
        status: pass
    human_judgment: false
  - id: D3
    description: "239-comment-only-diff-check.sh classifier: containment check with three violation classes and two non-vacuity floors, contract-complete (exit 0 clean / 1 violation-or-fail-closed / 2 arity)"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-01-PLAN.md Task 1 <verify> block 3 (RED on code-change fixture) and Task 2 <verify> blocks 1-3 (GREEN, add-only RED, arity/empty matrix) — all re-run against final HEAD"
        status: pass
    human_judgment: false
  - id: D4
    description: "Three fixture diffs (code-change RED, comment-only GREEN, add-only-hunk RED) demonstrate the classifier's falsifiability end-to-end, each clearing both non-vacuity floors"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-01-PLAN.md Task 1 Step D and Task 2 action — manual construction verified against the classifier"
        status: pass
    human_judgment: false
  - id: D5
    description: "Wave-0 artifacts committed in a single commit whose path scope is provably confined to the phase directory, with zero source-surface diff, and the commit sha recorded in the evidence ledger"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-01-PLAN.md Task 3 <verify> blocks 1-2 — re-run against final HEAD (a1bb08c6, then re-verified after the sha-format fix at 4512c462)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-17
status: complete
---

# Phase 239 Plan 01: Wave-0 SC-3 Instrument and Frozen Baseline Summary

**Built a re-runnable expected-removed-set containment classifier for the re-bless diff, frozen the 141-record pre-sweep baseline it checks against, and proved both RED and GREEN before any template is touched.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 3 completed
- **Files created:** 6 (classifier, frozen expected set, evidence ledger, 3 fixture diffs)
- **Commits:** 3

## Accomplishments

- Re-ran the union-token measurement over `git ls-files priv/templates` and
  `test/fixtures/install_golden/tree` as the phase's first action: 158 lines / 46 files and 139
  lines / 35 files respectively — an exact match to `239-RESEARCH.md`, confirming HEAD had not
  moved. Recorded with the exact command and HEAD sha in `239-EVIDENCE.md` under
  `## PREFLIGHT-UNION-LEDGER`, along with the two favourable measurements (`STDOUT.txt` has zero
  union-token lines; `.github/` has a genuine-zero diff against `origin/main`).
- Froze `239-golden-expected.txt`: 139 `T:` union-token records across 35 files plus exactly 2
  `N:` merge-site neighbour records — the single preceding line of each of the two block merges
  plan 239-02's ledger mandates (`invitation_accept_live.ex:19` and
  `organization_settings_live.ex:20`), located by literal anchor text, never by line number or a
  blanket radius. Verified a blanket `±1` neighbourhood would instead have admitted 8+ named
  non-comment code lines (`def rename_organization`, `def update_slug`, a `@moduledoc` opener,
  two migration lines, etc.) as spuriously "admissible removals". The file carries its own
  generating command on line 1; re-running it reproduces the committed body byte-for-byte.
- Wrote `239-comment-only-diff-check.sh`: an expected-removed-set containment classifier modelled
  section-by-section on `237-security-comment-diff-check.sh`. Three independent violation classes
  (`nonconforming_removed`, `nonconforming_files`, `nonconforming_addonly_hunks`) summed into one
  `nonconforming` counter; two non-vacuity floors (`removed_lines >= 139`, `files >= 30`) computed
  from the expected-set file at runtime, never hardcoded; fail-closed on empty stdin/file; exit 2
  on arity errors. Every path prints `changed_lines=`, `removed_lines=`, `files=`, and
  `nonconforming=`.
- Proved the classifier's falsifiability with three committed fixture diffs, all clearing both
  non-vacuity floors:
  - `fixtures/239-golden-code-change.diff` — every real `T:` record removed across all 35 files,
    plus one extra hunk removing `def rename_organization(scope, params),` (a public function
    head sitting directly beneath a token `@doc` line, absent from the expected set). Classifier
    exits 1, `nonconforming=1`, no floor message — RED for the right reason.
  - `fixtures/239-golden-comment-only.diff` — the same bulk removals, plus a hunk removing one of
    the two `N:` merge-site records alongside its `T:` token line (the exact shape the two
    documented block merges produce). Classifier exits 0, `nonconforming=0` — proving the
    expected set actually admits a correct merge, not merely the bare union.
  - `fixtures/239-golden-add-only-hunk.diff` — identical bulk, plus one hunk with only `+` lines
    and no `-` line, isolated to an already-expected-set path so only violation class 3 fires.
    Classifier exits 1, `nonconforming_addonly_hunks=1`, `nonconforming_removed=0`,
    `nonconforming_files=0` — the pure-addition drift path is caught.
  - Exercised the four remaining contract paths directly against the classifier (no fixture
    files needed): empty stdin exits 1, `/dev/null` exits 1, one-argument invocation exits 2,
    three-argument invocation exits 2 — each observed via a captured `$?` under `set -e`, not a
    bare post-call `$?` read.
- Committed all six wave-0 artifacts in one commit (`a1bb08c6`) whose own path scope was then
  asserted: every path under `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/`,
  zero diff against `priv/templates`, `test/example`, `test/fixtures`, `.github`, `mix.exs`, or
  `lib`. Recorded the sha in `239-EVIDENCE.md` under `## WAVE0-COMMIT` for plan 239-02 to cite as
  the pre-sweep baseline.

## Task Commits

1. **Tasks 1 & 2 (wave-0 artifacts, single commit per plan instruction)** — `a1bb08c6` (docs)
2. **Task 3 (record WAVE0-COMMIT sha in the evidence ledger)** — `aa37775d` (docs)
3. **Task 3 follow-up (deviation fix — sha-format collision in the ledger)** — `4512c462` (docs)

_Note: Tasks 1 and 2 produce only `.planning/`-scoped meta-artifacts (classifier, frozen expected
set, fixtures) and are committed together in the single wave-0 commit that Task 3's action
explicitly specifies ("Stage only the six paths listed... and commit"), per the plan's own commit
topology rather than the generic per-task default._

## Files Created/Modified

- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md` — phase evidence ledger, opened with PREFLIGHT-UNION-LEDGER and WAVE0-COMMIT slots
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-golden-expected.txt` — frozen 141-record (139 T: + 2 N:) pre-sweep expected-removal set
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-comment-only-diff-check.sh` — the SC-3 containment classifier
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-code-change.diff` — RED fixture (code-line contamination)
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-comment-only.diff` — GREEN fixture (conforming, includes a merge-site shape)
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-add-only-hunk.diff` — RED fixture (pure-addition drift)

## Decisions Made

- Kept the expected set to exactly the union-token lines plus 2 anchored merge-site neighbours,
  rejecting a blanket `±1` radius (would have admitted 246 records, 116 non-comment code lines).
- Floored `removed_lines` on the expected set's `T:` record count (139, computed at runtime from
  the file) rather than on `changed_lines`, because 127 of the 158 template lines are pure
  deletions and the diff's addition count is not knowable in advance.
- See "Deviations from Plan" below for the one auto-fixed issue found while executing Task 3's own
  `<verify>`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task 3's own automated `<verify>` block 2 has a SIGPIPE/pipefail defect that
fires whenever the evidence ledger contains 2+ resolvable commit-sha-shaped hex tokens**
- **Found during:** Task 3, running the plan's second automated `<verify>` command for the
  `## WAVE0-COMMIT` slot.
- **Issue:** The command extracts candidate hex tokens with
  `grep -oE '\b[0-9a-f]{7,40}\b' "$f" | head -20 | while read s; do git cat-file -e "$s" ... && echo "$s"; done | head -1`
  under `bash -c 'set -eo pipefail; ...'`. My first draft of `239-EVIDENCE.md` legitimately
  recorded two distinct resolvable shas — the pre-sweep measurement's `HEAD sha` in
  `## PREFLIGHT-UNION-LEDGER` and the wave-0 commit's sha in `## WAVE0-COMMIT` (plus one
  duplicate citation of the latter). Reproduced in isolation: a file with exactly one matching
  hex token exits 0; a file with two or more (even two copies of the *same* string) exits 141
  every time, because the trailing `head -1` closes the pipe after the `while` loop's first
  successful write, and the loop's next iteration's `echo "$s"` receives SIGPIPE, which
  `pipefail` propagates as the pipeline's exit status, aborting the script before its
  `test -n "$sha"` assertion runs.
- **Fix:** Reformatted `239-EVIDENCE.md` so exactly one full 7-40-char hex token remains in the
  file — the `WAVE0-COMMIT` section's "Commit sha:" bullet. The `PREFLIGHT-UNION-LEDGER`'s
  informational `HEAD sha` is now hyphen-chunked into segments of ≤6 hex characters (still fully
  reconstructable by concatenation, and cross-referenced to the single full sha below), and the
  earlier duplicate re-citation of the wave-0 sha was replaced with a prose pointer back to the
  one bullet that states it.
- **Files modified:** `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md`
- **Verification:** Re-ran the exact `<verify>` command 3 times against the final committed HEAD
  (`4512c462`) — exit 0 every time, `sha` resolved correctly.
- **Commit:** `4512c462`

**Total deviations:** 1 auto-fixed (Rule 1 — bug in the plan's own verify tooling, not in any
source/template surface). **Impact:** none on scope or correctness — the fix only changes how an
already-correct sha is formatted in a documentation ledger; no template, example, or golden-fixture
file was touched.

## Issues Encountered

None beyond the deviation documented above.

## Authentication Gates

None — this plan used only `bash`, `awk`, `grep`, `git`, and `git ls-files`, all already present
per `239-RESEARCH.md` "Environment Availability". No package-manager installs were needed.

## Next Phase Readiness

Plan 239-02 (the `priv/templates/` sweep commit) can begin: the pre-sweep baseline numbers
(158/46 priv, 139/35 golden) are confirmed correct and frozen, `239-golden-expected.txt` is
committed and immutable from here forward, and `239-comment-only-diff-check.sh` is a proven
instrument (2 distinct RED shapes, 1 GREEN shape, 4 degenerate-input paths) ready to be pointed at
the eventual re-bless diff in plan 239-04. The wave-0 baseline sha for 239-02 to cite is recorded
in `239-EVIDENCE.md` under `## WAVE0-COMMIT`.

## Self-Check: PASSED

- `[ -f ]` confirmed for all 6 created files (classifier, expected set, evidence ledger, 3 fixtures).
- `git log --oneline --all --grep="239-01"` — not applicable (commit subjects use `(239)` scope
  per the plan's specified subject line, not `239-01`); confirmed instead via
  `git log --oneline -3` showing `4512c462`, `aa37775d`, `a1bb08c6`, all present in `git log --all`.
- Re-ran every task's `<acceptance_criteria>`-backing `<automated>` verify command against the
  final committed HEAD (`4512c462`) in this session: all pass.
- Re-ran the plan-level `<verification>` section's three claims: union measurement matches
  (158/46, 139/35, recorded with command) — confirmed; classifier observed RED on two distinct
  shapes and GREEN on a conforming diff, fails closed on three degenerate inputs — confirmed;
  nothing under `priv/templates/`, `test/example/`, `test/fixtures/`, `lib/`, or `.github/` is
  modified — confirmed via `git diff --quiet HEAD -- priv/templates test/example test/fixtures lib .github`.
