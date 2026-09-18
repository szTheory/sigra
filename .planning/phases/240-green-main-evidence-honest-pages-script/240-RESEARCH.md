# Phase 240: Green-Main Evidence + Honest Pages Script - Research

**Researched:** 2026-09-18
**Domain:** GitHub Actions evidence capture (REST `/jobs` endpoint), defensive shell for the Pages REST API, offline prohibition guards, todo/issue closure bookkeeping
**Confidence:** HIGH (every claim below is a file+line read this session or a live command run this session; the two exceptions are labelled `[ASSUMED]`)

## Summary

This phase has an unusually small unknown surface. `240-CONTEXT.md` already folded a prior
research pass into 28 locked decisions, so the remaining gaps were implementation-readiness gaps,
not analysis gaps. All eight were closed by direct reads.

Three findings materially change what a planner should write, and none of them contradicts a
locked decision:

1. **The `/jobs`-endpoint collector D-11 asks for already exists.** D-12 names
   `capture-fast-01-remeasurement.sh` as the model, and it is the right model for the *runs*
   half — but `scripts/ci/capture-terminal-ratification-evidence.sh` already implements the
   *jobs* half, including the exact `total_count`-vs-length assertion D-11 demands
   (`total_count_disagreement`, `:70`) and a generic `collect_pages`/`validate_manifest` pair that
   works against either endpoint (`:78-97`, `:56-76`). Copying *that* file's pagination core is
   cheaper and closer to D-11 than re-deriving it from fast-01.
2. **The D-03 parity guard is cheap — `p15` already has the step-list parser.**
   `p15-pages-publisher-seeds-before-boot.test.mjs:40-56` contains a `stepList(jobBlockText)`
   function that splits a job block into ordered `{name, hasCondition, text}` records, and
   `_lib.mjs` exports `jobBlock(workflowText, jobId)` (`:179`) and `stripYamlComments` (`:128`).
   A step-name-sequence equality guard between `ci.yml#generated_admin_playwright_smoke` and
   `green-04-evidence.yml`'s job is roughly 60 lines of new code plus one fixture. Ship it.
3. **A 20-leg matrix will collide on the artifact name.** The copied job uploads
   `name: generated-admin-report` (`ci.yml:1497`, `:1506`) and
   `name: generated-admin-failure-diagnostics` (`:1518`, `:1527`). `actions/upload-artifact` at
   the pinned v7 major errors on a duplicate artifact name within one run, so a byte-faithful
   copy under `matrix.repeat: [1..20]` fails on leg 2. The copy must suffix every artifact name
   with `-${{ matrix.repeat }}` — the one deliberate, documented deviation from D-02.

Beyond that: `p12` is confirmed hardcoded to phase 230 and will **not** parse `240-EVIDENCE.md`
in CI; the completed Pages todo still carries `status: pending` in its own frontmatter; and the
phase contains four operator-credentialed actions an agent cannot perform unattended.

**Primary recommendation:** Structure the phase as four ordered plan groups — (A) the Pages
script rewrite + its new `.test.sh` + the D-03 parity guard + `green-04-evidence.yml` +
`capture-green-04-evidence.sh`, all fully agent-doable and offline; (B) merge to `main`; (C) the
single operator dispatch at final committed HEAD on a clean tree, then the capture run; (D) the
evidence ledger write and the #231/todo closures. Group C is the only hard ordering constraint
and it is the one that cannot be automated away.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| n≥20 repeat execution | GitHub Actions (CI) | — | Only the real runner topology proves the lane; a local repeat proves nothing about `ci-gate` |
| Run/job conclusion read | GitHub REST API via `gh` | Shell collector | D-08: job conclusion, never run conclusion |
| Evidence canonicalisation | Shell + `jq` (`scripts/ci/`) | — | Repo idiom: `capture-*.sh` emits canonical JSON, fail-closed |
| Evidence narrative | `.planning/phases/.../240-EVIDENCE.md` | — | Human-readable slot grammar; the JSON is the receipt, the MD is the claim |
| Pages source reconciliation | Shell (`scripts/ci/`) invoked from a publisher job | GitHub REST API | Already the location; SC-3 only changes its error posture |
| Structural invariants | `scripts/ci/prohibitions/*.test.mjs` (offline) | — | Standing constraint 5: never `mix ci`, never live API on the PR lane |
| Issue/todo closure | Operator + `gh` CLI | `.planning/todos/` file moves | Credentialed, irreversible-ish, last in the phase (D-24) |

## Project Constraints (from CLAUDE.md)

- **GSD workflow enforcement:** all edits go through a GSD command; no direct repo edits outside one.
- **`MIX_ENV=test mix ci` is the local gate** before every push — root `mix test` misses formatting and `test/example`. (Also ROADMAP standing constraint 3.)
- **`mix test` needs a live Postgres** (`scripts/db/up.sh`, `tmp/db.env`) and the **phx_new 1.8.8** archive, or `golden_diff_test` byte-diffs spuriously.
- **Testing:** comprehensive coverage — happy path, main error cases, boundary conditions; AAA style, flat, self-contained.
- **Public repo:** no adopter PII in committed artifacts (memory rule; relevant because the evidence ledger quotes API payloads).

## ROADMAP standing constraints that bind this phase (`.planning/ROADMAP.md:32-40`)

| # | Constraint | Consequence here |
|---|-----------|------------------|
| 1 | One live-external observation per phase; count-only acceptance rejected | Satisfied by the dispatch + `gh api` reads; a `wc -l` of run ids is **not** acceptance |
| 2 | Evidence captured at final committed HEAD on a clean tree | = D-13; drives plan ordering |
| 3 | `mix ci`, never root `mix test`, before every push | Every plan's pre-push gate |
| 5 | New prohibition guards go in `scripts/ci/prohibitions/*.test.mjs`, never `mix ci` | The D-03 parity guard's home; picked up by the glob at `ci.yml:393` |
| 6 | A guard never observed RED does not count — committed known-bad fixture under `test/fixtures/prohibitions/` | The D-03 guard needs `test/fixtures/prohibitions/p20-*.yml` (next free id is **p20**; `p18` is already absent from the directory, see below) |

**Guard id note [VERIFIED: `ls scripts/ci/prohibitions/`]:** the directory holds `p01`–`p17` and
`p19` — there is **no `p18`**. Fixtures directory mirrors this (`p01`..`p13`, `p17`, `p19`). A new
guard should take **`p20`**, not `p18`; reusing a skipped id invites "was this deleted or never
born?" ambiguity.

---

## 1. D-02 source material: the exact `generated_admin_playwright_smoke` shape

**Job span confirmed [VERIFIED: `.github/workflows/ci.yml` job-header line map]:**
`generated_admin_playwright_smoke:` begins at **line 1401**; the next job (`ci-gate:`) begins at
**line 1534**. So the job body is **1401–1533**, exactly as CONTEXT states.

### Job-level keys to reproduce

| Key | Value (verbatim) | Copy verdict |
|-----|------------------|--------------|
| `name:` | `Generated admin Playwright smoke` | **Must change** — see hazard below |
| `runs-on:` | `ubuntu-latest` | copy |
| `timeout-minutes:` | `15` | copy |
| `needs:` | `release_ref_guard` | **CANNOT copy** — job absent in the new workflow |
| `services.postgres` | `image: postgres:15`, `env.POSTGRES_PASSWORD: postgres`, `ports: ['5432:5432']`, `options: >- --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5` | copy verbatim |
| workflow-level `permissions` | `contents: read` (`ci.yml:36-37`) | copy at workflow level |
| workflow-level `concurrency` | `group: ${{ github.workflow }}-${{ github.event.pull_request.number \|\| github.run_id }}`, `cancel-in-progress: true` (`ci.yml:53-55`) | **Do not copy** — see hazard below |

### The 11 steps, in order (1401–1533)

