---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 16
subsystem: testing
tags: [enumeration-parity, named-surface-rule, planted-controls, example-host, registry]

requires:
  - phase: 259-compatibility-policy-pinned-source-and-copy-contract
    provides: five parity rows after Plans 259-14 (password-reset-request) and 259-15 (confirmation-resend), the enumeration parity harness and registry (Plan 259-07)
provides:
  - named-surface rule that judges each of the five named ids on its own (account-existence, payload-ignored, code-kind classes) with no total that can mask a failure
  - named_surface_violations/1, a pure helper with planted controls that prove each branch can fail
  - positive control that spans every named surface and keeps at least four other parity rows :same
  - registry notes for mfa-challenge and confirmation-resend that say each is counted separately
  - WR-08 residual closed in the brand-harness deferred-findings todo
affects: [259-17, 259-18, BCOPY-03]

actuals:
  tokens: 3209
  tasks: 2
  commits: 2

plan_head_before: 383c4e8a5ecab3ac9ac1c27b9065df333dfe1389
plan_head_after: a9da3bda484658415df618a709ae0208b46dbafc
commits: 2

tech-stack:
  added: []
  patterns:
    - "Pure rule helper plus in-memory planted controls: named_surface_violations/1 takes a by-id row map, and each control builds its planted registry with Map.update!/Map.delete over the real rows, never by editing the fixture"
    - "Judge-each-id-alone: no count or total across ids, so a row of one class cannot satisfy a requirement of another"

key-files:
  created: []
  modified:
    - test/example/test/example_web/enumeration_parity_test.exs
    - test/fixtures/brand/public-surfaces.json
    - .planning/todos/pending/2026-11-14-brand-harness-review-deferred-findings.md

key-decisions:
  - "mfa-challenge is kept as a real parity probe (a wrong authenticator code versus a wrong backup code) and is counted separately; it is not removed from the named set and not reclassified. It is barred from standing in for account-existence evidence by judging every id on its own. Test-only and reversible with a one-line edit; the owner may revisit it."
  - "confirmation-resend gets its own payload-ignored class: its probe proves a payload email is ignored, not that an existing and an unknown address answer alike. Its note must keep 'payload' and 'email-keyed resend form'."
  - "The five parity rows are stated plainly: three account-existence probes (sign-in, magic-link request, password-reset request), one payload-ignored probe, one code-kind probe."
  - "The 'at least three of five' floor and the parity-or-not_proven tolerance were deleted outright, not kept as an alternative branch."

patterns-established:
  - "A shrinkable floor ('at least N') is replaced by a named-set check: the named ids minus the observed ids must be empty. Extra rows are allowed, a missing named row is not."
  - "A control that asserts 'the others stay same' also asserts how many others there are, so it cannot pass over an empty or tiny set."

requirements-completed: [BCOPY-03]

coverage:
  - id: D1
    description: "The named-surface rule requires password-signin, magic-link-request and password-reset-request to each be parity with a null blocker; a not_proven row with a valid path:line blocker is reported, and mfa-challenge or confirmation-resend cannot satisfy or substitute for them"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#every named surface is parity with no blocker, each judged in its own class"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#a not_proven account-existence surface with a valid blocker is reported (control)"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#the payload-ignored and code-kind rows never satisfy an account-existence surface (control)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The two separately counted classes keep their guard phrases: a confirmation-resend note that drops 'payload' or 'email-keyed resend form', an mfa-challenge note that drops 'code kind' or 'not account existence', and a registry missing any named id are each reported"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#a confirmation-resend note that drops a guard phrase is reported (control)"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#an mfa-challenge note that no longer says code kind is reported (control)"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#a registry missing a named id is reported as missing (control)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The positive control covers all five named surfaces: leaking any one yields exactly one diff at that id, and at least four other parity rows stay :same (no vacuous 'others stay same')"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#every parity surface can go red: leaking any one yields exactly that one diff"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#a leak on exactly one parity surface yields exactly one diff, the others stay :same"
        status: pass
    human_judgment: false
  - id: D4
    description: "The registry notes for mfa-challenge and confirmation-resend record the separate-counting decision, and the WR-08 residual is moved out of Decisions needed into a Resolved section of the deferred-findings todo"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "mix test test/sigra/brand (331 tests, 0 failures, includes name_clearance_test)"
        status: pass
      - kind: other
        ref: "awk range over '## Decisions needed' finds 0 WR-08 lines; 'counted separately' appears on exactly the mfa-challenge and confirmation-resend note lines"
        status: pass
    human_judgment: false

duration: ~3min (start epoch captured at executor start, after reading the plan)
completed: 2026-11-15
status: complete
---

# Phase 259 Plan 16: Named-surface rule tightened, mfa-challenge counted apart Summary

