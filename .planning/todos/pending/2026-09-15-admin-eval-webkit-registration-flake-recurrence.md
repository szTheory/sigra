---
created: 2026-09-15T00:00:00.000Z
status: pending
title: admin-eval WebKit registration flake — the 2026-07-04 "resolved" fix outlived its premise and now reds main
area: testing
severity: medium
disposition: flake-hardening
recurrence_of: .planning/todos/resolved/2026-07-04-admin-eval-first-nav-flake.md
files:
  - test/example/priv/playwright/tests/admin-eval.spec.ts
  - test/example/priv/playwright/playwright.config.ts
source: post-merge diagnosis of CI run 35052017063 on main @ b6e889c4 (orchestrator + subagent, read-only)
---

## What

The `Admin eval render + probe` job fails intermittently on `main`. Two observed reds
share an **identical signature** — same helper, same line, same budget, different test:

| run | sha | failing test | error |
|---|---|---|---|
| 35052017063 | b6e889c4 | `[admin-eval-mobile] admin-eval.spec.ts:686 probe #8 card-in-card` | `TimeoutError: page.waitForURL: Timeout 10000ms exceeded` at `registerUser` (:164) |
| 34990229412 | fb11c8d3 | `[admin-eval-mobile] admin-eval.spec.ts:382 render bundle: board-mg-3/populated` | `TimeoutError: page.waitForURL: Timeout 10000ms exceeded` at `registerUser` (:164) |

Both `1 failed / 191 passed`. It lands wherever the stall happens to fall — the
definition of a flake. Eight other historical runs of this job on `main` are green.

`registerUser` (`admin-eval.spec.ts:155-168`) runs in `beforeEach` for **all 192** eval
tests: goto `/users/register`, then race `click()` against
`waitForURL(..., { timeout: 10_000 })` inside a `Promise.all`.

## Why it matters — the fix outlived its premise

This is a **recurrence of a todo marked resolved**, and the reason is precise and
checkable in git:

- **2026-07-08** — `4b2a264d fix(218-01): deflake first-nav goto in admin-eval.spec.ts (D-09)`
  lowered the nav budget 30_000 -> 10_000. The comment at `:161-162` justifies it:
  *"so a stuck first-nav fails fast into its **Playwright retry** instead of hanging
  ~16 min"*. At that moment retries existed, and the prior todo confirms they worked —
  *"passed on the warm retry in ~3s"*, *"Playwright's retries absorbed every one"*.
  **The fix was correct when written.**
- **2026-07-31** — `2a96d72f ci: authenticate Playwright once, then shard (#168)` set
  `retries: 0` (`playwright.config.ts:59`; `:15` now reads "Retries stay at zero everywhere").

So the premise was removed three weeks after the fix, and the comment was never
updated. **A cap chosen specifically to feed a retry now feeds nothing** — it just
reds the job faster. The comment actively misdescribes its own code, the same defect
class v1.48 exists to retire (cf. the false `mix.exs:189-191` "intentionally relative"
comment found in Phase 237 research).

Supporting detail: 10_000 is *below* the file's own 15 s global `expect.timeout`, which
the config raises precisely because `MIX_ENV=dev` falls back to `:longpoll` in headless
runners (`playwright.config.ts:61-67`). Only the WebKit project (`admin-eval-mobile`,
iPhone 13) has ever failed; the two Chromium projects never have.

Server-side confirmation this is a client/transport stall and **not** an app defect: the
failed run's server log holds **191** `INSERT INTO "auth"."users"` rows for 192 tests
(64 desktop, 64 dark, 63 mobile). The failing registration never reached the database.

## Not a regression from PR #242

Ruled out by direct inspection, with a positive control. The eval spec performs exactly
two navigations:

```
admin-eval.spec.ts:157  page.goto('/users/register')
admin-eval.spec.ts:356  page.goto('/admin/_design')
```

It never renders `/admin/audit`. Control for the search machinery: the same `grep` over
the same file returns 22 hits for `admin`, and 0 for `/admin/audit`. So the audit-index
rewrite could not have caused this — **and this job could never have caught an
audit-index regression either.**

## Suggested fix — ranked

Constraint: prohibition `p17` forbids masking with `retries`, `page.waitForTimeout(`, or
`test.slow(`. None of the below does that.

1. **Smallest honest fix.** Delete the false rationale comment at `:161-162` and restore a
   real budget (~30 s). Removing a cap set on a premise that no longer holds is not
   flake-masking — it is retiring a dead justification.
2. **Better.** Stop racing `click()` against `waitForURL` in `Promise.all`. Assert the
   server-confirmed outcome instead — `expect(page.getByRole('alert')).toContainText('Account created successfully!')`
   is already line 167 and runs under the 15 s global expect budget — and let the URL
   assertion follow from it.
3. **Best value, and mostly already built.** Register once per project via a Playwright
   `storageState` setup project and reuse the session, removing 191 of 192 race sites and
   a large slice of this job's ~17 min.

   **This pattern already exists in this repo and admin-eval was simply left out of it.**
   `#168` gave `admin-design-*` a setup project plus `storageState`
   (`playwright.config.ts:181-232`). The `admin-eval*` projects at `:239`, `:246`, `:253`
   have neither `storageState` nor `dependencies`. This is extending a working pattern one
   lane over, not building something new. It also converges with the storageState win
   already scoped in the CI-efficiency work.

## Scope note — file as flake-hardening, NOT as a gating change

`admin_eval_render` is deliberately excluded from `ci-gate`
(`ci.yml:2111`, `if: github.event_name != 'pull_request'`; Phase 230 FAST-03 / D-10, D-11 —
it cost 17 min and gated nothing). That trade was intentional and should stand.

But since Phase 231 GATE-04 removed the job-level `continue-on-error`, this lane is a
**hard red signal on `main`**. The combination — a 10 s client-side race, executed 192
times per invocation, with zero retries, justified by a comment that is no longer true —
means `main` goes red on a race no PR could have prevented. Fix the race; do not re-gate
the job.
