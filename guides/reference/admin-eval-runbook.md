# Admin Eval Runbook

Iteration guide for the Sigra admin eval harness (Phase 216). This runbook covers the
single-command local loop, how guards gate merges, how to settle a finding, how a cell
climbs an award band, and where human sign-off sits.

Cross-reference: `guides/reference/admin-eval-schema.md` for ledger contracts + band
semantics; `scripts/ci/admin-eval-harness.sh` for the executable orchestrator.

---

## Quick-Start: One Iteration Locally

```bash
# 1. Boot ephemeral test Postgres (if not already running)
scripts/db/up.sh

# 2. Boot example app on PORT 4011 (admin-eval default)
(cd test/example && MIX_ENV=dev PORT=4011 PGHOST=127.0.0.1 PGPORT=<port-from-tmp/db.env> \
  PGUSER=postgres PGPASSWORD=postgres mix phx.server &)

# Wait until the app responds (typically <5s after compile):
until curl -sf http://localhost:4011/ > /dev/null; do sleep 1; done

# 3. Run the full harness
cd test/example/priv/playwright
bash scripts/ci/admin-eval-harness.sh
```

The harness will:
1. Run `tests/admin-eval.spec.ts` across three Playwright projects (admin-eval,
   admin-eval-mobile, admin-eval-dark) and write evidence bundles under
   `eval/<app_git_sha>/<surface>/<cell>/` (gitignored — never committed to git).
2. Run the five derivative guards in sequence: stale-render, evidence-anchor,
   quality-findings-monotonic, award-guard, settled-findings-lint.

All five guards must print PASS for a clean iteration.

---

## Bundle Directory Layout

Bundles land under:
```
test/example/priv/playwright/eval/<app_git_sha>/<surface>/<cell>/
  bundle.json       # manifest: app_git_sha, surface, cell, render_sha256, findings_summary
  dom.html          # canonicalized board outerHTML (renderSha256 input)
  screenshot.png    # full-viewport PNG
  axe.json          # axe-core WCAG 2.1/2.2 AA result
  facts.json        # computed-style facts (spaceScale, radiusScale, controlScale, viewport)
  findings.json     # probe findings array
```

The bundle directory is gitignored (`eval/` in `.gitignore`). Bundles upload to CI as
artifacts only — never committed.

Surface keys are design gallery board IDs (e.g., `board-mg-5-populated`). Cell keys are
`<theme>-<viewport>-<state>` (e.g., `light-desktop-populated`).

---

## Guard Descriptions

### Guards in `fast_checks` (merge-blocking, cheap, deterministic)

| Guard | What it checks | Fails when |
|-------|---------------|-----------|
| `stale-render-guard.sh` | Bundles' `app_git_sha == HEAD`; admin source unchanged since capture | Bundle SHA != HEAD, or admin source changed after bundle |
| `evidence-anchor-check.mjs` | Every finding's `anchor` resolves in captured DOM (cheerio `$()`) | An anchor is a prose string or doesn't match the DOM |
| `quality-findings-monotonic.sh --base <merge-base>` | `open_findings` per cell may not increase vs base | Any cell's open finding count increases |
| `award-guard.mjs --base <merge-base>` | D-20 verify-then-climb: axis up only with fresh `verified_at_sha` + resolving evidence | Climb without fresh sha; `band != min(axes)`; axis decreased; empty evidence |
| `settled-findings-lint.sh` | `settled-findings.tsv` is sorted + no duplicate `finding_id` | Unsorted file or duplicate entry |

The fast_checks guards read the COMMITTED ledgers (`admin-render-sha.json`,
`admin-award-ledger.json`, `settled-findings.tsv`) against the merge-base. They do NOT
depend on the render-job's runtime output — the signal is forward-only in git.

### Render + probe job (separate `admin_eval_render` CI job — NOT merge-blocking)

The expensive Playwright render + probe pass runs as a separate `admin_eval_render` CI job
(never in fast_checks). It boots the example app, runs `scripts/ci/admin-eval-harness.sh`,
and uploads bundles as CI artifacts. This job is informational — it provides the evidence
that updates the committed ledgers, but it is NOT the merge gate.

**JUDGE-CI-01 invariant:** Only committed-ledger guards gate merges. The render job and any
future LLM panel run off the merge path.

---

## Adding a Settled Finding (Waiving or Resolving)

Findings that are intentionally acceptable (known design tradeoff, dense-control exempt, etc.)
are recorded in `guides/reference/settled-findings.tsv`. Never hand-edit the file's ordering
— use the helper:

```bash
bash scripts/ci/settled-findings-lint.sh --add \
  --surface users-index-live \
  --class off-token-spacing \
  --anchor '[data-testid="admin-users-desktop-results"] .sg-applied-chip' \
  --disposition waived \
  --waived-by <your-gh-username> \
  --note "dense admin inline chip — D-08 precedent"
```

