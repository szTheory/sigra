---
phase: quick-260918-lfq
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/ci/capture-green-04-evidence.sh
  - scripts/ci/capture-green-04-evidence.test.sh
  - .github/workflows/ci.yml
autonomous: true
requirements: [CR-01, CR-02, SELFTEST-CI]
estimate:
  tokens: 60000
  raw_tokens: 30000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "A `main` run whose `ci-gate` or `Generated admin Playwright smoke` job name matches ZERO jobs aborts the capture with `sc2_job_not_found` instead of contributing a silent `null` to `flake_attributable_red_count`."
    - "A matched SC-2 job whose `conclusion` is null aborts with `sc2_job_conclusion_null` — a DIFFERENT token from the absent-job case, never collapsed into it."
    - "A `main` window yielding fewer than `MIN_RUNS` runs aborts with `insufficient_main_runs`; a narrower floor is possible only via an explicit `--min-main-runs N` flag whose value is recorded in the receipt."
    - "A window that does not contain the dispatch run's `created_at` aborts with `main_window_excludes_dispatch_run`, enforcing the invariant the script header at :6-10 already claims."
    - "Every one of those four tokens is observed RED by `capture-green-04-evidence.test.sh` against a stub payload that actually triggers it."
    - "`fast_checks` in ci.yml runs `scripts/ci/capture-green-04-evidence.test.sh` on every PR, hermetically (no token, no network, no Postgres)."
  artifacts:
    - scripts/ci/capture-green-04-evidence.sh
    - scripts/ci/capture-green-04-evidence.test.sh
    - .github/workflows/ci.yml
  key_links:
    - "collector failure tokens -> self-test `expect_fail` assertions -> `fast_checks` step (the only thing that makes the assertions load-bearing)"
    - "gh stub `/actions/runs/{dispatch}` response -> `created_at` -> window-binding guard"
---

<objective>
Close the three Phase 240 collector follow-up todos as one coherent change: make
`scripts/ci/capture-green-04-evidence.sh` fail closed on (a) an SC-2 selector that matches zero
jobs, (b) a matched SC-2 job with a null conclusion, (c) an empty/near-empty `main` window, and
(d) a window unrelated to the dispatch run being captured — then prove each guard RED in the
hermetic self-test and finally give that self-test a CI caller so the guards cannot silently
regress.

Purpose: a collector that reports "zero red runs" because it matched zero jobs, or emits a clean
receipt over a window it never measured, is the exact "green gate that verified nothing" pattern
the v1.48 milestone exists to retire. A guard present but never observed failing is the same
defect one level up (Phase 216 SC-5; Phase 240 plan-review B-1) — hence the RED assertions and
the CI wiring are part of this change, not a follow-on.

Output: three modified files, no new files. No `mix` / Elixir changes.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
</execution_context>

<context>
@scripts/ci/capture-green-04-evidence.sh
@scripts/ci/capture-green-04-evidence.test.sh
@.planning/todos/pending/2026-09-18-capture-green-04-sc2-selectors-fail-open.md
@.planning/todos/pending/2026-09-18-capture-green-04-empty-window-clean-receipt.md
@.planning/todos/pending/2026-09-18-capture-green-04-selftest-has-no-ci-caller.md
</context>

<decisions>
Recorded here so the executor does not re-litigate them mid-task.

- **D-1 — `MIN_RUNS` default is `5`.** The shipped capture observed 8 runs. `1` makes the floor
  nearly vacuous (a single-run window still reads as a clean `main`), and the SC-2 claim is
  "`ci-gate` is green across a representative `main` window", which one or two runs cannot
  support. `5` is below the real capture (so it does not retroactively invalidate the shipped
  method) and high enough that a degenerate window is refused. A legitimately narrow window
  remains possible via `--min-main-runs N`, which forces the operator to state the weaker floor
  explicitly AND records it in the receipt, instead of the current silent pass.
- **D-2 — absent vs null are two tokens, never one.** `sc2_job_not_found` (selector matched zero
  jobs: a rename or a matrixed job) and `sc2_job_conclusion_null` (job present, still running or
  queued: the capture ran too early) have different causes and different operator responses.
  Collapsing them would reintroduce the conflation SC-1 already refuses at `:192-196`.
