# Phase 211: Terminal Ratification - Research

**Researched:** 2026-07-01
**Domain:** Milestone terminal-ratification mechanics (snapshot/canary reconciliation, ledger lock, generated-host parity, adversarial audit) for the Sigra Elixir/Phoenix auth library
**Confidence:** HIGH (all central claims verified live against the working tree this session with file:line evidence)

<user_constraints>
## User Constraints (from 211-CONTEXT.md)

### Locked Decisions (D-01..D-10 — do NOT re-litigate)
- **D-01** — Zero flips. Phase 210 already flipped every cell to bare `2`. 211 VERIFIES the terminal all-`2` state + forward-only lock; authors no new Tier-2 ratchets; both allowlists must stay empty at steady state.
- **D-02** (USER-RATIFIED) — Canary/snapshot reconciliation is **automated re-baseline into `main`, all-green == approval, NO human visual review**, driven through `scripts/ci/snapshot-recapture-gate.sh`. Preserve the 204-03 WCAG `.vt-status-pill` fix. **Reject** the `ci.yml:1852` human-visual-PNG-review recapture-PR path. **Reject** reverting the canary.
- **D-02a** (OPEN — the one mechanical question this research answers) — pick the exact green-path plumbing: (i) direct-to-`origin/main` recapture PR vs (ii) prove idempotency vs `HEAD` in-phase and defer origin/main reconciliation to the integration merge. Policy is locked; only plumbing is open.
- **D-03** — Compare-mode zero PNG drift across all 6 Playwright projects; allowlists empty at steady state; approval via `snapshot-recapture-gate.sh`. This is GATE-01's "compare-mode re-render shows zero PNG drift" leg.
- **D-04** — Run the EXISTING `scripts/ci/admin-acceptance-smoke.sh` (PORT=4017) + install-golden byte-diff under the **phx_new 1.8.7** pin; build no new harness. A real installer-template-drift regression is a FIX commit, not just a tick.
- **D-05** — Accept known/env failures, do NOT fix: 3 `Sigra.UpgradeIntegrationTest` env-DB failures + the `NoopTest` shard-log-capture flake (confirm-in-isolation first). Re-confirm 204 D-08's stale-contract fixes are green; do NOT re-fix.
- **D-06** — Produce `.planning/milestones/v1.42-MILESTONE-AUDIT.md` via `gsd-audit-milestone`; CITE the committed persona-JTBD panel + 8 per-surface docs (do NOT re-run the persona review); include the four RATIFY-style adversarial checks.
- **D-07** — Fix the stale `Status: PRE-FIX` header in `v1.42-PERSONA-JTBD-PANEL.md:6` → POST-FIX.
- **D-08** — Close-out ticks: mark Phase 208 complete; flip GATE-01/GATE-02 `[ ]→[x]` + coverage rows; correct `STATE.md milestone_name`; flip ROADMAP milestone status.
- **D-09** — NO `v1.42` git tag (dropped after v1.35).
- **D-10** — No scope creep: no new admin surfaces, no new Tier-2 ratchets, no product-behavior changes.

### Claude's Discretion
- Plan decomposition (single ratification plan vs split verify/parity/audit/housekeeping).
- Exact adversarial-check phrasing in the audit doc (bounded by 204 D-10 shape).
- Whether `NoopTest` gets a cheap determinism fix or stays documented-known (lean documented-known unless the isolation run shows the fix is trivial — the isolation run below passed 3/3).
- Exact commit grouping for the D-02 recapture (canary + its PNGs must be a coherent, reviewable, same-commit diff — 204 D-05 discipline).

### Deferred Ideas (OUT OF SCOPE)
- No net-new admin surfaces or Tier-2 ratchets — belongs to a future milestone.
- All reviewed-not-folded todos (uat-demo-dx-polish, migrate-schema helper, per-shard DB, runtime-auth-prefix, app-css-comment-corruption cleanup, vaultr rebrand residuals, white-label email theming, oban-enqueue-unguarded, phase200/phase209 code-review-deferred, ci-native board baselines) → backlog / future milestones.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GATE-01 | Terminal ratification — every ledger cell reads Tier-2, `quality-ledger-monotonic.sh --base origin/main` exits 0, all baselines recaptured with both allowlists empty and both canaries byte-stable, compare-mode re-render shows zero PNG drift (idempotency proven). | Ledger verified all-36-cells-bare-`2` + monotonic guard exits 0 live (Ground-Truth §1). Canary/drift green-path resolved by the D-02a recommendation below. Compare-mode zero-drift procedure in §"D-02a Command Sequence". `REQUIREMENTS.md:44`. |
| GATE-02 | Installer↔example byte-parity + golden fixture green + generated-host parity proven (fresh `phx.new` + `mix sigra.install` + admin-acceptance smoke renders elevated styled admin); adversarial milestone audit records persona-JTBD verdicts as Tier-2 evidence. | `admin-acceptance-smoke.sh` runnable as-is (PORT=4017); phx_new pin risk flagged (§"Environment Availability"). Milestone-audit doc shape + persona-panel evidence confirmed (§"Milestone Audit"). `REQUIREMENTS.md:45`. |
</phase_requirements>

## Summary

