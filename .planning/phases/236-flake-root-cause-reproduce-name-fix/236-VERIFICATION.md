---
phase: 236-flake-root-cause-reproduce-name-fix
verified: 2026-09-15T22:40:00Z
status: passed
score: 5/5 must-haves verified (SC-2 closed by accepted override)
overrides:
  - must_have: "If it is the product race, /admin/audit has exactly one owner of its URL: no plain <form method=\"get\"> / <a href> competing against handle_params/3 in lib/sigra/admin/live/audit_index_live.ex"
    reason: "D-30 scope boundary: the chip-remove and prev/next anchors are rendered by lib/sigra/admin/components.ex, shared with the two D-30-excluded views; converting them drags user-audit-*.png x3 and the users-index baselines into a PNG recapture lane that ROADMAP standing constraint 7 forbids in v1.48. Export CSV is a controller download that must remain a document navigation. The unconverted anchors are not on the failing test's path. Residue tracked in .planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md."
    accepted_by: "szTheory"
    accepted_at: "2026-09-15T23:05:00Z"
covered_files:
  - ".github/workflows/ci.yml"
  - ".planning/REQUIREMENTS.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-PLAN.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-01-SUMMARY.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-02-PLAN.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-02-SUMMARY.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-03-PLAN.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-03-SUMMARY.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-04-PLAN.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-04-SUMMARY.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-DIAGNOSIS.md"
  - ".planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md"
  - "lib/sigra/admin/live/audit_index_live.ex"
  - "scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs"
  - "test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts"
  - "test/sigra/planning/phase_236_audit_url_ownership_test.exs"
  - "test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs"
covered_digest: "v1:sha256:f6f3d57f33ea9cdbe36d23a472f8f2b53e1facea551f9386fe66ab051a34e1f6"
behavior_unverified: 0
overrides_applied: 0
deferred:
  - truth: "`main`'s aggregate gate observed green / non-flipping on main itself"
    addressed_in: "Phase 240 (GREEN-04)"
    evidence: "ROADMAP scope discipline: 'Green evidence: n≥20 via workflow_dispatch on the single affected job'; Phase 240 SC-4 explicitly owns closing .planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md against n≥20 green-main evidence. Phase 236 deliberately carries n=5 on the PR."
  - truth: "`ci-gate` run-level conclusion is green"
    addressed_in: "Out-of-scope todo (v1.48 REQUIREMENTS rollover debt)"
    evidence: ".planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md — CI log for run 35034938082 shard job 104601822192 shows exactly 3 failures of 2606, all phase_235_fast_01_* contract tests; ROADMAP standing constraint 4 routes found-while-cleaning to a todo."
human_verification:
  - test: "Decide whether ROADMAP SC-2's absolutist wording ('no plain <form method=\"get\"> / <a href> competing against handle_params/3 in lib/sigra/admin/live/audit_index_live.ex') is satisfied by the D-30-narrowed delivery: six anchors + the form converted, but four <a href>-shaped URL emitters remain in that file — Export CSV (:144, a controller CSV download that must stay a document navigation) and three hrefs passed into shared components (remove_href :162, prev_href :211, next_href :212, rendered by lib/sigra/admin/components.ex, which this phase was prohibited from editing)."
    expected: "Either accept the narrowing as written (the exception is named in 236-02-PLAN must_haves, driven by ROADMAP standing constraint 7's no-PNG-recapture rule, and tracked in .planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md) — recorded as an override — or require the three shared-component anchors before accepting the phase."
    why_human: "The residue is a deliberate planner-level scope decision with a documented cost (dragging user-audit-*.png ×3 and users-index baselines into a recapture lane). It is neither a defect nor full literal compliance; only the developer can decide whether the ROADMAP contract is met as narrowed. The behaviour SC-2 actually targets — the failing test's path — IS fixed and proven green."
---

# Phase 236: Flake Root Cause — Reproduce, Name, Fix — Verification Report

