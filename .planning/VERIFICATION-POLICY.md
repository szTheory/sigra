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

## Local database preflight

Before database-backed local verification, use `scripts/db/up.sh` and source the freshly written
`tmp/db.env` in the same shell that runs the checks. Do not trust `PGPORT` or
`SIGRA_TEST_PG_PORT` inherited from a long-lived agent shell: compare the configured port with the
current listener or the Sigra test container's published port. When an unrelated app logs a
connection refusal but the selected checks pass, identify the app and port from its config before
classifying it as a test failure. Never prune or stop project containers as a response to a port
mismatch; use the named Sigra test database and leave other projects' containers untouched.

## No-repeat verification routing

Treat UAT state and canonical phase-verification state as separate gates. A completed automated
UAT file does not refresh `*-VERIFICATION.md`, and a passing verification report does not justify
asking the user to repeat machine-checkable acceptance steps.

When a GSD command reports a stale or otherwise blocked verification:

- Read the canonical status and its routing output, then identify which workflow actually writes
  or refreshes the verification report. Do not assume the command named by a stale-status message
  can regenerate that report.
- After one attempt, compare the status and relevant artifact timestamps/fingerprint. If the same
  blocker remains and no verification artifact changed, do not invoke the same command again as a
  proposed fix. Follow the report-producing workflow directly, or stop with the precise routing
  dead end recorded in the active phase's `continue.md`.
- Before recommending a resume command, inspect its no-work/already-complete route. A phase with
  every PLAN summarized can exit before verification; never claim it will refresh the report
  unless that route demonstrably invokes the verifier.
- Keep the phase blocked until the canonical completion predicate passes. Never hide stale status,
  bypass it, mark it passed, or substitute conversational UAT for the missing machine evidence.
- Present the user only an action that cannot be completed safely by the available GSD workflow.
  Do not make them repeat checks that already have current automated evidence.

This policy applies to planning, execution, verification, and closeout. Prefer concrete committed
tests and machine-readable evidence over conversational UAT, while keeping verification scope
limited to the authorized phase and its recurring quality needs.
