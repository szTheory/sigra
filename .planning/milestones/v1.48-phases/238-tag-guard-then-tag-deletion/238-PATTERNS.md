# Phase 238: Tag Guard, Then Tag Deletion - Pattern Map

**Mapped:** 2026-09-16
**Files analyzed:** 13 (9 certain, 4 conditional on the D-01/Tier-2 probe outcome)
**Analogs found:** 11 / 13

Every analog path below was checked with `git ls-files` and is **git-tracked source** in this
repo (no gitignored mirror, no `.gsd/capabilities/` install copy).

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` | test (prohibition guard) | file-I/O → structural assert | `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` (shape/header/negative-control) + `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` (structured-data subject, both-directions) | **exact** |
| `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` | test fixture (known-bad) | file-I/O | `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` (prose header) + `test/fixtures/prohibitions/p10-manifest-stale-entry.tsv` (data-file fixture) | **exact** |
| `.github/rulesets/tag-namespace.json` | config (committed snapshot of live settings) | file-I/O (read-only subject) | `.github/ci-skip-manifest.tsv` (committed data artifact + prose renderer) and `guides/reference/fix-queue.json` (committed JSON data artifact) | role-match (no `.github/*.json` exists today — new directory) |
| `.planning/decisions/003-tag-delete-list.tsv` | config/data (allowlist) | batch (row-driven) | `.github/ci-skip-manifest.tsv` | **exact** (format + comment-header idiom) |
| `scripts/maintainers/delete-planning-tags.sh` | utility (operator script, destructive) | batch, dry-run default | home: `scripts/maintainers/planning-audit-hygiene.sh`; body idiom: `scripts/ci/admin-autofix-loop.sh` (safety-ruleset header, arg parse, DRY_RUN) + `scripts/ci/capture-fast-01-remeasurement.sh` (`fail()`, preflight, fail-closed `gh`/`jq`) | role-match (dry-run **default** is new; existing scripts default to apply) |
| `.github/workflows/ci-observe.yml` (EDIT — new job `tag_ruleset_drift`) | config (CI workflow job) | request-response (live `gh api`) | `demotion_receipt` job in the same file, `ci-observe.yml:44-80` | **exact** |
| `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md` (EDIT) | doc (ADR amendment) | — | the file itself (no amended-ADR precedent exists; 001/002/003 only) | self-analog |
| `MAINTAINING.md` (EDIT — 2 subsections) | doc (runbook) | — | `MAINTAINING.md:100-124` "Branch protection — enforced required checks (live ruleset)" | **exact** |
| `.planning/phases/238-…/238-TAG-RULESET-RECORD.md` | doc (pre-change settings record) | — | `.planning/phases/237-…/237-PAGES-SETTING-RECORD.md` | **exact** |
| `.planning/phases/238-…/238-EVIDENCE.md` | doc (machine-parsed ledger) | — | `.planning/phases/237-…/237-EVIDENCE.md` + `_lib.mjs:254-262` grammar | **exact** |
| TSV `pre_delete_sha` inventory prose (inside the TSV header / evidence) | doc (pre-mutation ref inventory) | — | `.planning/phases/237-…/237-GIT-OBJECT-SNAPSHOT.md` | **exact** |
| `.planning/REQUIREMENTS.md` (EDIT — REL-01 supersession, **conditional** on probe) | doc | — | the TEST-01/02 supersession precedent named in D-02 (in-file) | role-match |
| Tier-3 only (**conditional**): committed `pre-push` hook + installer script, `on: push: tags` detection workflow | utility + config | event-driven | no hooks infrastructure exists (`core.hooksPath` unset); installer would follow `scripts/ci/*.sh` header idiom; detection workflow follows `ci-observe.yml` job shape | **none (hook)** / role-match (workflow) |

---

## Pattern Assignments

### `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` (test, file-I/O)

**Analog:** `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` (most recent guard,
full file read) — plus `p10-no-undocumented-demotion.test.mjs` for the structured-data-subject shape
and `p12-run-id-provenance.test.mjs` for the offline-by-design header prose.

**Header prose pattern** (`p17:1-39`, `p12:1-20`) — every guard opens with: the prohibition
restated as `MUST NOT …`, a `Subject:` line naming the substitutable artifact, a `Secondary:`
line naming non-substitutable reads, an anti-vacuity note, and a "what silently breaks if this
guard is deleted" paragraph. `p12`'s offline rationale is the sentence `p19` should mirror:

```javascript
// STRUCTURAL AND OFFLINE BY DESIGN. This guard does NOT resolve run IDs against the
// GitHub API, for two reasons: (1) that would put `gh`, a token, and transient 5xx on the
// pull_request critical path, and a red PR for a reason unrelated to the diff is exactly
// the tax this milestone exists to remove; ...
```

**Imports + subject read** (`p17:41-50`; `p10:23-32` for the secondary-artifact form):

```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, stripJsComments, REPO_ROOT } from './_lib.mjs';

const CONFIG_SUBJECT = 'test/example/priv/playwright/playwright.config.ts';
const configText = stripJsComments(readSubject(CONFIG_SUBJECT));
```

For `p19`: `const snapshot = JSON.parse(readSubject('.github/rulesets/tag-namespace.json'));`
— exactly **one** `readSubject` call (the one-substitutable-artifact rule, `_lib.mjs:11-22`);
anything else (the 238 ledger, per RESEARCH Open Question 4) via `readRepoFile`. No prohibition
guard parses JSON today; the `JSON.parse` + explicit-shape-check idiom is in
`scripts/ci/award-guard.mjs:1-40` (header documents each failure condition (a)–(d) by letter).

**Pure-checker pattern** (`p17:63-102`) — returns `null` when clean or a **named explanatory
string**, never a boolean:

```javascript
/**
 * Pure checker over ANY text — ... Returns `null` when clean, or a NAMED, explanatory string
 * when it finds a wrapper. Never returns a boolean: the message is what a reviewer reads ...
 */
