---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 02
subsystem: templates
tags: [priv-templates, mix-sigra-install, security-comments, heex, code-hygiene]

requires:
  - phase: 239-01
    provides: "239-comment-only-diff-check.sh classifier, 239-golden-expected.txt frozen baseline, WAVE0-COMMIT sha (a1bb08c6) as the pre-sweep baseline"
provides:
  - "Commit 1 of the D-19 three-commit topology: priv/templates/ swept to zero union-token lines across all three generators (sigra.install/, sigra.upgrade/, sigra.gen.oauth/)"
  - "239-EVIDENCE.md ## SWEEP-COMMIT section: sweep commit sha, before/after counts (158 -> 0), and a documented analysis of the one unavoidable SC-5b instrument false positive"
affects: ["239-03", "239-04"]

actuals:
  tokens: 19000
  tasks: 3
  commits: 3
plan_head_before: 5096a1facbe3e85fc4ba2803cd67ddcc50da8310

tech-stack:
  added: []
  patterns:
    - "When a rewrite must remove a bookkeeping token that shares a physical line with a rationale word SC-5b's tolerance regex doesn't recognize, no rewording can satisfy both the union-token grep and SC-5b — this is a same-line-only conflict; when the token and rationale word sit on adjacent lines instead, leave the rationale line untouched and edit only the token line, which keeps that line out of SC-5b's removed-line set entirely."
    - "Treat comment BLOCKS (not lines) as the edit unit for any bookkeeping token that wraps across a physical line boundary (moduledoc list items, migration comment pairs, wrapped @doc parentheticals)."

key-files:
  modified:
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/auth_fixtures.ex
    - priv/templates/sigra.install/core/mfa_challenge_controller.ex
    - priv/templates/sigra.install/core/reset_password_controller.ex
    - priv/templates/sigra.install/core/scope.ex
    - priv/templates/sigra.install/core/user_auth.ex
    - priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
    - priv/templates/sigra.install/organizations/live/organization_members_live.ex
    - priv/templates/sigra.install/organizations/live/organization_settings_live.ex
    - priv/templates/sigra.install/organizations/migration.exs
    - priv/templates/sigra.install/organizations/organization_invitation_email.ex
    - priv/templates/sigra.install/organizations/organizations.ex
    - priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex
    - priv/templates/sigra.install/core/settings_live.ex
    - priv/templates/sigra.install/core/mfa_challenge_live.ex
    - priv/templates/sigra.install/core/mfa_settings_live.ex
    - priv/templates/sigra.install/core/mfa_challenge_html.ex
    - priv/templates/sigra.install/core/mfa_settings_html.ex
    - priv/templates/sigra.install/core/reset_password_live.ex
    - priv/templates/sigra.install/core/sigra_auth.css
    - priv/templates/sigra.install/core/audit_event.ex
    - priv/templates/sigra.install/core/emails.ex
    - priv/templates/sigra.install/core/login_html.ex
    - priv/templates/sigra.install/core/error_handler.ex
    - priv/templates/sigra.install/core/confirmation_live.ex
    - priv/templates/sigra.install/core/registration_live.ex
    - priv/templates/sigra.install/core/user.ex
    - priv/templates/sigra.install/core/user_token.ex
    - priv/templates/sigra.install/core/sudo_controller.ex
    - priv/templates/sigra.install/core/sudo_html.ex
    - priv/templates/sigra.install/core/reset_password_html.ex
    - priv/templates/sigra.install/core/token_controller.ex
    - priv/templates/sigra.install/core/api_token_created_email.ex
    - priv/templates/sigra.install/core/migration.exs
    - priv/templates/sigra.install/organizations/organization.ex
    - priv/templates/sigra.install/organizations/organization_invitation.ex
    - priv/templates/sigra.install/organizations/router_injection.ex
    - priv/templates/sigra.install/organizations/components/org_switcher.ex
    - priv/templates/sigra.install/organizations/live/organizations_live/index.ex
    - priv/templates/sigra.install/organizations/live/organizations_live/new.ex
    - priv/templates/sigra.install/admin/admin_hooks.js
    - priv/templates/sigra.upgrade/data_migration.exs
    - priv/templates/sigra.upgrade/alter_add_personal.exs
    - priv/templates/sigra.upgrade/alter_add_owner_user_id.exs
    - priv/templates/sigra.gen.oauth/oauth_settings_live.ex
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md

