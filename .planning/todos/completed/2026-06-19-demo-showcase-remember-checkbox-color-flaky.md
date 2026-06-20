---
created: 2026-06-19T00:00:00.000Z
status: pending
title: demo-showcase remember-checkbox accent-color assertion is flaky (off-by-one rgb) — de-flake or delete
area: test
files:
  - test/example/priv/playwright/tests/demo-showcase.spec.ts
source: PR #54 (v1.39 ship) — CI run 27833715452 lineage; surfaced once the full-lifecycle Playwright lane finally ran past its upstream blockers
---

## What

`demo-showcase.spec.ts` test `home page orients evaluators before login` (~line 403)
asserts at ~line 885:

```js
expect(rememberCheckedStyles.backgroundColor).toBe(rememberCheckedStyles.expectedAccent);
```

i.e. an **exact** rgb string equality between the checked "remember me" checkbox's
rendered `background-color` and the expected brand accent. In CI it intermittently fails
by **one or two units per channel**:

```
Expected: "rgb(72, 214, 202)"   (#48D6CA)
Received: "rgb(71, 212, 200)"   (#47D4C8)
```

It **passed on retry** (the lane's `retries: 1` masked it). Per `playwright.config.ts`,
`retries: 1` is the only concession to timing flake and D-15 forbids using retries to mask
real failures — so this assertion should be made deterministic or removed, not left to lean
on the retry.

## Why this is flakiness, not a real regression

- Off-by-one-per-channel and passing on retry is the classic signature of a sub-pixel /
  color-rounding / not-yet-settled `:checked` paint, not a wrong brand color.
- Both operands are read from the live DOM in the same `evaluate` block, so it is comparing
  a rendered computed color against an expected token; a 1–2 rounding delta (color-mix /
  opacity / transition mid-frame) is enough to fail an exact `toBe`.
- We do not want flaky gates in CI. Retry-masking is not an acceptable resting state here.

## Fix direction (pick during follow-up)

1. **De-flake (preferred if the assertion has value):** make the read deterministic —
   wait/poll until the checked background settles (or disable CSS transitions/animations for
   the assertion), and/or compare with a small per-channel tolerance instead of exact string
   `toBe` (parse rgb, allow ±2), and/or compare normalized hex. Root-cause the rounding (is
   it `color-mix()`/opacity on the checkbox accent?).
2. **Delete the sub-assertion / spec if low value:** the test's real job is "home page
   orients evaluators before login." The remember-checkbox accent-color micro-assertion is
   arguably over-specified design trivia already covered by the design-system layers
   (`sg-*` tokens, admin-checkpoints, the gallery). If de-flaking is more work than it is
   worth, drop just this color assertion (keep the orientation coverage) or the spec.

## Acceptance

- The assertion is deterministic across repeated CI runs (no reliance on `retries: 1` to
  pass), OR it is removed with a one-line rationale.
- `demo-showcase-chromium` runs green without flaky retries on this test.

## Related

- Same fragility family as `SEED-006` (admin-design gallery visual env-fragility) and the
  `SEED-005` CI-perf audit (flaky-gate elimination is explicitly in scope there). Consider
  resolving alongside SEED-006's deterministic-visual-capture work.
