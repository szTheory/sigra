# Phase 232: Playwright Economics — Authenticate Once, Then Shard - Pattern Map

**Mapped:** 2026-07-30
**Files analyzed:** 14 new/modified
**Analogs found:** 13 / 14

> **Path correction (binding).** CONTEXT.md's `<canonical_refs>` writes
> `test/example/priv/playwright/specs/…`. **That directory does not exist.**
> `ls test/example/priv/playwright/` → `fixtures helpers lib node_modules … tests`.
> `playwright.config.ts:52` is `testDir: './tests'`. Every `specs/…` path in CONTEXT.md
> must be read as `tests/…`. RESEARCH § Corrections C-1 already records this.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/priv/playwright/tests/auth.setup.ts` | test-fixture (setup project) | request-response (login → serialize state) | `helpers/adminFlows.ts:65-89` (`loginDemoUser`/`loginDemoAdmin`) | role-match (no storageState exists anywhere) |
| `test/example/priv/playwright/playwright.config.ts` (MOD) | config | — | its own `admin-design-chromium` project block `:176-183` | exact (self) |
| `scripts/ci/ci-step-metrics.sh` (NEW; name at planner's discretion) | utility / instrument | batch (API read → table) | `scripts/ci/ci-run-metrics.sh:1-125` (CLI+shape) + `ci-demotion-observer.sh:151-153` (step jq) | exact (split across two) |
| `scripts/ci/ci-step-metrics.test.sh` (NEW) | test (hermetic) | file-I/O + PATH stub | `scripts/ci/ci-run-metrics.test.sh:1-90` | exact |
| `.github/actions/boot-example-app/action.yml` (NEW) | config (composite action) | batch | `ci.yml:1270-1408` (`example_playwright_smoke` prelude — fullest call site) | role-match (first composite in repo) |
| `.github/workflows/ci.yml` — 7 prelude call sites (MOD) | config | — | `ci.yml:1270-1408` | exact (self) |
| `.github/workflows/ci.yml` — `example_playwright_shard` (NEW job) | config | — | `ci.yml:497-602` `library_tests_shard` | exact |
| `.github/workflows/ci.yml` — `example_playwright_smoke` thin aggregator (MOD) | config | — | `ci.yml:604-622` `library_tests` | exact |
| `scripts/ci/prohibitions/p17…p2N-*.test.mjs` (NEW, 232-pinned) | test (guard) | file-I/O | `p12-run-id-provenance.test.mjs` (whole file) + `_lib.mjs` | exact |
| `scripts/ci/prohibitions/p15-*.test.mjs` (MOD — rewrite for `uses:` indirection) | test (guard) | file-I/O | itself, `p15:38-56` `stepList()` | exact (self) |
| `test/sigra/planning/phase_232_*_test.exs` (NEW ×3: setup-wiring, aggregator-seam-ids, SC-4 single-definition) | test (contract) | file-I/O | `test/sigra/planning/phase_230_design_gallery_split_test.exs:1-80` | exact |
| `.planning/…/232-EVIDENCE.md` (NEW) | doc (ledger) | — | `230-EVIDENCE.md:1-40, 660-675` | exact |
| Shard-emptiness assertion (script or inline step) | utility | file-I/O (json reporter `stats.expected`) | — | **no analog** |
| `playwright.config.ts` reporter array (MOD, add `json`) | config | — | `playwright.config.ts:56` | exact (self) |

---

## Pattern Assignments

### `test/example/priv/playwright/tests/auth.setup.ts` (setup project, request-response)

**Analog:** `test/example/priv/playwright/helpers/adminFlows.ts:54-89`

**Login pattern — reuse, do not re-implement** (`adminFlows.ts:54-89`, verbatim):

```typescript
/**
 * Logs in as any pre-seeded demo persona using the password login form.
 *
 * The login page `/users/log_in` is a plain controller page (not a LiveView)
 * so waitForLiveViewReady is NOT called here. The form is submitted directly.
 *
 * No MFA challenge fires: the example app has no `mfa.check_fn` configured,
 * so Sigra creates a `:standard` session for all personas, including those
 * with TOTP enrolled (e.g. admin@demo.tasklane.test). This is safe to rely on
 * in all nine demo personas.
 */
export async function loginDemoUser(
  page: Page,
  email: string,
  password: string,
): Promise<void> {
  // /users/log_in is a plain controller page (not a LiveView) — do NOT call
  // waitForLiveViewReady here. Fill the form directly and submit.
  await page.goto('/users/log_in');
  // The login page has multiple forms (passkey, magic link, password).
  // Scope fills to #login_form to target the password form specifically.
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');
  // No MFA challenge — example app creates a :standard session without check_fn.
  await expect(page).not.toHaveURL(/\/users\/log_in/);
}

