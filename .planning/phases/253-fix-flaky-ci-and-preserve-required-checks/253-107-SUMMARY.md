---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "107"
subsystem: ci-reliability / hosted transport
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, hosted-transport, redirect, live-policy, r9]
requirements: [CIREL-02]
requires: ["253-102", "253-103"]
provides:
  - live approved-redirect hop in scripts/ci/ci-hosted-transport.py (_trusted_download_host)
  - test-only live-policy shim scripts/ci/ci-live-policy-shim.py (used by 253-108 and 253-109)
  - dry-run window guard in scripts/ci/ci-hosted-gate-verify.py
  - 253-LOAD-RECOVERY-PRESERVATION-R9.sha256 and 253-LOAD-RECOVERY-TRANSPORT-REDIRECT-RED-R9.json
affects: ["253-108", "253-109", "253-111", "253-113"]
tech-stack:
  added: []
  patterns:
    - "live-mode tests that redirect only the socket/TLS layer below every transport policy decision"
key-files:
  created:
    - scripts/ci/ci-live-policy-shim.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PRESERVATION-R9.sha256
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-TRANSPORT-REDIRECT-RED-R9.json
  modified:
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
decisions:
  - "One predicate, _trusted_download_host, decides a live download hop in both _approved_redirect and request_one; live hop 0 stays api.github.com:443 only"
  - "Fixed the request_one terminal-stop precedence bug as a separate fix(253-107) hole commit, RED-first, because the negative matrix requires the ledger to carry the refusal code"
  - "A 253-dryrun- window (transport_ledger or origin window_id) is synthetic everywhere and gapped in completion"
redirect_fix_commit: 375b4113805618e48a925d2841ca66545987a2f4
hole_fix_commits:
  - e72466b1c9ef8c6eb7a9f970ef2464d4a60f2074
metrics:
  duration: "about 3h 10m (dominated by two 28-minute ci-gate-canary-dryrun.test.py runs)"
  completed: 2026-10-15
actuals:
  tokens: 14900
  tasks: 3
  commits: 6
plan_head_before: ad1964168aaeb127f82d0c069897dc1cd3b11d1b
plan_head_after: 5c64d80b9989e3c50ecd69ce2dbf9b9271f04859
---

# Phase 253 Plan 107: Live approved-redirect hop, live-policy shim and dry-run guard Summary

The transport can now finish a real artifact download. It follows GitHub's 302 from api.github.com to a trusted blob host (for example productionresultssa17.blob.core.windows.net) and never sends the GitHub token to that host. The test that proves this runs the live-mode code path, and it was shown failing (RED) before the fix. There was zero network access and zero GitHub requests.

## What was wrong (the 253-104 halt)

In live mode, `request_one` refused every host except api.github.com. `follow_download` hands it the blob host that `_approved_redirect` has just approved, so no live artifact download could ever finish. Earlier gates missed this because all of them ran in hermetic-test mode, which skips that check.

## Commits

| # | Hash | Subject |
|---|------|---------|
| 1 | 836f745a9 | docs(253-107): R9 preservation checklist |
| 2 | fa31a8783 | test(253-107): live-mode approved redirect through the live-policy shim (RED) |
| 3 | 375b41138 | fix(253-107): allow the live approved-redirect hop to a trusted download host (**redirect_fix_commit**, full 375b4113805618e48a925d2841ca66545987a2f4; subject unique in the repo) |
| 4 | 60fa8054a | test(253-107): live hop negative matrix and positive controls (RED on terminal-stop label) |
| 5 | e72466b1c | fix(253-107): terminal-stop code keeps the transport error code (precedence hole) |
| 6 | 5c64d80b9 | feat(253-107): dry-run window guard |

Order holds as required: checklist, then RED receipt, then redirect fix.

## Task 1: checklist, shim, RED, fix

