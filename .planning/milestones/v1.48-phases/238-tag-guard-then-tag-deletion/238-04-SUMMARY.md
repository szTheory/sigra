---
phase: 238-tag-guard-then-tag-deletion
plan: 04
subsystem: infra
tags: [git, tags, rulesets, operator-script, tsv-manifest, destructive-safety]

requires:
  - phase: 238-02
    provides: "the live tag-namespace ruleset, and the AFTER-DELETE-PROBE verdict that ref deletion is NOT governed by it (no enforcement flip window required)"
provides:
  - ".planning/decisions/003-tag-delete-list.tsv — the committed 39-row explicit delete-set, with per-side presence flags and pre-deletion commit SHAs"
  - "scripts/maintainers/delete-planning-tags.sh — dry-run-by-default, one-literal-tag-per-delete operator script with four separate passes"
  - "scratch-clone observations proving adjacency-safety, idempotency, emptiness-vs-zero-row, vacuity refusal and failure propagation before anything real is deleted"
affects: [238-05, 238-06, 245]

actuals:
  tokens: 8236
  tasks: 3
  commits: 2
  plan_head_before: 47cdaf2adbbd996553fedde99fecce946c1fde54

tech-stack:
  added: []
  patterns:
    - "Destructive operator script inverts the repo's mutate-by-default idiom: reporting is the default, --apply is required"
    - "Committed TSV as the single oracle for a destructive set; prose and script both render it"
    - "Allowlist path override (--allowlist) so malformed-input safety paths are testable without editing the real data file"

key-files:
  created:
    - .planning/decisions/003-tag-delete-list.tsv
    - scripts/maintainers/delete-planning-tags.sh
  modified: []

key-decisions:
  - "pre_delete_sha carries the COMMIT each annotated tag wraps (Phase 245 needs commit reachability); the tag-object names are preserved in the file's comment header so that information is not lost with the refs"
  - "The delete call sites are written as bare `git tag -d \"$tag\"` / `git push origin --delete \"$tag\"` after a single `cd \"$ROOT\"`, rather than `git -C \"$ROOT\" …`, so a reader (and the plan's call-site scan) sees the destructive verb with no path indirection in between"
  - "The remote pass does not pre-refuse on an enforcement window: 238-02 observed deletion is unaffected by the ruleset, so a GH013 rejection is treated as live-ruleset drift and aborts with the flip instruction printed, rather than being assumed up front"

patterns-established:
  - "Non-vacuity floor before every set comparison, with the repo's 'the parse broke, this is not a pass' message"
  - "Absence is a skip; any other non-zero delete status aborts the pass with a snake_case reason code"

requirements-completed: [REL-02]

coverage:
  - id: D1
    description: "The delete set exists as a committed 39-row tab-separated allowlist derived from the live repository, with independent local/remote presence flags, class, pre-deletion SHA and a per-row reason"
    requirement: "REL-02"
    verification:
      - kind: other
        ref: "task 1 verify 1 — header row exactly the six named columns, 39 rows parsed, zero rows with the wrong column count"
        status: pass
      - kind: other
        ref: "task 1 verify 2 — 0 rows match the release or archive expressions; 0 rows are neither two-component nor phase-proof"
        status: pass
      - kind: other
        ref: "task 1 verify 3 — 39 rows visited, 60 presence branches entered (39 local + 21 remote), every claim matched the live listing, 39 resolvable SHAs"
        status: pass
    human_judgment: false
  - id: D2
    description: "The deletion script is dry-run by default, refuses unknown arguments, parses the allowlist fail-closed, and can never express a glob at a delete call site"
    requirement: "REL-02"
    verification:
      - kind: other
        ref: "task 2 verify 1-2 — bash -n clean; `--frobnicate` aborts non-zero with a named reason"
        status: pass
      - kind: other
        ref: "task 2 verify 3 — bare `local` and `remote` invocations leave both the local (52) and remote (33) listings byte-identical while still printing a per-row report"
        status: pass
      - kind: other
        ref: "task 2 verify 4 — zero-row allowlist aborts with allowlist_parsed_zero_rows; --allowlist documented in the usage block"
        status: pass
      - kind: other
        ref: "task 2 verify 5 — 4 delete call sites matched, 0 carrying a shell pattern metacharacter"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every destructive edge behavior is observed on a disposable clone: prefix-collision adjacency, idempotency, emptiness vs zero-row, vacuity refusal, failure propagation — and nothing real was deleted"
    requirement: "REL-02"
    verification:
      - kind: integration
        ref: "task 3 verify 1 — scratch clone 52→13 tags; v1.0 deleted, v1.0.0 still resolves to 5f036bcc; second apply exits zero with 39 absent; verify-local passes"
        status: pass
      - kind: integration
        ref: "task 3 verify 2 — zero-row abort, absent-only allowlist exits zero, tagless repo aborts with 'the parse broke', read-only .git aborts with local_delete_failed leaving all 52 clone tags intact"
        status: pass
      - kind: other
        ref: "task 3 verify 3 — leak scan, 60 presence branches entered, 0 leaks; working repo still 52 local / 33 remote tags"
        status: pass
      - kind: other
        ref: "task 3 verify 4 — 3 executable sort invocations outside comments; both artifacts tracked and the working tree clean in scripts/maintainers and .planning/decisions"
        status: pass
    human_judgment: false