export async function loginDemoAdmin(page: Page): Promise<void> {
  await loginDemoUser(page, DEMO_ADMIN_EMAIL, DEMO_ADMIN_PASSWORD);
}
```

**What the new file adds on top** (no analog exists — nothing in the repo writes
`storageState`; this is the shape the config must support):

- `import { test as setup, expect } from '@playwright/test';`
- `setup('authenticate as demo platform admin', async ({ page }) => { … })`
- call `loginDemoAdmin(page)` — do **not** re-implement the form fill (D-02, and the
  `:57-63` MFA comment is the reason the helper is safe)
- **D-05 explicit authenticated assertion before writing state** — e.g. `goto('/admin/users')`
  + `expect(...).toBeVisible()`; `not.toHaveURL(/log_in/)` inside `loginDemoUser` is
  necessary but not sufficient because storageState failure is silent downstream
- `await page.context().storageState({ path: STORAGE_STATE })`
- `STORAGE_STATE = '.playwright/design-admin.json'` (D-03; `.gitignore:4` already covers `.playwright/`)
- Do **not** set a project-level `use.baseURL` — inherit `playwright.config.ts:76`
  (`process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000'`) so D-04's byte-identical
  origin holds automatically.

**Anti-pattern already documented in-repo:** `admin-design.spec.ts:267-272` explains why
a `beforeAll` login does not authenticate test pages (per-test isolated contexts). That
comment must be **rewritten**, not deleted — left as-is it reads as contradicting the new code.

---

### `test/example/priv/playwright/playwright.config.ts` (config)

**Analog:** its own design-project blocks, `:176-203`.

**Project block shape to copy** (`playwright.config.ts:176-183`, verbatim):

```typescript
    {
      name: 'admin-design-chromium',
      testMatch: ADMIN_DESIGN_SPEC,
      use: {
        ...devices['Desktop Chrome'],
        video: checkpointVideo,
      },
    },
```

New setup project follows the same literal-const idiom used at `:24-44`
(`const AUTH_SETUP_FILE = /auth\.setup\.ts/;`), then:

```typescript
    { name: 'design-auth-setup', testMatch: AUTH_SETUP_FILE },
```

and each of the three design projects gains `dependencies: ['design-auth-setup']` plus
`storageState: '.playwright/design-admin.json'` inside its existing `use:` block.

**D-06 hard-fail — the two `testIgnore` arrays that must gain the new const.**
Both are *directory-wide* ignore lists, so a new file in `tests/` is picked up automatically:

```typescript
    {
      name: 'chromium',
      testIgnore: [ADMIN_CHECKPOINTS_SPEC, ADMIN_DESIGN_SPEC, ADMIN_GENERATED_SPEC, DEMO_SHOWCASE_SPEC, ADMIN_EVAL_SPEC],
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'mobile',
      testIgnore: [
        ADMIN_BEHAVIOR_SPECS,
        ADMIN_CHECKPOINTS_SPEC,
        ADMIN_DESIGN_SPEC,
        ADMIN_GENERATED_SPEC,
        WEBAUTHN_CDP_SPECS,
        DEMO_SHOWCASE_SPEC,
        ADMIN_MODAL_SPEC,
        ADMIN_EVAL_SPEC,
      ],
      use: { ...devices['iPhone 13'] },
    },
```

(`chromium` is single-line at `:94`; `mobile` is multi-line at `:103-112`. Note the other
five projects — `admin-checkpoints-*`, `admin-eval*`, `demo-showcase-*`, `admin-generated` —
use `testMatch`, so they are structurally immune and must **not** be touched.)

**Reporter (Wave 0, D-14/D-19)** — current line `:56`:

```typescript
  reporter: [['list'], ['html', { open: 'never' }]],
```

Add a `json` reporter with an outputFile; `stats.expected` from it is the only signal that
survives the E-3 empty-shard silence (there is no `0 passed` line to grep).

---

### `scripts/ci/ci-step-metrics.sh` (utility, batch)

Two analogs, deliberately split (D-11 / RESEARCH C-7).

**(a) CLI + preamble conventions to copy — `scripts/ci/ci-run-metrics.sh:1-90`.**
Header contract comment naming the *one* script that produces a class of claim; the
`set -euo pipefail` + `ROOT=` + `REPO="szTheory/sigra"` defaults; the `while [[ $# -gt 0 ]]`
`case` parser that **exits 2 on unknown args before any `gh` call**; `fail()`; `--format
table|json` validation; and the explicit "gh is invoked bare (resolved via PATH) so the
self-test can shadow it" security note.

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs) RUN_ID="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    *) echo "ci-run-metrics: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() { echo "ci-run-metrics: FAIL: $*" >&2; exit 1; }

