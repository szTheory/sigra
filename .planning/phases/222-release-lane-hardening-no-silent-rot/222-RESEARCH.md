# Phase 222: Release-Lane Hardening (No Silent Rot) - Research

**Researched:** 2026-07-10
**Domain:** CI/CD release automation (GitHub Actions + release-please + Hex publish), shell version-resolution
**Confidence:** HIGH (all critical facts verified against live Hex + the actual repo files this session)

## Summary

This phase is CI-workflow + shell + docs only — no application code, no external package installs.
The CONTEXT.md already locked the architecture (D-01…D-08); the research job was to de-risk the
network- and workflow-dependent facts and pin the concrete implementation shape.

**One finding changes a locked mechanism and MUST reach the planner:** CONTEXT D-03/D-04 assume the
stray `1.20.0` Hex release is (or can be treated as) **retired**, and that dropping `(retired)` rows
from the `mix hex.info` candidate list fixes the resolver. **That premise is false.** Live Hex reports
`1.20.0` with `retirement: None` — it is a fully-live, non-retired release, and it is currently Hex's
`latest_stable_version`. Independently, `mix hex.info sigra` renders **no** `(retired)` marker in its
"Recent releases" block for *any* version (verified across sigra + 3 other packages). So a
"drop `(retired)` rows" filter would match nothing and the resolver would still select `1.20.0`.
The durable fix is an **explicit known-stray exclusion** (`grep -vxF '1.20.0'`), which I tested end-to-end
against live Hex — it correctly makes the resolver select `1.3.0`.

Everything else in CONTEXT verified cleanly: the `release_created → gate-ci-green → publish-hex`
needs-chain is exactly as claimed; the 30-min silent stall is real (`gate-ci-green` timeout, run #74 =
`failure`); the dry-run proof target `v1.3.0` exists as a real tag; `hex-publish.yml dry_run=true`
short-circuits the Hex write correctly; `release-please.yml` already holds `issues: write`.

**Primary recommendation:** Replace the D-13 stopgap pin with a tested known-stray exclusion in
`upgrade-smoke.sh` (NOT a retired-filter); implement the loud signal as ONE shared shell script
(`scripts/ci/notify-failure-issue.sh`) using the preinstalled `gh` CLI (no new third-party action),
invoked from a push/schedule-gated reporter job in `ci.yml` and a failure-aggregator job in
`release-please.yml`; run the `hex-publish.yml dry_run=true` proof against `v1.3.0`; add the recovery
subsection under MAINTAINING.md "Release automation (default)".

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Keep `upgrade_smoke` on nightly/push-to-main cadence — do NOT make it PR-visible (honors the
  documented D-07 perf residual, MAINTAINING.md:146). HARD-01's requirement is an explicit OR; take the
  loud-red-main branch.
- **D-02:** Satisfy HARD-01 via a `push:main`-gated notify step that **opens/updates a tracking GitHub
  Issue** when `upgrade_smoke` (or the `ci-gate` aggregate) concludes non-success. Prefer issue-open/update
  over a new push-only required aggregate (merge-strand risk under ruleset 14941512; ci.yml:400-406).
  Annotation-only is acceptable as a secondary; the durable, discoverable signal is the issue.
- **D-03:** Replace the D-13 stopgap env pin (`SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"`, ci.yml:643)
  with a durable filter in `scripts/ci/upgrade-smoke.sh` that drops the stray **before** `sort -V | tail -1`.
  Keep `SIGRA_UPGRADE_SMOKE_START_VERSION` as an **escape hatch only** — the default resolver must no
  longer depend on a hand-maintained floor. *(See Finding 1: the filter must be a stray-exclusion, not a
  retired-filter — the mechanism named in D-03 does not work as literally written.)*
- **D-04:** The exact live-Hex marker format must be verified before writing the filter. *(Done this
  session — see Finding 1. Result: the stray is NOT retired and `mix hex.info` shows no retired marker.)*
- **D-05:** Operator-truth: v1.2.0/v1.3.0 were published via manual `hex-publish.yml`, NOT via
  release-please auto-publish. Auto-publish is unproven end-to-end and proven to stall silently (30-min
  `gate-ci-green` timeouts).
