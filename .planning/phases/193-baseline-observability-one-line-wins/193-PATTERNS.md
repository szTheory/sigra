# Phase 193: Baseline, Observability & One-Line Wins - Pattern Map

**Mapped:** 2026-06-19
**Files analyzed:** 3 (1 workflow modified, 1 spec modified, 1 planning artifact created)
**Analogs found:** 3 / 3 (every task has a first-party / in-repo analog — by design)

> Scope note: This is a deliberately small CI/DX phase. It touches NO `lib/` (security-critical) and NO `priv/templates/` (generator) code. All analogs live in the very files being modified (self-analog: `ci.yml` cache steps, `demo-showcase.spec.ts` `rgbChannels()`) or are first-party GitHub features (`$GITHUB_STEP_SUMMARY`, `actions/cache` `cache-hit`). No external packages, no new actions. See `193-RESEARCH.md` for the full verification trail.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/ci.yml` (CRIT-01: `needs:` edge drop) | config (CI DAG) | event-driven (job graph) | Every other `needs: release_ref_guard` lane in the same file (e.g. `ci.yml:82,149,198,313,363,632`) | exact (self-analog) |
| `.github/workflows/ci.yml` (BASE-03: `id:` + `$GITHUB_STEP_SUMMARY`) | config (CI observability) | transform (echo → summary file) | Existing `actions/cache` steps in same file (no `id:` yet) + the `ci-gate` `run:` shell idiom (`ci.yml:1205-1230`) | role-match (additive, first-party feature) |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts` (FLAKE-01) | test (Playwright spec) | transform (parse color → tolerance assert) | `rgbChannels()` parser + `relativeLuminance`/`contrastRatio` callers in the **same file** (`:52,:109,:120`) | exact (self-analog, parser already in-file) |
| `.planning/phases/193-.../193-BASELINE.md` (BASE-01/02) | doc (committed planning artifact) | batch (read-only `gh`/`mix` data → markdown table) | `.planning/seeds/SEED-005-...md` audit-playbook column set + sibling `.planning/` markdown tables | role-match (no prior `*-BASELINE.md`; SEED-005 dictates columns) |

## Pattern Assignments

### `.github/workflows/ci.yml` — CRIT-01 (config, event-driven)

**Analog:** Every non-`example_playwright_smoke` required lane that uses the minimal guard edge `needs: release_ref_guard` (e.g. `ci.yml:82`, `149`, `198`, `313`, `363`, `632`). They start at ~t=0 right after the 2s guard; `example_playwright_smoke` is the lone outlier carrying a gratuitous second edge.

**Exact change** (`ci.yml:697`, the ONLY line that changes for CRIT-01):
```yaml
# BEFORE
  needs: [release_ref_guard, library_tests]
# AFTER
  needs: [release_ref_guard]
```

**Surrounding context to confirm the right job** (`ci.yml:694-698`):
```yaml
  example_playwright_smoke:
    name: Example Playwright smoke (full lifecycle)
    runs-on: ubuntu-latest
    needs: [release_ref_guard, library_tests]   # ← CRIT-01 target line 697
    services:
```

**Guardrails the executor must hold:**
- KEEP `release_ref_guard` (the 2s release-ref correctness guard at `ci.yml:24-42`). Removing it is Pitfall 3 in RESEARCH. The diff must NOT drop `release_ref_guard` from the array.
- Do NOT touch the job `name:` or job id — `ci-gate.needs` (`ci.yml:1187`) references the job **id** `example_playwright_smoke`, which is unchanged; the lane stays required.
- This is a one-line change. Any diff touching cache keys, `--partitions`, or `library_tests_dep_off` selection is out of scope (Pitfall 5).

---

### `.github/workflows/ci.yml` — BASE-03 (config, transform)

**Analog A — the `actions/cache` step to add `id:` to.** All cache steps share this exact shape; add an `id:` so `cache-hit` becomes a referencable output. Current `library_tests` cache step (`ci.yml:167-173`):
```yaml
      - name: Cache library deps
        uses: actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae  # v5.0.5
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-library-${{ hashFiles('mix.lock') }}
```
Add **only** the `id:` line (additive — does NOT change `key:`, `path:`, or pin):
```yaml
      - name: Cache library deps
        id: deps_cache                       # ← ADD: enables steps.deps_cache.outputs.cache-hit
        uses: actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae  # v5.0.5
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-library-${{ hashFiles('mix.lock') }}
```
The same pattern applies to the example cache steps the summary should report on, e.g. `ci.yml:718-724` (`Cache example deps`, key `${{ runner.os }}-example-dev-...`) in `example_playwright_smoke`.

**Analog B — the in-repo `run:` shell idiom.** The repo's only multi-line CI shell is the `ci-gate` step (`ci.yml:1205-1230`), which opens with `set -euo pipefail` and reads `needs.*.result` via env vars. Mirror its `set -euo pipefail` discipline so a summary-write failure can't silently corrupt the step — but on a summary step, guard the *echo*, never the test:

```yaml
      - name: CI run summary
        if: always()                         # post-failure visibility is the whole point
        run: |
          {
            echo "## ${{ github.job }}"
            echo "- elixir: $(elixir --version | tail -1)"
            echo "- otp: $(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')"
            echo "- schedulers_online: $(elixir -e 'IO.write(System.schedulers_online())')"
            echo "- deps cache hit: ${{ steps.deps_cache.outputs.cache-hit }}"
          } >> "$GITHUB_STEP_SUMMARY"
```

**Resolved-version source already in-repo:** `erlef/setup-beam@fc68ffb...` (`ci.yml:163` and every job) resolves Elixir/OTP from `.tool-versions` (`erlang 28.5`, `elixir 1.19.5-otp-28`); echo `elixir --version` / `erl ... otp_release` (or setup-beam's `elixir-version`/`otp-version` outputs).

**Test-timing summary (BASE-03 in `library_tests`):** the `Run library tests` step is `ci.yml:185-191` (`run: mix test`). Add a sibling `if: always()` step that appends `mix test --slowest 10` output to `$GITHUB_STEP_SUMMARY` so slowest tests surface without log spelunking.

**Guardrails:**
- `if: always()` on every summary step (so failures still emit the summary).
- Adding `id:` to a cache step is inert w.r.t. caching.
- Echo only resolved versions / step outputs / static strings — NEVER interpolate untrusted `github.event.*` into a summary `run:` (shell-injection / Tampering; RESEARCH Security Domain).
- Do NOT add a new third-party action — use plain `run:` shell. Preserve `permissions: contents: read` and all SHA pins.
- Do NOT rename any job (Pitfall 1).

---

### `test/example/priv/playwright/tests/demo-showcase.spec.ts` — FLAKE-01 (test, transform)

**Analog (self, in-file):** `rgbChannels(value: string): [number, number, number]` at **`demo-showcase.spec.ts:52`** — already parses rgb + oklab into numeric channels, already consumed by `relativeLuminance` (`:110`) and `contrastRatio` (`:120-130`) in the same file. The fix reuses this existing helper; no new parser.

**The flaky assertion** (`demo-showcase.spec.ts:884-887`, inside `test("home page orients evaluators before login", ...)` at `:403`):
```js
    expect(rememberCheckedStyles.appearance).toBe("none");
    expect(rememberCheckedStyles.backgroundColor).toBe(   // ← lines 885-887: exact rgb equality, flakes ±1-2/channel
      rememberCheckedStyles.expectedAccent,
    );
```
`rememberCheckedStyles.backgroundColor` and `.expectedAccent` are produced at `:843-882` (`expectedAccent` resolved from `--vt-color-primary` at `:865-867`).

**The fix — replace the exact `toBe` (lines 885-887) with ±2 per-channel tolerance using the in-file parser:**
```js
    const [br, bg, bb] = rgbChannels(rememberCheckedStyles.backgroundColor);
    const [er, eg, eb] = rgbChannels(rememberCheckedStyles.expectedAccent);
    expect(Math.abs(br - er)).toBeLessThanOrEqual(2);
    expect(Math.abs(bg - eg)).toBeLessThanOrEqual(2);
    expect(Math.abs(bb - eb)).toBeLessThanOrEqual(2);
```

**Settle-wait precedent already present** (don't re-invent): the test already polls `::after` opacity to `"1"` before reading the checked styles (`:836-842`):
```js
    await expect
      .poll(() =>
        remember.evaluate(
          (element) => getComputedStyle(element, "::after").opacity,
        ),
      )
      .toBe("1");
```
If ±2 still proves insufficient, extend this poll pattern (or disable transitions) rather than widening tolerance further.

**Scope discipline:**
- Fix ONLY the evidenced assertion (`:885-887` `backgroundColor`). The same-family exact check at `:890-892` (`afterBackgroundColor` vs `expectedOnAccent`) is NOT evidenced as flaky by the todo — leave it unless it independently flakes (RESEARCH Open Question 2; don't over-edit).
- FORBIDDEN: do NOT add or rely on `retries`. `retries: 1` already exists at `playwright.config.ts:50`; D-15 / SEED-005 forbid masking real failures with it. Success = deterministic with retries OFF (`--retries=0`).
- Close the todo: move `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md` → `.planning/todos/completed/` when FLAKE-01 lands (state hygiene; RESEARCH Runtime State Inventory).

---

### `.planning/phases/193-.../193-BASELINE.md` — BASE-01/02 (doc, batch)

**Analog:** `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` §3 dictates the verbatim column set (no prior `*-BASELINE.md` exists in `.planning/phases/`, so this is the format authority). Markdown-table style matches the many tables already used across `.planning/` docs (e.g. RESEARCH.md's own job-enumeration table).

**Required per-job columns (SEED-005 §3 verbatim):**
```
workflow name | trigger | job name | runner | matrix dimensions | services/containers |
command(s) | average duration | p95 duration | failure/rerun rate | cache usage |
required-for-merge | quality signal | likely bottleneck | notes
```
Plus the seed's critical-path prose (which jobs gate merge, which run in parallel, which determines wall-clock, which steps dominate, what work is duplicated).

**Data-gathering commands (read-only; all verified available — `gh` 2.94.0 authed):**
```bash
RUN_ID=27846034918
# per-job durations
gh run view "$RUN_ID" --json jobs \
  --jq '.jobs[] | "\(.name)\t\((.completedAt|fromdateiso8601)-(.startedAt|fromdateiso8601))s"' \
  | sort -t$'\t' -k2 -rn
# run-level wall-clock
gh run view "$RUN_ID" --json createdAt,updatedAt
# recent runs for p95 (label sample size; n<5 → point estimate, RESEARCH Pitfall 2)
gh run list --workflow CI --limit 20 --json databaseId,event,conclusion,createdAt,updatedAt
# cache hit/miss for the snapshot (no id: yet → read from logs)
gh run view --job <JOB_ID> --log | grep -iE "cache (restored|not found|hit|miss)"
```

**BASE-02 diagnostics to record into the doc (run locally with test PG up — `scripts/db/up.sh` → `source tmp/db.env`):**
```bash
mix test --slowest 20
elixir -e 'IO.inspect({System.schedulers_online(), System.schedulers()}, label: :schedulers)'  # ubuntu-latest = 2
MIX_ENV=test mix compile --force --profile time
mix xref graph --label compile-connected
```

**Required-vs-not column source:** derive from `ci-gate.needs` (`ci.yml:1180-1190`) — the 10 required lanes are listed there. Jobs NOT in that list are non-required (signal-only).

**Honesty guardrails:** report p95 with a sample-size note (`n=3, point estimate`); use the longest recent green run as the conservative baseline (Pitfall 2).

## Shared Patterns

### Required-check gate surface (applies to CRIT-01 + BASE-03)
**Source:** `ci-gate` job, `.github/workflows/ci.yml:1177-1231` (its `needs:` list at `:1180-1190`).
The merge gate is this in-workflow job, NOT branch protection (`main` is unprotected — verified). The gate references job **ids**. Therefore: NEVER rename a job `name:` or change a job id; CRIT-01's edge drop and BASE-03's added steps both keep every job id/name intact, so the required surface is unchanged.
```yaml
  ci-gate:
    name: ci-gate
    needs:
      - install_golden_contract
      - library_tests
      - library_tests_dep_off
      - install_smoke
      - upgrade_smoke
      - example_http_smoke
      - example_playwright_smoke      # ← stays required after CRIT-01 edge drop
      - generated_admin_playwright_smoke
      - snapshot_drift_guard
      - quality_ledger_monotonic
    if: always()
```

### Supply-chain pins (applies to all `ci.yml` edits)
**Source:** every `uses:` line in `ci.yml` is SHA-pinned with a version comment (`actions/cache@27d5ce7f...  # v5.0.5`, `erlef/setup-beam@fc68ffb...  # v1.24.0`, `actions/checkout@df4cb1c...  # v6.0.3`).
**Apply to:** all BASE-03 work — add NO new action; use plain `run:` shell. Preserve top-level `permissions: contents: read`. Preserve the `mix archive.install --force hex phx_new 1.8.7` step (`ci.yml:182`; SEED-004 pin — do not touch).

### `set -euo pipefail` shell discipline (applies to BASE-03 summary steps)
**Source:** `ci-gate` run block, `ci.yml:1206`.
**Apply to:** new `$GITHUB_STEP_SUMMARY` steps — keep them `set -euo pipefail`-safe; guard the summary echo (`|| true`) if needed, NEVER the underlying test command, so a summary-write failure can't mask a real failure.

## No Analog Found

None. Every Phase 193 task has a first-party or in-repo analog (RESEARCH "Don't Hand-Roll" / "Key insight"). The planner does NOT need to fall back to RESEARCH.md's generic code examples for any file — the concrete analogs above are sufficient. The closest thing to "no analog" is `193-BASELINE.md` (no prior `*-BASELINE.md` artifact exists), but SEED-005 §3 fully specifies its format, so it is a role-match rather than a gap.

## Metadata

**Analog search scope:** `.github/workflows/ci.yml` (cache/needs/ci-gate blocks), `test/example/priv/playwright/tests/demo-showcase.spec.ts` (full file), `.planning/phases/`, `.planning/seeds/`, `.planning/` root.
**Files scanned:** ci.yml (targeted reads of jobs at lines 149-198, 693-762, 1177-1231 + full grep of cache/needs/setup-beam), demo-showcase.spec.ts (full, 999 lines), phase + seeds directory listings.
**Pattern extraction date:** 2026-06-19