if ! command -v gh >/dev/null 2>&1; then fail "gh CLI not found on PATH"; fi
```

**Single round-trip + duration clamp (`ci-run-metrics.sh:94-124`) — the job-level shape
that must be extended to `.steps[]`:**

```bash
  JOBS_JSON="$(gh run view "$RUN_ID" --repo "$REPO" --json jobs --jq '.jobs')" || fail "gh run view failed for run ${RUN_ID}"
  JOB_COUNT="$(echo "$JOBS_JSON" | jq 'length')"
  if [[ -z "$JOB_COUNT" || "$JOB_COUNT" -eq 0 ]]; then fail "run ${RUN_ID} has an empty job list"; fi

  DURATION_JQ='
    .[] as $j
    | (($j.completedAt|fromdate) - ($j.startedAt|fromdate)) as $raw
    | (if $raw < 0 then 0 else $raw end) as $dur
  '
```

Table rendering idiom to reuse verbatim (tab-separated + `column -t -s $'\t'`):

```bash
      {
        printf 'job\tconclusion\tduration_s\tduration\n'
        echo "$JOBS_JSON" | jq -r "
          ${DURATION_JQ}
          | (\$dur / 60 | floor) as \$m
          | (\$dur - (\$m * 60)) as \$s
          | \"\(\$j.name)\t\(\$j.conclusion)\t\(\$dur)s\t\(\$m)m\(\$s)s\"
        "
      } | column -t -s $'\t'
```

**(b) Step-level `gh` resolution to *model on*, not repurpose — `ci-demotion-observer.sh:151-153`:**

```bash
    NODE="$(echo "$RUN_JSON" | jq -c --arg pj "$PARENT_NAME" --arg n "$display_name" \
      '.jobs[] | select(.name == $pj) | .steps[]? | select(.name == $n)' | head -1)"
```

**Step-level duration guards to copy — `ci-demotion-observer.sh:161-165`** (steps carry
zero-dates that jobs do not; the plain `fromdate` clamp above is *insufficient* here):

```bash
    DUR="$(echo "$NODE" | jq -r '
      if (.completedAt // "") == "" or (.startedAt // "") == "" then 0
      elif (.completedAt | startswith("0001-")) then 0
      else (((.completedAt|fromdate) - (.startedAt|fromdate)) as $r | if $r < 0 then 0 else $r end)
      end')"
```

**Fail-closed verdict grammar to copy — `ci-demotion-observer.sh:167-183`** (status must be
`completed`; empty conclusion is never "not skipped"; `DUR <= 0` with a success conclusion is
"green on a no-op"). Note the API returns **job display names, never ids** — the reader's
inputs must be `name:` strings.

---

### `scripts/ci/ci-step-metrics.test.sh` (test, hermetic)

**Analog:** `scripts/ci/ci-run-metrics.test.sh:1-90` — copy structurally, whole file.

**Header case-enumeration idiom** (`:14-35`): every case letter-labelled with the exact
behaviour, incl. `D: unknown flag -> exit 2 … with ZERO recorded gh invocations`,
`E: gh absent from PATH`, `F: gh exits non-zero … no partial table on stdout`,
`G: empty job list`. Reuse letters A..H semantics for the step reader.

**PATH-shadowed `gh` stub scaffolding** (`:41-73`):

```bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/ci-run-metrics.sh"
if [[ ! -f "$SCRIPT" ]]; then echo "FATAL: script not found at ${SCRIPT}" >&2; exit 2; fi

PASS=0; FAIL=0
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
cleanup() { if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then rm -rf "$TMPDIR_ROOT"; fi }
trap cleanup EXIT
TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
: > "$GH_STUB_LOG"
```

**Canned-payload idiom** (`:75-82`) — inline JSON const mirroring a *real observed run*, with
the pathological rows baked in. The step-reader version needs `.steps[]` nested under a
job whose `name` matches, plus one step with a `0001-`-prefixed `completedAt`:

```bash
CANNED_JOBS='[
  {"name":"Admin eval render + probe (evidence only, not a merge gate)","conclusion":"failure","startedAt":"2026-07-28T19:11:21Z","completedAt":"2026-07-28T19:28:54Z"},
  {"name":"Upgrade smoke (published source series -> local candidate)","conclusion":"skipped","startedAt":"2026-07-28T19:11:14Z","completedAt":"2026-07-28T19:11:13Z"}
]'
```

Wire the new self-test into `fast_checks` next to the existing `ci-run-metrics.test.sh`
invocation (`ci.yml` `fast_checks` job at `:160`).

---

### `.github/actions/boot-example-app/action.yml` (config, composite — first in repo)

**Analog:** the duplicated prelude itself. **Fullest call site = `example_playwright_smoke`,
`ci.yml:1270-1408`.** Extract that block as the composite body; every other site is a subset.

Step sequence to lift (names are load-bearing — `p15` and `phase_230_*` match on them):

| # | Step | ci.yml line | Composite disposition |
|---|------|-------------|-----------------------|
| 1 | `uses: actions/checkout@3d3c42e5…  # v7.0.1` | `:1270` | in composite |
| 2 | `uses: erlef/setup-beam@54075bcc…  # v1.24.1` (`id: setup`, `version-file: .tool-versions`, `version-type: strict`) | `:1271-1276` | in composite — **must re-export `otp-version`/`elixir-version` via `outputs.<name>.value`** (D-29: internal step ids are action-scoped) |
| 3 | `uses: actions/setup-node@82076278…  # v7.0.0` (node 20, `cache: 'npm'`, `cache-dependency-path: test/example/priv/playwright/package-lock.json`) | `:1277-1282` | input-gated (`node`) — `example_unit_smoke`/`example_http_smoke` have none |
| 4 | `Cache example deps` (`id: example_deps_cache`) | `:1283-1292` | **may be unconditional** — see C-4 below |
| 5 | `Fetch example deps` / `Compile example --warnings-as-errors` | `:1293-1305` | in composite; `MIX_ENV` is an input (`test` for `example_unit_smoke`) |
| 6 | `Setup example dev DB` (`mix ecto.create && mix ecto.migrate`) | `:1306-1314` | in composite |
| 7 | `Run demo seeds` (`mix run priv/repo/seeds.exs`) | `:1315-1322` | input-gated, **default `false`** (C-5: `example_http_smoke` is the one booting job with no seeds) |
| 8 | `Install Playwright deps` (`npm ci`) | `:1323-1326` | input-gated |
| 9 | `Cache Playwright browsers` (`id: playwright_browsers_cache`, key `…-playwright-chromium-webkit-1.59.1-v2`) | `:1327-1359` | **caller-owned / input-gated — D-27 as corrected by C-4** |
| 10 | `Install Playwright browsers` (cache-hit branch) | `:1361-1375` | input-gated |
| 11 | `Boot example app in background` | `:1376-1388` | in composite |
| 12 | `Wait for app and warm up LiveView routes` | `:1389-1408` | in composite; warm path list is an input |