key-decisions:
  - "Task 1's exclusive files (core/auth.ex, core/reset_password_controller.ex, organizations/controllers/organization_switch_controller.ex) needed more edits than the 10-line same-line table alone — they carry additional union-token lines not visited by any later task, so Task 1 was extended to fully zero those three files rather than leaving residue for a task that never revisits them."
  - "For the organization_settings_live.ex ':21 (D-04), not 403.' window merge, left the 'enumeration safety' line completely untouched and edited only the adjacent token line (using an em dash instead of a merged comma) — this kept the rationale-bearing line out of SC-5b's removed-line set entirely, avoiding a second avoidable false positive."
  - "The one core/auth.ex:530 SC-5b false positive is structurally unavoidable (documented in 239-EVIDENCE.md ## SWEEP-COMMIT) and was accepted rather than worked around by editing the checker script, per D-16."

requirements-completed: []

coverage:
  - id: D1
    description: "Task 1: the 10 same-line D-17 co-occurrence rewrites applied, plus full resolution of the remaining union-token lines in the three Task-1-exclusive files (auth.ex, reset_password_controller.ex, organization_switch_controller.ex), each verified against the SC-5b instrument on a partial diff"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-02-PLAN.md Task 1 <verify> blocks 2-3, re-run against final tree state"
        status: pass
      - kind: other
        ref: "239-02-PLAN.md Task 1 <verify> block 1 (SC-5b on partial diff)"
        status: fail
    human_judgment: true
    rationale: "Block 1's SC-5b check on the partial diff structurally cannot pass for core/auth.ex:530 (documented false positive, see Deviations) — a human should confirm the accepted rationale is sound before this plan's SURF-03 contribution is treated as fully satisfied."
  - id: D2
    description: "Task 2: 127 plain strips + 21 window rewrites applied across 34 files; union grep reduced to exactly the 17 Task-3 HEEx lines; all four D-03 exclusions intact; scope confined to priv/templates/"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "239-02-PLAN.md Task 2 <verify> blocks 1-3 (union-grep ceiling, .planning/ absence, D-03 survival)"
        status: pass
      - kind: other
        ref: "239-02-PLAN.md Task 2 <verify> block 4 (git diff --name-only scoped to priv/templates)"
        status: fail
    human_judgment: true
    rationale: "Block 4 flags a pre-existing, unrelated uncommitted change to .planning/state.json present in the working tree before this plan started (visible in the session's initial git status) — not caused by this plan's edits, and never staged into the sweep commit. A human should confirm this is pre-existing drift, not scope creep."
  - id: D3
    description: "Task 3: the 17 D-12 EEx-escaped HEEx comment lines deleted whole across 7 files; balanced <%%/%> delimiters confirmed; union grep zero across 119 tracked template files; the single scoped sweep commit lands with commit-level scope assertion and .github/ zero-diff; MIX_ENV=test mix compile --warnings-as-errors clean"
    requirement: SURF-01
    verification:
      - kind: other
        ref: "239-02-PLAN.md Task 3 <verify> blocks 1-2, 4-5, re-run against committed HEAD"
        status: pass
      - kind: other
        ref: "239-02-PLAN.md Task 3 <verify> block 3 (SC-5b on full sweep-commit diff)"
        status: fail
    human_judgment: true
    rationale: "Block 3 fails for the identical documented core/auth.ex:530 reason as D1 — an instrument tolerance-regex gap, not a template regression. Human confirmation of the analysis in 239-EVIDENCE.md ## SWEEP-COMMIT is the appropriate closing step since D-16 forbids fixing the instrument itself."

duration: 70min
completed: 2026-09-17
status: complete
---

# Phase 239 Plan 02: priv/templates/ Bookkeeping Sweep (Commit 1 of 3) Summary