This is a **verify-and-lock** phase, not a feature phase — the direct analog of the completed Phase 204. Live verification this session confirms the terminal state is already correct on the branch: `guides/reference/admin-quality-ledger.md` reads bare `2` in all 36 tier cells, `quality-ledger-monotonic.sh --base origin/main` exits 0, both allowlists are empty, and `snapshot-canary-guard.sh --base HEAD` PASSES with **0 changed slugs (zero drift)** — i.e. terminal idempotency is already proven vs HEAD. The only non-trivial gate is the snapshot/canary drift vs the stale `origin/main` (local `main` is **368 commits ahead**, never pushed).

The central open question (D-02a) is purely mechanical: how does the canary guard turn green vs `origin/main`, given the WCAG-fixed `impersonation-banner` canary bytes only live on local `main`? The decisive precedent is **Phase 204 D-05**, which resolved the identical reconciliation by **committing the canary rebase + its recaptured PNGs in one atomic commit onto the working branch and proving zero-drift vs `HEAD`** — it did **not** push a recapture PR to origin/main. Phase 204's own summary (`204-03-SUMMARY.md:25,104,134`) is explicit: "`--base HEAD` canary guard shows 0 changed slugs (zero drift) = approval; `--require-all` is a pre-commit check that cannot work post-commit." **Recommendation: mechanism (ii)** — prove terminal idempotency vs HEAD in-phase; origin/main reconciliation is owned by the integration merge (PR #63), where `github.base_ref = main` means the integration PR carries the WCAG-fixed canary bytes as its own established baseline.

One correction to CONTEXT.md's drift enumeration surfaced during live tracing: there are **5** non-canary checkpoint slugs drifted vs origin/main, not 4. CONTEXT lists `audit-explorer`, `user-audit`, `global-user-index`, `org-scoped-admin` (all `modified`); live `git diff` also shows **`user-sessions` as `added`** (3 new PNGs). The guard never *reports* `user-sessions` because the `impersonation-banner` canary `fail()` (`snapshot-canary-guard.sh:104`) calls `exit 1` and short-circuits the evaluate loop before reaching it. This is latent and harmless for mechanism (ii) — HEAD is already zero-drift — but the plan must not assume "exactly 4 checkpoint slugs."

**Primary recommendation:** Adopt D-02a mechanism (ii). Prove `snapshot-canary-guard.sh --base HEAD` = PASS (0 drift) and `quality-ledger-monotonic.sh --base origin/main` = exit 0 in-phase (both already true today), verify compare-mode zero-drift via `snapshot-recapture-gate.sh`, run GATE-02 parity after installing phx_new **1.8.7** (currently **1.8.8** is installed — a blocker for the golden byte-diff), then do the D-06/D-07/D-08 doc housekeeping. No push to origin/main from this phase.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Ledger terminal-state verification | CI / Static guard (`quality-ledger-monotonic.sh`) | Docs (`admin-quality-ledger.md`) | Forward-only lock is a git-diff guard over a committed markdown table; no runtime involved. |
| Snapshot/canary drift reconciliation | CI / Static guard (`snapshot-canary-guard.sh`) + Playwright compare-mode | Example dev server (render source) | Byte-diff of committed PNGs vs a git base ref; render truth comes from the booted example app. |
| Generated-host parity | Build/Install (`mix sigra.install`) + Frontend server (booted phx.new host) | CI (`admin-acceptance-smoke.sh`) | Proves the installer template → generated host renders the elevated admin at runtime, not just in the example. |
| Adversarial milestone audit | Docs / process (`gsd-audit-milestone`) | Evidence (persona-JTBD panel + 8 surface docs) | Judgment doc that CITES already-captured Tier-2 evidence; no new capture. |
| Milestone-close housekeeping | Docs (ROADMAP/REQUIREMENTS/STATE) | — | Pure planning-doc edits; no code, no tag. |

## D-02a — DECISIVE RECOMMENDATION: mechanism (ii), prove-vs-HEAD + defer origin/main to integration merge

### The mechanics, traced with evidence

**How the canary guard computes drift** (`snapshot-canary-guard.sh`):
- Line 79: `git -C "$ROOT" diff --name-status "$BASE" -- "$SNAP_DIR"` — this diffs the **committed tree at `HEAD` (working-tree tracked state) vs the `$BASE` ref's committed tree**. For tracked PNGs it compares *committed bytes*, not un-staged working-tree edits (a `git diff <ref>` with no `--staged` and no second ref compares working tree vs `<ref>`; but PNGs recaptured and committed are part of HEAD, so effectively committed-vs-committed once committed).
- Lines 82-87: a second pass adds **untracked** (`??`) PNGs as `added`.
- Line 93-104: if a changed slug **is the canary**, `added` is tolerated (line 100-102, "first-established"), but `modified`/`deleted`/`mixed` calls `fail()` → **`exit 1` immediately** (line 104). This is the hard-forbid; the canary is never allowlistable.
- Line 106-108: any other changed slug not in the allowlist is a violation (accumulates `violations=1`, does not exit early).

**Live ground truth (this session, `git rev-list --count origin/main..HEAD` = 368):**

| Guard invocation | Result | Evidence |
|---|---|---|
| `snapshot-canary-guard.sh --base HEAD` | **PASS (0 changed slugs)** — terminal idempotency already proven | Ground-Truth §2 |
| `snapshot-canary-guard.sh --base origin/main` | **FAIL** — 4 modified checkpoint slugs + canary modify (exits at canary) | Ground-Truth §2 |
| `quality-ledger-monotonic.sh --base origin/main` | **PASS (36 cells)** exit 0 | Ground-Truth §1 |

