# Plan 241-01 evidence — TEST-01/TEST-02 supersession

**Captured:** 2026-09-19
**Execution HEAD before this evidence commit:** `ff5dda03`

This record captures the commands and output used to make the formatter deletion auditable. The
source sweep excludes generated and metadata directories so it measures repository source, rather
than stale build artifacts or this plan's own prose.

## Cross-ref consumer sweep (pre-delete)

```sh
bash -c 'set -o pipefail
count=0
while IFS= read -r ref; do
  paths=$(git grep -l SIGRA_EXUNIT_TIMING_PATH "$ref" -- ":!test/support" ":!.planning" 2>/dev/null || true)
  if test -n "$paths"; then
    printf "REF %s\\n%s\\n" "$ref" "$paths"
    count=$((count + 1))
  fi
done < <(git for-each-ref --format="%(refname)" refs/heads refs/remotes)
printf "MATCHING_REFS=%s\\n" "$count"'
```

```text
REF refs/heads/agent-exec-235-1-04-evidence
refs/heads/agent-exec-235-1-04-evidence:.github/workflows/ci.yml
refs/heads/agent-exec-235-1-04-evidence:scripts/ci/library-economics.sh
refs/heads/agent-exec-235-1-04-evidence:scripts/ci/library-economics.test.sh
refs/heads/agent-exec-235-1-04-evidence:test/sigra/planning/phase_233_library_economics_contract_test.exs
refs/heads/agent-exec-235-1-04-evidence:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/agent-exec-235-1-12-evidence
refs/heads/agent-exec-235-1-12-evidence:scripts/ci/library-economics.sh
refs/heads/agent-exec-235-1-12-evidence:scripts/ci/library-economics.test.sh
refs/heads/agent-exec-235-1-12-evidence:scripts/ci/library-partitions.sh
refs/heads/agent-exec-235-1-12-evidence:scripts/ci/library-partitions.test.sh
refs/heads/agent-exec-235-1-12-evidence:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/agent-exec-235-1-18-evidence
refs/heads/agent-exec-235-1-18-evidence:scripts/ci/library-economics.sh
refs/heads/agent-exec-235-1-18-evidence:scripts/ci/library-economics.test.sh
refs/heads/agent-exec-235-1-18-evidence:scripts/ci/library-partitions.sh
refs/heads/agent-exec-235-1-18-evidence:scripts/ci/library-partitions.test.sh
refs/heads/agent-exec-235-1-18-evidence:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/agent-exec-235-1-29-authority
refs/heads/agent-exec-235-1-29-authority:scripts/ci/library-economics.sh
refs/heads/agent-exec-235-1-29-authority:scripts/ci/library-economics.test.sh
refs/heads/agent-exec-235-1-29-authority:scripts/ci/library-partitions-portability.test.sh
refs/heads/agent-exec-235-1-29-authority:scripts/ci/library-partitions.sh
refs/heads/agent-exec-235-1-29-authority:scripts/ci/library-partitions.test.sh
refs/heads/agent-exec-235-1-29-authority:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/ci/phase-235-1-evidence
refs/heads/ci/phase-235-1-evidence:scripts/ci/library-economics.sh
refs/heads/ci/phase-235-1-evidence:scripts/ci/library-economics.test.sh
refs/heads/ci/phase-235-1-evidence:scripts/ci/library-partitions.sh
refs/heads/ci/phase-235-1-evidence:scripts/ci/library-partitions.test.sh
refs/heads/ci/phase-235-1-evidence:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/ci/phase-235-16-source-complete
refs/heads/ci/phase-235-16-source-complete:scripts/ci/library-economics.sh
refs/heads/ci/phase-235-16-source-complete:scripts/ci/library-economics.test.sh
refs/heads/ci/phase-235-16-source-complete:scripts/ci/library-partitions-portability.test.sh
refs/heads/ci/phase-235-16-source-complete:scripts/ci/library-partitions.sh
refs/heads/ci/phase-235-16-source-complete:scripts/ci/library-partitions.test.sh
refs/heads/ci/phase-235-16-source-complete:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/heads/gsd/phase-232-playwright-economics
refs/heads/gsd/phase-232-playwright-economics:.github/workflows/ci.yml
refs/heads/gsd/phase-232-playwright-economics:test/sigra/planning/phase_233_library_economics_contract_test.exs
REF refs/remotes/origin/ci/phase-235-1-evidence
refs/remotes/origin/ci/phase-235-1-evidence:scripts/ci/library-economics.sh
refs/remotes/origin/ci/phase-235-1-evidence:scripts/ci/library-economics.test.sh
refs/remotes/origin/ci/phase-235-1-evidence:scripts/ci/library-partitions-portability.test.sh
refs/remotes/origin/ci/phase-235-1-evidence:scripts/ci/library-partitions.sh
refs/remotes/origin/ci/phase-235-1-evidence:scripts/ci/library-partitions.test.sh
refs/remotes/origin/ci/phase-235-1-evidence:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/remotes/origin/ci/phase-235-16-source-complete
refs/remotes/origin/ci/phase-235-16-source-complete:.github/workflows/ci.yml
refs/remotes/origin/ci/phase-235-16-source-complete:scripts/ci/library-economics.sh
refs/remotes/origin/ci/phase-235-16-source-complete:scripts/ci/library-economics.test.sh
refs/remotes/origin/ci/phase-235-16-source-complete:test/sigra/planning/phase_233_library_economics_contract_test.exs
refs/remotes/origin/ci/phase-235-16-source-complete:test/sigra/planning/phase_235_1_library_economics_contract_test.exs
REF refs/remotes/origin/gsd/phase-232-playwright-economics
refs/remotes/origin/gsd/phase-232-playwright-economics:.github/workflows/ci.yml
refs/remotes/origin/gsd/phase-232-playwright-economics:test/sigra/planning/phase_233_library_economics_contract_test.exs
MATCHING_REFS=10
```

