# Agent Notes

For admin UI work, follow `guides/reference/admin-ui-principles.md` and `guides/reference/admin-design-contract.md`.

Key constraints:

- Preserve the `sg-*` cascade-layer/BEM design system.
- Use the Rail Accent brand assets from `brandbook/`.
- Support Light, Dark, and System modes.
- Keep Playwright/admin UI tests deterministic: role selectors, stable hooks, LiveView readiness, no sleeps.

## Automation-first verification

- Within explicitly authorized work, replace human verification and UAT with deterministic tests, browser automation, CI polling, and committed machine-readable evidence.
- Agents may create or update scoped evidence branches and pull requests, dispatch CI workflows, inspect run logs, and enable auto-merge when those actions are required by the authorized delivery workflow.
- Retry transient failures once and automatically diagnose and repair deterministic failures. Never waive, auto-approve, or mark missing evidence as passed; block with durable diagnostics when a requirement cannot be proven automatically.
- Do not use automation-first verification as authority to start unrelated phases or expand product scope.

## GSD forward routing

Before reporting the immediate next GSD command after a phase completes, identify the next
roadmap phase and check its readiness with `init.plan-phase <n>` (or `init.execute-phase <n>` if
it already has plans). Do not infer the forward route from the oldest stale verification report.

- Treat `init.verify-work` selecting an old stale report as separate verification maintenance;
  it does not by itself block planning the next phase.
- Route backward to verification first only when the next phase's GSD readiness reports that
  verification as a prerequisite blocker.
- If the next roadmap phase is pending, has no plan, and its planner reports no prerequisite
  blocker, recommend `$gsd-plan-phase <n>`. Report stale historical verification separately and
  keep `.planning/STATE.md` and `.planning/state.json` aligned with that forward route.
- Perform this check before writing a handoff or telling the user what to run.

## GitHub API usage

- Use at most one CI watcher per workflow run. Never use the three-second `gh run watch` default; use `gh run watch <run-id> --repo szTheory/sigra --compact --interval 60 --exit-status`.
- Do not poll the same run from multiple agents. Reuse the active watcher's result.
- After a run completes, fetch its structured summary once. Fetch failed logs only when the conclusion is a failure.
- Before a long watch, inspect `gh api rate_limit`. If the REST `core` budget has 250 or fewer requests remaining, make no further CI polling requests until its reported reset time.
- Treat HTTP 403 or 429 rate-limit responses as a hard stop until GitHub's reported reset or retry time; do not retry them immediately.
