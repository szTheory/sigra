---
phase: 197-playwright-lanes-design-gallery-re-gate
plan: "01"
subsystem: playwright-browser-tests
tags: [playwright, test-determinism, expect-poll, pw-02]
status: complete

dependency_graph:
  requires: []
  provides: [deterministic-mailbox-poll-organizations, deterministic-mailbox-poll-ga-uat]
  affects: [test/example/priv/playwright/tests/organizations.spec.ts, test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts]

tech_stack:
  added: []
  patterns: [expect.poll with closure variable, intervals + timeout configuration]

key_files:
  modified:
    - test/example/priv/playwright/tests/organizations.spec.ts
    - test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts

decisions:
  - Used `let link: string | null = null` outer closure to capture the resolved URL inside the poll callback — same pattern recommended in 197-PATTERNS.md
  - Intervals [250, 500, 1000] chosen for graduated backoff within the 30_000ms budget (mirrors the prior ~30x1s = 30s budget)
  - `throw new Error(...)` guard after poll handles TypeScript type narrowing (link remains `string | null` after poll)

metrics:
  duration: "~2 minutes"
  completed: "2026-06-20T19:00:55Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 197 Plan 01: Replace mailbox poll waitForTimeout with expect.poll — Summary

**One-liner:** Replaced two byte-identical `for`-loop + `waitForTimeout(1_000)` mailbox poll bodies in organizations.spec.ts and ga-uat-shift-left.spec.ts with `expect.poll()` using closure link capture, intervals [250, 500, 1000], and timeout 30_000ms.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Rewrite organizations.spec.ts mailbox loop to expect.poll (D-06) | 7c51e7c3 | test/example/priv/playwright/tests/organizations.spec.ts |
| 2 | Rewrite ga-uat-shift-left.spec.ts mailbox loop to expect.poll (D-06) | e81bc532 | test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts |

## What Was Built

Both `extractInvitationLink` helper functions in the browser-lane test files had their polling bodies replaced:

**Before (both files had this identical pattern):**
```typescript
for (let attempt = 0; attempt < 30; attempt += 1) {
  // fetch /dev/mailbox/json, find invitation row, extract/return link
  await page.waitForTimeout(1_000);  // fixed 1s sleep between attempts
}
throw new Error(`No invitation link...`);
```

**After (both files now use this pattern):**
```typescript
let link: string | null = null;
await expect.poll(async () => {
  // fetch /dev/mailbox/json, find invitation row, assign link via closure
  return link !== null;
}, {
  message: `No invitation link...`,
  intervals: [250, 500, 1000],
  timeout: 30_000,
}).toBe(true);
if (!link) throw new Error(`No invitation link...`);
return link;
```

Each file's existing helper signature and `page` parameter type was preserved exactly — only the loop body changed.

## Verification Results

All plan verification criteria passed:

- `grep -rln 'waitForTimeout' test/example/priv/playwright/tests/` returns nothing (PASS)
- `expect.poll` present in organizations.spec.ts (PASS)
- `expect.poll` present in ga-uat-shift-left.spec.ts (PASS)
- No `Process.sleep` or fixed-duration browser-lane wait introduced (PASS)

## Deviations from Plan

None — plan executed exactly as written. Both rewrites were faithful ports of the 197-PATTERNS.md target shape, following the `passkeys-hooks.spec.ts` in-suite precedent.

## Known Stubs

None. Both helpers return real invitation links extracted from the dev mailbox endpoint.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary changes introduced. This is a test-code-only change.

## Self-Check

Files exist:
- [x] `test/example/priv/playwright/tests/organizations.spec.ts` — modified, exists
- [x] `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` — modified, exists

Commits exist:
- [x] 7c51e7c3 — fix(197-01): replace waitForTimeout with expect.poll in organizations.spec.ts mailbox loop
- [x] e81bc532 — fix(197-01): replace waitForTimeout with expect.poll in ga-uat-shift-left.spec.ts mailbox loop

## Self-Check: PASSED
