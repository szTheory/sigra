---
phase: 209-judgment-level-page-pass
reviewed: 2026-07-01T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - lib/sigra/admin/live/user_sessions_live.ex
  - lib/sigra/admin/live/branding_live.ex
  - lib/sigra/admin/live/audit_index_live.ex
  - scripts/ci/panel-schema-check.sh
  - .github/workflows/ci.yml
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues-found
---

# Phase 209: Code Review Report

**Reviewed:** 2026-07-01
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues-found

## Summary

Phase 209 is dominated by copy/IA/empty-state/component-swap edits across 6 admin LiveViews
plus two CI artifacts: a new `admin_checkpoint_recapture` job in `ci.yml` and a new
`panel-schema-check.sh` validator. I traced every LiveView diff for dropped assigns and
broken bindings, verified the `scope_copy/1` helper and both `<.empty_state>` swaps against
the component contract, and audited the CI job and bash script for quoting, exit-propagation,
and snapshot-guard correctness.

The LiveView edits are correct: no dropped assigns break rendering, both `<.empty_state>`
swaps match the optional `inner_block` slot, the `scope_copy/1` helpers are present and
`@admin_scope` is available at every call site, and the `user_sessions_live` H1 entity
interpolation is guarded by `:if={@detail}` and reuses the exact `page_title` fallback
pattern. No security regressions — all changes are display copy plus one private helper.

Two Warnings stand out. First, the `admin_checkpoint_recapture` job's central mechanism —
"delete impersonation-banner PNGs before `--update-snapshots` so the canary re-appears as
`added`" — does not hold against the `--base HEAD` guard it actually runs: the canary PNGs
are tracked at HEAD, so delete-then-recreate yields `modified` (not `added`), which the guard
forbids. Second, `panel-schema-check.sh` is not wired into CI, so its schema guarantees are
never enforced on any push or PR. Both are documented in detail below alongside four Info nits.

## Warnings

### WR-01: admin_checkpoint_recapture "delete-before-recapture → added" premise is wrong for `--base HEAD`

**File:** `.github/workflows/ci.yml:1785-1861`
**Issue:** The job deletes `impersonation-banner-admin-checkpoints-*.png` before
`--update-snapshots` (step at 1785) on the documented theory that Playwright will then
re-create them as **added** files, which `snapshot-canary-guard.sh` tolerates (guard line
100), rather than **modified**, which it forbids (guard line 104). The guard is then invoked
with `--base HEAD` (ci.yml:1858).

The impersonation-banner PNGs are tracked at HEAD (confirmed via `git ls-files`). The guard
computes changes via `git diff --name-status HEAD` (guard line 79) plus untracked porcelain
(guard line 87). A tracked file that is deleted and then recreated in the *working tree* with
different bytes shows as `M` (modified) vs HEAD — it is neither `A` nor `??`, because the file
exists at HEAD. The "added" re-designation trick only works against a base ref where the file
is **absent** (e.g. `origin/main` before the file was first committed), not against `HEAD`.

Consequently, when CI-rendered bytes differ from the committed baseline, the canary appears as
`modified` and the guard hits line 104 → the job **fails at the gate step**. If CI bytes match
HEAD exactly, delete+recreate produces no diff and the guard passes trivially — but in that
case the delete step is a pointless no-op and the whole recapture PR is empty. Either way the
delete-before-recapture logic does not achieve its stated purpose against `--base HEAD`.

Note the phase's own 209-06 SUMMARY (deviation #2, coverage item D7) already flags that the
`--base origin/main` canary reconciliation is deferred to "when the Plan-01 CI job runs
post-merge." That deferral silently assumes the Plan-01 job re-establishes the canary as
`added`. Per the analysis above, it will not against `--base HEAD` — so the post-merge
resolution path is unproven and D7 (human-judgment) may not resolve as documented.
**Fix:** Either (a) change the guard invocation to compare against a base where the canary is
absent, or (b) drop the delete step and explicitly allow the canary re-baseline for this
one job via a distinct, audited mechanism, or (c) stage the deletion and commit it as a
separate `D` change so the recreate genuinely reads as add-after-delete against that commit.
Concretely, if the intent is "re-baseline the canary once," commit the deletion first:
```bash
# stage + commit the deletion so HEAD no longer has the canary,
# THEN recapture so the guard (vs the new HEAD) sees 'added'
git rm test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-admin-checkpoints-*.png
git commit -m "chore: drop canary baselines for deliberate re-establish [skip ci]"
npx playwright test ... --update-snapshots   # recreates as 'added' vs new HEAD
```
At minimum, add an assertion after `--update-snapshots` that fails loudly if the canary is
`modified`, so the job does not silently proceed on a false premise.