**The enumeration-parity test no longer lets any account-existence surface be not_proven, and counts mfa-challenge (code kind) and confirmation-resend (payload ignored) as separate classes through `named_surface_violations/1`, which judges every named id on its own and is proven able to fail by five planted controls.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-11-15T14:00:07Z
- **Completed:** 2026-11-15T14:03Z
- **Tasks:** 2 (both `auto`; Task 1 `tdd="true"`)
- **Files modified:** 3 (0 created, 3 modified)

## Accomplishments

- The tolerance that let the original shortfall pass is gone. The old test said each of five named surfaces may be parity or not_proven and that at least three must be parity, and it counted mfa-challenge toward that floor. Both the tolerance and the floor are deleted, not kept as an alternative branch.
- The five parity rows are now stated for what they are. Three are account-existence probes: `password-signin`, `magic-link-request`, `password-reset-request`. One is a payload-ignored probe: `confirmation-resend`. One is a code-kind probe: `mfa-challenge`. The verifier's observation that only sign-in and magic-link were genuine account probes is honoured: reset request is the third, and nothing else is counted as one.
- `named_surface_violations(by_id)` is a pure helper returning `"<id>: <what is wrong>"` strings. Each account-existence id is a violation when its row is missing, its state is not `parity`, or its blocker is not nil. The payload-ignored id adds a note guard on `payload` and `email-keyed resend form`. The code-kind id adds a note guard on `code kind` and `not account existence`. There is no total across ids, so a row of one class can never satisfy a requirement of another.
- Five planted controls (each builds its planted registry in memory over the real rows): a not_proven `password-reset-request` with a valid path:line blocker (the shape the old rule accepted), an mfa-only registry and a resend-only registry (every other named id reported, the lone parity row does not rescue it), a `confirmation-resend` note with each guard phrase removed in turn, an `mfa-challenge` note with each guard phrase removed in turn, and a registry missing each named id in turn.
- The positive control now asserts every named id is a parity row (`@named_parity_ids -- parity_ids == []`, extra parity rows allowed) and that leaking any one id leaves at least four other parity rows, all `:same`. The leak-yields-exactly-one-diff assertions are unchanged.
- Registry notes for `mfa-challenge` and `confirmation-resend` each gained one sentence saying the row is counted separately from the account-existence surfaces and can never satisfy or substitute for them. Existing sentences, state, compare list, todo and blocker are untouched. The ADR 006 mfa row already says identity is the code kind with status `bounded`, so it was left alone.
- The WR-08 residual is closed: the bullet moved from `## Decisions needed` to a new `## Resolved` H2 placed after the Info findings, with a pointer to this plan and a note that the classification is test-only and the owner may revisit it.

## Task Commits

1. **Task 1: Require every account-existence surface to be parity and count mfa-challenge separately** - `683649329` (test)
2. **Task 2: Record the counting decision where the registry and the todo restate it** - `a9da3bda4` (docs)

**Plan metadata:** the SUMMARY commit that follows this file, then a STATE/ROADMAP commit.

## TDD Evidence

**Task 1 RED, observed before the rule existed and committed together with GREEN (the plan makes Task 1 one commit).** The planted-control tests were written first against an inert stub `named_surface_violations(_by_id), do: []`. Run: 33 tests, 5 failures, and every failure was one of the five planted controls reporting `left: []` against an expected non-empty id list (the not_proven reset-request control, the resend/mfa-substitution control, the resend-note control, the mfa-note control and the missing-id control). The real-registry test passed against the stub, as it must, because an empty list is also what a correct registry yields. This RED was not run through `gsd_run check tdd-red-evidence` (ExUnit output is not a supported report format and the plan is `type: execute`).

**Task 1 GREEN:** with the real helper, 33 tests, 0 failures (28 at baseline, +5 net: the old single test became six).

**Mutation proof on the real fixture (reverted; `BASE=383c4e8a5`, restored from a backup copy, `git diff --quiet "$BASE" -- test/fixtures/brand/public-surfaces.json` exited 0 and `cmp` against the backup was identical):** flipping `password-reset-request` to `not_proven` with blocker `lib/sigra/lockout.ex:13` made "every named surface is parity with no blocker" red by name with both violations (`state is "not_proven" but a named surface must be parity`, `blocker is "lib/sigra/lockout.ex:13" but a parity row must have none`), and also made the positive control report `named surfaces that are not parity rows: ["password-reset-request"]`. Six further tests went red because the in-memory controls build on the real rows, which is expected and shows how widely the mutation is felt (8 failures in total).

### TDD Gate Compliance

Task 1 is `tdd="true"` but is one commit (tests plus rule together), so there is no separate `test(259-16)` RED commit followed by a `feat(259-16)` commit. The RED is the observed failing run above. The plan is `type: execute`, so no plan-level gate sequence is mandated. Flagged here rather than hidden.

