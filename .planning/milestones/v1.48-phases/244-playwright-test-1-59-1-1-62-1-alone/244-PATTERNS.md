# Phase 244: Playwright 1.59.1 → 1.62.1 Alone - Pattern Map

**Mapped:** 2026-09-25  
**Files analyzed:** 9 expected (4 modified, 5 new/inferred)  
**Analogs found:** 9 / 9

File names for the new measurement/receipt tools below are suggested from RESEARCH.md's
responsibility map; planning may choose final names. No application runtime files are implied.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/example/priv/playwright/package.json` | config (npm manifest) | transform / dependency resolution | same package manifest | exact |
| `test/example/priv/playwright/package-lock.json` | config (lockfile) | transform / dependency resolution | same lockfile | exact |
| `.github/workflows/ci.yml` | config (GitHub Actions) | event-driven / batch | existing Playwright shard and smoke jobs in this file | exact |
| `scripts/ci/playwright-cache-key-guard.sh` | utility (shell guard) | transform / validation | itself, lines 31-84 | exact |
| `scripts/ci/playwright-cache-key-guard.test.sh` | test (hermetic shell contract) | transform / validation | itself, lines 21-115 | exact |
| `scripts/ci/measure-playwright-drift.mjs` (suggested) | service / utility (measurement harness) | batch → transform → file-I/O | `scripts/ci/snapshot-canary-guard.sh` (snapshot inventory) plus existing Playwright runner/config | role-match |
| `scripts/ci/measure-playwright-drift.test.mjs` (suggested) | test (hermetic contract) | transform | `scripts/ci/award-guard.test.mjs` or shell guard self-test above | role-match |
| `scripts/ci/capture-phase-244-playwright-evidence.sh` (suggested) | service (GitHub API collector) | request-response → transform → file-I/O | `scripts/ci/capture-phase-241-final-head.sh` | exact |
| `.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json` (suggested) | config/data (durable evidence receipt) | transform → file-I/O | `.planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json` | exact |

The existing `.github/actions/example-playwright-boot/action.yml` is a required integration
boundary to preserve; RESEARCH.md does not call for changing its cache behavior. If the plan
does change it, copy the `npm ci` and browser cache/install seam from lines 103-140.

## Pattern Assignments

### `test/example/priv/playwright/package.json` and `package-lock.json` (npm config, dependency resolution)

**Analog:** These files themselves. Keep the package manifest and lockfile as a pair: the
lockfile currently resolves `@playwright/test`, `playwright`, and `playwright-core` together.
The workflow cache guard reads the resolved package version from
`package-lock.json`; update the lockfile through npm so integrity/resolved entries remain
consistent instead of hand-editing JSON. Playwright CLI use is already `npm ci` followed by
`npx playwright install` in `.github/actions/example-playwright-boot/action.yml:103-140`.

### `.github/workflows/ci.yml` (CI config, event-driven/batch)

**Analog:** Existing job bodies in `.github/workflows/ci.yml`.

The shard matrix already couples database, port, browser set, and versioned cache key per
seam (`:1190-1235`):

```yaml
example_playwright_shard:
  name: Example Playwright shard (${{ matrix.seam }})
  runs-on: ubuntu-latest
  strategy:
    fail-fast: false
    matrix:
      include:
        - seam: admin_behavior
          database: sigra_admin_behavior
          port: "4001"
          browsers: chromium
          browser_cache_key: playwright-chromium-1.59.1-v3
        - seam: admin_checkpoints
          database: sigra_admin_checkpoints
          port: "4002"
          browsers: chromium webkit
          browser_cache_key: playwright-chromium-webkit-1.59.1-v3
