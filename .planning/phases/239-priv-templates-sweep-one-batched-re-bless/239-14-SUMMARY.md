---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 14
subsystem: install-templates
tags: [gap-closure, priv-templates, adopter-facing-prose, measurement-scope, decisions]
status: complete
requires:
  - "239-12 (batch-3 re-bless, commit 87581665)"
  - "D-27, D-28, D-29, D-30 (239-CONTEXT.md round-2 decisions block)"
  - "239-v3-vocabulary-check.sh + 239-v3-allowlist.tsv (frozen instrument, D-30)"
provides:
  - "D-31 — the WR-01 installer-test claim retracted as false on the bytes"
  - "D-32 — generated-app V3 claim scoped to created-or-modified files"
  - "239-EVIDENCE.md § GENERATED-APP-SCOPE (frozen scope rule + halt clause)"
  - "239-EVIDENCE.md § BATCH-4-SWEEP-COMMIT (full per-command evidence)"
  - "BATCH-4-JUSTIFICATION-PENDING marker (plan 239-15 discharges)"
  - "239-13-PLAN.md amended so its criteria no longer contradict D-31"
affects:
  - "plan 239-15 (batch-4 re-bless — the golden fixture is now stale by exactly this batch)"
  - "plan 239-13 (re-runnable: its T-239-12-03 observation is re-based)"
tech-stack:
  added: []
  patterns:
    - "retraction over re-verification for adopter-shipped prose claims"
    - "content-independent measurement scope frozen before the measurement it governs"
    - "every zero paired with a live positive control on the same surface"
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
    - test/example/lib/example_web/live/invitation_accept_live.ex
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-CONTEXT.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-MIRROR-CHECKLIST.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-13-PLAN.md
decisions:
  - "D-31: the WR-01 @moduledoc replacement prose is RETRACTED as false on the bytes — lib/sigra/install/features/admin.ex:38-39 maps admin/policy_test.exs into every adopter's test/ tree. The repair is a retraction, not a re-verification: the corrected prose makes no claim about installer output at all."
  - "D-32: the generated-app V3 claim is scoped to the files mix sigra.install CREATED OR MODIFIED (not merely created), a rule borrowed from test/support/install_fixture.ex:360-364 that pre-dates the phase. Option (a), a new allowlist entry, is mechanically impossible — demonstrated live at exit 3."
  - "Task 4 delivers D-31 to plan 239-13 as an edit to its TEXT, not only as a CONTEXT.md record — an executor must never choose between its own acceptance criteria and a decision file."
metrics:
  duration: ~35m
  completed: 2026-09-18
actuals:
  tokens: 12290
  tasks: 4
  commits: 4
---

# Phase 239 Plan 14: Batch-4 Retraction of the False Installer-Test Claim Summary

The adopter-shipped `@moduledoc` in `invitation_accept_live.ex` no longer claims `mix sigra.install`
generates no tests — a claim that was false on the bytes and had already been blessed into the golden
fixture — and the generated-app measurement scope plan 239-13 needs is frozen by a content-independent
rule committed before the measurement it governs.

## What Was Built

Four atomic commits, in the D-19 topology (decisions → template → mirror → plan amendment):

| # | Commit | What |
|---|---|---|
| 1 | `a253b8c1` | D-31 + D-32 in `239-CONTEXT.md`; § `GENERATED-APP-SCOPE` frozen and the `BATCH-4-JUSTIFICATION-PENDING` slot opened in `239-EVIDENCE.md` |
| 2 | `7592e760` | The template retraction — one path, two prose lines replaced |
| 3 | `a13c40bc` | The `test/example/` mirror + § `BATCH-4-SWEEP-COMMIT` + the batch-4 mirror-checklist block |
| 4 | `cc2f5c61` | The four `T-239-12-03` amendments to `239-13-PLAN.md`, path-scoped to that file alone |

### The retraction

**Before:** `` `mix sigra.install` generates no tests, so if you customize this file, add an
equivalent assertion to your own test suite. ``

**After:** `your generated project does not inherit that assertion, so if you customize this file,
add an equivalent assertion to your own test suite.`

The paragraph's line count is unchanged (8 → 8). Two `-` lines, two `+` lines, per tier, all
`@moduledoc` prose — no function head, guard, route, plug, `attr` or `default:` among them.

### Every surviving clause checked as a claim

This is the step plan 239-11 skipped, and skipping it is what produced the defect repaired here.

- **Claim (i)** *Sigra's own suite asserts this absence in the shipped template* — T19 re-confirmed
  live at `test/example/test/example_web/live/invitation_accept_live_test.exs:582`, inside
  `describe "structural invariant (Jetstream #907 static check)"` (`:581`), whose subject is the
  shipped template path built at `:584-595`. Searched the **nested** example app, not the root tree.
