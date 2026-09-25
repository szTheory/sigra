---
created: 2026-09-15T00:00:00.000Z
status: pending
title: Gap-closure attestation verifier can still fail a passing run from its EXIT trap
area: ci
severity: moderate
files:

  - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh

source: 2026-09-15 — found while fixing the same flaw in the source-complete verifier (PR #239)
audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
---

## What

`scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` runs under
`set -euo pipefail` and installs a `cleanup()` EXIT trap over its temp dir. Under
`set -e`, a command that fails inside an EXIT trap overrides the script's exit
status — so a verification that *succeeded* can still report failure.

Its `cleanup()` special-cases only the `sudo` isolation path. On the non-sudo
paths it calls `rm -rf` unguarded, with no `chmod` first. The sandboxed `gh`
leaves behind `$work/home/.local/state/gh/device-id` under a mode that blocks
unlinking, which is exactly what made the source-complete verifier emit its
success banner and then exit non-zero in CI:

    rm: cannot remove '.../state/gh/device-id': Permission denied

That failure mode was observed live on PR #239 (two red tests in
`phase_235_fast_01_source_complete_contract_test.exs`), where the sibling
verifier's success banner appeared on both sides of the assertion and only the
exit code differed.

## Solution

Apply the same fix landed in `verify-fast-01-source-complete-attestation-offline.sh`
at commit `535876b0`: in `cleanup()`, restore write permission before unlinking
and swallow any residual cleanup error, so cleanup can never alter the script's
exit status.

    chmod -R u+rwX -- "$work" 2>/dev/null || true
    rm -rf -- "$work" 2>/dev/null || true

Keep the existing sudo branch, but guard its `rm` the same way.

## Why not now

Out of scope for the Phase 235 closure recovery — that PR was a content
recovery, and the source-complete verifier was touched only because its flaw
was actively failing the recovered contract tests. This sibling is latent: it
has not been observed failing, so it belongs in its own change with its own
CI proof.