**Cache-hit comparison idiom to preserve verbatim** (`ci.yml:1361-1375`) — D-29's
`cache-hit == ''` hazard is already handled correctly here:

```yaml
        run: |
          if [ "${{ steps.playwright_browsers_cache.outputs.cache-hit }}" = "true" ]; then
            npx playwright install-deps chromium webkit
          else
            npx playwright install --with-deps chromium webkit
          fi
```

**Boot + warm pattern** (`ci.yml:1376-1408`):

```yaml
      - name: Boot example app in background
        working-directory: test/example
        env:
          MIX_ENV: dev
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
          PHX_SERVER: "true"
        run: mix phx.server > /tmp/example-playwright-server.log 2>&1 &
      - name: Wait for app and warm up LiveView routes
        run: |
          for i in $(seq 1 30); do
            if curl -sf http://localhost:4000/ > /dev/null; then
              echo "App responding after ${i}s"; break
            fi
            sleep 1
          done
          for path in /users/register /users/log_in /users/confirm /dev/mailbox /users/sessions /users/sudo /users/settings/mfa /admin/users; do
            curl -sf -o /dev/null "http://localhost:4000${path}" \
              && echo "warmed ${path}" \
              || echo "warmup miss ${path} (non-fatal)"
          done
```

**Per-site deltas from this source shape** (verified against D-26 + RESEARCH):

| Call site | ci.yml lines | Delta vs. `example_playwright_smoke` |
|---|---|---|
| `example_unit_smoke` | `:742-775` | `MIX_ENV: test`; **no boot**, no node, no browsers, no seeds; cache id `example_unit_deps_cache` |
| `example_http_smoke` | `:1180-1231` | boot **without seeds** (only such job); no node/browsers; cache id `http_smoke_deps_cache` |
| `example_playwright_smoke` | `:1270-1408` | **source shape** (full + browser cache) |
| `admin_design_recapture` | `:2010-2089` | full; plain `install --with-deps` (no cache-hit branch); stale comment at `:2008-2009` ("verbatim clone of ci.yml:886–968") must be fixed |
| `admin_checkpoint_recapture` | `:2329-2379+` | full |
| `admin_eval_render` | `:2570-2644` | **`PORT: "4011"`** (`:2558-2559`); has a deps cache (`admin_eval_render_deps_cache`, `:2582`) but **no browser cache**; warms only `/admin/_design` |
| `playwright-github-pages.yml` | `:54-131` | full; `p15`-guarded step ordering |

