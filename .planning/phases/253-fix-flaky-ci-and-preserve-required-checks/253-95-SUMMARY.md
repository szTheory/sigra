---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "95"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, publication, readback, canary-freeze, r7]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: 253-91 publisher and freeze machinery; 253-92 halted ledger that exposed the readback defect
provides:
  - Publisher commit readback that accepts GitHub's one stripped trailing newline and nothing else
  - Same tolerance in the docs-only PR family verifier
  - GitHub-faithful local fake server (stripped commit message, 60-column wrapped blob base64)
  - R7 publication manifest and R7 canary freeze bound to the fixed source
affects: [253-96, 253-97, 253-98, 253-99]
requirements-completed: ["CIREL-02"]
actuals:
  tokens: 32000
  tasks: 3
  commits: 5
plan_head_before: 6cf3aa0321743ec7d63a57e620f9b2066a48d55a
plan_head_after: 526b0b0e698ce3e189f942c0894aaf0bfd09ebfd
coverage:
  - id: D1
    description: "Publisher candidate/fixture commit readback accepts exactly the sent message or it minus one trailing newline; every other difference and a differing sha is rejected"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-git-publication.test.py#test_commit_message_matches_accepts_only_equality_or_one_stripped_newline"
        status: pass
      - kind: integration
        ref: "scripts/ci/ci-git-publication.test.py#test_every_other_commit_message_readback_is_rejected_after_charge_without_a_ref"
        status: pass
      - kind: integration
        ref: "scripts/ci/ci-git-publication.test.py#test_actual_measured_https_uploads_local_only_objects_before_create_only_ref_readback"
        status: pass
    human_judgment: false
  - id: D2
    description: "Docs-only PR family verifier accepts the frozen docs commit messages or them minus one trailing newline and rejects near misses"
    requirement: CIREL-02
    verification:
      - kind: integration
        ref: "scripts/ci/ci-pr-proof.test.sh#test_docs_commit_readback_tolerates_exactly_one_stripped_trailing_newline"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-hosted-gate-verify.test.py#DocsCommitMessageToleranceTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "R7 publication manifest and canary freeze derived offline from the clean committed post-fix tree; the halted 253-92 approval is refused against the new freeze"
    requirement: CIREL-02
    verification:
      - kind: other
        ref: "Task 3 automated verify command (exit 0): check-only revision freeze, check-manifest, approval positive control and R7 refusal, pinned sha256 list, v1-r6 reconcile check-only"
        status: pass
    human_judgment: false
duration: ~1h
completed: 2026-10-15
status: complete
---

# Phase 253 Plan 95: Publisher readback fix and R7 canary freeze Summary

**The publisher and docs-only verifier now accept GitHub's real commit readback (message with exactly one trailing newline stripped, sha unchanged), proven RED first against a GitHub-faithful fake server, and a new R7 publication manifest and canary freeze are derived offline from the fixed committed tree.**

## Performance

- **Tasks:** 3 (all complete)
- **Completed:** 2026-10-15
- **Requests to GitHub:** 0. Pushes: 0. Fetches: 0. All transport was the local HTTPS fixture.

## Commits

| Commit | Message |
|---|---|
| `35fcaf9a0` | test(253-95): GitHub-faithful commit message readback (RED), fake server plus the RED receipt |
| `d208fe1e1` | fix(253-95): publisher one-trailing-newline readback tolerance, server_message_form |
| `97665bd2a` | fix(253-95): docs-only verifier tolerance, readback negatives, wrapped blob fixture, --freeze-plan (frozen source commit) |
| `b1c5b31ca` | docs(253-95): R7 publication manifest from the post-fix tree |
| `526b0b0e6` | docs(253-95): R7 canary freeze |

The summary commit follows. `commits:` above counts the five commits from `plan_head_before` to the freeze commit.

## RED evidence

