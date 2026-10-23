---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 07
subsystem: install-templates
tags: [gap-closure, mirror, test-example, bookkeeping-sweep, surf-01, surf-03]
requires:
  - "239-05 (widened V2 definition; login_html.ex `during UAT` fix this plan mirrors)"
  - "239-06 (the single template wording every converged sentence is copied from)"
  - "test/fixtures/install_golden/tree/.../router.ex (the wording authority for the five router sites)"
provides:
  - "test/example/ router + layouts carrying zero V2 bookkeeping tokens"
  - "Four moduledoc sentences stated ONCE across priv/templates/ and test/example/"
  - "239-MIRROR-CHECKLIST.md accurate at the final HEAD, with its own staleness recorded"
  - "239-EVIDENCE.md § CLOSURE-MIRROR-COMMIT — V2 with a live positive control, per-sentence convergence table, two confirmed no-edit dispositions"
affects:
  - "239-08 (the single re-bless; test/example/ now agrees with the templates it re-blesses from)"
tech-stack:
  added: []
  patterns:
    - "The generated golden tree is the wording authority for a mirrored comment — never a third, freshly invented wording"
    - "Namespace-normalized moduledoc diff as the convergence oracle, not eyeballed prose"
    - "Confirmed no-edit disposition recorded in the ledger instead of a phantom edit"
    - "Every zero paired with a positive control on the same surface and the same grep invocation"
key-files:
  created: []
  modified:
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/components/layouts.ex
    - test/example/lib/example_web/controllers/session_html.ex
    - test/example/lib/example_web/live/organization_members_live.ex
    - test/example/lib/example_web/live/organizations_live/index.ex
    - test/example/lib/example_web/live/invitation_accept_live.ex
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-MIRROR-CHECKLIST.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
decisions:
  - "A sixth router site (`router.ex:175`, `local UAT`) was swept as a Rule-2 deviation. It is outside the plan's enumerated five but inside V2, on a file this plan was already editing; leaving it would have made the plan's own `V2 → 0` truth false."
  - "The golden router collapsed the four-line `Phase 10.1.1 B9` login comment to one line, so the example collapses too. The plan explicitly forbade guessing — the golden file was read first."
  - "`vt-modal` vs `modal` in organization_members_live.ex is NOT a prose divergence: it is the demo app's mini-brand CSS class, the same class of substitution as the module namespace, on a line this phase never touched. Recorded as MATCH with the delta named rather than silently normalized away."
  - "SURF-01/SURF-03 deliberately NOT marked complete in REQUIREMENTS.md — they close at plan 239-08's re-bless, not here (same call 239-06 made after reverting its generic state step)."
  - "All three tasks land as ONE path-scoped commit per Task 3 and D-19 commit topology, overriding the executor default of one commit per task (same call as 239-05 and 239-06)."
metrics:
  duration: "~25m"
  completed: 2026-09-17
actuals:
  tokens: 4100
  tasks: 3
  commits: 1
status: complete
---

# Phase 239 Plan 07: Mirror the Router and Layouts Sweep into `test/example/` and Correct the SC-4 Checklist — Summary

The demo app's router and layouts now say what a freshly generated app's router and layouts say, every
sentence the closure batch repaired exists in exactly one wording across both trees, and the SC-4
mirror checklist is a record a reader can trust rather than a snapshot of a tree that moved underneath
it three commits ago.

## What Was Built

### 1. Seven mirrored sites (Task 1)

`test/example/lib/example_web/router.ex` — five sites, each taking the wording already committed in
`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex`:

| Site | Before | After |
|---|---|---|
| `:36` | `# Phase 17 D-06: single unscoped InvitationAcceptLive at` | `# Single unscoped InvitationAcceptLive at` |
| `:77` | `# MFA challenge (accessible with mfa_pending sessions, D-24)` | `# MFA challenge (accessible with mfa_pending sessions)` |
| `:103-106` | 4-line `# Phase 10.1.1 B9: login page is a plain controller + HEEx render, …` block | `# Login page is a plain controller, not a LiveView.` |
| `:209` | `# Sigra organizations (Phase 16)` | `# Sigra organizations` |
| `:226` | `# "switch" as a slug (D-06).` | `# "switch" as a slug.` |

The `:103` collapse was **read, not guessed**: the plan permitted either shape, and the golden router
had collapsed it to one line, so the example follows.

`test/example/lib/example_web/components/layouts.ex` — two sites:

- line 9 comment → `# Organization switcher function component.`
- line 52 `attr :user_organizations` `doc:` → `doc: "list of {organization, role} tuples for the current user"`.
  This one is **not a comment**: it is an `attr/3` `:doc` option, rendered into ExDoc and surfaced by
  LSP hover, so the token was user-visible documentation text (T-239-07-04).

Positive controls on the same files: `pipe_through` → **21**, `attr :` → **13**. Nothing structural
moved — the whole diff for these two files is comment and `doc:` text.

### 2. Four sentences converged onto one wording (Task 2)

Method: extract both `@moduledoc` bodies, substitute `<%= web_module %>` → `ExampleWeb`,
`<%= app_module %>` → `Example`, diff.

| Sentence group | Verdict |
|---|---|
| WR-03 / WR-04 / IN-01 / IN-02 — members seam + Architecture bullets | **MATCH** |
| WR-05 — Branch B (`pending invitations list with an Accept action for each invitation`) | **MATCH** |
| IN-04 + `during UAT` — login/session moduledoc | **MATCH** |
| IN-03(b) — `:mismatch` invariant note | **MATCH** |
| WR-07 — MFA auto-submit comment | **MATCH** (no edit; already converged) |

The one residual delta inside the members moduledoc is `vt-modal` vs `modal` — the demo's mini-brand
CSS class, on a line this phase did not touch. Named rather than normalized away.

**Factual check before converging WR-03/WR-04:** the template's present-tense seam wording is only
true of the example if the example actually renders a populated stream. It does —
`stream(:pending_invitations, …)` at `:60`, `<section id="pending-invitations-section">` at `:428`,
`Invite member` action at `:368`. The present tense was verified, not inherited.

**IN-03(b) strengthened, not thinned (T-239-07-06):** the appended sentence is additive;
`grep -c 'ZERO .phx-click'` still returns **1**, so the original structural-defense invariant survived.

### 3. Two confirmed no-edit dispositions (never a phantom edit)

| File | Confirming evidence |
|---|---|
| `…/live/mfa_settings_live.ex` | `diff` of template `:606-610` vs example `:631-635` → identical, exit 0 |
| `…/accounts/organization_invitation.ex` | `@moduledoc false` — no WR-06 sentence exists to converge |

Neither appears in this commit's `git diff --name-only`.

### 4. Three checklist corrections + an eight-row closure table (Task 3)

- **C-1:** `organizations/router_injection.ex`'s `no counterpart (delivered by injection)` disposition
  replaced with `test/example/lib/example_web/router.ex` and its five sites, plus the one-sentence
  diagnosis of why the original was defensible-but-wrong (a disposition derived from the `{:eex, …}`
  emission table cannot see a splice target).
- **C-2:** rows added for `lib/sigra/install/features/core.ex` (edited by `6fa3ead2` / `e4e03980`,
  omitted from the checklist entirely because it is not a `priv/templates/` file) and for
  `test/example/lib/example_web/components/layouts.ex` (both sites, with the ExDoc/LSP note).
- **Closure batch table:** eight rows, one per template the closure edited, one disposition each. Six
  name a converged counterpart; `core/sigra_auth.css` and `organizations/organization_invitation_email.ex`
  take grep-asserted no-mirror-needed / no-counterpart dispositions.
- **Staleness header note:** names the parent sha `60bac0bb`, and names `cafd9a53` as the original
  freeze point and `6fa3ead2` / `e4e03980` as what made it stale. The original framing is retained;
  the correction is recorded, not written over it (T-239-07-03).

### 5. `239-EVIDENCE.md` § `## CLOSURE-MIRROR-COMMIT` (new slot)

V2 with its live positive control, the per-sentence convergence table, the two no-edit dispositions,
the `sigra_auth.css` and IN-03(a) assertions, and the scope proofs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] A sixth router site: `router.ex:175` `local UAT`**

- **Found during:** Task 3's V2 measurement
- **Issue:** V2 over the two Task-1 files returned **1**, not the plan's asserted 0.
  `# Dev-only routes for local UAT — Swoosh local-mailbox preview at /dev/mailbox` carries
  `\bUAT\b` — the alternation 239-05 added to V2, and the same token 239-05 removed from
  `login_html.ex`. The plan's Task-1 enumeration used the narrower five-site grep
  (`D-[0-9]{2}|[Pp]hase[ -][0-9]+|\bB[0-9]\b`), which is blind to it, while the plan's own must-have
  truth asserts full-V2 zero on that file. The two cannot both hold without this edit.
