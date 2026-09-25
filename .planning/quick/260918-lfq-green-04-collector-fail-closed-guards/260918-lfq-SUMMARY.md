---
phase: quick-260918-lfq
plan: 01
status: complete
subsystem: ci-evidence
files_modified:
  - scripts/ci/capture-green-04-evidence.sh
  - scripts/ci/capture-green-04-evidence.test.sh
  - .github/workflows/ci.yml
metrics:
  self_test_before: "36 pass / 0 fail"
  self_test_after: "62 pass / 0 fail"
  prohibitions: "93 pass / 0 fail"
  commits: 3
---

# Quick Task 260918-lfq: GREEN-04 Collector Fail-Closed Guards — Summary

Closed three Phase 240 collector follow-up todos as one change: `capture-green-04-evidence.sh`
now fails closed on four previously fail-open paths, each guard observed RED against a stub
payload that actually triggers it, and the hermetic self-test finally has a CI caller.

## New fail-closed tokens and the label that proves each RED

| Token | Trigger | Proving label |
|---|---|---|
| `sc2_job_not_found` | anchored SC-2 selector matched 0 jobs (renamed / newly matrixed job) | `sc2_smoke_job_renamed`, `sc2_gate_job_renamed` |
| `sc2_job_conclusion_null` | matched SC-2 job present but `conclusion: null` (queued / running) | `sc2_smoke_conclusion_null`, `sc2_gate_conclusion_null` |
| `insufficient_main_runs` | `main` window below the `MIN_RUNS` floor (default 5) | `default_min_runs_floor` |
| `min_main_runs_malformed` | `--min-main-runs 0` / non-positive / non-integer | `min_runs_malformed` |
| `main_window_excludes_dispatch_run` | window does not contain the dispatch run's `created_at` | `window_excludes_dispatch` |
| `dispatch_run_created_at_malformed` | `created_at` not fixed-width UTC ISO-8601 | (shape check alongside the window guard) |

Seven new `expect_fail` labels; each asserts non-zero exit, the token in stderr, and no receipt
at the `--output` path. Plus three extra assertions: two proving the null-conclusion cases do
NOT name `sc2_job_not_found` (D-2 non-collapse), and one proving the window guard issues zero
`/jobs?` calls.

## Non-vacuity — RED observed before each guard existed

This was staged deliberately, since a guard that is present but never seen failing is the exact
defect class this task exists to close (Phase 216 SC-5; Phase 240 plan-review B-1).

- Task 1 RED run: `sc2_smoke_job_renamed` / `sc2_gate_job_renamed` both reported
  `exited 0, expected failure` and `receipt written despite failure` — the collector went GREEN
  and emitted a clean receipt against a payload where the selector matched zero jobs, letting
  `first` contribute a silent `null` to `flake_attributable_red_count`. Guard added → green.
- Task 2 RED run (collector carrying flag-accept-only scaffolding so each token failed for the
  *right* reason, never on `unknown_argument`): all five remaining labels reported
  `exited 0, expected failure` + `receipt written despite failure`, and both receipt-field
  assertions failed. `pass=44 fail=18`. Guards added → `pass=62 fail=0`.
- Belt-and-suspenders mutation at committed HEAD: weakening `MIN_RUNS=5` to `1` turns
  `default_min_runs_floor` red (3 failures); tree restored, green again.

## Decisions honored

- **D-1** `MIN_RUNS=5`, rationale in the comment; overridable only via explicit `--min-main-runs N`,
  whose value is recorded in the receipt as `sc2.min_runs`.
- **D-2** absent vs null are two distinct tokens, asserted non-collapsible.
- **D-3** no ambiguity guard added.
- **D-4** receipt strictly additive. Verified mechanically against the shipped
  `240-GREEN-04-EVIDENCE.json` (cited by the public closure comment on issue #231): key-path set
  is a strict superset, `missing: NONE`, `retyped: NONE`, added exactly `sc2.min_runs`,
  `sc2.window.dispatch_run_created_at`, `sc2.window.binding`; `schema_version` stays
  `sigra.green-04-evidence/v1`. The shipped receipt file itself is untouched.
- **D-5** window derivation recorded as a computed fact (`dispatch_run_created_at` + a fixed
  `binding` string), not caller prose. No new caller-steerable argument.
- **D-6** bash 3.2 compatible — optional-arg array expanded as `${extra[@]+"${extra[@]}"}`;
  self-test verified green under both `/bin/bash` 3.2.57 and bash 5.2.37.

## CI wiring

One step added to `fast_checks` in `.github/workflows/ci.yml`, immediately after the Pages
legacy-branch self-test, with no step-level `if:` and no `continue-on-error`. `ci-gate.needs`
is unchanged (still 10 entries; `fast_checks` was already one). YAML parse-verified. The stale
"NOT WIRED INTO ci.yml, deliberately" paragraph in the self-test header was corrected.

## Notes

- The window/binding guard reuses the metadata response already fetched for the `head_sha`
  check — no extra API call — and sits in preflight, so an unbound window costs zero collection
  calls. `head_sha` is still checked first (D-13 ordering).
- The `MIN_RUNS` floor sits before the per-run `/jobs` loop, so a refused window costs no
  further API calls.
- No `REQUIREMENTS.md` entry marked complete (quick task, not a phase).

## Deviations from plan

None affecting behavior. One process note: the SELECTOR CONTRACT header note that Task 2's
action re-specified was already landed by Task 1, so it was not applied twice.

## Verification

```
bash scripts/ci/capture-green-04-evidence.test.sh      # pass=62 fail=0 → PASS
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs   # 93 pass / 0 fail
```

Per the plan, `mix ci` was not run: no Elixir source is in scope, and this repo currently
carries six environmental `Sigra.Audit.Forwarders.ThreadlineTest` failures unrelated to this
change.

## Self-Check: PASSED
