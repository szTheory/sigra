---
phase: 238-tag-guard-then-tag-deletion
reviewed: 2026-09-17T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - .github/rulesets/tag-namespace.json
  - .github/workflows/ci-observe.yml
  - .gitignore
  - MAINTAINING.md
  - scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs
  - scripts/maintainers/delete-planning-tags.sh
  - test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json
findings:
  critical: 1
  warning: 2
  info: 6
  total: 9
status: issues_found
remediation: 5 fixed, 3 deferred to todos, 1 confirmed-unreachable and not fixed by decision
remediated: 2026-09-17
---

# Phase 238: Code Review Report

**Reviewed:** 2026-09-17
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Seven files reviewed: the committed ruleset snapshot, the `tag_ruleset_drift` observer job, a
`.gitignore` addition, the two new `MAINTAINING.md` runbook sections, the `p19` offline contract
guard, the operator deletion script, and the known-bad fixture.

Verified clean (no finding raised), because the prompt asked and the answer is genuinely "not an
issue":

- **No prohibited history verb anywhere.** `git gc`, `git reflog expire`, `git prune` and
  `--prune-now` appear in none of the seven files. The only occurrence of the word "prune" is the
  prose prohibition at `scripts/maintainers/delete-planning-tags.sh:30`.
- **No secrets, tokens, or home-directory paths** in any reviewed file (grepped for
  `/Users/`, `ghp_`, `github_pat_`, `HEX_API_KEY`, `token =`). The repo is public; nothing leaks.
- **No path can delete a tag outside the allowlist.** Both delete call sites
  (`delete-planning-tags.sh:185`, `:212`) take the row's first field verbatim; there is no glob,
  prefix expansion, or `git tag -d $(...)` anywhere, and the pre-pass validation loop (`:146-149`)
  hard-fails the whole run if any row names a three-component release tag or an `archive/` tag.
  Reporting-by-default (`APPLY=0`, `:87`, `:152`) is correctly implemented.
- **`set -euo pipefail` is present** (`:59`), the script is `shellcheck 0.11.0` clean
  (verified with a positive control), `mktemp -d` is trap-cleaned (`:118-119`), every expansion is
  quoted, and TSV parsing is fail-closed on a missing/wrong header (`:133`), a wrong column count
  (`:138`), and a zero-row parse (`:144`). Exit codes are coherent (1 for a failure, 2 for usage).
- **The fnmatch shape claim is NOT overclaimed.** `MAINTAINING.md:137-139` states in so many words
  that this is "a *shape* guard, not a SemVer validator" and enumerates `v1.2.3.4`, `v1.a.b`,
  `v1..` and `v...` as admitted. `p19` likewise asserts only the literal glob string, never
  SemVer-ness. Nothing in the code or the docs claims more than the guard does.
- **`p19` runs green** (19/19 tests) and the ledger it reads parses to exactly the 10 slots
  `DECLARED_LEDGER_SLOT_COUNT` declares. `readSubject(` appears exactly once, honouring the
  one-substitutable-subject rule.
- **The `.gitignore` addition** (`.gitignore:77-80`) is a correctly root-anchored, commented,
  single-purpose entry. Clean.
- **The ruleset snapshot JSON** is valid, matches the described Tier-2 shape field for field, and
  contains nothing sensitive. Clean.

One critical fail-open in the remote delete pass, two warnings, six info items follow.

## Critical Issues

### CR-01: The remote delete pass silently converts an unreachable origin into "already gone", exits 0, and prints a false success receipt

**File:** `scripts/maintainers/delete-planning-tags.sh:162-165` (the `|| true`), consumed at
`:197` and acted on at `:201-205`

**Issue:** `list_remote()` ends with `> "$1" || true`. With `pipefail` set, a failing
`git ls-remote --tags origin` (DNS failure, offline, revoked credential, 403, renamed remote)
makes the whole pipeline non-zero — and the `|| true` swallows it, leaving an **empty** listing
file. `run_remote_pass` then calls `list_remote` (`:197`) with **no non-vacuity floor**, so every
`remote=yes` row misses the `grep -qxF` membership test at `:201` and is reported as:

