# Requirements — v1.47 CI-EFFICIENCY

**Milestone goal:** Cut PR wall-clock from ~29.5m to under 12m and make every remaining gate honest — by *executing* the already-written SEED-005 audit rather than re-running it.

**Source of truth:** `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` (finished audit, prioritized Phase 198→203 sequence, re-verified accurate 2026-07-28). `.planning/seeds/SEED-005-*.md` holds the verbatim scope guardrails — they bind every requirement below.

**Measured baseline (last 40 runs, 2026-07-28):**

| trigger | n | mean | p50 | max | outcomes |
| --- | --- | --- | --- | --- | --- |
| pull_request | 21 | 29.5m | 27.3m | 41.7m | 17 pass / 4 fail |
| push (main) | 7 | 30.5m | 27.6m | 42.3m | 6 pass / 1 fail |
| schedule (nightly) | 9 | 27.3m | 27.1m | 29.4m | **0 pass / 9 fail** |

A PR burns ~56 runner-minutes for a 25.6m wall; a push ~92 for 35m.

---

## v1.47 Requirements

### Critical path (FAST)

- [ ] **FAST-01**: A contributor opening a PR gets a merge verdict in under 12 minutes at p50, measured over at least 10 runs after the change.
- [ ] **FAST-02**: Design-gallery snapshot boards no longer run on the PR gate; they run on push-to-main and nightly, and their accessibility assertions still run on every PR.
- [ ] **FAST-03**: `admin_eval_render` no longer runs on pull requests.
- [ ] **FAST-04**: Pushing a new commit to a PR branch cancels the superseded in-flight CI run instead of letting it complete; main and scheduled runs are never cancelled.
- [ ] **FAST-05**: A pull request that changes only documentation or `.planning/` files does not run the full job matrix, and its required checks still report a merge-eligible state rather than hanging pending.
- [ ] **FAST-06**: Playwright browser binaries are restored from cache rather than downloaded on every job.
- [ ] **FAST-07**: Every CI job carries an explicit `timeout-minutes`, so a hung job fails in bounded time instead of burning the 360-minute default.

### Gate honesty (GATE)

- [ ] **GATE-01**: The nightly scheduled run is green, or every remaining red lane is a filed, diagnosed defect with an owner.
- [ ] **GATE-02**: Generated-host parity is verified on a lane that actually executes; no required or aggregated lane can report pass solely because it was skipped by a stale condition.
- [ ] **GATE-03**: `ci-gate` distinguishes "skipped because correctly gated for this event" from "skipped because its gate rotted", and fails on the latter.
- [ ] **GATE-04**: `admin_eval_render` runs green on its new lane, and the harness guards downstream of its Playwright phase (`stale-render-guard.sh` and the fix-queue/anchor checks) demonstrably execute.
- [ ] **GATE-05**: A maintainer can see, from a single artifact, which specs run on PR vs main vs nightly before and after this milestone, proving no test was silently dropped.

### Playwright economics (PW)

- [ ] **PW-01**: The design-board specs authenticate once per project instead of registering a fresh user before every test.
- [ ] **PW-02**: Playwright specs can run in parallel without cross-spec database interference, so `workers: 1` is no longer required for correctness.
- [ ] **PW-03**: The example-app boot prelude is defined once and reused, rather than duplicated verbatim across jobs.

### Library suite economics (TEST)

- [ ] **TEST-01**: Slow-test visibility no longer forces the library suite to run serially.
- [ ] **TEST-02**: The two library shards finish within a comparable time of each other rather than one idling while the other works.
- [ ] **TEST-03**: The subprocess-heavy install tests no longer dominate library shard wall-clock, whether by sharing fixture setup or by moving to a non-PR lane with recorded justification.

### Hygiene and contributor DX (DX)

- [ ] **DX-01**: `mix ci` reproduces the PR gate, including formatting and dependency-lock checks.
- [ ] **DX-02**: Third-party GitHub Actions used in release-critical workflows are pinned to immutable SHAs.
- [ ] **DX-03**: Dependabot covers Hex and npm dependencies in addition to GitHub Actions.
- [ ] **DX-04**: Playwright spec files that no CI lane invokes are either wired into a lane or deleted.
- [ ] **DX-05**: The two filed release-lane defects are resolved — `gate-ci-green` no longer times out on a green release, and the `release-lane-rot` notifier raises an issue when a lane fails.
- [ ] **DX-06**: SEED-006 is verified against current CI and closed as delivered, or its residual work is filed.

---

## Traceability

| Requirement | Phase | Status |
| --- | --- | --- |
| _(filled by roadmap)_ | | |

---

## Future Requirements (deferred)

- Credo, Dialyzer and `mix_audit` as CI gates — each needs its own remediation plan before it can gate; a lib with thin specs would sit red for a long tail.
- Converting the `async: false` posture. `test/sigra/planning/phase_153_infra_stability_contract_test.exs` contract-locks 15 files to `async: false`; unpicking that is its own milestone.
- Larger or self-hosted runners. Solve the waste first — the current pipeline spends ~56 runner-minutes per PR, of which ~17 produce an unread red.
- A minimum-supported Elixir/OTP compatibility matrix.

## Out of Scope

- Re-running the SEED-005 audit playbook. Its output already exists and was re-verified accurate on 2026-07-28; re-deriving it would consume the milestone without adding information.
- Retiring the stray Hex `1.20.0`. Blocked by Hex 2.5's OAuth token scopes rather than by ownership (ADR 003); documented install lines are pinned `~> 1.4.0` as the zero-auth workaround.
- Deleting tests to make CI faster. SEED-005's guardrails permit demoting or removing only the lowest-signal, redundant or flaky checks, and only with evidence.
- Masking flake with retries or `continue-on-error`. `playwright.config.ts` records D-15 forbidding exactly that; retry is a quarantine tool, not a fix.
