# Phase 216: Harness Foundation + Award Gradient - Pattern Map

**Mapped:** 2026-07-03
**Files analyzed:** 15 new/modified
**Analogs found:** 11 / 15 (4 net-new mechanisms flagged in "No Analog Found")

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/ci/admin-eval-harness.sh` | orchestrator (bash) | batch / file-I/O | `scripts/ci/snapshot-recapture-gate.sh` | exact (role + shape) |
| `scripts/ci/stale-render-guard.sh` + `.test.sh` | guard (bash) | transform / git-plumbing | `scripts/ci/quality-ledger-monotonic.sh` + `.test.sh` | role-match (git-base diff idiom) |
| `scripts/ci/quality-findings-monotonic.sh` + `.test.sh` | guard (bash) | transform / git-plumbing | `scripts/ci/quality-ledger-monotonic.sh` + `.test.sh` | exact (clone + invert comparator) |
| `scripts/ci/settled-findings-lint.sh` + `.test.sh` | lint (bash) | transform / file-I/O | `scripts/ci/quality-ledger-monotonic.sh` (hermetic `.test.sh` scaffold) | role-match |
| `scripts/ci/award-guard.mjs` (or `.sh`+jq) + self-test | guard (node/json) | transform / git-plumbing | `quality-ledger-monotonic.sh` (idiom only); **no node analog** | partial — NET-NEW mechanism |
| `scripts/ci/evidence-anchor-check.mjs` + self-test | integrity check (node/cheerio) | transform / HTML-parse | (none — no `.mjs` in `scripts/ci/`) | **NO ANALOG** |
| `test/example/priv/playwright/tests/admin-eval.spec.ts` | test (Playwright/TS) | request-response / capture | `test/example/priv/playwright/tests/admin-design.spec.ts` | exact (render+probe sibling) |
| `test/example/priv/playwright/lib/eval/canonicalize.ts` | utility (TS/parse5) | transform | (none — parse5 tree-walk is new) | **NO ANALOG** (design in RESEARCH Pattern 1) |
| `test/example/priv/playwright/lib/eval/probes.ts` | utility (TS/getComputedStyle) | transform | `admin-design.spec.ts` (getComputedStyle/evaluate usage) | role-match |
| `test/example/priv/playwright/lib/eval/bundle.ts` | utility (TS/fs) | file-I/O | (harness-local; thin) | partial |
| `test/example/priv/playwright/playwright.config.ts` (modify) | config | — | existing `projects: [...]` blocks (L82-198) | exact |
| `guides/reference/admin-award-ledger.json` | config/data (committed) | — | (none — JSON schema is new) | **NO ANALOG** (schema in RESEARCH) |
| `guides/reference/settled-findings.tsv` | config/data (committed) | — | `guides/reference/admin-quality-ledger.md` (grammar/frozen-column precedent) | role-match (format is new) |
| `guides/reference/admin-render-sha.json` (or `.tsv`) | config/data (committed) | — | `admin-quality-ledger.md` (forward-only committed signal) | role-match |
| `.github/workflows/ci.yml` (modify) | config (CI) | — | existing `fast_checks` lane + `id: base` step (L58-116) | exact |
| `.gitignore` (modify) | config | — | existing `test/example/_build/` block (L37-48) | exact |

## Pattern Assignments

### `scripts/ci/admin-eval-harness.sh` (orchestrator, batch)

**Analog:** `scripts/ci/snapshot-recapture-gate.sh`

**Header + ROOT/PW/URL convention** (lines 14-18) — copy verbatim, rename:
```bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PW="${ROOT}/test/example/priv/playwright"
SIGRA_EXAMPLE_URL="${SIGRA_EXAMPLE_URL:-http://localhost:4011}"
```

**Playwright invocation shape** (lines 64-69) — the `( cd "$PW" && CI=true SIGRA_EXAMPLE_URL=... npx playwright test <spec> --project=<name> )` subshell idiom. For 216, invoke `tests/admin-eval.spec.ts --project=admin-eval` (+ `-mobile`/`-dark` siblings per D-15).

**Downstream guard chaining** (lines 71-98) — after the Playwright run, call `bash "${ROOT}/scripts/ci/<guard>.sh"` in sequence with labeled `echo` phase markers (`(a)`, `(b)`, `(c)`). For 216 the orchestrator runs render→canonicalize→then the derivative guards, but note the RESEARCH decision (Harness Wiring §4): the **guards themselves also attach to `fast_checks` independently** reading the committed ledgers — the orchestrator is the local/full-run driver, not the merge gate.

**Terminal PASS line** (line 107): `echo "admin-eval-harness: PASS ..."`.

---

### `scripts/ci/quality-findings-monotonic.sh` (guard, git-plumbing) — the clone target

**Analog:** `scripts/ci/quality-ledger-monotonic.sh` (structural clone, comparator INVERTED per D-21)

**Arg parse + fail helper** (lines 6-20) — copy verbatim:
```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="guides/reference/<findings-source>"   # render-sha/findings JSON or tsv
BASE="HEAD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    *) echo "quality-findings-monotonic: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done
```

**git-show-BASE associative-array diff** (lines 30-53) — the exact idiom. Load BASE counts via `git -C "$ROOT" show "${BASE}:${LEDGER}"`, load HEAD counts from the working tree, compare per key:
```bash
declare -A BASE_COUNTS=()
while IFS=$'\t' read -r item cnt; do BASE_COUNTS["$item"]="$cnt"; done \
  < <(git -C "$ROOT" show "${BASE}:${LEDGER}" 2>/dev/null | extract_open_counts)