- **Claim (ii)** *your generated project does not inherit that assertion* — T19's basename is not
  among the installer's `_test.exs` creation targets: `/usr/bin/grep -cF` over the enumeration → **0**,
  with the enumeration's own `wc -l` → **3** beside it as the positive control.
- **Claim (iii)** *the paragraph claims nothing about installer output* — fixed-string count of the
  retracted clause → **0** in both tiers, each paired with a live control (`by construction, not by
  convention` → **1**) on the same file.

The `DO NOT add an accept button here even "for convenience"` imperative and the
`Jetstream #907 / CVE-2026-1529` attribution each count exactly **1** per tier and appear in neither
the `+` nor the `-` content lines of either commit.

### The re-derived blocking fact

`/usr/bin/grep -rn 'test\.exs' lib/sigra/install/features/` → **3** hits, **classified, not counted**:

| Hit | Class |
|---|---|
| `core.ex:605` `target: Path.join(["config", "test.exs"])` | `config/test.exs` **injection** target — not a test file |
| `admin.ex:38-39` `{:eex, "admin/policy_test.exs", Path.join(["test", otp_app, "sigra_admin_policy_test.exs"])}` | one wrapped tuple — the **sole `_test.exs` creation target** |

One creation target is enough to falsify an absence claim.

### D-32's scope, in the created-or-modified form

The plan-checker's surviving concern was reconciled as instructed: **D-32 and § `GENERATED-APP-SCOPE`
are written in the created-or-modified form**, never "the files `mix sigra.install` writes, and no
other". The distinction is load-bearing — `mix sigra.install` **injects** into `phx.new`-authored
files (`injection.ex:15` names `lib/my_app_web/router.ex` as the canonical `:target`; `core.ex:350`,
`:525-526`, `:794` build `%Injection{}` records for router, config and `runtime.exs`), none of which
appear in any `{:eex, …}` target map. Under a target-maps-only scope a Sigra-authored bookkeeping line
injected into `router.ex` would sit outside the measurement **and** outside the halt clause. § (b) of
the frozen section names that trap explicitly.

Derivation used: **the union fallback** (`{:eex,…}`/copy/text targets ∪ `%Injection{}` targets — 90
create-target records / 78 distinct shapes, plus 21 injection targets), because computing the live
created-or-modified diff needs the scaffolded app that belongs to plan 239-13. Which one was used, and
why, is recorded in § (c).

### The live fail-closed demonstration (D-32's central claim, as a fact)

```
awk -F'\t' 'NF>=2' <scratch-copy> | wc -l          ->  3    [parse control, run BEFORE the exit code]
V3_ALLOWLIST=<scratch-copy> 239-v3-vocabulary-check.sh priv-templates
FAIL: allowlist entry 'lib/demo_web/…/home.html.heex' is exercised by none of the three named tiers …
EXIT=3
```

The scratch copy lived outside the repo working tree and was deleted; `git status --porcelain` was
empty afterwards and the real allowlist is byte-unchanged.

## Verification Results

| Gate | Result |
|---|---|
| `239-v3-vocabulary-check.sh priv-templates` | exit **0** — `hits=1`, `allowlisted=1`, `hits_outside_allowlist=0`, `control_defmodule=98`, `files_measured=119` |
| `239-v3-vocabulary-check.sh example` | exit **0** — `hits=0`, `hits_outside_allowlist=0`, `control_defmodule=2`, `files_measured=2` (SC-4 two-file scope, **never** all of `test/example/`; its 482-line / 157-file remainder stays routed to Phase 241 SURF-04, D-30) |
| Changed-region tier equality | `diff <(sed -n '16,23p' template) <(sed -n '16,23p' counterpart)` → **empty** |
| `mix format --check-formatted` | exit **0** (repo-configured), plus the counterpart checked individually → exit **0** |
| Instrument + allowlist byte-unchanged | `git diff --name-only baa01104..HEAD --` both paths → **empty** |
| Forbidden paths | `git diff --name-only baa01104..HEAD -- test/fixtures/install_golden .github .planning/REQUIREMENTS.md` → **empty** |
| SURF-03 | still `[ ]` — `/usr/bin/grep -c '^- \[ \] \*\*SURF-03\*\*'` → **1** |
| Commit topology (D-19) | `git merge-base --is-ancestor 7592e760 HEAD` → **0**; each commit path-scoped |
| `239-MIRROR-CHECKLIST.md` append-only | `git diff --numstat` → `21 0` (zero deletions) |
| `verify.plan-structure` on amended `239-13-PLAN.md` | `"valid": true` |
| `239-13-PLAN.md` self-consistency | stale-zero detector → **0** (control: `T-239-12-03` appears **7×**); `sigra_admin_policy_test.exs` → **5**; `as amended by D-31` → **4**; `*.exs` control retained → **3**; `depends_on: ["239-15"]` intact |

