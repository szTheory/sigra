---
created: 2026-07-28T00:00:00.000Z
status: pending
title: Generated sigra_admin_policy_test.exs is outside install-golden fixture coverage
area: installer
severity: low
audit_finding: W-6
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [BOOT-03, PROOF-02]
files:
  - test/support/install_fixture.ex
  - test/fixtures/install_golden/tree/
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

`test/support/install_fixture.ex:334-340` restricts the golden fixture tree to five paths:
`lib`, `priv/repo/migrations`, `priv/static`, `config`, `test/support`.

The installer generates `test/<app>/sigra_admin_policy_test.exs` (visible in the captured
`STDOUT.txt:149`), which falls outside all five. It is therefore absent from
`test/fixtures/install_golden/tree/` and invisible to the golden drift gate.

PROOF-02 claims template/example/golden/migration/JS/docs/feature-flag parity is "reviewed
as one generated contract". This is a hole in that claim: a generated file can change or
break with no golden diff.

Partially compensated — `scripts/ci/admin-acceptance-smoke.sh:172` actually *runs* that
file in a fresh generated host, so a broken policy test would fail CI. What is missing is
drift detection: a silent *content* change would not be noticed.

## Recommended fix

Extend the tracked-path list in `install_fixture.ex:334-340` to cover generated `test/`
output beyond `test/support`, then rebless the fixture
(`MIX_ENV=test mix sigra.fixture.rebless_golden`) and commit the newly captured files.

Before doing that, audit what *else* the installer emits outside those five paths — the
same reasoning that missed the policy test may have missed others. Compare the installer's
full emitted file list (from `STDOUT.txt` in the fixture) against the tracked globs and
enumerate every gap, rather than patching this one file.

Watch for churn: widening the tracked set may pull in files with per-run nondeterminism
(timestamps, generated app name). The existing tree already handles the app-name case, so
follow that pattern.

## Related

- W-5 in the same audit — same family: generated artifact outside its verification net.
- [[reference_installer_template_drift]]