declare -A HEAD_COUNTS=()
while IFS=$'\t' read -r item cnt; do HEAD_COUNTS["$item"]="$cnt"; done \
  < <(extract_open_counts < "${ROOT}/${LEDGER}")
```

**INVERTED comparator** (contrast analog line 49 `-lt`) — per RESEARCH Pattern 7:
```bash
for item in "${!HEAD_COUNTS[@]}"; do
  base="${BASE_COUNTS[$item]:-0}"; head="${HEAD_COUNTS[$item]}"
  if (( head > base )); then    # FAIL on INCREASE (tier guard fails on DECREASE)
    echo "quality-findings-monotonic: FAIL: open findings increased for '${item}': ${base} → ${head}" >&2
    violations=1
  fi
done
```

**CRITICAL skip-on-empty-base divergence (D-08/D-21):** the analog *skips* when `${#BASE_TIERS[@]} -eq 0` (lines 35-38) because a decrease is impossible with no baseline. For the findings guard this is WRONG in general — an increase from 0 IS a regression — so the empty-base skip may ONLY fire when the ledger *file* is absent at base (initial commit), never when the file exists with zero rows. Document the branch taken in `.test.sh`.

---

### `scripts/ci/quality-findings-monotonic.test.sh` (test, hermetic)

**Analog:** `scripts/ci/quality-ledger-monotonic.test.sh` — lift the entire hermetic scaffold.

**mktemp throwaway-repo scaffold** (lines 9-58) — copy verbatim: `TMPDIR_ROOT=$(mktemp -d)` + `trap cleanup EXIT`, `pass()`/`fail()` counters, locate `REAL_GUARD` relative to `${BASH_SOURCE[0]}`, `git init -q` with local `user.email`/`user.name`, `mkdir -p "$REPO/scripts/ci"` + `guides/reference`, `cp "$REAL_GUARD"` into the temp repo, commit a baseline fixture, capture `BASE_COMMIT=$(git rev-parse HEAD)`.

**Per-test run capture** (lines 88-117) — the `set +e; ( cd "$REPO"; bash scripts/ci/<guard>.sh --base "$BASE_COMMIT" 2>"$STDERR" ); EXIT=$?; set -e` + assert-on-exit-and-stderr idiom.

**Required cases for 216 (D-21, RESEARCH Test Map):** 3→4 count = FAIL; no-change = PASS; 4→3 = PASS (down-ratchet allowed); plus the **Test-D decorated-cell-invisible** lesson (lines 173-210) documented for whatever positional parse the findings source uses.

**Summary block** (lines 212-224) — copy verbatim.

---

### `scripts/ci/stale-render-guard.sh` + `.test.sh` (guard, git-plumbing)

**Analog:** `scripts/ci/quality-ledger-monotonic.sh` (idiom) — but the CORE is git plumbing over bundles, NOT a ledger diff.

**Idiom to lift:** the `ROOT`/`fail()`/arg-parse header (lines 6-20) and the `.test.sh` hermetic scaffold.

**Net-new core (D-07/D-08, no direct analog — design from RESEARCH Pitfall 5):**
- Read `bundle.app_git_sha` from each captured bundle; hard-fail if `!= $(git rev-parse HEAD)`.
- `git cat-file -e <sha>` to error LOUDLY on unreachable sha (never skip).
- `git diff --name-only <bundle_sha> HEAD -- <admin globs>` non-empty ⇒ FAIL "admin source newer than bundle". Anchor globs to the SAME paths the installer-detect step uses (`ci.yml:88`): `lib/sigra/**/admin/**`, `sigra_admin.css`, admin LiveViews.
- **Absence of bundles = hard FAIL, not skip** (opposite of the tier guard's empty-base skip). Unit-test the glob in `.test.sh`.

---

### `scripts/ci/settled-findings-lint.sh` + `.test.sh` (lint)

**Analog:** `scripts/ci/quality-ledger-monotonic.test.sh` (hermetic `.test.sh` scaffold) + the `fail()` idiom from `admin-artifact-bundle-contract.sh` (lines 10-13).

**Core (D-22):** FAIL if `guides/reference/settled-findings.tsv` is unsorted or has duplicate `finding_id`. Idiom: `sort -c` / `sort -u` comparison against the committed file. Provide a regen helper (`--add … --disposition`) so humans never hand-edit ordering. `.test.sh` cases: sorted PASS, unsorted FAIL, dup FAIL.

---

### `test/example/priv/playwright/tests/admin-eval.spec.ts` (test, capture)

**Analog:** `test/example/priv/playwright/tests/admin-design.spec.ts` (sibling spec)

**Imports pattern** (lines 1-3):
```typescript
import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Locator, type Page, type TestInfo } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';
```

**`waitForLiveViewReady` font-gate** (lines 15-26) — reuse VERBATIM before any capture (D-03). The `.phx-connected` wait + `document.fonts.ready` + hard `fonts.check('16px "Space Grotesk"')` assertion:
```typescript
await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
await page.evaluate(async () => { await (document as any).fonts.ready; });
const ok = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
expect(ok, 'Space Grotesk must be loaded before snapshot').toBe(true);
```

**Admin-registration for policy access** (lines 28-52) — reuse the `registerUser` + `platform-admin+...@example.test` email-prefix pattern (`Example.SigraAdminPolicy` requires the prefix). Derive a per-project unique email.

**Card-in-card probe #8** (lines 349-361) — LIFT VERBATIM (D-14). The `evaluateAll` over `GROUP_BOARDS`, honoring `data-sg-card-nesting-audit-only`, `.sg-card .sg-card:not(.sg-skeleton)`:
```typescript
const nestedCards = await page.locator(GROUP_BOARDS.map((id) => `#${id}`).join(',')).evaluateAll(
  (boards) => boards.flatMap((board) => {
    if (board.hasAttribute('data-sg-card-nesting-audit-only')) return [];
    const nested = board.querySelectorAll('.sg-card .sg-card:not(.sg-skeleton)');
    return Array.from(nested).map((el) => ({ boardId: board.id, className: el.getAttribute('class') }));
  }),
);
```

**Render-matrix data-testid convention** (lines 336-347) — the gallery already exposes `[data-testid="mg-N-{desktop,mobile,populated,zero,loading,error}"]`; iterate these for the surface×cell matrix (D-04). No new gallery markup needed.

**In-browser probe reads (probes.ts, via `page.evaluate`)** — no verbatim analog for the `--sg-*` live reads; use RESEARCH Pattern 2/3/4. Non-negotiables from D-12/D-13: `getComputedStyle(...).getPropertyValue('--sg-space-N')` NEVER `toHaveCSS` (#12629); read box LONGHANDS; focus-ring probe diffs `box-shadow` not `outline` (authored at `sigra_admin.css:148-150` as `--sg-focus-ring: 0 0 0 3px …`); axe `target-size` MUST be explicitly enabled (`.options({ rules: { 'target-size': { enabled: true } } })`).

---

### `test/example/priv/playwright/playwright.config.ts` (config, modify)

**Analog:** existing `projects: [...]` blocks (lines 82-198) — ADD, do not fork (D-03).

**Project registration pattern** — mirror the `admin-design-{chromium,mobile,dark}` triple (lines 170-197). Add a `testMatch` regex constant beside line 27 (`const ADMIN_EVAL_SPEC = /admin-eval\.spec\.ts/;`), exclude it from `chromium`/`mobile` `testIgnore` (lines 89, 98-106), then append:
```typescript
{ name: 'admin-eval', testMatch: ADMIN_EVAL_SPEC, use: { ...devices['Desktop Chrome'] } },
// + admin-eval-mobile (iPhone 13) and admin-eval-dark (colorScheme:'dark') siblings.
// Geometry probes HARD-GATE only in the DPR1 chromium project (D-15); -mobile/-dark WARN.
```
Inherits the top-level `use` (baseURL, longpoll timeouts) and `expect.toHaveScreenshot.pathTemplate` (lines 59-68). Config has NO top-level `animations`/`caret` — pass them per-`toHaveScreenshot` call if the eval spec screenshots.

---

### `.github/workflows/ci.yml` (config, modify)

**Analog:** the existing `fast_checks` lane + `id: base` step (lines 58-116).

**D-10 base-ref fix** (lines 70-72) — the ONE-LINE semantics change. Replace:
```yaml
git fetch origin "${{ github.base_ref }}" --depth=1
echo "ref=origin/${{ github.base_ref }}" >> "$GITHUB_OUTPUT"
```
with:
```yaml
git fetch origin "${{ github.base_ref }}"     # NO --depth=1 — merge-base needs history
MB=$(git merge-base "origin/${{ github.base_ref }}" HEAD)
echo "ref=${MB}" >> "$GITHUB_OUTPUT"
```
`fetch-depth: 0` on checkout (line 64) already provides HEAD history. This corrects ALL `--base "${{ steps.base.outputs.ref }}"` consumers at once: snapshot-canary (lines 101, 105-108), quality-ledger-monotonic (line 110), and the new findings/award guards.

**New guard step registration** — attach beside the `Quality ledger monotonic guard` steps (lines 109-112), following that exact `- name:` + `run: bash scripts/ci/<guard>.sh --base "${{ steps.base.outputs.ref }}"` shape. Add self-test steps mirroring line 111-112. The expensive render+probe Playwright job does NOT go in `fast_checks` (RESEARCH Open Q2 → separate job); only the cheap deterministic derivatives gate merges (JUDGE-CI-01 invariant).

---

### `.gitignore` (config, modify)

**Analog:** the `test/example/_build/` block (lines 37-48).

Add under a Phase-216 comment (Pitfall 4 — `test/example/priv/playwright/` is NOT currently ignored):
```
test/example/priv/playwright/eval/
test/example/priv/playwright/playwright-report/
test/example/priv/playwright/test-results/
```

---

### `guides/reference/settled-findings.tsv` + `admin-render-sha.json` (committed data)

**Analog:** `guides/reference/admin-quality-ledger.md` — for the ROLE (forward-only committed signal guarded by a monotonic script) and the FROZEN-GRAMMAR discipline (lines 14-31, 32-39): the tier column-4 is a bare `[012]` with a hard "decorators forbidden" contract because the `awk -F'|'` positional parse breaks silently on any decorator (proven in Test D). Apply the same discipline: keep the format machine-parseable, one authoritative source per guard, structural anchors (never prose/line-numbers). Columns per D-22: `finding_id  surface  class  anchor  disposition  waived_by  note`, sorted, one-per-line. `finding_id = sha256(surface \0 class \0 anchor)` — MUST match Phase 217 AUTOFIX-01 (see cross-phase flag below).

## Shared Patterns

### Bash guard skeleton
**Source:** `scripts/ci/quality-ledger-monotonic.sh:6-20`
**Apply to:** every new bash guard (`stale-render`, `quality-findings-monotonic`, `settled-findings-lint`)
```bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="HEAD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    *) echo "<name>: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done
fail() { echo "<name>: FAIL: $*" >&2; exit 1; }
```

### git-base-ref diff (associative-array compare)
**Source:** `scripts/ci/quality-ledger-monotonic.sh:30-53`
**Apply to:** `quality-findings-monotonic.sh` (invert comparator), `award-guard` (per-axis ordinal compare vs merge-base), `stale-render-guard.sh` (`git cat-file -e` / `git diff --name-only`)
Use `git -C "$ROOT" show "${BASE}:${FILE}"` for the base snapshot; **BASE is now the merge-base** after the D-10 fix.

### Hermetic self-test (mktemp throwaway git repo)
**Source:** `scripts/ci/quality-ledger-monotonic.test.sh:9-58, 88-117, 212-224`
**Apply to:** `.test.sh` / self-test for EVERY new guard
`mktemp -d` + `trap cleanup EXIT`; `pass()`/`fail()` counters; locate `REAL_GUARD` via `${BASH_SOURCE[0]}`; `git init -q` with local identity; `cp` guard into temp repo at `scripts/ci/`; commit fixture; run guard with `set +e; (...); EXIT=$?; set -e`; assert exit code AND stderr substring; summary block that `exit 1` on any FAIL.

### Bash orchestrator over Playwright
**Source:** `scripts/ci/snapshot-recapture-gate.sh:14-18, 64-98`
**Apply to:** `admin-eval-harness.sh`
`ROOT`/`PW`/`SIGRA_EXAMPLE_URL` header; `( cd "$PW" && CI=true SIGRA_EXAMPLE_URL="$SIGRA_EXAMPLE_URL" npx playwright test <spec> --project=<name> )` subshell; labeled phase `echo`s; chain into downstream `bash scripts/ci/<guard>.sh`.

### LiveView-ready capture gate
**Source:** `test/example/priv/playwright/tests/admin-design.spec.ts:15-26`
**Apply to:** `admin-eval.spec.ts` (before every capture)
Reuse `waitForLiveViewReady` verbatim (`.phx-connected` + `fonts.ready` + hard `fonts.check`).

### Suppression-attribute convention
**Source:** `admin-design.spec.ts:352` (`data-sg-card-nesting-audit-only`)
**Apply to:** every probe's escape hatch — use `data-sg-<probe>-audit-only` (D-14). Do NOT invent a new suppression mechanism.

## No Analog Found

Files with no close match — planner must design net-new, grounded in RESEARCH.md (cited sections below):

| File | Role | Data Flow | Reason / RESEARCH grounding |
|------|------|-----------|------------------------------|
| `scripts/ci/evidence-anchor-check.mjs` | integrity check (node/cheerio) | HTML-parse | **No `.mjs` exists in `scripts/ci/`** (verified: only `.sh` + `scripts/ci/lib/*.sh`). No cheerio precedent anywhere in repo. Design from RESEARCH Pattern 6: `import { load } from 'cheerio'; $(finding.anchor).length === 0 ⇒ exit 1`. HTML mode (not `xmlMode`). Anchors are structural selectors, never prose. |
| `scripts/ci/award-guard.mjs` (or `.sh`+jq) | guard (node/json) | git-plumbing + JSON | **No node guard and no jq-based JSON guard exist in `scripts/ci/`** (verified: no `.mjs`, no `jq` in any `scripts/ci/*.sh`). Only the bash MONOTONIC IDIOM transfers. Design from RESEARCH "Award guard FAIL conditions" (5 cases) + JSON schema §. Ordinal `A0..A3 → 0..3`; `band = min(axes)` recomputed; `verified_at_sha` freshness; `evidence_ref` resolves to known probe/test id; per-axis decrease vs merge-base = FAIL. Self-test must cover all 5 cases. Planner's discretion `.mjs` vs `.sh`+jq (CONTEXT Discretion). |
| `test/example/priv/playwright/lib/eval/canonicalize.ts` | utility (TS/parse5) | transform | No parse5/DOM-canonicalization code in repo. Net-new. Design from RESEARCH Pattern 1 (allowlist tree-walk, strip volatile `data-phx-*`/`nonce`/`?vsn=`, sort attrs+class tokens, `sha256` via `node:crypto`). Determinism self-test required (same HTML → same sha; mutated `data-phx-id` → same sha). |
| `guides/reference/admin-award-ledger.json` | config/data | — | No committed JSON ledger in `guides/reference/` (existing ledgers are markdown/tsv). Net-new schema from RESEARCH "Ledger / Award JSON Schema" §: `schema_version`, `cells.<surface>.{axes,band,verified_at_sha,rendered,evidence_ref}`. Frozen markdown tier column-4 stays untouched (D-19). |

**Cross-phase contract flag (A3 / Open Q1):** `finding_id = sha256(surface \0 class \0 anchor)` (D-22, RESEARCH schema §) MUST be locked JOINTLY with Phase 217 AUTOFIX-01, whose text says `surface+lens+question+anchor`. The 216 substrate key uses `class` (probes have a class, not a lens/question). Planner must not finalize the `settled-findings.tsv` columns without 217's queue schema in view.

## Metadata

**Analog search scope:** `scripts/ci/` (+ `scripts/ci/lib/`), `test/example/priv/playwright/{tests,helpers}/`, `guides/reference/`, `.github/workflows/ci.yml`, `.gitignore`, `test/example/priv/static/assets/sigra_admin.css`
**Files scanned:** ~14 (2 upstream docs + 12 analog/target files, targeted reads)
**Key verified facts:** no `.mjs` and no jq-JSON guard in `scripts/ci/` (award + anchor guards are net-new mechanism); `--sg-focus-ring` is `box-shadow`-authored at `sigra_admin.css:148-150` (grounds D-13); ledger tier column-4 frozen-grammar contract at `admin-quality-ledger.md:14-39`
**Pattern extraction date:** 2026-07-03
