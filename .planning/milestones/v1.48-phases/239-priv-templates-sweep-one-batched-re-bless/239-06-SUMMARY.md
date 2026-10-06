---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 06
subsystem: install-templates
tags: [gap-closure, adopter-surface, bookkeeping-sweep, prose-repair, surf-01, surf-03]
requires:
  - "239-05 (the measured, dispositioned FIX-239-06 fix list this plan executes against)"
  - "239-REVIEW.md § CR-01, WR-03…WR-07, IN-01…IN-03 (source of truth for replacement wording)"
provides:
  - "priv/templates/sigra.install/core/sigra_auth.css free of CI run ids, round-N history, the bare 231-02 plan id, and 'do not re-litigate this' — mechanism intact"
  - "Seven applied prose repairs in priv/templates/ (WR-03…WR-07, IN-01…IN-03)"
  - "239-EVIDENCE.md § CLOSURE-TEMPLATE-COMMIT — V2 re-measure + positive control, row-by-row FIX-239-06 closure, two-assertion comment-containment proof, SC-5 re-proof, empty .github diff"
  - "A provably stale golden fixture (rebless_golden --check exits 2) for plan 239-08's single re-bless to carry"
affects:
  - "239-07 (mirrors test/example onto these exact wordings; the example's mfa_settings_live.ex wording is now the template's too)"
  - "239-08 (seven golden-tree files now drift; all of them clear at the single re-bless)"
tech-stack:
  added: []
  patterns:
    - "Comment-only edits proven by TWO orthogonal line-number assertions (comment-range membership over a single-line-span-masked stream + empty non-comment remainder), never a character-class grep over diff text"
    - "Every zero-assertion grep paired with a positive control on the same surface"
    - "Brace group + `|| true` inside command substitution so a zero-match grep is a measurement, not a fatal status"
    - "Row-by-row closure record with a literal proving grep per row — aggregate greens are not accepted"
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/core/sigra_auth.css
    - priv/templates/sigra.install/core/mfa_settings_live.ex
    - priv/templates/sigra.install/organizations/live/organization_members_live.ex
    - priv/templates/sigra.install/organizations/live/organizations_live/index.ex
    - priv/templates/sigra.install/organizations/organization_invitation.ex
    - priv/templates/sigra.install/organizations/organization_invitation_email.ex
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
decisions:
  - "A THIRD sigra_auth.css comment block (`:705`, `/* Live multi-run CI evidence`) was cleaned alongside the two GAP-1 blocks. It matches no V2 alternation and was in neither the verifier's enumeration nor 239-05's triage, but leaving 'Live multi-run CI evidence' 190 lines below where the same phrase was just deleted would ship an incoherent file. Comment-prose only, inside priv/templates/, no scope change."
  - "Residual V2 over priv/templates/ is recorded as the measured 2 occurrences on 1 line (the already-dispositioned FALSE-POSITIVE SVG geometry), not rounded to the plan's anticipated bare 0. The 2 is harmless only BECAUSE the ledger dispositioned it; writing 0 would hide that dependency."
  - "All three tasks land as ONE path-scoped commit per Task 3 and D-19 commit topology, overriding the executor default of one commit per task (same call as 239-05)."
metrics:
  duration: "~30m"
  completed: 2026-09-17
actuals:
  tokens: 4975
  tasks: 3
  commits: 1
status: complete
---

# Phase 239 Plan 06: Strip Residual Adopter-Shipped Bookkeeping and Repair the Swept Prose — Summary

The CSS file every adopter receives verbatim now explains its own mechanism and says nothing about
Sigra's CI runs, review rounds, or plan ids — and the seven sentences the first sweep left
ungrammatical, unfollowable, or factually wrong are repaired, with the security rationale in two of
them strengthened rather than thinned.

## What Was Built

### 1. `sigra_auth.css` — three comment blocks rewritten to mechanism-only (CR-01)

| Removed | Kept |
|---|---|
| `Live multi-run CI evidence` (×2 blocks) | H2/P shared one right edge; neither had `min-width: 0` |
| `after rounds 1-2`, `initial round-3 draft`, `the round-3 commit` | grid items of a single-implicit-column `.sigra-auth-stack` stretch to the shared column track, floored by the largest sibling min-content |
| `runs 30518012012 and 30518015684` | `.sigra-auth p` (0,1,1) outranks `.sigra-auth__product` (0,1,0) and appears later |
| `321.4375px`, `scrollWidth 445-473px vs innerWidth 320px` | only `anywhere` — not `break-word` — participates in automatic-minimum-size, so `break-word` here would silently override the wordmark |
| `231-02's min-width: 0` → `the earlier leaf-level min-width: 0` | `.sigra-auth form` is grid → `.fieldset` wrapper is itself an un-contained grid item carrying min-content |
| `do not re-litigate this` + the `DIV.fieldset/LABEL/SPAN.label/INPUT/BUTTON` reflow payload | why the leaf-only fix was insufficient |

