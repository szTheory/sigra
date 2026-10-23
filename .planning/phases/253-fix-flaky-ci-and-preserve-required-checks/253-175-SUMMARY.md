---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "175"
status: halted
completed: "2026-10-20T19:17:02.004217+00:00"
requirements: [CIREL-01, CIREL-02]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-SUCCESSOR.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-SUCCESSOR.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-175-REPAIR-REVIEW.json
  modified:
    - scripts/ci/ci-git-publication.test.py
---

# Plan175 halted: bridge validation accepts stale executable instructions

Task1 implementation is complete at548d54f08: exact historical config fixture SHA-2568e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d, original test RED (1 failure), then7 config tests passed. The production publisher and dryrun source retain their pinned hashes. Neither policy nor current config was changed.

Task2 candidate is preserved at a783add6d, with14 finite tests passing in118.446s after root repairs; these are not acceptance. The generated-command, receipt and temporary-SDK checks include synthetic fixtures only. Root added real log-before-receipt commit ordering and full-dryrun native-output rejection after source review found both missing. All failing development runs were retained externally; final native output and hashes are embedded in175-REPAIR-REVIEW.json.

## Blocking source-review result

A root-owned deterministic reproduction returned `{"status":"verified","stage":"complete","plans":5}` while the same accepted fixture retained:

- `c.plan_pins.length!==174` instead of177;
- `c.halted_plans.length!==22` instead of23;
- `149 -> 174` and `158 -> 174`, assigning proof to a failed plan.

The bridge positive fixture appends new keywords without fixing these original executable assertions and owner instructions. Existing keyword/diff checks therefore do not prove the177 amendment contract. The exact reproducer and actual JSON output are embedded in175-REPAIR-REVIEW.json. This is an unresolved high finding, not a test waiver.

## Outcome and remaining work

Task1 delivered; Task2 acceptance criteria failed source review. Plan175 is halted under its output contract.175-REPAIR-REVIEW.json has status halted and a nonempty unresolved list; prepare refuses it. No176 acceptance, permission probe, receipt, browser, network request, ref change, freeze, disposition or whole-phase verification was run.176/177 remain blocked. Original PLANs/SUMMARYs/evidence and Phase252 bytes are unchanged from entry6b8bccad1a51a3455ab27d88360064d7ac8d30c8.

Required repair: make the bridge consumer reject unchanged executable counts and failed owners, verify all scoped amendments, and replace permissive positive fixtures with actual corrected instructions. Preserve this failed review and current candidate before future repairs. CIREL-01 remains partial_not_reproduced; CIREL-02 unaccepted; whole-phase verification not_started.

Next command: `$gsd-plan-phase 253`. Fresh SDK readiness must confirm no runnable continuation after this halted summary;254 remains pending and unstarted.

## Self-Check: FAILED

14 local tests passed, but the independent bridge source audit demonstrated an acceptance false pass. Plan175 is not complete.
