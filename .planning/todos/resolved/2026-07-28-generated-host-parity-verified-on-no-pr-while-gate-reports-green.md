---
created: 2026-07-28T00:00:00.000Z
status: resolved
resolved: 2026-09-15
resolved_by: phase-236-04
title: "generated_admin_playwright_smoke is skipped on every real PR by a stale head_ref gate, and ci-gate counts skipped as pass — so generated-host parity is verified on no PR at all while the gate reports green"
area: ci
files:

  - .github/workflows/ci.yml
  - .github/workflows/release-please.yml

severity: high
source: 2026-07-28 CI fan-out investigation that scoped the v1.47 CI-EFFICIENCY milestone
resolves_phase: 231
audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
---

## What

`generated_admin_playwright_smoke` (`ci.yml:1338`) is gated on

```yaml
if: github.event_name != 'pull_request' || github.head_ref == 'ship/v1.42-ci-gate-remediation'
```

carrying a comment that calls it a "temporary integration-scoped relaxation ... remove after
merge". **That branch merged long ago.** On every real PR the expression is therefore false and
the job resolves to `skipped`.

The job **is** in `ci-gate.needs` (`ci.yml:1464-1473`), and `ci-gate` treats `skipped` as a pass
(`ci.yml:1501-1505` — the check only fails when a result is neither `success` nor `skipped`).

Net effect, stated plainly: **generated-host parity is verified on no PR whatsoever, while the
gate reports green.**

## Blast radius

The same skipped-is-pass semantics let `upgrade_smoke` (`ci.yml:643`, also
`if: github.event_name != 'pull_request'`) pass unverified on PRs too, so `ci-gate` on a pull
request only ever asserts **7 of its 9 lanes**.

Note also that `ci-gate` is **itself not a required context** — ruleset `14941512` requires
exactly 5 lane names — so its assertions gate nothing directly; its only consumer is
`gate-ci-green` in `release-please.yml`. A rotted `if:` on a needed job is thus invisible twice
over: invisible to the PR (because skipped counts as success) and invisible to branch protection
(because the job asserting it is not required).

## Recommended fix (NOT implemented by this todo)

This todo records the diagnosis only. Nothing in `.github/` was changed.

1. **Remove the stale `head_ref` clause** now that `ship/v1.42-ci-gate-remediation` is merged, so
   the lane's PR behavior is a deliberate choice rather than a leftover.
2. **Decide deliberately whether `ci-gate` should distinguish** "skipped because correctly gated
   for this event" from "skipped because its gate rotted". An allowlist of legitimately
   event-gated lanes is one shape; failing on `skipped` for lanes not on that list is another.
   The current uniform skipped-is-pass rule cannot tell the two apart, which is precisely why
   this rotted silently.

Cross-reference the **v1.47 CI-EFFICIENCY** scope and
`.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md`, which
is the other half of the release-gate story.

## Resolution (2026-09-15, Phase 236 plan 04)

**Closed as already-resolved-at-HEAD — D-19.** The stale-`head_ref` gate this todo describes is
already gone. `.github/workflows/ci.yml:1401-1421` (`generated_admin_playwright_smoke` job) has
**no `if:` clause at all** — it declares only `needs: release_ref_guard`, so it runs on every
event including `pull_request`, unconditionally. The job carries an 11-line comment (`ci.yml:1403-
1420`) crediting the fix to "Phase 231 GATE-02 / D-06" and explicitly forbidding reintroduction of
either the removed branch-name condition or the seemingly-safer `github.event_name !=
'pull_request'` pattern, both of which this todo's own "Recommended fix" section would have
produced the same defect restated.

Corroborated independently, per Phase 236's `236-CONTEXT.md` D-19: `p09`'s pole pin and `p10`'s
tier-A floor comment both record this row's deletion. Phase 236 plan 04's Task 1 depended on this
already being fixed — its SC-3 evidence (`236-EVIDENCE.md`'s `AFTER-FIX-GREEN` slot) harvests five
`Generated admin Playwright smoke` job conclusions from ordinary `pull_request` runs on the fix
branch, which is only possible because the job genuinely executes (rather than skipping) on a PR.

**Not re-fixed here** — it was already fixed before this phase began; this closure documents that
fact with today's citation rather than leaving the stale finding open.