```
  absent  <tag> (already gone on origin; skipped, not an error)
```

The pass then prints `remote pass done — deleted=0 absent=N would_delete=0` and exits **0**.

This directly violates the script's own stated safety invariant, SAFETY RULESET item (4) at
`:22-24`: *"A delete that fails for any reason other than the tag already being absent ABORTS the
pass with a named reason and a non-zero exit. The status is never suppressed."* Here a
non-absence failure is suppressed and is actively **relabelled as absence** — the one thing the
invariant names as the permissible skip.

Reproduced against a scratch repo with an unresolvable `origin`:

```
fatal: unable to access 'https://example.invalid/nope.git/': Could not resolve host: example.invalid
  absent  v1.4 (already gone on origin; skipped, not an error)
delete-planning-tags: remote pass done — deleted=0 absent=1 would_delete=0
EXIT=0
```

The `fatal:` line reaches stderr, but the script's own summary and exit status both claim success.
For a tool whose entire stated value is "the auditability of a one-shot destructive operation"
(`:27-29`), a receipt that reads `deleted=0 absent=21` when in fact nothing was even looked at is
the exact failure this script exists to prevent. Honest mitigation: in the documented four-step
sequence (`MAINTAINING.md:184-187`) the subsequent `verify-remote` **does** catch it — that path
has the `NON_VACUITY_FLOOR` check at `compare_side:241` and fails with `remote_listing_empty`
(verified). But the script is committed as durable, re-runnable, copyable tooling, and a re-runner
who runs only the `remote` pass gets a clean green.

**Fix:** give the remote listing its own fail-closed floor rather than relying on the next pass.

```bash
list_remote() {
  local raw="${WORK}/ls-remote.raw"
  git ls-remote --tags origin > "$raw" || fail "ls_remote_failed: origin unreachable or refused — this is not 'no tags'"
  sed 's#.*refs/tags/##' "$raw" | grep -v '\^{}' > "$1" || true   # grep -v exit 1 == genuinely empty
}
```

and, in `run_remote_pass` after `list_remote "$present"` (`:197`), add the same non-vacuity floor
the verify pass already has:

```bash
  [[ "$(grep -c . "$present" || true)" -ge "$NON_VACUITY_FLOOR" ]] \
    || fail "remote_listing_empty: origin advertised zero tags — refusing to call every row 'absent'"
```

## Warnings

### WR-01: The verify keep-sets will red on tag namespaces the ruleset itself permits (`milestone/`, `proof/`)

**File:** `scripts/maintainers/delete-planning-tags.sh:64-65`, against `MAINTAINING.md:140-142`

**Issue:** The asymmetry the prompt asked about is correct in the direction it was designed for —
`KEEP_LOCAL_RE` (`:64`) carries `archive/.*`, `KEEP_REMOTE_RE` (`:65`) does not, and `archive/` is
local-only, so a shared expression would fail `verify-remote`. Both are properly anchored
(`^...$`), neither over-matches, and `archive/.*` cannot escape the `archive/` namespace. That part
is sound.

The defect is a contract mismatch with the guard shipped alongside it. `MAINTAINING.md:140-142`
states that because the scope selector is fnmatch with `FNM_PATHNAME`, *"the `archive/`,
`milestone/` and `proof/` namespaces are outside the rule entirely"* — i.e. the ruleset actively
**permits** creating `milestone/x` and `proof/x` tags. But `KEEP_LOCAL_RE` admits only
`v<n>.<n>.<n>[suffix]` and `archive/.*`. The moment anyone creates a `milestone/` or `proof/` tag
that the server-side guard is documented as allowing, `verify-local` fails with
`local_set_not_equal_to_keep_set` and the operator is looking at a drift alarm for a tag the
runbook told them was fine. Same for `verify-remote`, which does not even admit `archive/`.