```

Update every versioned key variant and preserve each browser set and seam isolation. The
aggregate job at `:1389-1415` explicitly rejects failed shard results, while `ci-gate`
lists both Playwright smoke jobs as separate dependencies (`:1550-1574`). For the new
measurement job, follow the existing Ubuntu runner and artifact upload conventions around
`:1370-1387`; preserve complete PNG inventory and render/diff files as artifacts, while the
committed receipt remains durable evidence.

### `scripts/ci/playwright-cache-key-guard.sh` (utility, config validation)

**Analog:** Itself (`:31-84`), with changes likely needed because it currently extracts only
the first `chromium-webkit` key (`:58-61`) and does not check the separate `chromium` form.

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="${ROOT}/.github/workflows/ci.yml"
LOCKFILE="${ROOT}/test/example/priv/playwright/package-lock.json"

fail() {
  echo "playwright-cache-key-guard: FAIL: $*" >&2
  exit 1
}

key_version="$(grep -oE 'playwright-chromium-webkit-[0-9]+\.[0-9]+\.[0-9]+-v[0-9]+' "$WORKFLOW" \
  | head -1 \
  | sed -E 's/^playwright-chromium-webkit-([0-9]+\.[0-9]+\.[0-9]+)-v[0-9]+$/\1/')" || true
[[ -n "$key_version" ]] || fail "no Playwright browser cache key found in ${WORKFLOW}"
```

Retain fail-closed missing/mismatch behavior and actionable errors. Extend extraction/validation
to assert every distinct cache-key browser-set variant matches the lockfile version, including
both `playwright-chromium-...` and `playwright-chromium-webkit-...`; do not change cache design.

### `scripts/ci/playwright-cache-key-guard.test.sh` (test, hermetic transform validation)

**Analog:** Itself (`:21-115`). This test creates small temporary workflow and lockfile
fixtures, passes them through the guard's CLI flags, captures exit codes, and checks the
diagnostic. Extend that fixture style for two cache variants: both matching passes, and either
missing or stale variant fails. Keep the tests offline and independent of GitHub credentials.

```bash
TMPDIR_ROOT="$(mktemp -d)"
trap cleanup EXIT

write_workflow() {
  local path="$1" version="$2"
  cat > "$path" <<EOF
      - name: Cache Playwright browsers
        with:
          key: \${{ runner.os }}-playwright-chromium-webkit-${version}-v2
EOF
}

set +e
OUT="$(bash "$SCRIPT" --workflow "$WF" --lockfile "$LF" 2>&1)"
EXIT_CODE=$?
set -e
```

The existing guard self-test is invoked by `fast_checks` in `.github/workflows/ci.yml`; wire
new harness contract tests into that same lightweight check path rather than a browser job.

### `scripts/ci/measure-playwright-drift.mjs` and its contract test (suggested; batch comparator)

**No single exact analog exists.** Combine the tracked snapshot inventory approach in
`scripts/ci/snapshot-canary-guard.sh` with the established isolated Playwright suite configured
by `test/example/priv/playwright/playwright.config.ts`. This is a CI-only harness, not an app
service. Derive expected PNG paths from tracked files at the measured SHA, render old/candidate
versions in separate install/browser roots on the same Ubuntu runner, then require exact path
set equality, equal dimensions, and zero decoded changed pixels. Emit a per-image JSON result;
missing/extra images or comparator failure must fail closed. Preserve renderer outputs/diffs as
workflow artifacts and do not update committed baselines.

The existing config uses a shared `test-results` output directory, serial workers, and zero
retries (`playwright.config.ts:54-60`), with named projects splitting checkpoint, design,
demo, and behavior specs (`:91-180`). Do not mistake a single shard/behavior project for the
whole screenshot corpus. Keep app readiness, browser dependencies, and test-data isolation on
the established CI boot seams. The phase does not currently have a decoded pixel comparator;
no concrete comparator excerpt exists to copy.

For its hermetic test, use the temp-fixture/expected-failure pattern in
`scripts/ci/playwright-cache-key-guard.test.sh`: test zero drift, one changed pixel, dimension
mismatch, missing image, extra image, and malformed/unavailable comparator output without
launching browsers.

### `scripts/ci/capture-phase-244-playwright-evidence.sh` (suggested; GitHub API collector)

