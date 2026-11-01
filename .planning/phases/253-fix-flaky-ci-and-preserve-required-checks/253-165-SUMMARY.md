---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "165"
subsystem: ci-reliability
status: complete
tags: [ci-reliability, load-recovery, pagination, pr-proof, r13, r14, r15, red-first]
requires: ["253-164 (complete)", "253-146 Task 1 pagination rule", "253-155 full offline gates"]
provides:
  - "dry-run --paged-listings: two-page run_jobs and run_artifacts listings for the full-pass run, in the mode's link form"
  - "paged_listing() helper and DryRunPagedListingsTests (82-test full dry-run suite)"
  - "PR World flags paged_listings (two-page attempt_jobs and run_artifacts) and pr_head_checks (a >100 PR head)"
  - "PrPaginatedListingsTests: live-policy and hermetic PR universes, and the fail-closed one-page PR-head check bound"
affects: ["253-166", "253-167", "253-168", "253-169", "253-170", "253-171", "253-172"]
tech-stack:
  added: []
  patterns: ["opt-in fake paging flag, default off", "one shared transport pagination rule proven per route by fakes"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-gate-canary-dryrun.py
    - scripts/ci/ci-gate-canary-dryrun.test.py
    - scripts/ci/ci-pr-proof.test.sh
key-decisions:
  - "The 253-146 pagination rule already covered run_jobs, run_artifacts and attempt_jobs in both link forms. No transport, driver, verifier or collector change was needed."
  - "The PR-head native check_runs read stays one page. A 101-run head is refused by the verifier (check_run_page_set) with 'native check-run response is incomplete or needs another charged page' after exactly one check_runs request. Recorded as an R13 unobserved shape for 253-167; not widened here."
requirements-completed: []
estimate: {tokens: 40000, tasks: 2}
actuals:
  tokens: 9500
  tasks: 2
  commits: 4
commits: 4
plan_head_before: 8514ed9abec36b7bd306352a54c00e7944501198
plan_head_after: b210be31a9a7003cdd0d7c2611e1f6dc1b618bec
duration: "about 1h55m (04:58Z to 06:53Z on 2026-10-20), mostly the 81-minute Task 1 verify block"
completed: 2026-10-20
---

# Phase 253 Plan 165: Paginated jobs, artifacts and PR listings under the one /repositories/<id>/ rule Summary

**The canary dry-run gains an opt-in `--paged-listings` flag that splits the full-pass run's jobs and artifacts listings over two pages. In live-policy mode the next link uses GitHub's `/repositories/1207487684/` form; in hermetic mode it uses the local `/repos/` form. Both modes pass end to end, and the 253-146 transport rule needed no change. The PR universe proves the same for attempt_jobs and run_artifacts inside the unchanged production table. A PR head with 101 check runs fails closed after one check_runs request.**

There were zero GitHub requests, fetches or pushes, and no native Playwright launch.

## Precondition (Task 1): met
- The 253-164 SUMMARY is `status: complete`. The 253-155 and 253-146 SUMMARYs are `status: halted`.
- PRESERVATION-R13 passed `shasum -c --quiet`.
- The tree was clean except config.json (sha256 8e312f6c…0b8d). state.json is 70229 B, sha256 prefix e45278c2cee0.
- R15 deadline guard, margin 1 (exit 0): `R13 canary deadline guard: margin 1 d, projected check_runs pages 4 of 10, canary deadline 2026-11-02T19:18:40.000Z`
- Positive control, margin 20 (exit 1, as required): `R13 canary deadline guard: margin 20 d, projected check_runs pages 14 of 10, canary deadline 2026-11-02T19:18:40.000Z`
- At SUMMARY time the guard printed the same margin-1 line again.

## Task 1: --paged-listings (RED ecb5d22d0, GREEN 840c7f4a4)

### RED
Command: `python3 scripts/ci/ci-gate-canary-dryrun.test.py DryRunPagedListingsTests`, 05:00Z.
Result: `Ran 4 tests in 0.689s`, `FAILED (failures=4, errors=2)`. Subtests count separately.
- **live and hermetic gates:** runner printed no JSON summary, with `error: unrecognized arguments: --paged-listings`.
- **refusal test (both subtests):** `'--paged-listings cannot be combined with --repos-link-form' not found` in the argparse usage error.
- **fake page-split test (both forms):** `AttributeError: module ... has no attribute 'paged_listing'`.

### GREEN (ci-gate-canary-dryrun.py only)
- **Module helper:** `paged_listing(body, key, page, base)`. Page 1 holds the first half, rounded up, and page 2 the rest. Both pages carry the unpaged total_count. Page 1's Link is rel next+last; page 2's is rel prev+first.
- **Page 2 routing:** `_paged` accepts page 2 on the run_jobs and run_artifacts routes only when `server.paged_listings` is on (max_page 2). Otherwise it stays at 1.
- **Listing replies:** `_jobs` and `_artifacts` reply through `_listing_reply`. It pages only the full-pass run's listing, only with the flag, and only when the listing has at least 2 items. Every other case is the one unpaged page, as before, and a page 2 request there is refused with 404.
- **`_listing_link_base`:** in live-policy mode, `https://api.github.com/repositories/1207487684/actions/runs/<id>/{jobs|artifacts}`. In hermetic mode, the local origin's `/repos/szTheory/sigra/...` form.
- **New keyword:** `start_fake(..., paged_listings=False)`.
- **Parser:** a new `--paged-listings` flag, default off. `parser.error("--paged-listings cannot be combined with --repos-link-form")` runs before the 253-164 scope check.
- **Summary keys:** no summary key was added. The test asserts the default run's key set equals the paged run's key set.
- **No product change:** the transport, driver and verifier are unchanged (diff-asserted against 89b8c8618, the 253-146/155 base commit).
- **Audit:** the R13 audit checker reported no moved anchor, so the audit record was not touched.

### DryRunPagedListingsTests (4 tests)
- **live-policy gate:** passes. paginated_reads has run_jobs and run_artifacts with pages 2 and form repositories-id, and check_runs with pages 3. attempt_jobs and artifact_metadata stay within the canary table (7 each), preflight is 7, and shim_refusals, violations, blob_with and api_without are all zero. In the same test, the default (no-flag) run has the same summary keys and route/category counts minus exactly one page on each listing (requests_total +2).
- **hermetic gate:** the same checks in the `repos` form.
- **fake helper:** the two pages concatenate to the unpaged job listing, total_count is the same on both pages, and the exact Link strings are checked in both forms.
- **refusal:** `--paged-listings` together with `--repos-link-form` exits nonzero with the literal message, both with and without the knob's full scope.

### paginated_reads of the two --paged-listings runs (r12 pair, r8..r11 seeds, --stop-after full-pass, committed HEAD 840c7f4a4)
```
live-policy: status passed; [{check_runs, pages 3, [repositories-id]}, {run_jobs, pages 2, [repositories-id]}, {run_artifacts, pages 2, [repositories-id]}]; attempt_jobs 2, artifact_metadata 2, preflight 7, blob_with 0
hermetic:    status passed; [{check_runs, pages 3, [repos]}, {run_jobs, pages 2, [repos]}, {run_artifacts, pages 2, [repos]}]; attempt_jobs 2, artifact_metadata 2, preflight 7, blob_with 0
```

### Task 1 verify block (long-run protocol)
- **Run:** in the background under `caffeinate -i -s`, power `Now drawing from 'AC Power'`, start 2026-10-20T05:08:43Z, end 06:29:35Z. It ran once and was not interrupted. **VERIFY-EXIT 0.**
- **DryRunPagedListingsTests:** `Ran 4 tests in 357.273s`, `OK`.
- **R15-FULL-SUITE (full dry-run suite, no filter):** **`Ran 82 tests in 4375.693s`** and **`OK`**, against a gate of 79 or more.
- **ci-hermetic-live-audit:** `Ran 54 tests in 35.730s`, `OK`.
- **Remaining checks:** the paged live run's jq predicate, both refusal greps, the 253-146 base commit positive control (89b8c8618 found), the transport/driver/verifier no-diff check, PRESERVATION-R13, config.json sha and the clean tree all passed.

## Task 2: PR collector on two-page listings (RED 69978462e, GREEN b210be31a)

### RED
Command: `bash scripts/ci/ci-pr-proof.test.sh`, 06:35Z to 06:39Z, with the tests committed and the fake options absent.
Result: `Ran 103 tests in 259.058s`, `FAILED (failures=3)`. The other 100 tests passed.
- **live-policy paged test:** `Lists differ: [1] != [1, 2]`. attempt_jobs was one page because the World option was absent.
- **hermetic paged test:** `Lists differ: [1] != [1, 2]`.
- **101-check head:** `Tuples differ: (6, 6) != (101, 100)`. The head served its default 6 checks.

No failure came from inside the collector or the verifier, so there was no collector finding.

### GREEN (ci-pr-proof.test.sh only)
- **`PRHandler._listing`:** with the `paged_listings` flag, the normal family's attempt_jobs and run_artifacts listings are two pages. Page 1 holds the first half, rounded up, and both pages carry the full total_count. Page 1 has rel next/last, page 2 rel prev/first. Without the flag, the reply is exactly `{"total_count": n, key: items}` as before.
- **`PRHandler._link_base`:** the local `https://localhost:<port>/repos/szTheory/sigra/...` form. `LivePRHandler._link_base` gives `https://api.github.com/repositories/1207487684/...` for the same route suffix.
- **`PRHandler._oversized_checks` (flag `pr_head_checks`):** page 1 holds the family's checks, so every required name is on it, followed by unrelated fillers up to 100 runs. It reports total_count 101 and carries GitHub's rel next/last header.
- **Helper `paged_r12_world`:** a live-policy r12 universe with the r8..r11 seeds and main_record, or a hermetic r12 universe.

### PrPaginatedListingsTests (3 tests)
- **live-policy:**
  - The normal family's attempt_jobs and run_artifacts are pages [1, 2]. Page 1's next destination starts `/repositories/1207487684/actions/runs/7001/`, and page 2 has no next link.
  - Every request URL stays on `/repos/szTheory/sigra/actions/runs/7001/`.
  - The two pages concatenate to the whole listing.
  - The server journal holds only `/repos/szTheory/sigra/`, `/rate_limit` and `/blob/` paths, with no `/repositories/` path.
  - Counts: attempt_jobs 3 of 4 and artifact_metadata 3 of 4 (normal 2 + docs-only 1). Every category is within PRODUCTION_CATEGORY_LIMITS, there are 120 or fewer requests, and one check_runs request per family.
  - The shim refused nothing and there were no violations.
  - The verifier reported `synthetic_pr_family_verified` (normal) and `synthetic_pr_pair_verified` (both).
- **hermetic:** the same checks in the local /repos/ form. `verify_pr_pair` reported `synthetic_pr_pair_verified` with the independent journal.
- **101-check head:** exactly one check_runs request (page_ordinal 1), with body total_count 101 and 100 runs. GitHub's rel next was present, which is the positive control that a second page was advertised. Every required name is on page 1, and no `page=2` check-runs request reached the fake.
  - `verify_pr_family` raised `native check-run response is incomplete or needs another charged page`, and the server journal grew by zero requests after the stop.
  - Positive control: a default r12 universe (6 check runs) verified its one check page.

Counts printed by the tests (identical in both modes):
```
253-165 live paged counts: {"artifact_downloads": 20, "artifact_metadata": 3, "attempt_jobs": 3, "docs_publication": 14, "native_checks": 2, "pr_create": 2, "pr_identity": 8, "pre_watch_rate": 2, "preflight": 4, "run_discovery": 4, "terminal_polls": 6}
253-165 head-101: collector exit 0, stop None, routes after check_runs ['run_artifacts', 'artifact_zip' x10]
```

### Collector finding (recorded, no fix)
- **Where the stop happens:** for a >100 PR head, the stop is in the independent verifier (`verify_pr_family` → `hydrate_effective_checks` → `check_run_page_set`), not in the collector.
- **What the collector does:** it reads the single check page (a `one`-mode jcall, by design) and continues to its artifact tail (run_artifacts plus 10 artifact_zip hops), ending `collected` with exit 0.
- **Why this is fail-closed:** the family can never verify, and no second check_runs request is made.
- **Why no fix here:** this is not a mishandled two-page listing, so the plan permits no ci-pr-proof.sh change. ci-pr-proof.sh is unchanged.
- **Hand-off:** 253-167 should list this as an R13 unobserved shape, together with its stop.

### Task 2 verify block
- **Run:** in the background under `caffeinate -i -s` on AC power, from 06:45:49Z to 06:50:47Z. **VERIFY-EXIT 0.**
- **ci-pr-proof.test.sh:** `Ran 103 tests in 262.793s`, `OK`.
- **ci-hermetic-live-audit:** `Ran 54 tests`, `OK`.
- **Remaining checks:** both greps, the transport/verifier/publisher no-diff check, the category-table grep, PRESERVATION-R13, config.json sha and the clean tree all passed.

## Audit rows
None changed. The R13 audit checker passed after each GREEN change and reported no moved or stale anchor. `253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R13.json` is byte-unchanged.

## Commits
- ecb5d22d0: test(253-165): two-page job and artifact listings in the /repositories/<id>/ form (RED)
- 840c7f4a4: feat(253-165): dry-run --paged-listings proves the shared pagination rule on jobs and artifacts
- 69978462e: test(253-165): PR listings over two /repositories/<id>/ pages and a >100 PR head (RED)
- b210be31a: test(253-165): PR collector proven on paginated listings and the one-page PR-head check bound

## Deviations from Plan
1. **Process: Task 1 verify script additions.** The Task 1 block deletes its full-suite log on success. To record the literal `Ran 82 tests` line the plan's output asks for, the background script gained two lines ahead of the verbatim block:
   - `cd /Users/jon/projects/sigra`;
   - an `rm` shell function that copies `253-165-full-dryrun.log` to `$TMPDIR/...log.kept` and then runs `command rm` as before.

   The block's semantics are unchanged. The copy lived in `$TMPDIR`, outside the tree, and was deleted afterwards. The Task 2 script gained only the same `cd` line.
2. **Process: Task 2 RED split.** The World options were written first, then removed for the RED commit (test class only) and restored for GREEN. This kept RED a real failure.
3. **Observed flake (out of scope, not fixed).** One GREEN check run, before the verify block, failed an existing test: `LivePolicyPRTests.test_live_policy_token_and_host_rules_hold_across_both_families`, with `[60, 60, 60, 0.001, 0.002, 60, 60, 60] != [60, 60, 60, 60, 60, 60]`.
   - **Cause:** 0.001 and 0.002 are CPython's `subprocess.Popen._wait` backoff (it starts at a 1 ms delay and doubles). That backoff runs when a `subprocess.run(..., timeout=...)` inside the shimmed collector reaps a child that has not exited yet, and the test's global `time.sleep` recorder logs it.
   - **Not this plan's change:** that class's universe uses no new flag, and the default fake path behaves the same as before.
   - **Runs that passed:** the RED run, the Task 2 verify block and 253-164's run.
   - **Handling:** the assertion was not touched (existing tests keep their assertions). Left for a later plan to harden.

## Threat Flags
None. T-253-382: no per-route rule; the transport is diff-asserted unchanged and the journal shows only approved /repos/ paths. T-253-383: the >100 head stops after one request; the category tables are unchanged.

## Known Stubs
None.

Full Phase 253 verification stays not_started. CIREL-02 stays open.

## Self-Check: PASSED
- scripts/ci/ci-gate-canary-dryrun.py, ci-gate-canary-dryrun.test.py and ci-pr-proof.test.sh exist and are committed.
- ecb5d22d0, 840c7f4a4, 69978462e and b210be31a are ancestors of HEAD.
- Both verify blocks ended with VERIFY-EXIT 0.
