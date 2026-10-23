---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "110"
subsystem: ci-reliability / hermetic-vs-live audit
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, audit, hermetic-vs-live, r9]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-107 live transport tests and shim, 253-108 live-policy canary gate, 253-109 live-policy PR universe"
provides:
  - "253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R9.json: all 69 hermetic-vs-live sites in the five hosted-proof files plus 2 supplementary rows (71 rows). Each row has an offline live-side test, a live-policy gate assertion or a stated residual risk."
  - "scripts/ci/ci-hermetic-live-audit.test.py: a durable checker covering the stated matcher, anchors, lines, refs, live markers and summary assertions, plus test_no_gap_rows and 9 positive controls"
  - "verify_transport_v2 live canary transaction host rule (verify_live_transaction_host)"
  - "offline live-side tests for every former gap row (transport, verifier, publisher)"
affects: ["253-111", "253-113", "253-114"]
tech-stack:
  added: []
  patterns:
    - "An audit record keyed by (file, exact source line, occurrence) and re-scanned by a checker. A new unaudited branch, a stale anchor or a moved line fails a test."
    - "The live canary host rule reads the host from the digest-bound URL and cross-checks any recorded host field."
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R9.json
    - scripts/ci/ci-hermetic-live-audit.test.py
  modified:
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-git-publication.test.py
key-decisions:
  - "The canary host rule takes the host from the transaction URL, which url_sha256 binds, and requires any recorded host field to agree. The v2 unit fixtures carry no host field. The rule mirrors the 253-107 transport policy by pattern only: canary evidence carries no allocation, so membership in the frozen download_hosts cannot be checked here."
  - "ci-pr-proof.sh:132 (--prepare --require-live-origin) is the only justified row. Covering it offline needs ci-pr-proof.test.sh, which this plan does not declare."
  - "No product file other than ci-hosted-gate-verify.py had a live-only defect, so the plan did not halt. The one verifier defect (the missing canary host rule) was fixed RED-first."
actuals:
  tokens: 25777
  tasks: 3
  commits: 4
commits: 4
plan_head_before: a7d2c42d477afdde68ebcaa896a6271d7c4f277e
plan_head_after: 91a6636b1be7b29a28b1bb2590495d73af86376d
duration: "about 1h 15m (54 minutes of it the final regression, mostly the dry-run suite)"
completed: 2026-10-16
---

# Phase 253 Plan 110: Hermetic-vs-live branch audit Summary

**Every hermetic-vs-live branch in the five hosted-proof files is now enumerated in an audit record of 71 rows. 70 rows name tests that execute the live side offline, either unit and shim tests or the 253-108/109 live-policy gates. The one row that cannot be covered with this plan's files states its residual risk. A checker re-scans the sources and fails on any new unaudited branch, stale anchor, missing test or gap row. The audit found one live-only defect: verify_transport_v2 checked no host for live canary transactions. That is now fixed RED-first and checked against the real R8 ledger. The R9 publication projects 17 of 22 requests, with every tree body at or under 2 MiB. There were zero GitHub requests.**

## Performance

- **Started:** 2026-10-16T01:35:35Z
- **Completed:** 2026-10-16T02:50:53Z
- **Tasks:** 3/3
- **Files:** 2 created, 4 modified. In the diff from a7d2c42d4 to 91a6636b1: +1933 / -2 lines, 103,109 added characters.

## The matcher

The record stores the matcher, and the checker requires the stored matcher to equal its own.
- **Skipped lines:** blank lines, full-line `#` comments and text inside triple-quoted strings.
- **Literal stripping:** a quoted literal that contains whitespace and neither `==` nor `!=` is a message, not a compared value. It is replaced by an empty literal before matching.
- **topic:** `hermetic|HERMETIC|test_origin|test_ca_file|["']live["']|synthetic|API_HOST|dryrun_window|DRYRUN_WINDOW_PREFIX`
- **condition:** `^\s*(if|elif|while|assert)\b|\bif\b.*\belse\b|==|!=|\[\[|jq -e|\bnot in\b|\band\b|\bor\b|\brequire\(`
- **selector:** `require_live_origin|--require-live-origin`
- **selector_excludes:** `add_argument\(|^\s*def `
- **Rule:**
  - A line is a site when condition and topic both match, or when selector matches and selector_excludes does not.
  - A site is keyed by its file, its exact stripped source line (the anchor) and the 1-based occurrence of that line in the file.

## Raw match counts

