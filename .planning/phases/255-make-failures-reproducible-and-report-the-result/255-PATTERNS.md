# Phase 255: Make Failures Reproducible and Report the Result - Pattern Map

**Mapped:** 2026-10-24
**Files analyzed:** 10 anticipated file groups (exact helper names remain planner discretion)
**Analogs found:** 10 / 10, with exact role matches for the main CI seams

## File Classification

| New/Modified File or group | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `mix.exs` | config / command registry | request-response, ordered command dispatch | `mix.exs` | exact |
| `scripts/ci/*local-repro*.sh` or command recorder | utility / process wrapper | request-response, file I/O | `scripts/ci/sigra-dep-off.sh` | role-match |
| `test/example/priv/playwright/playwright.config.ts` and invocation commands | config / browser setup | request-response, file I/O | same config; `.github/actions/example-playwright-boot/action.yml` | exact |
| `.github/workflows/ci.yml` and diagnostic staging/upload steps | config / workflow | event-driven, file I/O | `.github/workflows/ci.yml` | exact |
| `scripts/ci/*diagnostic*.{sh,py,mjs}` | utility / safe archive staging | transform, file I/O | `scripts/ci/ci_metrics_security.py` | role-match |
| `scripts/ci/*` focused contract/process tests | test | request-response, file I/O | `scripts/ci/ci-browser-records.test.mjs`; `scripts/ci/ci-run-metrics-attempt.test.py` | role-match |
| `.github/workflows/*canary*.yml` if delivery changes | config / hosted canary | event-driven, file I/O | `.github/workflows/release-receipt-canary.yml` | exact |
| `.planning/execution/*/MEASUREMENT/REPLAY*` / input package | utility/config / replay | batch, file I/O | `.planning/execution/254-environment-recovery/MEASUREMENT/run.py` | exact |
| `CONTRIBUTING.md` | documentation | request-response | `CONTRIBUTING.md` | exact |
| phase result/report (location at discretion) | report / evidence | transform, file I/O | `scripts/ci/ci-run-metrics.sh` result JSON; Phase 254 result records | role-match |

## Pattern Assignments

### Mix entry point and receiver proof

**Analog:** `mix.exs` (tracked)

**Relevant excerpt** (lines 149-168):
```elixir
ci: [
  "format --check-formatted",
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "test --exclude scaffold",
  "ci.install_golden",
  "sigra.dep_off"
],
"ci.install_golden": [
  "test test/sigra/install/features/passkeys_js_test.exs ... test/upgrade_test.exs"
],
"sigra.dep_off": ["cmd bash scripts/ci/sigra-dep-off.sh"],
```

**Use:** retain this seven-leg ordering and the `MIX_ENV=test mix ci` surface. Add actual process/receiver evidence where the receiver is invoked; alias text or a successful aggregate exit is insufficient to prove nested Mix receivers ran. The scaffold receiver owns its explicit six-test list exactly once. Keep failure exit behavior intact.

**Pitfall:** nested `mix test` calls can be skipped by Mix alias semantics while the outer command exits zero. Verify ordinary, scaffold and dep-off receiver markers independently before claiming parity.

### Dep-off wrapper, outcome ownership, and cleanup

**Analog:** `scripts/ci/sigra-dep-off.sh` (tracked)

**Core and cleanup excerpt** (lines 18-53, 67-75):
```bash
restore() {
  local restore_status=0
  ...
  (cd "${ROOT}" && MIX_ENV=test mix deps.get --check-locked) || restore_status=1
  (cd "${ROOT}" && MIX_ENV=test mix compile --force --warnings-as-errors) || restore_status=1
  ...
  return "${restore_status}"
}
finish() {
  local guard_status=$?
  local cleanup_status=0
  trap - EXIT INT TERM
  restore || cleanup_status=$?
  if ((cleanup_status != 0)); then
    echo "sigra-dep-off: FAIL: dependency cleanup failed" >&2
    exit 1
  fi
  exit "${guard_status}"
}
...
mix deps.unlock threadline || exit $?
...
mix test --only threadline_guard --no-deps-check
```

**Use:** follow its explicit trap/restore ownership and separate primary command result from cleanup status. For a general runner, preserve both stdout/stderr independently, record exit or signal before cleanup, and report cleanup/reporting errors as additional fields without replacing the first failure. Use argv arrays and shell-safe display strings; never evaluate report text or dump the environment.

