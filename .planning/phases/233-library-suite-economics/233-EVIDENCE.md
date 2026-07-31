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

## Requirement disposition

- **TEST-01:** observed on the retry-free PR run.
- **TEST-02:** measured-input-ready only; extraction, manifest, and final after-run comparison remain open.
