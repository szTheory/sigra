---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 11
subsystem: installer-templates
tags: [gap-closure, surf-01, surf-03, bookkeeping-sweep, mirror, wr-01, wr-02, wr-03]
status: complete

requires:
  - phase: 239 (plan 09)
    provides: "239-v3-vocabulary-check.sh + 239-v3-allowlist.tsv, frozen (D-30); the three fixed tier file lists; the 3-tier RED demonstration this plan turns green on two of them"
  - phase: 239 (plan 10)
    provides: "D-27…D-30 recorded in 239-CONTEXT.md; the amended SC-1 naming its measuring definition"
provides:
  - "priv/templates/ clean under V3: hits_outside_allowlist=0, exit 0 — the GREEN half of plan 239-09's RED/GREEN pair on the same tier, same definition, same allowlist"
  - "test/example/ SC-4 counterparts clean under V3 (scoped tier, files_measured=2)"
  - "WR-01 replaced: the adopter-shipped moduledoc no longer claims a regression guard the adopter does not have"
  - "WR-02 and WR-03 closed; both SC-1 gap sentences gone from two of three tiers"
  - "239-EVIDENCE.md § BATCH-3-SWEEP-COMMIT (12 subsections, incl. the mirror record)"
  - "239-MIRROR-CHECKLIST.md batch-3 block, append-only (25 insertions, 0 deletions)"
affects: [239-12, 239-13]

actuals:
  tokens: 38000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Every zero paired with a live positive control on the same file list — the pairing caught a real dead grep this run"
    - "Cross-line-break claims checked against a flattened, length-asserted region extraction rather than a single-line grep"
    - "Pre-existing tier drift proven pre-existing by reproducing the identical diff at the plan's base commit, not by assertion"

key-files:
  created: []
  modified:
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
    - priv/templates/sigra.install/organizations/live/organization_members_live.ex
    - test/example/lib/example_web/live/invitation_accept_live.ex
    - test/example/lib/example_web/live/organization_members_live.ex
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-MIRROR-CHECKLIST.md

key-decisions:
  - "The WR-01 replacement is written about the adopter's project, not Sigra's: it states that Sigra's suite asserts the absence in the shipped template, that `mix sigra.install` generates no tests, and that a customizer must add their own assertion — backed by two observations re-run in this plan, not cited"
  - "`mix format --check-formatted` on priv/templates is inapplicable by construction (EEx placeholders in Elixir syntax positions; `.formatter.exs` deliberately excludes the directory). Substituted the repo-configured `mix format --check-formatted` — the check `mix ci` actually runs — and recorded the substitution as a deviation rather than reporting a check that cannot exist"
  - "The wider `## Architecture` block carries one template-vs-example difference (`class=\"modal\"` vs `class=\"vt-modal\"`). Proven pre-existing by reproducing the identical one-line diff at base `74e6a148`; recorded, not reconciled. The changed region itself diffs empty, which is the claim the plan makes"

requirements-completed: []

metrics:
  duration: ~25m
  completed: 2026-09-18
---

# Phase 239 Plan 11: Batch-3 Sweep and Mirror Summary

Removed the two residual Sigra-internal bookkeeping sentences that still shipped into every generated
app, replaced an adopter-facing moduledoc claim that asserted a regression guard on an
authorization-bypass defense the adopter never receives, and mirrored both edits into `test/example/`
in a separate commit — flipping the V3 instrument from RED to GREEN on two of its three tiers without
touching the instrument.

## What Changed

| Finding | File | Edit |
|---|---|---|
| WR-01 (false safety claim) | `invitation_accept_live.ex` `@moduledoc` | `That absence is asserted by a test, not merely conventional` → prose stating what is true for an adopter: Sigra's suite asserts the absence *in the shipped template*; `mix sigra.install` generates no tests; add your own assertion if you customize. The `do not add accept controls to this branch` imperative survives verbatim. |
| WR-02 / SC-1 gap 1 | `invitation_accept_live.ex` `:326` | `# The plan-checker greps this function body and asserts zero matches.` deleted in full. The `DO NOT add an accept button here even "for convenience"` lines and the `Jetstream #907 / CVE-2026-1529` attribution survive and carry the constraint. |
| WR-03 / SC-1 gap 2 | `organization_members_live.ex` `:23-24` | Pagination bullet gains its terminator; the `Flop / sortable columns are a v1.2 concern.` release-sequencing sentence deleted. |

Both edits mirrored into the two `test/example/` counterparts in commit 2.

## Commits

| # | Hash | Scope |
|---|---|---|
| 1 (sweep) | `7eee6b00` | exactly the two `priv/templates/` files |
| 2 (mirror) | `8dc2ecc4` | exactly the two `test/example/` files + `239-EVIDENCE.md` + `239-MIRROR-CHECKLIST.md` |

D-19 topology holds. `git diff --name-only HEAD~2 -- test/fixtures/install_golden/ .github/` is empty.

## Verification