- **D-3 — no ambiguity guard.** A ">1 match discards silently via `first`" guard is deliberately
  NOT added. Both SC-2 regexes are anchored at both ends, so a matrixed (` (N)`-suffixed) job
  produces zero matches and lands on `sc2_job_not_found` rather than an ambiguous multi-match.
  Adding a third arm buys no new failure mode and costs a third stub shape.
- **D-4 — receipt fields are additive; `schema_version` stays `sigra.green-04-evidence/v1`.**
  `240-GREEN-04-EVIDENCE.json` is cited by the public closure comment on issue #231; no existing
  key changes meaning, type, or disappears. The three new keys (`sc2.min_runs`,
  `sc2.window.dispatch_run_created_at`, `sc2.window.binding`) are strictly added. Bumping the
  schema string would make the shipped receipt read as a stale schema in a reader that pins the
  version, for no gain.
- **D-5 — window derivation is recorded as a computed fact, not caller prose.** The todo suggests
  recording *how* the bounds were derived. A free-text `--window-derivation` argument would be a
  caller-authored claim inside a deliberately non-steerable collector. Instead the receipt records
  the objective fact the new guard checked: the dispatch run's `created_at` and a fixed
  `binding` string naming the enforced invariant.
- **D-6 — bash 3.2 compatible.** macOS ships bash 3.2, where `"${arr[@]}"` on an EMPTY array
  under `set -u` is an unbound-variable error. Any optional-argument array in the self-test must
  be expanded with the `${arr[@]+"${arr[@]}"}` idiom.
</decisions>

<tasks>

