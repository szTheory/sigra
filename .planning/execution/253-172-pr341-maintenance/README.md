# PR341: retain success and finish only the missing docs proof

PR341 CI succeeded. The original verifier rejected its212-file comparison because its code incorrectly capped the file list below100. GitHub documents300 as the compare endpoint limit. The repaired consumer accepts1–299 unique nonempty filenames and still rejects a saturated300-file response, duplicates and malformed entries. The saved212-file response exactly matches all212 frozen local paths. No response or closed attempt was changed.

The corrected, separately retained verifier accepts the original normal evidence with accepted_live=true. The original frozen verifier still rejects it. Both facts are retained. No CI rerun is needed for this comparison-consumer repair. The source candidate remainsa6838a8f9; the changed checker is recorded separately.

Lesson applied: successful external results are reusable read-only inputs, not budgets to reopen. The next hosted request is only the missing docs-only PR. Its fresh window must have its own approval and ledger. Verify the two families independently with the exact same source freeze; do not concatenate their ledgers or pretend they came from one window. The original flaky failure remains not reproduced and Phase253 remains unverified.
