# Phase 230: Tier-1 Critical-Path Reclamation - Pattern Map

**Mapped:** 2026-07-28
**Files analyzed:** 8 (5 new, 3 modified)
**Analogs found:** 8 / 8

No UI/component work in this phase. Every artifact is a CI guard script, an ExUnit
`ci.yml`-contract test, a workflow edit, or a Playwright spec edit.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/ci/ci-run-metrics.sh` (new) | utility / CI guard | batch (`gh` API read → table) | `scripts/ci/notify-failure-issue.sh` (gh-calling) + `scripts/ci/quality-ledger-monotonic.sh` (flag parsing) | exact (role), split across two |
| `scripts/ci/ci-run-metrics.test.sh` (new) | test (hermetic self-test) | batch | `scripts/ci/notify-failure-issue.test.sh` | **exact** |
| `scripts/ci/playwright-cache-key-guard.sh` (new) | utility / CI guard | file-I/O (two files cross-checked) | `scripts/ci/quality-ledger-monotonic.sh` | exact |
| `scripts/ci/playwright-cache-key-guard.test.sh` (new) | test (hermetic self-test) | file-I/O | `scripts/ci/notify-failure-issue.test.sh` (harness) + `scripts/ci/app-css-corruption-check.test.sh` (file-fixture flavor) | exact |
| `test/sigra/planning/phase_230_*_contract_test.exs` (new) | test (static contract) | file-I/O | `test/sigra/planning/phase_153_infra_stability_contract_test.exs` | **exact** |
| D-23 honest-skip artifact (new, durable) | config / documentation manifest | n/a | `MAINTAINING.md` §"CI cadence — PR-fast vs nightly/main-broad" + §"Accepted residuals (D-07 honest-truth disclosure)" | exact |
| `.github/workflows/ci.yml` (modified) | config | event-driven | in-file idioms (below) | in-file |
| `test/example/priv/playwright/tests/admin-design.spec.ts` (modified) | test (browser) | request-response | in-file idioms (below) | in-file |

`test/example/priv/playwright/playwright.config.ts` is listed in CONTEXT.md as *possibly*
modified. RESEARCH.md Pitfall 1 is decisive that it must stay **unmodified**. No pattern is
assigned to it; a plan proposing an edit there should be rejected.

---

## Pattern Assignments

### `scripts/ci/ci-run-metrics.sh` (utility / CI guard, batch)

**Analogs:** `scripts/ci/notify-failure-issue.sh` (gh + fail-closed env contract),
`scripts/ci/quality-ledger-monotonic.sh` (flag parsing + PASS/FAIL vocabulary).

**Header / provenance-comment convention** (`notify-failure-issue.sh:1-19`) — every guard opens
with `#!/usr/bin/env bash`, a phase/decision-ID attribution, an explicit contract paragraph,
a named consumer list, a Security note when it touches `gh`/contexts, then `set -euo pipefail`:

```bash
#!/usr/bin/env bash
# Shared idempotent tracking-issue notifier (D-07) for release-lane failures.
#
# Reads LABEL, TITLE, BODY from the environment (all required; fail-closed
# otherwise) and requires GH_TOKEN (issues: write). ...
#
# Two consumers (Phase 222 Plan 02, D-02/D-06.3):
#   - ci.yml `notify_release_lane_rot`            -- HARD-01: red ci-gate on main
#   - release-please.yml `notify-release-failure` -- HARD-02: publish/gate failure
#
# Security: never echoes GH_TOKEN or any secret. GitHub context strings
# (branch/actor/ref/run id/etc.) must reach this script only via the calling
# workflow step's `env:` mapping -- never inlined into a `run:` shell
# expression -- so a crafted context string cannot inject shell or workflow
# commands.
set -euo pipefail
```

**Fail-closed required-input pattern** (`notify-failure-issue.sh:21-24`) — this is exactly
RESEARCH.md's behavioural requirement 4 ("fail-closed on missing `gh`"):

```bash
: "${LABEL:?LABEL is required (e.g. release-lane-rot)}"
: "${GH_TOKEN:?GH_TOKEN is required (issues: write)}"
```

**Arg parsing + ROOT + fail() convention** (`quality-ledger-monotonic.sh:4-20`) — copy this
loop shape verbatim for `--repo/--workflow/--limit/--since/--event/--mode/--format/--jobs`.
Note the **unknown-arg exit 2** (distinct from the exit-1 failure code):

```bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="guides/reference/admin-quality-ledger.md"
BASE="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    *) echo "quality-ledger-monotonic: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "quality-ledger-monotonic: FAIL: $*" >&2
  exit 1
}
```

**Output vocabulary** — `<script-name>: FAIL: <reason>` to stderr on failure,
`<script-name>: INFO: ...` for a benign skip, `<script-name>: PASS (<n> cells checked vs <ref>)`
on success (`quality-ledger-monotonic.sh:37, 49, 59`). `ci-run-metrics.sh` should keep this for
its guard-ish paths and emit the REQUIREMENTS.md table on stdout.

**`gh` invocation form** (`notify-failure-issue.sh:26`) — `gh` is called bare (resolved via
`PATH`, which is what makes the PATH-stub self-test hermetic), with `--jq` doing the filtering:

```bash
existing="$(gh issue list --label "$LABEL" --state open --json number --jq '.[0].number' || true)"
```

**`$GITHUB_STEP_SUMMARY` convention** (`ci.yml:1254-1260`) — brace-group redirect, `if: always()`,
a `##` heading then `- key: value` lines. FAST-06's cache-hit evidence line is appended to this
**existing** step rather than a new one:

```yaml
      - name: Cache hit summary
        if: always()
        run: |
          {
            echo "## example_playwright_smoke cache"
            echo "- deps cache (exact hit): ${{ steps.example_deps_cache.outputs.cache-hit }}"
          } >> "$GITHUB_STEP_SUMMARY"
```

---

### `scripts/ci/ci-run-metrics.test.sh` (test, hermetic)

**Analog:** `scripts/ci/notify-failure-issue.test.sh` (138 lines) — read in full; copy structurally.

**Harness preamble — locate script, fail-fast if missing, pass/fail counters** (lines 14-37):

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/notify-failure-issue.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: script not found at ${SCRIPT}" >&2
  exit 2
fi

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

TMPDIR_ROOT=""
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "$TMPDIR_ROOT" && -d "$TMPDIR_ROOT" ]]; then
    rm -rf "$TMPDIR_ROOT"
  fi
}
trap cleanup EXIT
```

**The hermeticity mechanism — a PATH-shadowing recording `gh` stub** (lines 39-60). This is the
single most important pattern to copy: the stub logs argv to a file and returns canned stdout
driven by an env var, so the test asserts on *what the script called* with no network/token.
For `ci-run-metrics.sh` the stub must return canned `gh run list --json` / `gh run view --json jobs`
JSON — including a negative-duration skipped job and a `failure`-with-`continue-on-error` job:

```bash
TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
: > "$GH_STUB_LOG"

cat >"${STUB_BIN_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
# Recording stub for `gh` (test-only). Logs argv, returns a scripted response.
set -euo pipefail
echo "$*" >> "${GH_STUB_LOG}"
if [[ "${1:-}" == "issue" && "${2:-}" == "list" ]]; then
  echo "${GH_STUB_ISSUE_NUMBER:-}"
  exit 0
fi
echo "gh stub: unexpected invocation: $*" >&2
exit 1
STUB
chmod +x "${STUB_BIN_DIR}/gh"
```

**Per-case shape — narrate, reset log, run with PATH prepended under `set +e`, assert on
exit code AND the stub's argv log** (lines 62-82):

```bash
echo "Test A: no open issue -> gh issue create exactly once, never gh issue comment"
: > "$GH_STUB_LOG"

set +e
PATH="${STUB_BIN_DIR}:${PATH}" \
  GH_STUB_LOG="$GH_STUB_LOG" \
  GH_STUB_ISSUE_NUMBER="" \
  LABEL="release-lane-rot" TITLE="Red main" BODY="run url" GH_TOKEN="stub-token" \
  bash "$SCRIPT" >/dev/null 2>&1
EXIT_A=$?
set -e

CREATE_COUNT_A=$(grep -c '^issue create' "$GH_STUB_LOG" || true)
COMMENT_COUNT_A=$(grep -c '^issue comment' "$GH_STUB_LOG" || true)

if [[ "$EXIT_A" -eq 0 && "$CREATE_COUNT_A" -eq 1 && "$COMMENT_COUNT_A" -eq 0 ]]; then
  pass "Test A: created once, never commented (exit ${EXIT_A})"