<task type="tracer">
  <name>Task 1: `sc2_job_not_found` end-to-end — guard, stub knob, RED assertion</name>
  <files>scripts/ci/capture-green-04-evidence.sh, scripts/ci/capture-green-04-evidence.test.sh</files>
  <behavior>
    - RED: a `main` run whose smoke job is named `Generated admin Playwright smoke (shard 1)`
      (anchored regex matches zero) aborts non-zero, stderr names `sc2_job_not_found`, and no
      receipt is written at the `--output` path.
    - RED: a `main` run whose gate job is named `ci-gate-v2` aborts the same way.
    - GREEN (positive control, already asserted): the unmodified stub still yields
      `run_count == 2` and `flake_attributable_red_count == 0` with both selectors non-null.
  </behavior>
  <action>
    This task proves one guard through every layer — collector, gh stub, assertion — before the
    remaining three are expanded from the same shape in Task 2.

    In `capture-green-04-evidence.sh`, inside the `for main_run_id in $MAIN_RUN_IDS` loop and
    BEFORE the existing `jq -e --slurpfile ...` merge at `:241-252`, add explicit bash-level
    selector counts (bash-level, not a jq `error()`, so the failure token is emitted by the
    script's own `fail` helper and is grep-stable in stderr):

    - Build `$jobs` once into a temp file (reuse `$TMPD`) as
      `[$pages[].body.jobs[]] | map({name, conclusion})`, then read
      `gate_matches` and `smoke_matches` via `jq -r --arg re ... '[.[] | select(.name | test($re))] | length'`.
    - If either count is `0`, call
      `fail "sc2_job_not_found: run ${main_run_id} matched 0 jobs for <selector label>"` where the
      label distinguishes the gate selector from the smoke selector. The token substring
      `sc2_job_not_found` must be present verbatim in both messages so one grep covers both arms.
    - Leave the existing merge jq reading `| first` as-is: with a non-zero count proven above,
      `first` can no longer yield the fail-open `null` that CR-01 describes.

    Add a short header note next to the SELECTOR CONTRACT block explaining that SC-2 now has the
    analog SC-1 has had since `:192-196`: zero matches is a REJECTED SHAPE, not an empty window.
    Do not restate any literal that an acceptance grep negates.

    In `capture-green-04-evidence.test.sh`, extend the EXISTING stub generator rather than forking
    it: replace the inline per-main-run `printf` at `:96-99` with an `emit_main_jobs <run_id>`
    function that holds `gate_name`, `smoke_name`, `gate_concl`, `smoke_concl` in locals and
    mutates them from a single `SC2="${FAKE_SC2_MODE:-ok}"` case statement — same pattern as
    `emit_legs`/`FAKE_JOB_NAME_SHAPE`. For this task implement modes `ok`, `smoke_renamed`
    (`smoke_name="Generated admin Playwright smoke (shard 1)"`) and `gate_renamed`
    (`gate_name="ci-gate-v2"`). Keep the emitted JSON byte-identical to today's in `ok` mode so
    the existing 36 assertions are untouched.

    Add two `expect_fail` calls using the existing helper:
      `expect_fail sc2_smoke_job_renamed sc2_job_not_found "$TMP/out/sc2-smoke-renamed.json" FAKE_MODE=ok FAKE_SC2_MODE=smoke_renamed FAKE_HEAD_SHA="$REAL_HEAD"`
      and the `gate_renamed` sibling.
  </action>
  <verify>
    <automated>bash -c 'cd /Users/jon/projects/sigra && bash scripts/ci/capture-green-04-evidence.test.sh >/tmp/g04-t1.out 2>&1; rc=$?; tail -2 /tmp/g04-t1.out; grep -c "ok   - sc2_smoke_job_renamed\|ok   - sc2_gate_job_renamed" /tmp/g04-t1.out; exit $rc'</automated>
  </verify>
  <done>Self-test exits 0, prints `fail=0`, and reports 6 ok-lines across the two new labels (exits non-zero / names the token / no receipt, x2). The ten original `ok:` assertions still pass unchanged.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: expand to the remaining three guards — null conclusion, `MIN_RUNS` floor, window binding</name>
  <files>scripts/ci/capture-green-04-evidence.sh, scripts/ci/capture-green-04-evidence.test.sh</files>
  <behavior>
    - RED `sc2_job_conclusion_null`: matched smoke job with `"conclusion": null` aborts; separately,
      matched gate job with `"conclusion": null` aborts. Both name `sc2_job_conclusion_null` and
      NEITHER names the absent-job token (D-2).
    - RED `insufficient_main_runs`: default floor with a 2-run stub window aborts.
    - RED `min_main_runs_malformed`: `--min-main-runs 0` (and any non-positive / non-integer) aborts
      at argument parse, before any `gh` call.
    - RED `main_window_excludes_dispatch_run`: dispatch run `created_at` of `2026-09-19T00:00:00Z`
      against the harness window `2026-09-17T00:00:00Z..2026-09-18T00:00:00Z` aborts, before any
      `/jobs?` collection call.
    - GREEN: the `ok` receipt gains `sc2.min_runs == 2`, `sc2.window.dispatch_run_created_at`
      equal to the stub's value, and a non-empty `sc2.window.binding`; determinism still holds.
  </behavior>
  <action>
    Collector, in this order:

    1. **Null-conclusion arm (CR-01, second half).** Immediately after the Task 1 count checks, if
       the matched gate or smoke job's `conclusion` is not a non-empty string, call
       `fail "sc2_job_conclusion_null: run ${main_run_id} ..."`. This mirrors `leg_without_conclusion`
       at `:200-201`: an in-progress or queued job means the capture ran too early. Keep it a
       distinct token from the Task 1 one — D-2.

    2. **`--min-main-runs` flag.** Add `MIN_RUNS=5` beside the other fixed constants, documenting
       D-1's rationale in the comment. Add a `--min-main-runs) ... MIN_RUNS="$2"` arm to the
       argument loop and extend the `usage` string. Validate with
       `[[ "$MIN_RUNS" =~ ^[1-9][0-9]*$ ]] || fail "min_main_runs_malformed"` alongside the other
       argument validations at `:76-79`, so it fires before the `gh` preflight.

    3. **Window/dispatch binding (CR-02, second half).** At `:97`, the run metadata is already
       fetched once; capture that response into a shell variable instead of piping straight to jq,
       then read BOTH `.head_sha` and `.created_at` from it — no additional API call. Keep the
       existing `head_sha` check first (D-13 ordering). Then validate the timestamp shape with the
       same `^[0-9]{4}-...Z$` regex used for the window arguments (`fail "dispatch_run_created_at_malformed"`)
       and assert `[[ ! "$RUN_CREATED_AT" < "$WINDOW_START" ]] && [[ ! "$RUN_CREATED_AT" > "$WINDOW_END" ]]`
       (inclusive bounds; lexicographic compare is exact for fixed-width `Z` ISO-8601), failing with
       `main_window_excludes_dispatch_run`. Because this sits in preflight, it fires before any
       collection call.

    4. **`MIN_RUNS` floor.** After `collect_pages` fills `SC2_RUNS_MANIFEST` at `:224-226` and
       before the per-run `/jobs` loop, count the runs in the manifest and
       `fail "insufficient_main_runs"` when the count is below `MIN_RUNS` — placing it before the
       loop so a refused window costs no further API calls.

    5. **Receipt (D-4, additive only).** Pass `--argjson min_runs "$MIN_RUNS"` and
       `--arg run_created_at "$RUN_CREATED_AT"` into the final `jq -S -n` and add, under `sc2`:
       `min_runs: $min_runs`, and inside `window`: `dispatch_run_created_at: $run_created_at` plus a
       fixed `binding` string naming the enforced invariant (D-5). Change nothing else about the
       emitted object.

    Self-test:

    - Stub: extend the `emit_main_jobs` case statement with `smoke_null` and `gate_null` modes
      (set the respective `*_concl` local to the JSON literal `null`). Extend the
      `/actions/runs/${DISPATCH_RUN_ID}` response to emit `created_at` from
      `FAKE_RUN_CREATED_AT`, defaulting to `2026-09-17T12:00:00Z` — inside the harness window, so
      every existing assertion keeps passing.
    - Harness: `run_collector` must append an optional `--min-main-runs` argument. Read a
      `SELFTEST_MIN_RUNS` shell variable defaulting to `2`; when its value is the literal
      `default`, append nothing (that is how the default-floor RED case is driven). Build it as a
      local array and expand with `${extra[@]+"${extra[@]}"}` per D-6. Callers set it with a
      variable prefix on the function call, e.g. `SELFTEST_MIN_RUNS=default expect_fail ...`, which
      is visible to the function body without touching `expect_fail`'s `env "$@"` forwarding.
      With the default `2`, all ten existing `ok:` assertions and the determinism pair are
      unaffected.
    - Add five `expect_fail` calls: `sc2_smoke_conclusion_null` and `sc2_gate_conclusion_null`
      (token `sc2_job_conclusion_null`), `default_min_runs_floor` (token `insufficient_main_runs`,
      driven by `SELFTEST_MIN_RUNS=default` against the 2-run stub — this simultaneously proves the
      compiled-in default exceeds 2), `min_runs_malformed` (token `min_main_runs_malformed`, driven
      by `SELFTEST_MIN_RUNS=0`), and `window_excludes_dispatch` (token
      `main_window_excludes_dispatch_run`, driven by `FAKE_RUN_CREATED_AT=2026-09-19T00:00:00Z`).
    - Add a non-collection proof for the window guard in the same style as the existing
      `rate_limited` / `dirty_tree` checks: assert `$TMP/window_excludes_dispatch.calls` contains
      no `/jobs?` line.
    - Add two positive assertions on `$TMP/out/ok.json`: `.sc2.min_runs == 2`, and
      `.sc2.window.dispatch_run_created_at` equals the stub default with `.sc2.window.binding` a
      non-empty string.
  </action>
  <verify>
    <automated>bash -c 'cd /Users/jon/projects/sigra && bash scripts/ci/capture-green-04-evidence.test.sh >/tmp/g04-t2.out 2>&1; rc=$?; tail -2 /tmp/g04-t2.out; grep -c "ok   - sc2_smoke_conclusion_null\|ok   - sc2_gate_conclusion_null\|ok   - default_min_runs_floor\|ok   - min_runs_malformed\|ok   - window_excludes_dispatch" /tmp/g04-t2.out; exit $rc'</automated>
  </verify>
  <done>Self-test exits 0 with `fail=0`; the five new labels contribute 15 ok-lines; `jq -e '.sc2.min_runs and .sc2.window.dispatch_run_created_at and .sc2.window.binding'` is true on the ok receipt; the shipped `240-GREEN-04-EVIDENCE.json` keys are all still produced (no key removed or retyped).</done>
</task>

<task type="auto">
  <name>Task 3: wire the self-test into `fast_checks` and correct the now-false header claim</name>
  <files>.github/workflows/ci.yml, scripts/ci/capture-green-04-evidence.test.sh</files>
  <action>
    Add one step to the `fast_checks` job in `.github/workflows/ci.yml`, immediately after the
    `Pages legacy-branch script self-test` step (the byte-model at `:262-267`): same 6-space step
    indentation, a `name:`, a short explanatory comment naming this quick task and what the
    self-test proves, and a single `run: bash scripts/ci/capture-green-04-evidence.test.sh`. No
    step-level `if:` (the neighbouring self-test steps have none, and a docs-gated `fast_checks`
    step is what prohibition `p06` exists to refuse). Do NOT touch `ci-gate.needs` — `fast_checks`
    is already an entry there.

    Then correct `capture-green-04-evidence.test.sh`'s header at `:16-18`, which currently asserts
    the script is deliberately unwired. Replace that paragraph with the true statement: the
    self-test IS run by `fast_checks`, it is hermetic (stub `gh` on PATH, throwaway git repo — no
    token, no network, no Postgres), and the collector itself remains operator-invoked once on a
    clean tree at the final committed HEAD. Leaving the stale paragraph would make the file assert
    something the workflow contradicts.

    Sanity-check that prohibition `p20` is unaffected: it compares `green-04-evidence.yml` against
    ci.yml's `generated_admin_playwright_smoke` job only, and this edit touches `fast_checks`.
  </action>
  <verify>
    <automated>bash -c 'cd /Users/jon/projects/sigra && grep -n "capture-green-04-evidence.test.sh" .github/workflows/ci.yml && node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs >/tmp/g04-prohib.out 2>&1; tail -6 /tmp/g04-prohib.out; bash scripts/ci/capture-green-04-evidence.test.sh | tail -2'</automated>
  </verify>
  <done>`ci.yml` contains exactly one `fast_checks` step invoking the self-test, positioned after the Pages self-test step with matching indentation and no `if:`; all prohibition tests still pass (`p20` and `p06` in particular); the self-test still ends `PASS`.</done>
</task>

</tasks>

<verification>
Run from the repo root on branch `gsd/quick-green-04-collector-fail-closed-guards` (do not switch
branches; do not push to `main`):

```
bash scripts/ci/capture-green-04-evidence.test.sh
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```

The first must end `PASS` with `fail=0` and a pass count strictly greater than 36. The second must
report zero failing tests.

Do NOT gate on a clean `mix ci`: this repo currently carries six environmental
`Sigra.Audit.Forwarders.ThreadlineTest` failures unrelated to this change. No Elixir source is
touched here, so `mix` is out of scope entirely.

Shell note: every command above is written to run under `bash -c`. The operator's interactive
shell is zsh, which does not word-split unquoted expansions and has previously produced a
confident false negative in this repo when a glob was passed unquoted.
</verification>

<success_criteria>
- Four new fail-closed tokens exist in the collector: `sc2_job_not_found`,
  `sc2_job_conclusion_null`, `insufficient_main_runs`, `main_window_excludes_dispatch_run`
  (plus the argument-validation token `min_main_runs_malformed` and the shape token
  `dispatch_run_created_at_malformed`).
- Each of those four is observed RED by the self-test against a stub payload that triggers it —
  seven new `expect_fail` labels in total, each asserting non-zero exit, the token in stderr, and
  no receipt at the `--output` path.
- The absent-job and null-conclusion cases resolve to DIFFERENT tokens.
- The original 36 assertions still pass, produced by the same single stub generator (extended, not
  forked).
- `MIN_RUNS` defaults to 5 with a documented rationale and is overridable only through an explicit
  `--min-main-runs N` flag whose value is recorded in the receipt.
- The emitted receipt is a strict superset of the `sigra.green-04-evidence/v1` shape shipped in
  `240-GREEN-04-EVIDENCE.json`.
- `fast_checks` runs the self-test; `ci-gate.needs` is unchanged.
- No REQUIREMENTS.md entry is marked complete.
</success_criteria>

<output>
No SUMMARY file is required for a quick task. Report the final self-test pass/fail counts and the
list of new tokens with the label that proves each one RED.
</output>
