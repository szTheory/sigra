---
phase: 221
slug: unblock-the-gate-ship-honest-generated-host-debt
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 221 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `221-RESEARCH.md` § Validation Architecture. This is an ops/maintenance phase —
> most proofs are sub-30s and local; the terminal gate-green proof is CI/registry-side (operator-driven).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (library golden tests) + bash `*.test.sh` self-tests (CI guards) |
| **Config file** | `.github/workflows/ci.yml` (job wiring); `test/sigra/install/golden_diff_test.exs` (golden) |
| **Quick run command** | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` (golden drift; exit 2 on drift) |
| **Full suite command** | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` |
| **Estimated runtime** | golden `--check` ~seconds; golden suite ~1–2 min |

**Prerequisites (CLAUDE.md local-dev):** live Postgres (`scripts/db/up.sh` → `tmp/db.env`) + `phx_new 1.8.8` archive (`mix archive.install --force hex phx_new 1.8.8`). Re-bless with `MIX_ENV=test`.

---

## Sampling Rate

- **After every task commit:** the requirement's own command below (golden `--check`, the target grep, or the bash driver) — all sub-30s and local.
- **After every plan wave:** `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` + `bash scripts/ci/app-css-corruption-check.test.sh` + `bash scripts/uat/up.sh --help`.
- **Before `/gsd-verify-work`:** golden suite green + all bash drivers exit 0 + local smoke resolution snippet resolves to `1.3.0`.
- **Phase gate (operator-driven, non-local):** the publish/pin/retire sequence on `main`, then observe `upgrade_smoke`→success and `ci-gate`→green.
- **Max feedback latency:** ~120 s local; gate proof is external.

---

## Per-Task Verification Map

| Task ID | Req | Type | Automated Command | Local? | Status |
|---------|-----|------|-------------------|--------|--------|
| PUB-01 (compile) | PUB-01 | integration | reproduce `upgrade-smoke.sh:44-53` sed/grep/sort snippet → expect `1.3.0` (after publish+pin) | ✅ local after publish+pin | ⬜ pending |
| PUB-01 (gate green) | PUB-01 | integration | observe `upgrade_smoke`→success + `ci-gate`→green on a push-to-`main` run | ❌ CI/push only | ⬜ pending |
| PUB-02 (publish v1.2.0) | PUB-02 | registry | `curl -s https://hex.pm/api/packages/sigra` shows `1.2.0`; dry-run log clean first | ❌ operator-gated Hex write | ⬜ pending |
| PUB-03 (publish v1.3.0) | PUB-03 | registry | `curl -s https://hex.pm/api/packages/sigra` shows `1.3.0` | ❌ operator-gated Hex write | ⬜ pending |
| PUB-04 (retire 1.20.0) | PUB-04 | registry | API `latest_stable_version` == `1.3.0`; `1.20.0` shows `(retired)` | ❌ operator-gated Hex write-auth | ⬜ pending |
| SHIP-01 (scope + clause) | SHIP-01 | golden | `mix test test/sigra/install/golden_diff_test.exs` + `grep -n 'scope:\|impersonation_forbidden' test/fixtures/install_golden/tree/.../mfa_settings_live.ex` | ✅ local | ⬜ pending |
| SHIP-02a (delete copy) | SHIP-02 | golden | `grep -c 'Delete this passkey' <golden mfa_settings_live.ex>` → 1 (heading only) | ✅ local | ⬜ pending |
| SHIP-02b (up.sh --help) | SHIP-02 | smoke (bash) | `bash scripts/uat/up.sh --help \| grep -q -- '--print-env'` | ✅ local | ⬜ pending |
| SHIP-03 (guard reset) | SHIP-03 | unit (bash) | `bash scripts/ci/app-css-corruption-check.sh test/fixtures/css/orphan_after_terminated_decl.css` → exit 1; clean fixture → exit 0 | ✅ local (Wave 0 fixture) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/fixtures/css/orphan_after_terminated_decl.css` — regression fixture for SHIP-03 (orphan bare value after a `;`-terminated `:root` declaration). D-10.
- [ ] `scripts/ci/app-css-corruption-check.test.sh` — bash driver asserting exit 1 on the corrupt fixture and exit 0 on a clean one; wire into `ci.yml` alongside the existing `*.test.sh` self-tests (`ci.yml:139-152`), mirroring `settled-findings-lint.test.sh` / `stale-render-guard.test.sh`.
- [ ] No framework install needed — ExUnit + bash harness already present.

*Golden re-bless is not "new tests" — existing `golden_diff_test.exs` + `rebless_golden --check` cover SHIP-01/02a once the template edits land.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex publish v1.2.0 / v1.3.0 | PUB-02 / PUB-03 | Operator-gated: `hex-publish.yml workflow_dispatch` needs operator to trigger; publish is largely irreversible | `gh workflow run hex-publish.yml -f tag=vX -f release_version=X -f dry_run=true` (verify clean), then `dry_run=false`. Confirm via Hex API. |
| Retire stray `1.20.0` | PUB-04 | Needs an operator-minted Hex **write** key (interactive password); CI `HEX_API_KEY` is read-only | `mix hex.user key generate --permission api` then `mix hex.retire sigra 1.20.0 invalid --message "..."`; verify `latest_stable_version`==`1.3.0`. |
| `ci-gate` green on `main` | PUB-01 | Inherently CI/registry-side; `upgrade_smoke` is `skipped` on PRs, only runs on push | Push/dispatch on `main`; observe `upgrade_smoke`→success and `ci-gate` prints "passed: all required release lanes succeeded". |

---

## Validation Sign-Off

- [ ] Local SHIP proofs (golden grep, bash drivers) all automated and green
- [ ] Wave 0 CSS fixture + driver committed and wired into CI
- [ ] Publish/pin/retire tasks flagged `autonomous: false` operator checkpoints
- [ ] Gate-green proof documented as CI/push-only (not falsely claimed local)
- [ ] `nyquist_compliant: true` set once the above hold

**Approval:** pending
