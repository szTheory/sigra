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
