# Phase 247 Plan 08: Dry-run recovery record

## Exact source and baseline

- Candidate PR #224 remains open at `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, based on reviewed main `d135cbce343947499a0810736c500ef5f1cb5c32`.
- Evidence PR #296 was merged through protected checks. Its pre-merge head is `76f6c6aced57a71020573bbd477d3624fd2c2f73`; its main merge is `a494f3ee3878da93aab4f70712ffddeefd77a802`.
- The exact four-path baseline uses `git-diff-raw-v1`, SHA-256 `d7cbfeddd55bc0528738f89b82377379e55a73464f2c174217af31410625ac5e`, 8,372 bytes, and manifest blob `c87eeb19e79b4e19d34ff522c487894c8cb3c558`.

## Pre-auth stop and bounded retry

The first dispatch, run [37803560621](https://github.com/szTheory/sigra/actions/runs/37803560621), stopped during the pre-auth baseline check. The evidence PR branch had been deleted after merge, so the workflow checkout could not resolve the evidence PR's pre-merge tree. It did not reach the Hex toolchain/authentication step, and it did not produce a passing receipt.

Recovery restored only the evidence branch ref to the already-verified PR #296 head `76f6c6aced57a71020573bbd477d3624fd2c2f73`. The commit and tree did not change. Verification confirmed the restored manifest blob, exact baseline digest and byte count, exact four allowlisted main paths, merged PR provenance, and unchanged PR #224 head/base. The workflow was then dispatched once more.

The successful authenticated run is [37803817504](https://github.com/szTheory/sigra/actions/runs/37803817504), attempt 1, on trusted `main` at `a494f3ee3878da93aab4f70712ffddeefd77a802`. Its safe receipt records the requested and checked-out candidate as `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, the exact baseline and evidence provenance above, `mix hex.publish --dry-run --yes` success, credential name `HEX_DRY_RUN_API_KEY` with boolean presence `true`, and HTTP 404 for Hex 1.6.0 before and after. No credential value or secret metadata was inspected. No release tag, publication, or PR #224 merge occurred.

## Final readiness

The final readiness validator passed at `2026-10-08T15:59:46.969Z`. It observed PR #224 still open at the exact candidate/base, required CI run `37800067568` successful on the exact candidate, trusted live main at the evidence merge, a clean candidate checkout, and complete current inherited commit/path/open-PR dispositions. The validator independently recomputed the baseline and accepted only the four allowlisted evidence files in the main advance.

The shared primary checkout contains unrelated changes, so the validator's clean-checkout helper was run against a separate clean detached checkout of exact live main `a494f3ee3878da93aab4f70712ffddeefd77a802`. The primary working tree was not cleaned or reset. Focused validator tests pass 24/24.
