---
phase: 185-audit-infrastructure
reviewed: 2026-06-14T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - test/example/lib/example_web/live/admin/design_gallery_live.ex
  - test/example/lib/example_web/router.ex
  - test/example/lib/example_web/components/layouts/root.html.heex
  - test/sigra/install/design_gallery_isolation_test.exs
  - test/example/priv/playwright/tests/admin-design.spec.ts
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/snapshot-allowlist-design
  - scripts/ci/quality-ledger-monotonic.sh
  - scripts/ci/snapshot-canary-guard.sh
  - scripts/ci/snapshot-recapture-gate.sh
  - .github/workflows/ci.yml
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 185: Code Review Report

**Reviewed:** 2026-06-14
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed all 11 source files changed in phase 185 (audit-infrastructure): the design
gallery LiveView, router extension, root layout CSS repair, D-04 isolation test, the
admin-design Playwright spec, playwright.config.ts project trio, snapshot allowlist,
and three CI bash scripts (quality-ledger-monotonic.sh, snapshot-canary-guard.sh,
snapshot-recapture-gate.sh), plus the ci.yml additions.

The overall structure is sound. Auth defence-in-depth on the dev-gated route is correct
(plug-level pipeline plus LiveView on_mount). The CI wiring for `quality_ledger_monotonic`
and the design drift guard is correctly connected to `ci-gate`. The canary guard's
`slug_of()` sed alternation is correct (longest suffix first: `chromium` before `mobile`
before `dark`). The D-04 isolation test correctly catches design gallery artifacts in
the installer tree.

Two warnings are raised: `quality-ledger-monotonic.sh` calls `awk` instead of `gawk`,
making it silently broken on macOS (the documented dev platform). The
`snapshot-recapture-gate.sh` shares `ALLOW_ARGS` across the checkpoint and design lanes,
making design-only (or checkpoint-only) recaptures impossible without manually bypassing
the gate. Two info items address a silent false-negative risk in the D-04 test and a
documentation ambiguity around slug normalisation.

## Warnings

### WR-01: `quality-ledger-monotonic.sh` uses `gensub()` via `awk`, not `gawk` — fails on macOS

**File:** `scripts/ci/quality-ledger-monotonic.sh:23-26`

**Issue:** `extract_tiers()` calls `gensub()` inside an `awk` invocation. `gensub()` is a
GNU awk extension (gawk). On macOS, the system `awk` is BSD awk (version 20200816), which
does not implement `gensub()`. Running the script locally on macOS produces:

```
awk: calling undefined function gensub
 input record number 1, file
 source line number 2
```

CI is unaffected because `ubuntu-latest` provides gawk as the default `awk`. However,
this project's development environment is macOS (confirmed by platform: darwin in env),
so `scripts/ci/quality-ledger-monotonic.sh --base HEAD` is broken for every developer
who tries to run it locally. The 185-02 SUMMARY explicitly notes "no POSIX fallback
needed" for CI, but does not acknowledge the macOS breakage.

**Fix:** Replace `gensub()` with a POSIX-compatible trim using `gsub()` (available in all
awk implementations):

```bash
extract_tiers() {
  grep -E '^\| [a-z]' | awk -F'|' '{
    item=$2; gsub(/^ +| +$/, "", item)
    tier=$4; gsub(/^ +| +$/, "", tier)
    if (tier ~ /^[012]$/) print item ":" tier
  }'
}
```

This eliminates the gawk dependency without changing behaviour. Alternatively, replace
`awk` with `gawk` everywhere in the script and document the `brew install gawk`
prerequisite for local use.

---

### WR-02: `snapshot-recapture-gate.sh` shares `ALLOW_ARGS` between checkpoint lane (b) and design lane (b2) — design-only recaptures always fail

**File:** `scripts/ci/snapshot-recapture-gate.sh:25-53`