| File | At a7d2c42d4 (Task 1) | At 3d8ef2a47 (after the fix) |
|---|---|---|
| ci-hosted-transport.py | 25 | 25 |
| ci-gate-canary.sh | 6 | 6 |
| ci-pr-proof.sh | 2 | 2 |
| ci-git-publication.py | 8 | 8 |
| ci-hosted-gate-verify.py | 27 | 28 (the new `if not hermetic_canary(evidence):` host-rule site, occurrence 2) |
| **Total** | **68** | **69** |

There are 2 reasoned supplementary rows outside the matcher:
- `transport-948-supplementary`: the plan named the fetch_pages synthesized rules page 2.
- `verifier-128-supplementary`: verify_transport_v2 had no host condition at all, so its missing branch is recorded against the function.

## Rows per file and per coverage kind (final record, audit_head 3d8ef2a47)

| File | Rows | offline-live-test | live-policy-gate | justified | gap |
|---|---|---|---|---|---|
| ci-hosted-transport.py | 26 | 26 | 0 | 0 | 0 |
| ci-gate-canary.sh | 6 | 2 | 4 | 0 | 0 |
| ci-pr-proof.sh | 2 | 0 | 1 | 1 | 0 |
| ci-git-publication.py | 8 | 7 | 1 | 0 | 0 |
| ci-hosted-gate-verify.py | 29 | 15 | 14 | 0 | 0 |
| **Total** | **71** | **50** | **20** | **1** | **0** |

In the Task 1 record (70 rows) the counts were 36 offline-live-test, 20 live-policy-gate, 1 justified and **13 gap**.

## Gap rows found in Task 1, and how each was closed

| Row | Live side that no offline test ran | New refs (all `offline-live-test`) |
|---|---|---|
| transport-262 | `_route` refusing test-only routes under a live allocation | `LivePolicyAllocationTests.test_live_allocation_refuses_every_test_only_route` |
| transport-479 | live minimum of one request | `LivePolicyAllocationTests.test_live_canary_max_requests_is_one_through_117_while_hermetic_may_be_zero` |
| transport-483 | live canary range 1..117 (refusal side) | the same, plus the live canary routes test |
| transport-507 | `_validate_allocation`'s live download_hosts rule (refusal side) | `LivePolicyAllocationTests.test_live_download_hosts_must_be_a_unique_list_of_trusted_hosts_only` |
| transport-673 | Accept header per host | `test_live_accept_header_is_github_json_on_api_github_com_and_plain_json_on_the_download_host` |
| transport-998, transport-1005, transport-1018 | `_next_page_url`'s live branch: no fake ever sent a Link to a live allocation | `test_live_pagination_follows_an_api_github_com_next_link_as_a_second_charged_api_request`, `test_live_pagination_refuses_every_link_off_api_github_com_or_off_the_route_before_a_second_request` |
| transport-948-supplementary | live synthesized rules page 2 | `test_live_full_first_rules_page_is_followed_by_one_charged_second_rules_page_on_api_github_com` |
| verifier-119 | `api_view` on live evidence | `test_api_view_returns_live_evidence_unchanged_and_rewrites_only_hermetic_evidence` |
| verifier-968, verifier-969 | `verify_pr_transport` rejecting a live foreign host | `test_a_live_pr_ledger_on_api_github_com_and_a_frozen_download_host_verifies`, `test_a_live_pr_transaction_on_any_other_host_is_rejected` |
| verifier-128-supplementary, and the new verifier-new-195 | the live canary host rule (missing) | `test_live_canary_transactions_hop_zero_on_api_github_com_and_later_hops_on_trusted_download_hosts_only`, `test_hermetic_https_canary_evidence_is_unaffected_by_the_live_host_rule`, `test_the_halted_r8_live_ledger_rows_satisfy_the_live_host_rule` |

Refs were also added to rows that were already covered:
- **transport-455:** `test_live_unknown_allocation_mode_is_refused`.
- **publication-628 and publication-629:** `LiveOriginDerivationTests`, which calls `derive_origin`'s live branch directly with blob, pipelines, local, missing-host, pending and empty ledgers.

None of the new live-side tests failed against the product code. Apart from the canary host rule, no live-only defect was found.

