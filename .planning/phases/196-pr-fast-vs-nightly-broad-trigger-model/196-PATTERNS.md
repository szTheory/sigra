# Phase 196: PR-Fast vs Nightly-Broad Trigger Model - Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 4 modified (no new files) — `ci.yml`, `MAINTAINING.md`, 2 contract tests
**Analogs found:** 6 / 6 (all in-repo; every line anchor re-verified against the live files this session)

> This phase MODIFIES existing files. Each "analog" is an existing in-repo pattern the
> executor mirrors for a surgical edit. All line numbers below were re-grepped against the
> live files on 2026-06-20 and **match RESEARCH.md's point-in-time anchors exactly**.
> Per D-12/D-15 the executor MUST still re-grep at execution (any prior commit shifts lines).

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `.github/workflows/ci.yml` (trigger block) | config (CI control plane) | event-driven | `.github/workflows/playwright-github-pages.yml:14-18` (`schedule: cron`) | exact (copy-shape) |
| `.github/workflows/ci.yml` (`workflow_dispatch.inputs` for probe) | config | event-driven | `.github/workflows/hex-publish.yml:9-24` (`inputs:` w/ `type: boolean`) | exact (copy-shape) |
| `.github/workflows/ci.yml` (5 moved job `if:` gates) | config (job) | event-driven | `upgrade_smoke` header `ci.yml:502-505` (job header shape) | exact (insertion point) |
| `.github/workflows/ci.yml` (`ci-gate` result loop, D-09) | config (aggregator) | event-driven | `ci-gate` loop `ci.yml:1289-1325` (the line to change) | exact (in-place) |
| `.github/workflows/ci.yml` (D-04 contrast — step gate, NOT used) | config (step) | event-driven | `fast_checks` detector `ci.yml:74-85` | contrast-only |
| `MAINTAINING.md` (nightly cadence + residuals + probe runbook) | doc | n/a | existing required-check section (already correct, ADD only) | role-match |
| `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` | test (contract) | transform (text assert) | line 28 assertion + ExUnit `=~` idiom in same file | exact (re-anchor) |
| `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` | test (contract) | transform (text slice) | slicer lines 27-38 (verify-only, no edit expected) | exact (verify) |

## Pattern Assignments

### 1. `ci.yml` trigger block — add `schedule: cron` (D-01)

**Analog to MIRROR:** `.github/workflows/playwright-github-pages.yml:14-18` — the live in-repo cron precedent.

```yaml
# playwright-github-pages.yml:14-18  [VERIFIED live]
on:
  workflow_dispatch:
  schedule:
    # Daily UTC; adjust if you want a different window.
    - cron: '45 6 * * *'
```

**Target shape** — the live `ci.yml` `on:` block to extend (`ci.yml:3-10`, verbatim):

```yaml
# ci.yml:3-10  [VERIFIED live]
on:
  # Release-ref evidence path: manually dispatch this workflow from a v* tag
  # (`gh workflow run "CI" --ref v1.0.0` or Actions UI) to rerun canonical gates.
  workflow_dispatch:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

**Edit:** insert a `schedule:` key (with `- cron: '<minute> <hour> * * *'`) into this block.
RESEARCH §5 recommends `cron: '30 4 * * *'` to avoid the `45 6` collision — Claude's discretion
(any non-`45 6` value satisfies D-01). Mirror the precedent's `- cron: '…'` list-item form.

---

### 2. `ci.yml` `workflow_dispatch.inputs` — forced-failure probe input (D-14)

**Analog to MIRROR:** `.github/workflows/hex-publish.yml:9-24` — the in-repo `workflow_dispatch.inputs`
precedent, including a `type: boolean … default: false` flag read via `inputs.<name>`.

```yaml
# hex-publish.yml:9-24  [VERIFIED live] — note the boolean `dry_run` flag shape
on:
  workflow_dispatch:
    inputs:
      tag:
        description: 'Git tag or commit SHA that resolves to v<release_version> (e.g. v1.0.0).'
        required: true
        type: string
      dry_run:
        description: 'Run mix hex.publish --dry-run instead of publishing.'
        required: false
        type: boolean
        default: false