else
  fail "Test A: exit=${EXIT_A} create_count=${CREATE_COUNT_A} comment_count=${COMMENT_COUNT_A}"
fi
```

**Fail-closed negative case** (lines 106-124) — assert **zero** stub calls, not just non-zero exit:

```bash
CALL_COUNT_C=$(wc -l <"$GH_STUB_LOG" | tr -d ' ')
if [[ "$EXIT_C" -ne 0 && "$CALL_COUNT_C" -eq 0 ]]; then
  pass "Test C: exited non-zero (${EXIT_C}) with zero gh calls (fail-closed, no partial call)"
```

**Summary block + exit** (lines 126-139) — copy byte-for-byte modulo the script name:

```bash
echo ""
echo "----------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "----------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo "notify-failure-issue.test: FAIL"
  exit 1
fi

echo "notify-failure-issue.test: PASS"
exit 0
```

**Also copy the docblock case list** (lines 1-13): the self-test header enumerates cases A/B/C
in prose that mirrors the plan's `<behavior>` block. Do the same for the four behaviours
RESEARCH.md pins (clamp-negative, explicit p50, no `conclusion == "success"` filter, fail-closed).

---

### `scripts/ci/playwright-cache-key-guard.sh` + `.test.sh` (utility + test, file-I/O)

**Analog:** same pair shape as above. For the *script* body the closer analog is
`quality-ledger-monotonic.sh` (reads two sources, compares, `FAIL:`/`PASS (...)`), because this
guard makes **no `gh` call** — it reads `.github/workflows/ci.yml` and
`test/example/priv/playwright/package-lock.json` off disk.

- Reuse the `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"` + relative-path-constants
  form (`quality-ledger-monotonic.sh:6-8`, `settled-findings-lint.sh:27-28`).
- Reuse the `while [[ $# -gt 0 ]] ... case` loop even if the guard takes no flags today —
  unknown args must exit 2, not be silently ignored.
- Its self-test needs **no `gh` stub**; it needs a `mktemp -d` fixture dir with a fake `ci.yml`
  snippet and a fake `package-lock.json` at matching then mismatching versions. Keep the same
  `pass`/`fail` counters, `trap cleanup EXIT`, and summary block. Closest in-repo file-fixture
  flavor: `scripts/ci/app-css-corruption-check.test.sh`.

**`fast_checks` wiring** — new guards are appended as adjacent `guard` + `guard self-test` step
pairs, each carrying a phase/decision-ID comment explaining *why* it exists and what it does
**not** cover. Copy this exact adjacency convention (`ci.yml:119-122, 158-167`):

```yaml
      - name: Quality ledger monotonic guard
        run: bash scripts/ci/quality-ledger-monotonic.sh --base "${{ steps.base.outputs.ref }}"
      - name: Quality ledger monotonic guard self-test
        run: bash scripts/ci/quality-ledger-monotonic.test.sh
      - name: Upgrade-smoke resolver self-test
        # Phase 222 Plan 01 (HARD-01): offline proof that resolve-sigra-source.sh
        # durably excludes the immutable Hex stray 1.20.0 ... No network call — stubs `mix hex.info sigra`.
        run: bash scripts/ci/upgrade-smoke.test.sh
      - name: Notify-failure-issue self-test
        # Phase 222 Plan 02 (HARD-01/HARD-02/D-07): hermetic proof that the shared
        # tracking-issue notifier is idempotent (create-once / comment-once) and
        # fail-closed on missing LABEL/TITLE/BODY. No real `gh` CLI or network call.
        run: bash scripts/ci/notify-failure-issue.test.sh
```

Insert the two new self-test steps **before** the `actions/setup-node` step at `ci.yml:213` —
everything after that line is the cheerio-dependent block that requires `npm ci`. Both new
self-tests are bash-only and must sit in the zero-setup region.

Note the split convention at `ci.yml:146-149`: when a guard cannot run in `fast_checks` (it needs
artifacts), only the **self-test** is wired there and the comment says so explicitly.
`ci-run-metrics.sh` is in that category — it needs live `gh`; wire only `ci-run-metrics.test.sh`.

---

### `test/sigra/planning/phase_230_*_contract_test.exs` (test, static contract)

**Analog:** `test/sigra/planning/phase_153_infra_stability_contract_test.exs` (81 lines).

**Module + module-attribute path constants** (lines 1-11) — `async: true`, no DB, paths as
`@attr` constants at the top, `ci.yml` bound to `@ci`:

