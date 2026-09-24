# Phase 241 Plan 01 Evidence

**Recorded:** 2026-09-22  
**Scope:** ADR 004 and removal of the unowned `Sigra.CI.ExUnitTimingFormatter` support module.

## Cross-reference consumer sweep (Task 1, Step A)

```bash
bash -c 'refs=$(git for-each-ref --format="%(refname)" refs/heads refs/remotes); count=0; while IFS= read -r ref; do paths=$(git grep -l SIGRA_EXUNIT_TIMING_PATH "$ref" -- ":!test/support" ":!.planning" 2>/dev/null || true); if [ -n "$paths" ]; then count=$((count + 1)); printf "REF %s\\n%s\\n" "$ref" "$paths"; fi; done <<EOF
$refs
EOF
printf "COUNT %s\\n" "$count"'
```

Captured output (the ADR records the same full set):

```text
REF refs/heads/agent-exec-235-1-04-evidence
.github/workflows/ci.yml; scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; test/sigra/planning/phase_233_library_economics_contract_test.exs; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/agent-exec-235-1-12-evidence
scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; scripts/ci/library-partitions.sh; scripts/ci/library-partitions.test.sh; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/agent-exec-235-1-18-evidence
scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; scripts/ci/library-partitions.sh; scripts/ci/library-partitions.test.sh; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/agent-exec-235-1-29-authority
scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; scripts/ci/library-partitions-portability.test.sh; scripts/ci/library-partitions.sh; scripts/ci/library-partitions.test.sh; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/ci/phase-235-1-evidence
scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; scripts/ci/library-partitions.sh; scripts/ci/library-partitions.test.sh; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/ci/phase-235-16-source-complete
scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; scripts/ci/library-partitions-portability.test.sh; scripts/ci/library-partitions.sh; scripts/ci/library-partitions.test.sh; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/gsd/phase-232-playwright-economics
.github/workflows/ci.yml; test/sigra/planning/phase_233_library_economics_contract_test.exs
REF refs/remotes/origin/ci/phase-235-1-evidence
scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; scripts/ci/library-partitions-portability.test.sh; scripts/ci/library-partitions.sh; scripts/ci/library-partitions.test.sh; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/remotes/origin/ci/phase-235-16-source-complete
.github/workflows/ci.yml; scripts/ci/library-economics.sh; scripts/ci/library-economics.test.sh; test/sigra/planning/phase_233_library_economics_contract_test.exs; test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/remotes/origin/gsd/phase-232-playwright-economics
.github/workflows/ci.yml; test/sigra/planning/phase_233_library_economics_contract_test.exs
COUNT 10
```

## Pre- and post-delete source sweep (Task 1, Steps B and E)

The checkout contains nested `.claude/worktrees/` sibling worktrees. They are not part of this
repository's source tree and are excluded to avoid treating another agent's copies as live source.
`|| true` preserves the intended zero-match success case under `set -o pipefail`.

```bash
bash -c 'set -eo pipefail; grep -rIl -e ExUnitTimingFormatter -e SIGRA_EXUNIT_TIMING . --exclude-dir=_build --exclude-dir=deps --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.gsd --exclude-dir=.planning --exclude-dir=.claude | sort'
```

Captured pre-delete output:

```text
./test/support/ci/ex_unit_timing_formatter.ex
./test/support/ci/ex_unit_timing_formatter_test.exs
```

```bash
bash -c 'set -eo pipefail; matches=$(grep -rIl -e ExUnitTimingFormatter -e SIGRA_EXUNIT_TIMING . --exclude-dir=_build --exclude-dir=deps --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.gsd --exclude-dir=.planning --exclude-dir=.claude || true); n=$(printf "%s\\n" "$matches" | sed "/^$/d" | wc -l | tr -d " "); test "$n" = "0"; echo "source-reference-count=$n"'
```

Captured post-delete output:

```text
source-reference-count=0
```

## Alias and compile proof (Task 2)

```bash
bash -c 'set -eo pipefail; touched=$(git diff --name-only "$(git merge-base HEAD origin/main)" -- mix.exs test/sigra/planning/phase_233_library_economics_contract_test.exs); echo "touched=[$touched]"; test -z "$touched"'
```

Captured output:

```text
touched=[]
```

```bash
bash -c 'set -eo pipefail; MIX_ENV=test mix compile --warnings-as-errors; echo "compile=passed"'
```

Captured output:

```text
compile=passed
```

```bash
bash -c 'set -eo pipefail; mix test test/sigra/planning/phase_233_library_economics_contract_test.exs'
```

Captured output:

```text
Running ExUnit with seed: 673111, max_cases: 36
Excluding tags: [:upgrade]

......
Finished in 0.06 seconds (0.06s async, 0.00s sync)
6 tests, 0 failures
```

## Honest full-suite claim (SC-1)

The full-suite claim for SC-1 is made against **CI**, not a local `MIX_ENV=test mix ci` claim. A
local full-suite run carries six environmental `Sigra.Audit.Forwarders.ThreadlineTest` failures
(`Threadline.attach/1` undefined) unrelated to this phase. Those tests are **not** excluded from
the suite and no `--exclude` was added; the local failure is named rather than hidden.

**CI evidence:** [run 35936689143](https://github.com/szTheory/sigra/actions/runs/35936689143)
completed successfully on attempt 1 for head SHA `8b7cd66379900596a922cf3882203b7fffd2cb5e`.
The `Library tests shard`, aggregate `Library tests`, and `ci-gate` all passed; the full required
PR checks, including install and browser lanes, passed as well. No retry was used within that run.

The first CI run at `997d8a240456686e19b183c9fd7dabd387ff9c7f` stopped at `mix format
--check-formatted` because the unrelated Phase 242 contract test was unformatted. The four
formatter-only wraps in `test/sigra/planning/phase_242_shift_left_contract_test.exs` were applied
in commit `8b7cd663`; the successful run above validates that resulting exact code head.