```

**How an input is READ in this repo:** `hex-publish.yml:30` uses `${{ inputs.tag }}`
(`group: hex-publish-${{ inputs.tag }}`) — the `inputs.<name>` accessor (preserves type), not the
legacy `github.event.inputs.<name>`. Mirror this for the probe step `if:`.

**Edit:** ci.yml line 6 is currently the bare `workflow_dispatch:` (no `inputs:`). Convert it to
carry `inputs.force_fail_probe` using the `dry_run` boolean shape above (`type: boolean`,
`default: false`). The probe STEP guards on `if: ${{ inputs.force_fail_probe }}` and runs `exit 1`.
RESEARCH §Pattern (forced-failure probe) gives the exact step block:

```yaml
# Target step (RESEARCH-derived; lives INSIDE a non-PR-gated moved job)
  - name: Forced-failure probe (nightly self-test)
    if: ${{ inputs.force_fail_probe }}
    run: |
      echo "force_fail_probe=true: intentionally failing to prove the nightly lane reports red"
      exit 1
```

**Probe-host constraint (D-14 + Pitfall 3):** host the probe in a `needs`-free moved job so
`release_ref_guard` cannot pre-empt it. `[VERIFIED]` `passkeys_manual_fallback_smoke` (554),
`install_matrix` (604), and `passkeys_opt_out_smoke` (733) have **no `needs:`** key; `upgrade_smoke`
(505) and `generated_admin_playwright_smoke` carry `needs: release_ref_guard`. RESEARCH §Open
Question 1 recommends a dedicated `needs`-free `nightly_probe` job — Claude's discretion.

---

### 3. `ci.yml` moved-job `if:` gate — representative job header (D-02/D-05)

**Analog (insertion-point reference):** `upgrade_smoke` header, `ci.yml:502-505` (verbatim):

```yaml
# ci.yml:502-505  [VERIFIED live]
  upgrade_smoke:
    name: Upgrade smoke (published source series -> local candidate)
    runs-on: ubuntu-latest
    needs: release_ref_guard
```

**Edit (the ONLY structural add per moved job):** insert one line
`if: github.event_name != 'pull_request'` at the job level — after `runs-on:` (and after `needs:`
where present; placement among `name:`/`runs-on:`/`needs:` is cosmetic — YAML mapping keys are
unordered, but match house readability by putting `if:` adjacent to `runs-on:`/`needs:`). Mirror
exactly as RESEARCH §Pattern shows:

```yaml
  upgrade_smoke:
    name: Upgrade smoke (published source series -> local candidate)
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'   # ← the ONLY structural add per moved job
    needs: release_ref_guard
    # …body (services.postgres, caches, $GITHUB_STEP_SUMMARY) byte-identical…
```

**Apply the identical one-line `if:` to all 5 moved job headers** `[VERIFIED live line anchors]`:

| Job | Header line | `name:` (must stay byte-identical) | Has `needs:`? |
|-----|-------------|-------------------------------------|---------------|
| `upgrade_smoke` | 502 | `Upgrade smoke (published source series -> local candidate)` | yes (`release_ref_guard`) |
| `passkeys_manual_fallback_smoke` | 554 | `Passkeys manual fallback smoke` | no |
| `install_matrix` | 604 | `Install matrix (flag combinations)` | no |
| `passkeys_opt_out_smoke` | 733 | `Passkeys opt-out smoke` | no |
| `generated_admin_playwright_smoke` | 1156 | `Generated admin Playwright smoke` (`timeout-minutes: 60`) | yes (`release_ref_guard`) |

**Do NOT add `if:` to** the 5 required lanes, `install_golden_contract` (102), or
`library_tests_dep_off` (298) — D-06/D-11.

---

### 4. `ci.yml` `ci-gate` skip-tolerant result loop (D-09)

**Analog (the exact line to change, in-place):** `ci-gate` job, `ci.yml:1276-1325` (verbatim core):

```bash
# ci.yml:1289       if: always()                       [VERIFIED — already present, no change]
# ci.yml:1305-1321  the result loop:
          for lane in \
            INSTALL_GOLDEN_CONTRACT \
            LIBRARY_TESTS \
            LIBRARY_TESTS_DEP_OFF \
            INSTALL_SMOKE \
            UPGRADE_SMOKE \
            EXAMPLE_HTTP_SMOKE \
            EXAMPLE_PLAYWRIGHT_SMOKE \
            GENERATED_ADMIN_PLAYWRIGHT_SMOKE \
            FAST_CHECKS
          do
            result="${!lane}"
            if [[ "$result" != "success" ]]; then          # ← ci.yml:1317  CHANGE THIS LINE
              echo "Required release lane $lane: $result"
              failed=1
            fi
          done