**What committing recaptured PNGs onto local `main` does:**
- **vs `HEAD`:** already 0 drift (the WCAG-fixed canary + all recaptured checkpoint PNGs are already committed on this branch — that is *why* `--base HEAD` PASSes today). Idempotency is a property of the branch, already satisfied.
- **vs `origin/main`:** still FAILs, and **re-baselining into local `main` alone cannot fix this** until `origin/main` itself carries the WCAG-fixed canary bytes — because the guard diffs committed-tree-vs-committed-tree and origin/main still holds the pre-fix canary. This is exactly the D-02a tension.

### Why mechanism (ii), not (i)

**Phase 204 is the strongest precedent and it used (ii).** `204-03-SUMMARY.md`:
- `:25` — key decision: "Recapture gate post-commit verification: `--base HEAD` canary guard shows 0 changed slugs (zero drift); `--require-all` is a pre-commit check that cannot work post-commit when working tree = HEAD."
- `:104` — "**Recapture gate `--require-all` works pre-commit, not post-commit** ... After commit (working tree = HEAD), 0 changed slugs is the correct zero-drift proof."
- `:134` — "Post-commit verification uses `snapshot-canary-guard.sh --base HEAD` directly (0 changed slugs = zero drift = approval), not the full gate script with `--require-all`."
- The canary rebase landed in **one atomic commit `c96749fa`** (`204-03-SUMMARY.md:90-98,149`) on the working branch. **There is no push-to-origin/main recapture-PR step anywhere in the 204 plans or summaries.** 204 proved-vs-HEAD-and-deferred origin/main to the merge.

**The `ci.yml:1839-1854` human-visual recapture-PR path is explicitly REJECTED by D-02** (it opens `gh pr create --base main` with body "the gate is human visual review of these PNG diffs"). Mechanism (i) is a variant of that rejected path (publishing bytes to origin/main out-of-band) and re-introduces the human-review gate D-02 forbids. Reject (i).