duration: 25 min
completed: 2026-09-17
status: complete
---

# Phase 238 Plan 04: Tag-deletion machinery, built and proven harmless Summary

**A committed 39-row TSV delete-set plus a dry-run-by-default operator script whose destructive paths were exercised end-to-end in a disposable clone — 52 tags to 13 there, zero refs touched here.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-17T13:27Z (plan HEAD `47cdaf2a`)
- **Completed:** 2026-09-17T13:52Z
- **Tasks:** 3
- **Files created:** 2

## Accomplishments

- **The delete set is reviewable data, derived from the live repository.** 39 rows: 28 two-component `vX.Y` planning tags and 11 `phase-238-*` proof tags. Local/remote flags were read independently from `git tag` and `git ls-remote --tags origin` — 39 rows are local, 21 are on origin, and the 18-row gap is exactly the local-only subset the remote pass must skip. The partition closes on both sides with nothing unclassified: allowlist rows ∪ regex keep-set reproduces `git tag` (52) and origin's listing (33) exactly.
- **The prefix-collision footgun is impossible by construction, and that was demonstrated rather than argued.** In a scratch clone an applied local pass deleted `v1.0` and left `v1.0.0` resolving to the same object (`5f036bcc8eb1be74e2f646a1c90787a50f531148`) it resolved to before the pass. `v1.0.0` backs a published GitHub Release and a published Hex package.
- **The script's safety properties were observed, not asserted:** a bare invocation mutates nothing; an unknown argument hard-exits; a zero-row or headerless or wrong-width allowlist aborts with a named reason; a tagless repository refuses to report a clean comparison of two empty sets; a delete that fails for any reason other than absence aborts the pass on the first row with a non-zero exit.
- **Nothing real was deleted.** The working repository still holds 52 tags and origin still holds 33 — verified after all scratch work, with the scan reporting the 60 presence branches it entered so it cannot pass vacuously.

## Task Commits

1. **Task 1: pre-deletion ref inventory and the committed allowlist** — `781d27cc` (docs)
2. **Task 2: the dry-run-by-default deletion script** — `6db17704` (feat)
3. **Task 3: prove the edge behaviors before anything is destroyed** — no commit; this task mutates nothing in the repository by design (its own verify block asserts the working tree is clean in `scripts/maintainers` and `.planning/decisions`). Its record is this SUMMARY.

**Plan metadata:** see the `docs(238-04)` commit carrying this file.

## Files Created/Modified

- `.planning/decisions/003-tag-delete-list.tsv` — the delete-set oracle. Comment header carries the why block, the exclusion rule, the consumers block (the script, ADR 003, Phase 245), the capture command, and the annotated tag-object names; then the six-column header row and 39 data rows.
- `scripts/maintainers/delete-planning-tags.sh` — four passes (`local`, `verify-local`, `remote`, `verify-remote`), exactly one per invocation; `--apply` to mutate; `--allowlist PATH` to point at a fixture.

## Scratch-clone observations (task 3, the phase's sole sanctioned deliberate-deletion site)

Both clones were made with `mktemp -d` + `git clone --no-hardlinks file://$PWD`, their `origin` was asserted **not** to resolve to GitHub before any destructive command (a `file://` URL pointing at this working repository, in both cases), only the local pass and the local verification were ever run in them, and both temp trees were removed afterwards.

