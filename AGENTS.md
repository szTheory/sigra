# Agent Notes

For admin UI work, follow `guides/reference/admin-ui-principles.md` and `guides/reference/admin-design-contract.md`.

Key constraints:

- Preserve the `sg-*` cascade-layer/BEM design system.
- Use the Rail Accent brand assets from `brandbook/`.
- Support Light, Dark, and System modes.
- Keep Playwright/admin UI tests deterministic: role selectors, stable hooks, LiveView readiness, no sleeps.
