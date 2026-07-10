# Quarantine PR: `impersonation-banner` canary reconciliation (3 PNGs)

**Status:** DRAFT. This document is a ready-to-paste PR body + operator checklist. No PR has
been opened, pushed, or merged by this task (Phase 220 Plan 04, D-05..D-08). The actual PR
creation and merge are operator actions, executed as step 2 of the coherent ship sequence in
`220-CLOSE-READINESS.md`.

## Pre-flight: current PNG drift re-verification

Re-verified at execution time (2026-07-10, HEAD `52d5c51e733961c74962a160264d1f35d2b93ab2` on
branch `gsd/phase-219-baseline-recapture-canary-reconciliation`):

```
$ git fetch origin main --quiet
$ git diff --name-status origin/main...HEAD -- '*.png'
M	test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-chromium.png
M	test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-dark.png
M	test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-mobile.png
```

**Exactly 3 files, all `M` (modified), all `impersonation-banner-admin-checkpoints-{chromium,
dark,mobile}.png`.** No other baseline drifted (`board-notice` and the other ~112 checkpoint/
design PNGs already match `origin/main`). This matches the CONTEXT/RESEARCH claim byte-for-byte
— re-verify this command immediately before opening the quarantine PR, since research validity
is scoped to 7 days and PR states shift as ratification commits land.

## (a) Ready-to-paste PR title + body

**Branch name:** `ci/quarantine-impersonation-banner-canary-recapture`

**How to cut the branch (baselines-only diff, isolated from the other 191 v1.44 commits):**

```bash
git fetch origin main
git checkout -b ci/quarantine-impersonation-banner-canary-recapture origin/main
git checkout gsd/phase-219-baseline-recapture-canary-reconciliation -- \
  'test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-chromium.png' \
  'test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-dark.png' \
  'test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-mobile.png'
git status --short   # MUST show exactly these 3 files staged, nothing else
git commit -m "ci(checkpoints): recapture impersonation-banner canary (fresh amd64 bytes)

Isolated baselines-only reconciliation. See guides/reference/admin-eval-runbook.md
'merge-boundary canary-red is EXPECTED' note and .planning/phases/220-terminal-ratification/
220-QUARANTINE-PR-BODY.md for the full rationale. Diff is exactly these 3 PNGs — no other
change."
```

**PR title:**

```
ci(checkpoints): recapture impersonation-banner canary (3 PNGs, amd64-native)
```

**PR body (paste verbatim):**

```markdown
## What

Recaptures the 3 `impersonation-banner` admin-checkpoint baselines (chromium/dark/mobile) to
the fresh amd64-native bytes produced by Phase 219's in-CI recapture run. This is a
baselines-only PR — the diff is exactly these 3 PNGs, nothing else.

## Why

`origin/main` still holds stale darwin-rendered bytes for this one canary slug (all other ~112
admin checkpoint/design baselines already match). `snapshot-canary-guard.sh` is intentionally
**never-allowlistable** for the canary (see D-05/D-06 in
`.planning/phases/220-terminal-ratification/220-CONTEXT.md`) — it will not let a canary
*modify* pass `fast_checks` on any PR, by design. Isolating the rebirth to this small PR means
the terminal v1.44 milestone PR (opened after this merges) sees **zero** PNG diff and ships
caveat-free (D-07).

## What to expect on this PR's checks

- **`Example Playwright smoke (full lifecycle)` (REQUIRED) → GREEN.** This is the load-bearing
  signal: a fresh amd64-native Playwright render is compared byte-for-byte against the 3 newly
  committed baselines in this PR. A green result here is a **positive byte-correctness proof**
  — stronger evidence than a human eyeballing pixel diffs, because it is the exact comparison
  the merge-blocking gate performs on every future PR.
- **`fast_checks` (NOT required) → RED, expected.** `snapshot-canary-guard.sh` hard-fails any
  canary *modify* unconditionally (it is the zero-human safety tripwire — see D-06: "the canary
  must never be allowlisted... this would silence the zero-human safety tripwire"). This red is
  **known, intended, and not to be suppressed, allowlisted, or investigated as a regression.**
  `fast_checks` is not in ruleset 14941512's required-check list, so it does not block this
  merge.
- The other 4 required checks (`Library tests`, `Example unit smoke`, `Install smoke`, `Example
  HTTP smoke`) are unaffected by a PNG-only diff and are expected green as a matter of course.

## Merge-order requirement

**Merge this PR FIRST**, before the terminal v1.44 milestone PR. Once this merges to `main`,
the terminal PR (rebased on the new `main`) will see zero PNG diff on this canary and ship with
all 5 required checks + `fast_checks` green — no caveats, no quarantine-shaped scar tissue in
the milestone artifact of record.

## Non-goals

- Does NOT touch `snapshot-canary-guard.sh`, the allowlist, or any guard logic.
- Does NOT include any other admin/UI/library code change.
```