**D-27 correction to apply (RESEARCH C-4, VALIDATION § Correction).** `admin_eval_render`
*does* declare an `actions/cache` (`ci.yml:2581-2591`). Its structural guarantee is about the
**Playwright browser** cache (`~/.cache/ms-playwright`) only. **Operative rule: the deps cache
may be unconditional in the composite; only the browser cache must be caller-owned.**

**Anti-pattern (verified against the guard surface):** do not move the
`if: needs.changes.outputs.docs_only != 'true'` conditions inside the composite. Every
prelude step in `:1270-1408` carries one, and `p10`'s `stepIf()` and the tier-C rows of
`.github/ci-skip-manifest.tsv` resolve them by reading `ci.yml`. Inside a composite they
become invisible to every guard.

---

### `ci.yml` — `example_playwright_shard` + thin aggregator (config)

**Analog:** `library_tests_shard` → `library_tests`, `ci.yml:497-622`. Copy verbatim.

**Working job header (`:497-517`) — the four load-bearing properties:**

```yaml
  library_tests_shard:
    name: Library tests shard ${{ matrix.partition }}
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: release_ref_guard
    strategy:
      fail-fast: false            # D-01: one shard failing must NOT cancel the sibling
      matrix:
        partition: [1, 2]         # D-04: N=2
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: sigra_test
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
```

`name:` **interpolates the matrix value** — that is what stops Actions emitting
`Library tests (1)`/`(2)` and orphaning the bare required context.
`timeout-minutes` is present on the runner job (`p09` requires exactly one per `runs-on:`).
The per-shard `services.postgres` block is D-15's isolation mechanism; per-shard
`PGDATABASE` needs no Elixir change (`test/example/config/dev.exs:4-12`).

**Per-shard artifact-path disambiguation idiom** (`:566`, `:582`) — the tee'd log is
partition-suffixed so legs never collide:

```yaml
          mix test --partitions 2 --slowest 10 2>&1 | tee /tmp/library_tests_${{ matrix.partition }}.log
```

**Thin aggregator — copy whole, `ci.yml:593-622`** (D-21/D-22; the comment block is as
load-bearing as the code):

```yaml
  # TEST-01 (D-02/D-03): Thin name-preserving aggregator. Reuses job id `library_tests`
  # and name `Library tests` — byte-identical to ruleset 14941512 required check string
  # (confirmed via gh api repos/szTheory/sigra/rulesets/14941512 at execution time).
  # A bare matrix on a named job emits "Library tests (1)"/"(2)" — never a bare
  # "Library tests" — which would orphan the required check (stuck pending → merge outage).
  library_tests:
    name: Library tests          # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT (D-02)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    needs: [library_tests_shard]
    if: always()                 # must run even if a shard fails (mirrors ci-gate pattern)
    steps:
      - name: Require all library_tests shards to pass
        env:
          # needs.<matrix-job>.result is 'success' only if EVERY leg succeeded.
          # 'failure' if any leg failed — independent of fail-fast: false.
          SHARDS: ${{ needs.library_tests_shard.result }}
        run: |
          set -euo pipefail
          if [[ "$SHARDS" != "success" ]]; then
            echo "library_tests_shard result: $SHARDS"
            exit 1
          fi
          echo "all library_tests shards passed"
```

For 232: job id stays `example_playwright_smoke`, `name:` stays byte-identical
`Example Playwright smoke (full lifecycle)`; the working job becomes
`example_playwright_shard` with `name: Example Playwright smoke shard ${{ matrix.seam }}`.
Keep `!= "success"` — do **not** relax to `!= "failure"` (a wholly-skipped matrix resolves
to `skipped`).

**D-20 — the seam-outcome aggregator that must survive the split** (`ci.yml:1584-1589`, six
hard-coded step ids inside an `if: always()` step at `:1563`):

```bash
          for o in "${{ steps.admin_behavior.outcome }}" \
                   "${{ steps.admin_checkpoints.outcome }}" \
                   "${{ steps.design_gallery.outcome }}" \
                   "${{ steps.design_gallery_snapshots.outcome }}" \
                   "${{ steps.non_admin_smoke.outcome }}" \
                   "${{ steps.demo_showcase.outcome }}"; do
            [ "$o" = "failure" ] && fail=1
            [ "$o" = "skipped" ] || all_skipped=0
          done
```

Note the `all_skipped` half is Phase 231 GATE-03's signal for telling a correctly-gated skip
from a rotted one — carry both halves, not just `fail`.

**Seam step shape to replicate per shard leg** (`ci.yml:1477-1503`):

