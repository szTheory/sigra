# OAuth Playwright Trace Policy

Workflow: `.github/workflows/ci.yml / oauth_e2e_playwright`.

The GAUAT-04/05/06 browser lane uploads `trace.zip` only on failure.
For the local phase-close verification on `367a164`, the trio passed cleanly, so no trace archive was produced.
Use `npx playwright show-trace <trace.zip>` on a failed CI artifact when investigation is needed.