The sites the plan named are all covered:
- **request_one's origin check:** transport-594 and transport-599, through the 253-107 tests.
- **`_approved_redirect`:** transport-816 and transport-818.
- **`_connect`:** transport-570. It is offline-live-test with a residual risk: the shim's CA stands in for the system trust store.
- **ci-gate-canary.sh live publication verification and the verified REF_STATE:** canary-411 and canary-412, through the live-policy gate with assertions on `fixture_ref_state` and `origin_kind`.
- **The live refusal of `SIGRA_CANARY_TEST_*`:** canary-357. It was already covered offline for every variable and mode by `LiveOverrideRefusalTests`, so no flow-stub test was needed.
- **The synthetic label:** pr-proof-457.
- **`derive_origin`:** publication-628.
- **`verify_pr_transport`:** verifier-950 through verifier-991.
- **`_view_for_checks`:** verifier-1014 through verifier-1021.

## The justified row

**pr-proof-132:** `publisher.verify_publication(receipt_path, bool(args.require_live_origin))`
- **Justification:** the line only forwards the flag to `ci-git-publication.verify_publication`. Three things are tested elsewhere:
  - that function accepts an actual-github receipt with `require_live_origin` (`test_actual_github_origin_needs_live_allocation_hosts_and_server_derived_identities`);
  - this exact line refuses a hermetic receipt (`test_prepare_rejects_a_hermetic_publication_origin_when_live_acceptance_is_required`), which proves the flag arrives as True;
  - the live-policy PR universe runs `--prepare` on an actual-github receipt (`LivePolicyPRTests`).
- **Residual risk:** no offline test runs `ci-pr-proof.sh --prepare` with the flag and an actual-github receipt together. A defect that appears only in that combination inside `prepare()` would first surface in the 253-114 hosted window.

One `offline-live-test` row also carries a residual risk:
- **transport-570** (`_connect`): the shim patches `ssl.create_default_context` to trust the fake's CA. Validation of GitHub's real certificate chain against the system trust store only runs in a hosted window.

## Live canary host rule (Task 2)

- **RED (2a388d160):**
  - In V2VerifierContractTests, 15 tests ran with 2 target tests failing (17 subtest failures).
  - Every tampered shape returned "VerificationError not raised": a hop-0 blob host; an untrusted, lookalike, api.github.com, port-8443 or http hop 1; a host/URL disagreement; and an untrusted hop 0. Each was checked with channel None and with github-api.
  - The R8 control failed with "the live canary transaction host rule is missing".
  - The positive cases and the hermetic test passed before the fix.
  - `gsd-tools check tdd-red-evidence` returned RED_EVIDENCE_OK for both targets. Semantic check: each failed on its planned assertion, with no load or fixture fault.
- **GREEN (3d8ef2a47):** `verify_live_transaction_host` runs for every non-hermetic transaction in `verify_transport_v2`.
  - Hop 0 (or no hop) must be on api.github.com.
  - A redirect hop must be on `pipelines.actions.githubusercontent.com` or `productionresultssaN.blob.core.windows.net`, and never on api.github.com.
  - The request must use https on 443 without credentials, and a recorded host field must equal the URL host.
  - The verifier suite passed 90/90.
- **Real live data (read-only):** all 30 rows of the halted R8 ledger, all on api.github.com, satisfy the rule. The same row tampered to a blob host is rejected.
- **253-108's live-policy evidence still verifies:**
  - A `--live-policy --stop-after full-pass` smoke run after the fix passed, with 33 requests and one hop 1 to productionresultssa17. The verifier accepted full-pass.
  - The full `--live-policy --seed-r8-refs` gate in Task 3 also passed.

## Early R9 publication projection (Task 3)

- **Command:** `ci-git-publication.py --prepare` at candidate HEAD 91a6636b1, server parent 84ebcea6, with the R9 fixture workflow. Output went to `$TMPDIR` and was deleted.
- **Status:** `ready-local-proposal`, with no blockers.
- **projected_total_requests:** 17, against a limit of 22. That is 1 parent preflight, 12 fixed non-tree requests, 4 tree requests and 0 binary blobs. It leaves 5 requests of headroom inside the 22, and 7 inside the 24-request publication category.
- **tree_request_count:** 4.
- **tree_requests[].body_bytes:** 1,850,575; 2,083,078; 1,034,007; 17,686.
- **largest_tree_body_bytes:** 2,083,078 of 2,097,152. That leaves 14,074 bytes of headroom, the same largest body as R8. The packer splits trees automatically, so the cap binds only on a single entry larger than it.
- **Halt check:** no halt threshold was reached, so the fallback options were not needed.

## Task commits

| # | Hash | Subject |
|---|---|---|
| 1 | 62d960af0 | feat(253-110): hermetic-vs-live branch audit and its durable checker |
| 2 | 2a388d160 | test(253-110): live canary transaction host rule (RED) |
| 3 | 3d8ef2a47 | fix(253-110): live canary transaction host rule |
| 4 | 91a6636b1 | test(253-110): close every hermetic-vs-live audit gap with an offline live-side test |

