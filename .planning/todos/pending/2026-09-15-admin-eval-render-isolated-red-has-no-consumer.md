---
created: 2026-09-15
source: v1.47 CI-EFFICIENCY milestone audit (re-audit at close)
severity: medium
requirements: [GATE-04, FAST-06]
audit_acknowledged: v1.47
---

# An isolated `admin_eval_render` failure notifies nobody, and it skips the browser cache

**GATE-04 signal has no consumer.** `admin_eval_render` (`ci.yml:2101-2106`) now reds its
own job on push/schedule (job-level `continue-on-error` removed; step-level retained at
`:2141`). But it is not in `ci-gate.needs`, and `notify_release_lane_rot`
(`ci.yml:1642-1649`) only fires on `needs.ci-gate.result == 'failure'`. A run where *only*
`admin_eval_render` is red leaves `ci-gate` green and opens no issue — the observed shape
on nightly `34929531476`. The hard signal Phase 231 restored is real but unwatched.

**FAST-06 leakage.** `ci.yml:2126-2134` calls `example-playwright-boot` without
`cache-browsers`/`browser-cache-key`, so it defaults to `"false"` (`action.yml:25-32`) and
re-downloads chromium+webkit on every non-PR run. Off the PR critical path, so FAST-01 is
unaffected — pure runner-minute leakage.

Fix: add `admin_eval_render` to the `notify_release_lane_rot` trigger condition, and pass
the cache inputs at the `admin_eval_render` call site.