function retryWrapperIssue(text) {
  if (/retries\s*:[^\n,}]*process\.env/.test(text)) {
    return 'a `retries` value is read from `process.env` — ...';
  }
  ...
  return null;
}
```

`p19` equivalent: `rulesetShapeIssue(obj)` asserting `target === 'tag'`,
`enforcement === 'active'`, `conditions.ref_name.include`, and the rule's
`operator`/`negate`/`pattern` (D-10). **Do not** assert `bypass_actors` — D-10.

**Non-vacuity floor pattern** (`p17:104-118`, message convention from `_lib.mjs:20-25`):

```javascript
test('the config parse locates a `retries:` line at all (non-vacuity floor)', () => {
  const found = [...configText.matchAll(/\bretries\s*:\s*[^\n,}]+/g)];
  assert.ok(found.length > 0,
    'no `retries:` line found in the config subject — the parse broke, this is not a pass');
});
```

**Negative-control test pattern** (`p17:132-151`) — the cheap second RED proof alongside the
committed fixture; copy verbatim in structure:

```javascript
test('negative control: a fixture reintroducing a retry wrapper fails the guard', () => {
  const fixture = `...`;
  const issue = retryWrapperIssue(fixture);
  assert.ok(issue !== null,
    'a fixture that reintroduces a retry wrapper must fail the guard — a guard that only ' +
      'passes on the real file is not falsifiable');
});
```

**Error-handling pattern:** there is none — guards let `_lib.mjs` throw. `readSubject`
(`_lib.mjs:73-80`) throws `subject not found at ${p} — a missing subject is a broken run, never
an absent violation`. **Ordering consequence for the planner** (RESEARCH "Ordering hazard"):
`p19` must not be committed before `.github/rulesets/tag-namespace.json` exists, or every
intervening commit reds `fast_checks`.

**Wiring:** none. `.github/workflows/ci.yml:392` picks it up:

```yaml
        # A bare directory arg is NOT valid here (node 22 resolves it as a module); the
        # shell glob is load-bearing.
        run: node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```

---

### `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` (test fixture, file-I/O)

**Analog:** `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts:1-12`

**Header-prose pattern** (JSON has no comments — put this text in the *guard's* header and, if a
`.md` sibling is wanted, follow `p12-claim-without-run-id.md`; the p17 prose is the model):

```
// KNOWN-BAD fixture for P17 (236-03). Carries all three retry-wrapper violations at once: ...
// It is structurally valid — a recognisable `defineConfig({...})` with a locatable `retries:`
// line — so every non-vacuity floor passes and the RED comes from `retryWrapperIssue`, never a
// parse-broke message. Never imported or executed — read as text only.
```

Load-bearing rule to copy: the fixture must be **structurally valid** (parses, clears every
non-vacuity floor) so the RED comes from the shape checker, not a parse error. For `p19` that
means valid JSON with `rules: []` or an altered `pattern`/`enforcement: "disabled"`.

**RED proof command** (the `_lib.mjs:11-18` fail-first protocol):
`GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json node --test scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs`

---

### `.planning/decisions/003-tag-delete-list.tsv` (config/data, batch)

**Analog:** `.github/ci-skip-manifest.tsv:1-24`

**Comment-header pattern** (why / how it is consumed / the one-source-of-truth sentence):

```
# Phase 230 (D-23): the honest-skip set, as data.
#
# WHY THIS FILE EXISTS
# ... That enumeration used to live only as prose in MAINTAINING.md. Prose is now a RENDERER
# of this file, not a second source of truth: ...
#
# CONSUMERS
#   - scripts/ci/ci-demotion-observer.sh                   reads the `assert` rows ...
```

Copy the three-block structure verbatim: title line, `WHY THIS FILE EXISTS`, `CONSUMERS`
(for 238: `scripts/maintainers/delete-planning-tags.sh`, ADR 003, Phase 245's `pre_delete_sha`
forward-feed). Then a **tab-separated header row** followed by data rows —
`tag<TAB>local<TAB>remote<TAB>class<TAB>pre_delete_sha<TAB>reason`.
Second precedent for a TSV beside prose: `guides/reference/settled-findings.tsv` (`# finding_id	surface	class	anchor	disposition	waived_by	note`).

