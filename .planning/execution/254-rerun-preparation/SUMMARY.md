# Phase 254 approved rerun continuation

Both preparation invocations failed. No measured sample was started, no comparison window was opened, and the phase remains unverified.

The baseline retained its original merge checkout and workflow. It failed the shallow Git-history comparison and wrote a docs-only result despite the missing diff; ECR also refused the PostgreSQL image with a data-limit error. No successful full native workload or warm cache was established.

Candidate draft PR #345 retained the exact reviewed tree and reached the library suite: 2,659 tests, one stale workflow assertion failed. That assertion, current Git-history handling, and the browser execution-record capture parser are repaired locally. Failed hosted sources and outcomes are unchanged.

The original preparation pass spent two invocations, zero trigger retries, and186 HTTP requests. An artifact-only parser repair reused its original clock and request counter; the earlier closed bookkeeping ledger and failed capture were preserved first. It started no CI run. The pass is now closed. All three saved snapshots verify their hashes, including 20 selected candidate artifacts with all five execution records. Auxiliary generated-admin-report inventories are retained; their ZIPs are outside this selected measurement acquisition.

See RESULT.json for authenticated source/tree identities, raw data paths, failures and the exact request ledger. FINAL-RECOVERY.json names the durable recovery ref and verified file hashes. The original Phase252 baseline and original Plan08 halted records remain unchanged.

REBASELINE-PROPOSAL.json and PROPOSED-BASELINE-REPAIR.patch are reviewable proposals only: preserve Git history, use the candidate's PostgreSQL registry, and update the one live image assertion in a newly amended baseline source. A scoped six-test check of that proposed original-source workspace passed. No hosted action has been started for this proposal.

Next command after explicit approval of that baseline amendment and separate two-invocation preparation allowance: `$gsd-execute-phase 254`. Resume the same Plan08. Do not reset old budgets, replace either failure, mark CISPEED requirements complete, or advance to Phase 255.