```elixir
defmodule Sigra.Planning.Phase153InfraStabilityContractTest do
  use ExUnit.Case, async: true

  @phase_dir ".planning/milestones/v1.33-phases/153-infra-stability"
  @ci ".github/workflows/ci.yml"
```

**The `ci.yml` assertion idiom** (lines 66-80) — **no YAML parser**. `File.read!/1` then
substring/regex assertions, iterating a list constant. Follow this exactly for both new
assertions:

```elixir
  test "existing CI proof lanes remain the phase proof surface" do
    ci = File.read!(@ci)
    plan = File.read!(Path.join(@phase_dir, "153-01-PLAN.md"))

    for lane <- [
          "library_tests",
          "library_tests_dep_off",
          "example_unit_smoke",
          "example_playwright_smoke",
          "generated_admin_playwright_smoke"
        ] do
      assert ci =~ lane
      assert plan =~ lane
    end
  end
```

**Regex + `refute` for negative contracts** (lines 39, 48-51) — the FAST-07 completeness assertion
is naturally a count comparison; the `@snapshot` tag-integrity assertion needs both `assert` and
`refute` per test:

```elixir
    assert postgres_case =~ ~r/start_owner!\(\s*Sigra\.Test\.PostgresRepo/
    refute source =~ "start_supervised!({Sigra.Test.PostgresRepo"
```

**Concrete shapes for the two new assertions** (following the above idiom):

- **FAST-07 timeout completeness:** count `runs-on:` occurrences and `timeout-minutes:`
  occurrences in `File.read!(@ci)` via `Regex.scan(~r/^\s+runs-on:/m, ci)` and assert the
  `timeout-minutes` count is `>=` the `runs-on` count (matrix jobs still declare one each).
  Prefer a per-job walk if the plan wants named failure output — but keep it string-based;
  **no YAML dependency is in `mix.exs` and none may be added** (RESEARCH.md: no dep changes).
- **`@snapshot` tag integrity:** `File.read!("test/example/priv/playwright/tests/admin-design.spec.ts")`,
  assert the board-generation loop contains `{ tag: '@snapshot' }`, assert the three axe test
  titles are present, and `refute` that `test.describe('Design gallery board snapshots'` carries a
  tag argument (which would sweep all 40 tests).

**Naming:** `test/sigra/planning/phase_230_<slug>_test.exs`, module
`Sigra.Planning.Phase230<Slug>Test`. No registration step exists — `mix test` discovers the file;
`test/sigra/planning/` is run wholesale as the fast pre-check.

---

### D-23 honest-skip artifact (config / documentation manifest)

**Analog:** `MAINTAINING.md` §"CI cadence — PR-fast vs nightly/main-broad (Phase 196)" and
§"Accepted residuals (D-07 honest-truth disclosure)". This is the repo's established durable,
committed, later-phase-consumed CI inventory — exactly what D-23 asks for, and it already
enumerates the pre-existing non-PR job set that Phase 230 *extends*.

**Shape to imitate** (structure, not content): a phase-attributed `###` heading; a two-tier
bulleted enumeration with the tier stated as a literal trigger list; then a numbered
"Accepted residuals" subsection where each item names what is **not** covered and what
backstops it:

```markdown
### CI cadence — PR-fast vs nightly/main-broad (Phase 196)

**PR-fast gate (runs on every PR and push):**
- The 5 required lanes (Library tests, Example unit smoke, ...)
- `install_golden_contract` (path-gated on installer changes)

**Nightly / main / dispatch-broad coverage (runs on `schedule:`, `push: main`,
`workflow_dispatch` — skipped on PRs):**
- `install_matrix` (four flag-combination installs)
- `nightly_probe` (forced-failure self-test; see runbook below)

#### Accepted residuals (D-07 honest-truth disclosure)

Two coverage areas moved to nightly are accepted residuals and must never be silently
treated as "covered on PRs":

1. **`upgrade_smoke` whole upgrade path** — ... This is accepted as release-boundary
   coverage; any regression surfaces before a Hex publish.
```