- RED commit `35fcaf9a0`, receipt `253-LOAD-RECOVERY-READBACK-RED-R7.json` (produced_on_head `6cf3aa0321743ec7d63a57e620f9b2066a48d55a`), committed before the fix commit `d208fe1e1` (ancestor order checked).
- `ci-git-publication.test.py`: 53 tests, 12 failed. The target test `test_actual_measured_https_uploads_local_only_objects_before_create_only_ref_readback` failed with `PublicationError: server commit readback differs for candidate` (an assertion on the expected error, not a crash).
- `ci-pr-proof.test.sh`: 14 failures and 1 setup error (zero-test guard tripped). All trace to the same publisher rejection in the suite's shared setup.
- Task 2 RED (observed before the verifier/`--freeze-plan` implementation): 3 new tests failed (`DocsCommitMessageToleranceTests`, the docs readback test in `ci-pr-proof.test.sh` where the docs-only verifier rejected the stripped message with "docs base must be one unsigned child...", and the `--freeze-plan` test with "unrecognized arguments").
- The publisher negative tests (extra newline, two chars stripped, CRLF, trailing space, missing, non-string, unrelated; tolerated message with a different sha) and the wrapped-blob test were green on the unfixed code too: the old exact-equality comparison already rejected everything, and `validate=False` already tolerated wrapped base64. They are guards against over-loosening, not RED-first tests.

## Final results (all offline)

| Suite | Result |
|---|---|
| `ci-git-publication.test.py` | 59 tests OK (was 53) |
| `ci-hosted-gate-verify.test.py` | 66 tests OK |
| `ci-pr-proof.test.sh` | 34 tests OK |
| `ci-gate-canary-recovery.test.py` | 5 tests OK |
| `ci-gate-canary.test.sh` | passed |
| Task 3 automated verify | exit 0 |

## Design notes

- The receipt keeps `message` as the newline-terminated canonical value because that is the byte string the commit sha binds and what `make_commit` requires. The new `server_message_form` field (`verbatim` or `trailing_newline_stripped`) records what the server returned.
- `commit_message_matches` (publisher) and the same-named verifier helper accept only `server == sent` or `server + "\n" == sent` for str inputs. No rstrip, no whitespace or CRLF folding.
- `--freeze-plan` takes `253-NN` only (default `253-91`; the 253-91 freeze bytes and every existing test are unchanged).

## Readback audit

| Comparison | Location | Field | What GitHub returns | Verdict |
|---|---|---|---|---|
| publish() parent preflight | ci-git-publication.py:795 and the check above it | parent sha, tree.sha | Observed live, 253-92 ledger row 1 (200, sha 84ebcea6..., tree e9d63071...) | safe |
| publish() create_tree response | :808 | sha | Not yet observed live (253-92 stopped at the first create_commit) | safe |
| publish() create_commit response | :818 | sha | Observed live, 92 ledger row 5 (sha 1351b066...) | safe |
| publish() commit readback | :821-823 | sha, tree.sha, parents sha list | Observed live, 92 ledger row 6 (equal) | safe |
| publish() commit readback | :823 | message | Observed live rows 5 and 6: trailing newline stripped | **fixed** (`commit_message_matches`) |
| publish() commit readback | :823 | author, committer (dict equality) | Observed live row 6: exactly name, email, seconds-resolution Z date, equal to sent | safe |
| publish() workflow blob readback | :836 | sha, size, wrapped base64 content | Not yet observed live; fixture now serves 60-column wrapped base64, decode uses validate=False, bytes and object sha compared | safe (exercised) |
| publish() get_ref probe / create_ref / readback | :846, :856, :859 | object.sha | Not yet observed live | safe |
| publish_docs() | ci-git-publication.py:1037, :1045 | readback sha and tree only; ref object.sha | No message comparison; the sha binds the message bytes | safe |
| ci-pr-proof.sh publish_docs() | :349, :353, :356, :365 | tree sha, commit sha, readback sha and tree, ref object.sha | Same; no message comparison | safe |
| verify_pr_family docs-only | ci-hosted-gate-verify.py tree, commit, ref and parents checks | shas, parents | Sha based | safe |
| verify_pr_family docs-only | readbacks message list | message | Same one-newline stripping | **fixed** (`commit_message_matches`) |
| ledger_identities, verify_publication | ci-git-publication.py:918 and onwards | sha and tree identities only | n/a | safe |

## R7 freeze (Task 3)