### Browser invocation config and diagnostics

**Analogs:** `test/example/priv/playwright/playwright.config.ts` (tracked) and `.github/actions/example-playwright-boot/action.yml` (tracked)

**Relevant excerpt** (`playwright.config.ts`, lines 64-81, 100-105):
```typescript
const failureJsonlPath = process.env.SIGRA_PLAYWRIGHT_FAILURE_JSONL;
if (failureJsonlPath) {
  reporters.push([
    path.resolve(__dirname, 'lib/reporters/failure-jsonl.mjs'),
    { outputFile: failureJsonlPath },
  ]);
}
export default defineConfig({
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: reporters,
  use: {
    baseURL: process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
```

**Use:** scope trace-retention changes to the affected invocation boundary and any custom contexts. Keep retries zero. Existing invocation-specific reporter pattern is opt-in and path-configured. Test first-attempt assertion failure retention and passing-run disposal, plus output isolation across sequential runs. Ensure server and preparation use `CI=true` and the same `PORT`; use actual readiness checks and clean only invocation-owned process/database/temp paths.

**Pitfall:** a trace may contain DOM and authenticated requests. An auth-file exclusion alone does not make it safe to publish. Browser failure before context creation or hard runner termination can produce no trace; report that limitation directly.

### Workflow artifact and isolated canary

**Analogs:** `.github/workflows/ci.yml` (tracked) and `.github/workflows/release-receipt-canary.yml` (tracked)

**CI artifact excerpt** (`ci.yml`, lines 605-625):
```yaml
- name: Run contributor CI gate
  env:
    MIX_ENV: test
  run: mix ci
- name: Upload library test timing
  if: always()
  uses: actions/upload-artifact@... # pinned action
  with:
    name: library-test-timing-${{ github.run_id }}-${{ github.run_attempt }}
    path: |
      test-results/ci-exunit-timing-main.json
      test-results/ci-exunit-timing-threadline-guard.json
    retention-days: 7
    if-no-files-found: warn
```

**Canary excerpt** (`release-receipt-canary.yml`, lines 45-71):
```yaml
record-failure:
  needs: controlled-probe
  if: ${{ always() && inputs.scenario == 'failure' }}
  permissions:
    actions: read
    contents: read
...
- name: Upload unique canary failure receipt
  uses: actions/upload-artifact@... # pinned action
  with:
    name: release-canary-failure-${{ github.run_id }}-${{ github.run_attempt }}-${{ inputs.probe_id }}
    path: canary-receipt.json
    if-no-files-found: error
    retention-days: 30
```

**Use:** retain existing seven-day debugging artifact lifetime unless scope says otherwise, and name artifacts with run, attempt, job/seam, invocation and source identity. Stage an explicit allowlist. If terminal upload behavior changes, use a finite isolated non-publishing canary covering success, injected failure and actual fixture cancellation; do not treat local fixtures as proof of hosted trigger/upload/retrieval behavior. No publish credential.

### Safe staging, hashes, and identity checks

**Analog:** `scripts/ci/ci_metrics_security.py` (tracked)

**Relevant excerpts** (lines 753-781):
```python
def verified_failure_log(root, relative, expected_sha256):
    root = pathlib.Path(root).resolve()
    rel = pathlib.PurePosixPath(relative or "")
    if not relative or rel.is_absolute() or ".." in rel.parts:
        raise ValueError("failure_log_path_invalid")
    path = (root / pathlib.Path(*rel.parts)).resolve()
    if not path.is_relative_to(root) or not _matches(path, expected_sha256):
        raise ValueError("failure_log_hash_or_containment_invalid")
    return path.read_bytes()

def verified_zip_members(archive_path, expected_archive_sha256, member_hashes):
    ...
    if len(names) != len(set(names)):
        raise ValueError("duplicate_archive_member")
    ...
```

`sanitize_failure_log` follows immediately (lines 788+), bounds input/output, redacts token-like values and environment dumps.

**Use:** reuse containment/hash/archive validation for diagnostic bundles and replay receipt paths. Add explicit staged-file allowlists and symlink-root checks; test secret sentinels, auth storage, stale outputs and escaping symlinks. Preserve source SHA, run ID, attempt, job/seam and invocation identity on each retained record.

### Focused test style

**Analogs:** `scripts/ci/ci-browser-records.test.mjs` and `scripts/ci/ci-run-metrics-attempt.test.py` (tracked)

