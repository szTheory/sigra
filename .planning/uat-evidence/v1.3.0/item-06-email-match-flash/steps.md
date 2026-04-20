# SEED-6 — Invitation email lock / mismatch flash (machine closure)

## Playwright (merge-blocking `example_playwright_smoke`)

- `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` — invitation
  accept signup: tamper locked email → server-side
  `This invitation is locked to …` error (email_mismatch path).

## Local reproduction

Boot `test/example` on port 4000 (dev), then:

```bash
cd test/example/priv/playwright
npm ci && npx playwright install chromium
SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/ga-uat-shift-left.spec.ts --project=chromium
```