`mix format --check-formatted` over `priv/templates/` is **inapplicable by construction** (EEx
placeholders in Elixir syntax positions; `.formatter.exs` deliberately excludes the directory) — the
repo-configured run is the recorded substitution, as plan 239-11 did.

## Deviations from Plan

**1. [Rule 1 — Plan arithmetic] The scratch-allowlist parse control returns 3, not the 2 the plan predicted**

- **Found during:** Task 1, the D-32 fail-closed demonstration.
- **Issue:** the plan required `awk -F'\t' 'NF>=2' <scratch> | wc -l` to equal **2** ("the original
  entry plus the appended one"). It returns **3**, because the allowlist's `# path<TAB>literal<TAB>reason`
  header line also parses with `NF>=2`. The committed original returns **2** for the same reason.
- **Fix:** none needed in the instrument or the fixture — the control's *intent* (prove the appended
  row is genuinely tab-separated, so an exit other than 3 would be a real falsification rather than a
  silently-skipped comment row) is fully satisfied: `3 = 2 baseline lines + 1 appended row`. The
  off-by-one is in the plan's arithmetic, not in the control. Recorded verbatim inside D-32 so a later
  reader is not misled into thinking the control was loosened.
- **Files modified:** `239-CONTEXT.md` (the D-32 parse-control paragraph).
- **Commit:** `a253b8c1`.

**2. [Rule 3 — Blocking, plan-internal contradiction] The Task-4 before/after sub-entry was written in Task 3's commit**

- **Found during:** Task 3.
- **Issue:** Task 4's action requires its four before/after records to live in `239-EVIDENCE.md`
  § `BATCH-4-SWEEP-COMMIT`, but Task 4's commit is required by its own acceptance criteria and by the
  phase prohibitions to contain **exactly one path**, `239-13-PLAN.md`. Both cannot hold in one commit.
- **Fix:** the sub-entry (§ (g)) was written into § `BATCH-4-SWEEP-COMMIT` in Task 3's commit, and
  Task 4 then applied exactly the amendments that section records. The record is a strict **ancestor**
  of the amendment it describes, which preserves the auditability the requirement exists for while
  keeping Task 4's commit single-path.
- **Files modified:** `239-EVIDENCE.md`.
- **Commit:** `a13c40bc`.

**3. [Plan-checker concern, resolved as instructed] Four "Sigra-authored" phrasings reconciled to "created or modified"**

The executor brief flagged that L80/L96/**L230**/L334-335 of the plan still said *Sigra-authored*
where the binding constraints say *created or modified*. D-32's headline statement, § `GENERATED-APP-SCOPE`'s
rule text, its path-pattern set and its halt clause are all written in the **created-or-modified**
form. The trap description (§ (b)) retains the word *Sigra-authored* where it is used **correctly** —
describing the line that would escape a target-maps-only scope.

## Deliberate Non-Actions

- `test/fixtures/install_golden/` untouched — the golden fixture is left **stale by exactly this
  batch**, which is the state plan 239-15 requires (D-09).
- `.planning/REQUIREMENTS.md` untouched; **SURF-03 stays `[ ]`**. Plan 239-13 re-checks it, last and
  alone.
- `.github/` untouched (D-23). `239-v3-vocabulary-check.sh` and `239-v3-allowlist.tsv` untouched (D-30).
- The batch-4 justification is **opened, not filled** — D-29 requires it in the commit immediately
  preceding plan 239-15's re-bless.
- No generated app, no Postgres, no tarball, no `MIX_ENV=test mix ci`, no SC-5 — every live external
  observation stays plan 239-13's, deliberately un-pre-empted.

## Known Stubs

None. Every change is `@moduledoc` prose plus `.planning/` records; no code path, module, function,
route or config key was created or altered.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern, or schema change. The one
security-relevant surface in scope — the Jetstream #907 structural defense — was asserted **byte-intact**
in both tiers (T-239-14-07).

## For The Next Phase

**Plan 239-15** (the batch-4 re-bless) must: fill the `BATCH-4-JUSTIFICATION-PENDING` slot in the
commit immediately before its re-bless, then run `MIX_ENV=test mix sigra.fixture.rebless_golden` as a
single batched, comment-only-diff commit.

**Plan 239-13** (re-run last, `wave: 16`, `depends_on: ["239-15"]`) is now re-runnable unchanged: its
`T-239-12-03` observation asks for `>= 1` `_test.exs` with `sigra_admin_policy_test.exs` named, with
the `*.exs` control retained, and its generated-app V3 run is governed by § `GENERATED-APP-SCOPE` —
including the **halt clause**: enumerate the actual excluded hits, and stop if any excluded path turns
out to be one the installer created **or modified**.

## Self-Check: PASSED

All five files and all five commits verified present at the final HEAD on a clean tree
(Standing Constraint 2). No missing items.
