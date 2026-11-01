# Phase 241 Plan 03 — Honest-skip parity evidence

All commands are local, deterministic `bash -c` invocations. `p21` is offline: it reads
the committed subject, manifest, and delegated `p10` source; it makes no network call and
does not require `gh` or a token.

## BEFORE-P21-REAL-DOC-RED

Status: captured deterministic RED before `MAINTAINING.md` was corrected.

```bash
bash -c 'set -o pipefail; node --test --test-reporter=tap scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs 2>&1 | tee /tmp/241-03-red.txt; rc=${PIPESTATUS[0]}; test "$rc" -ne 0 || { echo "p21 passed against an uncorrected doc — the guard asserts nothing"; exit 1; }; grep -q "example_playwright_shard" /tmp/241-03-red.txt || { echo "red is not attributable to the known rot"; exit 1; }'
```

```text
not ok 2 - every manifest id and step parent is documented in the honest-skip section
error: manifest row `example_playwright_shard` column `id` requires `example_playwright_shard` in MAINTAINING.md's honest-skip section, but it is missing.
# pass 2
# fail 1
```

The guard was committed in this RED state before the documentation correction. The permanent
fixture below makes both independent conditions reproducible at later HEADs.

## AFTER-P21-FIXTURE-RED-AND-REAL-GREEN

Status: captured deterministic fixture RED and corrected-subject GREEN.

```bash
bash -c 'set -o pipefail; GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p21-maintaining-stale-topology.md node --test --test-reporter=tap scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs > /tmp/241-03-fixture-both.txt 2>&1; rc=$?; test "$rc" -ne 0 || { echo "fixture did not red"; exit 1; }; grep -q "example_playwright_shard" /tmp/241-03-fixture-both.txt || { echo "fixture red is not attributable to the known rot"; exit 1; }; grep -q "parent_job_id" /tmp/241-03-fixture-both.txt || { echo "fixture did not exercise the missing step parent"; exit 1; }; node --test --test-reporter=tap scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs'
```

```text
fixture:
not ok 2 - every manifest id is documented in the honest-skip section
error: manifest row `example_playwright_shard` column `id` requires `example_playwright_shard` in MAINTAINING.md's honest-skip section, but it is missing.
not ok 3 - every step parent is documented in the honest-skip section
error: manifest row `design_gallery_snapshots` column `parent_job_id` requires `example_playwright_shard` in MAINTAINING.md's honest-skip section, but it is missing.
# pass 2
# fail 2

real MAINTAINING.md:
# tests 4
# pass 4
# fail 0
```

## AFTER-P21-MANIFEST-AND-PROHIBITIONS-GREEN

Status: captured deterministic final verification.

```bash
bash -c 'set -eo pipefail; for f in .github/ci-skip-manifest.tsv test/fixtures/prohibitions/p10-manifest-stale-entry.tsv; do grep -q "p21-honest-skip-parity.test.mjs" "$f"; n=$(grep -c "prohibitions/honest-skip-parity" "$f" || true); test "$n" = "0" || { echo "$f still cites a path that does not exist"; exit 1; }; done; node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs; mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs; test -z "$(git diff --name-only "$(git merge-base HEAD origin/main)" -- .github/workflows/ci.yml mix.exs)"'
```

```text
node --test scripts/ci/prohibitions/*.test.mjs: 97 tests, 97 pass, 0 fail
mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs: 7 tests, 0 failures
manifest and p10 fixture citations: both reference p21; zero stale unprefixed citations
ci.yml and mix.exs: no diff from origin/main for this plan
```

## Recorded dispositions

1. **`example_playwright_smoke` manifest row is inaccurate at HEAD.** Its `gate_level=step`
   description does not match the pure aggregator job. It is not fixed here; it is filed in
   `.planning/todos/pending/2026-09-19-example-playwright-smoke-manifest-step-gate-inaccuracy.md`.
   `p10` deliberately skips this ambiguous job-row comparison and `p21` deliberately does not
   interpret the gate column, so changing the cell requires separately measured guard work.
2. **`ci-gate.needs` remains deliberately unasserted** (D-14 / FUT-03). The milestone's Out of
   Scope table forbids editing it, including the known `example_unit_smoke` omission.
3. **Gate-column semantics remain deliberately unasserted** (D-13). Parsing `${{ }}` expressions
   here would turn a documentation parity guard into a YAML-expression evaluator that reds on
   unrelated `ci.yml` changes.