**Swept all 158 planning-bookkeeping token lines out of 46 files across `priv/templates/`'s three generators in one scoped commit, driving the union-token grep to zero across all 119 tracked templates while preserving every rationale sentence and all five D-03 deliberate exclusions.**

## Performance

- **Duration:** ~70 min
- **Started:** 2026-09-17
- **Completed:** 2026-09-17
- **Tasks:** 3 completed
- **Files modified:** 46 templates + 1 evidence ledger

## Accomplishments

- Applied the full D-17 rewrite ledger: 10 same-line co-occurrence rewrites (Task 1) plus 21
  window-case rewrites (Task 2) — every rationale sentence (`enumeration prevention`, `XSS
  defense`, `phishing defense`, `last-owner guard`, `membership-before-write`,
  `at-most-one-personal-org-per-user`, etc.) survives with its bookkeeping token gone.
- Discovered and closed a plan-scope gap: `core/auth.ex`, `core/reset_password_controller.ex`,
  and `organizations/controllers/organization_switch_controller.ex` are Task-1-exclusive (no
  later task revisits them), but carried union-token lines beyond the 10-line table (e.g.
  `auth.ex:409` `10.1 IN-05`, `auth.ex:508` `Per D-29`, `reset_password_controller.ex:53/61`,
  `organization_switch_controller.ex:5-6` two-line block merge). Extended Task 1 to fully zero
  these three files rather than leaving residue no other task would catch.
- Stripped the remaining 127 plain-bookkeeping lines and the one dead `.planning/` URL
  (`organizations/organizations.ex:59-60`) across 34 files in Task 2, including the
  heaviest files first per `239-RESEARCH.md` §2.1 ordering
  (`organization_members_live.ex` 19 hits, `organizations/migration.exs` 13,
  `organizations.ex` 11, `organization_settings_live.ex` 11, `auth_fixtures.ex` 8,
  `user_auth.ex` 7, `sigra_auth.css` 7, `organizations_live/index.ex` 6, plus 26 more files
  with 1-4 hits each).
- Deleted the 17 D-12 EEx-escaped HEEx comment lines whole across 7 files
  (`settings_live.ex`, `mfa_challenge_live.ex`, `mfa_settings_live.ex`, `mfa_challenge_html.ex`,
  `mfa_settings_html.ex`, `reset_password_live.ex`, `organization_settings_live.ex`), verified
  `<%%`/`%>` delimiters stay balanced in every file (no orphaned opener).
- Union grep over `git ls-files priv/templates` (119 tracked files) returns **0** lines — down
  from 158. Verified across all three generators (`sigra.install/`, `sigra.upgrade/`,
  `sigra.gen.oauth/`).
- All five D-03 deliberate exclusions confirmed intact verbatim: `policy.ex` `TODO:`,
  `mfa_challenge_live.ex` `XXXX-XXXX` placeholder, `sigra_auth.css` v1.46 compat prose,
  `scope.ex` `UPGRADE-v1.2.md` pointer, and arity/version strings throughout.
- Landed the single scoped sweep commit (`cafd9a53`): 46 files changed, every path under
  `priv/templates/`, `.github/` shows zero diff against `origin/main`,
  `MIX_ENV=test mix compile --warnings-as-errors` clean.
- Recorded the sweep in `239-EVIDENCE.md` under `## SWEEP-COMMIT` (separate `.planning/`-scoped
  commit `2b362456`, permitted by this plan's D-19 scope discipline alongside the priv/templates
  commit), including a full written analysis of the one unavoidable SC-5b instrument false
  positive (see Deviations below).

## Task Commits