- **Preservation checklist**: 39 lines. All 36 pinned hashes matched exactly, and the three disposition-line files matched their prefixes. `shasum -a 256 -c --quiet` exits 0. Positive control: a scratch copy with one altered hash exits 1.
- **RED**: `ci-hosted-transport.test.py` ran 38 tests with 1 failure. The failure was `test_live_artifact_zip_follows_the_approved_redirect_to_the_trusted_blob_host`, with the real transport's `origin_rejected: live transport is restricted to api.github.com`. A probe of the same run showed hop 0 reached the local server as api.github.com:443 with Authorization. There was no hop-1 connection and no shim refusal, so the failure came from the transport, not the harness. The receipt was committed before the fix.
- **GREEN**: 38/38. The ledger holds two complete rows with one request_group: hop 0 is api.github.com with 302 and hop 1 is the blob host with 200. Both rows are charged to artifact_downloads, and the hop-1 URL query is shown as `?[REDACTED]`. The connect log shows api.github.com:443 then the blob host on 443. SNI carried the same two real hostnames. The server saw `Bearer <dummy>` on hop 0 and no Authorization header on hop 1. The refusal log is empty.
- **Rule** (`request_one`, live mode): hop 0 (or no destination) must be api.github.com on port 443. A later hop is allowed only on a download route, only with an integer hop between 1 and max_hops, and only if `_trusted_download_host` passes. That means port 443, a host in the allocation's download_hosts, and a host matching the trusted policy. Anything else raises `origin_rejected` before the ledger is charged. Hermetic branches, the token lookup, the Accept header, categories, caps and max_hops are unchanged.

## Task 2: negative matrix (49 transport tests)

Each case below ran live through the shim. The local server answers for every one of these hostnames, so a hole would have shown up as a real connection.

| Case | Result |
|------|--------|
| 302 to evil.example.com | redirect_rejected, no connection, terminal |
| 302 to productionresultssa17.blob.core.windows.net.evil.example (lookalike) | redirect_rejected |
| 302 to http://blob host | malformed_location |
| 302 to blob host on port 8443 | redirect_rejected |
| 302 to productionresultssa41 (matches the policy, but not in download_hosts) | redirect_rejected |
| 302 to a Location with userinfo / with a fragment | malformed_location (both) |
| 302 back to api.github.com | redirect_rejected (expected: api.github.com is never a download host) |
| Direct `request_one` calls (9 cases): non-API host at hop 0 or hop absent; trusted destination on the `run` route; api.github.com at hop 1; sa41 at hop 1; untrusted host at hop 1; port 8443; hop 3 > max_hops; boolean hop | origin_rejected; the ledger count stayed at 1 and stayed non-terminal; no connection |
| Direct call on a fresh window | origin_rejected, no ledger file |

In every redirect case: exit 1, exactly one charged transaction (hop 0), terminal_stop set to the refusal code, an empty shim refusal log, and no archive written.

Positive controls passed: the trusted blob redirect, a run_logs redirect to pipelines.actions.githubusercontent.com with no Authorization header, and max_hops 1 with two redirects (redirect_budget_exhausted, 2 charged requests).

**Offline suites on the final HEAD** (all exit 0):

| Suite | Tests |
|-------|-------|
| ci-hosted-transport.test.py | 49 |
| ci-git-publication.test.py | 66 |
| ci-hosted-gate-verify.test.py | 87 |
| ci-gate-canary-flow.test.py | 22 |
| ci-gate-canary-recovery.test.py | 5 |
| ci-gate-canary-dryrun.test.py | 21 |
| ci-gate-canary.test.sh | passed |
| ci-pr-proof.test.sh | 39 |

**Hermetic gate** (`ci-gate-canary-dryrun.py`): status passed, synthetic true. requests_by_category: artifact_downloads 10, artifact_metadata 6, attempt_jobs 7, cancellation 1, dispatch 7, failure_logs 6, pre_watch_rate 7, preflight 5, publication 19, run_discovery 7, terminal_polls 18.

**Check-only commands**: the v1 and r2–r8 reconcile `--check-only` commands all exit 0. `--require-target-disposition` exits 0 and `--require-target-accepted` exits 3, both unchanged.

## Task 3: dry-run window guard

- RED on the unchanged verifier: 87 tests ran with 6 failures and 19 errors, spread over 7 of the 10 new tests. The 3 control tests passed (real window ids, hermetic channel kept, real completion). All 78 existing tests passed.
- GREEN: 87/87. Existing verifier tests were not edited (the test file diff is insertions only: 173 added, 0 removed).
- Labelling: `dryrun_window()` checks transport_ledger.window_id and origin.window_id against the `253-dryrun-` prefix.
  - CLI canary results (transport, preflight, scenario, sources, matrix) get synthetic true and channel `live-policy-dry-run`. Hermetic evidence keeps `hermetic-https`.
  - `verify_canary_matrix` gets synthetic true.
  - PR family and pair results go through `dryrun_pr_result`: status becomes synthetic_*, accepted_live false, synthetic true.
  - `verify_completion` adds `synthetic:<link>:dry-run window cannot satisfy live acceptance` for canary, publication, pr_normal and pr_docs_only. Both `--require-accepted` and `--require-dispositioned` then reject.
  - Real ids such as 253-113-canary-window-1 and 253-114-pr-window-1 are not flagged, and neither are `x-253-dryrun-1` or `253-dryrun`.