**Placement recommendation:** RESEARCH.md Open Question 2 leaves this to the planner. Two
in-repo precedents exist for a *durable* CI artifact: `MAINTAINING.md` (living, maintainer-facing,
survives milestone close) and `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` (a standalone
top-level `.planning/*.md` findings doc, also durable — phase directories get archived but
top-level `.planning/*.md` files do not). Extending the existing `MAINTAINING.md` sections is the
stronger match because the pre-existing honest-skip set already lives there and Phase 230 is
adding to that same set rather than starting a new one. A standalone
`.planning/CI-HONEST-SKIP-SET.md` following the `v1.42-CI-GATE-REMEDIATION-FINDINGS.md` precedent
is the acceptable alternative. **Do not** put it in the phase SUMMARY — those archive at
milestone close while GATE-03/GATE-05 need it live.

Per RESEARCH.md Pitfall 8, this artifact is also the designated home for the recorded loss of
per-board axe attribution plus its recovery route
(`admin-generated.spec.ts:160-161`, `AxeBuilder(...).include(selector)`).

---

### `.github/workflows/ci.yml` (config, event-driven) — in-file idioms

RESEARCH.md §"Verified Line Anchors (HEAD 5db4f0fb)" carries the anchor table; not duplicated here.
These are the **idioms each edit must imitate**.

**1. Non-PR gating (FAST-03, D-10)** — the literal form, seven existing sites
(`:646, 699, 750, 880, 1564, 1871, 2248`). Insert as one line in the job header, after `needs:`,
above `continue-on-error:` — and **do not touch `:2110`** (D-11):

```yaml
  admin_eval_render:
    name: Admin eval render + probe (evidence only, not a merge gate)
    runs-on: ubuntu-latest
    needs: [release_ref_guard]
    if: github.event_name != 'pull_request'
    continue-on-error: true
```

**2. The FAST-05 template — `install_golden_contract`'s always-run job + `detect` step**
(`ci.yml:228-308`). Three load-bearing pieces: `fetch-depth: 0` on checkout (`:243-245`), the
`detect` step that short-circuits `run=true` on non-PR events then does a shallow base fetch
before `git diff` (`:246-261`), and `if: steps.detect.outputs.run == 'true'` repeated on **every**
heavy step including `setup-beam` and the cache (`:264, :270, :279, :284, :287, :290, :302`):

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
        with:
          fetch-depth: 0
      - name: Detect installer-related changes (PRs only)
        id: detect
        shell: bash
        # Phase 51: include GA-adjacent lib surfaces ... — see MAINTAINING.md §Installer golden CI contract.
        run: |
          set -euo pipefail
          if [ "${{ github.event_name }}" != "pull_request" ]; then
            echo "run=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          git fetch origin "${{ github.base_ref }}" --depth=1
          if git diff --name-only "origin/${{ github.base_ref }}...HEAD" | grep -qE '^priv/templates/sigra\.install/|^lib/sigra/install/'; then
            echo "run=true" >> "$GITHUB_OUTPUT"
          else
            echo "run=false" >> "$GITHUB_OUTPUT"
          fi
      - uses: erlef/setup-beam@54075bcc5e249e4758d363f27d099f55d843f124  # v1.24.1
        id: setup
        if: steps.detect.outputs.run == 'true'
```

Note the **polarity difference** the plan must handle: this precedent uses `run=true` (opt-in to
work); RESEARCH.md's `changes` job uses `docs_only` with consumers testing
`!= 'true'` (fail-open). Same structure, inverted output name — state the polarity in the step
comment so a reader does not pattern-match the wrong sense.

Also note the security convention (RESEARCH.md §Security V5): `github.base_ref` should reach the
`run:` shell via an `env:` mapping rather than inline `${{ }}`, per
`notify-failure-issue.sh:14-18`. The existing `detect` step predates that convention; the new
`changes` job should adopt the safer form.

**3. SHA-pinned `actions/cache` block (FAST-06, D-18)** — house shape at `ci.yml:1028-1036`:
`name:` + `id:` + SHA-pinned `uses:` with a trailing `# vX.Y.Z` comment, then
`path:` / `key: ${{ runner.os }}-<scope>-...-v1` / `restore-keys:` prefix:

```yaml
      - name: Cache example deps
        id: example_deps_cache
        uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0
        with:
          path: |
            test/example/deps
            test/example/_build
          key: ${{ runner.os }}-example-dev-otp${{ steps.setup.outputs.otp-version }}-...-v1
          restore-keys: ${{ runner.os }}-example-dev-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-dev-
```

The new step goes immediately before `Install Playwright browsers` (`ci.yml:1066-1068`), whose
current body is the one-liner the FAST-06 branch replaces:

