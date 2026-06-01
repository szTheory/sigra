---
status: complete
phase: 148-evaluator-funnel-and-first-run-dx
source:
  - 148-VERIFICATION.md
started: 2026-05-31T21:31:59Z
updated: 2026-05-31T21:38:24Z
---

## Current Test

resolved by automation

## Tests

### 1. 10-Minute Evaluator Stopwatch

expected: First meaningful auth flow is reachable in 10 minutes or less using documented commands only.

steps:

1. From `test/example`, run `mix setup && mix phx.server`.
2. Open `http://localhost:4000/demo/credentials`.
3. Complete one meaningful auth flow, for example logging in as `alice@demo.sigra.dev`.
4. Record the end-to-end elapsed time and any blocker encountered.

why_human: Time-to-complete and interaction pacing are runtime/manual behaviors not verifiable via static analysis or unit tests.

automation: `test/example/priv/playwright/tests/demo-showcase.spec.ts` now verifies this path in the `demo-showcase-chromium` project by starting at `/demo/credentials`, logging in as `alice@demo.sigra.dev`, reaching `/users/sessions`, and asserting elapsed browser-path time is <= 10 minutes.

ci: Existing `example_playwright_smoke` runs `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium` on PR/main.

result: passed

## Summary

total: 1
passed: 1
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
