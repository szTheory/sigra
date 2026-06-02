# Phase 34: Generated-Host E2E Coverage and Phase 28 Retroactive Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `34-CONTEXT.md`.

**Date:** 2026-04-17
**Phase:** 34 — Generated-Host E2E Coverage and Phase 28 Retroactive Verification
**Mode:** User selected **all** gray areas and requested one-shot research-backed recommendations (four parallel subagents), then synthesis into `34-CONTEXT.md`.

---

## Gray area 1 — `28-VERIFICATION.md` shape and evidence bar

| Approach | Description | Role here |
|----------|-------------|-----------|
| Example-only evidence | Dense `test/example` + ExUnit / Playwright | Primary lane for Phase 28 feature truth |
| Generated-host only | Fresh install + smoke | Required for installer/runtime claims only |
| Hybrid lanes | Tag each row `(library)` / `(test/example)` / `(generated host)` | **Selected** — matches Phase 30/32 audit style |

**User's choice:** Hybrid + mirror `30/32` skeleton + bind to ROADMAP five criteria + honest SKIP/human for CI-only execution.

**Notes:** Django-admin / Devise lessons: falsifiable URL/state claims beat adjective-heavy prose; avoid screenshot-as-SOT; disconfirmation pass prevents false confidence.

---

## Gray area 2 — `admin-generated.spec.ts` depth

| Approach | Description | Role here |
|----------|-------------|-----------|
| Strict status only | Exact HTTP codes everywhere | Rejected as sole strategy — brittle on auth transport |
| Semantic / outcome | Roles, CSV headers, banner signals | **Selected** alongside strict security invariants |
| Duplicate example suite | Copy full admin-user-ops matrix | **Rejected** — violates Phase 31 D-03/D-05 |

**User's choice:** Extend generated-host spec minimally; strict where security matters; allowed small sets only where documented; reuse fixtures; CSV shape not byte snapshot.

**Notes:** Playwright upstream guidance: `getByRole`, web-first assertions, traces on failure; testing pyramid keeps most weight in ExUnit.

---

## Gray area 3 — Bash smoke vs Playwright

| Layer | Responsibility |
|-------|----------------|
| Bash (pre-Playwright) | Scaffold, boot, `gen_expect_non_5xx`, unknown-org, POST non-5xx mount check |
| Playwright | Cookies, CSRF, sudo, authenticated impersonation, export download semantics |

**User's choice:** Never skip bash probes for feature `--test` slices; duplicate only **orthogonal** assertions; ROADMAP names **`audit-export`** and **`impersonation-controller`** (optional `impersonation` alias for CLI ergonomics only); `all` = bash + full Playwright file.

**Notes:** Heroku-style fail-fast cheap checks + Rails request-vs-system split inform the division; avoid `curl -f` on intentional 4xx/302 probes.

---

## Gray area 4 — CI / `generated_admin_playwright_smoke`

| Topic | Decision |
|-------|----------|
| Job topology | Single job, `--test all`, extend script ordering |
| Timeouts | Add `timeout-minutes`; Playwright retries via env/config |
| Phase 35 gate | Fast separate job — do not merge into smoke |
| Artifacts | Keep existing two-tier upload policy |

**User's choice:** Minimal workflow diff (timeout + optional retries env); reproduction stays `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test …`.

---

## Claude's Discretion

Subagent synthesis delegated minor wiring choices (grep vs tag for Playwright slices, exact retry integers after first CI samples) to implementation phase — see `34-CONTEXT.md` Claude's Discretion.

## Deferred Ideas

- Parallel smoke jobs without shared generated-app artifact reuse.
- Screenshot baselines for generated host — Phase 35.