- **D-06:** Do NOT cut a throwaway version bump. Satisfy HARD-02's OR via: (1) `hex-publish.yml
  dry_run=true` against the current shipped tag; (2) treat green ci-gate + wiring trace + shipped v1.3.0
  as readiness evidence; (3) build the "fails loudly" notify on `publish-hex` and `gate-ci-green`.
- **D-07:** Unify the loud-signal mechanism across HARD-01 and HARD-02 — one shared notify-on-failure
  pattern (issue open/update), two consumers.
- **D-08:** Recovery runbook lives in `MAINTAINING.md` as a new subsection near "Recovery / one-off
  publish" (MAINTAINING.md:266-276). Cross-reference `docs/release-runbook-v1-0.md` (:262); do NOT create
  a new top-level doc. Follow the "Forced-failure probe runbook (D-14)" precedent (:178-198).

### Claude's Discretion
- Exact notify implementation (composite action vs inline step; `actions/github-script` vs `gh issue`),
  issue title/label convention, whether an annotation is added alongside the issue.
- Retired/stray-filter grep/awk shape once the live marker format is confirmed.
- Whether the dry-run proof is a one-shot operator step or a re-runnable checkpoint.
- Exact runbook subsection heading and ordering within MAINTAINING.md.

### Deferred Ideas (OUT OF SCOPE)
- Retiring the stray Hex `1.20.0` (PUB-04) — deferred (Hex 2.5 blocks programmatic retire).
- Live green auto-publish via throwaway v1.3.1 bump — declined by Jon.
- Playwright per-shard-DB perf (PERF-01 / SEED-005).
- The admin `impersonation-banner` canary-recapture-lane noise (different lane).
- PUB-05 adopter `~> 1.0` proof / PROOF-01 trust bundle → Phase 223.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HARD-01 | The `Upgrade smoke` gate can no longer rot unnoticed — PR-visible **OR** a red result on `main` raises a loud, discoverable signal. | Finding 1 (durable stray-exclusion resolver, tested) + Finding 2 (shared notify-issue on `ci-gate` failure, push/schedule-gated). Take the OR = loud-red-main branch (D-01). |
| HARD-02 | release-please auto-publish verified to fire end-to-end **OR** fail loudly; recovery/manual-dispatch runbook documented. | Finding 2 (notify-issue on `gate-ci-green`/`publish-hex` failure) + Finding 3 (`dry_run=true` proof against v1.3.0) + Finding 4 (wiring trace confirmed) + Finding 5 (runbook insertion point). |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Resolve latest published start version | CI shell (`upgrade-smoke.sh`) | Hex registry (network) | Version selection is pure text parsing over `mix hex.info`; the stray-exclusion belongs in the resolver, not the workflow YAML. |
| Loud failure signal | GitHub Actions job + `gh` CLI | GitHub Issues API | Reporter jobs consume job `result`s and open/update a tracking Issue; logic centralized in one shell script (D-07). |
| Publish-path proof | GitHub Actions (`hex-publish.yml` dispatch) | Hex (dry-run, no write) | Operator-dispatched, idempotency-guarded; proves compile+test+package+dry-run without a real release. |
| Recovery documentation | `MAINTAINING.md` (maintainer entry-point index) | `docs/release-runbook-v1-0.md` (canonical) | Entry-point index points to canonical runbook; new subsection documents dispatch commands only (anti-duplication). |

## Standard Stack

No external packages installed. Tooling is all already-present:

| Tool | Where | Purpose | Notes |
|------|-------|---------|-------|
| `gh` CLI | ubuntu-latest runners (preinstalled) | open/update tracking Issue; dispatch workflows | Already used throughout `release-please.yml` (e.g. `gh pr view`, `gh run list`). No install step needed. `GH_TOKEN` env + `issues: write` required. [VERIFIED: release-please.yml uses `gh` extensively] |
| `mix hex.info` | resolver (`upgrade-smoke.sh:44,66`) | list published releases | Network call; renders "Recent releases" version+date lines, no retired markers. [VERIFIED: live run this session] |
| `grep`/`sed`/`sort -V` | resolver pipeline | version filter/select | Standard coreutils; `grep -vxF` is the tested stray-drop. [VERIFIED] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `gh issue` CLI in a shared shell script | `actions/github-script` (inline JS/octokit) | github-script is a new third-party action that MUST be SHA-pinned per repo convention (every action is pinned, e.g. `checkout@df4cb1c…`). `gh` is preinstalled, needs no new pinned dependency, and keeps the idempotency logic in a shellcheck-able, locally-testable script. **Recommend `gh` + shared script.** |
| Shared `scripts/ci/notify-failure-issue.sh` invoked from both workflows | Composite action `.github/actions/notify-failure-issue` | Composite action adds packaging indirection and is harder to unit-test than a shell script. The repo already carries ~10 `scripts/ci/*.sh` helpers. **Recommend the shell script** (lower-risk, DRY per D-07). |
| `mix hex.info` + stray-exclusion | `curl -s https://hex.pm/api/packages/sigra` + `jq` (authoritative `retirement` field, no truncation) | The JSON API is more robust (structured retirement, full release list) but adds a `jq` dependency and a bigger rewrite. Minimal-change stray-exclusion keeps the existing `mix hex.info` path. **Recommend stray-exclusion**; note JSON-API path as future hardening if retired-dropping is ever needed. |

**Installation:** None.

## Package Legitimacy Audit

**Not applicable** — this phase installs no external packages (npm/Hex/PyPI/crates). It edits GitHub
Actions workflow YAML, one shell script, and `MAINTAINING.md`. If any new GitHub Action were introduced
(e.g. `actions/github-script`), repo convention requires SHA-pinning it and letting Dependabot update —
but the recommendation avoids new actions entirely (uses preinstalled `gh`).

## Findings (De-Risking the Locked Plan)

### Finding 1 — D-04/D-03: the stray `1.20.0` is NOT retired; the retired-filter mechanism is invalid [HIGHEST PRIORITY]

**Verified live this session:**

- `curl -s https://hex.pm/api/packages/sigra` → `1.20.0 | retirement: None`; it is the API's
  `latest_stable_version` **and** `latest_version`. [VERIFIED: hex.pm API]
- `mix hex.info sigra` → `Config: {:sigra, "~> 1.20"}`, and its "Recent releases" block prints:
  ```
    1.20.0 (2026-04-28)
    1.3.0 (2026-07-10)
    1.2.0 (2026-07-10)
    1.1.0 (2026-06-13)
    1.0.0 (2026-06-03)
    ...
  ```
  **No `(retired)` suffix on any line.** Confirmed the same "no retired marker in Recent releases" across
  `distillery`, `poison`, `httpoison`. `mix hex.info` surfaces retirement only for a *specific* version
  query (`mix hex.info sigra 1.2.3` → a `Retired:` line), never in the package-level list. [VERIFIED]

**Consequence for D-03:** dropping `(retired)` rows from the `mix hex.info` candidate list would match
zero rows, and the resolver would still pick the stray. I reproduced the current bug and the fix:

```
# current pipeline (series=1) selects the STRAY:
sed -n 's/^  \([0-9.]*\).*/\1/p' | grep -E '^1\.[0-9]+\.[0-9]+$'
  → 1.20.0, 1.3.0, 1.2.0, 1.1.0, 1.0.0
  → sort -V | tail -1  ==>  1.20.0   ❌

