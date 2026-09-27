# Phase 242 Hex retirement: initial `mix ci` blockage (resolved)

This file preserves the initial gate failure history. The blockage was later resolved by the 260926-gzb quick task, which corrected the unrelated Phase 232 cache-key expectation and verified that the exact full gate passed under the escalated environment. The four authorized Phase 242 deletions were then committed locally as `ed68e2b9` after that pass.

## Initial gate attempts

The first two attempts used the required command from `/private/tmp/sigra-phase244-plan02-clone`:

```sh
MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci
```

- Attempt 1: exit status 2; ExUnit reported 2,614 tests and 3 failures.
- Attempt 2 (the single ordinary-environment retry, captured in `MIX-CI-RETRY.log`): exit status 2 with the same three failures.
- A subsequent sandbox-escalated attempt also exited 2; its captured output was truncated before the final summary.

The Phase 242 absence contract passed during these attempts. The initial failures were the two Phase 235 `sandbox-exec: sandbox_apply: Operation not permitted` cases and the Phase 232 expectation of two `playwright-chromium-1.59.1-v3` keys when the live workflow used `1.62.1-v3`.

## Later resolution and source commit

The completed 260926-gzb evidence records the exact full gate command exiting 0 under the escalated environment. Its main suite reported 2,614 tests and 0 failures; the additional CI set reported 65 tests and 0 failures. See:

- `../260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-SUMMARY.md`
- `../260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-VERIFICATION.md`
- `../260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-ESCALATED.log`

After that successful gate, commit `ed68e2b9` removed exactly these four resurrected Plan 13 artifacts:

- `.github/workflows/hex-remediate-phantom.yml`
- `scripts/ci/prohibitions/p22-hex-remediation.test.mjs`
- `test/fixtures/prohibitions/p22-hex-remediation-broadened.yml`
- `test/fixtures/prohibitions/p22-hex-remediation-unsafe-secret.yml`

This record documents historical failed attempts and must not be read as the current gate status. No Phase 244 branch/ref or PR #283 update was made.