## Files Created/Modified

- `test/example/test/example_web/enumeration_parity_test.exs` - `@account_existence_ids`, `@payload_ignored_ids`, `@code_kind_ids` with `@named_parity_ids` kept as their concatenation, the two note-phrase lists, `named_surface_violations/1` and `named_row_violations/3`, test helpers `downgrade/2`, `update_note/3`, `violated_ids/1`, six registry tests replacing one, strengthened positive control, moduledoc section "The five named surfaces"
- `test/fixtures/brand/public-surfaces.json` - one appended sentence on each of the `mfa-challenge` and `confirmation-resend` notes
- `.planning/todos/pending/2026-11-14-brand-harness-review-deferred-findings.md` - WR-08 residual moved to `## Resolved`

## Decisions Made

- Count mfa-challenge separately rather than remove or reclassify it. A wrong authenticator code versus a wrong backup code is a real pre-auth probe worth keeping green; removing it would drop a working probe and letting it count would repeat the over-claim. It is only barred from standing in for account-existence evidence.
- confirmation-resend is its own class for the same reason: its probe shows a payload email is ignored, not that an existing and an unknown address answer alike.
- The note guards for the two separate classes are phrase-based (`payload`, `email-keyed resend form`, `code kind`, `not account existence`). "counted separately" is recorded in the notes but is not itself guarded, because the plan fixes the guard phrases and Task 1 had to stay green before Task 2 edited the registry.

## Deviations from Plan

None - plan executed exactly as written.

One small in-file tightening beyond the listed edits, within the plan's intent ("delete the floor entirely") and not a deviation from any instruction: the test "no parity row passes as empty-versus-empty" carried its own `assert length(rows) >= 3` floor. It now asserts `@named_parity_ids -- Enum.map(rows, & &1["id"]) == []`, so no count floor remains in the file.

**Total deviations:** 0 auto-fixed.

## Issues Encountered

- `mix format --check-formatted` flagged the new test file after the first write (one over-long `refute` line). `mix format` was run from the repo root on that single file only, never inside `test/example`; the check then passed.
- The positive control's negative greps use `test -z "$(grep ...)"` (not `wc -l | grep -qx 0`, which false-negatives on darwin), and each was shown able to fail: the same `test -z` expression on a pattern that is present reports failure.

## Verification Results

| Check | Result |
|-------|--------|
| Parity suite, baseline before edits (`--include example_app`) | 28 tests, 0 failures |
| Parity suite after Task 1 and after Task 2 | 33 tests, 0 failures each |
| `mix test test/sigra/brand/name_clearance_test.exs` | 18 tests, 0 failures |
| `mix test test/sigra/brand` | 331 tests, 0 failures |
| Whole example suite (`--include example_app`) | 391 tests, 0 failures (386 at the end of Plan 259-15 plus the 5 net new) |
| Zero shipped bytes vs `62ef40442` (lib, priv, brandbook, brand, .github, scripts) | pass; control: 645 tracked shipped files exist, and a real diff makes the same `test -z` fail |
| Privacy gate (no `/Users/...` or `/home/...` in the diff outside the phase dir) | pass; control: planted path matched |
| `mix format --check-formatted` (repo root) | pass |
| Acceptance greps (Task 1) | `at least three of the five` = 0 (HEAD 1); `@account_existence_ids` = 3; `named_surface_violations` = 11; `parity or not_proven` absent (`test -z`) |
| Acceptance checks (Task 2) | `counted separately` on exactly the `mfa-challenge` and `confirmation-resend` note lines; `Identity = code kind, not account existence` still present; WR-08 with `resolved` on 1 line; WR-08 under Decisions needed = 0 (control: the same awk range sees WR-03 = 1); `git diff --name-only` over `.planning/todos/pending` prints exactly the one todo file |

## Known Stubs

None. The `STUB (RED step)` helper written during the RED run was replaced before the first commit; no stub reaches HEAD.

## Threat Flags

None. No `lib/` or `priv/` byte changed; the plan edits one test file, one test fixture and one planning todo.

## Handoff to later plans

- **259-17 / 259-18:** BCOPY-03 is declared by sibling plans 17 and 18 with no SUMMARY yet, so `requirements.ready-ids` is expected to hold it back; it is not marked complete here if a sibling still declares it.
- The classification of `mfa-challenge` and `confirmation-resend` is a one-line test edit if the owner wants a different call. The todo records that.

## Self-Check: PASSED

All three modified files exist; commits `683649329` and `a9da3bda4` are ancestors of HEAD (a planted bogus hash `deadbeef0` is reported MISSING).

---
*Phase: 259-compatibility-policy-pinned-source-and-copy-contract*
*Completed: 2026-11-15*
