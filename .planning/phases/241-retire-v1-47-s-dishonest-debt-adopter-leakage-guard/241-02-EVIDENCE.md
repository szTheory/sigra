# 241-02 evidence — single-owner library CI contract

## Attributable RED and real-workflow GREEN

```sh
SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/phase241-library-economics-two-owners.yml MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs
```

Exited non-zero from the replacement assertion, with this captured message:

```text
more than one owner of the full library suite: found 2 owner(s): ["library_tests_first", "library_tests_second"]
```

The fixture's other derived properties pass; the red names the two violating jobs.

```sh
MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs
```

Against `.github/workflows/ci.yml`: 4 tests, 0 failures.

## Broken-run controls and compiler check

```sh
SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/p18-planning-path-leak.ex MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs
```

Exited non-zero with `library_tests* parse found no jobs — the workflow parse broke, not a pass`.

```sh
SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/no-such-subject.yml MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs
```

Exited non-zero with `missing subject is a broken run, never an absent violation`.

```sh
MIX_ENV=test mix compile --warnings-as-errors
MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs
```

Compilation passed; the three test files reported 28 tests, 0 failures.  The Phase 235 tests
exercise the receipt's two remaining live readers.

## Receipt disposition

The test's dependency on `235-FAST-01-REMEDIATION.json` is retired deliberately (D-09).  The JSON
file remains because `scripts/ci/capture-fast-01-gap-closure.sh` and
`phase_235_fast_01_gap_closure_contract_test.exs` still read it (D-10).  The receipt claimed a
sha256 for this same contract test, but no check recomputed that digest; after any rewrite the value
was silently false while the receipt assertion remained green.  That is the defect SC-2 removes.
Going forward, the tamper record is public Git history and the Phase 239-style evidence files.
The capture script verifies the receipt's `file_digests` at its immutable cutoff SHA using
`git show "$CUTOFF_SHA:$file"`, so retiring this live HEAD dependency does not affect its
verification.