**Phase Goal:** `main`'s aggregate gate stops flipping red on an unchanged SHA — because the `Generated admin Playwright smoke` failure has a named, fixed cause, not because it was retried into silence.
**Verified:** 2026-09-15
**Status:** human_needed (4/5 verified, 1 partial by explicit design)
**Re-verification:** No — initial verification
**Branch verified:** `gsd/phase-236-flake-root-cause` @ `b8a15873` (phase base `160de093`)

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence (independently re-derived) |
|---|-------|--------|-------------------------------------|
| SC-1 | A captured RED exists for the `toHaveURL` assertion, recorded with run id / artifact path; no fix accepted without it | ✓ VERIFIED | `gh run view 35004420339` → `conclusion: failure`, `event: push`, `headBranch: main`, `headSha cc4835c5`. `gh api .../jobs/104500542292` → `Generated admin Playwright smoke`, `conclusion: failure`. I pulled the raw job log myself: `Received string: "http://localhost:4017/admin/audit?action_prefix=admin.impersonation&order_by=inserted_at&order_direction=desc&outcome=failure"` at `admin-generated.spec.ts:459:22`. The verbatim string in the ledger is not fabricated. Local trace exists at `.gsd/scratch/phase236-evidence/trace.zip`, 2,005,798 bytes — byte count matches the ledger claim exactly. **Line numbers: BOTH documents are right** — `:428` is the `test(` declaration and `:459` is the `toHaveURL` assertion; verified directly against the spec file. |
| SC-1b | The received URL discriminates D-05's three branches and the diagnosis cites which | ✓ VERIFIED | `actor=` is *absent* from the received URL (not present-and-empty) → D-05 branch **(a)**. Re-derived from the raw CI log, not from the SUMMARY. `236-DIAGNOSIS.md:3` states "Named cause: product race." |
| SC-2 | Written differential names harness race / DB collision / product race and rules out the other two; if product race, `/admin/audit` has exactly ONE owner of its URL; behaviour-preserving in rendered classes/layout | ⚠️ PARTIAL (by explicit design) | Differential present with named rule-outs at `236-DIAGNOSIS.md:88` (harness race), `:111` (DB collision), `:122` (value-wipe). Fix present and substantive (see Artifacts). **Residue:** four `<a href>`-shaped emitters remain in `audit_index_live.ex` (`:144` Export CSV → controller download, legitimately a document navigation; `:162`, `:211`, `:212` → shared-component hrefs the phase was prohibited from editing). The LiveView's own six anchors + form ARE converted. Zero PNG files changed. See Human Verification. |
| SC-3 | The affected job, dispatched repeatedly against the fix, passes every repeat, and the Criterion-1 reproduction no longer reproduces — both from the Actions API | ✓ VERIFIED | I ran `gh run view <id> --json jobs` on all five ids myself: `Generated admin Playwright smoke` = `success` on 35029916498, 35030710957, 35031404780, 35032086557, 35034938082. All five `event: pull_request`, none `cancelled` (proving genuine sequencing under `cancel-in-progress: true`). Repro half: five batch logs under `.gsd/scratch/phase236-04-afterfix/` each report `10 passed`, 50/50 total, `grep -c toHaveURL` = 0 failures per log (pre-fix was 41/50 failures). |
| SC-4 | A retry wrapper fails a `scripts/ci/prohibitions/*.test.mjs` guard, demonstrated RED against a committed known-bad fixture; and `PLAYWRIGHT_RETRIES: 1` is wired or deleted | ✓ VERIFIED | I ran the guard myself: `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts node --test …p17….test.mjs` → **exit 1** with the named message "a `retries` value is read from `process.env` — recovering a failed attempt … masks the isolation evidence a flake investigation depends on". Same guard against the real config → **exit 0**. Full glob `node --test scripts/ci/prohibitions/*.test.mjs` → **71/71 pass**, no guard-number collision (p01–p17, SURF-04 correctly reserved as `p18`). `grep -c PLAYWRIGHT_RETRIES .github/workflows/ci.yml` = **0** with positive control `grep -c PLAYWRIGHT_` = **8** (the search ran; silence is a finding, not an artifact). Non-vacuity floors present at guard `:104` (`retries:` line must parse) and `:112` (≥10 spec files). `mix.exs` untouched (0 files in diff) — no `mix ci` topology change. |
| SC-5 | If root cause genuinely fails, a dated quarantine entry naming an owner in `.github/ci-skip-manifest.tsv` | ✓ N/A — correctly not triggered | Root cause did NOT fail (SC-1/2/3 all carried). `git log --diff-filter=A -- .github/ci-skip-manifest.tsv` → created `16622ade` (v1.47), and `git log 160de093..HEAD -- .github/ci-skip-manifest.tsv` → **empty**: the file predates this phase and was not touched. Plan 236-04 explicitly prohibited building the schema amendment under branch (a) — prohibition honored. Existence is not a violation; provenance checked. |