# with stray-exclusion the resolver selects the real GA:
... | grep -vxF '1.20.0'
  → 1.3.0, 1.2.0, 1.1.0, 1.0.0
  → sort -V | tail -1  ==>  1.3.0    ✅
```
[VERIFIED: executed against live Hex this session]

**Concrete, tested filter (drop-in for `upgrade-smoke.sh:45`).** Insert the exclusion between the
existing series `grep` and the `sort -V | tail -1` at `:52`. Keep the exact-line, fixed-string match so it
can never accidentally drop a real version whose string contains `1.20.0` as a substring:

```bash
# Known immutable Hex strays: releases published in error that cannot be
# unpublished (outside the 1-hour window) or retired (Hex 2.5 blocks programmatic
# retire; manual retire is deferred PUB-04). They out-sort real GA, so drop them
# by exact version before selecting the latest. This is a durable fact, not a
# per-release floor — new real releases (1.4.0, 1.5.0, …) are unaffected.
SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS="${SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS:-1.20.0}"

resolve_latest_sigra_source() {
  local info versions selected
  validate_source_series
  info="$(mix hex.info sigra)"
  versions="$(printf '%s\n' "${info}" \
    | sed -n 's/^  \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' \
    | grep -E "$(series_regex)" \
    | grep -vxF -f <(printf '%s\n' ${SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS//,/ }) \
    || true)"
  if [[ -z "${versions}" ]]; then
    echo "FAIL: no published sigra release found on Hex for series ${SOURCE_SERIES}" >&2
    exit 1
  fi
  selected="$(printf '%s\n' "${versions}" | sort -V | tail -n1)"
  printf '%s' "${selected}"
}
```

Notes for the planner:
- **Do NOT remove** the `SIGRA_UPGRADE_SMOKE_START_VERSION` override block (`upgrade-smoke.sh:56-77`) — it
  stays as the escape hatch (D-03) **and** the phase_147 structural test asserts both
  `SIGRA_UPGRADE_SMOKE_START_VERSION` and `resolve_latest_sigra_source` still appear in the script
  (test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs:30-31). Renaming the function or deleting
  the env would break that test. [VERIFIED]
- **Remove** the `env: SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"` pin at **ci.yml:643** and its
  D-13 comment block (`:638-641`). After the resolver fix the default path no longer needs the floor.
