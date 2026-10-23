---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: '15'
status: complete
subsystem: registration-reliability
tags: [registration, playwright, budget, native-evidence, log-redaction]
requires:
  - phase: 253
    provides: [preserved-registration-capture, reviewed-infrastructure-retry]
provides:
  - credential-safe-registration-logs
  - strict-native-receipt-and-slot-accounting-checks
  - saved-desktop-and-mobile-registration-diagnostics
affects: [253-16]
tech-stack:
  added: []
  patterns: [source-bound-native-receipts, pre-hash-log-redaction, one-use-slot-accounting]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-15-CREDENTIAL-RED.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-15-CREDENTIAL-GREEN.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-15-RECEIPT-RED.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-15-RECEIPT-GREEN.json
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "Redact the entire seeded demo-credential block before writing or hashing command logs, while retaining redaction counts."
  - "Require revision receipts to bind exact source, report, log digests, CLI result, and spent-slot accounting."
  - "Keep the historical preceding-order observation unknown and leave CIREL-01 open until its remaining evidence exists."
patterns-established:
  - "Sanitize sensitive setup output before the first file write and compute digests only from sanitized bytes."
  - "Verify saved native receipts through the real CLI and reject independent report, source, log, status, and budget mutations."
requirements-completed: []
coverage:
  - id: D1
    description: "The registration runner removes seeded credential blocks before persisting or hashing logs."
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#command logs redact the complete seeded demo credentials block before hashing"
        status: pass
    human_judgment: false
  - id: D2
    description: "The revision verifier accepts the saved native desktop and mobile receipts and rejects forged or inconsistent evidence."
    verification:
      - kind: integration
        ref: "scripts/ci/ci-registration-recovery.test.mjs#saved native receipts and adversarial CLI cases"
        status: pass
      - kind: integration
        ref: "node scripts/ci/ci-registration-recovery.mjs --verify-diagnostic .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-15-VERIFIED-REGISTRATION-EVIDENCE.json --revision"
        status: pass
    human_judgment: false
  - id: D3
    description: "Setup failures, occupied ports, early app exit, stale frozen source, and inherited port/build settings are covered by deterministic fixtures."
    verification:
      - kind: integration
        ref: "bash scripts/ci/ci-registration-repro.test.sh"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#occupied port, early app exit, stale source, and inherited environment cases"
        status: pass
    human_judgment: false
actuals:
  tokens: 101766
  tasks: 2
  commits: 43
metrics:
  duration: 8m 13s
  completed_date: 2026-10-13
  started: "2026-10-13T21:37:01Z"
  completed: "2026-10-13T21:45:14Z"
  status: complete
  plan_ledger_commits: 43
  plan_head_before: 5fa42c052922238bd0149cd4ad3845c425c9e501
  plan_head_after: d8e184aa08254e0268473dd06c5bc76f19f7657d
  continuation_commits: 6
  continuation_head_before: 25286d5d4
  continuation_files: 6
  continuation_insertions: 311
  continuation_deletions: 19
  continuation_diff_chars: 25326
  continuation_tokens_chars_div_4: 6331
---

# Phase 253 Plan 15: Registration diagnostics and receipt hardening

**The saved desktop retry and mobile registration diagnostics both pass, and the runner now redacts seeded credentials before persisting logs and verifies native receipt accounting against exact source and artifacts.**

## Performance

- **Duration:** 8m 13s for this continuation; prior halted-attempt time remains in the native ledger.
- **Started:** 2026-10-13T21:37:01Z
- **Completed:** 2026-10-13T21:45:14Z
- **Tasks:** 2 of 2 complete.
- **Changed in this continuation:** 6 files, 311 insertions and 19 deletions; 25,326 diff characters (6,331 characters/4).

## Accomplishments

- Redacted the whole contiguous `=== Demo Credentials ===` fixture block before writing or hashing command logs. Receipts retain the number of redacted fields and blocks without exposing fixture passwords.
- Hardened revision verification against empty or fake evidence, incorrect project/title/status/exit values, altered report or log digests, missing database cleanup, source/config drift, duplicate or spent slots, and over-budget or over-time accounting. Verification now requires `used_slots` to match the actual native attempts.
- Added deterministic child-process and localhost fixtures for setup failure, occupied ports, early app exit, inherited `PORT`/`MIX_BUILD_PATH`, attempt-directory collisions, stale source, and preservation of dirty config bytes. The actual shell and CLI paths are exercised; these cases do not start browsers.
- Verified the saved native receipt through the real revision CLI: desktop retry and mobile each passed, with server POST and success flash asserted, database setup/drop recorded, and per-attempt logs and reports bound by digest.

## Native evidence and remaining limits

The immutable accepted receipt is `253-15-VERIFIED-REGISTRATION-EVIDENCE.json` (SHA-256 `a2ca73dbdad8b4e00766d28b98f7841a9ac2233e7c481ea7fda309b5a310fdfb`). Its status remains `diagnosis_incomplete`: it proves two passing diagnostic attempts, not Phase 253 acceptance.

The first desktop launch had failed before the selected registration test began. The later reviewed desktop retry passed in 46,803 ms, and the mobile diagnostic passed in 40,993 ms. Including that failed launch, the saved historical charge, and preparation, the ledger records 121,680 ms across three new browser launches. The shared retry was consumed; the ledger reports six regular execution slots and nine conditional acceptance commands remaining. The dark combined diagnostic/control remains reserved for Plan 16. The archived original preceding-order log is absent, so its order remains unknown; the original registration cause also remains unknown. No CIREL-01 or Phase 253 acceptance claim is made.