| # | Step `name` (or `uses`) | Key fields |
|---|---|---|
| 1 | *(unnamed)* `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` | — |
| 2 | *(unnamed)* `erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124  # v1.24.1` | `with: version-file: .tool-versions`, `version-type: strict` |
| 3 | *(unnamed)* `actions/setup-node@820762786026740c76f36085b0efc47a31fe5020  # v7.0.0` | `with: node-version: '20'`, `cache: 'npm'`, `cache-dependency-path: 'test/example/priv/playwright/package-lock.json'` |
| 4 | `Install Hex + Rebar` | `run: mix local.hex --force` / `mix local.rebar --force` |
| 5 | `Install phx_new archive` | `run: mix archive.install --force hex phx_new 1.8.8` |
| 6 | `Install Playwright deps` | `working-directory: test/example/priv/playwright`, `run: npm ci` |
| 7 | `Install Playwright browsers` | `working-directory: test/example/priv/playwright`, `run: npx playwright install --with-deps chromium webkit` |
| 8 | `Run generated admin acceptance smoke` | `env: PGUSER: postgres, PGPASSWORD: postgres, PGHOST: localhost, GITHUB_WORKSPACE: ${{ github.workspace }}`; `run: scripts/ci/admin-acceptance-smoke.sh --test all` |
| 9 | `Collect curated generated-host admin screenshots` | `if: always()`, `working-directory: test/example/priv/playwright`, multi-line `run:` (`mkdir -p artifacts/admin-checkpoints/`, `compgen -G "test-results/**/admin-*.png"`, `src_count=$(find … \| wc -l)`, `find … -exec cp -n {} artifacts/admin-checkpoints/ \;`, `ls -la … \|\| true`) |
| 10a | `Upload generated admin review bundle (main, 14d retention)` | `if: always() && github.ref == 'refs/heads/main'`; `uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1`; `name: generated-admin-report`; `path:` the two dirs; `retention-days: 14` |
| 10b | `Upload generated admin review bundle (PR/push, 7d retention)` | `if: always() && github.ref != 'refs/heads/main'`; same artifact `name`; `retention-days: 7` |
| 11a | `Upload generated admin failure diagnostics (main, 14d retention)` | `if: failure() && github.ref == 'refs/heads/main'`; `name: generated-admin-failure-diagnostics`; `path: test/example/priv/playwright/test-results/`; `retention-days: 14` |
| 11b | `Upload generated admin failure diagnostics (PR/push, 7d retention)` | `if: failure() && github.ref != 'refs/heads/main'`; same artifact `name`; `retention-days: 7` |

`[VERIFIED: .github/workflows/ci.yml:1401-1533]` — read verbatim this session.

### What CANNOT be copied verbatim (the D-02 flag list)

| Item | Line | Why it cannot be copied as-is | Required deviation |
|---|---|---|---|
| `needs: release_ref_guard` | `ci.yml:1421` | `release_ref_guard` does not exist in `green-04-evidence.yml`; an unresolvable `needs:` is a workflow-validation error | **Drop it.** Its purpose (`ci.yml:78-96`: `workflow_dispatch` on `ci.yml` must use `refs/tags/v*`) is replaced by D-01's `if: github.ref == 'refs/heads/main'` |
| Artifact `name: generated-admin-report` ×2 | `ci.yml:1497`, `:1506` | A 20-leg matrix uploads the same artifact name 20× in one run; `actions/upload-artifact` v4+ (the pin here is v7) **errors** on a duplicate name rather than merging | Suffix: `name: generated-admin-report-${{ matrix.repeat }}` |
| Artifact `name: generated-admin-failure-diagnostics` ×2 | `ci.yml:1518`, `:1527` | same | `…-${{ matrix.repeat }}` |
| `github.ref == 'refs/heads/main'` retention split (4 steps) | `:1496`, `:1505`, `:1517`, `:1526` | Not *broken* — the job-level `if` already pins the workflow to `main`, so the `!= 'refs/heads/main'` legs are dead | **Recommend:** keep all four verbatim for byte-faithfulness, or collapse to the main-only pair and comment why. Either is defensible; collapsing is a step-list divergence the D-03 guard must then be taught to allow |
| Job `name: Generated admin Playwright smoke` | `ci.yml:1402` | `ci.yml:559-565` documents that a bare matrix suffixes the job name → `Generated admin Playwright smoke (1)`. Reusing the string in a *different workflow* does not orphan the required check (job names are workflow-scoped), but it makes the SC-1 harvest ambiguous and the SC-2 `main`-window read noisy | Use a distinct name, e.g. `Generated admin Playwright smoke (GREEN-04 repeat)`; the collector then selects by that name and can never accidentally ingest a real `ci.yml` job |
| workflow `concurrency` block | `ci.yml:53-55` | Group key references `github.event.pull_request.number`, meaningless on a dispatch-only workflow; `cancel-in-progress: true` would let a second dispatch cancel an in-flight evidence run mid-matrix | **Omit entirely.** Both existing dispatch-only evidence workflows omit `concurrency` [VERIFIED: `fast-01-remeasurement-evidence.yml`, `generated-app-login-runtime-proof.yml` — neither declares it] |

**No other blockers found.** The step bodies reference **no** `needs.*` output, **no**
`github.event.pull_request.*`, and **no** matrix context. `steps.<id>.outputs` is not used
anywhere in the range. The only contexts touched are `github.workspace` and `github.ref`.
`[VERIFIED: ci.yml:1401-1533, read in full]`

### Precedent that validates D-01's shape

`generated-app-login-runtime-proof.yml` [VERIFIED: read in full] is exactly this pattern already
accepted in-repo: `on: workflow_dispatch`, workflow-level `permissions: contents: read`, one
named job with the same `services.postgres` block byte-for-byte, the same checkout and setup-beam
SHA pins, `mix archive.install --force hex phx_new 1.8.8`, a generated-host script invocation, a
receipt-validation step, and an `if: always()` artifact upload. It does **not** carry
`if: github.ref == 'refs/heads/main'`; `fast-01-remeasurement-evidence.yml:11` does
(`if: github.ref == 'refs/heads/main'` at **job** level, not workflow level — that is the shape
D-01 should copy).

---

## 2. The capture-script template shape

### Recommended base: `capture-terminal-ratification-evidence.sh`, not `capture-fast-01-remeasurement.sh`

D-12 names fast-01 as the model. That is correct for the *runs* endpoint and for the
canonical-JSON/`schema_version` idiom. But the **jobs**-endpoint half D-08/D-11 require is already
implemented, generically, in the sibling collector:

| D-11 requirement | Where it already exists | Line |
|---|---|---|
| `?per_page=100&page=N` on every call | `request_page()` — `gh api "${endpoint}&per_page=100&page=${page}"` | `capture-terminal-ratification-evidence.sh:47` |
| `total_count` vs summed item length | `if ([.[0:-1][].body[$key] \| length] \| add // 0) == .[0].body.total_count then . else error("total_count_disagreement")` | `:70` |
| `total_count` stability across pages | `error("total_count_changed")` | `:68` |
| terminal empty page proof | `error("absent_terminal_empty_page")` | `:69` |
| contiguous, non-duplicate pages | `error("non_contiguous_or_duplicate_page")` | `:66` |
| no empty non-terminal page | `error("nonterminal_empty_page")` | `:71` |
| duplicate item id | `error("duplicate_item_id")` | `:74` |
| pagination bound | `minimum_pages=$(( (total + 99) / 100 + 1 ))`, `MAX_PAGES` | `:87-88` |
| generic over endpoint + item key | `collect_pages "$endpoint" "$item_key" "$label" "$manifest"` | `:78` |
| a real `/jobs` call site | `collect_pages "repos/${REPO}/actions/runs/${run_id}/jobs?" jobs "jobs-${run_id}" "$manifest"` | `:123` |

`[VERIFIED: scripts/ci/capture-terminal-ratification-evidence.sh, read in full]`

**Recommendation:** lift `request_page` / `validate_manifest` / `collect_pages` verbatim into
`capture-green-04-evidence.sh` (a copy, not a shared library — the repo's collectors are
deliberately standalone), and take the *canonical-output* idiom (`schema_version`, `--slurpfile`,
`jq -S -n`, temp-file-then-`mv -f`) from fast-01. Record the dual provenance in the header
comment; this satisfies D-12's intent (model on an existing collector, do not extend fast-01)
without re-deriving pagination logic that is already hardened.

### Skeleton a planner can hand to an executor