**How origin/main actually goes green — owned by the integration merge, not this phase.** CI computes `base=origin/${{github.base_ref}}` for PRs (`ci.yml:70-72`). `github.base_ref` is the **PR's target branch**. When the v1.42 integration branch is PR'd (PR #63, the folded todo's "can v1.42 merge cleanly" gate), its diff base is `origin/main`; the WCAG-fixed canary appears as a `modify` **on that PR** → the canary guard would fire on `fast_checks`. Two clean resolutions, both outside 211's boundary and both matching the established CI machinery:
  1. **Delete-then-recapture-as-`added`** — the proven CI pattern at `ci.yml:1486-1498` (design lane) deletes the canary PNGs *before* `--update-snapshots` so Playwright re-creates them as **`added`**, which the guard tolerates as "first-established" (`snapshot-canary-guard.sh:100-102`). This re-establishes the canary with the new bytes without a forbidden `modify`, on the integration branch, with no allowlist and no human review. This is the mechanically clean way to publish the WCAG-fixed canary to origin/main at merge time.
  2. Or the integration merge lands directly (the 368-commit fast-forward), after which origin/main carries the new canary bytes and every subsequent PR sees them byte-stable.

**Conclusion:** Phase 211 owns proving GATE-01/GATE-02 vs the state it controls (HEAD + origin/main-ledger). It does **not** own pushing canary bytes to origin/main. The `--base origin/main` canary FAIL is a **publish-time reconciliation owned by the integration merge (PR #63)**, resolvable with the already-in-tree delete-then-`added` re-establishment pattern. 211 should *document* this hand-off in its verification + the milestone audit so the close reads honestly, but must not attempt an out-of-band origin/main push (that would be the rejected human-review path and is out of the terminal-ratification boundary).

### D-02a Command Sequence (reproducible, local)

Because the branch is **already terminal-idempotent** (canary `--base HEAD` = 0 drift; ledger vs origin/main = exit 0), the "recapture" is a **verification pass**, not a fresh capture — matching 204's "compare-mode zero-drift, not force-recapture." The steps prove the state; they do not mutate PNGs unless a compare-mode diff surfaces (which would itself be a finding).

**Boot gotchas (from CONTEXT + project memory) — bake into the plan:**
- Boot the example dev server on an **alt PORT** — `4000` collides with Rulestead Docker; `4011` is the recapture-gate default (`snapshot-recapture-gate.sh:18`). Use `PORT=4011`.
- **Pre-compile before launch** (`mix compile`) to avoid the code-reload crash on first request.
- Export `SIGRA_EXAMPLE_URL=http://localhost:4011` for the gate.
- Source `tmp/db.env` (or fall back to localhost:5432) so the server's `PGPORT` matches the live test Postgres — 204 lost time to a stale-port server (`204-03-SUMMARY.md:111-116`).
- **darwin vs ubuntu caveat:** `admin-design` (board-*) baselines are **CI-native / ubuntu** (project memory: `admin-design baselines are CI-native`). A local **darwin** `--update-snapshots` of `board-*` PNGs is **WRONG** and will produce spurious 1px-height diffs (204 confirmed these are pre-existing local artifacts, `204-03-SUMMARY.md:105,133`). Prove the design lane via **compare-mode only** locally; never re-record board-* on darwin. The checkpoint lane (`admin-checkpoints`) is the one that proves idempotency locally.

```bash
# 0. Live PG + alt port; pre-compile (avoids first-request reload crash)
cd /Users/jon/projects/sigra
source tmp/db.env 2>/dev/null || true          # or rely on localhost:5432 fallback
MIX_ENV=dev mix compile
PORT=4011 PHX_SERVER=true MIX_ENV=dev mix phx.server >/tmp/example-4011.log 2>&1 &
# wait for http://localhost:4011/ to answer before proceeding

# 1. GATE-01 leg A — ledger terminal-lock (already green live)
bash scripts/ci/quality-ledger-monotonic.sh --base origin/main      # expect: PASS (36 cells), exit 0

# 2. GATE-01 leg B — in-phase idempotency vs HEAD (already green live)
bash scripts/ci/snapshot-canary-guard.sh --base HEAD                 # expect: PASS (0 changed slugs)
SNAP_DIR="test/example/priv/playwright/tests/admin-design.spec.ts-snapshots" \
  bash scripts/ci/snapshot-canary-guard.sh --base HEAD \
    --allowlist test/example/priv/playwright/snapshot-allowlist-design --canary board-notice  # expect: PASS

# 3. GATE-01 leg C — compare-mode zero PNG drift across all 6 projects + component byte-goldens
#    (allowlists empty => pass NO intended slugs; the gate runs full compare + drift/canary guard)
SIGRA_EXAMPLE_URL=http://localhost:4011 \
  bash scripts/ci/snapshot-recapture-gate.sh  <intended-slug-if-any>
#    NOTE: the gate REQUIRES >=1 slug arg (snapshot-recapture-gate.sh:20-23). At steady state there is
#    no intended slug. Two options for the planner:
#      (a) run the two compare-mode Playwright projects + the two --base HEAD canary guards directly
#          (steps 2 + the playwright invocations at snapshot-recapture-gate.sh:64-69,81-86,97-98), OR
#      (b) if a real compare-mode diff surfaces on the CHECKPOINT lane (never board-* on darwin),
#          that is an intended recapture: --update-snapshots that project, restore any incidental
#          non-intended PNGs, then `snapshot-recapture-gate.sh <slug>` with the slug in the SAME diff,
#          then reset the allowlist to empty (204 D-05 same-commit discipline).

# 4. Confirm both allowlists empty at steady state (comments only)
grep -vE '^\s*#|^\s*$' test/example/priv/playwright/snapshot-allowlist        # expect: no output
grep -vE '^\s*#|^\s*$' test/example/priv/playwright/snapshot-allowlist-design # expect: no output
```

**Steady-state expectation:** because the branch is already idempotent, step 3 is a *compare-mode confirmation* (Playwright projects pass with 0 diffs on the checkpoint lane) and both allowlists stay empty. If a checkpoint compare-mode diff appears, it is a finding → recapture that slug in one commit + reset allowlist (204 D-05). Do **not** recapture board-* locally.

**GATE-02 legs (D-04) — run AFTER installing phx_new 1.8.7 (see Environment Availability):**
```bash
# (d) generated-host runtime parity — existing harness, PORT=4017
GITHUB_WORKSPACE=$(pwd) bash scripts/ci/admin-acceptance-smoke.sh            # expect: "success"
# install-golden byte-diff under the phx_new 1.8.7 pin (SEED-004)
mix archive.install --force hex phx_new 1.8.7                                # PRECONDITION
MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs                # expect: green under 1.8.7
```

## Ground-Truth Snapshot (captured this session, 2026-07-01)

### §1 — Quality ledger (D-01)
```
$ bash scripts/ci/quality-ledger-monotonic.sh --base origin/main
quality-ledger-monotonic: PASS (36 cells checked vs origin/main)   exit=0
```
- `admin-quality-ledger.md`: **all 36 tier cells read bare `2`** (grep for any non-`2` tier row returned empty; count of tier-`2` cells = 36). CONTEXT D-01 confirmed exactly.

### §2 — Snapshot/canary guard (D-02/D-03)
```
$ bash scripts/ci/snapshot-canary-guard.sh --base HEAD
snapshot-canary-guard: PASS (0 changed slug(s), all within allowlist)   exit=0

$ bash scripts/ci/snapshot-canary-guard.sh --base origin/main
FAIL: unintended snapshot change: audit-explorer (modified)
FAIL: unintended snapshot change: user-audit (modified)
FAIL: unintended snapshot change: global-user-index (modified)
FAIL: unintended snapshot change: org-scoped-admin (modified)
FAIL: canary snapshot modified: 'impersonation-banner' must stay byte-green ...   exit=1
```
- Allowlists (checkpoints + design): **both empty** (comments only). Confirmed.
- **CORRECTION to CONTEXT:** raw `git diff --name-status origin/main -- <checkpoint-snapshots>` shows **5** non-canary drifted slugs, not 4:
  - `modified`: `audit-explorer`, `user-audit`, `global-user-index`, `org-scoped-admin`
  - **`added`: `user-sessions`** (3 PNGs: chromium/dark/mobile — absent at origin/main; `git cat-file -e origin/main:...` → "exists on disk, but not in origin/main")
  - The guard never *reports* `user-sessions` because the `impersonation-banner` canary `fail()`/`exit 1` (`snapshot-canary-guard.sh:104`) short-circuits the evaluate loop first (verified via `bash -x` trace). Latent, not a problem for mechanism (ii) — HEAD is 0-drift — but the plan must not assume "exactly 4."
- Design lane vs origin/main also drifts (`board-mg-1/2/4/5/6/8/9` modified, `board-cfg-user-detail` added) but the **`board-notice` design canary is NOT in the drift set** — these are the expected CI-native board-* deltas that must NOT be recaptured on darwin. Design lane vs **HEAD** is clean.

### §3 — Known-failure set (D-05)
```
$ MIX_ENV=test mix test test/sigra/audit/forwarders/noop_test.exs
3 tests, 0 failures        # NoopTest passes in ISOLATION => confirmed shard-log-capture flake, not a regression
```
- 204 D-08 stale-contract tests re-confirmed green (do NOT re-fix):
```
$ mix test .../phase_192_known_failure_contract_test.exs .../phase_148_evaluator_funnel_and_first_run_dx_test.exs
4 tests, 0 failures
```
- `Sigra.UpgradeIntegrationTest` env-DB failures live at `test/upgrade_test.exs` (`seed_users!/2` / `run_mix ecto.create|migrate|run` under a per-fixture DB, ~lines 205-218). Accepted env failures — do NOT fix.

### §4 — Environment / phx_new pin (D-04) — **BLOCKER FLAGGED**
```
$ mix archive
* phx_new-1.8.8      # <-- 1.8.8 installed, NOT the pinned 1.8.7
```
- The install-golden byte-diff will **spuriously FAIL locally** under 1.8.8 (it injects the `root_tag_attribute` config block — CLAUDE.md / SEED-004). The plan MUST run `mix archive.install --force hex phx_new 1.8.7` before the GATE-02 golden/parity lane. Do NOT regenerate the fixture to "fix" the diff.

### §5 — Housekeeping literals (D-07/D-08) — exact current text for precise edits
- `STATE.md:4` → `milestone_name: CI-Gate Remediation`  ⟶ **`ADMIN-DS-ELEVATION`**
- `v1.42-PERSONA-JTBD-PANEL.md:6` → `**Status:** PRE-FIX — captures live DOM defect state before Wave-2 remediation`  ⟶ **POST-FIX** (remediation landed).
- `.planning/uat-evidence/v1.42-persona-jtbd/`: 8 docs present (`audit-index-live`, `audit-user-live`, `branding-live`, `index-live`, `organization-live`, `user-sessions`, `user-show-live`, `users-index-live`).
- `REQUIREMENTS.md:44` `- [ ] **GATE-01**: ...`  ⟶ `[x]`; `:45` `- [ ] **GATE-02**: ...` ⟶ `[x]`.
- `REQUIREMENTS.md:86` `| GATE-01 | Phase 211 | Pending |` ⟶ Complete/Satisfied; `:87` `| GATE-02 | Phase 211 | Pending |` ⟶ Complete/Satisfied.
- `ROADMAP.md:4` `**Status:** v1.42 ADMIN-DS-ELEVATION in progress (phases 205-211). Hex: v1.1.0.` ⟶ complete.
- `ROADMAP.md:8` `- 🚧 **v1.42 ADMIN-DS-ELEVATION** — Phases 205-211 (in progress)` ⟶ ✅ / complete.
- `ROADMAP.md:24` `- [ ] **Phase 208: L2 Meta-Component Group Elevation** ...` ⟶ `[x]` (208-03/GROUP-02 folded into 210-02).
- `ROADMAP.md:27` `- [ ] **Phase 211: Terminal Ratification** ...` ⟶ `[x]` (on close).
- `ROADMAP.md:230` `| 208. L2 Meta-Component Group Elevation | v1.42 | 2/3 | In Progress|  |` ⟶ Complete (mark 3/3 or note the fold, per `gsd-complete-milestone` expectation).
- `ROADMAP.md:233` `| 211. Terminal Ratification | v1.42 | 0/? | Not started | - |` ⟶ Complete on close.

### §6 — Milestone audit shape (D-06)
- `.planning/milestones/v1.42-MILESTONE-AUDIT.md` does **not** exist yet (confirmed). Precedents `v1.41-` and `v1.40-MILESTONE-AUDIT.md` present.
- `v1.41-MILESTONE-AUDIT.md` frontmatter shape to mirror: `milestone`, `milestone_name`, `audited` (ISO8601), `status` (`tech_debt`/`complete`), `scores:` (`requirements`/`phases`/`integration`/`flows`), `gaps: {}`, optional `tech_debt:` list; body = title + `## <REQ> Adversarial Checks` with the four (a)-(d) checks each backed by cited evidence.
- Persona evidence to CITE (do NOT re-run): `.planning/v1.42-PERSONA-JTBD-PANEL.md` (roll-up, all 8 surfaces `actionable`/remediated) + the 8 per-surface docs above.
- Folded integration todo present: `.planning/todos/pending/2026-06-30-v142-integration-snapshot-canary-drift.md`.

## Architecture Patterns

### Ratification flow (204 → 211, unchanged mechanics)
```
                       ┌─────────────────────────────────────────────┐
   local main (368     │  guides/reference/admin-quality-ledger.md    │
   ahead of origin) ──▶│  36 cells all bare `2` (Phase 210 flipped)   │
                       └───────────────┬─────────────────────────────┘
                                       │ quality-ledger-monotonic.sh --base origin/main
                                       ▼  (PASS, exit 0 — forward-only lock)     [GATE-01 leg A]
   PNG baselines  ─────────────────────┼─────────────────────────────
   (checkpoints + design)              │
                                       ├─ snapshot-canary-guard.sh --base HEAD  (PASS, 0 drift)  [GATE-01 leg B: idempotency]
                                       ├─ snapshot-recapture-gate.sh  (compare-mode 6 projects + drift/canary + byte-goldens)  [GATE-01 leg C]
                                       │      allowlists EMPTY at steady state
                                       ▼
   integration merge (PR #63)  ── owns origin/main reconciliation ──▶ canary re-established as `added`
                                       (ci.yml:1486 delete-then-recapture pattern) OR fast-forward merge
   generated host  ─────────────────────────────────────────────────
   fresh phx.new 1.8.7 → mix sigra.install → admin-acceptance-smoke.sh (PORT=4017)  ──▶ elevated admin renders  [GATE-02 parity]
   install-golden byte-diff (phx_new 1.8.7 pin)  ──▶ green   [GATE-02 byte-parity]
                                       ▼
   gsd-audit-milestone  ──▶ v1.42-MILESTONE-AUDIT.md (cites persona panel + 8 surface docs)  [GATE-02 SC-4]
                                       ▼
   housekeeping: ROADMAP / REQUIREMENTS / STATE edits (NO git tag)  ──▶ milestone closed
```

### Pattern: canary re-baseline via delete-then-`added` (for the integration merge, NOT 211)
**What:** To change an established canary's bytes without tripping the modify-forbid, delete the canary PNGs before `--update-snapshots` so Playwright re-creates them as `added` (the guard's tolerated "first-established" path).
**When to use:** Only at the origin/main publish boundary (integration merge). Cited from `ci.yml:1486-1498` (design lane, `board-notice`).
**Why 211 doesn't need it:** 211 proves vs HEAD (already 0-drift). The canary bytes are already the WCAG-fixed baseline on this branch.

### Anti-Patterns to Avoid
- **Recapturing board-* (admin-design) PNGs on darwin** — they are CI-native/ubuntu; local recapture injects spurious 1px diffs. Prove design lane compare-mode only; never `--update-snapshots` board-* locally.
- **Reverting the canary to origin/main's pre-fix bytes** — re-opens the WCAG AA `.vt-status-pill` failure (D-02 explicitly rejects).
- **Opening a `ci.yml:1852`-style human-visual recapture PR** — D-02 rejects the human-review path; the automated gate is the approval.
- **Regenerating the install-golden fixture to silence a 1.8.8 diff** — install phx_new 1.8.7 instead (SEED-004).
- **Creating a `v1.42` git tag** — D-09; milestone tags dropped after v1.35.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PNG drift / canary approval | A new drift script or manual `git status` eyeball | `snapshot-canary-guard.sh` + `snapshot-recapture-gate.sh` (exist) | D-04/D-10 forbid new gate scripts; the toolchain is the ratified approval mechanism. |
| Ledger forward-only lock | A custom monotonic check | `quality-ledger-monotonic.sh` (exists, green live) | Already the merge-blocking guard. |
| Generated-host parity | A bespoke scaffold script | `admin-acceptance-smoke.sh` (exists, PORT=4017) | 204 D-12 precedent; proven RUN_PARITY lane. |
| Milestone audit | Freehand audit prose | `gsd-audit-milestone` skill against `v1.41-/v1.40-` templates | Consistent frontmatter/body; cites evidence. |

**Key insight:** This phase *runs* existing tooling and *edits docs*. It builds nothing (D-04, D-10). Every "capability" already has an owner in-tree.

## Runtime State Inventory

This is a docs/verification phase touching planning markdown + PNG baselines, not a rename/refactor/migration. No stored data, live-service config, OS-registered state, secrets, or build artifacts carry milestone-name strings that break at runtime. **None found — verified by scope:** the only mutable state is (a) committed PNG baselines (owned by the compare-mode gate) and (b) planning-doc text edits (STATE/ROADMAP/REQUIREMENTS/persona-panel). The `STATE.md milestone_name` correction (D-08.3) is a docs edit, not a runtime key.

## Common Pitfalls

### Pitfall 1: Assuming exactly 4 checkpoint slugs drift vs origin/main
**What goes wrong:** CONTEXT says 4; there are 5 (`user-sessions` is `added` and masked by the canary early-exit).
**How to avoid:** For any origin/main-facing reasoning, use raw `git diff --name-status origin/main -- <snap-dir>`, not the guard's (short-circuiting) output. For 211 itself this is moot — prove vs HEAD (0 drift).

### Pitfall 2: phx_new 1.8.8 installed instead of 1.8.7
**What goes wrong:** Golden byte-diff fails locally with a spurious `root_tag_attribute` diff; someone "fixes" it by regenerating the fixture (SEED-004 violation).
**How to avoid:** `mix archive.install --force hex phx_new 1.8.7` before the GATE-02 lane. Warning sign: golden_diff_test failing on a config/config.exs delta.

### Pitfall 3: Stale example dev-server port after a Docker/PG restart
**What goes wrong:** Server holds an old `PGPORT`; registration silently fails; Playwright checkpoint aborts (bit 204, `204-03-SUMMARY.md:111-116`).
**How to avoid:** Kill any running example server, `source tmp/db.env`, pre-compile, then boot on PORT=4011.

### Pitfall 4: `snapshot-recapture-gate.sh` requires ≥1 slug arg
**What goes wrong:** At steady state there is no intended slug, but the gate exits 2 with a usage error if called with none (`:20-23`).
**How to avoid:** Either run the compare-mode Playwright projects + `--base HEAD` canary guards directly for the zero-drift confirmation, or (if a real checkpoint diff surfaces) pass that one slug and reset the allowlist after.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL (test) | example boot, admin-acceptance-smoke | ✓ (per CLAUDE.md; `tmp/db.env` or localhost:5432) | — | localhost:5432 default |
| phx_new archive | GATE-02 golden byte-diff + admin-acceptance-smoke | ✓ but **WRONG PIN** | **1.8.8 installed; 1.8.7 required** | `mix archive.install --force hex phx_new 1.8.7` (REQUIRED before GATE-02) |
| Node/Playwright | compare-mode + generated-host specs | ✓ (example priv/playwright; `npm ci` guarded) | — | `npm ci` in playwright dir |
| Elixir/Erlang | all mix tasks | ✓ | ~>1.18 / OTP 27 (per CLAUDE.md) | — |

**Missing dependencies with no fallback:** none blocking.
**Wrong-version dependency (must correct):** phx_new 1.8.8 → 1.8.7 before the GATE-02 lane (SEED-004). Treat as a plan precondition step, not a code fix.

## Validation Architecture

> Nyquist: this phase's "validation" IS the gate toolchain — the held-out proof is compare-mode re-render (property: idempotency) and generated-host runtime parity (property: installer↔example equivalence). No new ExUnit needed beyond confirming the known-failure set.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (`mix test`) + Playwright (`test/example/priv/playwright`) + bash CI guards |
| Config file | `test/example/priv/playwright/playwright.config.*`; `tmp/db.env` for PG |
| Quick run command | `MIX_ENV=test mix test test/sigra/audit/forwarders/noop_test.exs` (isolation flake check) |
| Full suite command | `MIX_ENV=test mix test` (accept D-05 known/env failures) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | Exists? |
|--------|----------|-----------|-------------------|---------|
| GATE-01 | Ledger forward-only lock | guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ (green live) |
| GATE-01 | Idempotency (0 PNG drift vs HEAD) | guard | `bash scripts/ci/snapshot-canary-guard.sh --base HEAD` (×2 lanes) | ✅ (green live) |
| GATE-01 | Compare-mode 6-project zero drift | ui | Playwright compare-mode via `snapshot-recapture-gate.sh` legs | ✅ |
| GATE-02 | Generated-host parity | integration | `GITHUB_WORKSPACE=$(pwd) bash scripts/ci/admin-acceptance-smoke.sh` | ✅ (needs phx_new 1.8.7) |
| GATE-02 | Install-golden byte-parity | golden | `mix test test/sigra/install/golden_diff_test.exs` | ✅ (needs phx_new 1.8.7) |
| GATE-02 | Adversarial audit records persona verdicts | doc | `gsd-audit-milestone` → `v1.42-MILESTONE-AUDIT.md` | ✅ (skill) |
| D-05 | Known-flake is a shard race, not a regression | unit | `mix test .../noop_test.exs` (isolation) | ✅ (3/3 live) |

### Sampling Rate
- **Per verification pass:** the two `--base HEAD` canary guards + ledger guard (seconds).
- **Phase gate:** full compare-mode 6-project run + admin-acceptance-smoke + golden byte-diff (under phx_new 1.8.7) all green; both allowlists empty; audit doc produced.

### Wave 0 Gaps
- None — the entire validation surface already exists in-tree. The only precondition is the phx_new 1.8.7 archive install (environment correction, not a test to author).

## Security Domain

No new auth paths, endpoints, schema, or crypto in this phase (verify-and-lock + docs). The one security-relevant invariant is **preserving the 204-03 WCAG AA `.vt-status-pill` contrast fix** (V-accessibility, not V-crypto) — reverting the canary would re-open a WCAG failure. No ASVS category is newly engaged; `security_enforcement` here reduces to "do not regress the shipped contrast fix." Threat model unchanged from v1.41 close.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Integration merge (PR #63) owns publishing the WCAG-fixed canary bytes to origin/main via fast-forward or the `ci.yml:1486` delete-then-`added` pattern | D-02a recommendation | LOW — if the merge instead needs an explicit re-establishment step, it is one added step on the integration branch, still automated/no-human-review; 211's in-phase proofs (HEAD 0-drift, ledger exit 0) are unaffected. Flag for the planner to note the hand-off in 211-VERIFICATION + the audit. |
| A2 | `user-sessions` `added` PNGs are intended (a real new checkpoint from phases 205-210), not accidental | Ground-Truth §2 | LOW — they are tracked at HEAD and part of the terminal state; if spurious, the compare-mode pass would surface it. Planner should spot-confirm they correspond to a real checkpoint in `admin-checkpoints.spec.ts`. |

**All other claims are VERIFIED live this session (command outputs in Ground-Truth) or CITED to file:line.**

## Open Questions

1. **Exact origin/main publish step timing (A1).**
   - What we know: 211 proves vs HEAD (0-drift, live-confirmed); ledger vs origin/main is exit 0 (live). The canary-vs-origin/main FAIL is structural (origin/main is 368 commits stale).
   - What's unclear: whether the integration merge lands as a plain fast-forward (canary bytes published automatically) or needs the explicit `ci.yml:1486` delete-then-`added` re-establishment on the integration branch.
   - Recommendation: 211 documents the hand-off; does NOT push to origin/main. The planner should add a verification note (not a task) describing the integration-merge reconciliation so the close reads honestly.

## Sources

### Primary (HIGH confidence — verified live this session)
- `scripts/ci/snapshot-canary-guard.sh` (lines 16-20, 71-87, 93-108, 114-127) — drift computation + canary short-circuit; traced with `bash -x`.
- `scripts/ci/snapshot-recapture-gate.sh` (lines 18, 20-23, 64-98, 100-105) — approval gate, per-lane routing, ≥1-slug requirement, RUN_PARITY.
- `scripts/ci/quality-ledger-monotonic.sh` (lines 22-33, 45-56) — forward-only lock; PASS 36 cells live.
- `scripts/ci/admin-acceptance-smoke.sh` (lines 20-31, 84-109, 230-334) — PORT=4017 generated-host parity.
- `.github/workflows/ci.yml` (lines 60-92 base calc; 1486-1498 delete-then-`added` canary re-establishment; 1839-1854 rejected human-visual recapture-PR path).
- `.planning/milestones/v1.41-phases/204-terminal-ratification/204-CONTEXT.md` + `204-03-SUMMARY.md` (lines 25, 90-98, 104, 111-124, 133-134, 149) — the decisive prove-vs-HEAD precedent + same-commit canary rebase (`c96749fa`).
- Live git: `git rev-list --count origin/main..HEAD` = 368; `git diff --name-status origin/main -- <snap-dir>` (5 checkpoint slugs incl. `user-sessions` added).
- `guides/reference/admin-quality-ledger.md` — 36 cells all bare `2` (grep-verified).
- `test/upgrade_test.exs` (~205-218), `test/sigra/audit/forwarders/noop_test.exs` (3/3 isolation), stale-contract tests (4/4).
- `.planning/STATE.md:4`, `.planning/REQUIREMENTS.md:44-45,86-87`, `.planning/ROADMAP.md:4,8,24,27,230,233`, `.planning/v1.42-PERSONA-JTBD-PANEL.md:6` — exact housekeeping literals.
- `mix archive` — phx_new-1.8.8 installed (pin mismatch).

### Secondary (MEDIUM confidence)
- Project memory notes: `admin-design baselines are CI-native`, `admin checkpoint Playwright`, `Sigra Docker DX`, `installer template drift`, phx_new 1.8.7 pin.

## Metadata

**Confidence breakdown:**
- D-02a recommendation (mechanism ii): HIGH — direct 204 precedent + live guard behavior traced.
- Ground-truth gate states: HIGH — captured live this session.
- Housekeeping literals: HIGH — exact line-numbered grep.
- Integration-merge publish timing (A1): MEDIUM — reasoned from CI base-ref logic + the in-tree delete-then-`added` pattern; not executed (out of 211's boundary).

**Research date:** 2026-07-01
**Valid until:** ~7 days (fast-moving: local `main`/origin divergence and the pending integration merge change the origin/main-facing facts; the HEAD-facing proofs are stable).

## RESEARCH COMPLETE

**Phase:** 211 - Terminal Ratification
**Confidence:** HIGH

### Key Findings
- **D-02a resolved → mechanism (ii):** prove idempotency vs HEAD in-phase (already green live: canary `--base HEAD` = 0 drift; ledger `--base origin/main` = exit 0), defer origin/main canary reconciliation to the integration merge (PR #63). Direct 204 D-05 precedent (`c96749fa`, `204-03-SUMMARY.md:25,104,134`); the `ci.yml:1852` human-review PR path is correctly rejected by D-02.
- **Terminal state already correct on-branch:** 36 ledger cells all bare `2`; both allowlists empty; `--base HEAD` canary guard PASSES with 0 drift.
- **CORRECTION:** 5 (not 4) non-canary checkpoint slugs drift vs origin/main — `user-sessions` is `added` and masked by the canary `exit 1` short-circuit (`snapshot-canary-guard.sh:104`). Harmless for (ii); plan must not hard-code "4."
- **BLOCKER for GATE-02:** phx_new **1.8.8** is installed, not the pinned **1.8.7** — must `mix archive.install --force hex phx_new 1.8.7` before the golden/parity lane (SEED-004).
- **D-05 confirmed:** `NoopTest` passes 3/3 in isolation (shard flake, not regression); 204 stale-contract tests green (4/4, do NOT re-fix); UpgradeIntegrationTest env-DB failures accepted.
- Housekeeping literals captured with exact line numbers for precise edits; milestone-audit + persona-panel evidence shapes confirmed.

### File Created
`.planning/phases/211-terminal-ratification/211-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack (gate toolchain) | HIGH | All four scripts read + run live; behavior traced. |
| Architecture (ratification flow) | HIGH | Mirrors verified 204 precedent; git ground-truth captured. |
| Pitfalls | HIGH | phx_new pin + slug-count + stale-port each verified live. |

### Open Questions
- A1: exact origin/main publish timing at the integration merge (fast-forward vs explicit `ci.yml:1486` re-establishment) — out of 211's boundary; 211 documents the hand-off, does not push.

### Ready for Planning
Research complete. The planner can spec: (1) in-phase HEAD-idempotency + ledger proof; (2) compare-mode zero-drift confirmation (checkpoint lane only on darwin; never board-*); (3) GATE-02 parity after installing phx_new 1.8.7; (4) D-06 audit doc citing the persona panel; (5) D-07 panel status fix; (6) D-08 housekeeping edits with the exact literals in Ground-Truth §5. No git tag (D-09). No new tooling (D-04/D-10). No origin/main push from this phase.
