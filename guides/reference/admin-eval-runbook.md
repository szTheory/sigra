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
NOT gate merges. Phase 217 will add the LLM-panel step; until then, the harness is purely
deterministic.

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