**Score:** 4/5 truths verified, 1 partial-by-design (0 present-behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/admin/live/audit_index_live.ex` | 6 `patch={}` conversions, `phx-submit`, `handle_event/3`, whitelist | ✓ VERIFIED | `grep -c 'patch={'` = 6 at :78, :85, :143, :164, :177, :202. `phx-submit="apply_filters"` at :96. `handle_event("apply_filters", …)` at :56 doing `index_path |> append_query(Map.take(params, @filter_param_keys)) |> push_patch`. `handle_params/3` at :25 is still the **sole** loader (`Explorer.list_events` appears only there); `handle_event` does zero I/O. `phx-change` count = **0** (D-09 honored). |
| `@filter_param_keys` whitelist | Must cover exactly the form's `name=` attributes (D-14) | ✓ VERIFIED | Form emits `name=` for: action_prefix, actor, effective_user, from, order_by, order_direction, outcome, page_size, to (9). Whitelist at :53 is the same 9 keys, no more, no less. `cursor` deliberately absent (documented). |
| `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` | Guard, observed RED | ✓ VERIFIED | Exit 1 / exit 0 re-observed by this verifier, not taken from SUMMARY. |
| `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` | Committed known-bad fixture (constraint 6) | ✓ VERIFIED | Present and tracked; drives the RED above. |
| `test/sigra/planning/phase_236_audit_url_ownership_test.exs` + `…retry_wrapper_prohibition_test.exs` | ExUnit source contracts | ✓ VERIFIED | `mix test` on both → **17 tests, 0 failures**. |
| `236-EVIDENCE.md` | Parses under `parseEvidenceSlots`, p12 grammar | ✓ VERIFIED | Parsed by invoking `parseEvidenceSlots` from `scripts/ci/prohibitions/_lib.mjs` **directly against this phase's ledger** (NOT by running p12, which hardcodes phase 230's ledger at `:26` and would prove nothing here). Result: 3 slots — BEFORE-FLAKE-RED, AFTER-P17-GUARD-OBSERVED, AFTER-FIX-GREEN — each with a conforming `Status:` line carrying real run ids. Empty-doc positive control correctly threw `…the parse broke, this is not a pass`. |
| `236-DIAGNOSIS.md` | Differential with cited rule-outs | ✓ VERIFIED | Sections 3, 4, 5 rule out harness race, DB collision, value-wipe with cited observations. |
| Deferral todo | D-30 residue survives archival | ✓ VERIFIED | `.planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md` names `audit_user_live.ex:98`, `users_index_live.ex:126`, AND the three unconverted `/admin/audit` anchors (`components.ex:378-380`, `:841`, `:859`) with the recapture cost spelled out. |

### Key Link Verification

| From | To | Via | Status |
|------|-----|-----|--------|
| `handle_event("apply_filters")` | `handle_params/3` | `index_path/1` → `append_query/2` → `push_patch(to:)` | ✓ WIRED — single loader preserved |
| `@filter_param_keys` | patched URL | `Map.take/2` (ASVS V5 control) | ✓ WIRED — whitelist applied before URL construction; no raw param map reaches the URL |
| `push_patch` target | local path only | `index_path(socket.assigns.admin_scope)` | ✓ WIRED — never a full URL/host; scope-resolved |
| `ci.yml:393` glob | `p17-*.test.mjs` | `node --test scripts/ci/prohibitions/*.test.mjs` | ✓ WIRED — zero workflow edits needed; p17 present among the 17 discovered guards |
| `lib/` fix | generated hosts | admin LiveViews are lib-owned | ✓ WIRED — `find` confirms exactly ONE `audit_index_live.ex` in the repo (no `priv/templates/` or `test/example/` copy to drift) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| p17 reds on known-bad | `GSD_PROHIB_SUBJECT=…fixture node --test …p17….mjs` | exit 1, named message | ✓ PASS |
| p17 greens on real config | `node --test …p17….mjs` | exit 0 | ✓ PASS |
| Whole prohibition suite | `node --test scripts/ci/prohibitions/*.test.mjs` | 71 pass / 0 fail | ✓ PASS |
| Phase contract tests | `MIX_ENV=test mix test …phase_236_*` | 17 tests, 0 failures | ✓ PASS |
| Evidence ledger parses | `parseEvidenceSlots` invoked directly on `236-EVIDENCE.md` | 3 slots, control throws | ✓ PASS |
| SC-3 job conclusions | `gh run view <5 ids> --json jobs` | success ×5 | ✓ PASS |
| SC-1 RED log verbatim | `gh api .../jobs/104500542292/logs` | received URL matches ledger byte-for-byte | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| GREEN-01 (failure reproduced as captured RED before any fix) | 236-01, 236-04 | ✓ SATISFIED | Real CI run `35004420339` + local trace.zip; commit order confirms repro-before-fix: `f400fa15`/`34291dcd` (236-01 RED capture) precede `e3b61df6` (the `lib/` fix). |
| GREEN-02 (audit-filter navigation race fixed in shipped `lib/`; retry-wrapping prohibited) | 236-02, 236-03, 236-04 | ✓ SATISFIED (with the D-30 residue above) | `audit_index_live.ex` no longer runs a bare `<form method="get">` + `<a href>` presets against `handle_params/3` with no `handle_event`; p17 mechanizes the retry-wrap prohibition. |

No ORPHANED requirements: `grep` of REQUIREMENTS.md maps only GREEN-01/GREEN-02 to Phase 236, and both are claimed by plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | `TBD`/`FIXME`/`XXX` scan over all 6 changed source files (positive control: `grep -c 'def '` = 4 on the same lib file, so the search demonstrably ran) | — | **None found.** No debt-marker blocker. |

### Notes / Info (not gaps)

1. **The aggregate `ci-gate` is still red on all five SC-3 runs** — but for a *deterministic, named, out-of-scope* reason, not a flake. I pulled the shard log for run 35034938082 (job 104601822192) myself: `33 doctests, 3 properties, 2606 tests, 3 failures` — all three in `phase_235_fast_01_*_contract_test.exs`. That is the v1.48 REQUIREMENTS-rollover debt already todo-filed. It does NOT count against this phase, but it does mean the phase goal's *headline* ("`main`'s aggregate gate stops flipping red") is not yet directly observable: the fix is unmerged, and the gate is red for another cause. The part of the goal this phase owns — "the failure has a named, fixed cause, not retried into silence" — is fully achieved and proven.
2. **Evidence durability.** The SC-1 local `trace.zip` and the SC-3 batch logs live under untracked `.gsd/scratch/`. The ledger acknowledges this and anchors on the durable CI run/artifact instead. The local artifacts will not survive a scratch clean.
3. **SC-3 run 5 headSha** (`620991620…` = commit `62099162`) is the final *committed* HEAD at capture time; the three commits after it (`19d900fa`, `63d01d3e`, `b8a15873`) are the evidence/bookkeeping docs themselves. Standing constraint 2 is satisfied in the only way it can be.
4. **Orchestrator deviation is disclosed, not absorbed.** `236-04-SUMMARY.md:148-158` records the split explicitly (orchestrator drove branch/PR/five empty commits; executor independently re-verified via a second `gh` invocation under `bash -c`, and did the repro half and Tasks 2-3).
5. **ROADMAP bookkeeping lag:** the four `236-0N-PLAN.md` checkboxes and the Phase 236 line in ROADMAP.md are still `- [ ]`, while REQUIREMENTS.md already marks GREEN-01/02 `Complete`. Normal `phase.complete` bookkeeping, noted for the orchestrator.
6. **Prohibitions all honored** (re-derived, not trusted): `git diff --name-only 160de093..HEAD` over `components.ex`, `audit_user_live.ex`, `users_index_live.ex`, `admin-generated.spec.ts`, `mix.exs` → **0 files**. Zero `.png` changed. `phx-change` absent. The 2026-07-30 actor-filter-race todo correctly left `pending` (Phase 240 owns closure). Two todos correctly moved to `resolved/` as renames.

### Gaps Summary

No blocking gaps. One partial: SC-2's absolutist wording vs the D-30-narrowed delivery. The behaviour SC-2 exists to protect — the failing test's path on `/admin/audit` — is fixed, and that fix is proven green on five real CI runs and 50/50 local repeats. What remains unconverted is three shared-component anchors (plus a controller download that must stay a document navigation), deliberately excluded to avoid opening the PNG recapture lane that ROADMAP standing constraint 7 forbids, and tracked in a filed todo. This is a decision for the developer, not a defect.

**This looks intentional.** To accept the deviation, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "If it is the product race, /admin/audit has exactly one owner of its URL: no plain <form method=\"get\"> / <a href> competing against handle_params/3 in lib/sigra/admin/live/audit_index_live.ex"
    reason: "D-30 scope boundary: the chip-remove and prev/next anchors are rendered by lib/sigra/admin/components.ex, shared with the two D-30-excluded views; converting them drags user-audit-*.png ×3 and the users-index baselines into a PNG recapture lane that ROADMAP standing constraint 7 forbids in v1.48. Export CSV is a controller download that must remain a document navigation. Residue tracked in .planning/todos/pending/2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md."
    accepted_by: "<name>"
    accepted_at: "<ISO timestamp>"
```

---

_Verified: 2026-09-15_
_Verifier: Claude (gsd-verifier)_
