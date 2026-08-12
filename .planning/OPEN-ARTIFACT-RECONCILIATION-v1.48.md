# v1.48 Open-Artifact Reconciliation

**Date:** 2026-08-12
**Policy:** Close only with deterministic evidence. Move genuinely future, manual, or out-of-scope work to the deferred ledger without claiming implementation.

## Repaired metadata

- `.planning/debug/knowledge-base.md` is a resolved-pattern index, not an active session; terminal frontmatter now prevents a scanner false positive.
- Quick tasks `260718-dst`, `260718-mba`, `260718-pdd`, and `260718-svg` shipped in commit `8acf00a4`; their missing completion summaries were restored from current source and git history.
- Quick task `260728-d9h` remains deliberately unimplemented and was moved intact to `.planning/deferred/quick/`.

## Resolved todos

These files moved from `todos/pending/` to `todos/resolved/` because their acceptance condition was delivered or superseded by stronger executable evidence:

| Todo | Resolution evidence |
| --- | --- |
| playwright-parallelization-per-shard-db | Phase 232 delivered authenticate-once sharding and passed verification. |
| app-css-corruption-guard-blind-spot | Phase 221-02 fixed the state machine, added corrupt/clean fixtures, and wired the self-test into CI. |
| 218-rereview-followups | Phase 221 closed the enumerated SHIP-01/02 follow-ups with synchronized template/golden evidence. |
| installer-context-impersonation-guard-gap | Phase 221 added generated-host scope propagation and deny-path coverage. |
| upgrade-smoke-button-type-hex-publish | Hex API confirms `1.2.0`, `1.3.0`, and `1.4.0` are published; current lanes use `phx_new 1.8.8`. |
| admin-eval-render-burns-17m-per-pr-for-an-unread-red | Phase 230 removed admin-eval from PR execution while retaining it as an observed non-PR signal. |
| gate-ci-green-timeout-too-tight-for-push-to-main | Release polling now has a 75-minute bounded workflow timeout and hardened wait logic. |
| generated-host-parity-verified-on-no-pr-while-gate-reports-green | The stale branch gate is gone; generated-host smoke is an explicit `ci-gate` dependency with honest-skip enforcement. |
| release-lane-rot-label-missing-breaks-hard-02-signal | `notify-failure-issue.sh` now creates the label when absent and has deterministic regression tests. |
| release-please-orphans-unreleased-block | Quick task `260728-glj` completed the changelog folding/bookkeeping correction. |
| W-2 example auth CSS parity | Current installer tests enforce auth stylesheet parity. |
| W-3 generated auth runtime coverage | Phase 238 added the generated-host browser journey suite. |
| W-4 generated auth Axe coverage | `generated-auth.spec.ts` runs scoped Axe checks across reached material auth states. |
| Phase 234 GitHub evidence residual | Phase 236 reconciled and verified the immutable evidence lifecycle. |
| Phase 234 PR evidence blocked | Phase 236 replaced the blocked diagnostic with verified closeout evidence. |

## Deferred ledger

The remaining pending todos were moved intact to `.planning/todos/deferred/`. They are not v1.48 gaps and are not represented as complete. This includes future v2 features, accepted visual/admin follow-ups, manual repository or Hex administration, low-severity reliability work, the passkey-primary composition gap, and the measured FAST-01 residual.

Notable external state: Hex still reports unretired `1.20.0` as `latest_stable_version`; that operator-only item remains deferred rather than being falsely closed.

## Seed dispositions

- SEED-004: resolved by current `phx_new 1.8.8` generated-host/install evidence.
- SEED-005: audit and remediation addressed; the honest 772s versus `<720s` residual is deferred separately.
- SEED-006: resolved by Phase 197 and reconfirmed by Phase 234 evidence.