| Check | Result |
|---|---|
| V3 `priv-templates` | `hits=1 allowlisted=1 hits_outside_allowlist=0 control_defmodule=98 files_measured=119`, **exit 0** (was `hits=3 … outside=2`, exit 1 at plan 239-09) |
| V3 `example` (SCOPED, 2 counterparts) | `hits=0 outside=0 control_defmodule=2 files_measured=2`, **exit 0** |
| V3 `golden` | `outside=2`, **exit 1** — stale by exactly this batch, the two sentences and nothing else. Closed by plan 239-12. |
| Fixed-string grep, sentence 1 & 2, over `priv/templates` | `0` / `0`, controls `defmodule`=**97 files**, `DO NOT add an accept button here`=**1 file** |
| Fixed-string grep, sentence 1 & 2, over `test/example` | `0` / `0`, controls **156** / **1** |
| Region checks (flattened, `region_lines=11`) | `generates no tests`=1, `your own test suite`=1, `asserted by a test`=0, `merely conventional`=0, imperative=1 |
| Post-substitution tier equality | all three changed regions diff **empty** |
| `mix format --check-formatted` (repo inputs) | exit 0 |
| `237-security-comment-diff-check.sh` | sweep diff: `examined_removed_lines=5` exit 0; combined diff: `=10` exit 0. Script byte-unchanged. |
| Instrument + allowlist byte-unchanged | `git diff --name-only HEAD~2..HEAD --` those two paths: empty |
| Changed-line classification | 10 `+`/`-` content lines: 9 inside `@moduledoc` heredocs, 1 `#` comment. No function head, guard, route, plug, `attr`, or `default:`. |

Full record: `239-EVIDENCE.md` § `## BATCH-3-SWEEP-COMMIT` (a)–(l).

## Deviations from Plan

**1. [Rule 3 - Blocking] `mix format --check-formatted` on `priv/templates/` is inapplicable by construction**

- **Found during:** Task 1 verification
- **Issue:** The plan's `<verify>` chains `mix format --check-formatted` over the two template files.
  Templates carry EEx placeholders in Elixir syntax positions (`defmodule <%= web_module %>.X do`) and
  are not parseable Elixir — the command fails with `(SyntaxError) … before: '='` on any template,
  before and after this plan's edits. `.formatter.exs` deliberately omits `priv/templates` from its
  `inputs:`, with a comment explaining why; the exclusion pre-dates this phase.
- **Fix:** Ran the repo-configured `mix format --check-formatted` — the check `mix ci` actually
  enforces — and got exit 0. The two `test/example/` files *are* in `inputs:` and were checked
  individually as the plan specifies (exit 0).
- **Files modified:** none
- **Commit:** recorded in evidence § (i), no code change

**2. [Measurement, not a code change] A dead grep was produced and caught by its own control**

The first named-string run used `grep … $(git ls-files priv/templates)` relying on word splitting.
This shell does **not** word-split unquoted expansions, so the whole list arrived as one argument and
every count came back `0` — including the paired `defmodule` control, which is what exposed it. Re-run
via `git ls-files -z | xargs -0` with two live controls. This is the `unclassified` edge-probe's dead-grep
case firing for real, and the reason the plan requires a control beside every zero. Recorded in
evidence § (d).

**3. [Recorded, not reconciled] Pre-existing `class="modal"` vs `class="vt-modal"` drift**

The wider `## Architecture` block differs between tiers by one line of demo-app `vt-*` brand-class
drift. Not a stop-the-line event: the identical diff reproduces at base commit `74e6a148`, so it is
pre-existing and outside every region this batch changed; the changed region itself diffs empty.
Recorded in evidence § (l) and in the checklist row.

## Open / Routed

- The `golden` tier remains RED by exactly this batch — expected, and plan 239-12's single re-bless
  closes it (D-09). A golden `outside=0` here would have meant a hand-edited fixture.
- The unswept `test/example/` remainder (482 lines / 157 files, measured by plan 239-09) stays routed
  to **Phase 241 SURF-04**. This plan's `example` zero is scoped to 2 files and says nothing about it.
- `IN-01`…`IN-04` in `239-REVIEW.md` remain open by design — deliberately not closed here to keep the
  batch-3 diff line-by-line auditable.
- Every line number quoted in this plan's evidence is invalidated by plan 239-12's re-bless.

## Known Stubs

None. No stub, placeholder, `TODO`, `FIXME`, or unwired component was introduced — every change is
`@moduledoc` prose or a `#` comment, and no executable line moved.

## Self-Check: PASSED

- `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` — FOUND
- `priv/templates/sigra.install/organizations/live/organization_members_live.ex` — FOUND
- `test/example/lib/example_web/live/invitation_accept_live.ex` — FOUND
- `test/example/lib/example_web/live/organization_members_live.ex` — FOUND
- `239-EVIDENCE.md` § `## BATCH-3-SWEEP-COMMIT` — FOUND
- `239-MIRROR-CHECKLIST.md` batch-3 block — FOUND (25 insertions, 0 deletions)
- Commit `7eee6b00` — FOUND
- Commit `8dc2ecc4` — FOUND