```yaml
      - name: Install Playwright browsers
        working-directory: test/example/priv/playwright
        run: npx playwright install --with-deps chromium webkit
```

The same `id:` then feeds the **existing** `Cache hit summary` step (`ci.yml:1254-1260`) — add a
line there rather than creating a new summary step.

**4. The seam-outcome aggregator loop (D-05, the phase's #1 silent-failure mode)**
(`ci.yml:1225-1244`). The new `design_gallery_snapshots` step id must be added to this loop.
Note the step-authoring idiom the new snapshot step must also copy from its sibling at
`:1168-1193`: `name:` + `id:` + `if:` + `working-directory:` + `env: { CI, SIGRA_EXAMPLE_URL }` +
a multi-line `run: |` with one `--project=` flag per line:

```yaml
      - name: Aggregate Playwright step outcomes
        if: always()
        # D-02 (197-02): re-fails the job if any guarded seam returned 'failure'.
        run: |
          set -euo pipefail
          fail=0
          for o in "${{ steps.admin_behavior.outcome }}" \
                   "${{ steps.admin_checkpoints.outcome }}" \
                   "${{ steps.design_gallery.outcome }}" \
                   "${{ steps.non_admin_smoke.outcome }}" \
                   "${{ steps.demo_showcase.outcome }}"; do
            [ "$o" = "failure" ] && fail=1
          done
          if [ "$fail" -eq 1 ]; then
            echo "::error::one or more Playwright seams failed"; exit 1
          fi
          echo "all seams passed"
```

The step being copied for the new snapshot step (`ci.yml:1168-1193`), minus its long comment:

```yaml
      - name: Run design gallery boards (chromium, mobile, dark)
        id: design_gallery
        if: ${{ !cancelled() }}
        working-directory: test/example/priv/playwright
        env:
          CI: "true"
          SIGRA_EXAMPLE_URL: "http://localhost:4000"
        run: |
          npx playwright test \
            tests/admin-design.spec.ts \
            --project=admin-design-chromium \
            --project=admin-design-mobile \
            --project=admin-design-dark
```

The new step's `if:` must compose both conditions:
`if: ${{ !cancelled() && github.event_name != 'pull_request' }}` — keeping the house `!cancelled()`
seam guard alongside the FAST-03 event form.

**5. Decision-ID comments on load-bearing edits.** Every non-obvious `ci.yml` construct carries a
`# Phase NNN (REQ-ID / D-NN): <why>` comment (`:123-125, :175-1187, :1227-1230, :249, :298-300`).
Every FAST-0x edit must carry one; the aggregator-`id` addition and the `continue-on-error`
non-removal especially, since both are silent-failure boundaries.

**6. `timeout-minutes` placement (FAST-07).** Only one site exists today (`ci.yml:1347`, inside
`generated_admin_playwright_smoke`, and it is the value FAST-07 corrects). RESEARCH.md sets the
convention: immediately after `runs-on: ubuntu-latest` in every job header. Consistency of slot
across all 22 jobs matters more than matching the one legacy position.

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (test, browser) — in-file idioms

**The test-declaration form the `{ tag: '@snapshot' }` details object threads into**
(`admin-design.spec.ts:257-261`) — the details object is the **second positional argument**,
between the title and the body; the existing `async ({ page }, testInfo)` destructuring and the
one-line delegating body are unchanged:

```ts
  for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS]) {
    test(`board: ${boardId}`, async ({ page }, testInfo) => {
      await assertBoardScreenshot(page, testInfo, boardId);
    });
  }
```

**The untagged sibling form the three new axe tests copy** (`:263-267`) — plain `test(title, fn)`,
declared inside the same `test.describe` so it inherits the `beforeEach`. Note the arg list is
`async ()` when the body needs no page, `async ({ page })` when it does:

```ts
  test('notice_link board is registered as a standalone L1 component', async () => {
    expect(COMPONENT_BOARDS).toHaveLength(13);
```

**The `beforeEach` the new axe tests must inherit unchanged** (`:243-255`) — the reason the axe
tests belong *inside* the describe rather than in a new one:

```ts
test.describe('Design gallery board snapshots', () => {
  test.beforeEach(async ({ page }, testInfo) => {
    const adminEmail = adminDesignEmail(testInfo);
    await registerUser(page, adminEmail, TEST_PASSWORD);
    await page.goto('/admin/_design');
    await waitForLiveViewReady(page);
  });
```

**The helper whose axe call site moves** (`:77-78`) — `assertNoAxeViolations` itself is reused
unchanged; only line 78 is deleted from `assertBoardScreenshot`:

```ts
async function assertBoardScreenshot(page: Page, testInfo: TestInfo, boardId: string) {
  await assertNoAxeViolations(page, `axe:${boardId}`);   // ← this line moves out
  const dark = testInfo.project.name.includes('dark');
```

**The wrong doc comment that must be corrected in the same commit** (`:58-60`, and the parallel
claim at `:5-13`). The code at `:64-66` calls `new AxeBuilder({ page })` with **no `.include()`** —
a full-document scan — contradicting the prose:

```ts
  // This helper is element-scoped (board locator, not full page), so it runs
  // against the board element rather than the whole admin shell. The axe
  // `best_practice` tag-group is intentionally excluded (D-09): ...
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
    .analyze();
```

**Comment-density convention:** every non-obvious construct in this spec carries a
`Phase NN / D-NN` attributed rationale block (`:54, :72-76, :82-83, :244-249`). The tag loop, the
three new axe tests, and the corrected helper comment must each carry one citing FAST-02 / D-01.

---

## Shared Patterns

### Guard-plus-hermetic-self-test pair
**Source:** `scripts/ci/notify-failure-issue.{sh,test.sh}`; wiring at `ci.yml:119-122, 163-167`.
**Apply to:** both new `scripts/ci/*` pairs.
Every new script under `scripts/ci/` ships with a `<name>.test.sh` sibling that is fully hermetic
(PATH stubs or `mktemp -d` fixtures — never network, never a token) and is wired into `fast_checks`
as an adjacent step with a decision-ID comment. Exit 1 on any failed case; `pass`/`fail` counters
plus the fixed summary block.

### Phase/decision-ID attribution comments
**Source:** `ci.yml:123-125, 249, 298-300, 1227-1230`; `notify-failure-issue.sh:1-18`;
`admin-design.spec.ts:54-63, 82-83`.
**Apply to:** every file this phase touches.
Format: `Phase NNN (REQ-ID / D-NN): <what and why>`, including what the construct explicitly does
**not** cover. This is how the repo makes silent-skip boundaries reviewable.

### SHA-pinned third-party actions with a version comment
**Source:** `ci.yml:243, 262, 271, 1023, 1030`.
**Apply to:** every `uses:` in the FAST-05 `changes` job and the FAST-06 cache step.
`uses: owner/action@<40-char-sha>  # vX.Y.Z` — two spaces before `#`. This phase introduces no new
action; reuse `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` and
`actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9  # v6.1.0` verbatim.

### `<script-name>: FAIL|INFO|PASS` output vocabulary
**Source:** `quality-ledger-monotonic.sh:18-20, 37, 59`; `settled-findings-lint.sh:30-33`;
`notify-failure-issue.test.sh:133, 137`.
**Apply to:** both new scripts and both new self-tests. Failures go to stderr and carry the
script name; the PASS line states what was checked and against what.

### Static-contract ExUnit tests read files, never parse
**Source:** `test/sigra/planning/phase_153_infra_stability_contract_test.exs:66-80`.
**Apply to:** the new `phase_230_*` contract test. `use ExUnit.Case, async: true`, path constants
as module attributes, `File.read!/1` + `=~` / `Regex.scan` / `refute`. No YAML library; no DB.

### `if: always()` + explicit-aggregate rather than implicit success
**Source:** `ci.yml:1225-1244` (seam aggregator), `:417-435` (`library_tests` name-preserving
aggregator), `:1502` (`ci-gate` counting `skipped` as pass).
**Apply to:** any new step whose failure must not be discarded. A step id absent from an
aggregator's hard-coded list is silently green — this is the v1.42 failure mode and D-05's
entire reason for existing.

## No Analog Found

None. Every artifact this phase creates has a working in-repo template.

## Metadata

**Analog search scope:** `scripts/ci/` (56 files), `test/sigra/planning/`,
`.github/workflows/ci.yml`, `test/example/priv/playwright/tests/`, `MAINTAINING.md`,
`.planning/*.md`
**Files read for excerpts:** 9
**Pattern extraction date:** 2026-07-28 (HEAD `5db4f0fb`)