Today no such tag exists locally (only `archive/*` and `v*.*.*`), so this is latent, not live — but
the script is documented as durable tooling, and the two documents disagree about what a clean
repository looks like.

**Fix:** either widen the keep expressions to the namespaces `MAINTAINING.md` declares
out-of-scope, or amend the runbook to say the verify passes intentionally demand a *stricter*
set than the ruleset enforces and that any new namespace must be added to both regexes:

```bash
KEEP_LOCAL_RE='^(v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?|(archive|milestone|proof)/.*)$'
KEEP_REMOTE_RE='^(v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?|(milestone|proof)/.*)$'
```

### WR-02: The runtime-joined field name defeats the textual gate it routes around, leaving that gate unable to prove its own claim

**File:** `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs:312` (documented at `:50-59`),
against the gate at `.planning/phases/238-tag-guard-then-tag-deletion/238-03-PLAN.md:169`

**Issue:** The gate is
`b=$(grep -v "^//" "$f" | grep -c "bypass_actors"); test "$b" -eq 0`, and its stated purpose is to
prove *the checker never asserts the bypass actor list*. The guard file complies by building the
field name as `['bypass', 'actors'].join('_')` at `:312`.

The **intent** is honoured: `rulesetShapeIssue` (`:122-194`) genuinely never touches that field, and
the test at `:306-317` asserts the opposite of an assertion — that mutating it still yields `null`.
Verified by reading the checker line by line. So this is not a masked violation.

What is defective is the gate. Once the codebase establishes "route around the grep with a runtime
join" as an accepted idiom, the grep can no longer distinguish a compliant file from a
non-compliant one: a future edit could add `if (obj[['bypass','actors'].join('_')].length) return ...`
*inside `rulesetShapeIssue`* — a genuinely vacuous CI assertion, exactly what D-10 forbids — and the
gate would still report 0 and pass. A textual gate whose subject file has been taught to evade it
textually proves nothing going forward. Secondary cost: a maintainer grepping the repo for
`bypass_actors` (the natural way to find every consumer of that field) will not find this file,
which is the one file with the most important thing to say about it.

Impact is bounded — the gate is a one-shot plan-level verification command, not a committed CI
lane — but the idiom is now committed and will be copied.

**Fix:** make the gate structural instead of textual, so the test may use the literal name. E.g.
scope the grep to the checker function's body rather than the whole file, or replace it with a
behavioral assertion that the committed guard returns `null` for a snapshot differing only in that
field (which `:306-317` already is). Then restore the literal `bypass_actors` at `:312` and delete
the six-line apologia at `:50-59`.

## Info

### IN-01: The known-bad fixture's second declared violation is never actually exercised

**File:** `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json:7,10` and
`scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs:331-347`

**Issue:** The fixture is genuinely distinguishable from the real snapshot and does clear every
floor as claimed (it is an object, has `target: "tag"`, has a non-empty `rules` array), so the RED
proof is valid. But `rulesetShapeIssue` short-circuits: the `enforcement` check (`:144-149`)
precedes the `exclude` check (`:159-168`), so the fixture always returns the *enforcement* message
and its second violation — `exclude: ["refs/tags/v*"]` widened to equal `include`, described at
`:64-67` as the headline scenario — is never reached. The test only asserts `issue !== null` plus
"not a floor message", so it cannot notice. The widened-exclude case is covered separately by the
inline test at `:281-290`, so coverage exists; the fixture's own prose just overstates what the
fixture proves.

**Fix:** assert the exact message in the fixture test (`assert.ok(issue.includes('\`enforcement\`'))`),
and either split the fixture in two or amend the `:61-68` prose to say the second violation is
documentary rather than asserted.

### IN-02: The keep-set regexes reject a SemVer tag carrying both prerelease and build metadata

**File:** `scripts/maintainers/delete-planning-tags.sh:64-65`