```

**Edit (single condition, RESEARCH §Pattern):**

```bash
# ci.yml:1317
-            if [[ "$result" != "success" ]]; then
+            if [[ "$result" != "success" && "$result" != "skipped" ]]; then
```

**Why only this line:** `if: always()` (1289) already runs `ci-gate` when a need is skipped. Of the
9 `needs` (1280-1288), only `UPGRADE_SMOKE` (1284/1297) and `GENERATED_ADMIN_PLAYWRIGHT_SMOKE`
(1287/1300) become `skipped` on PRs; the new condition keeps a real `failure`/`cancelled` red. Do
NOT touch the `needs:` list (D-10) and do NOT add the other 3 moved jobs to it — they are not in
`ci-gate.needs` today `[VERIFIED: list is exactly the 9 above]`.

---

### 5. `ci.yml` step-level event-gate idiom — CONTRAST ONLY (D-04, NOT the pattern to copy)

**Analog (do NOT mirror for moved jobs):** `fast_checks` change-detector, `ci.yml:74-85` (verbatim):

```yaml
# ci.yml:74-85  [VERIFIED live] — STEP-level event gate; D-04 says do NOT use this for whole-job removal
        run: |
          set -euo pipefail
          if [ "${{ github.event_name }}" != "pull_request" ]; then
            echo "run=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          if git diff --name-only "origin/${{ github.base_ref }}...HEAD" | grep -qE '<path-detector>'; then
            echo "run=true" >> "$GITHUB_OUTPUT"
          else
            echo "run=false" >> "$GITHUB_OUTPUT"
          fi
      - name: Installer milestone audit (INT-01..03)
        if: steps.detect.outputs.run == 'true'
        run: bash scripts/ci/installer-milestone-audit.sh