**Adjacency (the load-bearing one).** Clone carried 52 tags. The pair search found `v1.0` (an allowlist row) with its three-component neighbour `v1.0.0` also resolving, so the case is real rather than vacuous. Neighbour object before the pass: `5f036bcc8eb1be74e2f646a1c90787a50f531148`.

```
$ bash <clone>/scripts/maintainers/delete-planning-tags.sh local --apply
  …
  deleted v1.48
delete-planning-tags: local pass done — deleted=39 absent=0 would_delete=0
```

After the pass: `refs/tags/v1.0` does not resolve; `refs/tags/v1.0.0` resolves, and to the same object. Clone tag count 52 → 13.

**Idempotency.** The second applied pass in the same clone:

```
  absent  v1.48 (already gone locally; skipped, not an error)
delete-planning-tags: local pass done — deleted=0 absent=39 would_delete=0
```

Exit 0, every row reported absent, neighbour untouched, and `verify-local` still green afterwards:

```
delete-planning-tags: local listing=13 keep-set=13 (keep expression: ^(v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?|archive/.*)$)
delete-planning-tags: local set-equal to its regex-derived keep-set
```

**Emptiness vs a zero-row parse — two different outcomes, both through `--allowlist`.**

```
$ bash <clone>/…/delete-planning-tags.sh local --apply --allowlist <fixture>/zero.tsv     # header only
delete-planning-tags: FAIL: allowlist_parsed_zero_rows: …/zero.tsv yielded no data rows — the parse broke, this is not a pass   (exit 1)

$ bash <clone>/…/delete-planning-tags.sh local --apply --allowlist <fixture>/absent.tsv   # one row naming a tag that does not exist
  absent  no-such-tag-238 (already gone locally; skipped, not an error)
delete-planning-tags: local pass done — deleted=0 absent=1 would_delete=0                 (exit 0)
```

**Vacuity.** A freshly `git init`'d repository carrying only the script and the allowlist, no tags:

```
delete-planning-tags: local listing=0 keep-set=0 (keep expression: …)
delete-planning-tags: FAIL: local_listing_empty: the parse broke, this is not a pass      (exit 1)
```

Two empty sets do not compare equal here — the positive control fires first.

**Failure propagation.** `chmod -R a-w <clone>/.git`, then the applied local pass:

```
delete-planning-tags: FAIL: local_delete_failed: phase-238-generated-auth-proof-68c9d632: error: could not delete reference
  refs/tags/phase-238-generated-auth-proof-68c9d632: Unable to create '…/.git/packed-refs.lock': Permission denied      (exit 1)
```

It aborted on the **first** row rather than continuing or reporting a no-op; the clone still held all 52 tags afterwards. Permissions were restored and the tree removed.

**No leak.** After all of the above, in the working repository: 52 local tags, 33 remote tags, every `local=yes` row still resolving locally and every `remote=yes` row still resolving on origin, leak scan entering 60 presence branches.

## Decisions Made

- **`pre_delete_sha` holds the dereferenced commit.** All 39 delete-set tags are annotated, so `%(objectname)` is a tag object and `%(*objectname)` is the commit. Phase 245 needs the commit to stay reachable, so that is the column's value; the tag-object names are recorded in the comment header rather than dropped, because they too stop existing when the refs go.
- **Delete call sites carry no `-C` indirection.** A single `cd "$ROOT"` after preflight means the destructive lines read exactly `git tag -d "$tag"` and `git push origin --delete "$tag"`. This was a correction made during task 2 (see Deviations).
- **The remote pass does not open with a refusal.** 238-02's `AFTER-DELETE-PROBE` observed a `v*`-scoped tag deleting cleanly with the ruleset `active`, so no flip window is required. A GH013 on the remote pass therefore means the live ruleset changed since that observation; the script prints that reasoning and the flip procedure and then aborts with `remote_delete_failed`, rather than silently retrying or assuming a window is needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Delete call sites were invisible to the plan's own call-site scan**