The Node test builds synthetic selection/native reports and invokes the CLI via `spawnSync`; the Python test creates isolated temporary fixtures and uses the real evaluator. Extend the nearest owner seam with real-process tests for:
- separate stdout/stderr and original exit/signal retained despite cleanup failure;
- actual Mix receiver execution and nonzero failure preservation;
- initial Playwright assertion trace retained, passing trace removed, and sequential output isolated;
- hostile bundle fixtures (sentinel, auth file, stale file, symlink escape);
- missing/corrupt replay input and changed dependency diagnostics.

Keep development checks local and deterministic; these do not authorize or renew hosted acceptance.

### Offline replay and final report

**Analogs:** `.planning/execution/254-environment-recovery/MEASUREMENT/run.py` (tracked), `scripts/ci/ci-run-metrics.sh` (tracked)

**Replay driver excerpt** (`run.py`, lines 19-33, 60-73):
```python
SCOPE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[4]
CONTRACT = SCOPE / 'CONTRACT.json'
METRICS = ROOT / 'scripts/ci/ci-run-metrics.sh'
...
def confined(relative):
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError('path_outside_repository')
    return path
...
if issues or contract.get('sample_identity') != 'run_id+run_attempt':
    raise ValueError(...)
```

**Result truth excerpt** (`ci-run-metrics.sh`, lines 2647-2662):
```python
def p95(xs):
    xs=sorted(xs); return xs[math.ceil(.95*len(xs))-1] if xs else None
...
performance_verdict='pass' if len(wait_before)==20 ... else ('miss' if len(wait_before)==20 else 'insufficient_data')
...
print(json.dumps({'status':verdict,'performance_verdict':performance_verdict,
                  'metrics':metrics,'diagnostics':issues},sort_keys=True))
```

**Use:** make the package accessible to a clean checkout using a durable scoped ref or exact-byte archive; local ignored paths and expiring Actions artifacts do not suffice. Verify all receipt hashes before offline calculation; pin calculator/helpers/data separately from measured app/workflow; snapshot input hashes before and after. The expected output is `insufficient_data`, zero successful comparable pairs, null median/p95, baseline failure (2046 runner-seconds), candidate success (1589 runner-seconds). Exit 0 is not a speed pass.

**Pitfalls:** don't require absent synthetic producer Git objects when preserved hash-verified producer payloads exist; don't overwrite Phase 252 archive/failed baseline manifest; don't infer speed from unequal failure/success observations. Later development CI is a separate result from the fixed comparison.

### Contributor guidance

**Analog:** `CONTRIBUTING.md` (tracked)

Existing local gate documentation at lines 20-51 spells out ordered `mix ci` legs, PostgreSQL and pinned `phx_new` prerequisites, and CI-only browser limits. Extend beside this material with focused reproduction commands, safe report retrieval, OS/browser caveats, and exact replay invocation. State coverage boundaries in plain terms.

## Shared Patterns

### Source identity and failure truth
Apply to every local record, CI artifact, replay bundle and final report: commit/source SHA, branch/ref, dirty state, tool versions, run/attempt/job/seam/invocation as relevant. Preserve the first command failure and report cleanup/capture failures separately. Do not claim a test ran from aggregate green status.

### Safe diagnostics and browser outputs
Use explicit staging allowlists, root containment checks, bounded/sanitized logs and SHA-256 receipts. Never include full env dumps, auth storage, stale output or untrusted arbitrary paths. Traces may contain sensitive page/network data.

### Replay/report contract
Replay immutable input bytes offline with pinned analysis helpers. Validate semantic fields, not just exit status. Report baseline failure, candidate success, zero matched successful pairs, null statistics and observed costs honestly; Phase 255 can prove replay of `insufficient_data` while the speed requirements remain open.

## No Analog Found

None. Exact names for new local recorder, report and distribution artifacts are left to the planner; closest role matches above identify their ownership boundaries.

## Metadata

**Analog search scope:** tracked `mix.exs`, `scripts/ci/`, `test/example/priv/playwright/`, `.github/actions/`, `.github/workflows/`, `CONTRIBUTING.md`, and Phase 254 measurement execution/evidence.
**Files scanned:** 12 primary analogs/tests/config files; every named existing analog was verified with `git ls-files`.
**Pattern extraction date:** 2026-10-24
