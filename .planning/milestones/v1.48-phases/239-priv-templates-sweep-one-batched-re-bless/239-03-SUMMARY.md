---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 03
subsystem: testing
tags: [priv-templates, test-example, mirror, mix-ci, elixir]

requires:
  - phase: 239-02
    provides: "priv/templates/ swept to zero union-token lines across all 119 tracked templates (sweep commit cafd9a53); WAVE0-COMMIT baseline a1bb08c6 for lib/-touch verification"
provides:
  - "Commit 2 of the D-19 three-commit topology: test/example/ mirrored for the 30 counterparts of edited templates only (110 of 476 repo-wide token lines), leaving the deliberately-unswept remainder (~366 lines / ~64 files) for a future milestone"
  - "239-MIRROR-CHECKLIST.md: SC-4 per-file disposition table for all 46 edited templates (30 mirrored, 4 already-absent, 12 no-counterpart/injection-delivered)"
  - "239-EVIDENCE.md ## MIRROR-COMMIT + ## MIX-CI-RUNS sections: mirror-commit sha, mix ci run #1 (2606 tests, 0 failures, exit 0), and the cold-build Threadline diagnosis"
  - "A filed todo for a pre-existing, unrelated test/example compile-time warning (SettingsLive's dev-only ~p route)"
affects: ["239-04"]

actuals:
  tokens: 16801
  tasks: 3
  commits: 3
plan_head_before: 7a12e2e2

tech-stack:
  added: []
  patterns:
    - "Content-based mirroring: counterpart edits resolved by matching the swept template's post-sweep wording, never by line number, because generated-app counterparts are renderings with EEx-header offsets relative to their source templates"
    - "Trailing evidence-recording commit: a commit cannot honestly record its own not-yet-created child commit's sha or not-yet-run test results, so the sha+results recording lands in a small commit AFTER the artifact/mirror commits it describes — same resolution 239-01 and 239-02 used for their own WAVE0-COMMIT/SWEEP-COMMIT sections"
    - "Cold-_build diagnosis over blind re-run: when Sigra.Audit.Forwarders.Threadline's Code.ensure_compiled/1 guard races threadline's own compile in the same run, the fix is `mix compile --force` once (deterministic priming) before citing a `mix ci` result, not silently re-running until green"

key-files:
  created:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-MIRROR-CHECKLIST.md
    - .planning/todos/pending/2026-09-17-example-settings-live-dev-mailbox-verified-route-test-env.md
  modified:
    - test/example/lib/example_web/user_auth.ex
    - test/example/lib/example_web/live/organization_members_live.ex
    - test/example/lib/example/organizations.ex
    - test/example/lib/example_web/live/organization_settings_live.ex
    - test/example/test/support/fixtures/auth_fixtures.ex
    - test/example/lib/example/accounts/emails.ex
    - test/example/lib/example_web/live/mfa_settings_live.ex
    - test/example/priv/static/assets/sigra_auth.css
    - test/example/lib/example/accounts.ex
    - test/example/lib/example_web/live/organizations_live/index.ex
    - test/example/lib/example/accounts/audit_event.ex
    - test/example/lib/example_web/live/mfa_challenge_live.ex
    - test/example/lib/example_web/live/reset_password_live.ex
    - test/example/lib/example_web/controllers/reset_password_controller.ex
    - test/example/lib/example_web/controllers/organization_switch_controller.ex
    - test/example/lib/example/accounts/scope.ex
    - test/example/lib/example_web/live/invitation_accept_live.ex
    - test/example/lib/example_web/components/org_switcher.ex
    - test/example/lib/example/accounts/organization.ex
    - test/example/lib/example_web/live/registration_live.ex
    - test/example/lib/example_web/live/confirmation_live.ex
    - test/example/lib/example_web/controllers/reset_password_html.ex
    - test/example/lib/example_web/controllers/auth/sudo_controller.ex
    - test/example/lib/example_web/controllers/auth/sudo_html.ex
    - test/example/lib/example/accounts/user.ex
    - test/example/lib/example/accounts/user_token.ex
    - test/example/assets/js/admin_hooks.js
    - test/example/lib/example_web/controllers/session_html.ex
    - test/example/lib/example_web/live/organizations_live/new.ex
    - test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md

