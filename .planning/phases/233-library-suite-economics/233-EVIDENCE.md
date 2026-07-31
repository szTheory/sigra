# Phase 233 — Library Timing Evidence Ledger

## Timing-probe receipt

Status: observed. This is the retry-free PR timing probe for the pre-extraction topology; it does **not** claim TEST-02 complete.

- PR: [#175](https://github.com/szTheory/sigra/pull/175)
- Run: [30666977944](https://github.com/szTheory/sigra/actions/runs/30666977944)
- Event: `pull_request`
- Head SHA: `5803ef3d03f9a224143a70a3ffe55aefdf0aa621`
- Attempt: `1` (retry-free)
- Workflow conclusion: `success`

The run was selected by matching `workflow=CI`, `event=pull_request`, PR `175`, and the exact head SHA; it was not selected as the latest repository run.

## Producing commands

```sh
gh api "repos/szTheory/sigra/actions/runs?event=pull_request&head_sha=5803ef3d03f9a224143a70a3ffe55aefdf0aa621&per_page=100"
gh run watch 30666977944 --exit-status
gh run view 30666977944 --json databaseId,event,headSha,conclusion,jobs,url
gh pr checks 175
bash scripts/ci/ci-run-metrics.sh --jobs 30666977944
gh run download 30666977944 --name library-test-timings-1 --dir <temp>/library-test-timings-1
gh run download 30666977944 --name library-test-timings-2 --dir <temp>/library-test-timings-2
```

## Inherited before baseline

Source: `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md`, captured from `pull_request` run `30390832059` with:

```sh
bash scripts/ci/ci-run-metrics.sh --jobs 30390832059
```

Verbatim relevant result:

```text
PASS  Library tests shard 1  success  470s
PASS  Library tests shard 2  success  278s
```

## Timing-probe raw observations

```text
Library tests shard 1  success  476s  (job 91276189948)
Library tests shard 2  success  304s  (job 91276189887)
Library tests           success    3s
ci-gate                 success    8s
```

Both ordinary jobs ran the same non-serial command in the selected run:

```text
mix test --partitions 2 --formatter ExUnit.CLIFormatter --formatter Sigra.CI.ExUnitTimingFormatter
```

The two artifacts were created by the same run and downloaded successfully:

```text
library-test-timings-1 / sigra-library-1-timings.json
sha256 97f08b7bc0a14fc213344109942b650826ac27acaefda939beaf458335e55208
schema_version=1 total=1135

library-test-timings-2 / sigra-library-2-timings.json
sha256 7b88e69f0759f4137f35d1d877565da44c665d28a774b169315e3a4ba3e71e8e
schema_version=1 total=1368
```

Both receipt schema checks passed, neither shard was skipped, and the source run had a single attempt. Raw receipts are intentionally not committed; the immutable artifact names and SHA-256 digests preserve provenance.

## Deterministic per-file aggregation

The two validated receipts were aggregated by repository-relative `file` path, rejecting non-integer/negative timings, empty receipts, non-repository paths, and duplicate `(file,module,name)` identities. Equal totals use lexical path order after descending total microseconds.

```sh
jq -s 'def repo_path: if startswith("/home/runner/work/sigra/sigra/") then sub("^/home/runner/work/sigra/sigra/"; "") else error("non-repository receipt path") end; if length != 2 then error("expected exactly two receipts") else . end | if all(.[]; .schema_version == 1 and ((.tests | type) == "array") and ((.tests | length) > 0)) then . else error("invalid or empty receipt") end | [.[].tests[] | if ((.file | type) == "string" and (.module | type) == "string" and (.name | type) == "string" and (.time_us | type) == "number" and (.time_us | floor == .) and .time_us >= 0) then {path: (.file | repo_path), identity: [.file, .module, .name] | join("\\u0000"), time_us: .time_us} else error("invalid test timing entry") end] | if (length > 0 and (([.[].identity] | length) == ([.[].identity] | unique | length))) then . else error("empty or duplicate test identity") end | sort_by(.path) | group_by(.path) | map({path: .[0].path, time_us: (map(.time_us) | add)}) | sort_by(-.time_us, .path)' <receipt-1.json> <receipt-2.json>
```

Result: 217 unique repository-relative files, totalling `506537530` microseconds. The highest measured costs are `test/sigra/install/features/passkeys_js_test.exs` (173836450us), `test/sigra/install/generator_passkeys_opt_out_test.exs` (129066942us), and `test/sigra/install/golden_diff_test.exs` (115942689us). The committed JSON carries the complete sorted aggregate; volatile raw receipts remain downloadable under the named artifacts.

## Requirement disposition

- **TEST-01:** observed on the retry-free PR run.
- **TEST-02:** measured-input-ready only; extraction, manifest, and final after-run comparison remain open.

## Final exact-head observation

Run [30668911851](https://github.com/szTheory/sigra/actions/runs/30668911851) is the retry-free `pull_request` CI run for PR #175 functional SHA `6974bd1e2e4214fd5b9d519a987dfef2c3e89b89`. Its ordinary shards succeeded in 115s and 114s (1s gap, below the inherited 192s gap); the scaffold receiver succeeded in 909s; and the byte-stable required `Library tests` aggregate succeeded.

Downloaded receipts: `library-test-timings-1` SHA-256 `78604b612b797d44bb28ad3693a17caeb5a564b12e316f5899b58b592e728541`, `library-test-timings-2` SHA-256 `6defe9902362eb31e81c12906c7b33b8b7154f4f8bdafd0a02fab69fe876e009`, and `library-test-timings-scaffold` SHA-256 `2f324a60e8f3f2792264187b4ecebf1582fef07a4075cd2f5383c7121eab39be`. The receiver receipt contains `test/upgrade_test.exs`, `golden_diff_test.exs`, and `idempotency_test.exs`; ordinary receipts contain no canonical scaffold paths.