**Parser contract to satisfy** (`_lib.mjs:199-224`, `parseSkipManifest`) — if `p19` (or any
future guard) parses the delete list, follow this exact shape: skip blank/`#` lines, require a
named header cell, throw on wrong column count, throw on zero rows:

```javascript
    if (cells.length < 8) {
      throw new Error(`skip-manifest row has ${cells.length} columns, expected 8: ${line}`);
    }
  ...
  if (!sawHeader) {
    throw new Error('skip-manifest has no `tier` header row — the parse broke, this is not a pass');
  }
  if (rows.length === 0) {
    throw new Error('skip-manifest parsed to zero rows — the parse broke, this is not a pass');
  }
```

---

### `scripts/maintainers/delete-planning-tags.sh` (utility, batch/destructive)

**Analogs:** location + shebang: `scripts/maintainers/planning-audit-hygiene.sh:1-2`;
header + arg parse + DRY_RUN: `scripts/ci/admin-autofix-loop.sh:1-68`;
fail-closed preflight + `gh`/`jq`: `scripts/ci/capture-fast-01-remeasurement.sh:1-46`.

**Safety-ruleset header pattern** (`admin-autofix-loop.sh:1-41`) — the closest thing in the repo
to a destructive-operator-script header. Copy the numbered SAFETY RULESET + Usage/Options block:

```bash
#!/usr/bin/env bash
# admin-autofix-loop.sh — apply auto_eligible fix-queue entries as atomic commits, ...
#
# SAFETY RULESET (CRITICAL — do not bypass):
#   (1) One fix per commit (git add -A && git commit).
#   (2) Auto-revert via `git revert --no-edit HEAD` (a NEW commit — NEVER reset/force-push).
#   ...
#   (5) This script must NEVER be wired into any CI lane — it is an operator/nightly tool.
#
# Usage:
#   bash scripts/ci/admin-autofix-loop.sh [--max-fixes N] [--dry-run] [--queue PATH]
#
# DO NOT WIRE THIS SCRIPT INTO ANY CI LANE.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
```

**Arg-parse pattern** (`admin-autofix-loop.sh:57-68`) — note the **inversion** 238 requires:
existing scripts default to apply and opt into `--dry-run`; D-13 demands dry-run **default** with
`--apply` required. Keep the `while/case` shape and the unknown-arg hard exit:

```bash
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-fixes)  MAX_FIXES="$2";      shift 2;;
    --dry-run)    DRY_RUN=1;           shift;;
    *) echo "admin-autofix-loop: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done
```

**Preflight / fail-closed pattern** (`capture-fast-01-remeasurement.sh:13-29`) — named `fail()`
with snake_case reason codes, tool presence checks, and refusal rather than `|| true`
(Pitfall 6: never paper over a remote-delete error):

```bash
usage() { echo "usage: $0 --readiness OUTPUT | ..." >&2; exit 2; }
fail() { echo "capture-fast-01-remeasurement: FAIL: $*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH"
command -v jq >/dev/null 2>&1 || fail "jq not found on PATH"
```