key-decisions:
  - "Resolved the plan's temporal-ordering tension (a commit cannot record its own not-yet-created child commit's sha) via a trailing evidence-recording commit, exactly as 239-01/239-02 resolved the identical problem for WAVE0-COMMIT/SWEEP-COMMIT — the mirror commit (e69f4d9b) itself is entirely test/example/-scoped and its immediate parent (df04e43a) is the .planning/-scoped checklist commit, satisfying the plan's core intent; the sha+mix-ci-results recording follows in a third, also .planning/-scoped commit."
  - "Diagnosed rather than silently re-ran mix ci's first cold-build failure (6 Threadline UndefinedFunctionErrors) to a build-ordering race in Code.ensure_compiled/1, confirmed lib/ untouched by this phase, then re-ran clean after mix compile --force -- documented both the failure and its resolution in the evidence ledger rather than citing only the final green run."
  - "Documented, rather than acted on, the discovery that mix ci's :scaffold-tag exclusion leaks into the same-VM ci.install_golden invocation -- this plan's mix ci run #1 is valid evidence for its own scope but is explicitly NOT cited as proof of golden-fixture drift state, which remains plan 239-04's job."
  - "Left the pre-existing test/example ~p\"/dev/mailbox\" compile warning (SettingsLive, gated behind dev-only dev_routes config) unfixed and filed it as a todo instead, per the v1.48 standing constraint and because settings_live.ex is one of this plan's four already-absent counterparts."

requirements-completed: []

coverage:
  - id: D1
    description: "Task 1 tracer: user_auth.ex mirrored end-to-end (mapping via manifest grep, 7 content-matched rewrites, mix format, MIX_ENV=test compile --warnings-as-errors), proving the mirror pattern before expansion"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-03-PLAN.md Task 1 <verify> blocks 2-3 (union-grep zero, phrase survival, mix format) — re-run against final tree state"
        status: pass
      - kind: other
        ref: "239-03-PLAN.md Task 1 <verify> block 4 (MIX_ENV=test mix compile --warnings-as-errors inside test/example)"
        status: fail
    human_judgment: true
    rationale: "The compile check fails on one pre-existing, unrelated warning (SettingsLive's dev-only ~p\"/dev/mailbox\" route, absent under MIX_ENV=test) confirmed via git stash against unmodified HEAD before any of this plan's edits existed. A human should confirm the todo filed for it (df04e43a) is the correct resolution rather than an in-phase fix, per the v1.48 standing constraint."
  - id: D2
    description: "Task 2: the remaining 29 counterparts mirrored (30 non-zero-row files modified total including the tracer), 239-MIRROR-CHECKLIST.md written disposing all 46 edited templates (30 mirrored / 4 already-absent / 12 no-counterpart), repo-wide test/example/ union count confirmed at 366 (>0, <400)"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-03-PLAN.md Task 2 <verify> blocks 1-2 (counterpart file count + zero-hits, repo-wide bounds) and block 3 (checklist row/na/injection/476 assertions) — re-run against final tree state"
        status: pass
      - kind: other
        ref: "239-03-PLAN.md Task 2 <verify> block 4 (mix format --check-formatted repo-wide)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Task 3: the mirror commit (e69f4d9b) is entirely test/example/-scoped with the checklist commit (df04e43a) as its immediate parent; .github/ zero-diff confirmed; mix ci run #1 captured green (2606 tests, 0 failures, exit 0) after diagnosing and resolving a cold-build ordering artifact; evidence ledger records both sections with the required Status: lines"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-03-PLAN.md Task 3 <verify> blocks 1-2 (Postgres reachability, commit path-scope + .github/ diff) — re-run against commit e69f4d9b specifically"
        status: pass
      - kind: other
        ref: "239-03-PLAN.md Task 3 <verify> block 3 (mix ci ExUnit summary + no non-golden failure) and block 4 (evidence ledger headings/Status lines) — re-run against final HEAD"
        status: pass
    human_judgment: true
    rationale: "Final HEAD after this plan (0f24144c, the evidence-recording commit) is NOT the mirror commit itself, because the plan's own instruction to record a not-yet-created commit's sha and not-yet-run mix ci results inside a commit that must PRECEDE that commit is temporally impossible. This was resolved via the established 239-01/239-02 trailing-commit precedent, and the mirror commit's own path-scope/.github/ assertions were verified directly against its own sha (e69f4d9b) rather than against final HEAD. A human should confirm this resolution is faithful to the plan's actual intent (an honestly-scoped, unpolluted mirror commit) rather than a scope violation."