No docs(253-110) line-refresh commit was needed: no product line moved after 3d8ef2a47.

## TDD record

- **Task 1 (checker):**
  - RED: the first run had no record at all and gave a FileNotFoundError ERROR, which was recorded but is not valid RED.
  - The valid RED used a skeleton record with schema and matcher but no rows. `test_the_committed_record_is_complete_and_current` failed with "the record has no rows", and the classifier returned RED_EVIDENCE_OK.
  - GREEN: the enumerated record passed 12/12.
- **Task 2 (host rule):** RED and GREEN as described above.
  - The gap-row tests are coverage tests for existing behaviour. They passed on first run, so they found no defect.
  - Two refusal subtests first expected the wrong code. Userinfo and fragment Links are refused earlier by the response-header scrubber (`malformed_location`), still before any second request. The tests now state the code per case. This was a test expectation, not a product defect.
- **REFACTOR:** none.

## Verification

- **Task 1 `<verify>`, verbatim (tracer gate, re-run before expansion):** rc 0, with the checker at 12 OK. The tracer was verified end to end before expansion.
- **Task 2 `<verify>`, verbatim:** rc 0.

  | Suite | Result |
  |---|---|
  | ci-hermetic-live-audit.test.py | 14 OK |
  | ci-hosted-gate-verify.test.py | 94 OK |
  | ci-hosted-transport.test.py | 57 OK |
  | ci-git-publication.test.py | 69 OK in 141 s |
  | ci-gate-canary-flow.test.py | 22 OK |

  The jq no-gap and justified-residual check, `test_no_gap_rows` and the `fix(253-110)` commit on the verifier all held, and the tree was clean.
- **Task 3 `<verify>`, verbatim:** VERIFY3_RC 0, 3217 s.

  | Check | Result |
  |---|---|
  | projection | ok |
  | ci-hermetic-live-audit.test.py | 14 OK |
  | ci-hosted-transport.test.py | 57 OK |
  | ci-git-publication.test.py | 69 OK |
  | ci-hosted-gate-verify.test.py | 94 OK |
  | ci-gate-canary-flow.test.py | 22 OK |
  | ci-gate-canary-recovery.test.py | 5 OK |
  | ci-gate-canary-dryrun.test.py | 42 OK in 2523 s |
  | ci-gate-canary.test.sh | passed |
  | ci-pr-proof.test.sh | 54 OK in 132 s |

  - **Hermetic default gate:** passed with 93 requests (publication 19, preflight 5, dispatch 7, run_discovery 7, pre_watch_rate 7, terminal_polls 18, attempt_jobs 7, artifact_metadata 6, artifact_downloads 10, failure_logs 6, cancellation 1).
  - **`--live-policy --seed-r8-refs` gate:** passed with 93 requests, the same categories, 85 api requests with the token, 0 without it, 0 blob requests with it, 8 live hops, 0 shim refusals and 0 violations. Publication was `published-actual-github`, origin actual-github, fixture_ref_state verified, verifier_dryrun_window true, and `seeded_r8_refs_changed` false.
  - **Predicates and records:** `--require-target-disposition` exited 0 and `--require-target-accepted` exited 3. The v1 and r2-r8 `--check-only` commands exited 0, and `shasum -c` on PRESERVATION-R9 exited 0.
  - **Invariants:** config.json sha, state.json size and a clean tree were all checked inside the verify.
- **Positive controls for the negative results:**
  - **The checker's 9 controls** each fail for the stated reason: a removed row, an added `mode == "hermetic-test"` branch in a copy of the transport, a ref to a missing test, a hermetic-only test cited as live coverage, a stale anchor and a moved line, a justified row without residual risk, a live-policy-gate row without its assertion, a changed matcher, and a well-formed gap row that only `test_no_gap_rows` reports.
  - **`test_no_gap_rows`** would report the Task 1 record's 13 gaps.
  - **"Every refused Link causes no second request"** is meaningful because the accepted-Link test shows a valid Link does cause a second charged request.
  - **The live PR host refusals** sit beside an accepted live ledger in the same class.
  - **"No `__pycache__`"** was checked beside a positive `ls` of scripts/ci.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The Task 3 verify could not run under `bash -c`**