```bash
#!/usr/bin/env bash
# Capture the GREEN-04 n>=20 dispatch window. No caller-configurable repo/workflow/job.
set -euo pipefail

REPO="szTheory/sigra"
EVIDENCE_WORKFLOW="green-04-evidence.yml"   # SC-1 population
CI_WORKFLOW="ci.yml"                        # SC-2 population
JOB_NAME="Generated admin Playwright smoke (GREEN-04 repeat)"   # SC-1 selector
CI_JOB_NAME="Generated admin Playwright smoke"                  # SC-2 selector
JOBS_FILTER="latest"                        # D-11: chosen explicitly, never defaulted
MIN_LEGS=20
MAX_PAGES=10000

fail() { echo "capture-green-04-evidence: FAIL: $*" >&2; exit 1; }
# 1. argument surface: --output PATH --run-id <dispatch run id> --main-window-start <UTC>
# 2. command -v gh / jq  (fail-closed)
# 3. rate-limit preflight: gh api rate_limit -> .resources.core.remaining > 250
# 4. clean-tree + HEAD assertion (D-13):
#      [[ -z "$(git status --porcelain)" ]] || fail "dirty_tree"
#      [[ "$(gh api repos/$REPO/actions/runs/$RUN_ID --jq .head_sha)" == "$(git rev-parse HEAD)" ]] \
#        || fail "evidence_run_head_sha_is_not_final_committed_head"
# 5. collect_pages "repos/$REPO/actions/runs/$RUN_ID/jobs?filter=$JOBS_FILTER" jobs …
# 6. collect_pages "repos/$REPO/actions/workflows/$CI_WORKFLOW/runs?branch=main&created=$START..$END" workflow_runs …
#    then, per main run, collect_pages "repos/$REPO/actions/runs/$id/jobs?filter=$JOBS_FILTER" jobs …
# 7. jq -e schema assertions (fail-closed)
# 8. jq -S -n canonical emission to a temp file in the output dir, then mv -f
```

### What must CHANGE relative to the runs-endpoint collectors

| Concern | Runs endpoint (fast-01) | Jobs endpoint (this script) |
|---|---|---|
| Envelope key | `.workflow_runs` | `.jobs` |
| Default `per_page` | 30 (same) — but fast-01 hardcodes `per_page=100` inline in the URL (`:60`) | Must pass `per_page=100` **and** assert `total_count`; **`ci.yml` expands to exactly 30 jobs** (CONTEXT live finding), i.e. exactly at the silent-truncation boundary |
| `filter` parameter | n/a | `filter=latest` (default) vs `filter=all` (includes superseded re-run attempts). **Set it explicitly** per D-11 |
| Selection | by `.event == "pull_request"` | by `.name == $job_name` — D-08's "read the job, not the run" |
| Identity assertion | `.id`, `.conclusion`, `.created_at`, `.updated_at` chronology | `.id`, `.name`, `.conclusion`, and the skipped-job exemption for `started_at`/`completed_at` nullability (`capture-terminal-ratification-evidence.sh:126`) |
| Population assertion | ≥10 PR runs | **≥20 matrix legs**, all with `.conclusion == "success"`, `unique | length == 20` on `matrix.repeat` |
| Cross-check | — | Each leg's parent run id must equal the single dispatch run id |
| `no conclusion` rows | tolerated for non-PR events | **fail-closed** — an in-progress leg means the capture ran too early |

### Canonical JSON shape to emit

```json
{
  "schema_version": "sigra.green-04-evidence/v1",
  "repository": "szTheory/sigra",
  "head_sha": "<git rev-parse HEAD>",
  "clean_tree": true,
  "sc1": {
    "workflow": "green-04-evidence.yml",
    "dispatch_run_id": 0,
    "job_name": "…",
    "jobs_filter": "latest",
    "legs": [{"run_id": 0, "job_id": 0, "matrix_repeat": 1, "url": "", "conclusion": "success"}],
    "leg_count": 20,
    "verdict": "pass"
  },
  "sc2": {
    "workflow": "ci.yml",
    "branch": "main",
    "window": {"start": "…Z", "end": "…Z"},
    "runs": [{"run_id": 0, "url": "", "run_conclusion": "failure",
              "jobs": [{"name": "…", "conclusion": "…"}]}],
    "ci_gate_conclusions": {"success": 0, "failure": 0, "skipped": 0},
    "flake_attributable_red_count": 0,
    "caveat": "example_unit_smoke is absent from ci-gate.needs (ci.yml:1547-1557)"
  }
}
```

### The EVIDENCE.md slot writing

Do **not** have the shell script write `240-EVIDENCE.md`. Neither existing collector does — both
emit JSON only and leave the ledger to the plan's own prose step. The ledger is authored by the
executor from the JSON, following the grammar in §3.

---

## 3. The p12 evidence-slot grammar contract

### The exact grammar (from the parser, not from the example)

`[VERIFIED: scripts/ci/prohibitions/_lib.mjs:254-294]`

- **Slot heading:** `SLOT_HEADING_RE = /^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/` — a level-2
  heading, the literal `BEFORE-` or `AFTER-` prefix, then **uppercase letters, digits and hyphens
  only**. Lowercase or underscores do not parse as a slot. Any *other* `^##` heading terminates
  the current slot.
- **Slot body** = every line until the next `##` heading. The `Status:` line lives inside the body.
- **Status:** first match of `/^Status:\s*(.+)$/m` in the body.
- **Status grammar** (`p12-run-id-provenance.test.mjs:44`):
  `/^(captured \((run|runs) [\s\S]+\)|pending \(.+\))$/` — so exactly
  `captured (run <…>)` / `captured (runs <…>)` / `pending (<reason>)`. Note `captured` with **no**
  parenthetical (as `AFTER-P17-GUARD-OBSERVED` uses in `236-EVIDENCE.md`) **fails** this regex —
  the ledger passes today only because p12 runs against the *230* ledger, not the 236 one. Do not
  copy that bare-`captured` form into 240.
- **Run ids:** `/\b(\d{8,12})\b/g` over the slot text. Backticks around the id are fine (`\b`
  matches at the backtick boundary).
- **Corroboration rule** (`p12:…"each captured slot Status run ID also appears in that slot body"`):
  every id named in `Status:` must occur **≥2 times** in the slot text. Because `s.text` includes
  the `Status:` line itself, this means **the Status occurrence plus at least one more** — the id
  must reappear in a command or an output block.
- **Fenced blocks:** `/```[\s\S]*?```/g`. Every `captured` slot needs ≥1, and at least one fenced
  block must contain `ci-run-metrics.sh` or match `/\bgh (run|pr|api)\b/`.
- **Pending slots:** `Status:` must match `/pending \(.*obligation.*\)/i` — the literal word
  *obligation* — and the slot must still carry ≥1 fenced block (the command to run later).
- **Non-vacuity floors:** `slots.length >= 4` and `captured.length >= 3`.
- **Hard throw:** zero slots parsed → `Error('evidence ledger parsed to zero BEFORE-*/AFTER-* slots')`.

### Is p12 hardcoded to phase 230? — CONFIRMED

`[VERIFIED: scripts/ci/prohibitions/p12-run-id-provenance.test.mjs:26]`

```js
const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const slots = parseEvidenceSlots(readSubject(LEDGER));
```

`readSubject` → `subjectPath` (`_lib.mjs:33-38`) returns `process.env.GSD_PROHIB_SUBJECT` when set,
else `REPO_ROOT + archiveAwareRelPath(LEDGER)`. So:

- **In CI, p12 will NOT parse `240-EVIDENCE.md`.** The CONTEXT claim (and todo
  `2026-09-15-p12-evidence-guard-is-pinned-to-phase-230.md`) is correct. Writing 240's ledger in
  p12 grammar is a *convention*, mechanically unenforced, unless the plan does one of:
  1. run `GSD_PROHIB_SUBJECT=.planning/phases/240-.../240-EVIDENCE.md node --test --test-reporter=tap scripts/ci/prohibitions/p12-run-id-provenance.test.mjs` as an evidence step (agent-doable, offline, zero workflow edit); **or**
  2. generalise p12 to a ledger glob — which is **Phase 241's call** per CONTEXT's deferred list, not 240's.
- **If option 1 is chosen, 240-EVIDENCE.md must clear p12's own floors**: ≥4 `BEFORE-*`/`AFTER-*`
  slots and ≥3 `captured`. A two-slot ledger fails not on grammar but on the non-vacuity floor.
  Budget the slot set accordingly, e.g. `BEFORE-PAGES-LENIENT`, `AFTER-PAGES-LOUD-RED`,
  `AFTER-GREEN-04-N20`, `AFTER-CI-GATE-MAIN-WINDOW`, `AFTER-ISSUE-231-CLOSED` (5 slots, ≥3 captured).
- `archiveAwareRelPath` (`_lib.mjs:49-68`) means a milestone archive move of `.planning/phases/240-…`
  is handled automatically — no future breakage from that direction.

---

## 4. The Pages script rewrite surface

`[VERIFIED: scripts/ci/ensure-github-pages-legacy-branch.sh, 76 lines, read in full]`

### Line-exact map