```

**Why contrast:** this `event_name`/`steps.detect.outputs.run` step idiom is the right tool ONLY for
jobs that must keep REPORTING (required, or feeding a required aggregator) while skipping a heavy
step. `install_golden_contract` (102) uses the same idiom and STAYS PR-conditional via it (D-06).
Moved jobs use **job-level** `if:` (§3) — whole-job removal, not step gating. The executor must not
confuse the two. NOTE: this exact block (the `Installer milestone audit` step at lines 83-85) is
also the **re-anchor target** for §7 below.

---

### 6. `MAINTAINING.md` — ADD nightly cadence + residuals + probe runbook (D-07/D-13/D-14)

**Analog:** the existing required-check section (RESEARCH §7: MAINTAINING.md:100-122) is **already
correct** — it already states the 5 enforced checks are job `name:` strings and `ci-gate` is an
internal aggregator, with the verify command. **Do NOT "fix" it (anti-pattern).** ADD only:

- nightly-cadence note (the new cron, what runs nightly/main/dispatch vs every-PR);
- the two honest-truth residuals (D-07): (a) `upgrade_smoke` whole-path is nightly/main-only on PRs;
  (b) generated-host **template parity** becomes nightly-only, backstopped by DIST-06
  `scripts/ci/admin-acceptance-smoke.sh`;
- probe runbook one-liner (D-14): `gh workflow run "CI" -f force_fail_probe=true`.

Placement is Claude's discretion. The reconciled CRIT-03 framing (`ci-gate` not required) is
recorded in **196-VERIFICATION**, not by editing REQUIREMENTS.md/ROADMAP prose (RESEARCH §7 / Open Q2).

---

### 7. `phase_51_install_golden_ci_contract_test.exs` — re-anchor line 28 (D-15)

**Analog (the existing ExUnit assertion idiom to MATCH):** same file, lines 24-28 (verbatim live):

```elixir
# phase_51_install_golden_ci_contract_test.exs:24-28  [VERIFIED live]
    assert length(Regex.scan(~r/#{escaped}/, yml)) == 2,
           "expected the canonical path detector substring exactly twice (both CI jobs)"

    assert yml =~ "install_golden_contract:"
    assert yml =~ "installer_milestone_audit:"          # ← line 28: RED on main
```

**Edit (change ONLY line 28):** Phase 194 folded the `installer_milestone_audit:` **job** into the
`fast_checks` job as a **step**. Re-anchor the `yml =~ "…"` assertion to a SURVIVING anchor from the
live `fast_checks` block (§5 above, `ci.yml:83-85`) — the step name and/or run command:

```elixir
    assert yml =~ "Installer milestone audit"               # the surviving step name (ci.yml:83)
    # and/or:
    assert yml =~ "scripts/ci/installer-milestone-audit.sh" # the surviving run cmd (ci.yml:85)
```

Match the existing `assert yml =~ "<string>"` idiom (lines 27-28). **Keep lines 24 (×2 detector) and
27 (`install_golden_contract:`) intact** — only line 28 is RED (RESEARCH §8 / Pitfall 2). For honesty
(D-15), also update the `@moduledoc` (lines 2-6) and the test name (line 20), both of which still say
`installer_milestone_audit` *job* — but only line 28 is the hard RED. Do not let the test pass
vacuously.

---

### 8. `phase_58_oauth_oa01_ci_contract_test.exs` — VERIFY-only (D-16)

**Analog (the slicer to RE-VERIFY, expected no edit):** same file, lines 27-38 (verbatim live):

```elixir
# phase_58_oauth_oa01_ci_contract_test.exs:27-38  [VERIFIED live]
  defp library_tests_shard_job(yml) do
    case String.split(yml, "library_tests_shard:", parts: 2) do
      [_, tail] ->
        case String.split(tail, "\n  library_tests:", parts: 2) do
          [body, _] -> body
          _ -> tail
        end
      _ ->
        flunk("expected library_tests_shard job in .github/workflows/ci.yml")
    end
  end
```

**Why it should stay green:** the slicer splits on `"library_tests_shard:"` then `"\n  library_tests:"`.
D-02's job-level `if:` does NOT rename/reorder `library_tests_shard`/`library_tests`, and none of the
5 moved jobs sits between that boundary `[VERIFIED: moved jobs at 502/554/604/733/1156; the
shard→aggregator boundary is the 176→279 region]`. **No edit expected — D-16 mandates a post-edit
`mix test` run to confirm.** Risk only if a planner inserts a moved job between those two job keys
(don't).

---

## Shared Patterns

### Job-level event gate (applies to all 5 moved jobs)
**Source:** house-style header `ci.yml:502-505`; semantics per RESEARCH §GitHub Actions Semantics.
**Apply to:** `upgrade_smoke`, `passkeys_manual_fallback_smoke`, `install_matrix`,
`passkeys_opt_out_smoke`, `generated_admin_playwright_smoke`.
```yaml
    if: github.event_name != 'pull_request'
```
One line per job; bodies unchanged. Never apply to required lanes (D-11).

### `inputs.<name>` accessor for reading a dispatch input
**Source:** `hex-publish.yml:30` (`${{ inputs.tag }}`).
**Apply to:** the D-14 probe step `if: ${{ inputs.force_fail_probe }}`.

### ExUnit text-contract assertion idiom
**Source:** `phase_51_*` (`assert yml =~ "<string>"`) and `phase_58_*` (`String.split` slice + `=~`).
**Apply to:** the D-15 re-anchor — keep the `=~` form; anchor on a string that exists in the live
workflow post-edit.

### Doc-add-only discipline for MAINTAINING.md
**Source:** existing correct required-check section (MAINTAINING.md:100-122).
**Apply to:** all D-07/D-13/D-14 doc work — ADD nightly/probe/residual subsections; do not rewrite the
already-correct required-check list.

## No Analog Found

None. Every edit this phase makes has a concrete in-repo precedent (cron, inputs, job header, loop,
step gate, both ExUnit idioms). This is a precision phase, not a novelty phase.

## Metadata

**Analog search scope:** `.github/workflows/` (all workflow YAML), `test/sigra/planning/` (the two
contract tests), `MAINTAINING.md`.
**Files scanned:** `ci.yml`, `playwright-github-pages.yml`, `hex-publish.yml`,
`phase_51_install_golden_ci_contract_test.exs`, `phase_58_oauth_oa01_ci_contract_test.exs`.
**Live-anchor re-verification (2026-06-20):** trigger block `ci.yml:3-10` ✓; cron precedent
`playwright-github-pages.yml:14-18` ✓; inputs precedent `hex-publish.yml:9-24` ✓; moved jobs
502/554/604/733/1156 ✓ (names byte-match RESEARCH §1); `install_golden_contract:` 102,
`library_tests_dep_off:` 298, `fast_checks:` 48 ✓; ci-gate `if: always()` 1289 + needs 1279-1288 +
loop condition 1317 ✓; `fast_checks` detector/step 74-85 ✓; phase_51 RED assertion line 28 ✓;
phase_58 slicer lines 27-38 ✓.
**Pattern extraction date:** 2026-06-20
