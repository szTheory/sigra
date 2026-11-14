# Current Plan180 execution authority: versioned consumer

Quick261021-drl implements the user's explicit instruction to repair the28-halt incompatibility additively while preserving179-pinned files, its real receipt, historical halts and budgets. This addendum supersedes only Plan180's stale repair-owner/count/consumer/simulation instructions. The original180 PLAN, original helper/tests,179 receipt/log/preflight and every original SUMMARY remain byte-identical to the179 receipt source. No numbered successor plan is needed.

This quick task does not execute180 or amend168–172 in the project. It creates no180 SUMMARY/bridge record, acceptance attempt, freeze, disposition, budget or hosted request. Implementation of this consumer is separate from actual180 bridge verification and whole-phase verification.

## Current facts and finite scope

-179 is complete with its actual receipt;181/182/183 remain halted. Current counts:183plans,76completed,28halted,79without summaries.
- Exact halted IDs:02,07,09,12,16,27,40,51,63,73,84,92,97,104,113,122,134,143,146,155,167,173,174,175,178,181,182,183.
- Sparse reconciliation domain:01–167 plus173–178 and181–183,176members partitioned as75original completed,28halted and73unstarted. The73 targets remain original71 plus176/177. All183 PLANs are pinned.168 and179/180 are ordinary proof owners outside that partition; no halted plan supplies a completed repair.
- All historical halts, prior failed receipts, source-producing commits, never-run instructions and the full-paged attempt_jobs7/7 stop stay literal. No acceptance rerun or request/retry/time/page/size limit increase is authorized.

## Execute180 with the new read-only consumer

Use `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-BRIDGE-V2.py` for every180/168/169/172 local receipt/bridge check. It imports immutable leaf checks from the179-pinned helper and carries explicit versioned bridge functions; it exposes no prepare/enter/write-receipt or hosted operation. Never patch the old helper or run its old27-halt simulation.

1. On a clean committed checkout, run `python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer 168`. This reopens the actual179 output, permission context, source hashes and maintenance authority. It tolerates shared routing changes and only the exact five v2-rendered plan amendments, verified through a v2 bridge record.
2. Read179's source_commit from its actual receipt. Preserve exactly the seven original PLANs168–172/176/177 at `refs/gsd/phase253-successor-180-v2-plan-originals`, pointing to that source; read back every blob/path/byte/hash before any amendment. Do not move an existing different ref.
3. Render externally with `python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-BRIDGE-V2.py render-amendments --output-dir <fresh-external-directory>`. The renderer reads only receipt-pinned originals. Stage entry applies only168/169; stage complete applies170–172 as well. No other original file changes.176/177 remain original and unexecuted.
4. Use `253-180-BRIDGE-V2-RECORD.json`, schema `sigra.phase253.successor-bridge/v2`. Keep Plan180's original record fields: stage,179 source_commit, preservation_ref, exact seven originals with blob/sha256/bytes, every original Phase253/252 protected_source_binding, amended_sha256 for exactly2 entry or5 complete paths, and dispositions_for[]. Record176->179/177->180 as unexecuted retirements, never fabricated outputs.
5. After entry is committed clean, run the v2 `verify-bridge --stage entry --record <v2-record>` and `verify-receipt --consumer 168` commands. After the complete amendments are committed, set sdk_copy to an empty placeholder object, commit the record, then obtain the actual installed-SDK report with `python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-BRIDGE-V2.py sdk-copy --output <fresh-external-report.json>`, preserve its native four query outputs outside the checkout under a scoped durable ref, and bind report_path/report_sha256 in sdk_copy. The source manifest excludes only the v2 bridge record to avoid self-hashing. Tests may simulate180 and ordinary future168–172/73dispositions only in a labeled disposable committed copy. They must preserve every existing SUMMARY, especially halted183, and produce183rows/0incomplete/28exacthalts. Simulated final summaries are155nonhalted plus28halted; they are not actual phase completion.
6. Commit complete record/report bindings and run v2 `verify-bridge --stage complete --sdk --record <v2-record>` plus `verify-receipt --consumer 168` on the clean actual checkout. The original170/171 hosted tasks and all eight172 completion links must remain byte-identical. Only after actual verification succeeds may180 receive a complete SUMMARY. A failure stops180 and leaves its real diagnostic; it does not authorize a new179 attempt.

Plan169's rendered instructions and executable assertions use exact28 halt IDs,183 pins,73 target IDs and actual179/180 proof owners. Its consumer still requires the original accepted-only/dispositioned predicate, v1–R12 checks and unchanged deadlines. Plans170/171 retain their exact hosted operator tasks. Plan172 retains all eight original completion links; its permitted local verifier and exact target-exclusion assertions alone change.

## Stopping point

After actual180 completion, run `$gsd-progress` to inspect168 readiness and remaining original CI proof. Do not automatically launch hosted CI. CIREL-01 remains partial_not_reproduced, CIREL-02 remains unaccepted and whole-phase verification remains not_started. Recheck254 readiness only after actual253 completion;254 is not started here.