duration: 95min
completed: 2026-09-17
status: complete
---

# Phase 239 Plan 03: test/example/ Mirror of the priv/templates/ Sweep Summary

**Mirrored plan 239-02's 158-line planning-bookkeeping sweep into the 30 test/example/ counterparts of edited templates (110 of 476 repo-wide token lines), producing a per-file SC-4 disposition checklist and a green `mix ci` run #1 after diagnosing a cold-build Threadline ordering artifact.**

## Performance

- **Duration:** ~95 min
- **Started:** 2026-09-17
- **Completed:** 2026-09-17
- **Tasks:** 3 completed
- **Files modified:** 30 test/example files + 1 evidence ledger + 1 new checklist + 1 new todo

## Accomplishments

- Task 1 (tracer): proved the whole mirror pattern end-to-end on `user_auth.ex` — confirmed the
  manifest mapping (`{:eex, "core/user_auth.ex", ...}` -> `lib/example_web/user_auth.ex`),
  content-matched all 7 union-token lines to their swept template's post-sweep wording (the
  `@user_organizations` socket-assign comment and the `require_mfa` doc line both lose their
  bookkeeping prefixes while keeping their descriptions), ran `mix format`, and compiled the
  example app with warnings as errors.
- Discovered during Task 1's compile check that `test/example`'s `SettingsLive` renders a
  `~p"/dev/mailbox"` verified route that only exists when `config/dev.exs`'s `dev_routes` flag is
  compile-time true — absent under `MIX_ENV=test`, so `mix compile --warnings-as-errors` inside
  `test/example` has always failed on this one pre-existing warning, previously undetected because
  no `mix ci` step compiles `test/example` directly with that flag. Confirmed via `git stash`
  reproducing the identical warning against unmodified HEAD (`7a12e2e2`). Filed as a todo rather
  than fixed in-phase (v1.48 standing constraint; `settings_live.ex` is also one of this plan's
  four already-absent counterparts).
- Task 2: mirrored the remaining 29 counterparts (18-line `organization_members_live.ex` down to
  9 single-line files), resolving all edits by content against the swept templates — including the
  4 D-21 renamed-counterpart mappings (`core/login_html.ex` -> `session_html.ex`, `core/auth.ex`
  -> `lib/example/accounts.ex`, and the two timestamped migrations) taken from the authoritative
  manifest, not re-derived by basename. Deleted 5 whole HEEx/plain-comment lines whose templates
  removed the comment entirely rather than rewording it (matching the D-12 pattern from 239-02).
  Left the 4 already-zero-token counterparts completely untouched.
- Wrote `239-MIRROR-CHECKLIST.md`: one row per all 46 edited templates, disposed as 30 mirrored
  (with mirrored line counts summing to 110), 4 `n/a — already absent`, and 12 `no counterpart
  (delivered by injection)`, plus the 476-vs-110 scoping paragraph.
- Verified: all 30 modified counterparts return zero union-token hits; repo-wide `test/example/`
  count is 366 (>0, proving no over-reach into the unswept remainder; <400, proving the
  counterparts were genuinely swept); `mix format --check-formatted` passes repo-wide; the four
  zero-token counterparts are confirmed byte-unmodified.
- Task 3: landed the D-19 commit-2 topology as two ordered commits — `df04e43a` (`.planning/`:
  checklist + the filed todo) then `e69f4d9b` (the mirror, `test/example/` only, 30 files,
  parent = `df04e43a`) — and confirmed `git show --name-only --format= e69f4d9b` lists exactly 30
  paths all under `test/example/`, and `.github/` is zero-diff against `origin/main`.
