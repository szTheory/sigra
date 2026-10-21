# Agent Notes

## Communication preferences

- Use plain English in user-facing explanations. The user explicitly finds phrases such as "new trusted historical evidence" meaningless.
- Name the actual missing item and explain what would resolve it. For example: "an original approval or automated test record from before the release, whose origin we can check."
- Avoid abstract GSD and verification jargon. If a technical term is necessary, explain it with a concrete example before using it.
- State what this means for the user: what is missing, what can be done next, and whether anything is needed from them.

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

## Planning artifact write-ahead preservation

- Before rewriting or cleaning any `.planning/` path that is already dirty at the task's capture boundary, first commit it or preserve its exact path/status/bytes under a durable scoped ref and verify read-back. Inventory hashes alone are not recovery copies.
- Treat `.planning/HANDOFF.json`, `.planning/STATE.md`, `.planning/state.json`, closeout ledgers, and phase evidence as write-ahead state: never refresh or replace a dirty revision until its prior bytes are recoverable. If preservation cannot be proven, stop the mutation and record the blocker separately.
- After a scoped preservation, re-read source status and content hash before writing the replacement. Keep the prior ref and exact identity in the phase record so recovery survives later handoff refreshes.

## GSD forward routing

At every GSD stopping point, report the exact next command and distinguish completed
implementation from completed phase verification. Before a context reset, persist the
route, remaining blockers, and evidence references in the project handoff and state files.

Before reporting the immediate next GSD command after a phase completes, identify the next
roadmap phase and check its readiness and context with `init.plan-phase <n>` (or
`init.execute-phase <n>` if it already has plans). Do not infer the forward route from the oldest
stale verification report.

- Treat `init.verify-work` selecting an old stale report as separate verification maintenance;
  it does not by itself block planning the next phase.
- Route backward to verification first only when the next phase's GSD readiness reports that
  verification as a prerequisite blocker.
- If the next roadmap phase is pending, has no plan, and its planner reports no prerequisite
  blocker, inspect its context/readiness: when `CONTEXT.md`/`RESEARCH.md` is absent, use
  `$gsd-discuss-phase <n>` as the default forward command; when context exists, use
  `$gsd-plan-phase <n>`. Report stale historical verification separately and keep
  `.planning/STATE.md` and `.planning/state.json` aligned with that forward route.
- Perform this check before writing a handoff or telling the user what to run.

## GitHub API usage

- Use at most one CI watcher per workflow run. Never use the three-second `gh run watch` default; use `gh run watch <run-id> --repo szTheory/sigra --compact --interval 60 --exit-status`.
- Do not poll the same run from multiple agents. Reuse the active watcher's result.
- After a run completes, fetch its structured summary once. Fetch failed logs only when the conclusion is a failure.
- Before a long watch, inspect `gh api rate_limit`. If the REST `core` budget has 250 or fewer requests remaining, make no further CI polling requests until its reported reset time.
- Treat HTTP 403 or 429 rate-limit responses as a hard stop until GitHub's reported reset or retry time; do not retry them immediately.

## Avoid repeated repair-plan loops

- Read `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-RESET.md` and `253-LEARNINGS.md` before resuming Phase253. The user's recovery instruction supersedes the old immediate gap-planning route.
- Do not create a numbered successor plan solely to fix an ordinary development error, fixture, expected message, or capture parser. Under authorized local maintenance, diagnose the cause, make the scoped fix, and run meaningful tests. Keep prior stopped attempts and acceptance budgets unchanged; maintenance results cannot be substituted for their missing results.
- Before another repair plan after repeated failures, explain why the previous fixes did not work and what smaller independent check will resolve that cause. Do not repeat a count/owner migration merely because the new plan has another number. Historical fixture expectations stay tied to their historical source.
- Separate unit/development verification from once-only acceptance and hosted collection. Development errors do not imply acceptance permission; acceptance limits do not require a fresh plan for every local assertion repair. Never silently renew a spent acceptance budget.
- Report progress against the original requirement's observable behavior. Passing plan/schema checks, preservation records and hypothetical routing copies do not establish a CI fix or a successful required gate.
- Use concise current state with references to preserved history. Do not copy an entire raw-output ledger into every handoff or add new review layers without a demonstrated failure they prevent.