**Primary analog:** `scripts/ci/capture-phase-241-final-head.sh` (`:1-50`, `:86-146`, and
receipt serialization/self-validation at `:160-200`). Its pattern is fixed selectors,
validated caller-supplied run/SHA, one rate-limit preflight, structured `gh api` reads,
complete jobs pagination, exact-SHA checks, and atomic output only after full validation.

```bash
REPO="szTheory/sigra"
WORKFLOW="ci.yml"
fail() { echo "capture-phase-241-final-head: FAIL: $*" >&2; exit 1; }

[[ "$RUN_ID" =~ ^[0-9]+$ ]] || fail "run_id_malformed"
[[ "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]] || fail "head_sha_malformed"
[[ "$(git rev-parse HEAD 2>/dev/null || true)" == "$HEAD_SHA" ]] || fail "local_head_sha_mismatch"
git diff --cached --quiet || fail "staged_changes_present"
```

Adapt selectors to require `ci-gate`, the five matrix shard jobs (including each `seam`),
`example_playwright_smoke`, and `generated_admin_playwright_smoke`, each completed with
`success` at the same resulting `main` SHA. Keep aggregate gate and individual jobs distinct;
do not let `skipped` or a green aggregate satisfy a missing consumer. Treat API JSON as
untrusted structured input and never interpolate API fields into shell. Reuse the collector's
atomic temp-file-then-rename output discipline.

### `.planning/phases/244-.../244-PLAYWRIGHT-EVIDENCE.json` (suggested; receipt data)

**Analog:** Tracked `.planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json`.
It uses machine-readable top-level SHA/repository fields and records individual job identities,
run IDs, and conclusions instead of only a prose statement. The phase 241 collector's
canonical JSON emission is the closest generator for the file.

The receipt should bind the measurement source SHA/run ID, package versions, manifest URLs and
browser revisions, runner/comparator versions, inventory digest/count, per-image dimensions and
pixel counts, drift verdict, PR decision state, and resulting-main SHA/run ID. Store `ci-gate`
separately from each consumer and include each matrix seam identity. This receipt is committed;
short-lived artifacts carry the full rendered images and diffs.

## Shared Patterns

### CI evidence and fail-closed validation

**Sources:** `scripts/ci/capture-phase-241-final-head.sh:18-50,86-146`; `scripts/ci/playwright-cache-key-guard.sh:43-84`. Validate SHA, run ID, required fields, exact job names, and conclusions before writing output. Fail closed on missing, duplicate, stale, skipped, malformed, or inconclusive evidence. Capture/serialize to a temporary file and rename only after validation.

### Playwright boot and cache seam

**Source:** `.github/actions/example-playwright-boot/action.yml:103-140`. `npm ci` runs from the Playwright package directory; browser install uses the selected browser list and skips download only on an exact cache hit. Retain this boot behavior and keep package-versioned cache keys aligned across all browser variants.

### Exact rendered image inventory

**Sources:** `scripts/ci/snapshot-canary-guard.sh` and
`test/example/priv/playwright/playwright.config.ts:54-76,91-180`. Snapshot baselines are
committed under `*-snapshots/`, while the existing assertion config defines stable path
templates and separately scoped projects. The measurement's output inventory must be matched
to the complete tracked path set before pixel comparison; existing screenshot assertion
tolerance is not the exact-drift authority.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| Proposed measurement harness | utility / batch comparator | batch → transform → file-I/O | No current utility compares two complete Playwright output inventories with decoded zero-tolerance pixel counts. Compose existing snapshot inventory and CI test-run patterns. |

## Metadata

**Analog search scope:** `.github/workflows/`, `.github/actions/`, `scripts/ci/`, `test/example/priv/playwright/`, and tracked phase 240/241 evidence artifacts.  
**Files scanned:** focused matches only; stopped after the strong CI guard, capture, Playwright config, and evidence precedents.  
**Tracked-source gate:** named code analogs were verified with `git ls-files`; no ignored runtime/install mirrors are referenced.  
**Pattern extraction date:** 2026-09-25
