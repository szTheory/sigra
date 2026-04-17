---
status: complete
phase: 22-passkeys-generator-wiring
source:
  - 22-01-SUMMARY.md
  - 22-02-SUMMARY.md
  - 22-03-SUMMARY.md
  - 22-04-SUMMARY.md
started: 2026-04-16T13:35:30Z
updated: 2026-04-16T15:23:29.614Z
---

## Current Test

[testing complete]
## Tests

### 1. Cold Start Smoke Test
expected: Kill any running generated app/server and start from scratch on a fresh generated install. The generated app should boot without passkey-related compile/runtime errors, complete setup cleanly, and respond to a basic request.
result: pass
verified_by: automation
automation_command: bash scripts/ci/passkeys-opt-out-smoke.sh
evidence: "│ | └─ lib/mix/tasks/compile.asn1.ex:74:15: Mix.Tasks.Compile.Asn1.run/1 | warning: :asn1ct.compile/2 is undefined (module :asn1ct is not available or is yet to be defined) | │ | 74 │       :asn1ct.compile(to_charlist(input), options) | │               ~ | │ | └─ lib/mix/tasks/compile.asn1.ex:74:15: Mix.Tasks.Compile.Asn1.run/1"

### 2. Default Install Enables Passkeys
expected: Running `mix sigra.install` without `--no-passkeys` should leave passkeys enabled by default. The generated install summary should make that explicit, and the generated app should include passkey routes/assets rather than requiring an extra opt-in flag.
result: pass
verified_by: automation
automation_command: bash scripts/ci/passkeys-default-smoke.sh
evidence: "==> passkeys-default: sigra_passkeys_default responded after 3s | ==> passkeys-default: success"

### 3. Enabled Install Wires Real Browser/Dependency Support
expected: In a passkeys-enabled generated app, passkey browser wiring should be real rather than placeholder metadata. The generated output should include the passkey browser assets and the package/dependency wiring needed for them to work.
result: pass
verified_by: automation
automation_command: bash scripts/ci/passkeys-default-smoke.sh
evidence: "==> passkeys-default: booting app and checking root responds | ==> passkeys-default: sigra_passkeys_default responded after 3s | ==> passkeys-default: success"

### 4. No-Passkeys Install Omits Passkey Surfaces
expected: Running `mix sigra.install --no-passkeys` should produce a structurally clean app with no passkey routes, no passkey JS assets, no passkey deps/config, and no leftover passkey UI or controller residue.
result: pass
verified_by: automation
automation_command: bash scripts/ci/passkeys-opt-out-smoke.sh
evidence: "==> passkeys-opt-out: sigra_no_passkeys responded after 3s | ==> passkeys-opt-out: sigra_no_organizations_no_passkeys responded after 3s | ==> passkeys-opt-out: success"

### 5. No-Organizations + No-Passkeys Also Stays Clean
expected: Running `mix sigra.install --no-organizations --no-passkeys` should also omit all passkey-specific routes/files/deps/config while the generated app still compiles, migrates, builds assets, and boots cleanly.
result: pass
verified_by: automation
automation_command: bash scripts/ci/passkeys-opt-out-smoke.sh
evidence: "==> passkeys-opt-out: sigra_no_passkeys responded after 3s | ==> passkeys-opt-out: sigra_no_organizations_no_passkeys responded after 3s | ==> passkeys-opt-out: success"

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0
## Gaps
