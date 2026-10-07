# Verification Policy

## Default: shift verification left

GSD work should aim for zero human verification or UAT checkpoints. Turn each acceptance
criterion into the lowest-cost deterministic check that proves the user-visible behavior, and
run it automatically before handoff. Prefer, in order of fit, unit and contract tests,
integration tests, browser E2E or smoke tests, and CI checks. Put checks in CI when they provide
recurring protection worth their runtime and maintenance cost.

For each phase:

- Map every observable requirement to executable evidence. Cover seams between components with
  integration, E2E, or smoke tests; include negative controls for important guards where useful.
- Run relevant checks during implementation and again at the phase verification boundary. Record
  the exact command or workflow, result, and durable CI run or artifact reference when available.
- Treat flaky, skipped, cancelled, stale, or unrelated green aggregate results as unproven. Diagnose
  deterministic failures and repair them; never waive a missing signal or mark it passed by
  assertion.
- Add recurring checks to CI when their continuing value exceeds their runtime and upkeep. Keep
  fast feedback local where CI adds no durable signal, and avoid duplicating equivalent coverage.
- Do not ask the user to repeat a result already established by current automated evidence. Present
  only checkpoints whose remaining uncertainty requires human judgment or an inherently manual
  operation.

Human checkpoints are exceptional: reserve them for irreducibly subjective judgment, operator
authorization or credentials that cannot be automated, and behavior that depends on unavailable
physical hardware or third parties. Automate setup, objective assertions, and post-action evidence
around those checkpoints, so the handoff asks only for the decision or action that cannot be
proven by a machine. A `human_judgment` label in planning coverage is a prompt to look for a
repeatable rubric or test; it is not by itself a reason to send work to the user.

This policy applies to planning, execution, verification, and closeout. Prefer concrete committed
tests and machine-readable evidence over conversational UAT, while keeping verification scope
limited to the authorized phase and its recurring quality needs.