| Lines | What it is | D-xx | Disposition |
|---|---|---|---|
| `:9` | `set -euo pipefail` | — | keep |
| `:11` | `REPO="${GITHUB_REPOSITORY:?…}"` | — | keep |
| `:12-16` | no-token early `exit 0` | D-22 | **keep**, add reason comment |
| **`:18`** | `if ! pages_json=$(gh api "repos/${REPO}/pages" 2>/dev/null); then` | **D-14/D-15/D-16** | **REWRITE** — lenient site #1: any-error → create |
| `:19-31` | create-branch: echo, `POST /pages`, echo, build trigger, `exit 0` | — | body reused under the new `404` arm |
| **`:30`** | `gh api "…/pages/builds" --method POST >/dev/null 2>&1 \|\| true` | **D-22** | **LEAVE ALONE** + reason comment (swallow #1) |
| `:34-37` | `jq` presence check → `exit 1` | — | keep (already loud) |
| `:39-41` | `bt` / `branch` / `path` extraction | — | keep |
| `:43-46` | `build_type == workflow` → `exit 0` | — | keep (legitimate no-op) |
| `:48-52` | already `gh-pages` `/` → build trigger, `exit 0` | D-20 | keep — **this is the arm that fires today**, which is why the 403 branch is unreachable |
| **`:50`** | build-trigger swallow | **D-22** | **LEAVE ALONE** + reason comment (swallow #2) |
| `:54-65` | echo + `mktemp` + `trap` + PUT body heredoc | — | keep |
| **`:66`** | `if ! put_out=$(gh api "…/pages" --method PUT --input "${put_body}" 2>&1); then` | **D-17/D-18** | **REWRITE** — merged `2>&1` blob |
| **`:67-70`** | `grep -qE '403\|Resource not accessible by integration'` → echo → `exit 0` | **D-17** | **REWRITE** — unanchored `403` matches inside `documentation_url`, request ids, rate-limit numbers, a 500 body |
| `:71-72` | echo body, `exit 1` | — | subsumed by the `*)` arm |
| `:74` | success echo | — | keep |
| **`:75`** | final build-trigger swallow (last line of file) | **D-22** | **LEAVE ALONE** + reason comment (swallow #3) |

The three `|| true` swallows are therefore at **`:30`, `:50`, `:75`** — CONTEXT D-22 says "`:31`,
`:52`, final line", which is off by one on the first two (those are the `exit 0` lines that follow
each swallow). Cosmetic; flagged so a plan citing D-22 uses the right line numbers.

### Live `gh api -i` behaviour — re-verified this session

Probed with real requests at **gh 2.95.0** (`gh --version`):

```
$ gh api -i repos/microsoft/TypeScript/pages   # 404
rc=1
stdout line 1: HTTP/2.0 404 Not Found
stdout: headers …, blank line, {"message":"Not Found","documentation_url":"…","status":"404"}
stderr: gh: Not Found (HTTP 404)

$ gh api -i repos/torvalds/linux/actions/permissions   # 403
rc=1
stdout line 1: HTTP/2.0 403 Forbidden
stdout: headers …, blank line, {"message":"You must have repository read permissions …","documentation_url":"…","status":"403"}
stderr: gh: You must have repository read permissions … (HTTP 403)
```

`[VERIFIED: live commands run 2026-09-18]`. This confirms every channel D-21 enumerates, and adds
two details a stub must reproduce:

1. The wire version is literally `HTTP/2.0` (not `HTTP/2`), so an anchored match must be
   `HTTP/[0-9.]+ <code>` or a field-2 `awk` read.
2. The JSON error body carries **no trailing newline**, and the `documentation_url` value contains
   the digits of no status — but `"status":"404"` **does** contain a bare number, which is exactly
   the class of false positive `:67`'s unanchored `grep -qE '403'` is vulnerable to.

Also confirmed live: `gh api repos/szTheory/sigra/pages` returns
`{"status":"built", …, "build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}` — so the
`:48` arm fires and the PUT is unreachable on the real repo. **D-20's "stub, not live" is forced,
not preferred.** `[VERIFIED: live `gh api repos/szTheory/sigra/pages`, 2026-09-18]`

### Proposed replacement — site #1 (`:18`, per D-15/D-16)

```bash
# D-16: on a PUBLIC repo GET /pages needs no admin, so 404 genuinely means
# "no Pages site configured" -- GitHub's 404-masking-403 policy covers private
# resources only. Live-probed across 8 public repos (240-RESEARCH.md §4).
# Anything that is neither 200 nor 404 is a real failure and must be loud:
# the prior `2>/dev/null` form treated 403/422/500/rate-limit/network-blip as
# "no site yet" and fell through to POST-create.
get_out="$(gh api -i "repos/${REPO}/pages" 2>/dev/null || true)"
get_status="$(printf '%s' "${get_out}" | head -n 1 | awk '{print $2}')"
case "${get_status}" in
  200)
    pages_json="$(printf '%s' "${get_out}" | sed -n '/^\r\{0,1\}$/,$p' | tail -n +2)"
    ;;
  404)
    echo "ensure-github-pages-legacy-branch: no Pages site yet; creating legacy gh-pages / ..."
    gh api "repos/${REPO}/pages" --method POST --input - <<'JSON'
{ "build_type": "legacy", "source": { "branch": "gh-pages", "path": "/" } }
JSON
    echo "ensure-github-pages-legacy-branch: created."
    # D-22: build triggers stay lenient on purpose -- reddening the publisher on a
    # transient build-trigger failure is a red for a reason unrelated to the diff.
    gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
    exit 0
    ;;
  *)
    echo "ensure-github-pages-legacy-branch: GET /pages returned '${get_status:-<no status line>}'; refusing to guess." >&2
    printf '%s\n' "${get_out}" >&2
    exit 1
    ;;
esac
```

**Two sharp edges in that snippet a planner should know about:**
- `head -n 1 | awk '{print $2}'` on empty input yields the empty string, which falls to `*)` and
  exits 1 — correct fail-closed behaviour for "gh itself did not run".
- Header/body separation: the blank line may be `\r\n`-terminated. The `sed -n '/^\r\{0,1\}$/,$p'`
  form above handles both. An alternative that dodges the problem entirely: issue **two** calls —
  `gh api -i … --silent` for the status, then a plain `gh api …` for the body. Costs one extra
  request against a 5000/hr budget. `[ASSUMED]` that either is acceptable to reviewers; the
  single-call form is fewer moving parts.

### Proposed replacement — site #2 (`:66-73`, per D-17/D-18/D-19)

```bash
# D-18: `-i` is required, not stylistic -- a successful PUT /pages returns
# 204 No Content with an EMPTY body, so the status line is the only signal and
# `--jq` is bypassed entirely on an error response. `gh` exits 1 for ANY HTTP
# failure, so rc cannot discriminate 403 from 404 from 500.
put_out="$(gh api -i "repos/${REPO}/pages" --method PUT --input "${put_body}" 2>/dev/null || true)"
put_status="$(printf '%s' "${put_out}" | head -n 1 | awk '{print $2}')"
case "${put_status}" in
  204|200)
    echo "ensure-github-pages-legacy-branch: updated."
    ;;
  403)
    # D-19: the caller declares permissions {contents: write, pages: write}
    # (playwright-github-pages.yml:36-38). `pages: write` permits REQUESTING a
    # build but is not repo-admin, which is why a settings-source PUT legitimately
    # 403s. This one status stays tolerable; every other status is now loud.
    echo "ensure-github-pages-legacy-branch: Pages API PUT returned 403 (pages:write is not repo-admin). gh-pages push already ran; set Settings -> Pages -> branch gh-pages / manually." >&2
    exit 0
    ;;
  *)
    echo "ensure-github-pages-legacy-branch: PUT /pages returned '${put_status:-<no status line>}'." >&2
    printf '%s\n' "${put_out}" >&2
    exit 1
    ;;
esac
# D-22: swallow #3 -- see the note at the create arm.
gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
```

**Note on SC-3's wording.** ROADMAP SC-3 says the script "**fails loudly** on a 403". D-19 keeps
the PUT-403 tolerable. These are reconcilable and the phase must say so in writing: SC-3's defect
is that a 403 was *indistinguishable from every other failure*; the fix makes 403 a named,
single, commented arm and makes everything else exit 1. The RED demonstration SC-3 asks for is
then **the `*)` arm firing on a 500/422**, plus the **GET-side 403** now exiting 1 instead of
silently POST-creating. A plan that implements D-19 without stating this will read as
contradicting its own success criterion. *(This is a wording tension, not a decision conflict —
see "Decision conflicts" below.)*

---

## 5. The fake-`gh` stub harness idiom

### Mechanism (identical in both precedents)

`[VERIFIED: scripts/ci/capture-terminal-ratification-evidence.test.sh:1-20, 60-125;
scripts/ci/capture-fast-01-remeasurement.test.sh:1-45, 49-95]`

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/ci/ensure-github-pages-legacy-branch.sh"
test -x "$SCRIPT"                     # or: bash "$SCRIPT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_GH_LOG"     # call log -> assert WHICH calls were made
... dispatch on "$*" and "${FAKE_MODE:-ok}" ...
EOF
chmod +x "$TMP/bin/gh"

FAKE_MODE=put_403 FAKE_GH_LOG="$TMP/calls" PATH="$TMP/bin:$PATH" \
  GITHUB_REPOSITORY=owner/name GH_TOKEN=stub bash "$SCRIPT" >"$TMP/out" 2>"$TMP/err"
```

The five load-bearing pieces:
1. **`PATH="$TMP/bin:$PATH"`** prepended per-invocation (never exported globally).
2. **`FAKE_MODE`** selects the scenario; `${FAKE_MODE:-ok}` is the happy default.
3. **`FAKE_GH_LOG`** receives `"$*"` on every call — this is how the test asserts *negative*
   facts ("the create POST was never issued", `test "$(grep -c '/jobs?' … )" -eq 0`).
4. **`set +e` / capture `$?` / `set -e`** around every expected-failure invocation, then
   `test "$RC" -ne 0` and `grep -q '<error token>' "$TMP/*.err"` — asserting the *reason*, not
   just non-zero. (`capture-terminal-ratification-evidence.test.sh:96-104`.)
5. A terminal `echo "<name>.test: PASS"` (fast-01 idiom, `:95`).

### Stub modes D-21 requires, plus three more the rewrite needs

| Mode | Stub emits | Expected script behaviour |
|---|---|---|
| `get_200_already_gh_pages` (default `ok`) | GET: `HTTP/2.0 200 OK` + headers + blank + `{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}`, rc 0 | exits 0, "already gh-pages /", **no PUT in the call log** |
| `get_404` | GET: `HTTP/2.0 404 Not Found` + body + `gh: Not Found (HTTP 404)` on stderr, rc 1 | POST-create fires, exits 0 |
| **`get_403`** | GET: `HTTP/2.0 403 Forbidden` + `{"message":"Resource not accessible by integration","documentation_url":"…","status":"403"}` + stderr line, rc 1 | **exit 1**, body echoed to stderr, **no POST-create in the call log** (this is the D-15 regression guard) |
| `get_500` | `HTTP/2.0 500 Internal Server Error` + an HTML-ish body containing the digits `403` somewhere | **exit 1** — the D-17 false-positive guard: proves a bare `403` in a body no longer reads as "expected 403" |
| **`put_204`** (mandatory per D-21) | GET: 200 with `source.branch: "main"`; PUT: `HTTP/2.0 204 No Content` + headers + **empty body**, rc 0 | exits 0, "updated." — this is the case a body-parsing implementation gets wrong |
| **`put_403`** | GET 200 branch=main; PUT: all four channels of a real 403 | exit **0**, the documented tolerable message on **stderr** |
| `put_422` / `put_500` | GET 200 branch=main; PUT non-403 failure | exit 1, body echoed |
| `no_token` | — (`GH_TOKEN` and `GITHUB_TOKEN` unset) | exit 0, "no GH_TOKEN/GITHUB_TOKEN; skip.", **zero gh calls logged** |
| `build_type_workflow` | GET 200 with `"build_type":"workflow"` | exit 0, "not changing", no PUT |

The four-channel 403 payload the stub must emit verbatim (matching the live probe in §4):

```bash
printf 'HTTP/2.0 403 Forbidden\r\n'
printf 'Content-Type: application/json; charset=utf-8\r\n'
printf '\r\n'
printf '{"message":"Resource not accessible by integration","documentation_url":"https://docs.github.com/rest/pages/pages#update-information-about-a-apiname-pages-site","status":"403"}'
echo 'gh: Resource not accessible by integration (HTTP 403)' >&2
exit 1
```

### Where the new `.test.sh` gets RUN — an open wiring decision

`[VERIFIED: grep for `.test.sh` across `.github/workflows/`]` — **19** shell self-tests are wired
as individual `fast_checks` steps (`ci.yml:216, 224, 234, 243, 251, 256, 261, 270, 279, 300, 302,
310, 312, 340, 352, 361, 370, 382, 400`). Each is a named step with an explanatory comment, e.g.:

```yaml
      - name: Notify-failure-issue self-test
        # Phase 222 Plan 02 (HARD-01/HARD-02/D-07): hermetic proof that the shared
        # tracking-issue notifier is idempotent … No real `gh` CLI or network call.
        run: bash scripts/ci/notify-failure-issue.test.sh
```

But **`capture-fast-01-remeasurement.test.sh` and `capture-terminal-ratification-evidence.test.sh`
have NO CI caller** — they exist and are runnable, but nothing in `.github/workflows/` invokes
them, and `mix ci`'s alias (`mix.exs:149-157`) does not either. (`capture-fast-01-remeasurement.sh`
itself is pinned by `test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs`, which
is what D-12 means by "hardcoded protected constants".)

**Implication for planning:** a new `ensure-github-pages-legacy-branch.test.sh` that is not wired
into `fast_checks` is a self-test nobody runs — the exact class of defect this milestone exists to
remove. Adding one `fast_checks` step is a `ci.yml` edit; standing constraint 5 forbids `mix ci`
changes and routes *prohibition guards* to the glob, but it says nothing against adding a
`fast_checks` self-test step, and 19 precedents exist. **Recommend wiring it.** The new
`capture-green-04-evidence.test.sh`, by contrast, may follow the unwired capture-collector
precedent — but say so explicitly rather than leaving it unstated.

---

## 6. The D-03 parity guard — cost/benefit call: **SHIP IT**

### Why it is cheap

Everything the guard needs already exists and is exported:

| Need | Available | Line |
|---|---|---|
| Split a workflow into job blocks | `jobBlocks(workflowText)` | `_lib.mjs:93` |
| Fetch one job's block by id | `jobBlock(workflowText, jobId)` | `_lib.mjs:179` |
| Strip comments so prose cannot fake a match | `stripYamlComments(text)` | `_lib.mjs:128` |
| Read a second repo file (not the subject) | `readRepoFile(relPath)` | `_lib.mjs:80` |
| Ordered step records `{name, hasCondition, text}` | `stepList(jobBlockText)` — copy from p15 | `p15-…test.mjs:40-56` |
| Fail-first injection | `readSubject(default)` + `GSD_PROHIB_SUBJECT` | `_lib.mjs:33-38, 70-78` |
| Zero-workflow-edit pickup | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | `ci.yml:393` |

The p15 precedent is a near-exact structural twin: it already compares a step list extracted from
one workflow against an ordering invariant, with a pure `…Issue(steps)` checker function so the
real subject and the known-bad fixtures run through identical code
(`p15-…test.mjs:58-92`). That "pure checker + fixtures" shape is the house idiom (also `p19`).

### Why it is worth it

D-02's own words: *"Any drift makes the proof worthless — 20 green runs of a sibling harness say
nothing about the lane that reds `ci-gate`."* The proof's validity depends on a copy staying a
copy, and the copy lives in a file nobody has a reason to open again. A comment citing
`ci.yml:1401-1533` (the comment-only alternative) is exactly the "green gate that verified
nothing" pattern the milestone thesis names. The guard converts a silent future divergence into a
PR-lane red.

### Sketch: `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs`

```js
// P20 (240-xx-PLAN.md) — mechanical enforcement.
//
//   MUST NOT let .github/workflows/green-04-evidence.yml's job body drift from
//   ci.yml's `generated_admin_playwright_smoke` step list. The GREEN-04 n>=20
//   proof is only evidence about ci-gate's lane while the two step lists agree;
//   a drifted copy proves 20 green runs of a sibling harness.
//
// Subject: .github/workflows/green-04-evidence.yml (via GSD_PROHIB_SUBJECT).
// STRUCTURAL AND OFFLINE BY DESIGN — mirrors p12/p15/p19: no gh, no token, no network.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, readRepoFile, jobBlock, stripYamlComments } from './_lib.mjs';

const SUBJECT   = '.github/workflows/green-04-evidence.yml';
const REFERENCE = '.github/workflows/ci.yml';
const REF_JOB   = 'generated_admin_playwright_smoke';
const EVIDENCE_JOB = 'green_04_evidence_repeat';

function stepList(jobBlockText) { /* verbatim copy of p15-…test.mjs:40-56 */ }

// Names/`uses` that are ALLOWED to differ, each with the deviation recorded in
// 240-RESEARCH.md §1 (artifact-name matrix suffix). Compare on a normalised name.
const normalize = (n) => n.replace(/-\$\{\{\s*matrix\.repeat\s*\}\}/g, '');

function parityIssue(refSteps, evSteps) {
  if (refSteps.length === 0 || evSteps.length === 0) {
    return 'the parse broke, this is not a pass — zero steps extracted';
  }
  const a = refSteps.map((s) => normalize(s.name));
  const b = evSteps.map((s) => normalize(s.name));
  if (a.length !== b.length) return `step count ${b.length} != ci.yml's ${a.length}`;
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) return `step ${i}: "${b[i]}" != ci.yml's "${a[i]}"`;
  }
  // The four load-bearing run: bodies must be byte-equal after comment stripping.
  for (const key of ['npm ci', 'npx playwright install --with-deps chromium webkit',
                     'mix archive.install --force hex phx_new 1.8.8',
                     'scripts/ci/admin-acceptance-smoke.sh --test all']) {
    const inRef = refSteps.some((s) => s.text.includes(key));
    const inEv  = evSteps.some((s) => s.text.includes(key));
    if (inRef !== inEv) return `command drift: "${key}" present in ci.yml=${inRef}, evidence=${inEv}`;
  }
  return null;
}

