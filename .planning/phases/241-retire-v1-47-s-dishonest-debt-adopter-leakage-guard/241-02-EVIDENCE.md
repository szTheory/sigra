# 241-02 — DEBT-02 single-owner contract evidence

Captured on 2026-09-19 against the committed Phase 241 Plan 02 changes. Every command below was
run through `bash -c`; the RED and missing-subject checks intentionally return non-zero from their
inner `mix test` command and turn that result into a successful proof only after checking the
attributable output.

## RED — committed two-owner fixture

```bash
bash -c 'set -o pipefail; SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/phase241-library-economics-two-owners.yml mix test test/sigra/planning/phase_233_library_economics_contract_test.exs 2>&1 | tee /tmp/241-02-red.txt; rc=${PIPESTATUS[0]}; test "$rc" -ne 0 || { echo "fixture did not red — this is not a proof"; exit 1; }; grep -q "more than one owner of the full library suite" /tmp/241-02-red.txt || { echo "red is not attributable to the replacement assertion"; exit 1; }; mix test test/sigra/planning/phase_233_library_economics_contract_test.exs'
```

Result: PASS as a fail-first proof. The fixture run exited non-zero, its output contained the
replacement assertion's runtime-generated distinctive phrase, and the same file then passed
against the real `.github/workflows/ci.yml` with no override.

Captured fixture failure message (verbatim):

```text
1) test library execution universe is fail-closed and has one full-suite owner (Sigra.Planning.Phase233LibraryEconomicsContractTest)
   test/sigra/planning/phase_233_library_economics_contract_test.exs:6
   more than one owner of the full library suite: found 2 full-suite invocations in job ids ["library_tests", "library_tests_shard"]; expected exactly 1
   code: assert length(full_suite_invocations) == 1,
```

GREEN result: `4 tests, 0 failures`.

## Missing-subject direction

```bash
bash -c 'set -o pipefail; SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/does-not-exist.yml mix test test/sigra/planning/phase_233_library_economics_contract_test.exs 2>&1 | tee /tmp/241-02-missing-subject.txt; rc=${PIPESTATUS[0]}; test "$rc" -ne 0 || { echo "missing subject did not fail"; exit 1; }; grep -q "a missing subject is a broken run, never an absent violation" /tmp/241-02-missing-subject.txt || { echo "missing-subject failure was not attributable to subject resolution"; exit 1; }'
```

Result: PASS as a fail-closed proof. The subject path did not exist and the captured failure was:

```text
subject not found at test/fixtures/prohibitions/does-not-exist.yml — a missing subject is a broken run, never an absent violation
```

## Warnings-as-errors compilation

```bash
bash -c 'set -eo pipefail; MIX_ENV=test mix compile --warnings-as-errors; printf "compile --warnings-as-errors: PASS\\n"'
```

Result: `compile --warnings-as-errors: PASS`.

## Retired remediation-receipt dependency

D-09 deliberately retires only `phase_233_library_economics_contract_test.exs`'s dependency on
`235-FAST-01-REMEDIATION.json`: its two receipt assertions, `@remediation_path`, and their four
private helpers were removed. The receipt asserted a sha256 for this very test file, and nothing
recomputed that digest after a rewrite. It could therefore remain green while silently describing
old bytes — the dishonest-debt class this plan removes.

The archived JSON remains in place under
`.planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/`. D-10 requires
that retention because two live readers remain: `scripts/ci/capture-fast-01-gap-closure.sh` and
`test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs`. The collector mechanically
checks each `file_digests` entry at its immutable cutoff SHA with `git show "$CUTOFF_SHA:$file"`,
not at HEAD, so this rewrite causes no collateral damage. Going forward, the tamper record is
public-repository git history plus the Phase 239-style committed evidence files, rather than a
stale self-digest receipt.
