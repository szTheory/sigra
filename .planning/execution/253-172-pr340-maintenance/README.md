# PR340: actual failure and offline repair inside Plan172

The approved source4734916ee attempt is immutable at dc1e552aa. Its six hosted canary cases and independent verifier passed. PR340 CI failed in the library suite; Fast checks and the browser aggregate passed. The local independent verifier separately rejected the absent shared protection/rules snapshot. The attempt used93 canary and30 PR requests,37 canary jobs,7 dispatches and1 draft PR;0 reruns. It is closed. No docs-only PR was created and no request was made after the halt.

The exact candidate reproduces a stale Elixir assertion still naming the old planning path after the Node guard moved to an explicit source fixture. The repair makes both consumers read the same fixture and verify its origin and bytes. The original three captured slots, source ledger and known-bad controls remain unchanged. Saved job-step metadata locates the hosted library failure; detailed hosted logs were not downloaded, so the local stacktrace is labeled an offline reproduction.

The operator now types its rate/main reads as shared, but Collector.preflight incorrectly treated any shared row as a complete required-check/workflow snapshot. The new fail-first regression starts with those two actual local-HTTPS transport reads, collects both PR families and invokes the independent verifier. It reproduces the exact hosted verifier error before the fix and verifies both families after it. Incomplete, duplicated and failed snapshots stop before requests. The independent verifier is unchanged.

Lesson applied: testing the operator up to the point where the collector starts misses the handoff. Future bundle startup checks must execute the generated collector preflight as well, while full local transport/collector/verifier tests cover both families. Run the full exported-candidate library suite after any provenance consumer change, not only the Node guard.

Initial local library environment failures remain in separate logs: stale saved DB port, missing Git identity in an exported tree, and nested macOS sandbox restriction. The final candidate run uses its actual Git identity and the available local Postgres; it passes2656 tests,33 doctests and3 properties, with12 skipped and22 excluded as printed. No native browser acceptance or CI rerun was launched.

Both requirements remain open. CIREL-01 is partial_not_reproduced. CIREL-02 still lacks verified normal and docs-only PR results. Continue existing Plan172; no new quick or numbered plan.