```yaml
      - name: Run design gallery boards (chromium, mobile, dark)
        id: design_gallery
        if: ${{ !cancelled() && needs.changes.outputs.docs_only != 'true' }}
        working-directory: test/example/priv/playwright
        env:
          CI: "true"
          SIGRA_EXAMPLE_URL: "http://localhost:4000"
        run: |
          npx playwright test \
            tests/admin-design.spec.ts \
            --project=admin-design-chromium \
            --project=admin-design-mobile \
            --project=admin-design-dark \
            --grep-invert '@snapshot'
```

Per D-01 these two invocations (`:1497-1503` and `:1525-1530`) need **no change** for PW-01.
Per D-17, PW-02's SC-2 proof adds `--retries=0` **on the CLI** (`playwright.config.ts:55`
sets `retries: process.env.CI ? 1 : 0`). Never add `--no-deps`.

---

### `scripts/ci/prohibitions/*.test.mjs` — new 232-pinned guards (test, file-I/O)

**Analog:** `p12-run-id-provenance.test.mjs` (whole file) + `_lib.mjs`.

**Header contract idiom (`p12:1-20`)** — every guard opens with: the prohibition sentence in
`MUST NOT` form; `Subject:` line + `(substitutable via GSD_PROHIB_SUBJECT)`; a
"STRUCTURAL AND OFFLINE BY DESIGN" rationale; and a **"What silently breaks if this guard is
deleted"** paragraph. Reproduce all four parts.

**Import + subject indirection (`p12:22-27`):**

```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import { readSubject, parseEvidenceSlots } from './_lib.mjs';

const LEDGER = '.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md';
const slots = parseEvidenceSlots(readSubject(LEDGER));
```

**This constant is exactly why new guards are required (RESEARCH C-3):** `p01`, `p03`, `p08`,
`p11`, `p12`, `p13` are all hard-pinned to the **230** ledger and can never red on a 232
omission. The 232 analogues re-point `LEDGER` at
`.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md`.

**Non-vacuity floor — required first test in every guard (`p12:29-35`):**

```javascript
test('the ledger parse finds a non-trivial set of observation slots', () => {
  assert.ok(
    slots.length >= 4,
    `only ${slots.length} BEFORE-*/AFTER-* slot(s) parsed. An emptied or restructured ledger ` +
      `would make every assertion below vacuously true — the parse broke, this is not a pass.`,
  );
});
```

**Status-grammar assertion (`p12:37-49`)** — the exact regex the 232 ledger must satisfy:

```javascript
    assert.match(
      s.statusRaw,
      /^(captured \((run|runs) [\s\S]+\)|pending \(.+\))$/,
      …
    );
```

**Shared helpers in `_lib.mjs` the new guards call:**

- `subjectPath()` / `readSubject()` / `readRepoFile()` — `_lib.mjs:32-53`; every guard has
  exactly **one** substitutable subject, secondary artifacts read from real paths
- `SLOT_HEADING_RE = /^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$/` + `parseEvidenceSlots()` —
  `_lib.mjs:213-224`; explicitly **generic across phases** ("Phases 231-235 inherit it")
- `REQUIRED_CONTEXTS` — `_lib.mjs:193-200`, one of the two hard-coded five-name lists (D-24):

```javascript
export const REQUIRED_CONTEXTS = Object.freeze([
  'Library tests',
  'Example unit smoke (ExUnit + ConnTest)',
  'Install smoke (fresh phx.new + sigra.install)',
  'Example HTTP smoke (boot + curl critical routes)',
  'Example Playwright smoke (full lifecycle)',
]);
```

- `normalizeExpr()` — `_lib.mjs:157-165`; **required** for any new `if:` assertion, because
  ci.yml uses both bare and `${{ }}`-wrapped forms and the one a naive guard would drop is
  the tier-B step
- `parseSkipManifest()` — `_lib.mjs:168-190`; throws rather than returning `[]`
- `jobBlock()` / `stripYamlComments()` — used by `p15`

**`p15` rewrite analog is `p15` itself** — `stepList()` at `:38-56` matches `^ {6}- name:`
and derives a `uses:`-labelled fallback:

```javascript
      const nameMatch = block.match(/^ {6}- name:\s*(.+)$/m);
      const usesMatch = block.match(/^ {6}- uses:\s*(.+)$/m);
      return {
        name: nameMatch ? nameMatch[1].trim() : (usesMatch ? `uses:${usesMatch[1].trim()}` : '(unnamed)'),
        hasCondition: /^ {8}if:/m.test(block),
        text: block,
      };
```

The `uses:` fallback already exists — the rewrite must make `seedsOrderingIssue()`
(`p15:62-70+`) follow the `uses: ./.github/actions/boot-example-app` indirection into the
composite's own step list rather than returning its `the parse broke, this is not a pass`
sentinel. Preserve the guard's intent (exactly one seeds step, strictly between DB setup
and boot, carrying no `if:`); record the rewrite with evidence.

---