### WR-02: panel-schema-check.sh is never invoked by CI — schema guarantees are unenforced

**File:** `scripts/ci/panel-schema-check.sh:1-189` (and its absence in `.github/workflows/ci.yml`)
**Issue:** The new validator was authored to enforce the persona-JTBD panel schema (frontmatter
shape, lens/question completeness, column-4 integer prohibition), and the 209-02 SUMMARY lists
it under `provides`. But `grep -n "panel-schema-check" .github/workflows/ci.yml` returns no
match — the script is not referenced by any CI job, pre-commit hook, or gate. A schema guard
that never runs provides zero enforcement: a future edit to any panel doc that breaks the
schema (wrong `disposition`, missing lens heading, a bare `0` in the count column) will pass
CI silently. This is dead tooling as shipped.
**Fix:** Wire the validator into `fast_checks` (or a dedicated docs-lint step) so it runs on
PRs that touch `.planning/uat-evidence/v1.42-persona-jtbd/*.md`, e.g.:
```yaml
- name: Validate persona-JTBD panel schema
  run: |
    for f in .planning/uat-evidence/v1.42-persona-jtbd/*.md; do
      bash scripts/ci/panel-schema-check.sh "$f"
    done
```
If enforcement is genuinely out of scope for this phase, record that decision explicitly so the
script is not mistaken for an active gate.

## Info

### IN-01: Dead assign `@summary_posture` in index_live after Total-users removal

**File:** `lib/sigra/admin/live/index_live.ex:29`
**Issue:** Plan 03 removed the `total_users = summary_count(@summary_posture, :total)` binding
and the Total-users chip. `@summary_posture` is still assigned at line 29 but is now referenced
nowhere else in the module — `needs_review` recomputes `summary_group(..., :posture)` inline at
line 34 rather than reading the assign. The assignment is now dead computation. It will not
trigger an unused-assign compile warning (LiveView assigns are not compile-checked like local
variables) and `summary_group/2` is side-effect-free, so this is a quality nit, not a defect.
**Fix:** Either delete the `assign(:summary_posture, ...)` line, or have line 34's
`needs_review` read `assigns.summary_posture` instead of recomputing, so the assign earns its
place.

### IN-02: panel-schema-check.sh column-4 guard only scans kill-count, not tighten-count

**File:** `scripts/ci/panel-schema-check.sh:171-179`
**Issue:** The awk check inspects `$4` only. For a leading-pipe markdown row
(`| surface | disposition | kill-count | tighten-count | doc |`), `awk -F'|'` maps `$4` to the
kill-count cell and `$5` to the tighten-count cell. The 209-02 SUMMARY states the intent is
that "kill-count / tighten-count expressed as none/xN" — i.e. both count columns should be
protected from bare `0/1/2`. As written, a bare integer in the tighten-count column (`$5`)
slips through. Incomplete coverage of the stated invariant.
**Fix:** Extend the guard to also test `$5` (and any other count columns), e.g.
`f = $4; g = $5; if (f ~ /^[012]$/ || g ~ /^[012]$/) { ... }`.

### IN-03: panel-schema-check.sh emits FAIL diagnostics to stdout, not stderr

**File:** `scripts/ci/panel-schema-check.sh:40-163` (python block)
**Issue:** The bash `fail()` helper writes to stderr (line 29), but every FAIL/print inside the
embedded python block writes to **stdout** (bare `print(...)`). Exit propagation is correct
(verified: `sys.exit(1)` aborts the script under `set -e`), so this is not a correctness bug —
but mixing failure diagnostics between stdout and stderr is inconsistent with the rest of the
script and complicates log filtering in CI.
**Fix:** Route python failure messages to stderr: `print(..., file=sys.stderr)`.

### IN-04: Warmup readiness loop cannot fail the job when the app never boots

**File:** `.github/workflows/ci.yml:1768-1784`
**Issue:** The `for i in $(seq 1 30)` readiness loop breaks on the first successful curl but has
no `else`/failure branch — if the app never responds within 30s, the loop exits normally and the
job proceeds to `--update-snapshots`, which then fails with an opaque Playwright connection error
instead of a clear "app never booted" message. (This mirrors the cloned `admin_design_recapture`
prelude, so it is pre-existing behavior, not net-new to this phase.)
**Fix:** Track readiness and fail fast, e.g.:
```bash
ready=0
for i in $(seq 1 30); do
  if curl -sf http://localhost:4000/ > /dev/null; then ready=1; break; fi
  sleep 1
done
[ "$ready" = 1 ] || { echo "app failed to boot within 30s"; cat /tmp/example-checkpoint-recapture-server.log; exit 1; }
```

---

_Reviewed: 2026-07-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
