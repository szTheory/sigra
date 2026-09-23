# Phase 241 Plan 03: Honest-skip parity evidence

All observations were run locally against committed repository artifacts; the p21 guard is
offline and neither requires `gh` nor a token.

## Task 1 — RED before documentation correction

Command:

```bash
bash -c 'set -o pipefail; node --test --test-reporter=tap scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs 2>&1 | tee /tmp/241-03-red.txt; rc=${PIPESTATUS[0]}; test "$rc" -ne 0; grep -q "example_playwright_shard" /tmp/241-03-red.txt'
```

Captured output:

```text
# Subtest: every manifest id and step parent is documented in the honest-skip section
not ok 2 - every manifest id and step parent is documented in the honest-skip section
  error: |-
    manifest row kind=step id=design_gallery_snapshots has parent_job_id=example_playwright_shard, which is missing from MAINTAINING.md's honest-skip section.
    manifest row kind=job id=example_playwright_shard is missing from MAINTAINING.md's honest-skip section.
    2 !== 0
# tests 3
# pass 2
# fail 1
```

The guard was then committed RED as `03ff9eef` before `MAINTAINING.md` changed.

## Task 2 — fixture RED and corrected-document GREEN

Commands:

```bash
bash -c 'set -o pipefail; GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p21-maintaining-stale-topology.md node --test scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs > /tmp/241-03-fixture.txt 2>&1; rc=$?; test "$rc" -ne 0; grep -q "example_playwright_shard" /tmp/241-03-fixture.txt; node --test --test-reporter=tap scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs'
node --test --test-reporter=tap scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs
```

Captured fixture output:

```text
not ok 2 - every manifest id and step parent is documented in the honest-skip section
  error: |-
    manifest row kind=step id=design_gallery_snapshots has parent_job_id=example_playwright_shard, which is missing from MAINTAINING.md's honest-skip section.
    manifest row kind=job id=example_playwright_shard is missing from MAINTAINING.md's honest-skip section.
# tests 3
# pass 2
# fail 1
```

Captured corrected-document output:

```text
# tests 3
# pass 3
# fail 0
```

## Task 3 — citations and full prohibition suite

Command:

```bash
bash -c 'set -eo pipefail; for f in .github/ci-skip-manifest.tsv test/fixtures/prohibitions/p10-manifest-stale-entry.tsv; do grep -q "p21-honest-skip-parity.test.mjs" "$f"; n=$(grep -c "prohibitions/honest-skip-parity" "$f" || true); test "$n" = "0"; done; node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs; mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs; test -z "$(git diff --name-only "$(git merge-base HEAD origin/main)" -- .github/workflows/ci.yml mix.exs)"'
```

Captured output:

```text
1..96
# tests 96
# pass 96
# fail 0
Finished in 0.01 seconds
7 tests, 0 failures
PASS: citations, p21/p10 prohibition suite, Phase 236 guard, and no forbidden workflow or mix edits
```

## Recorded dispositions

1. The `example_playwright_smoke` manifest row claims `gate_level=step`, although that job is a
   pure aggregator with no step-level `docs_only` gate. This plan does not change that cell: p10
   deliberately skips this unresolvable class and p21 must not evaluate gate expressions. It is
   filed as `.planning/todos/pending/2026-09-23-example-playwright-smoke-manifest-gate-level-is-inaccurate.md`.
2. `ci-gate.needs` remains deliberately unasserted (D-14 / FUT-03); the existing
   `example_unit_smoke` todo owns that separate concern.
3. Gate-column semantics remain deliberately unasserted (D-13), avoiding a second YAML-expression
   evaluator that would red on unrelated workflow edits.