**Dry-run report pattern** (`admin-autofix-loop.sh:375-376`):

```bash
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "admin-autofix-loop: DRY-RUN: would commit ${FINDING_ID} to ${TARGET_FILE}"
```

**Testing:** many `scripts/ci/*.sh` ship a sibling `*.test.sh` (`admin-autofix-loop.test.sh`,
`honest-skip-verdict.test.sh`, `docs-only-receipt.test.sh`) run from `fast_checks`. If a
self-test is wanted for the delete script, that is the shape — but note `scripts/maintainers/`
has no test sibling today and D-13 does not require one.

---

### `.github/workflows/ci-observe.yml` — new job `tag_ruleset_drift` (config, request-response)

**Analog:** the `demotion_receipt` job in the same file, `ci-observe.yml:44-57`.

```yaml
  demotion_receipt:
    name: Demotion receipt (non-PR executed-set evidence, not a merge gate)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    if: ${{ github.event.workflow_run.event != 'pull_request' }}
    permissions:
      contents: read
      actions: read
    env:
      GH_TOKEN: ${{ github.token }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

Copy verbatim: `name:` carrying the "**not a merge gate**" suffix, `timeout-minutes: 5`, the
non-`pull_request` `if:`, explicit `permissions:`, `GH_TOKEN: ${{ github.token }}`, and the
**SHA-pinned** `actions/checkout@3d3c42e5…  # v7.0.1`. Drop `actions: read` (the rulesets read
needs only Metadata, implied by `contents: read`).

**Boundary comment to mirror** (`ci-observe.yml:16-25`) — the new job must restate both the
"observe and report, never in `ci-gate.needs`" boundary and the default-branch caveat:

```yaml
# NOTE: `workflow_run` only ever runs the copy of this file on the DEFAULT BRANCH. It
# therefore does nothing until it merges -- which is correct, because both receipts are
# post-merge observations by construction.
```

Error-reporting idiom in this lane is `echo "::error::…"; exit 1` (see the RESEARCH job sketch);
the `set +e` note at `ci-observe.yml:76-80` explains GitHub's `bash -e {0}` invocation, relevant
if the step wants to inspect a non-zero exit rather than die on it.

---

### `.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md` (doc, EDIT)

**Analog:** the file itself — ADR structure at `003-…:1-6` is
`# ADR NNN: <title>` / `**Status:** Accepted` / `**Date:**` / `**Context:**`, then
`## The footgun` → `## Decision — guardrails to preserve (do NOT regress these)` (numbered) →
`## Status of the residue` → `## Consequences`.

**The clause D-19 amends**, verbatim (`003-…:36-38`):

```markdown
3. **Do not mint milestone `vX.Y` git tags.** Milestone tagging was stopped after `v1.35`
   precisely to eliminate the namespace collision. If milestone marking is ever wanted
   again, use a **distinct namespace** (e.g. `milestone/v1.36`), never bare `v1.36`.
```

Note it already names `milestone/v1.36` — D-19's prescribed `milestone/` namespace is an
extension of existing ADR text, not a new invention. RESEARCH proves the sentence is factually
wrong (`v1.47`, `v1.48` minted after 2026-07-11), so the amendment **corrects**, not just extends.
There is no amended-ADR precedent in `.planning/decisions/` (only 001, 002, 003 exist, none
amended) — D-19's dated `## Amendment — 2026-09-16 (Phase 238)` section with `**Status:**
Accepted` retained is the new precedent.

---

### `MAINTAINING.md` (doc, EDIT — two subsections)

**Analog:** `MAINTAINING.md:100-124`, "Branch protection — enforced required checks (live ruleset)".

```markdown
### Branch protection — enforced required checks (live ruleset)

Branch protection for `main` is enforced via **ruleset 14941512** (`enforcement: active`), not
legacy branch protection rules. ...

To verify the live list at any time: `gh api repos/szTheory/sigra/rulesets/14941512 --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'`
```

Copy: `### ` heading naming the surface and "(live ruleset)", a paragraph stating the enforced
value, a **bolded do-not-break warning**, and a single-line `gh api … --jq` operator one-liner.
The D-11 sibling section goes immediately after this one; the D-13 delete-tags runbook is a
separate `### ` subsection that **points at** `scripts/maintainers/delete-planning-tags.sh`
rather than restating its steps (the `ci-skip-manifest.tsv` "prose renders the data file"
discipline).