## Source blast-radius sweep (before and after deletion)

```sh
bash -c 'set -eo pipefail
grep -rIl -e ExUnitTimingFormatter -e SIGRA_EXUNIT_TIMING . \\
  --exclude-dir=_build --exclude-dir=deps --exclude-dir=node_modules \\
  --exclude-dir=.git --exclude-dir=.gsd --exclude-dir=.planning | sort'
```

```text
./test/support/ci/ex_unit_timing_formatter.ex
./test/support/ci/ex_unit_timing_formatter_test.exs
SOURCE_MATCHING_FILES=2
```

```sh
bash -c 'set -eo pipefail
n=$((grep -rIl -e ExUnitTimingFormatter -e SIGRA_EXUNIT_TIMING . \\
  --exclude-dir=_build --exclude-dir=deps --exclude-dir=node_modules \\
  --exclude-dir=.git --exclude-dir=.gsd --exclude-dir=.planning || true) | wc -l | tr -d " ")
printf "SOURCE_MATCHING_FILES=%s\\n" "$n"
test "$n" = "0" || { echo "still referenced in $n file(s)"; exit 1; }'
```

```text
SOURCE_MATCHING_FILES=0
```

The post-delete command intentionally guards only `grep`'s expected zero-match status before the
pipeline. With `set -o pipefail`, an unguarded zero-match grep would abort before `wc` can prove the
required count; this guard preserves the asserted zero rather than masking a nonzero result.

## Strict compile and alias contract

```sh
bash -c 'set -eo pipefail
touched_previous=$(git diff --name-only HEAD~ -- mix.exs)
printf "touched_previous=[%s]\\n" "$touched_previous"
test -z "$touched_previous"
touched=$(git diff --name-only "$(git merge-base HEAD origin/main)" -- mix.exs test/sigra/planning/phase_233_library_economics_contract_test.exs)
printf "touched=[%s]\\n" "$touched" >&2
test -z "$touched"
MIX_ENV=test mix compile --warnings-as-errors
mix test test/sigra/planning/phase_233_library_economics_contract_test.exs'
```

```text
touched_previous=[]
touched=[]
Generated sigra app
Running ExUnit with seed: 941279, max_cases: 36
Excluding tags: [:upgrade]

.....

11:02:56.239 [debug] Tzdata polling for update.

11:02:56.639 [debug] Tzdata polling shows the loaded tz database is up to date.
.

Finished in 16.1 seconds (16.1s async, 0.00s sync)
6 tests, 0 failures
```

## Honest full-suite claim

The full-suite claim for SC-1 is made against **CI** at this phase's final committed HEAD; it is
not a local-green claim. A local `MIX_ENV=test mix ci` currently carries 6 environmental
`Sigra.Audit.Forwarders.ThreadlineTest` failures (`Threadline.attach/1 undefined`) that are
unrelated to this plan and are green in CI at the same commit. Those tests are **not** excluded
from the suite, and no `--exclude` is added; the failure mode is named instead of hidden.

**CI run URL:** `PENDING — filled at phase verification` (this plan does not push).