## Shim interface (scripts/ci/ci-live-policy-shim.py)

- `make_tls_identity(directory, hostnames) -> (cert, key)`: a self-signed certificate whose SAN lists the given DNS names (wildcards allowed).
- `prepare(directory, host_map, ca_file, connect_log, sleep_scale=None) -> env`: writes `directory/sitecustomize.py` and returns `{PYTHONPATH, SIGRA_LIVE_POLICY_SHIM}`.
- `patched(...)`: an in-process context manager with the same patches, restored on exit.
- `refusal_log_for(connect_log)` (the connect log path plus `.refusals`), `read_log(path)`, `ENV_VAR`.
- Patches:
  - `socket.create_connection`: a mapped host on port 443 goes to 127.0.0.1:<mapped port> and is logged; everything else raises an OSError "live-policy shim refused real network destination ..." and is logged as a refusal.
  - `socket.getaddrinfo`: only loopback names resolve; anything else is refused.
  - `ssl.create_default_context`: trusts only the test CA, with hostname checking on.
  - `time.sleep`: optionally scaled.
- The shim does nothing without the variable, and product code never imports it. A positive control proves an unmapped `example.invalid:443` is refused and logged, and that a process without the variable is left unpatched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrong terminal-stop code in request_one (hole-fix commit e72466b1c)**
- **Found during:** Task 2, by the http, userinfo and fragment negative cases.
- **Issue:** The terminal-stop expression `error_code or f"http_{status}" if status in {401,403,429} else "core_budget_stop"` was parsed as `(a or b) if c else d`. So any error on a status other than 401/403/429 recorded `core_budget_stop` in the ledger instead of the real error. Example: `malformed_location` on a 302. The bug dates from 253-18 (156d59883). The request was still refused (exit 1, the correct code on stderr, no connection), but the ledger label was wrong, and the plan requires the ledger to carry the refusal code.
- **Fix:** Added parentheses so error_code wins. The http_4xx codes and the genuine core-rate-floor `core_budget_stop` are unchanged; both existing assertions of that code (transport test and ci-pr-proof) still pass. This followed the plan's RED-first hole path: test commit 60fa8054a failed 3 cases, and the fix used a subject different from the redirect-fix subject.
- **Files modified:** scripts/ci/ci-hosted-transport.py (one line).

**2. [Test harness] Two corrections to my own new tests during RED (no product or existing-test change)**
- Redirect cases: I had asserted that no body file exists. The transport already writes hop 0's empty 302 body to `--body-output` (unchanged behaviour), so the test now asserts that no archive bytes were written.
- Task 3 end-to-end fixture: I was missing `repository`. RED was rerun after the fix, and the counts above are from that rerun.

## Known Stubs

None.

## Notes for later plans

- The publication receipt (ci-git-publication.py) currently has no `origin.window_id` or `transport_ledger`, so the completion guard can only flag a dry-run publication if 253-108's live-policy dry-run writes `origin.window_id` (or a ledger) into that receipt. 253-108 should do this, or the publication gap will not fire.
- The `verify_pr_family` dry-run label is covered by a direct `dryrun_pr_result` test plus a source-wiring assertion. No offline live-mode PR-family fixture exists yet; 253-108 / 253-109 can exercise it end to end through the shim.
- Changing scripts/ci means FREEZE-R8 no longer matches this tree, as the plan expected. 253-111 freezes the fixed source.

## Invariants

- `git status --short`: only ` M .planning/config.json`.
- config.json sha256 prefix 8e312f6ccd34 (unchanged). state.json is 70229 bytes, sha256 prefix e45278c2cee0 (unchanged).
- STATE.md, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json were not touched, and no gsd state or roadmap writer verbs were run. scripts/ci/__pycache__ was removed after every python run.
- Zero GitHub requests, no push or fetch; the real GH_TOKEN/GITHUB_TOKEN were unset. Full Phase 253 verification is still not_started.

## Self-Check: PASSED

All created files exist and all six commits are ancestors of HEAD (checked before writing this file).