- Ran `mix ci` run #1. First invocation reported 6 spurious `Sigra.Audit.Forwarders.Threadline`
  failures — diagnosed as a cold-`_build` ordering race (the module's own `Code.ensure_compiled/1`
  guard evaluates before `threadline`'s same-run compile finishes) rather than a code fault,
  confirmed via `git log a1bb08c6..HEAD -- lib/` being empty (no `lib/` change this phase could
  have caused it). Re-ran clean after `MIX_ENV=test mix compile --force`: **2606 tests, 0
  failures, exit 0**, including `ci.install_golden`'s 65-test pass and the `sigra.dep_off` guard
  script's clean self-test + restore. Also discovered and documented that `mix ci`'s
  `test --exclude scaffold` step leaks its `:excluded_tags` filter into the same-VM
  `ci.install_golden` invocation, so `golden_diff_test.exs` (tagged `:scaffold`) did not actually
  execute inside this run — recorded explicitly so this green run is never miscited as proof of
  golden-fixture drift state (that remains plan 239-04's job).
- Recorded both results in `239-EVIDENCE.md` under new `## MIRROR-COMMIT` and `## MIX-CI-RUNS`
  headings, in a third, `.planning/`-scoped commit (`0f24144c`) — the only way to honestly record
  a commit's own sha and not-yet-run test results without contradicting the parent-then-mirror
  ordering the plan itself specifies (see Deviations).

## Task Commits

1. **Task 1 & 2 (checklist + mirror, no commit in Task 1/2 per plan's Task-3-owns-all-commits
   instruction)**: staged but not committed until Task 3.
2. **Task 3, commit 1 of 2 (`.planning/` checklist + filed todo)** — `df04e43a` (docs)
3. **Task 3, commit 2 of 2 (the `test/example/` mirror)** — `e69f4d9b` (refactor)
4. **Task 3 follow-up (evidence ledger: mirror-commit sha + mix ci run #1)** — `0f24144c` (docs)

_Note: as in 239-01 and 239-02, the evidence-recording step for a commit's own sha and its
downstream `mix ci` results necessarily lands in a small trailing commit, since neither can be
known before that commit exists / those tests run._

## Files Created/Modified

- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-MIRROR-CHECKLIST.md` — SC-4
  per-file disposition table for all 46 edited templates
- `.planning/todos/pending/2026-09-17-example-settings-live-dev-mailbox-verified-route-test-env.md`
  — filed todo for the pre-existing `~p"/dev/mailbox"` compile warning
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md` — new
  `## MIRROR-COMMIT` and `## MIX-CI-RUNS` sections
- 30 files under `test/example/` — see `key-files.modified` in the frontmatter for the full list

## Decisions Made

See `key-decisions` in the frontmatter above.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's Task 3 commit-topology instruction creates a temporal-ordering
impossibility: a commit cannot record its own not-yet-created child commit's sha, nor
not-yet-run `mix ci` results**
- **Found during:** Task 3, while assembling the `.planning/` commit's content per the action's
  literal instruction ("The `.planning/` artifacts go first... and the `239-EVIDENCE.md`
  updates... [including] the commit sha[and mix ci results]").
- **Issue:** The plan specifies committing `239-EVIDENCE.md` updates (containing the mirror
  commit's own sha and `mix ci` run results) in the FIRST of the two commits, whose child is the
  mirror commit itself — but neither the sha nor the mix-ci results exist yet at that point.
  Literally satisfying both "commit 1 contains the final evidence content" and "commit 1 precedes
  the commit whose sha it records" is impossible.
- **Fix:** Split into three commits instead of two, following the exact precedent 239-01's Task 3
  and 239-02's Task 3 already established for the identical problem (WAVE0-COMMIT / SWEEP-COMMIT
  sha-recording): commit 1 (`df04e43a`) carries only `239-MIRROR-CHECKLIST.md` + the filed todo;
  commit 2 (`e69f4d9b`) is the mirror, entirely `test/example/`-scoped, with commit 1 as its
  parent — satisfying the plan's core intent (mirror commit clean of `.planning/` noise, checklist
  committed first); commit 3 (`0f24144c`) records the now-known sha and `mix ci` results.
  Verified the mirror commit's own path-scope and `.github/`-diff assertions directly against its
  sha (`e69f4d9b`), matching what the plan's assertion text actually describes ("the mirror did
  not escape `test/example/`"), rather than against final HEAD (which is the trailing evidence
  commit).
- **Files modified:** `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md`
  (new commit rather than folded into commit 1)
- **Verification:** `git show --name-only --format= e69f4d9b` lists exactly 30 paths, all under
  `test/example/`; `git diff --name-only origin/main -- .github/` empty; `e69f4d9b`'s parent is
  `df04e43a` (`git log --oneline -1 e69f4d9b^` confirms).
- **Committed in:** `df04e43a`, `e69f4d9b`, `0f24144c`

**2. [Rule 1 - Bug] First `mix ci` run reported 6 spurious `Sigra.Audit.Forwarders.Threadline`
failures unrelated to this phase**
- **Found during:** Task 3, running `mix ci` run #1 for the first time this session.
- **Issue:** `Sigra.Audit.Forwarders.Threadline`'s module definition is gated behind
  `Code.ensure_compiled(Threadline) == {:module, Threadline}`. On this session's cold `_build`,
  `threadline` (an optional dependency) compiled in the same run as `sigra`, so the guard evaluated
  before `threadline` was available and the module was never defined, producing 6
  `UndefinedFunctionError` failures in `test/sigra/audit/forwarders/threadline_test.exs`.
- **Fix:** Diagnosed as a build-ordering artifact (confirmed `git log a1bb08c6..HEAD -- lib/` is
  empty — no `lib/` change in this phase touches this code path), then ran `MIX_ENV=test mix
  compile --force` once to deterministically prime `_build`, then re-ran `mix ci`.
- **Files modified:** none (build-artifact only, no source change)
- **Verification:** re-run `mix ci` after `mix compile --force`: 2606 tests, 0 failures, exit 0.
- **Committed in:** n/a (no source change; diagnosis and result recorded in `239-EVIDENCE.md`,
  commit `0f24144c`)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — a plan-sequencing defect and a cold-build test
artifact, neither a template/example source regression).
**Impact on plan:** none on the actual deliverable — the mirror is genuinely scoped to the 30
counterparts, the checklist is honest about all 46 templates' dispositions, and `mix ci` run #1 is
authoritatively green. The impact is confined to (a) which of three commits the evidence-ledger
content lands in, and (b) one build-ordering artifact that self-resolved with a standard
`mix compile --force`.

## Issues Encountered

- `mix ci`'s `test --exclude scaffold` step leaks its `:excluded_tags` filter into the same-VM
  `ci.install_golden` invocation, so `golden_diff_test.exs` (tagged `:scaffold`) did not actually
  execute its assertions inside this run's `ci.install_golden` pass. This is documented explicitly
  in `239-EVIDENCE.md` so the green run #1 is never miscited as evidence about golden-fixture
  drift state — that verification is plan 239-04's job (the re-bless commit).

## Authentication Gates

None — this plan used only `bash`, `python3`, `git`, `mix`, and a local Dockerized Postgres
(`scripts/db/up.sh`), all already available/documented in the environment.

## Next Phase Readiness

Plan 239-04 (the batched re-bless / commit 3) can begin: `priv/templates/` carries zero
planning-bookkeeping tokens (239-02), the 30 direct `test/example/` counterparts are mirrored and
consistent with the swept templates (this plan), `239-MIRROR-CHECKLIST.md` gives 239-04's
downstream reviewer the full 46-template disposition table plus the FUT-01 diagnosis material
(the 4 already-absent counterparts and 12 no-counterpart templates), and `mix ci` run #1 is
recorded green with the `:scaffold`-leak caveat spelled out so 239-04 knows its own golden-fixture
verification must run `golden_diff_test.exs` in a context where `:scaffold` is not excluded.
SURF-01 and SURF-03 remain `Pending` in `REQUIREMENTS.md` by design — SURF-03 is shared across
239-01/02/03/04 and the shared-ID gate correctly withholds marking it `Complete` until plan 04's
`SUMMARY.md` also exists.

## Self-Check: PASSED

- `[ -f ]` confirmed for `239-MIRROR-CHECKLIST.md`, the filed todo, and all 30 modified
  `test/example/` files.
- `git log --oneline --all | grep -q df04e43a`, `e69f4d9b`, and `0f24144c` — all three found.
- Re-ran every task's acceptance-criteria-backing check against the final committed state: all
  pass except the two `human_judgment: true` items documented above (the pre-existing compile
  warning's todo-filing, and the trailing-commit resolution of the plan's temporal-ordering
  defect) — both are `human_judgment: true` in the coverage block above, not silently passed.
- Re-ran the plan-level `<verification>` section: all edited counterparts zero union-token hits,
  repo-wide count 366 (bounds satisfied) — confirmed; `239-MIRROR-CHECKLIST.md` disposes all 46
  templates — confirmed; `mix format --check-formatted` passes repo-wide, example app compiles
  with warnings as errors except the one documented pre-existing warning — confirmed; commit 2's
  paths (checked against `e69f4d9b` specifically) are entirely under `test/example/`, `.planning/`
  artifacts land in the immediately preceding commit (`df04e43a`), `.github/` unchanged from
  `origin/main` — confirmed.