test('the evidence workflow mirrors ci.yml\'s generated-admin step list', () => {
  const ref = stepList(jobBlock(stripYamlComments(readRepoFile(REFERENCE)), REF_JOB));
  const ev  = stepList(jobBlock(stripYamlComments(readSubject(SUBJECT)), EVIDENCE_JOB));
  assert.equal(parityIssue(ref, ev), null);
});

test('non-vacuity floor: both parses find the acceptance-smoke invocation', () => { /* … */ });

test('negative control: a fixture with a dropped browser-install step is caught', () => {
  const ref = stepList(jobBlock(stripYamlComments(readRepoFile(REFERENCE)), REF_JOB));
  const bad = stepList(jobBlock(stripYamlComments(
    readRepoFile('test/fixtures/prohibitions/p20-green-04-step-drift.yml')), EVIDENCE_JOB));
  assert.notEqual(parityIssue(ref, bad), null);
});
```

**RED fixture:** `test/fixtures/prohibitions/p20-green-04-step-drift.yml` — a copy of
`green-04-evidence.yml` with the `Install Playwright browsers` step deleted (the most consequential
possible drift: the smoke would still "run", against no browsers). Standing constraint 6 is then
satisfied two ways — the committed negative-control test, and a demonstrated
`GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p20-green-04-step-drift.yml node --test …` RED run
recorded in the evidence ledger, following the `AFTER-P17-GUARD-OBSERVED` shape in
`236-EVIDENCE.md`.

**Cost:** ~80 lines guard + ~40 line fixture + one evidence slot. **Benefit:** the only mechanical
defence of D-02's central premise. Ship it.

---

## 7. Ordering + operator-action inventory

### (a) Agent-doable, offline, no credentials — the whole build

| Action | Notes |
|---|---|
| Rewrite `scripts/ci/ensure-github-pages-legacy-branch.sh` (`:18`, `:66-73`) | §4 |
| Author `scripts/ci/ensure-github-pages-legacy-branch.test.sh` with the 9 stub modes | §5 |
| Wire that self-test as a `fast_checks` step in `ci.yml` | §5 (decide explicitly) |
| Author `.github/workflows/green-04-evidence.yml` | §1 |
| Author `scripts/ci/prohibitions/p20-…test.mjs` + `test/fixtures/prohibitions/p20-….yml` | §6 |
| Author `scripts/ci/capture-green-04-evidence.sh` (+ optional `.test.sh`) | §2 |
| Demonstrate every guard RED against its stub/fixture; record exit codes and verbatim messages | standing constraint 6 |
| Draft `240-EVIDENCE.md` with `pending (… obligation …)` slots for the not-yet-captured ones | §3 |
| `MIX_ENV=test mix ci` | CLAUDE.md + constraint 3 |

### (b) Requires a push to `main` / merged PR first

| Action | Why |
|---|---|
| Dispatching `green-04-evidence.yml` | `workflow_dispatch` only fires from a workflow file **on the default branch**; the file must be merged before the Actions UI/API will accept a dispatch `[ASSUMED]` — standard GitHub behaviour, not re-verified live this session |
| D-01's `if: github.ref == 'refs/heads/main'` | The job is a no-op on any other ref by construction |
| D-13's clean-tree/final-HEAD capture | The dispatch's `head_sha` must equal the final committed HEAD; any later commit invalidates the window (the Phase 216 SC-5 lesson) |

### (c) Requires an operator with credentials

| Action | Command | Why not automatable |
|---|---|---|
| Merge the PR to `main` | `gh pr merge --squash` | Repo policy; Jon's standing preference is squash merge |
| Trigger the n≥20 dispatch | `gh workflow run green-04-evidence.yml --ref main` | Credentialed write; ~75–100 runner-minutes, 4 sequential waves at `max-parallel: 5` (D-04/D-07) |
| Comment + close #231 | `gh issue comment 231 …` then `gh issue close 231` | Credentialed write on a public issue; D-24 orders comment → close → `gh issue view 231 --json state` |
| Verify live Pages payload for the closure comment | `gh api repos/szTheory/sigra/pages` | Read-only, agent-runnable — **but** must be re-run at closure time, not reused from this document |

### The ordering constraint, stated for plan decomposition

```
Group A (offline build, N plans, parallelisable)
   ↓  MIX_ENV=test mix ci green