The user-approved cleanup replaced only the two setup-log originals identified in `253-15-APPROVED-LOG-SANITIZATION.json` (SHA-256 `592ff833f5e10a633a0197d21f16706f62931540964f1a76e4910d5b1ec9cfeb`). The saved sanitized receipt and manifest preserve their hashes and redaction record. Other original evidence and failed-attempt artifacts remain unchanged.

The pre-existing plan ledger measures 43 commits from `5fa42c052922238bd0149cd4ad3845c425c9e501` through `d8e184aa08254e0268473dd06c5bc76f19f7657d`; this broad window contains interleaved Plan 18/19 and parent commits, so it is not a Plan 15 commit count. The continuation boundary is `25286d5d4`, after which this work added six commits, listed below. The ledger file itself was left unchanged.

## Task commits in this continuation

1. **Task 1: Freeze the remaining budget and drive one real desktop registration** — `dc80351b2` test(253-15): reject seeded credentials in setup logs; `3a59e797e` fix(253-15): redact seeded demo credentials from logs.
2. **Task 2: Record the mobile diagnostic and enforce adversarial native receipt checks** — `a2cd477a9` test(253-15): reject inconsistent native receipt ledgers; `2c9aad3e9` fix(253-15): validate native revision slot accounting; `cc0cf9f9e` test(253-15): require frozen source identity before reruns; `d8e184aa0` test(253-15): cover setup exit and inherited port isolation.

## Files changed in this continuation

- `scripts/ci/ci-registration-recovery.mjs` — complete seeded-credential block redaction, log digest ordering, and strict native slot accounting.
- `scripts/ci/ci-registration-recovery.test.mjs` — synthetic redaction fixture, real CLI receipt mutations, and hermetic startup/environment controls.
- Four focused JSON records under this phase directory capture RED and GREEN evidence for credential redaction and receipt-accounting contracts. Their fixtures contain only synthetic sentinel credentials.

## Decisions made

- Preserve accepted native facts and historical charges in the saved receipt; do not re-freeze or rerun native slots after source changes.
- Keep `CIREL-01` open because the historical preceding-order evidence and root-cause finding are still missing, even though both current diagnostic attempts passed.
- Keep the dark diagnostic/control with Plan 16 and retain all remaining budget counts without spending native capacity here.

## Deviations from plan

### Auto-fixed issues

**1. [Rule 2 - Missing security protection] Redacted seeded demo credentials before log persistence.**
- **Found during:** Task 1.
- **Issue:** The runner redacted `secret_key_base` but allowed the seeded `Demo Credentials` block into setup logs and hashes.
- **Fix:** Redact the complete fixture block before first write and hash; preserve redaction counts in receipts.
- **Verification:** Synthetic sentinel regression failed before the fix and passed after it; the 26-test recovery suite passed.
- **Committed in:** `dc80351b2`, `3a59e797e`.

**2. [Rule 1 - Receipt validation bug] Reject native slot counters that disagreed with accepted attempts.**
- **Found during:** Task 2.
- **Issue:** The revision verifier could accept a receipt whose `used_slots` list did not match the recorded native attempts.
- **Fix:** Require exact slot list/counter agreement and reject malformed, duplicate, mismatched, or over-budget receipt variants through the real CLI.
- **Verification:** The saved receipt verified; adversarial copied receipts were rejected; all 26 Node tests passed.
- **Committed in:** `a2cd477a9`, `2c9aad3e9`.

**3. [Rule 2 - Missing isolation coverage] Added hermetic controls for startup and inherited process settings.**
- **Found during:** Task 2.
- **Issue:** Setup failure and several child-process isolation behaviors were only covered by static checks or not covered directly.
- **Fix:** Added deterministic CLI/shell fixtures for stale source, process exit, occupied ports, attempt directory collision, dirty config preservation, and inherited compiled port/build path.
- **Verification:** Recovery tests passed 26/26 and shell repro tests passed 5/5.
- **Committed in:** `cc0cf9f9e`, `d8e184aa0`.

**Total deviations:** 3 auto-fixed. All were required for credential safety, receipt correctness, or deterministic verification; no product scope was added.

## Validation

- `node --test --test-reporter=tap scripts/ci/ci-registration-recovery.test.mjs` — 26 passed, 0 failed.
- `bash scripts/ci/ci-registration-repro.test.sh` — 5 passed, 0 failed.
- `node scripts/ci/ci-registration-recovery.mjs --verify-diagnostic .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-15-VERIFIED-REGISTRATION-EVIDENCE.json --revision` — verified 2/2 diagnostics, 2 accepted launches in the receipt, 121,680 ms charged, `diagnosis_incomplete`.
- No native commands or browser runs were issued during this continuation.

## Next phase readiness

Plan 15 implementation and its two planned tasks are complete. Phase acceptance is still open. Plan 16 owns the dark combined diagnostic/control and its reserved budget. The historical preceding-order log and a supported registration root cause remain unavailable; those facts must not be inferred from the passing desktop/mobile attempts.

## Self-Check: PASSED

- The new summary, four contract records, accepted native receipt, approved cleanup record, and sanitized manifest exist and their recorded hashes were read back.
- All six continuation task commits are ancestors of the current branch; the pre-existing 43-commit ledger window remains unchanged and is labeled as broad rather than attributed to Plan 15.
- The only dirty path is the unrelated `.planning/config.json`; its SHA-256 remains `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`, with preserved blob `ab8aa3007f17294e2f224d4ac8482522b79bda24`.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-13*