1. **Task 1 & 2 (no commit — plan-specified deferral)**: all edits land in the single Task 3
   sweep commit per D-19 ("Do not commit in this task; commit 1 lands at the end of Task 3 as a
   single sweep commit").
2. **Task 3: the priv/templates/ sweep** — `cafd9a53` (refactor)
3. **Task 3: record the sweep in the evidence ledger** — `2b362456` (docs)

**Plan metadata:** committed separately below.

## Files Created/Modified

46 files under `priv/templates/sigra.install/`, `priv/templates/sigra.upgrade/`, and
`priv/templates/sigra.gen.oauth/` — see `key-files.modified` in the frontmatter for the full
list. Plus `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md`
(new `## SWEEP-COMMIT` section).

**Content-change callout (not scope creep):** `organizations/organizations.ex:65,75,85,99` are
`@doc "…"` one-liners that render in an adopter's own IEx/ExDoc — rewording them to drop `D-10`,
`D-11`, `D-18` is a small adopter-visible content change, not a pure comment strip, exactly as
`239-02-PLAN.md` flagged in advance.

## Decisions Made

- Extended Task 1's edit scope to the full extent of its three exclusive files (see key-decisions
  above) rather than leaving residual tokens for tasks that never revisit those files.
- For the `organization_settings_live.ex` D-04 window case, chose to leave the rationale-bearing
  line byte-identical and edit only the adjacent token line (em dash instead of a merged comma),
  which incidentally also kept that line out of the SC-5b instrument's removed-line set — a
  second, avoidable false positive was closed this way during execution.
- Accepted the one remaining `core/auth.ex:530` SC-5b false positive rather than reword around it
  further (no rewording exists that satisfies both instruments — see Deviations) or edit the
  checker script (forbidden by D-16).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's Task 1 file scope was incomplete: three Task-1-exclusive files carried
union-token lines beyond the documented 10-line same-line table**
- **Found during:** Task 1, after applying the 10 documented rewrites and running the union grep
  over `core/auth.ex`, `core/reset_password_controller.ex`, and
  `organizations/controllers/organization_switch_controller.ex` in isolation.
- **Issue:** These three files appear ONLY in Task 1's `<files>` list (Task 2's file list omits
  them), yet at HEAD they carried 6 additional union-token lines never covered by any table in
  the plan: `auth.ex:409` (`10.1 IN-05`), `auth.ex:508` (`Per D-29`), `auth.ex:532` (`(D-29)` —
  actually documented in the *Task 2* window-case table despite the file being Task-1-exclusive),
  `reset_password_controller.ex:53` (`(D-29)`), `reset_password_controller.ex:61`
  (`10.1 IN-03:`), and `organization_switch_controller.ex:5-6` (a `D-05 / ORG-UX-03` two-line
  block). Left unresolved, Task 3's zero-union-grep gate over all `priv/templates/` would have
  failed with residue in files no later task visits.
- **Fix:** Extended Task 1 to fully clear these three files: applied `auth.ex:532`'s
  documented AFTER text (moved there from the Task 2 window-case table since the file itself is
  Task-1-only), and applied plain strips to the remaining five lines, preserving each sentence's
  meaning.
- **Files modified:** `priv/templates/sigra.install/core/auth.ex`,
  `priv/templates/sigra.install/core/reset_password_controller.ex`,
  `priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex`
  (plus `organization_invitation_email.ex:1`, a similar one-line residue in a file shared with
  Task 2, closed early for the same reason).
- **Verification:** Re-ran the union grep over the three exclusive files after the fix — zero
  hits. Re-ran Task 1's block 2 and block 3 `<verify>` commands — both pass.
- **Commit:** Folded into the single sweep commit `cafd9a53` (per D-19, Task 1/2 produce no
  standalone commit).

**2. [Rule 1 - Bug] A second SC-5b instrument false positive was found and closed during Task 2's
window-case rewrite of `organization_settings_live.ex:21`**
- **Found during:** Task 3's pre-commit SC-5b dry run against the full working-tree diff.
- **Issue:** The plan's documented AFTER for `:21` ("merge into the preceding line so the sentence
  reads `Non-members receive 404 for enumeration safety, not 403.`") requires touching the
  preceding line (which contains the class word "enumeration"), which unavoidably marks that
  line's HEAD text as removed in the diff, tripping SC-5b's `enumeration` + no-recognized-token
  rule (the token, `D-04`, was on the *following* line at HEAD, not the same line).
- **Fix:** Left the "enumeration safety" line byte-identical to HEAD (untouched — pure context in
  the diff) and edited only the following line, replacing `(D-04), not 403.` with `— not 403.`
  This keeps the semantic outcome the plan specified while avoiding the false positive.