- **Found during:** Task 2 (running the plan's fifth verify block)
- **Issue:** The script originally used `git -C "$ROOT" tag -d` / `git -C "$ROOT" push origin --delete`. The plan's scan regex is `git (tag -d|update-ref -d|push .*--delete)`, which the `-C "$ROOT"` interposition defeats — the scan found only 1 site (a header comment) and correctly failed as vacuous.
- **Fix:** Resolve the repository root, preflight, then `cd "$ROOT"` once and use plain `git` for every subsequent invocation, so the destructive verbs are written with no indirection. Added a comment at the `cd` saying why. Also resolved `--allowlist` against the caller's cwd *before* the `cd`, so a relative override still means what the operator typed.
- **Files modified:** `scripts/maintainers/delete-planning-tags.sh`
- **Verification:** the call-site scan now reports `n=4 bad=0`; all five task-2 verify blocks re-run green.
- **Committed in:** `6db17704` (Task 2 commit)

**2. [Rule 3 - Blocking] macOS `grep` has no `-P`**

- **Found during:** Task 1 (the TSV generator's SHA lookup)
- **Issue:** The generator used `grep -P "^\Q$t\E\t"` to pull a tag's row out of the `for-each-ref` capture; BSD grep rejects `-P`.
- **Fix:** Replaced with an `awk -F'\t' -v n="$t" '$1==n{print $3}'` exact-field lookup. Generator-only change — the generator is scratch, not a committed artifact; the committed TSV is its output.
- **Files modified:** none in the repository (scratch generator only)
- **Verification:** regenerated the TSV cleanly; all three task-1 verify blocks green.
- **Committed in:** n/a (the corrected output is in `781d27cc`)

### Procedural deviations (stated plainly, not smoothed over)

- **Task 3 produced no commit.** The plan asks for an atomic commit per task, but task 3 is observation-only and its own verify block asserts the working tree is *clean* in the two artifact paths. Committing anything for it would have failed its own gate. The observations are recorded in this SUMMARY and committed with it.
- **Commits were made directly on `main`.** The executor's generic pre-commit assertion treats the default branch as protected and `git.allow_default_branch_commits` is not set in `.planning/config.json`. The orchestrator's pin degrades isolation to `none` and pins `main` explicitly, `git.branching_strategy` is `"none"`, and 238-01…238-03 all landed on `main` the same way. Stated here rather than left implicit.
- **`mix ci` was not run.** This plan touches no Elixir and nothing was pushed. CLAUDE.md requires `mix ci` before a push; the push is not this plan's to make.

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking), plus 3 procedural deviations stated above.
**Impact on plan:** No scope change. Both auto-fixes were required to satisfy the plan's own verify blocks on this platform.

## Issues Encountered

None beyond the deviations above. Every gate in the plan was run as written and passed as written; no gate was modified to make it pass.

## Assertions NOT proven here (honest limits)

- **The remote delete path has never been executed.** Its reporting mode was exercised against the real origin listing (21 rows, `would_delete=21`, nothing touched), but no `git push origin --delete` has ever run from this script. The scratch clone's `origin` is the working repository, so running the remote pass there would have deleted real refs — the plan forbids it and it was not run. 238-05 is the first execution of that path.
- **Order-independence is proven behaviorally, bounded structurally.** The deciding evidence is that `verify-local` passes in the clone after the applied pass, which an order-dependent comparison cannot survive. The structural count (3 executable `sort` invocations outside comments, two of which are the comparison's operands) is a backstop that narrows how that green could have been reached; it does not by itself prove those invocations *are* the operands.
- **`archive/` keep-behavior on the remote side is untested by observation.** The remote keep expression deliberately omits `archive/` because that namespace never reached origin; that asymmetry is asserted from the live listing (0 `archive/` tags on origin) rather than exercised by a `verify-remote` run against a post-deletion remote. 238-05 runs it.

## User Setup Required

None.

## Next Phase Readiness

- 238-05 can run the four passes in order: `local --apply` → `verify-local` → `remote --apply` → `verify-remote`, as four separate invocations. No enforcement flip window is required (238-02 `AFTER-DELETE-PROBE`).
- 238-06's ADR amendment should cite `.planning/decisions/003-tag-delete-list.tsv` — a path that survives the milestone-close move of `.planning/phases/` — and correct guardrail 3's claim that milestone tagging stopped at `v1.35` (`v1.47` and `v1.48` were minted after ADR 003's date; both rows say so).
- Phase 245 has its forward-feed: every deleted object's commit SHA is in the `pre_delete_sha` column before the branch holding the phase-proof tags is considered for pruning.

---
*Phase: 238-tag-guard-then-tag-deletion*
*Completed: 2026-09-17*

## Self-Check: PASSED

- Created files present on disk: `.planning/decisions/003-tag-delete-list.tsv`, `scripts/maintainers/delete-planning-tags.sh`.
- Task commits present in history: `781d27cc`, `6db17704`.
- Working repository ref state unchanged by this plan: 52 local tags, 33 remote tags.
