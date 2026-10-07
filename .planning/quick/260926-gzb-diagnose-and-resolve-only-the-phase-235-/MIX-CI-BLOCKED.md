# 260926-gzb: ordinary sandbox denial and elevated gate resolution

The ordinary execution environment denied Darwin's `sandbox-exec`, which caused the initial focused Phase 235 checks and two ordinary full-gate attempts to fail. The verifier was not changed: its network denial and attestation validation remain fail-closed. The exact full gate subsequently passed under one escalated environment run, so this quick task is complete.

## Preflight and ordinary-environment diagnostics

- Clone: `/private/tmp/sigra-phase244-plan02-clone`
- Branch: `gsd-quick/260926-gzb-gate-fix`
- Initial worktree state matched the plan: the four Phase 242 deletions, existing `.planning/STATE.md` edit, prior quick evidence directory, and this active quick directory only.
- Host probe command: `/usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)' /usr/bin/env true`
- Host probe result: exit 71, `sandbox-exec: sandbox_apply: Operation not permitted`.
- Unchanged Phase 235 focused contract test in the ordinary environment: exit 2; 16 tests, 2 failures, both due to `sandbox-exec` exit 71.
- Phase 232 focused test after correcting the expectations to the live `1.62.1-v3` keys: exit 0; 6 tests, 0 failures.
- The verifier was inspected. It retains Darwin network denial, clean `env -i` credentials/proxies, empty HOME, and attestation signer/source identity validation. No in-repository defect was established.

## Ordinary full-gate diagnostics

Exact command, run from the clone root:

```sh
MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci
```

- Attempt 1: exit 2. ExUnit reported `33 doctests, 3 properties, 2614 tests, 3 failures, 12 skipped (22 excluded)`. Two failures were Phase 235 sandbox errors. The third was an unrelated `Sigra.DeliveryTest` `KeyError: key :user_id not found`; the isolated test command `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix test test/sigra/delivery_test.exs:128` exited 0 (1 test, 0 failures), so the one ordinary retry was used.
- Attempt 2: exit 2. ExUnit reported `33 doctests, 3 properties, 2614 tests, 2 failures, 12 skipped (22 excluded)`. Both failures were Phase 235 tests receiving `{"sandbox-exec: sandbox_apply: Operation not permitted\\n", 71}`.

## Successful escalated gate

The same exact command was run once under the escalated environment, with full output captured in the clone-local [MIX-CI-ESCALATED.log](MIX-CI-ESCALATED.log).

- Exit: 0.
- Main suite: 2,614 tests, 0 failures (12 skipped, 22 excluded).
- Additional CI test set: 65 tests, 0 failures.
- Authorized source commit after gate success: `9e193a38 test(phase232-phase235): align Playwright cache key contract`.
- The commit includes only `test/sigra/planning/phase_232_playwright_economics_test.exs`.

The prior ordinary attempt logs remain available at `/tmp/260926-gzb-mix-ci.log`, `/tmp/260926-gzb-mix-ci-retry.log`, `/tmp/260926-gzb-focused-before.log`, `/tmp/260926-gzb-phase232.log`, `/tmp/260926-gzb-phase235.log`, and `/tmp/260926-gzb-delivery-diagnostic.log`.

## Scope preserved

The Phase 235 verifier and tests were not changed. The four Phase 242 deletions, `.planning/STATE.md`, prior quick evidence, Phase 242 contract test, Phase 244 implementation, branch refs, remotes, and PR #283 were not modified by this task.
