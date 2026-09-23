### Honest-skip set after Phase 230 (v1.47 FAST-02/FAST-03/FAST-05)

`ci-gate` counts a `skipped` conclusion as a pass (the `ci-gate` job's result loop treats
`"$result" != "success" && "$result" != "skipped"` as the only failing case), so the tiers below are the
enumerated baseline against which Phase 231's GATE-03 distinguishes "skipped because correctly
gated for this event" from "skipped because its gate rotted", and against which Phase 235's
GATE-05 builds its before/after coverage inventory. Every entry names the construct (job id or
step id) and its literal gating condition, verified against the shipped `ci.yml` at the commit
this section was written.

**Tier A — event-gated, pre-existing (Phase 196).** `install_matrix`, `upgrade_smoke`,
`passkeys_manual_fallback_smoke`, `passkeys_opt_out_smoke`, `nightly_probe`, plus the two
recapture lanes (`admin_design_recapture`, `admin_checkpoint_recapture`) and
`notify_release_lane_rot` — all gated to non-`pull_request` events. The "CI cadence" enumeration
above is the authority for this tier; it is repeated here only so the post-Phase-230 honest-skip
set reads as one list. `generated_admin_playwright_smoke` is no longer in this tier: Phase 231
GATE-02 / D-06 deleted its `if:` condition outright (not replaced), so it now runs on every
event, including `pull_request`, gated by nothing.

**Tier B — event-gated, added by Phase 230.**

- The job `admin_eval_render` (`Admin eval render + probe (hard signal on push/schedule/dispatch;
  not in ci-gate)`) — `if: github.event_name != 'pull_request'` — newly gated to non-`pull_request`
  events, removing a measured 17m33s from every PR (FAST-03, D-10).
- The step `design_gallery_snapshots` ("Run design gallery board snapshots (non-PR)") inside
  `example_playwright_smoke` — `id: design_gallery_snapshots`,
  `if: ${{ !cancelled() && github.event_name != 'pull_request' && needs.changes.outputs.docs_only != 'true' }}`
  — newly gated to non-`pull_request` events, carrying the 84 per-board pixel-diff snapshot
  assertions (FAST-02, D-01/D-04). Its step id is in the seam-outcome aggregator's hard-coded
  outcome list (the `Aggregate Playwright step outcomes` step's `for o in ...` loop inside
  `example_playwright_smoke`), so a snapshot regression on `main` still reds the
  ruleset-required "Example Playwright smoke (full lifecycle)" context.

**Tier C — diff-gated (docs-only), added by Phase 230.** These skip on the *content of the diff*
(a new `changes` job's `docs_only` output) rather than on the event, which is a different audit
question from Tier A/B. Gated:

- The heavy steps (deps cache through the test-running step) of the four app-behaviour
  ruleset-required lanes — `example_unit_smoke`, `install_smoke`, `example_http_smoke`,
  `example_playwright_smoke` — each guarded `if: needs.changes.outputs.docs_only != 'true'` (with
  `!cancelled()` composed in where the job also carries other conditions). Gated at step level, not
  job level, so all four required contexts still run and conclude `success`.
- The whole `library_tests_dep_off` job —
  `if: ${{ !cancelled() && needs.release_ref_guard.result == 'success' && needs.changes.outputs.docs_only != 'true' }}`
  — gated at job level, permitted because it is not a ruleset-required context (D-08).

**Fail-open polarity:** an empty, missing, or non-`'true'` `docs_only` output runs every heavy
step and job above. Only an explicit `docs_only == 'true'` skips them.

**Not skipped.** `fast_checks` and `library_tests`/`library_tests_shard` are deliberately exempt
from Tier C and carry no `changes` dependency.

#### Accepted residuals introduced by Phase 230