### `test/sigra/planning/phase_232_*_test.exs` (test, file-I/O)

**Analog:** `test/sigra/planning/phase_230_design_gallery_split_test.exs:1-80`.

**Module + path-constant preamble (`:1-26`):**

```elixir
defmodule Sigra.Planning.Phase230DesignGallerySplitTest do
  use ExUnit.Case, async: true

  # ... rationale: "No YAML or TypeScript parser exists in this suite and none is
  # added here -- these are string/regex assertions over the raw file contents,
  # following the phase_153_infra_stability_contract_test.exs idiom."
  @spec_path "test/example/priv/playwright/tests/admin-design.spec.ts"
  @ci_path ".github/workflows/ci.yml"

  @aggregated_seam_ids [
    "admin_behavior",
    "admin_checkpoints",
    "design_gallery",
    "design_gallery_snapshots",
    "non_admin_smoke",
    "demo_showcase"
  ]
```

Note `@spec_path` already uses the correct `tests/` directory — further confirmation of the
path correction.

**`ci.yml` job extraction without a YAML parser (`:31-51`) — copy verbatim** for the SC-4
"exactly one prelude definition" contract and the D-20 seam-id contract:

```elixir
  defp extract_job(content, job_id) do
    job_ids =
      ~r/^  ([a-z_]+):$/m
      |> Regex.scan(content, capture: :all_but_first)
      |> List.flatten()

    idx = Enum.find_index(job_ids, &(&1 == job_id))
    assert idx, "job `#{job_id}:` not found in #{@ci_path}"

    case Enum.at(job_ids, idx + 1) do
      nil ->
        [_, body] = Regex.run(~r/^  #{job_id}:$(.*)\z/ms, content)
        body

      next_id ->
        [_, body] = Regex.run(~r/^  #{job_id}:$(.*?)^  #{next_id}:$/ms, content)
        body
    end
  end
```

**Assertion + failure-message idiom (`:53-80`)** — `File.read!` then `assert spec =~ ~r/…/`
with a multi-sentence message explaining *what silently breaks*:

```elixir
  test "test.describe is not tagged, so tagging cannot sweep all 41 tests per project" do
    spec = File.read!(@spec_path)

    refute spec =~ ~r/test\.describe\('Design gallery board snapshots',\s*\{/,
           "test.describe('Design gallery board snapshots', ...) must not carry a tag " <>
             "details object -- a tag there would sweep all 41 tests per project, ..."

    assert spec =~ "test.describe('Design gallery board snapshots', () => {",
           "test.describe should be declared with the plain title+function form"
  end
```

**D-10 hard-fail:** these four existing assertions in `phase_230_design_gallery_split_test.exs`
pin `admin-design.spec.ts` literal text and must stay green through the PW-01 `beforeEach`
edit. The three job-scoped tests in the same file break *certainly* on PW-02 (RESEARCH C-8) —
re-anchor them in-file with a recorded note, do not delete.

---

### `.planning/…/232-EVIDENCE.md` (doc, ledger)

**Analog:** `230-EVIDENCE.md`.

**Preamble (`:1-11`)** — one-sentence bold thesis, then the
`.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` precedent citation.

**Slot Index table (`:13-26`)** — anchor-linked rows, one per slot:

```markdown
## Slot Index

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-PR](#before-pr) | PR run `30390832059` (2026-07-28, pre-change) | `ci-run-metrics.sh --jobs 30390832059` | captured (run 30390832059) |
```

**Slot body — the exact format `_lib.mjs:213`/`p12` require (`230-EVIDENCE.md:28-40`):**

```markdown
## BEFORE-PR

Status: captured (run 30390832059)

The pre-change PR baseline. …

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs 30390832059
```
```

Format rules the parser enforces, verbatim:
- heading `^##\s+((?:BEFORE|AFTER)-[A-Z0-9-]+)\s*$` — **all-caps, hyphens/digits only**
- `Status: captured (run <id>)` **or** `Status: pending (<…obligation…>)` —
  `p12`'s pending test matches `/pending \(.*obligation.*\)/i`, so the word "obligation"
  must literally appear
- ≥1 fenced block per slot, and for captured slots one fenced block must contain
  `ci-run-metrics.sh` or match `/\bgh (run|pr|api)\b/`
- **pending slots also need ≥1 fenced block** (the future capture command)
- each Status run id must appear **≥2×** inside its own slot body

**Observed-output quotation style (`:186-196`)** — quote the job id, the step name, and
Playwright's own reporter tail verbatim (`Running 39 tests using 1 worker` … `39 passed (3.9m)`).
This is the D-14 executed-test-count requirement in practice.

**SC-restatement section (`230-EVIDENCE.md:660-675`) — the D-08 target.** Heading grammar
`^##\s+Restated Success Criterion\s*\(SC-\d+\)\s*$`, then the unsatisfiability finding, then a
blockquoted **"Operative restatement — verify against this, not the ROADMAP wording:"**:

```markdown
## Restated Success Criterion (SC-2)

RESEARCH finding 2 established that SC-2 as worded in ROADMAP.md is literally unsatisfiable: …

**Operative restatement — verify against this, not the ROADMAP wording:**

> `admin_eval_render` appears in a PR run's job list with `conclusion == "skipped"` and
> `duration < 5s`, and appears on a non-PR run with `conclusion == "success"` and a
> real duration — with its ~17m no longer charged to any PR.
```

Per RESEARCH C-2 the machine-readable restatement lives in the **EVIDENCE ledger**
(mirrored to `230-VALIDATION.md:169`), with a ROADMAP prose pointer as the human half.
A ROADMAP-only restatement satisfies no guard.

---

## Shared Patterns

### Fail-closed, non-vacuous guard authorship
**Source:** `scripts/ci/prohibitions/_lib.mjs:1-25` (header) and `:44-47`
**Apply to:** every new guard, script, and contract test in this phase

```javascript
    throw new Error(
      `subject not found at ${p} — a missing subject is a broken run, never an absent violation`,
    );
```

The repo-wide message convention, borrowed from
`phase_230_ci_timeouts_test.exs`: **"the parse broke, this is not a pass"**. Every extractor
throws rather than returning empty; every guard asserts a floor on what it found.

### Committed-instrument provenance
**Source:** `scripts/ci/ci-run-metrics.sh:1-46` (header contract)
**Apply to:** the new step-level reader, and every number in `232-EVIDENCE.md`

> "this is the ONE script that produces every 'how long did a CI job take' … claim … No
> wall-clock or per-job claim in this milestone is valid unless it was produced by invoking
> this script against a real run and citing the run ID."

Also states the `gh`-invoked-bare / PATH-shadowable contract and the "never filter on
`conclusion` for a duration" rule (a `continue-on-error` failure still burned runner time).

### Rationale-in-place commenting on load-bearing CI constructs
**Source:** `ci.yml:593-603`, `:1327-1359`, `:1563-1580`
**Apply to:** every new job, composite step, and guard

Each records the *failure mode it prevents*, the phase/decision id (`Phase 230 (FAST-06 / D-15…)`),
and, where a prior belief was wrong, the correction (`the original non-blocking premise was that …
— that was factually wrong`). Stale comments are treated as defects: `ci.yml:2008-2009`'s
"verbatim clone of ci.yml:886–968" is already wrong (source is `:1270-1408`) and should be
fixed as part of PW-03.

### `DO NOT EDIT` byte-identical name marking
**Source:** `ci.yml:605`
**Apply to:** the `example_playwright_smoke` aggregator's `name:`

```yaml
    name: Library tests          # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT (D-02)
```

Four consumers key on these strings (D-24): `honest-skip-verdict.sh:101-111` (list) +
`:142-157` (cross-check loop), `ci-demotion-observer.sh:151-153` (resolves by parent job
*display name*), `.github/ci-skip-manifest.tsv` rows 10/15, and the two hard-coded five-name
lists in `docs-only-receipt.sh:41-49` + `_lib.mjs:193-200`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Shard-emptiness assertion (D-19; script or inline step) | utility | file-I/O over the Playwright `json` reporter | Nothing in the repo reads a Playwright JSON report. RESEARCH E-2 gives the mechanizable predicate — `stats.expected > 0` — and E-3 the second trigger (`--shard` + empty `--grep` exits **0 silently**, producing **zero stdout**, so there is no `0 passed` line to parse). Closest structural precedent is `scripts/ci/admin-artifact-bundle-contract.sh` (a `MIN_COUNT` floor over produced artifacts, `ci.yml:1653`) — copy its fail-closed floor idiom, not its content. |

Partial-analog notes:
- `auth.setup.ts`'s **storageState** half has no analog — no `storageState`, `dependencies:`,
  or `globalSetup` exists anywhere in the repo. Use RESEARCH § Pattern 1 for that half; use
  `adminFlows.ts` for the login half.
- `.github/actions/` does not exist; the composite's *YAML mechanics* (D-28/D-29) come from
  RESEARCH, its *content* from `ci.yml:1270-1408`.

---

## Metadata

**Analog search scope:** `.github/workflows/`, `.github/actions/` (absent), `scripts/ci/`,
`scripts/ci/prohibitions/`, `test/sigra/planning/`, `test/example/priv/playwright/`,
`.planning/phases/230-*/`
**Files scanned:** 14 read in full or in targeted ranges; 4 directories enumerated
**Pattern extraction date:** 2026-07-30 (worktree `discuss-231`, HEAD `a1076264`)