Post-edit greps on that file: run ids **0**, `\b[Rr]ound[s]?[ -][0-9]` **0**, `\b[0-9]{3}-[0-9]{2}\b`
**0**, `do not re-litigate this` **0**, `Live multi-run CI evidence` **0**, full V2 **0**. Paired
mechanism-survived controls on the same file: `min-width: 0` **12**, `overflow-wrap` **7**,
`automatic-minimum-size|automatic minimum` **2**.

**Measured false-positive class, recorded not smoothed:** the plan's criterion
`grep -cE '[Rr]ound[s]?[ -][0-9]'` returns **5**, all from `background 220ms cubic-bezier(…)` — the
criterion was written without the `\b` the V2 alternation actually carries. The word-bounded form
`\b[Rr]ound[s]?[ -][0-9]` returns **0**, with a live control of **4** on `239-VERIFICATION.md`. The
criterion's intent holds; its literal form over-matches CSS declarations.

### 2. The two-assertion comment-containment proof (T-239-06-04)

```
masked_single_line_spans post=1 pre=1
changed added_lines=20 removed_lines=26
ASSERTION_1 comment-range membership:    PASS  (post_set_size=50, pre_set_size=56)
ASSERTION_2 empty non-comment remainder: PASS
```

Assertion 1 masks single-line `/* … */` spans before the state machine runs, so the one
declaration-and-comment line in this file (`min-width: 0; /* … */`, near `:732`) cannot latch it
open. Assertion 2 is independent of any post-edit-derived line set and is what would catch an edit to
the declaration half of that mixed line, or an edit that drops a closing `*/` and widens Assertion
1's own oracle. Both pass; no CSS declaration, selector, or value moved.

### 3. Seven prose repairs in `priv/templates/`

| Finding | File | Change |
|---|---|---|
| WR-03 | `organization_members_live.ex` | unfollowable `` `this section` `` HEEx pointer deleted; seam described in present tense |
| WR-04 | `organization_members_live.ex` | forward-looking subjectless "This section will replace the card body" gone; Architecture bullet no longer claims a HEEx comment marker |
| IN-01 | `organization_members_live.ex` | `Generated by` wrap joined onto one line |
| IN-02 | `organization_members_live.ex` | stray `only.` deleted; "v1.2 concern" sentence retained |
| WR-05 | `organizations_live/index.ex` | `Branch B: pending invitations list with an Accept action for each invitation` — no actor-less verb, no dangling "until then" |
| WR-06 | `organization_invitation.ex` | **the library** named as owner of generation/delivery/accept-reject; the schema only persists state |
| WR-07 | `mfa_settings_live.ex` | template adopts the example's clean wording; trailing bare colon gone — both trees converge |
| IN-03(a) | `organization_invitation_email.ex` | `(phishing defense — prevents inviter/org spoofing)` — the threat is named, not the defense |
| IN-03(b) | `invitation_accept_live.ex` | tool-agnostic `That absence is asserted by a test … do not add accept controls to this branch.` appended; original `ZERO phx-click` invariant sentence intact |

IN-03(b)'s claim was checked rather than asserted: `invitation_accept_live_test.exs:582` (T19) refutes
`phx-click="accept` and `phx-submit="accept` in the extracted `render_mismatch/1` body. The note is
true at HEAD, and names no plan-checker, plan id, or grep.

### 4. `239-EVIDENCE.md` § `## CLOSURE-TEMPLATE-COMMIT` (new slot)

V2 re-measure with its **97-file** `defmodule` positive control; **7 closure rows**, each with the
file, the line as it read before, and the literal proving grep; the containment proof above; the SC-5
re-proof; the empty `.github/` diff; and the commit-scope/golden-staleness record.

**Closure rows: 3 `FIX-239-06` + 4 absorbed instrument-gap lines.** Rows 1-3 are 239-05's triage
(`:524`, `:531`, `:696`). Rows 4-7 are lines V2 is structurally blind to and which a green V2 would
have certified clean forever: the line-split `after rounds` / `1-2.`, `Live multi-run CI evidence`
(×2 blocks), and `do not re-litigate this`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] A third `Live multi-run CI evidence` block at `:705`**