**Issue:** The suffix group is `([-+][0-9A-Za-z.-]+)?`. The character class omits `+`, so
`v1.2.3-rc.1+build.5` — a valid SemVer string, and exactly the shape of a tag the release
automation could mint during a deletion window (the scenario `:53-58` says the suffix group exists
to tolerate) — does not match and would be reported as drift by both verify passes.

**Fix:** `([-+][0-9A-Za-z.+-]+)?`.

### IN-03: `tag_ruleset_drift`'s most likely failure mode aborts before its own named error, and the ruleset list is unpaginated

**File:** `.github/workflows/ci-observe.yml:204-209`

**Issue:** The trigger condition *can* fire (`workflow_run` on a `CI` completion whose
`.event != 'pull_request'` — i.e. any push to `main`), the action is SHA-pinned (`:199`),
`timeout-minutes: 5` is set (`:194`), and `permissions: contents: read` (`:196-197`) is the right
least privilege for a metadata-scope ruleset read. Two smaller issues:

1. Under `set -euo pipefail` (`:203`), a failing `gh api` (403, 5xx, network) aborts at the
   `ID=$(...)` assignment on `:204`, so the carefully worded `::error::the tag-namespace ruleset is
   ABSENT ... has been silently removed` at `:207` is reachable only when the call *succeeds* and
   returns no match. The common transient failure therefore produces an unlabelled red rather than
   a diagnosable one.
2. `gh api "repos/.../rulesets"` is not paginated (no `--paginate`), so it reads only the first 30
   rulesets. If the repository ever exceeds one page, the name lookup returns `null` and the job
   raises a **false** "the server-side guard has been silently removed" alarm.

**Fix:** add `--paginate`, and wrap the read so a call failure gets its own message:

```bash
RULESETS=$(gh api --paginate "repos/${GITHUB_REPOSITORY}/rulesets") \
  || { echo "::error::could not read repos/${GITHUB_REPOSITORY}/rulesets (API error, not a drift verdict)"; exit 1; }
ID=$(jq -r '[.[]|select(.name=="tag-namespace")][0].id' <<<"$RULESETS")
```

### IN-04: Loop-body git commands inherit the TSV as stdin

**File:** `scripts/maintainers/delete-planning-tags.sh:185`, `:212` (loops closed at `:190`, `:223`)

**Issue:** Both delete loops read from `< "$ROWS"`, so `git tag -d` and `git push origin --delete`
inherit the remaining allowlist rows as their stdin. Neither reads stdin in normal operation, but
`git push` over SSH can spawn helpers, and a helper that reads stdin would consume allowlist rows
and silently skip them — a classic while-read-loop hazard in a script whose correctness depends on
every row being visited.

**Fix:** append `</dev/null` to both delete invocations, or switch the loops to a file descriptor
(`while ... done < "$ROWS"` → `while ... done 3< "$ROWS"` with `read -u 3`).

### IN-05: Tag names are passed to git without an end-of-options separator

**File:** `scripts/maintainers/delete-planning-tags.sh:185`, `:212`

**Issue:** `git tag -d "$tag"` treats a leading-dash value as an option — verified: `git tag -d "-f"`
exits 129 with a usage dump, while `git tag -d -- "-f"` correctly reports `tag '-f' not found`.
**This is currently unreachable**: git refuses to create refnames beginning with `-`, and the
`git rev-parse -q --verify "refs/tags/${tag}"` precheck at `:174` short-circuits such a row to
`absent` before the delete is attempted. Recorded as hardening only, because the file is documented
as copyable operator tooling.

**Fix:** validate the tag field in the pre-pass loop (`:146-149`) alongside the existing release-tag
and archive-tag rejections:

```bash
  [[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || fail "allowlist_row_tag_not_a_plain_refname: $tag"
```

### IN-06: The runbook's fnmatch caveat omits the closest near-miss to the recurrence class

**File:** `MAINTAINING.md:140-142`