**Issue:** `ALLOW_ARGS` is built from all positional arguments (`$@`) and then passed with
`--require-all` to **both** the checkpoint canary guard (step b) and the design lane canary
guard (step b2). `--require-all` fails if any declared slug did not change in the target
snapshot directory.

Because checkpoint and design boards live in separate snapshot directories with different
filenames, any slug that is a design board (e.g. `board-stat`) is absent from the
checkpoint snapshots directory. Step (b) then fails with:

```
snapshot-canary-guard: FAIL: declared intended delta 'board-stat' did not change
```

The reverse is equally true: a checkpoint-only slug (e.g. `impersonation-banner`) causes
step (b2) to fail against the design snapshots directory. In practice there is no slug
that appears in both directories, so any recapture invocation targeting only one lane
will fail mid-gate and the gate is broken for single-lane re-recording.

**Fix:** Add a `--design-slugs` / `--checkpoint-slugs` split, or define two separate
`ALLOW_ARGS` arrays built from distinct argument prefixes. The simplest fix is a convention
where slugs starting with `board-` are routed to the design lane only:

```bash
declare -a CHECKPOINT_ALLOW=()
declare -a DESIGN_ALLOW=()
for s in "$@"; do
  if [[ "$s" == board-* ]]; then
    DESIGN_ALLOW+=(--allow "$s")
  else
    CHECKPOINT_ALLOW+=(--allow "$s")
  fi
done
```

Then pass `CHECKPOINT_ALLOW` to step (b) and `DESIGN_ALLOW` to step (b2). Update the
usage comment and `README` to document the convention.

---

## Info

### IN-01: D-04 isolation test silently passes when installer template directory is absent

**File:** `test/sigra/install/design_gallery_isolation_test.exs:20-21`

**Issue:** The test uses a relative `@installer_template_root` path and calls
`Path.wildcard/1`:

```elixir
@installer_template_root "priv/templates/sigra.install"

offenders =
  Path.wildcard("#{@installer_template_root}/**/*")
  |> Enum.filter(&String.contains?(&1, "design"))
```

`Path.wildcard/1` returns `[]` when the directory does not exist. If the installer
template directory is ever renamed, moved, or the test is run from a wrong working
directory, `offenders` is always `[]` and the assertion always passes — without the guard
having actually checked anything. This is a silent false negative.

**Fix:** Assert that the template root directory exists before scanning it:

```elixir
test "no design gallery artifact exists in installer template tree (D-04)" do
  assert File.dir?(@installer_template_root),
         "Installer template root missing: #{@installer_template_root}"

  offenders =
    Path.wildcard("#{@installer_template_root}/**/*")
    |> Enum.filter(&String.contains?(&1, "design"))

  assert offenders == [],
         "Design gallery artifacts found in installer template tree (D-04 violation):\n" <>
           Enum.join(offenders, "\n")
end
```

---

### IN-02: Allowlist slug normalisation (underscore → hyphen) is implicit and undocumented

**File:** `test/example/priv/playwright/snapshot-allowlist-design:1-14`

**Issue:** Board IDs in the spec (`board-stat_link`, `board-summary_chip`) contain
underscores, but Playwright normalises underscores to hyphens in PNG filenames
(`board-stat-link-admin-design-chromium.png`). The `slug_of()` function strips the
project suffix from the PNG filename, so slugs in the allowlist must use the
**hyphenated** form (`board-stat-link`), not the underscore form from the spec source
(`board-stat_link`).

The allowlist is currently empty (steady state), so this creates no immediate bug.
However, the allowlist comment block does not mention this normalisation, and an operator
adding a slug by copying the board ID from the spec will write the wrong key and the
canary guard will not treat the intended change as allowed.

**Fix:** Add a note to the allowlist header:

```
# Slugs use Playwright's filename normalisation: underscores become hyphens.
# e.g. board-stat_link in the spec → board-stat-link as the slug here.
```

---

_Reviewed: 2026-06-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