- **Found during:** Task 1
- **Issue:** The GAP-1 enumeration and 239-05's triage cover `:508-533` and `:689-698`. A third
  comment block at `:705-714` (the `.sigra-auth .label` nowrap rationale) opens with the same
  `Live multi-run CI evidence` phrase. It matches no V2 alternation, so nothing would ever flag it.
- **Fix:** Its first two lines rewritten to `A residual, distinct overflow survives the grid-item
  containment fix above -- …`. The WCAG-1.4.4 / nowrap mechanism is untouched.
- **Files modified:** `priv/templates/sigra.install/core/sigra_auth.css`
- **Commit:** `f11dfbe2`

### Measured departures from acceptance-criterion literals (not defects)

| Criterion | Expected | Measured | Reading |
|---|---|---|---|
| `grep -cE '[Rr]ound[s]?[ -][0-9]' sigra_auth.css` | 0 | **5** | all `background 220ms` — the criterion dropped the `\b` V2 carries; word-bounded form returns **0** |
| `grep -c 'Branch B' index.ex` | 1 | **2** | the moduledoc has exactly 1; the second is a pre-existing in-code `# Branch B — zero memberships…` comment at `:130`, untouched by this plan |
| V2 over `priv/templates/` | 0 | **2 occurrences / 1 line** | `oauth_html.ex:54` SVG path geometry `5.373-12`, already dispositioned `FALSE-POSITIVE` in the ledger. Undispositioned rows: **0** — the stop-the-line condition did not fire |

**2. [Rule 4-adjacent — reverted, surfaced not resolved] SURF-01/SURF-03 NOT marked complete**

- **Found during:** state updates
- **Issue:** The executor's generic state step marks a plan's frontmatter `requirements:` complete.
  Running it checked SURF-01 and SURF-03 off in `REQUIREMENTS.md` — but SURF-03's `test/example`
  mirror is plan 239-07's commit and the golden re-bless is 239-08's, both still unrun. This is
  exactly the false-Complete defect 239-05 filed a durable todo about for SURF-02.
- **Fix:** `git checkout -- .planning/REQUIREMENTS.md`; both requirements stay open. They belong to
  whichever plan closes the phase, not to this one.
- **Files modified:** none (revert)

### Deliberate departure from executor default

**Commit topology:** one path-scoped commit for all three tasks, per Task 3's explicit instruction and
D-19. `git show --name-only --format= HEAD` lists 8 paths, 0 outside `priv/templates/` and the phase
directory; `git status --porcelain` empty afterward.

## Known Stubs

None. Every edit is finished prose; no placeholder, no TODO, no deferred wording.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern, or schema change. T-239-06-01 through
T-239-06-05 are all mitigated and each carries a recorded, falsifiable proof (see
§ CLOSURE-TEMPLATE-COMMIT (a)-(f)). Notably T-239-06-02: no `# SECURITY:`-class rationale was deleted
or weakened — SC-5 exits 0 having examined **45** removed lines, and both touched rationales are
strictly stronger than before.

## Verification Results

| Check | Result |
|---|---|
| Task 1 `<automated>` | `CSS_OK` |
| Task 2 `<automated>` | `PROSE_OK` |
| Task 3 `<automated>` | `SCOPE_OK` (0 paths outside scope) |
| V2 over `priv/templates/` | 2 occ / 1 line, all pre-dispositioned `FALSE-POSITIVE`; undispositioned **0** |
| Positive control `grep -lc defmodule` over same file list | **97** files |
| V2 over `sigra_auth.css` | **0**, paired with `min-width: 0` → **12** |
| Comment containment, Assertion 1 (range membership) | PASS |
| Comment containment, Assertion 2 (empty non-comment remainder) | PASS |
| `237-security-comment-diff-check.sh` | `examined_removed_lines=45`, exit **0** |
| `git diff --name-only origin/main -- .github/` | empty (0) |
| `MIX_ENV=test mix compile --warnings-as-errors` | exit **0**, no output (run after Task 1 and again after Task 2) |
| `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | exit **2**, `DRIFT DETECTED:` on 7 golden files |
| `git show --name-only --format= HEAD` | 8 paths, all in `priv/templates/` or the phase dir |
| `git status --porcelain` | clean |

## Self-Check: PASSED

- `priv/templates/sigra.install/core/sigra_auth.css` — FOUND
- `priv/templates/sigra.install/organizations/live/organization_members_live.ex` — FOUND
- `priv/templates/sigra.install/organizations/organization_invitation.ex` — FOUND
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md` § `## CLOSURE-TEMPLATE-COMMIT` — FOUND
- Commit `f11dfbe2` — FOUND in `git log`