## (b) Why the required check goes green while the non-required check goes red — plain explanation

The `impersonation-banner` canary is the one deliberately unforgeable tripwire in the baseline
system: `snapshot-canary-guard.sh` treats a canary *modify* as an unconditional hard failure,
with no allowlist escape hatch (D-05/D-06). That is correct, permanent behavior — it exists so
nobody can silently swap in a "close enough" baseline for the one slug the whole recapture
discipline is built to protect.

The catch: Phase 219's in-CI amd64-native recapture legitimately produced 3 new, *correct*
bytes for this canary (replacing stale darwin-rendered bytes on `main`). Landing those bytes
anywhere will trip the canary guard exactly once, on whichever PR carries the diff. Rather than
accept that red on the terminal milestone PR (normalizing "it's fine, that one's expected" on
the artifact of record — a normalization-of-deviance risk), this PR isolates the rebirth:

- **`Example Playwright smoke (full lifecycle)` is REQUIRED and goes GREEN** because it performs
  a fresh render → byte-compare against the baselines this PR commits. Green here is not "the
  guard was skipped" — it is a positive, automated proof that the new bytes are the correct
  fresh amd64 render. This is the same comparison every future PR is held to.
- **`fast_checks` is NOT required and goes RED** purely because `snapshot-canary-guard.sh` fires
  on the canary-modify by design. It is not weakened, not suppressed, not routed around — it
  fires exactly as intended, on a PR scoped small enough that a human can trivially confirm the
  red is the expected 3-file canary rebirth and nothing else (see checklist below).

This mirrors the ecosystem idiom (Chromatic/Percy/reg-suit): an intentional baseline update
turns its own check green on approval; it is never merged as a standing red on the primary
artifact.

## (c) D-08 footgun: `GITHUB_TOKEN` does not retrigger workflow runs

**A PR opened or pushed using the default `GITHUB_TOKEN` (e.g. via `gh pr create` running under
GitHub Actions, or any bot-authored push) does NOT trigger a new workflow run** — GitHub
suppresses `pull_request` / `push` event dispatch for commits authored via `GITHUB_TOKEN` to
prevent recursive workflow loops. If this quarantine PR is opened that way, the 5 required
checks will simply never run, the PR will show "no checks reported," and it will look mergeable
by ruleset default (or worse, sit un-mergeable with only the merge-blocking checks perpetually
pending) without ever actually proving the byte-correctness claim above.

**Mitigation:** open and push this PR using a **Personal Access Token (PAT)** authenticated as a
real user, or push it from a local `git push` using normal user credentials (not a CI bot
identity). Either path triggers the normal `pull_request` event and the 5 required checks run
for real. Confirm this worked by checking that `gh pr checks <pr-number>` shows all 5 required
check names present and running/complete — not absent.

## (d) Operator scope-check + merge-order checklist

Before merging this PR, confirm all of the following:

- [ ] `git diff --name-only <base>...<head> -- '*.png'` on the quarantine branch shows **exactly
      3 files**, all `impersonation-banner-admin-checkpoints-{chromium,dark,mobile}.png`, and
      `git diff --stat` shows **no other file changed**.
- [ ] The PR was opened/pushed via a PAT or manual user push (not `GITHUB_TOKEN`) — confirm via
      `gh pr checks <pr-number>` that the 5 required checks actually ran (not silently skipped).
- [ ] `Example Playwright smoke (full lifecycle)` is **green**.
- [ ] `fast_checks` is **red**, and the failure reason (visible in the job log) is
      `snapshot-canary-guard: FAIL: canary snapshot ... modify ... forbidden` (or equivalent
      canary-modify message) — i.e. the red is the expected canary tripwire, not an unrelated
      failure. If `fast_checks` fails for any *other* reason, STOP — do not merge; investigate
      the unrelated failure first.
- [ ] The other 4 required checks (`Library tests`, `Example unit smoke`, `Install smoke`,
      `Example HTTP smoke`) are green.
- [ ] **Merge this PR before opening the terminal v1.44 milestone PR** — merging first is what
      makes the terminal PR's PNG diff go to zero (D-07).

Once merged, `main`'s `impersonation-banner` canary bytes match the fresh amd64 render, and the
terminal PR (opened after a rebase onto the new `main`) carries zero PNG diff.

## (e) Fallback (non-default)

If the extra merge-and-wait cycle above is judged not worth it for a given execution, the
D-06-compliant fallback is: **skip this quarantine PR and ship the terminal v1.44 milestone PR
directly with `fast_checks` red on the same canary-modify reason.** This is safe (the guard is
never weakened either way) but produces worse reviewer DX — a standing red on the milestone PR
of record that a reviewer must be told to ignore, rather than a clean 6/6 green terminal
artifact. **This fallback is NOT the default path; the quarantine PR above is.** Use it only if
the operator explicitly decides the extra PR-and-merge cycle isn't worth it for this ship.