The helper computes the `finding_id = sha256(surface\0class\0anchor)`, inserts the row in
sorted order, and writes the file. The file must always be sorted by `finding_id` (column 1,
lexicographic ascending). The settled-findings-lint guard enforces this on every CI run.

Once a finding is settled, `open_findings` for that cell decreases by 1 in the next render run
(because `open = total - settled`). Update `admin-render-sha.json` to reflect the new
`open_findings` when re-running the harness.

---

## How a Cell Climbs an Award Band

A cell in `admin-award-ledger.json` can only climb (never regress) via:

1. **Run the full harness** to get fresh bundles at HEAD.
2. **Examine the rendered evidence**: probes ran, axe-clean confirmed, states rendered.
3. **Update `admin-award-ledger.json`** for the surface:
   - Raise the relevant axis (e.g., `a11y_polish`: A1 → A2)
   - Set `verified_at_sha` to the current `git rev-parse HEAD`
   - Set `rendered: true`
   - Add resolving `evidence_ref` entries (e.g., `probe:focus-ring`, `test:assertUserResultEquivalence`)
   - Set `band = min(axes)` — **never set band by hand** — the award-guard recomputes and fails if it disagrees

4. **Update `admin-render-sha.json`** with the new `render_sha256` and `open_findings` for
   each affected cell.

5. **Run the award-guard** to confirm PASS before committing:
   ```bash
   node scripts/ci/award-guard.mjs --base HEAD
   ```

Band semantics recap (from `admin-eval-schema.md`):

| Band | Criteria |
|------|----------|
| A0 Nominated | Tier-2 + every applicable probe has a rendered evidence key |
| A1 Shortlisted | A0 + 3 manual proxies (motion/whitespace-rhythm/target-size) rendered |
| A2 Commended | A1 + adversarial states rendered & axe-clean + content-equivalence proven |
| A3 Award-grade | A2 + persona-JTBD panel clean + cross-viewport/theme render parity |

**Pilots cap at A2** — A3 requires the persona-JTBD panel to be re-run at current HEAD (Phase 209 artifact; out of scope for Phase 216).

`band = min(axes)` is enforced by the award-guard. A surface cannot "buy" a higher band by maxing one cheap axis.

---

## Where Human Sign-off Sits

This phase's loop is **fully deterministic** — no human reviewer is needed in the hot path:

- Merge-blocking gates: stale-render, evidence-anchor, findings-monotonic, award-guard,
  settled-findings-lint. These are automated bash/Node guards.
- Render + probe job: uploads artifacts to CI; results inform the next ledger update.
- **Human sign-off** sits at the milestone-terminal PR (e.g., the Phase 216 close-out PR).
  A reviewer looks at the final award bands and the accumulated findings before merging
  to main.