---

### `.planning/phases/238-…/238-TAG-RULESET-RECORD.md` (doc, pre-change record)

**Analog:** `.planning/phases/237-…/237-PAGES-SETTING-RECORD.md:1-58` — follow it exactly.

**Frontmatter** (`:1-7`):

```markdown
---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 02
requirement: GREEN-03
decision: D-07
kind: outward-facing-settings-change-record
---
```

**Body pattern** (`:9-20`): title `# <surface> change — pre-change record and revert value`; a
paragraph stating the file exists so the change is reversible "by a **recorded, known value**
rather than by a reconstruction… committed **before** the change is performed"; a paragraph
naming the authorizing decision; then:

```markdown
## PRE-CHANGE STATE — the value to revert to

Captured live at **2026-09-16T13:08:27Z**, before any mutation, with:

```bash
gh api repos/szTheory/sigra/pages
```

Full response payload, verbatim:

```json
{ ... }
```
```

For 238 the payload is `gh api repos/szTheory/sigra/rulesets` plus the by-id call for
`14941512` (the two-step read; the list endpoint omits `conditions`/`rules`/`bypass_actors`).

**Redaction rule** carried from `237-GIT-OBJECT-SNAPSHOT.md:9-14`: the repo is public — replace
any home-directory prefix with `<REDACTED_HOME>` and scrub tokens before commit.

---

### `.planning/phases/238-…/238-EVIDENCE.md` (doc, machine-parsed ledger)

**Analog:** `.planning/phases/237-…/237-EVIDENCE.md:1-55`, with the grammar enforced by
`_lib.mjs:254-262`.

**Structure** (`237-EVIDENCE.md:1-19`): `# Phase NNN Evidence Ledger`, an
`Observed at commit: <sha>` line, a paragraph asserting the observations were captured at that
exact commit on a clean tree, then a **summary table** (`| Slot | What it is | How captured |
Status |`) with anchor links, then one `## BEFORE-*` / `## AFTER-*` section per slot.

**Slot body pattern** (`237-EVIDENCE.md:23-42`) — `Status:` line first, then the fenced producing
command with its output:

```markdown
## BEFORE-PHASE-BASELINE

Status: pending (historical baseline established in `237-RESEARCH.md` …)

```bash
$ gh api repos/szTheory/sigra/pages
{...}
```
```

**Machine contract** (`_lib.mjs:257-262`): heading must match
`/^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/`; `Status:` must be at line start; `captured` /
`pending` are the recognized prefixes; run ids are extracted as `\b(\d{8,12})\b` (a 10-digit
`rule_suite_id` satisfies this naturally). **RESEARCH Pitfall 4 correction:** no guard currently
reads a ledger other than Phase 230's (`p01:19 p03:18 p08:21 p11:29 p12:26 p13:18` all pin
`230-EVIDENCE.md`), so this format is convention-enforced, not machine-enforced, unless `p19`
adds the assertion via `readRepoFile`.

---

### `.github/rulesets/tag-namespace.json` (config, committed snapshot)

**Analog:** no `.json` exists under `.github/` today (`find .github -name '*.json'` → empty), so
this is a new directory. Closest precedents:
- `.github/ci-skip-manifest.tsv` — a committed data artifact under `.github/` whose header
  declares WHY / CONSUMERS and the "prose is a renderer, not a second source of truth" rule.
- `guides/reference/fix-queue.json` + `guides/reference/admin-award-ledger.json` — committed JSON
  data artifacts read by `scripts/ci/*.mjs` guards (`award-guard.mjs:1-26` documents its subject
  and its four failure conditions in the *script*, since JSON cannot carry comments).

Since JSON carries no comment channel, the WHY/CONSUMERS prose that `ci-skip-manifest.tsv` puts
in its own header must live in `p19`'s file header and in `MAINTAINING.md`. Content is the
**verbatim** `gh api repos/szTheory/sigra/rulesets/{id}` payload (D-09), which is what makes the
`ci-observe` `jq -S '{target,enforcement,conditions,rules}'` diff a byte-comparison.

---

## Shared Patterns

### Non-vacuity floors ("the parse broke, this is not a pass")
**Source:** `scripts/ci/prohibitions/_lib.mjs:19-25`; instances at `p17:104-118`, `p10:51-70`,
`p12:28-34`.
**Apply to:** `p19`, and every assertion inside `delete-planning-tags.sh` (RESEARCH explicitly
calls for a positive control before the `diff`-based set-equality, since two empty files diff clean).

