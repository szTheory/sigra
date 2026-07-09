# Phase 220: Terminal Ratification - Context

**Gathered:** 2026-07-09 (assumptions mode + deep multi-lens research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Terminal/ship phase of milestone **v1.44 ADMIN-UX-RATCHET** (phases 216–220). Scope (RATIFY-01,
SC-1…SC-4): (1) confirm the award/quality sub-score cells are locked forward under the monotonic
ratchet guards, (2) commit a harness runbook usable by a zero-context future agent, (3) ship the
milestone via a PR gated on the five ruleset-required CI checks, (4) keep the LLM panel advisory /
off-CI in the shipped state.

**In scope:** verifying existing guards run green live against the real merge-base; a light runbook
freshness commit; resolving the `cheerio` `fast_checks` break; reconciling the one-canary merge
drift; assembling the milestone-ship PR (readiness record only — the actual merge is `/gsd-ship`,
archival is `/gsd-complete-milestone`).

**Out of scope / NOT this phase:** new admin-UI elevation, new probes/lenses, new award bands,
re-rendering/re-climbing cells, weakening any guard, digest-pinning the Playwright image (deferred
CI-hardening), and the mechanical PR-merge / milestone-archival (deferred to `/gsd-ship` +
`/gsd-complete-milestone` per the 215 precedent).
</domain>

<decisions>
## Implementation Decisions

### Situational anchor (verified facts driving every decision)
- The branch `gsd/phase-219-baseline-recapture-canary-reconciliation` is **189 commits ahead of
  origin/main, 0 behind** — it is the SOLE integration branch holding all of v1.44 (216–219).
  Nothing from v1.44 is on main; main is at v1.43 close-out (PR #68, `f2e54612`).
- The 5 ruleset-required checks (ruleset 14941512) are EXACTLY: `Library tests`, `Example unit
  smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke
  (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`. **`fast_checks` and
  `ci-gate` are NOT required** — a PR is mergeable with `fast_checks` red.
- **Baseline drift vs origin/main is exactly 3 PNGs** — the `impersonation-banner` checkpoint
  canary (chromium/dark/mobile), all `M` (modified). `board-notice` and the other ~112 baselines
  ALREADY match main. (The Phase-219 handoff's "all 115 modified" worst case did NOT materialize;
  verified via `git diff --name-status origin/main...HEAD -- '*.png'`.) The 3 PNGs are the correct
  fresh amd64 bytes (#71 recapture `ed692906`); main holds the stale darwin #64 bytes.

### Award / quality ledger lock (SC-1)
- **D-01:** No net-new guard code. The forward-only lock already exists and is wired into
  `fast_checks`: `award-guard.mjs` (band-decrease → FAIL, `ci.yml:133`) and
  `quality-ledger-monotonic.sh` (tier-decrease → FAIL, `ci.yml:120`), both diff against the resolved
  merge-base (`ci.yml:79–85`). Terminal posture is **verify-then-confirm, not fresh-climb** — a
  fresh re-render could legitimately shift a geometry-adjacent finding and spuriously red the ship;
  re-climbing also contradicts the ratchet's "trust prior verified state unless changed" contract.
- **D-02:** The lock is proven by a **LIVE guard execution against the real PR merge-base** (both
  guards exit 0; both self-tests `quality-ledger-monotonic.test.sh` + `award-guard.test.mjs` green in
  the same job) — NOT by a documentation assertion. This closes the repo's 216 SC-5 trap ("don't
  trust green self-tests; prove the live committed-HEAD path").

### Harness runbook (SC-2)
- **D-03:** Keep `guides/reference/admin-eval-runbook.md` (no rewrite — it already satisfies SRE
  runbook hallmarks: copy-pasteable one-iteration quick-start, failure-triage table, "where human
  sign-off sits", "reading the dossier" map, JUDGE-CI-01 off-CI split). `scripts/uat/RUNBOOK.md` is
  the unrelated UAT-demo runbook and is NOT the SC-2 artifact.
- **D-04:** Add three light, additive post-219 freshness notes (single commit) so a zero-context
  future agent (SC-2's explicit test) is oriented: (a) a **"you-are-here" preamble** distinguishing
  the local eval-harness loop (gitignored `eval/` bundles) from committed-baseline PNG recapture
  (CI-native ubuntu/amd64 only — NEVER darwin), (b) a note that the **merge-boundary
  `impersonation-banner` canary-red is EXPECTED** and reconciled post-merge (never allowlisted),
  (c) a one-line cross-ref to the **branch-scoped recapture dispatch** (`recapture_branch` input /
  `release_ref_guard` relaxation).

### Canary-merge reconciliation (SC-3) — quarantine strategy [LOCKED]
- **D-05:** The `snapshot-canary-guard.sh` will NEVER green a canary *modify* by design (D-06
  never-allowlistable tripwire); a one-time non-required `fast_checks` red on the canary rebirth is
  unavoidable *somewhere*. **Do NOT weaken/allowlist/bypass the guard.**
- **D-06:** **Quarantine the rebirth.** Split the 3 `impersonation-banner` PNGs into an isolated,
  baselines-only PR whose diff is *only* those 3 files; merge it FIRST. On that PR the required
  `Example Playwright smoke` goes **green** (fresh amd64 render matches the fresh baselines =
  positive byte-correctness proof) while only the non-required `fast_checks` reds on the intended
  canary-modify (documented one-line reason + human D-05-style scope check on a trivial 3-file diff).
  This mirrors the ecosystem "approve baseline → check turns green" idiom (Chromatic/Percy/reg-suit);
  the ecosystem never normalizes *merging* a red check on the artifact of record.
- **D-07:** After the quarantine PR merges, the terminal v1.44 milestone PR (rebased on the new
  main) sees **zero PNG diff → all six checks green** — a clean, caveat-free milestone artifact.
- **D-08:** **Footgun mitigation:** a `GITHUB_TOKEN`-authored PR does NOT retrigger workflow runs —
  open/push the quarantine PR via a PAT or a manual push so the 5 required checks actually run and
  can be confirmed green before merge.
- **Fallback (only if the extra merge is judged not worth it):** ship the terminal PR with
  `fast_checks` red directly — safe and D-06-compliant, but worse reviewer DX. Quarantine is the
  locked default.

### cheerio fast_checks break (SC-4) — lazy-require [LOCKED]
- **D-09:** `evidence-anchor-check.mjs` is a **deterministic D-09 cite-and-flip integrity gate (NOT
  the LLM panel)** — it uses cheerio's `$()` selector matching, zero model/API. It therefore SHOULD
  stay merge-blocking; SC-4/JUDGE-CI-01 bars only the *LLM panel*, not this derivative.
- **D-10:** Fix = **lazy-require** — move the runtime `require('cheerio')` call
  (`evidence-anchor-check.mjs:47`) to *after* the existing "no-bundles → exit 0" guard (~lines
  100–103). It is already a `createRequire(...)` runtime call (not a static ESM import), so this is a
  clean 2-line relocation: a bundle-free `fast_checks` checkout exits 0 without needing cheerio,
  while the gate stays fully armed wherever bundles exist (`admin_eval_render`). Faithful to the
  repo's own `--no-optional-deps` library-hygiene principle. REJECTED: job reorder (fragile /
  positional — silent re-break on any future step insertion); make advisory (discards real
  protection); root package.json (heavyweight second manifest, new lockfile-drift surface). Close
  the tracked TODO `.planning/todos/pending/2026-07-09-fastchecks-cheerio-missing-dep.md`.

### Milestone-ship PR mechanics (Area 5)
- **D-11:** Ship as **ONE full-branch merge-commit PR** (this branch → main, all commits,
  `.planning/` included) via `/gsd-ship`. NOT squash (would flatten 76 conventional `feat`/`fix`
  commits and gut the granular per-plan changelog release-please builds). NOT `/gsd-pr-branch`
  filtered (already tried this wave → PR #70, CLOSED; `.planning/` is first-class — ~1002 files
  already tracked on main). Matches the 215/v1.43 precedent (PR #67, full-branch merge commit).
  release-please auto-hides `docs`/`chore` planning commits from the changelog.
- **D-12:** **release-please ordering:** merge the open **PR #66 (`chore(main): release 1.2.0`)
  FIRST** to cut v1.2.0 for the already-landed prior milestones; then merge the v1.44 milestone PR;
  release-please regenerates a fresh release PR (→ v1.3.0, minor bump from the ~48 `feat`s) which is
  merged to publish to Hex. Keeps release cut-points aligned to milestone boundaries.
- **D-13:** Phase 220 itself produces a **close-readiness record** and DEFERS the actual PR merge to
  `/gsd-ship` and milestone archival to `/gsd-complete-milestone` (215 precedent; MUST NOT
  self-merge or archive within the phase).

### Coherent ship sequence (the through-line D-01…D-13 assemble into)
1. Ratification commits on THIS branch: cheerio lazy-require (D-10) → runbook freshness notes (D-04)
   → live-guard confirmation record (D-02) → close-readiness record (D-13).
2. Quarantine 3-PNG `impersonation-banner` canary PR — push via PAT (D-08), 5 required green +
   `fast_checks` red-as-expected (D-06), human scope-check, merge FIRST (D-07).
3. Merge release-please PR #66 → v1.2.0 (D-12).
4. Terminal v1.44 merge-commit PR (D-11), rebased on new main → 6/6 green, human sign-off.
5. `/gsd-ship` merge → release-please v1.3.0 → `/gsd-complete-milestone` archival.

### Claude's Discretion
- Exact wording/placement of the three runbook notes (D-04) and the close-readiness record format.
- Whether steps 2 and 3 (quarantine PR vs release-please #66) merge in either order — they are
  independent (the 3-PNG PR is a non-version-bumping `ci:`/`chore:` change); sequence them for
  whichever produces the cleanest terminal-PR rebase.

### Folded Todos
- `2026-07-09-fastchecks-cheerio-missing-dep.md` — folded into scope (resolved by D-09/D-10).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 220 detail block + v1.44 milestone framing + ruleset-14941512 note
- `.planning/REQUIREMENTS.md` — RATIFY-01 (line 46), requirement-coverage table
- `.planning/phases/219-baseline-recapture-canary-reconciliation/219-CONTEXT.md` — D-04/D-05/D-06
  (canary never-allowlistable), the deadlock insight, branch-scoped recapture dispatch
- `.planning/phases/219-baseline-recapture-canary-reconciliation/219-VERIFICATION.md` — the two
  Phase-220 handoffs (canary-merge deadlock; cheerio fast_checks regression) + "3 PNGs changed" proof
- `scripts/ci/snapshot-canary-guard.sh` — canary modify/delete forbid logic + never-allowlistable
  hard-block (D-06)
- `scripts/ci/award-guard.mjs` + `scripts/ci/quality-ledger-monotonic.sh` (+ their `.test`) — the
  monotonic ratchet guards to confirm live (D-01/D-02)
- `guides/reference/admin-award-ledger.json` + `guides/reference/admin-quality-ledger.md` — the
  locked cells
- `scripts/ci/evidence-anchor-check.mjs` — the deterministic D-09 gate; lazy-require fix site (D-10)
- `.github/workflows/ci.yml` — `fast_checks` job (~67–210): evidence-anchor step (~145), scoped
  `npm ci` (~206), base-ref resolve (~79–85), guard wiring (~119–135); branch-scoped recapture jobs
  (~1600–1980); `ci-gate` aggregation (~1448–1485)
- `guides/reference/admin-eval-runbook.md` — the SC-2 runbook (D-03/D-04)
- `.planning/todos/pending/2026-07-09-fastchecks-cheerio-missing-dep.md` — folded TODO (D-10)
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — required-vs-advisory check design
  (lines 307–324), `GITHUB_TOKEN` no-retrigger footgun (line 227), release-please/conventional-commit
  release path, `--no-optional-deps` hygiene (lines 55, 107)
- Prior terminal-ratification precedent (v1.43): `.planning/milestones/v1.43-phases/215-*` (PR #67
  full-branch ship; `/gsd-ship` + `/gsd-complete-milestone` deferral pattern)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Both ratchet guards + self-tests already built and wired** (216) — no new guard code (D-01).
  `award-guard.mjs` is two-directional (also blocks unearned band climbs), stronger than a naive
  counter.
- **Branch-scoped recapture machinery** (219, D-04): `recapture_branch` workflow_dispatch input +
  `release_ref_guard` relaxation + bot-PR-into-branch flow — the same "baselines-only PR" shape the
  quarantine PR (D-06) reuses.
- **`snapshot-canary-guard.sh`** already enforces the never-allowlistable canary (D-06 tripwire) and
  tolerates a pure `added` canary only when the base lacks the slug — the mechanism that makes the
  quarantine red unavoidable-by-design (correct behavior, not a defect).
- **`admin-eval-runbook.md`** — strong existing runbook, needs only additive orientation notes.
- **`evidence-anchor-check.mjs`** already loads cheerio via runtime `createRequire` + has a
  no-bundles early-exit → the lazy-require fix (D-10) is a 2-line relocation.

### Established Patterns
- Monotonic/ratchet forward-only guards vs merge-base; deterministic derivatives gate, LLM panel
  stays off-CI (JUDGE-CI-01).
- Full-branch merge-commit milestone ships with `.planning/` in history (PR #67/#63 precedent); `.planning/`
  is a tracked first-class citizen on main.
- release-please changelog is conventional-commit type-filtered (`feat`/`fix` surface; `docs`/`chore`
  hidden) — planning-commit noise is invisible in release notes without squashing.

### Integration Points
- The quarantine PR (D-06) → new main baseline → terminal PR sees zero PNG diff (D-07): the ordering
  seam is the whole SC-3 strategy.
- release-please PR #66 (v1.2.0) sits between the current main and the v1.44 ship (D-12) — merge
  ordering matters for clean milestone-aligned version cuts.
- cheerio fix (D-10) is what turns `fast_checks` green on the terminal PR (alongside the
  now-zero-canary-diff) → the "6/6 green" milestone artifact (D-07).
</code_context>

<specifics>
## Specific Ideas

- **Verified pivotal fact:** `git diff --name-status origin/main...HEAD -- '*.png'` → exactly 3
  `impersonation-banner` PNGs, all `M`. `board-notice` = 0 diff. This narrows SC-3 from the feared
  115-PNG wholesale swap to a clean 3-file quarantine.
- **Ecosystem lesson (cited):** Chromatic/Percy/reg-suit all resolve an intentional baseline update
  by turning the status check *green on approval* — they never merge a standing red on the feature
  PR. The quarantine PR is the git-native analogue; a standing red-with-a-reason on the primary
  merge trains reviewers to skim past red ("normalization of deviance").
- **Ecosystem lesson (cited):** ratchet guards' #1 footgun is base-branch drift — Sigra mitigates it
  correctly by resolving `merge-base origin/<base> HEAD` (ci.yml:79–85); the terminal obligation is to
  run the guard *live* against that real base, not trust the unit test (216 SC-5).
- **Positive-proof insight:** the quarantine PR's *required* `Example Playwright smoke` going green
  is itself the proof the recaptured amd64 bytes are correct (fresh render matches fresh baseline) —
  a stronger signal than a human eyeballing pixels.
</specifics>

<deferred>
## Deferred Ideas

- **Digest-pin the Playwright/Chromium image** — prevents a silent upstream FreeType/raster bump
  masquerading as canary drift. Worthwhile CI-hardening but out of the ratification scope (carried
  from 219-CONTEXT deferred).
- **Periodic (non-terminal) re-render cadence for locked cells** — ratchets can permanently trust a
  stale cell; a future cadence to revisit locked bands would close the "permanent-stale lock"
  ratchet footgun. Not a terminal-phase task.

### Reviewed Todos (not folded)
- The other pending todos (`mix-sigra-migrate-schema-helper`, `playwright-parallelization-per-shard-db`,
  `runtime-auth-prefix-override`, `white-label-auth-email-theming`, `app-css-corruption-guard-blind-spot`,
  `hex-retire-stray-1-20-0`, `218-rereview-followups`) are unrelated to terminal ratification — not
  folded; they belong to future milestones/backlog.
</deferred>