The LLM panel (Phase 217's advisory AUTOFIX-01 panel) is off-CI and advisory only. It does
NOT gate merges. See the **Off-CI LLM Panel + Auto-Fix Loop** section below for details.

---

---

## Off-CI LLM Panel + Auto-Fix Loop

**JUDGE-CI-01 invariant (absolute):** Neither `admin-panel.sh` nor `admin-autofix-loop.sh`
is ever in `fast_checks` or any merge-blocking gate. Only their deterministic derivatives
gate merges — the committed ledgers (`admin-panel-verdicts.json`, `fix-queue.json`,
`admin-render-sha.json`) are what the guards read. The panel and loop run off the merge path.

### Running the Panel (`admin-panel.sh`)

```bash
# Prerequisite: fresh bundles captured at HEAD
bash scripts/ci/admin-eval-harness.sh

# Run the LLM panel (pilot surfaces — board-mg-5-*/board-mg-9-*)
ANTHROPIC_API_KEY=<your-key> bash scripts/ci/admin-panel.sh

# Fan out to ALL surfaces (Phase-218 scope — use --all)
ANTHROPIC_API_KEY=<your-key> bash scripts/ci/admin-panel.sh --all

# Dry-run: print cells + estimated call count without making API calls
ANTHROPIC_API_KEY=<your-key> bash scripts/ci/admin-panel.sh --dry-run
```

**`ANTHROPIC_API_KEY` no-op degrade (Hammer guarantee):**
When `ANTHROPIC_API_KEY` is not set, `admin-panel.sh` exits 0 with a warning that names
the env var by name only — it never echoes the key value. This is the structural
JUDGE-CI-01 guarantee: a run without a key can only ever pass, never block.

```
admin-panel: ANTHROPIC_API_KEY not set — skipping LLM panel (JUDGE-CI-01 no-op pass)
admin-panel: To run the panel, export ANTHROPIC_API_KEY=<your-key> and re-run.
```

**Pilot surfaces (Plan 217-08 — Option 2 alignment):**
The default run judges the board-mg-5-* and board-mg-9-* surfaces (the concrete boards the
217 render matrix actually renders). These are the surfaces whose `render_sha256` cells are
populated in `admin-render-sha.json`. Pass `--all` to fan out to every surface. The script
always prints the estimated API call count (K=3 per cache-miss cell) BEFORE making any
calls so you can abort if the estimate is unexpectedly large.

Prior to Plan 217-08, the default run targeted `users-index-live` and `user-show-live` (pilot
surface names derived from board-mg-5 and board-mg-9 respectively). Those names were never
rendered by the 217 harness, so a live run found no bundles and made 0 API calls for the
wrong reason. The current pilot names (`board-mg-5-*`, `board-mg-9-*`) are the concrete
boards the harness actually captures — so a live run now finds real bundles and makes
meaningful API calls.

**Content-hash skip (SC-2):**
If `admin-panel-verdicts.json` already contains a cache entry for the current
`render_sha256` with matching provenance (model, k, quorum, rubric_version), the panel
makes ZERO API calls for that cell. Running the panel twice on an unchanged tree costs
nothing on the second run.

**Bundle-freshness precondition (T-217-07-STALE / 216-09 SC-5):**
If no bundles exist under `eval/<HEAD-sha>/`, the panel warns and exits 0. This prevents
judging stale renders. Always ensure bundles are fresh at the committed HEAD before
running the panel (the 216-09 SC-5 discipline: a render captured before the final commit
has the wrong `app_git_sha` and must not be judged).

**What `admin-panel.sh` writes (and doesn't):**
- Writes: `guides/reference/admin-panel-verdicts.json` (committed; keyed on `render_sha256`)
- Writes: `eval/<sha>/<surface>/<cell>/panel-findings.json` (gitignored; parallel output)
- NEVER writes: `findings.json`, `admin-render-sha.json`, or any deterministic-guard ledger

### Running the Auto-Fix Loop (`admin-autofix-loop.sh`)

```bash
# Run the auto-fix loop (pilot run — max 5 fixes)
bash scripts/ci/admin-autofix-loop.sh --max-fixes 5

# Dry-run: print eligible findings without applying
bash scripts/ci/admin-autofix-loop.sh --dry-run
```

**Safety ruleset:** The loop commits one fix per commit, re-renders after each, and
auto-reverts via `git revert --no-edit HEAD` (a NEW commit — never `reset --hard` or
`push --force`) if any of FOUR safety rails trips:

| Rail | Trigger |
|------|---------|
| Rail 1 | `quality-findings-monotonic.sh` count increased vs pre-loop sha |
| Rail 2 | `award-guard.mjs` min(axes) decreased vs pre-loop ledger snapshot |
| Rail 3 | Any deterministic gate flip / anchor resolution failure (non-zero harness exit) |
| Rail 4 | Committed baseline PNG drift vs pre-loop sha (`snapshot-canary-guard.sh`) |

When any rail trips: the offending commit is reverted, the finding is written to
`settled-findings.tsv` with `disposition=waived`, and added to the gitignored
`eval/autofix-state.json` poison-set so it is never retried.

**Apply surface:** `fix-apply.mjs` applies only copy-swap and token-swap changes to admin
LiveView `.heex`/`.ex` files and `test/example`. CSS files, components requiring semantic
judgment, and non-admin files are all refused — no LLM text reaches source files.

**SC-4 chain — AUTONOMOUSLY PROVEN (Plan 217-08, clone-isolated, API-free):**
The SC-4 apply→rail-trip→revert→waive chain is proven in a throwaway git clone of the final
committed HEAD (the real repo history is never touched). The clone-isolated proof:

1. Seeds the `board-autofix-seed` in-band SPACE finding (12.5px `padding` in
   `design_gallery_live.ex`, resolved by `fix-apply.mjs` to `var(--sg-space-12)` via the
   10-entry SPACE scale — NOT the 4-entry radius scale, which would refuse).
2. Runs `admin-autofix-loop.sh --max-fixes 20 --skip-render` (API-free, no Playwright).
3. The loop applies the fix and a post-commit hook bumps `open_findings` on one cell,
   causing Rail 1 (`quality-findings-monotonic.sh`) to trip on the next check-rails pass.
4. The loop reverts via `git revert --no-edit HEAD` (a new `Revert "autofix..."` commit).
5. The finding is written to `settled-findings.tsv` with `disposition=waived`.
6. `admin-award-ledger.json` is restored to its pre-loop snapshot.
7. The reflog shows no `force-push` or `reset --hard`.

This proof is mechanized by Task 3's automated verify block (see `scripts/ci/admin-autofix-loop.test.sh`
for the hermetic equivalent). The real repo working tree and git history are unchanged.

**JUDGE-CI-01 invariant (restated):** Neither `admin-panel.sh` nor `admin-autofix-loop.sh`
is ever in `fast_checks` or any merge-blocking gate. Only `judge-cli.test.mjs` (the
deterministic, key-free CLI bundle-wiring self-test, wired into `fast_checks` in Plan 217-08)
joins the merge path. The panel and loop are strictly off the merge path.

**TRUE-live SC-2 paid run (OPTIONAL — post-merge, operator-only):**
The one step that cannot be automated is the TRUE-live SC-2 confirmation: running the panel
twice with a real key and verifying the 2nd run makes 0 API calls (proving the content-hash
skip is real, not a side-effect of missing bundles or a missing key). This is the only
un-automatable check; it is NOT a gate. The mechanism is already hermetically proven by
`judge.test.mjs` (callCount===0 on cache hit) and additionally proven against a real on-disk
board-mg bundle by `judge-cli.test.mjs` (Plan 217-08 Test 2).

To perform the optional operator confirmation:

```bash
# 1. Ensure fresh bundles captured at the COMMITTED HEAD (see SC-5 discipline)
bash scripts/ci/admin-eval-harness.sh

# 2. First run — populates admin-panel-verdicts.json cache
ANTHROPIC_API_KEY=<your-key> bash scripts/ci/admin-panel.sh

# 3. Second run — must report 0 API calls AND produce empty verdicts diff
ANTHROPIC_API_KEY=<your-key> bash scripts/ci/admin-panel.sh

# 4. Verify: no diff means SC-2 is confirmed
git diff guides/reference/admin-panel-verdicts.json
# expected: no output (empty diff)
```

This is an OPTIONAL post-merge operator confirmation. The plan completes autonomously without it.

### Reading the Dossier

| File | Location | What it is |
|------|----------|------------|
| `admin-panel-verdicts.json` | `guides/reference/` | Committed verdicts cache — content-hash keyed, human-readable |
| `fix-queue.json` | `guides/reference/` | Committed auto-eligible open findings — the loop's input |
| `panel-findings.json` | `eval/<sha>/<surface>/<cell>/` | Gitignored per-cell raw panel output |
| `admin-panel-report.md` | `eval/<sha>/` | Gitignored human-readable panel summary (if generated) |
| `settled-findings.tsv` | `guides/reference/` | Committed waived/resolved findings (never retry) |
| `eval/autofix-state.json` | `eval/` | Gitignored poison-set + loop resume state |

### Where Human Sign-off Sits

The panel is **advisory and off-CI throughout**. Human sign-off sits at two points:

1. **Before applying fixes:** The operator reviews the fix-queue (`fix-queue.json`) and
   panel verdicts (`admin-panel-verdicts.json`). The auto-fix loop proposes changes; the
   operator can abort or edit the queue before running.

2. **After the loop:** The operator reviews the before/after diff (committed changes after
   successful fixes, `Revert "autofix(...)"` commits for reverted fixes) and the updated
   `settled-findings.tsv`. The milestone-terminal PR is the final human gate.

Neither `admin-panel.sh` nor `admin-autofix-loop.sh` is ever in a merge-blocking position.

---

## Self-Tests

Run guard self-tests at any time to verify the guards work correctly in isolation:

```bash
for t in stale-render-guard quality-findings-monotonic settled-findings-lint; do
  echo "--- $t ---"
  bash scripts/ci/$t.test.sh
done
node scripts/ci/award-guard.test.mjs
node scripts/ci/evidence-anchor-check.test.mjs
```

All self-tests must print PASS (or their equivalent summary line) before running the full loop.

---

## Troubleshooting

**`stale-render-guard: FAIL: no bundle.json files found`**
Run the harness first (`scripts/ci/admin-eval-harness.sh`). Bundles are gitignored and must
be captured at the current HEAD before the guard can check them.

**`award-guard: FAIL: axis rose but verified_at_sha did not change`**
You updated an axis in `admin-award-ledger.json` without a fresh render. Update
`verified_at_sha` to the current HEAD SHA from the render run.

**`award-guard: FAIL: band != min(axes)`**
You set `band` manually. Remove the hand-typed value and let the guard tell you what it
computed — then set `band` to match `min(axes)`.

**`quality-findings-monotonic: FAIL: open findings increased`**
A code change introduced new probe findings. Either fix the finding, or settle it via
`settled-findings-lint.sh --add`. Do NOT increase `open_findings` in the ledger without
addressing the root cause.

**`evidence-anchor-check: FAIL: anchor absent`**
A finding's `anchor` selector no longer matches any element in the captured DOM. This is
the harness catching a stale finding — the component was refactored. Update or remove the
finding from `findings.json` (or re-run the harness to recapture fresh findings).