```javascript
// NON-VACUITY IS THE POINT
// A guard whose extractor silently matches nothing reports green and protects nothing.
// Every parse below throws rather than returning empty, and every guard asserts a floor
// on what it found. The message convention is borrowed verbatim from
// test/sigra/planning/phase_230_ci_timeouts_test.exs: "the parse broke, this is not a
// pass".
```

### One substitutable subject per guard
**Source:** `_lib.mjs:11-22` + `_lib.mjs:33-38` (`subjectPath`) + `p17:13-16`.
**Apply to:** `p19` — the ruleset snapshot is the subject; the 238 ledger (if asserted) is a
`readRepoFile` secondary.

```javascript
export function subjectPath(defaultRelPath) {
  const injected = process.env.GSD_PROHIB_SUBJECT;
  if (injected && injected.length > 0) return resolve(injected);
  return resolve(REPO_ROOT, archiveAwareRelPath(defaultRelPath));
}
```

### Archive-aware paths for anything under `.planning/phases/`
**Source:** `_lib.mjs:42-67` (`archiveAwareRelPath`) — milestone close moves phase dirs to
`.planning/milestones/v<X.Y>-phases/`.
**Apply to:** the reason D-12 puts the delete list in `.planning/decisions/`; and to any `p19`
reference to `238-EVIDENCE.md` (must go through `subjectPath`/`archiveAwareRelPath`, never a raw
`resolve(REPO_ROOT, '.planning/phases/238-…')`).

### Committed data file + prose renderer
**Source:** `.github/ci-skip-manifest.tsv:1-24`; consumed by `p10` and `ci-demotion-observer.sh`.
**Apply to:** `003-tag-delete-list.tsv` ↔ `delete-planning-tags.sh` ↔ `MAINTAINING.md` runbook
↔ ADR 003 amendment. Exactly one oracle; the other three cite it.

### Fail-closed shell (`set -euo pipefail`, named `fail()`, never `|| true`)
**Source:** `capture-fast-01-remeasurement.sh:1-29`; `admin-autofix-loop.sh:41-47`.
**Apply to:** `delete-planning-tags.sh`. Note `planning-audit-hygiene.sh:23,27` uses `|| true`
for *reporting* loops — that is the wrong idiom for a destructive pass (Pitfall 6: `|| true`
would swallow a genuine ruleset rejection).

### SHA-pinned actions in workflows
**Source:** `ci-observe.yml:57` — `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`.
**Apply to:** the new `tag_ruleset_drift` job (and the Tier-3 detection workflow if it fires).

### Public-repo redaction in committed evidence
**Source:** `237-GIT-OBJECT-SNAPSHOT.md:9-14` (`<REDACTED_HOME>` placeholder).
**Apply to:** `238-TAG-RULESET-RECORD.md`, `238-EVIDENCE.md` (embedded rule-suite JSON).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Committed `pre-push` hook + its installer script (Tier 3, **conditional** on both probes failing) | utility | event-driven | No hooks infrastructure exists at HEAD: `git config core.hooksPath` is unset and `.git/hooks/` holds only `.sample` files. RESEARCH flags this as genuinely new infrastructure and the most expensive tier. Use RESEARCH Pattern 3 plus the `admin-autofix-loop.sh` header/arg-parse idiom for the installer. |
| `.github/workflows/tag-namespace-detect.yml` — `on: push: tags: ['v*']` detection lane (Tier 3, **conditional**) | config | event-driven | No `on: push: tags:` workflow exists in this repo, and ADR 003 guardrail 2 forbids that trigger for *publish*. Nearest structural analog is `ci-observe.yml`'s job body + `scripts/ci/notify-failure-issue.sh` for the "open an issue" half; the trigger block itself has no precedent and must be justified in the ADR amendment. |

---

## Metadata

**Analog search scope:** `scripts/ci/prohibitions/`, `scripts/ci/`, `scripts/maintainers/`,
`test/fixtures/prohibitions/`, `.github/` (workflows + data files), `.planning/decisions/`,
`.planning/phases/237-*/`, `MAINTAINING.md`, `guides/reference/*.tsv|*.json`.
**Files scanned:** 22 read; ~60 enumerated.
**Tracked-source check:** all 15 cited analog paths verified with `git ls-files` (all tracked).
**Pattern extraction date:** 2026-09-16