Group B (operator: merge to main)          ← branch point; nothing after this is agent-only
   ↓  final committed HEAD is now fixed
Group C (operator: dispatch) → (agent: capture-green-04-evidence.sh at clean tree + that HEAD)
   ↓  240-EVIDENCE.md pending slots flip to captured
Group D (agent: ledger write; operator: #231 comment+close; agent: todo moves)
   ↓  gh issue view 231 --json state  == CLOSED
```

**The trap D-13 names:** if Group D's ledger write is a *commit*, HEAD moves after the capture. Two
ways out, both acceptable — (i) the evidence run's `head_sha` is asserted equal to the HEAD **at
dispatch time** and the ledger commit is explicitly declared a post-evidence documentation commit
(the `236-EVIDENCE.md` precedent: its fifth run's `headSha` equalled HEAD at *evidence-capture*
time, with `git status --porcelain` clean but for known untracked paths); or (ii) the capture
script itself records `head_sha` + `clean_tree` into the JSON before the ledger is written, making
the claim self-dating. **Prefer (ii)** — it is mechanical, and it is what the §2 skeleton's step 4
does.

### Todo-closure mechanics — one correction to D-25's framing

`[VERIFIED: head -30 .planning/todos/completed/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md]`

That file is indeed already under `completed/`, but its own frontmatter still reads
**`status: pending`** (line 3), with `resolves_phase: 237`. So "already closed" is true of its
*location* and false of its *metadata*. D-25's conclusion (verification + evidence-append, not a
move) stands; the plan should additionally flip `status:` to `completed` and note that the Phase
237 closure moved the file without updating the field.

The pending todo `2026-07-30-admin-generated-audit-presets-actor-filter-race.md`
`[VERIFIED: read in full]` confirms D-26 exactly: its `files:` list names
`lib/sigra/admin/live/audit_live.ex` (a path that does not exist), and its body cites
`admin-generated.spec.ts:454-458` and an `"Apply filters"` button. The closure must cite the
corrected coordinates — `lib/sigra/admin/live/audit_index_live.ex` and
`admin-generated.spec.ts:459` — per `236-CONTEXT.md` D-06/D-07. Its frontmatter already carries
`resolves_phase: 236`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Paginating an Actions endpoint safely | A fresh `while`/`page++` loop | `collect_pages`/`validate_manifest`/`request_page` copied from `capture-terminal-ratification-evidence.sh:47-97` | Already encodes contiguity, terminal-empty-page, `total_count` stability **and** `total_count`-vs-length — i.e. all of D-11 |
| Extracting a job's ordered step list from YAML | A regex over raw text | `stepList()` from `p15-…test.mjs:40-56` + `stripYamlComments` | Comment prose containing a step's tokens is a documented false-match vector (`p06`, `p15` header comments) |
| Reading an HTTP status from `gh` | `grep -E '403'` over a `2>&1` blob | `gh api -i` + status-line field read | The exact defect SC-3 exists to remove (`:67`) |
| Detecting HTTP failure from `gh`'s exit code | `case $?` | Status line | **`gh` exits 1 for any HTTP failure** — verified live for both 403 and 404 |
| Faking `gh` in tests | A mock library or a function override | `PATH`-shadowed executable + `FAKE_MODE` + `FAKE_GH_LOG` | Two in-repo precedents; the call log is what makes *negative* assertions possible |
| A YAML parser dependency for the guard | `js-yaml` / `yaml` | `_lib.mjs` block splitters | Guards are dependency-free `node --test` by house rule; `node --test scripts/ci/prohibitions/*.test.mjs` runs with zero install |

**Key insight:** every primitive this phase needs already exists in this repo, battle-tested, with
a named failure token for each way it can go wrong. The risk here is not writing new machinery —
it is writing new machinery when a hardened copy is three files away.

## Common Pitfalls

### Pitfall 1: duplicate artifact names across matrix legs
**What goes wrong:** the byte-faithful copy uploads `generated-admin-report` from all 20 legs; leg 2 onward fails the upload step. **How to avoid:** `-${{ matrix.repeat }}` suffix on all four artifact names (§1). **Warning sign:** legs 2–20 red with an upload-artifact conflict error while leg 1 is green.

### Pitfall 2: reading the run conclusion instead of the job conclusion
**What goes wrong:** `ci.yml`'s run-level conclusion on `main` is currently `failure` for `admin_eval_render`, a job outside `ci-gate.needs` (`ci.yml:1547-1557` lists exactly ten entries; `admin_eval_render` starts at `:2106`). A naive `gh run list --branch main` reports red and misattributes it to the flake. **How to avoid:** D-08 — always `GET /runs/<id>/jobs` and select by `name`. **Warning sign:** an SC-2 table whose rows are run conclusions.

### Pitfall 3: unpaginated `/jobs`
**What goes wrong:** the endpoint defaults to `per_page=30` and `ci.yml` expands to exactly 30 jobs — it returns all 30 today with page 2 empty, so it *looks* correct. One added job and the call silently drops it, with no error. **How to avoid:** `per_page=100` **and** the `total_count` assertion. **Warning sign:** none — that is the point.

### Pitfall 4: the `p12` grammar is not actually enforced on 240
**What goes wrong:** a ledger is written "in p12 grammar" that p12 never parses, drifts, and is discovered wrong later. **How to avoid:** run p12 with `GSD_PROHIB_SUBJECT` pointed at `240-EVIDENCE.md` as an explicit evidence step, and clear its ≥4-slot / ≥3-captured floors. **Warning sign:** a ledger with fewer than 4 slots, or a `Status: captured` with no parenthetical.

### Pitfall 5: a bare `403` inside an unrelated body
**What goes wrong:** `:67`'s `grep -qE '403'` matches `"status":"403"` — but equally matches a request id, a rate-limit number, or a 500-page body, swallowing a genuine failure as "expected 403". **How to avoid:** anchored status-line read. **Warning sign:** the publisher job green while the site is broken — the exact observed defect.

### Pitfall 6: budgeting a live 403 observation
**What goes wrong:** the plan schedules "observe the 403 on a real run" and stalls, then is tempted into deliberately misconfiguring Pages on a public repo. **How to avoid:** D-20 — the `:48` "already gh-pages /" arm fires today (re-verified live this session), so the PUT is unreachable. The stub is the only honest route.

### Pitfall 7: zsh vs bash in verify commands
**What goes wrong:** zsh does not word-split unquoted parameter expansions; a `for id in $IDS` loop over run ids passes one newline-laden argument and every `gh run view` fails. `236-EVIDENCE.md` records this exact finding. **How to avoid:** run all verify commands via `bash -c`. **Warning sign:** "observed 0, expected 20".

## State of the Art

| Old approach | Current approach | Where |
|---|---|---|
| `gh api … 2>&1` + `grep` for a status | `gh api -i` + status-line read | This phase (SC-3) |
| Run-level conclusion as the gate verdict | Job-level conclusion, selected by name | Phase 238 lesson, inverted (D-08) |
| Evidence asserted in prose | Canonical JSON receipt + attested artifact + a slot ledger | `capture-fast-01-*`, `capture-terminal-ratification-*` |
| 20 full pushes for repeat evidence | `workflow_dispatch` + `matrix.repeat` on the single affected job | D-01, ROADMAP scope-discipline line |

**Deprecated/outdated in the CONTEXT itself:** D-22's `|| true` line citations (`:31`, `:52`) are
one line late; the actual swallows are `:30`, `:50`, `:75`.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---|---|---|
| `gh` CLI, authenticated | every API read, the dispatch, #231 closure | ✓ | 2.95.0 | none |
| GitHub API core quota | capture (~25–60 calls) | ✓ | 5000 remaining at probe | wait for reset |
| `jq` | collectors + the Pages script (`:34-37`) | ✓ | assumed present (repo-wide requirement) | none — script already exits 1 |
| `node` ≥ 22 | `node --test` prohibition guards | ✓ `[ASSUMED]` — `ci.yml:393` comment references node-22 module-resolution behaviour | none |
| Postgres + phx_new 1.8.8 | `MIX_ENV=test mix ci` locally | per CLAUDE.md: `scripts/db/up.sh`, `mix archive.install --force hex phx_new 1.8.8` | — | none |
| Actions runner minutes | 20 legs × ~3.73m ≈ 75–100 | ✓ | — | reduce n (would break SC-1) |

**Missing dependencies with no fallback:** none identified.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Frameworks | ExUnit (`mix ci`), `node:test` (prohibition guards), plain-bash `*.test.sh` self-tests |
| Config files | `mix.exs:144-157` (`ci` alias); guards need none |
| Quick run command | `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` (< 5s, hermetic) |
| Guard run command | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` (< 10s, offline) |
| Full suite command | `MIX_ENV=test mix ci` (requires live Postgres + phx_new 1.8.8) |

### Phase Requirements → Test Map

| Req | Behavior | Test type | Automated command | Exists? |
|---|---|---|---|---|
| GREEN-04 | The evidence workflow's step list has not drifted from `ci.yml`'s job | unit (guard) | `node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` | ❌ Wave 0 |
| GREEN-04 | That guard fires RED on a dropped-step fixture | unit (negative control) | `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p20-green-04-step-drift.yml node --test … p20-….test.mjs` | ❌ Wave 0 |
| GREEN-04 | Collector fails closed on truncated `/jobs` pagination | unit (stub) | `bash scripts/ci/capture-green-04-evidence.test.sh` | ❌ Wave 0 |
| GREEN-04 | Collector refuses a dirty tree / HEAD mismatch | unit (stub) | same | ❌ Wave 0 |
| GREEN-04 | n≥20 legs, all `success`, at final HEAD | integration (live) | `bash scripts/ci/capture-green-04-evidence.sh --output … --run-id <id>` then `jq -e '.sc1.leg_count >= 20 and .sc1.verdict == "pass"'` | ❌ Wave 0 (needs operator dispatch) |
| GREEN-04 | SC-2 `main` window readable from the API, not prose | integration (live) | `jq -e '.sc2.flake_attributable_red_count == 0'` on the same JSON | ❌ Wave 0 |
| GREEN-05 | PUT 403 stays tolerable and is the ONLY tolerated failure | unit (stub, `FAKE_MODE=put_403`) | `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` | ❌ Wave 0 |
| GREEN-05 | PUT 204 (empty body) is read as success | unit (stub, `put_204`) | same | ❌ Wave 0 |
| GREEN-05 | PUT 422/500 exits 1 (the loud-RED demonstration) | unit (stub, `put_500`) | same | ❌ Wave 0 |
| GREEN-05 | GET 403 exits 1 instead of POST-creating | unit (stub, `get_403`) | same | ❌ Wave 0 |
| GREEN-05 | A body containing `403` on a 500 does not read as tolerable | unit (stub, `get_500`) | same | ❌ Wave 0 |
| GREEN-05 | #231 is CLOSED | integration (live) | `gh issue view 231 --json state --jq '.state'` → `CLOSED` | ✓ command exists |
| GREEN-05 | The ledger satisfies p12's grammar | unit | `GSD_PROHIB_SUBJECT=.planning/phases/240-…/240-EVIDENCE.md node --test --test-reporter=tap scripts/ci/prohibitions/p12-run-id-provenance.test.mjs` | ✓ guard exists, must be pointed at 240 |

### Sampling Rate

- **Per task commit:** `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` + `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs`
- **Per wave merge:** `MIX_ENV=test mix ci`
- **Phase gate:** `MIX_ENV=test mix ci` green, plus the live SC-1/SC-2 JSON and `gh issue view 231`

### Wave 0 Gaps

- [ ] `scripts/ci/ensure-github-pages-legacy-branch.test.sh` — GREEN-05 (9 stub modes)
- [ ] `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` — GREEN-04
- [ ] `test/fixtures/prohibitions/p20-green-04-step-drift.yml` — GREEN-04 RED fixture (constraint 6)
- [ ] `scripts/ci/capture-green-04-evidence.sh` + `.test.sh` — GREEN-04
- [ ] `.github/workflows/green-04-evidence.yml` — GREEN-04
- [ ] One `fast_checks` step wiring the Pages self-test (`ci.yml`, near `:261`)

## Security Domain

Per `.planning/config.json` no `security_enforcement: false` is set, so this section is included.

### Applicable ASVS categories

| ASVS category | Applies | Standard control |
|---|---|---|
| V2 Authentication | no | No auth code changes |
| V3 Session Management | no | — |
| V4 Access Control | **yes** | Least privilege: `green-04-evidence.yml` declares `permissions: contents: read` only (`ci.yml:36-37` precedent); the Pages script relies on the caller's `pages: write` and must not request more (`playwright-github-pages.yml:36-38`) |
| V5 Input Validation | **yes** | The collectors take no caller-configurable repo/workflow — a deliberate in-repo pattern (`capture-terminal-ratification-evidence.sh:5-8`) that prevents a local caller steering the evidence |
| V6 Cryptography | no | No crypto here; `actions/attest-build-provenance` is optional and already pinned by SHA |

### Known threat patterns

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| Evidence forgery (a chosen window that flatters the verdict) | Repudiation | Fixed, non-configurable parameters; `head_sha` + `clean_tree` in the receipt; run ids on the record (p12's whole reason) |
| Supply-chain drift in a new workflow | Tampering | Every `uses:` pinned to the same full commit SHAs already used in `ci.yml` — copy the pins, never a tag |
| Command injection via a status-line read | Tampering | `awk '{print $2}'` on untrusted header text is safe; never `eval` the body, never interpolate it into a further shell command |
| Over-broad token on the evidence workflow | Elevation of Privilege | Workflow-level `permissions: contents: read`; no `id-token`/`attestations` unless attestation is actually wanted |
| Accidental public-repo settings mutation | Tampering | D-20: no live Pages misconfiguration; the stub is the proof surface |

## Decision conflicts

None of the 28 decisions is contradicted. Four items need the planner's explicit attention:

1. **D-02 vs `actions/upload-artifact` (hard, must deviate).** A byte-faithful copy of the four
   artifact-upload steps fails under a 20-leg matrix on duplicate artifact names. The deviation
   (a `-${{ matrix.repeat }}` suffix) is mandatory and should be recorded as a documented
   exception to D-02, along with the dropped `needs: release_ref_guard`.
2. **SC-3's "fails loudly on a 403" vs D-19's tolerable PUT-403 (wording, reconcilable).** Both
   are right about different things; the phase must state the reconciliation in writing (§4), or a
   reviewer will read the implementation as contradicting its own success criterion.
3. **D-12's "modelled on `capture-fast-01-remeasurement.sh`" (refinement, not conflict).** The
   jobs-endpoint half plus every D-11 assertion already exists in
   `capture-terminal-ratification-evidence.sh`. Copying from both is entirely consistent with
   D-12's actual constraint, which is *do not extend fast-01*.
4. **D-22 line citations off by one.** The `|| true` swallows are at `:30`, `:50`, `:75`, not
   `:31`, `:52`. Cosmetic.

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | `actions/upload-artifact` v7 errors (rather than merges) on a duplicate artifact name within one run | §1, Pitfall 1 | If it merges instead, the suffix is harmless belt-and-braces; if it errors, omitting the suffix reds 19 of 20 legs. Cheap to pre-verify with one 2-leg dispatch, or by reading the action's README at the pinned SHA |
| A2 | `workflow_dispatch` requires the workflow file to be on the default branch before the event is offered | §7(b) | If wrong, the dispatch could happen pre-merge and the ordering constraint relaxes — harmless either way, since D-13 forces post-merge capture regardless |
| A3 | Node ≥ 22 is the CI runtime for the prohibition guards | Environment | Guard uses only `node:test` + `node:assert/strict`; a lower version would still run |
| A4 | Adding one `fast_checks` step to wire a shell self-test does not violate standing constraint 5 | §5 | Constraint 5 names `mix ci` and the prohibitions glob specifically, and 19 precedents exist; if a reviewer reads it more broadly, the self-test ships unwired with that stated |
| A5 | The single-call `gh api -i` header/body split (`sed -n '/^\r\{0,1\}$/,$p'`) is portable across the `\r\n` forms `gh` emits | §4 | If it mis-splits, `jq` fails loudly on the body — fail-closed, not silent. The two-call alternative removes the risk at one extra request |

## Open Questions

1. **Does the plan run `p12` against `240-EVIDENCE.md`, or leave the ledger unenforced?**
   - Known: p12 is hardcoded to the 230 path; `GSD_PROHIB_SUBJECT` can redirect it at runtime; generalising p12 is Phase 241's territory.
   - Unclear: whether a one-off redirected invocation counts as "enforced" for this phase's purposes.
   - Recommendation: run it as an evidence step, size the ledger to ≥4 slots / ≥3 captured, and file the "generalise p12 to a ledger glob" work against the existing todo rather than doing it here.
2. **One commit or two for the Pages script's two sites (D-16 vs D-18)?** Explicitly Claude's discretion. Recommendation: **two** — they have independent RED demonstrations (`get_403` vs `put_500`), and a bisect that lands between them still leaves a coherent script.
3. **Keep or collapse the four `github.ref != 'refs/heads/main'` upload legs in the copy?**
   - Recommendation: **keep verbatim.** Byte-faithfulness is D-02's whole point, the dead legs cost nothing, and keeping them means the p20 parity guard needs no allowance beyond the artifact-name normalisation.

## Sources

### Primary (HIGH confidence — read or executed this session)
- `.github/workflows/ci.yml` — `1-40`, `62-100`, `160-178`, `216-400`, `555-570`, `1401-1533`, `1534-1565`, `1640-1690`, job-header line map
- `.github/workflows/fast-01-remeasurement-evidence.yml`, `.github/workflows/generated-app-login-runtime-proof.yml`, `.github/workflows/playwright-github-pages.yml` (`25-45`, `185-215`)
- `scripts/ci/ensure-github-pages-legacy-branch.sh` (all 76 lines)
- `scripts/ci/capture-fast-01-remeasurement.sh`, `scripts/ci/capture-fast-01-remeasurement.test.sh`
- `scripts/ci/capture-terminal-ratification-evidence.sh`, `scripts/ci/capture-terminal-ratification-evidence.test.sh`
- `scripts/ci/prohibitions/_lib.mjs` (`30-78`, `93-130`, `179-200`, `254-294`), `p12-run-id-provenance.test.mjs`, `p15-pages-publisher-seeds-before-boot.test.mjs` (`1-92`), `p19-tag-namespace-ruleset.test.mjs` (`1-60`)
- `.planning/phases/236-…/236-EVIDENCE.md`; `.planning/ROADMAP.md` (`28-80`, `250-275`); `.planning/REQUIREMENTS.md` (`10-30`); `.planning/config.json`; `mix.exs:144-168`
- `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md`; `.planning/todos/completed/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`
- Live: `gh --version` (2.95.0); `gh issue view 231 --json state` → `OPEN`; `gh api repos/szTheory/sigra/pages` → `built / legacy / gh-pages / /`; `gh api rate_limit` → 5000; `gh api -i` 403 and 404 probes

### Secondary (MEDIUM)
- `.planning/research/ARCHITECTURE.md:100`, `.planning/research/STACK.md:72,78,219` — corroborate the Pages defect description

### Tertiary (LOW)
- A1–A5 in the Assumptions Log — training knowledge, not verified this session

## Metadata

**Confidence breakdown:**
- Source material for D-02: **HIGH** — the full 1401–1533 range read verbatim
- Capture-script template: **HIGH** — both collectors read in full
- p12 grammar: **HIGH** — derived from the parser and the guard, not from an example
- Pages rewrite surface: **HIGH** — full file read + live `gh api -i` probes at the exact gh version
- Stub harness idiom: **HIGH** — both precedent harnesses read
- D-03 cost call: **MEDIUM-HIGH** — every primitive verified present; the ~80-line estimate is judgement
- Ordering inventory: **HIGH**, except A2 (`[ASSUMED]`)

**Research date:** 2026-09-18
**Valid until:** 2026-10-18 for the file-level claims; the live claims (issue #231 state, Pages payload, `main` run conclusions) are **point-in-time** and must be re-read at closure.
