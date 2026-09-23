---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 05
status: complete
---

# Plan 241-05 summary

Ported the Phase 239 V3 scanner into the reusable p18 helper and added CI-glob-discoverable
guards for adopter-surface `.planning/` paths and `priv/templates/` bookkeeping vocabulary.
The port preserves paired `(path, literal)` allowlisting, raw-hit reporting, and distinct
dirty-surface versus instrument-failure errors.  Two committed one-violation fixtures prove the
documented cross-product, including the wide-vocabulary superset cell.

Verification: live guards green; full Node prohibition glob green (98 tests); fixture RED/PASS
matrix matches the plan; both fixtures pass `mix format --check-formatted`.

`SURF-04` deliberately remains open for Plan 241-06.