**Issue:** The `FNM_PATHNAME` paragraph correctly notes that `*` does not cross `/`, and names
`archive/`, `milestone/`, `proof/` and `phase-NNN-*` as outside the rule. It does not name the case
nearest to the class the guard exists to block: a `v`-prefixed tag *containing a slash*, e.g.
`v1.4/notes`, is not matched by `include: refs/tags/v*` at all and so is creatable, despite being a
two-component milestone-shaped name under the `v` prefix. The claim at `:135-137` — "a tag name
under the `v` prefix that does **not** carry three dot-separated segments cannot be created" — is
false for that case. (`delete-planning-tags.sh`'s verify passes would flag such a tag, so the hole
is not unguarded end-to-end, just undocumented.)

**Fix:** add `v1.4/notes` to the enumerated admitted examples at `:138-139`, or qualify `:135-137`
with "…that contains no `/`".

---

_Reviewed: 2026-09-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---

## Remediation — 2026-09-17 (orchestrator, code-review gate)

Each finding below was re-verified against the source by the orchestrator before being acted on;
nothing was fixed or deferred on the reviewer's say-so alone.

| ID | Verdict | Outcome |
|---|---|---|
| CR-01 | Confirmed | **Fixed** — `list_remote` now runs `git ls-remote` alone and hard-fails on non-zero (`remote_listing_failed`); `run_remote_pass` gained the same non-vacuity floor `compare_side` already had (`remote_listing_empty`). RED proof re-run in a scratch clone with an unresolvable `origin`: was `deleted=0 absent=1`, exit 0 — now `FAIL: remote_listing_failed`, exit 1, no ref touched. |
| WR-01 | Confirmed (latent) | **Fixed in docs** — `MAINTAINING.md` now states that the script's keep-set is deliberately narrower than the ruleset permits, names `milestone/` and `proof/` as the affected namespaces, and says to widen the expression in the same commit that adopts one. The regexes themselves were left alone: both are anchored and neither over-matches. |
| WR-02 | Confirmed | **Deferred** — todo `2026-09-17-p19-bypass-actors-literal-…`. The gate it routes around lives in an executed plan's verify block; replacing it is a contract change, not a defect fix. |
| IN-01 | Confirmed | **Deferred** — todo `2026-09-17-p19-known-bad-fixture-short-circuits-…`. |
| IN-02 | Confirmed | **Fixed** — keep-set suffix class widened to `([-+][0-9A-Za-z.+-]+)?` so `v1.2.3-rc.1+build.5` reads as a keep-set member, not drift. |
| IN-03 | Confirmed | **Deferred** — todo `2026-09-17-tag-ruleset-drift-observer-has-never-run-…`. Editing a workflow that has never executed trades one unverified state for another; the fix and its first observation belong in the same pass. |
| IN-04 | Confirmed | **Fixed** — `</dev/null` on the three loop-body git commands so none can consume the TSV the `while read` loop is iterating. |
| IN-05 | Confirmed unreachable | **Not fixed, by decision.** The reviewer verified git refuses such refnames and the `:174` precheck short-circuits first. Adding `--` to `git push --delete` is not cleanly supported, so the change would be asymmetric and unprovable. Recorded here rather than filed. |
| IN-06 | Confirmed | **Fixed** — `MAINTAINING.md` now names the `v1.4/notes` near-miss and states the absolute claim holds only for names without `/`. A false absolute in a brand-new runbook is the exact failure ADR 003's guardrail 3 was amended for this phase. |

**Post-remediation proof:** `shellcheck` clean (positive-controlled — a deliberately bad script
exits 1 first), `bash -n` clean, prohibitions suite 90/90 across 18 files (positive-controlled on
the glob), all four script passes re-run read-only (`verify-local` 13=13 set-equal, `verify-remote`
12=12 set-equal, dry-run `local` absent=39, dry-run `remote` absent=21 — the last now trustworthy
because the new floor proves the listing was real). Tags unchanged at local=13 / remote=12; no ref
was touched and no history verb was run.