- Making the exclusion env-driven (default `1.20.0`, comma-separated) keeps it configurable without a
  code edit if another stray ever appears; hardcoding a `STRAY_VERSIONS=("1.20.0")` constant is an equally
  valid, slightly simpler choice (Claude's Discretion, D-03).
- **Truncation is not a risk:** `mix hex.info` lists "Recent releases" **version-descending**, so the
  highest real version is always near the top; the `...` truncation only drops old low versions, which
  never affect `sort -V | tail -1`. The stray (highest version) is always visible and always excludable.

**This is the single item where the locked mechanism (D-03 "drop `(retired)` rows") does not survive
implementation-time verification. Plan the stray-exclusion instead. The *intent* of D-03 (durable, no
hand-maintained floor) is fully honored.**

### Finding 2 — D-02/D-06.3/D-07: the shared loud-signal mechanism

**Confirmed in-repo:**
- `ci.yml` workflow-default permissions are `contents: read` (ci.yml:31-32). A notify job needs a
  **job-level** `permissions: issues: write` override. [VERIFIED]
- `release-please.yml` already declares **workflow-level** `issues: write` (release-please.yml:22) — no
  per-job override needed there. [VERIFIED]
- `ci-gate` fails when `upgrade_smoke` fails on push:main (ci-gate `needs` includes `upgrade_smoke` at
  :1465; the aggregate treats only `success`/`skipped` as pass, :1498). But `ci-gate` is **not** an
  enforced required check (MAINTAINING.md:112) and has no failure consumer today → the silent rot. [VERIFIED]
- Precedent for a needs-free, push/schedule-gated reporter job that is NOT in `ci-gate.needs`:
  `nightly_probe` (ci.yml:2181, `if: github.event_name != 'pull_request'`). Copy this shape. [VERIFIED]
- `::error::` annotation precedent at ci.yml:1238 (inside the playwright seam aggregator) — usable as the
  optional secondary annotation (D-02). [VERIFIED]

**Recommended shape — ONE shared script, TWO consumers (D-07):**

`scripts/ci/notify-failure-issue.sh` (new): find-open-issue-by-label → comment-or-create (idempotent):
```bash
#!/usr/bin/env bash
set -euo pipefail
# Args/env: LABEL (stable, e.g. "release-lane-rot"), TITLE, BODY. Requires GH_TOKEN + issues:write.
existing="$(gh issue list --label "$LABEL" --state open --json number --jq '.[0].number' || true)"
if [[ -n "$existing" ]]; then
  gh issue comment "$existing" --body "$BODY"     # append occurrence, no spam
else
  gh issue create --label "$LABEL" --title "$TITLE" --body "$BODY"
fi
```
Idempotency = one durable tracking issue per label that accumulates occurrences; the maintainer closes it
when the lane is fixed (optionally a green run auto-closes — discretionary). The `BODY` should carry the
run URL (`${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`), the
failing job/surface, and the commit SHA.

**Consumer A — HARD-01 (ci.yml).** New job `notify_release_lane_rot`:
- `needs: [ci-gate]` (covers `upgrade_smoke` via the aggregate, per D-02)
- `if: always() && github.event_name != 'pull_request' && needs.ci-gate.result == 'failure'`
  — push/schedule/dispatch only, never PRs (honors D-01, avoids PR noise)
- `permissions: issues: write`, `env: GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}`
- **NOT** added to `ci-gate.needs`; **NOT** a required check → zero merge-strand risk (D-02).

**Consumer B — HARD-02 (release-please.yml).** New job `notify-release-failure`:
- `needs: [release-please, gate-ci-green, publish-hex]`
- `if: always() && needs.release-please.outputs.release_created == 'true' && (needs.gate-ci-green.result == 'failure' || needs.publish-hex.result == 'failure')`
  (consider also `== 'cancelled'` to catch cancellations)
- Uses the workflow-level `issues: write`; runs the same script with a distinct or shared label.
- A separate aggregator job (vs inline `if: failure()` steps in each job) is more robust: the
  `gate-ci-green` timeout `exit 1` → `result: failure` reliably fires the downstream reporter, and it
  mirrors the existing `ci-gate` aggregation pattern. **Recommend the separate job.**

**Composite-action vs inline decision (Claude's Discretion, D-02):** the **shared shell script called
inline from a job in each workflow** is the lower-risk choice — no new pinned third-party action, DRY
logic in one shellcheck-able file, and it reuses the `gh` CLI already trusted throughout the release
workflows.

### Finding 3 — D-06.1: the HARD-02 dry-run proof

`hex-publish.yml` inputs (hex-publish.yml:11-24): `tag` (:12, required), `release_version` (:16, required),
`dry_run` (:20-24, boolean, default false). [VERIFIED]

`dry_run=true` short-circuits every Hex write (verified against the actual `if:` guards):
- Idempotency check: `if: ${{ inputs.dry_run != true }}` (:170) — skipped for dry-run.
- Dry-run publish: `if: ${{ inputs.dry_run == true || steps.idempotency.outputs.skip != 'true' }}` (:178)
  → runs `mix hex.publish --dry-run --yes`.
- Real publish: `if: ${{ inputs.dry_run != true && steps.idempotency.outputs.skip != 'true' }}` (:184)
  → **not** reached when `dry_run=true`.
- Post-publish verify/evidence steps: all `if: ${{ inputs.dry_run != true }}` (:190/:207/:216). [VERIFIED]

So a `dry_run=true` run does the full compile + `mix test` (Postgres service) + `mix hex.build --unpack`
inspection + `mix hex.publish --dry-run` and never writes to Hex — exactly the "prove the publish path is
green without a Hex write" evidence D-06.1 wants.

**Proof target (verified):** current shipped version is `1.3.0` (`.release-please-manifest.json` → `".": "1.3.0"`;
`mix.exs @version "1.3.0"`); tag **`v1.3.0` exists** locally and on origin (`8a600ba0…`). [VERIFIED]

Operator command (the runbook should document this verbatim):
```bash
gh workflow run "Hex publish (manual recovery)" \
  -f tag=v1.3.0 -f release_version=1.3.0 -f dry_run=true
```
**This is an operator-run dispatch** (requires `gh` auth + `workflow_dispatch`), not an automatic CI
checkpoint. It is fully re-runnable at any time (idempotency-safe), so "one-shot operator step" and
"re-runnable checkpoint" are the same artifact here — recommend running it once as readiness evidence and
documenting it in the runbook as the repeatable proof (Claude's Discretion, D-06.1).

### Finding 4 — D-06.2: wiring trace CONFIRMED (no discrepancy)

The `release_created → gate-ci-green → publish-hex` needs-chain matches CONTEXT exactly: [VERIFIED]
- `release-please` job outputs `release_created`, `tag_name`, `version`, `sha` (:33-37).
- `gate-ci-green`: `needs: release-please`, `if: release_created == 'true'` (:99-100); polls `ci.yml` for
  a `ci-gate == success` job on the release SHA; `max_attempts=60 × wait_seconds=30 = 1800s` → **30-min
  timeout** then `exit 1` (:119, :124-169). CONTEXT's ":119-169 ~30-min timeout" is accurate.
- `publish-hex`: `needs: [release-please, gate-ci-green]`, `if: release_created == 'true'` (:171-174);
  idempotency "Skip if version already on Hex" (:279-285) → dry-run publish (:287-291) → real publish
  (:293-297). CONTEXT's ":279-285 idempotency" and ":287 dry-run" are accurate.

**Silent-stall confirmed real:** `gh run list --workflow release-please.yml` shows run `29095622962`
(Merge PR #74) with conclusion **`failure`** on 2026-07-10 — the `gate-ci-green` timeout against the then-red
gate, with no issue/notification. Post-221 Release Please runs are now `success` but that only means the
`release-please` job ran without creating a release (`release_created=false` → `gate-ci-green`+`publish-hex`
skipped); **auto-publish is still unproven end-to-end**, matching D-05. [VERIFIED]

### Finding 5 — D-08: runbook insertion point CONFIRMED

MAINTAINING.md structure (verified):
- `## Release automation (default)` at **:266**; enumerated steps :270-275; the `**Recovery / one-off
  publish:**` line at **:276** ("Actions → Hex publish (manual recovery) — supply the tag or SHA…").
- Canonical release runbook pointer `docs/release-runbook-v1-0.md` at **:262** (with ":264 keep this file
  as the maintainer entry-point index and do not duplicate"). [VERIFIED]
- Precedent shape to copy: `#### Forced-failure probe runbook (D-14)` at **:178-198** — copy-paste
  `gh workflow run "CI" -f force_fail_probe=true` commands + a plain-English "what this proves". [VERIFIED]
- Enforced-required-checks list at :106-110; `ci-gate` NOT enforced at :112. [VERIFIED]

**Recommended insertion:** add a new `###`/`####` subsection immediately after the "Recovery / one-off
publish:" line (:276), titled e.g. `### Release-lane rot signals & recovery (HARD-01/HARD-02)`. It should
document, in the D-14 copy-paste style:
1. `hex-publish.yml` manual dispatch (`tag` + `release_version` + `dry_run`) — the exact `gh workflow run`
   command from Finding 3, and when to use it vs release-please auto-publish.
2. How to read a `gate-ci-green` timeout (the 30-min stall) and where the new tracking Issue appears.
3. How to red-probe the new loud signal (mirror the D-14 probe pattern).
4. A cross-reference to `docs/release-runbook-v1-0.md` (:262) — **do not duplicate** the release matrix.
Do **not** create a new top-level doc (D-08 + the file's anti-duplication guidance).

## Line-Number Drift Audit (CONTEXT.md refs vs current files)

All CONTEXT.md file:line anchors were checked this session. Result: **no material drift** — every anchor
still points where claimed. Minor exact-line notes for the planner:

| CONTEXT ref | Actual | Status |
|-------------|--------|--------|
| ci.yml:636 `upgrade_smoke` PR-invisible `if:` | 636 (`if: github.event_name != 'pull_request'`) | ✅ exact |
| ci.yml:643 stopgap pin | 643 (`SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"`) | ✅ exact |
| ci.yml:1465 ci-gate needs upgrade_smoke | 1465 | ✅ exact |
| ci.yml:1498 skipped-as-pass | 1498 | ✅ exact |
| ci.yml:1238 `::error::` annotation | 1238 | ✅ exact |
| ci.yml:2181 `nightly_probe` | 2181 | ✅ exact |
| ci.yml:400-406 matrix/required-context hazard | 400-406 (library_tests aggregator comment) | ✅ exact |
| upgrade-smoke.sh:45 `sed` marker-strip | 45 | ✅ exact |
| upgrade-smoke.sh:52 `sort -V \| tail -1` | 52 | ✅ exact |
| upgrade-smoke.sh:56-77 override block | 56-77 | ✅ exact |
| release-please.yml:22 `issues: write` | 22 | ✅ exact |
| release-please.yml:96-174 gate chain | gate-ci-green 96-169, publish-hex 171-174 | ✅ (chain spans as claimed) |
| release-please.yml:119-169 ~30-min timeout | 119 (`max_attempts=60`), loop 124-166, exit 168-169 | ✅ exact |
| release-please.yml:279-285 idempotency | 279-285 | ✅ exact |
| release-please.yml:287 dry-run | 287-291 | ✅ exact |
| hex-publish.yml:20-24 inputs | dry_run 20-24; full inputs block 11-24 (tag :12, release_version :16) | ✅ (dry_run exact; `tag`/`release_version` slightly above :20) |
| MAINTAINING.md:146 D-07 residual | 146 | ✅ exact |
| MAINTAINING.md:178-198 forced-failure probe runbook | 178-198 | ✅ exact |
| MAINTAINING.md:262 canonical runbook pointer | 262 | ✅ exact |
| MAINTAINING.md:266-276 recovery area | 266 (section), 276 (Recovery line) | ✅ exact |
| MAINTAINING.md:106-110 / :112 enforced checks / ci-gate not enforced | 106-110 / 112 | ✅ exact |
| MAINTAINING.md:31,:33 "anti-duplication" | 31/33 are the v1.12-trust-bundle "do not fork tables" guidance | ⚠ general principle, not release-runbook-specific (minor mis-citation; principle still applies) |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Open/update a tracking issue | A custom REST client / curl-to-issues-API | `gh issue list/create/comment` | Preinstalled, auth via `GH_TOKEN`, handles pagination/JSON. |
| Idempotent "one issue, many occurrences" | Deleting/recreating issues, per-run new issues | find-open-by-label → comment-or-create | No spam; one durable, discoverable surface. |
| Dropping the stray version | A version *ceiling* / floor pin (rots every release) | exact fixed-string exclusion (`grep -vxF`) | The stray is a fixed immutable Hex fact; a floor/ceiling is itself a rot vector (D-03). |
| Proving the publish path | A throwaway version bump / live release | `hex-publish.yml dry_run=true` | Idempotency-guarded, no Hex write, re-runnable (D-06). |

**Key insight:** every "durable" mechanism here must be self-maintaining. A pinned floor (the D-13 stopgap)
and a per-release-updated ceiling both rot; only an exact known-stray exclusion and a structured
find-or-create issue are truly maintenance-free.

## Common Pitfalls

### Pitfall 1: Implementing D-03 literally as a `(retired)` filter
**What goes wrong:** the resolver still selects `1.20.0`; the gate stays broken but now with no pin either.
**Why:** the stray is not retired and `mix hex.info` shows no retired marker (Finding 1).
**How to avoid:** use the tested stray-exclusion. Add a resolver test asserting selection of `1.3.0`
(not `1.20.0`) from a fixture.
**Warning signs:** upgrade-smoke logs "resolved latest published 1.x series as 1.20.0".

### Pitfall 2: Making the loud signal a new required/push-only aggregate
**What goes wrong:** a push-only required context can leave PR merges stuck pending (the matrix-orphans-a-
required-context class already bit this repo; ci.yml:400-406, MAINTAINING.md ruleset note).
**How to avoid:** the notify job must NOT be in `ci-gate.needs` and NOT a required check; issue-open is the
signal (D-02). Gate it `github.event_name != 'pull_request'`.

### Pitfall 3: Forgetting the `issues: write` permission in ci.yml
**What goes wrong:** `gh issue create` fails with 403 in `ci.yml` (workflow default is `contents: read`).
**How to avoid:** add job-level `permissions: issues: write` on the ci.yml notify job. `release-please.yml`
already has it at the workflow level (:22).

### Pitfall 4: Breaking the phase_147 structural test
**What goes wrong:** removing `SIGRA_UPGRADE_SMOKE_START_VERSION` or renaming `resolve_latest_sigra_source`
fails `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs:30-31`.
**How to avoid:** keep the override env (as escape hatch, D-03) and the function name; only remove the
**ci.yml:643 pin** and add the exclusion inside the function.

## Runtime State Inventory

This is a CI-config/shell/docs phase, not a rename/refactor/migration. Two "state outside the repo" items
are worth an explicit note (both are read-only for planning, no migration task):

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Live service config | Hex registry: `1.20.0` is a live, non-retired, immutable published release (cannot be unpublished/retired here — PUB-04 deferred). The resolver must route around it in code. | Code (stray-exclusion), not data migration. |
| Live service config | GitHub ruleset 14941512: 5 enforced required checks (MAINTAINING.md:106-110); `ci-gate` and the new notify job must NOT be added to it. | None — just do not touch the ruleset. |
| OS-registered state | None (no OS-level registrations). | None. |
| Secrets/env vars | `HEX_API_KEY` (Actions secret) used by publish/dry-run; `GITHUB_TOKEN` for the notify job. Names unchanged. | None — reuse existing secrets. |
| Build artifacts | None. | None. |

## Validation Architecture

> nyquist_validation is enabled (`.planning/config.json` → `workflow.nyquist_validation: true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (structural workflow-assertion tests) + shell (shellcheck available, not a CI gate) |
| Config file | `test/test_helper.exs`; existing precedent `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` |
| Quick run command | `mix test test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` |
| Full suite command | `mix test` (requires Postgres — see CLAUDE.md local dev prereqs) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| HARD-01 | resolver excludes stray `1.20.0`, selects latest real GA | unit (pure filter over fixture text) | `mix test test/.../upgrade_smoke_resolver_test.exs` (new) | ❌ Wave 0 — extract/parametrize the parse so it runs offline against a fixture |
| HARD-01 | ci.yml pin removed; upgrade-smoke.sh contains exclusion; override env retained | structural | extend `phase_147_upgrade_migration_lanes_test.exs` (assert `ci.yml` no longer contains `SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"`; script contains the exclusion) | ⚠ extend existing |
| HARD-01 | notify job is push/schedule-gated, has `issues: write`, not in `ci-gate.needs`, not required | structural | new/extended workflow-assertion test on `ci.yml` | ❌ Wave 0 |
| HARD-02 | `notify-release-failure` fires on `gate-ci-green`/`publish-hex` failure; workflow keeps `issues: write` | structural | workflow-assertion test on `release-please.yml` | ❌ Wave 0 |
| HARD-02 | shared `notify-failure-issue.sh` is idempotent (find-open→comment else create) | shell unit (stub `gh`, dry-run mode prints intended calls) | `bash`-based test with a `gh` stub on `PATH` | ❌ Wave 0 |
| HARD-02 | `dry_run=true` never reaches real publish | structural | assert the `if:` guards on hex-publish.yml publish steps | ⚠ optional (guards verified this session) |
| HARD-02 | runbook subsection exists + cross-references canonical runbook, no duplication | structural | assert `MAINTAINING.md` contains the new heading + `docs/release-runbook-v1-0.md` reference | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** the targeted structural test(s) for the file touched (`mix test test/sigra/planning/...`).
- **Per wave merge:** `mix test` (full suite, Postgres-backed).
- **Phase gate:** full suite green + the operator `dry_run=true` proof run recorded as HARD-02 evidence.

### Wave 0 Gaps
- [ ] `test/.../upgrade_smoke_resolver_test.exs` (or a shell test) — HARD-01 resolver picks real GA over stray.
      Requires extracting the parse pipeline into a fixture-testable form (no live network).
- [ ] Workflow-assertion coverage for the two new notify jobs (permissions, `if:` gating, not-in-ci-gate).
- [ ] Shell test for `scripts/ci/notify-failure-issue.sh` idempotency using a `gh` stub / dry-run mode.
- [ ] Extend `phase_147_upgrade_migration_lanes_test.exs` to assert the ci.yml:643 pin is gone.
- Framework install: none — ExUnit + shell already present.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | notify job, dry-run dispatch | ✓ (ubuntu runners + local, authed) | current | — |
| `mix hex.info` (Hex network) | resolver | ✓ | live | — |
| Hex `v1.3.0` tag + release | dry-run proof target | ✓ | v1.3.0 (`8a600ba0`) | — |
| Postgres (test service) | `mix test` in publish/hex-publish jobs | ✓ (service container / local) | 15 | — |
| `HEX_API_KEY` Actions secret | dry-run + publish | ✓ (assumed configured; used by shipped v1.2/v1.3) | — | operator-run |

**Missing dependencies with no fallback:** none.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-maintained `SIGRA_UPGRADE_SMOKE_START_VERSION` floor pin | Durable exact stray-exclusion in the resolver | This phase (HARD-01) | Removes the per-release rot vector. |
| Silent 30-min `gate-ci-green` timeout with no alert | Shared notify-on-failure tracking Issue | This phase (HARD-01/02) | Release-lane failures become loud + discoverable. |
| Retire-then-filter (`(retired)` rows) — **assumed** in CONTEXT | Not viable (stray not retired; no marker in `mix hex.info`) | Verified this session | Planner must use stray-exclusion, not retired-filter. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `HEX_API_KEY` Actions secret is currently configured (inferred from the successful v1.2.0/v1.3.0 manual publishes 2026-07-10). Not directly inspected this session. | Env Availability | dry-run proof would 401; low risk (three publishes succeeded hours ago). |
| A2 | No new stray beyond `1.20.0` will appear before this phase ships; the exclusion default `1.20.0` covers the known case. | Finding 1 | Low — env-driven list makes adding another trivial. |
| A3 | shellcheck is available locally but NOT enforced as a CI gate (only inline `# shellcheck disable` directives found, no lint job). Shell-script validation should therefore ride an ExUnit structural/shell test, not a shellcheck CI lane. | Validation Arch | Low — affects only where the shell test lives. |

## Open Questions (RESOLVED)

> Both items are Claude's-Discretion calls with accepted recommendations; Plan 02 implements both. No blocking unknowns remain.

1. **RESOLVED — Auto-close of the tracking Issue on a subsequent green run?**
   - Known: idempotent open/comment is straightforward.
   - Unclear: whether the notify job should auto-close when the lane goes green, or leave closure manual.
   - Recommendation: leave manual for v1 (simpler, avoids flapping); note as a future enhancement. (Claude's Discretion.)

2. **RESOLVED — Shared label vs distinct labels for HARD-01 vs HARD-02 surfaces?**
   - Recommendation: one label family (e.g. `release-lane-rot`) with a surface tag in the title, so both
     consumers share the script but a maintainer can tell which surface failed. (Claude's Discretion, D-02.)

## Sources

### Primary (HIGH confidence — verified this session)
- Live `mix hex.info sigra` + `curl https://hex.pm/api/packages/sigra` — retirement state of `1.20.0` (None), no retired marker in Recent releases; cross-checked distillery/poison/httpoison.
- Executed resolver pipeline (sed→grep→sort) proving stray-selection bug and `grep -vxF` fix.
- `.github/workflows/ci.yml`, `.github/workflows/release-please.yml`, `.github/workflows/hex-publish.yml` — read in full for the relevant jobs; all CONTEXT line anchors re-verified.
- `scripts/ci/upgrade-smoke.sh` — resolver + override block read in full.
- `MAINTAINING.md` — runbook precedent, insertion point, enforced-checks list.
- `.release-please-manifest.json`, `mix.exs @version`, `git tag`/`git ls-remote` — v1.3.0 proof target.
- `gh run list --workflow release-please.yml` — silent-stall (run #74 = failure) + post-221 success = no-release.
- `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` — structural assertions on the resolver script.

### Secondary
- CONTEXT.md (221-CONTEXT D-13/D-16 referenced), REQUIREMENTS.md HARD-01/HARD-02.

## Metadata

**Confidence breakdown:**
- Stray-exclusion resolver fix: HIGH — reproduced the bug and the fix against live Hex.
- Notify mechanism shape: HIGH — permissions/precedents verified in-repo; exact impl is discretionary.
- Wiring trace + dry-run guards: HIGH — read the actual `if:` conditions.
- Runbook insertion point: HIGH — line anchors confirmed.

**Research date:** 2026-07-10
**Valid until:** ~7 days for the live-Hex facts (a new publish or a retire of 1.20.0 would change them); ~30 days for the workflow/file structure.