- Frozen source commit: `97665bd2a56443a2bb10f894aafd46c5f06e4ce9`; product tree `1d8039ebdc08dc9e7e304ad214c54d580362a867` (1473 product files).
- Server parent: `84ebcea60024c9e8caee405d55cad1c76b0e858a`, re-derived offline. Local `refs/remotes/origin/main` equals it, tree `e9d63071f0ab4ac8edba8a60a2503cc882cb5556`, and 253-92 ledger row 1 (live 200 GET) returned the same sha and tree. No discrepancy.
- `253-LOAD-RECOVERY-CANARY-PUBLICATION-R7.json` sha256 `6813630f1eaa25d3b6ec03f9ab509712b24a9c87f19f8a5956575753b70d1550`; status ready-local-proposal; projected requests 17 (<= 24); largest tree body 2083078 bytes (<= 2097152); 4 tree requests, no binary blobs.
- `253-LOAD-RECOVERY-CANARY-FREEZE-R7.json` sha256 `f608a445dcdd00fc0d3d2a529e50d445f9f831813c32f41140af00544736110c`; plan `253-95`.
- Section digests: canary `9059971bd427cf05cd49a26a8b06bb4176f4b65c266b8fa4e555399aeaf1c67d`; docs_and_prs `c2f66af0143ff604317cc5a4df97f8f919f5f92a5a13e3bc7d4aec05ef087ca4`. Both differ from the 253-91 values (678e2576..., 5d15af53...).
- Candidate `ce89eb7319c20596850a0c8a0b6e5661e197c86a` (differs from the unreferenced 1351b066...); fixture `12cc2ded39301724b7234a4ee9a7a0d79609cc45`; docs base `8cfbc1148b264effd966f0f1f2da25580ab60ac1`; docs head `bd13e7653b3dba228a4733f10bf25f4d57d98b10`.
- outward_actions: canary section = publish_git_objects (max 24), create_ref candidate, create_ref fixture, 7 workflow_dispatch, cancel_run; docs_and_prs section = publish_docs_objects (max 14, two scoped docs refs), draft pr_create for the normal family (base main) and the docs-only family (base gsd/253-replan-docs-base), plus the PR read/poll actions listed in the freeze.
- Ref names stay the create-only scoped names `gsd/253-replan-candidate` and `gsd/253-replan-fixture`. The 253-92 ledger has no get_ref or create_ref transaction, so neither ref was ever created.
- Replay control: the halted 253-92 approval passes `--check-approval` against the OLD freeze (positive control) and is refused against FREEZE-R7.
- All pinned 253-91 and 253-92 records and the R6 contract keep their sha256 values; `reconcile --check-only` for v1 and r2..r6 exit 0; `--require-target-disposition` exits 0 and `--require-target-accepted` exits 3 (CIREL-01 stays partial). config.json sha256 unchanged; state.json 70229 bytes.

## Deviations from Plan

1. **[Observation] RED for the PR suite.** The plan expected the PR suite to go RED on the docs-only rejection. In practice the suite goes RED earlier, at its shared setup, because the unfixed publisher rejects the stripping server. The docs-only verifier rejection was proven RED separately after the publisher fix (Task 2). No code or expectation was altered to force a failure.
2. **[Observation] Negative tests were already green on old code** (see RED evidence). They remain as guards.

**Total deviations:** 0 auto-fixed. No code was changed in Task 3.

## Issues Encountered

None. The wrapped-blob fixture needed no reader fix; the existing blob decode already tolerated line wraps.

## Known Stubs

None.

## Threat Flags

None. No new network surface; the verifier and publisher comparisons were narrowed to exactly one tolerated difference.

## Deferred review findings from 253-91 (recorded, not acted on)

Approvals have no consumed-once marker; `require_listed` does not count uses; an interrupted PR collection needs a new evidence path; later publication-category rows are not pinned. Full Phase 253 verification stays not_started.

## Next Phase Readiness

Ready for 253-96/97: the canary approval for the R7 canary section (digest above) is the next human gate.

## Self-Check: PASSED

Created files exist (RED, PUBLICATION-R7, FREEZE-R7); commits 35fcaf9a0, d208fe1e1, 97665bd2a and 526b0b0e6 are ancestors of HEAD.