- **Found during:** Task 3.
- **Issue:** the harness safety check refuses `rm` inside a `bash -c` script it cannot inspect.
- **Fix:** I ran the identical command sequence directly. The `rm` targets were literal absolute paths (`scripts/ci/__pycache__` and the three `$TMPDIR` outputs) instead of `$M`/`$O1`/`$O2`. The checks and their order are unchanged.

**2. [Rule 1 - Bug, test-only] Pagination refusal subtests expected the wrong stop code for userinfo and fragment Links**
- **Issue:** the response-header scrubber refuses userinfo and fragment Links first, with `malformed_location`.
- **Fix:** the expected code is now set per case. Both are still refused after exactly one charged request, before any second socket request. This was fixed in 91a6636b1, before the commit.

**3. [Process] An extra RED commit for the host rule**
- **Change:** the plan asked for one `fix(253-110)` commit. I committed the RED tests first as `test(253-110)` (2a388d160), then made the verifier-only fix as `fix(253-110)` (3d8ef2a47).
- **Effect:** the RED gate is visible in history, and the verify's `fix(253-110)`-on-the-verifier check still holds.

**4. [Interpretation] audit_head**
- `audit_head` is 3d8ef2a47, the commit whose product lines the final rows are taken at. Row ids keep their Task 1 line numbers (a7d2c42d4) so the ids stay stable, while the `line` fields are current.

### Not done (out of declared scope, recorded)
- **pr-proof-132 coverage:** it stays justified rather than covered, because ci-pr-proof.test.sh is not a declared file.
- **WINDOWS.md:** no entry was appended to the cross-phase ledger, to keep the tree limited to the plan's declared files. The justified row's residual risk is recorded here and in the audit record.

## Known Stubs

None.

## Threat Flags

None. The only product change tightens the verifier: live canary evidence that was accepted before can now be rejected, never the reverse. T-253-226 is mitigated by the checker and its controls. T-253-227 is mitigated by the host rule, which was RED-first and checked against the R8 ledger. T-253-228 is mitigated by the projection: 17 of 22 requests, largest body 2,083,078 of 2,097,152.

## Notes for 253-111 and later

- **Publication budget at freeze:** the projection at 91a6636b1 is 17 requests and 4 trees, with a largest body of 2,083,078 bytes.
  - The 22-request budget leaves 5 requests of headroom.
  - The 2 MiB body cap leaves 14,074 bytes, which is thin. If 253-111 adds product bytes to the file that lands in the largest tree, re-run `--prepare`. The packer splits trees, so the realistic risk is another tree request, not a refusal.
- **The audit is a gate:** any edit to the five hosted-proof files that adds or moves a matched line fails `ci-hermetic-live-audit.test.py` until its row is added or its `line` is refreshed. 253-111 should include the checker in its pre-clock gate, beside `--live-policy --seed-r8-refs`.
- **Observation, not changed:** `verify_pr_transport`'s live host rule is weaker than the canary rule. It accepts api.github.com or any frozen download host at any hop, so a hop-0 blob host would verify. The transport refuses that shape before the socket, so a real ledger cannot contain it. If the verifier should be independent here too, mirror `verify_live_transaction_host` in a replan.
- **Still not covered offline:**
  - real system-trust-store TLS validation;
  - redirect hosts other than productionresultssa17 and pipelines.actions.githubusercontent.com (productionresultssa18 appears only as a second-hop budget case);
  - real GitHub latency, auth scopes and 403/429 responses;
  - `ci-pr-proof.sh --prepare --require-live-origin` with an actual-github receipt (the justified row).
- **Pipelines host:** pipelines.actions.githubusercontent.com is exercised at the transport level (`test_run_logs_follow_to_pipelines_host_without_authorization`) and by the new verifier test. Neither live-policy gate uses it.
- **Verification status:** full Phase 253 verification remains not_started.

## Invariants

- `git status --short` shows only ` M .planning/config.json`.
- config.json sha256 is 8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d.
- state.json is 70229 bytes with sha256 prefix e45278c2cee0.
- STATE.md, ROADMAP.md, REQUIREMENTS.md, state.json and HANDOFF.json were not touched, and no gsd state, roadmap, config or requirements writer verbs were run.
- No pinned PLAN, SUMMARY, R7/R8 record or PRESERVATION-R9 file changed (`shasum -c` rc 0).
- scripts/ci/__pycache__ was removed after every python run.
- The projection output was written to `$TMPDIR` only and deleted.
- Zero GitHub requests, no push, no fetch, no gh or curl.

## Self-Check: PASSED

- Both created files exist, and all four task commits are ancestors of HEAD.
- The commit count measured from the plan ledger is 4 (a7d2c42d4..91a6636b1).