- **Files modified:** `priv/templates/sigra.install/organizations/live/organization_settings_live.ex`
- **Verification:** Re-ran the full-sweep SC-5b dry run before committing — this specific line no
  longer appears as a survivor (confirmed by diffing the before/after SC-5b output).
- **Commit:** `cafd9a53`

### Accepted Instrument Limitation (not a template defect)

**`237-security-comment-diff-check.sh` (SC-5b) reports exactly one survivor against this plan's
full sweep-commit diff: `core/auth.ex:530`.** This is fully documented with a three-way repro
(isolated single-file diff, six-file partial diff, full sweep-commit diff — all three report the
identical single survivor) in `239-EVIDENCE.md` under `## SWEEP-COMMIT`. Root cause: SC-5b's
tolerance regex recognizes only `D-[0-9]{2}`, `SC-[0-9]+`, and `Phase [0-9]{1,3}` co-occurring
with a rationale word on the *same removed line* — it does not recognize `IN-[0-9]{2}`. Unified
diff is line-granular, so any edit to `auth.ex:530` necessarily marks the current HEAD text
(`security signals are preserved (10.1 IN-03)`) as removed, and that text has no
SC-5b-recognized token regardless of what replaces it. The only tokens SC-5b tolerates are
themselves union-grep targets this phase must remove, so no AFTER wording satisfies both
instruments for this one line simultaneously. Per D-16, `237-security-comment-diff-check.sh` was
not modified. The plan's actual goal — token gone, rationale sentence intact — is fully achieved
and independently verified by direct grep (`security signals are preserved` present,
`IN-03` absent). This is recorded as `human_judgment: true` coverage in the frontmatter above so
`/gsd-verify-work` surfaces it for a human sign-off rather than silently auto-passing or
silently failing.

**Total deviations:** 2 auto-fixed (both Rule 1 — scope-completeness bugs discovered during
execution, not architectural changes) + 1 accepted, fully-documented instrument limitation.
**Impact:** none on the actual deliverable — the union-token corpus is genuinely zero, every
rationale sentence survives, and all D-03 exclusions are intact. The impact is confined to one
advisory (not workflow-wired) verification script reporting one known, structurally-explained
false positive.

## Issues Encountered

None beyond the two auto-fixed deviations and the one accepted instrument limitation, both
documented above.

## Authentication Gates

None — this plan used only `bash`, `grep`, `python3`, `git`, and `mix compile`, all already
available in the environment.

## Next Phase Readiness

Plan 239-03 (the batched `mix sigra.fixture.rebless_golden`) can begin: `priv/templates/` is now
the source of truth with zero planning-bookkeeping tokens, the sweep commit sha (`cafd9a53`,
hyphen-chunked in the ledger as `cafd9a-5328b5-f08f31-5a123f-d874d2-698831-7537`) is recorded in
`239-EVIDENCE.md` under `## SWEEP-COMMIT`, and `239-comment-only-diff-check.sh` /
`239-golden-expected.txt` from plan 239-01 are ready to classify the re-bless diff plan 239-03
will produce. SURF-01 and SURF-03 remain `Pending` in `REQUIREMENTS.md` by design — both are
shared across plans 239-01/02/03/04, and the shared-ID gate correctly withholds marking them
`Complete` until every declaring plan (03 and 04 still outstanding) has a `SUMMARY.md`.

## Self-Check: PASSED

- `[ -f ]` confirmed for all 46 modified template files and `239-EVIDENCE.md`.
- `git log --oneline --all | grep -q cafd9a53` and `2b362456` — both found.
- Re-ran every task's acceptance-criteria-backing `<automated>` verify command against the final
  committed HEAD: all pass except the two documented, analyzed instrument-limitation cases
  (both `human_judgment: true` in coverage above, not silently marked pass).
- Re-ran the plan-level `<verification>` section: union grep zero over 119 files — confirmed;
  no `.planning/` path in `priv/templates/` — confirmed; SC-5b on the sweep diff — one documented
  survivor, not zero (see Deviations); commit scope entirely under `priv/templates/` and
  `.github/` zero-diff against `origin/main` — confirmed.