- **Fix:** rewritten to `# Dev-only routes for local manual testing — Swoosh local-mailbox preview at`
  / `# /dev/mailbox`. Meaning preserved — the very next line still reads "so manual testers can
  inspect rendered emails". Example-only comment with no template or golden counterpart, so fixing it
  here creates no new divergence.
- **Files modified:** `test/example/lib/example_web/router.ex`
- **Commit:** `5e2da7a6`

**2. [Deliberate non-action, mirroring 239-06] SURF-01/SURF-03 NOT marked complete**

The executor's generic state step marks a plan's frontmatter `requirements:` complete. SURF-03 closes
at plan 239-08's re-bless, not at this mirror. `REQUIREMENTS.md` is untouched by this plan; both
requirements stay open.

### Deliberate departure from executor default

**Commit topology:** one path-scoped commit for all three tasks, per Task 3's explicit instruction and
D-19. `git show --name-only --format= HEAD` lists 8 paths, 0 outside `test/example/` and the phase
directory; `git status --porcelain` clean afterward; no file deletions in the commit.

## Known Stubs

None. Every edit is finished prose; no placeholder, no TODO, no deferred wording. The two no-edit
files are recorded dispositions, not deferred work.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern, or schema change.

| Threat | Status |
|---|---|
| T-239-07-01 (route/plug altered under cover of a comment mirror) | mitigated — diff inspected line by line; every `+`/`-` pair is comment or `doc:` text; `mix compile --warnings-as-errors` exit 0 |
| T-239-07-02 (`attr` name / `default:` changed) | mitigated — exact `doc:` literal asserted, `attr :` control → 13 |
| T-239-07-03 (checklist quietly overwriting its stale history) | mitigated — header note names `cafd9a53`, `6fa3ead2`, `e4e03980` and the parent sha |
| T-239-07-04 (bookkeeping in an ExDoc-rendered `doc:`) | mitigated — line 52 swept, exact-literal grep → 1 |
| T-239-07-05 (`.github/` drift) | mitigated — `git diff --name-only origin/main -- .github/` empty |
| T-239-07-06 (IN-03(b) rationale thinned) | mitigated — sentence converged verbatim from the template, `ZERO phx-click` invariant still → 1 |

## Verification Results

| Check | Result |
|---|---|
| Task 1 `<automated>` | `MIRROR_OK` |
| Task 2 `<automated>` | `CONVERGED` |
| Task 3 `<automated>` | `CHECKLIST_OK` |
| V2 over `router.ex` + `layouts.ex` | **0** |
| V2 positive control (IN-05 example-only files, deliberately unswept) | **28** |
| V2 over the four converged files | **0** |
| `pipe_through` / `attr :` controls | 21 / 13 |
| golden-wording literals (`MFA challenge …`, `Single unscoped …`, `# Sigra organizations`, `"switch" as a slug.`, `doc: "…current user"`) | 1 each |
| `during UAT` / `until then` / `Look for the` / `^\s+only\.` | 0 / 0 / 0 / 0 |
| `LiveView's` / `SessionController.create/2` / `pending-invitations-section` / `ZERO .phx-click` | 1 / 1 / 3 / 1 |
| `Branch B` in `index.ex` | **2** — 1 moduledoc (the converged one) + 1 pre-existing in-code comment at `:130`, untouched (same measured departure 239-06 recorded) |
| `mfa_settings_live.ex` template `:606-610` vs example `:631-635` | identical, exit 0 |
| closure-batch table rows | **8** |
| `MIX_ENV=test mix compile --warnings-as-errors` | exit **0**, no output (run after Task 1 and again after Task 2) |
| `git diff --name-only origin/main -- .github/` | empty (0) |
| `git show --name-only --format= HEAD` | 8 paths, 0 outside scope |
| `git diff --diff-filter=D HEAD~1 HEAD` | empty — no deletions |
| `git status --porcelain` | clean |

## Flagged Assumptions (surfaced, unresolved — per the plan's frontmatter)

- **SURF-03 edge:** an `attr … doc:` string is treated as user-visible text rather than a comment, so
  SURF-03's mirror clause covers it. The assumption is acted on and surfaced; it is not resolved.
- **SURF-01 edge:** the dead-grep case. The V2 zero on the two edited files is paired with **28** on
  the IN-05 files. Surfaced, not resolved.

## Self-Check: PASSED

- `test/example/lib/example_web/router.ex` — FOUND
- `test/example/lib/example_web/components/layouts.ex` — FOUND
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-MIRROR-CHECKLIST.md` — FOUND
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md` § `## CLOSURE-MIRROR-COMMIT` — FOUND
- Commit `5e2da7a6` — FOUND in `git log`
