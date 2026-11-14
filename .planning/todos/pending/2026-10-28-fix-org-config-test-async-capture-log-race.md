---
created: 2026-10-28T21:30:00+00:00
status: pending
area: testing
priority: high
milestone_origin: v1.50
requirement_origin: 255.1-06 attempt 06 stop
audit_acknowledged:
  milestone: v1.50
  at: 2026-11-10
---

# Fix the async capture_log race in the org config test

`test/sigra/organizations/config_test.exs:78` ("does not emit a warning for the 7-day default") is flaky. It failed 1 of 2,645 tests in PR CI run `40791815283` (job `123178645021`, Library tests shard). That failure stopped Phase 255.1 installation attempt 06 before the merge.

The cause is a race between two async modules:

- The module is `use ExUnit.Case, async: true`.
- `ExUnit.CaptureLog.capture_log/1` captures every log line emitted in the VM while it runs, not only lines from its own process.
- `refute log =~ "phishing-window"` therefore picked up `[warning] [Sigra] invitation_ttl configured to 60 days ...`, which `test/sigra/organizations/invitations_test.exs:338` emitted at the same time. That module is also `async: true` and uses 24*60 hours.
- The tests at :55 and :67 in the same module have the same exposure.

Fix options, in order of preference:

1. **Process-scoped capture.** Wrap the call with `Logger.metadata`/`with_log` and filter on a unique marker, or use a test-local handler keyed to `self()`. Then the refute can only see this process's warning. Keep `async: true`.
2. **Run the module serially.** Make it `async: false`. ExUnit runs every async module before any sync module, so the refuting tests can no longer overlap `invitations_test.exs`. This is the simplest fix. It costs a little suite parallelism.
3. Assert on the function's return or on a pure "should warn?" helper instead of on log text.

Also grep for other `refute ... =~` checks inside `capture_log` in async modules. They have the same race.

Constraints:

- Deliver this as its own PR to main.
- Do NOT change the Phase 255.1 install tree (`3c7f7f4c`). The source commit is pinned and bound into every install record.
- Prove it with a loop of the two modules run together (for example, `mix test test/sigra/organizations --seed <n>` repeated). Add a positive control showing that the old test fails under forced overlap.

Source: `.planning/execution/255.1/protected-delivery-scope/installation-proposal-06/stop-diagnosis/DIAGNOSIS.json`.
