# Phase 88: GAUAT closing cluster — backup-code rotation + clean-machine getting-started + results filing & SEED-001 closure - Research

**Researched:** 2026-04-28  
**Domain:** GA evidence-pack design, human-verification sequencing, and launch-truth filing for SEED-001 [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md; .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]  
**Confidence:** HIGH [VERIFIED: repository sources and local command checks only; no unresolved library/API ambiguity]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Backup-code evidence shape
- **D-88-01:** `GAUAT-07` uses a hybrid evidence pack, but transcript/query truth is primary. Screenshots prove the human flow happened; persisted-state and audit proofs carry the security claim.
- **D-88-02:** The evidence directory must contain `README.md`, `transcript.log`, an explicit old-code-reuse failure artifact, an explicit audit proof artifact for `mfa.backup_codes_regenerate`, and a `screenshots/` folder with only the key user-visible checkpoints.
- **D-88-03:** The screenshot set stays minimal: sudo prompt reached, regenerate modal with TOTP input, success/new-codes-shown-once, and audit UI row visible if the UI is used as the human-facing confirmation surface.
- **D-88-04:** Do not treat screenshots as proof that old codes were invalidated. The proof must show a pre-regen code failing after regen or an equivalent query-backed verification.
- **D-88-05:** Do not over-expose raw backup codes. One tightly scoped “shown once” capture is enough; prefer redaction/cropping anywhere else.

### Clean-machine run standard
- **D-88-06:** `GAUAT-08` uses a hybrid standard: keep `scripts/ci/getting-started-contract.sh` as the mechanical floor, then add one bounded human fresh-run on a fresh Phoenix 1.8 app.
- **D-88-07:** The operator may know Phoenix, Mix, and normal Elixir tooling, but should be new to Sigra specifically. “Unfamiliar developer” does not mean novice; it means no prior Sigra-specific tribal knowledge.
- **D-88-08:** A “clean machine” means a fresh temporary Phoenix host app with the published prerequisites already installed. It does not require a theatrical pristine VM beyond the documented prereqs.
- **D-88-09:** Record `start`, `first server boot`, `first successful register/login/reset cycle`, and `end`. Treat “under 30 minutes” as a target attestation, not a brittle cliff gate.
- **D-88-10:** Evidence for `GAUAT-08` must include a timestamped transcript, exact host/prereq versions, and a short friction log. Off-script source spelunking or maintainer hints count as friction and must be written down.

### Go/no-go and seed-closure policy
- **D-88-11:** `validated` requires every `GAUAT-01..08` row to be explicitly closed with remote-verifiable CI evidence or dated human evidence on the exact release-candidate SHA. Local-only green is never enough for launch truth.
- **D-88-12:** `partially-validated` is allowed only for pre-declared non-launch-critical laggards, with an explicit `reopen_trigger` naming the row, the missing proof, and what claim remains off-limits until closure.
- **D-88-13:** There must be no silent pending rows in `.planning/v1.20-GA-UAT-RESULTS.md`. Every row is `PASS`, `FAIL`, or `BLOCKED`.
- **D-88-14:** The current Phase 87 caveat is load-bearing: as of 2026-04-28, `GAUAT-03..06` are only local-pass until the SHA `367a164` GitHub Actions provenance exists and the evidence READMEs are regenerated with populated `ci_run_url`.

### Results-file structure
- **D-88-15:** `.planning/v1.20-GA-UAT-RESULTS.md` is a compact signoff index, not a second workflow spec and not a clone of `.planning/v1.4-GA-UAT.md`.
- **D-88-16:** The file structure is:
  `# Sigra v1.20 GA UAT Results`
  `## Release anchors`
  `## Scope and source-of-truth`
  `## GAUAT results`
  `## Launch-leg disposition`
  `## Follow-ups / reopen triggers` when needed.
- **D-88-17:** The `GAUAT results` table columns are: `Requirement | Outcome | Evidence | Residual / exception | Launch impact`.
- **D-88-18:** Keep outcome vocabulary to `PASS`, `FAIL`, `BLOCKED`. Evidence links should stay within two clicks of the underlying proof bundle.

### Downstream planning preference
- **D-88-19:** Downstream agents should shift decision burden left by default for this phase: synthesize a coherent recommended approach and only surface user choices when they are genuinely high-impact. Honor the repo’s existing `workflow.discuss_comprehensive_research` and `workflow.discuss_synthesize_when_user_delegates` posture.

### Claude's Discretion
- Exact filenames for the backup-code audit/query artifacts (`audit-query.txt` vs `audit-row.json`) as long as the proof is explicit and reviewer-friendly.
- Whether the `GAUAT-08` transcript is pure shell output or wrapped with a small README summary, as long as timestamps, versions, and friction are easy to inspect.
- Whether `.planning/v1.20-GA-UAT-RESULTS.md` includes one or two evidence links per row, as long as it remains concise and within the two-click rule.

### Deferred Ideas (OUT OF SCOPE)
- Fully automated end-to-end backup-code regeneration with DB/audit proof in Playwright would be a future tightening step, but it is not required to close Phase 88.
- A heavier onboarding-study artifact (full recording, third-party operator, repeated runs) is a later DX research lane, not v1.20 launch scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GAUAT-07 | Backup-code regeneration human verification [VERIFIED: .planning/REQUIREMENTS.md] | Use transcript-first witness pack with explicit old-code invalidation proof and `mfa.backup_codes_regenerate` audit proof; do not treat screenshots as the security claim [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; lib/sigra/mfa.ex; test/example/test/example_web/smoke/backup_code_rotation_test.exs] |
| GAUAT-08 | Clean-machine getting-started timed run [VERIFIED: .planning/REQUIREMENTS.md] | Run the mechanical contract first, then a fresh Phoenix-host walkthrough with timestamped transcript, versions, and friction log; record milestone timings instead of only pass/fail [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; guides/introduction/getting-started.md; scripts/ci/getting-started-contract.sh] |
| GAUAT-09 | Results filing + seed closure [VERIFIED: .planning/REQUIREMENTS.md] | Final results filing is a compact signoff index that consumes Phases 86-87 evidence plus the new Phase 88 human bundles, and it must represent GAUAT-03..06 as `BLOCKED` until Phase 87 remote CI provenance exists [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md; docs/uat-ci-coverage.md] |
</phase_requirements>

## Summary

Phase 88 is not a product-code phase first; it is an evidence-integrity phase that closes the last two human witness lanes and then files a launch-truth index consumed directly by Phase 89 launch messaging. [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md; .planning/PROJECT.md] The codebase already contains the mechanical and semantic proof surfaces for MFA rotation and getting-started integrity, so the planning focus should be on evidence-pack design, ordering, and truth gating rather than new library behavior. [VERIFIED: lib/sigra/mfa.ex; test/example/test/example_web/smoke/backup_code_rotation_test.exs; test/sigra/mfa_audit_atomicity_test.exs; guides/introduction/getting-started.md; scripts/ci/getting-started-contract.sh]

The execution should split cleanly into two parallel evidence slices and one sequential signoff slice. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md] Slice A captures `mfa-backup-rotation` with minimal screenshots plus transcript, old-code invalidation proof, and audit proof; Slice B captures `getting-started-clean-machine` with timestamps, exact environment versions, and friction notes; Slice C updates `.planning/v1.20-GA-UAT-RESULTS.md`, `SEED-001`, the v1.20 evidence index, and `88-VERIFICATION.md` only after those bundles exist and after Phase 87 provenance status is represented honestly. [VERIFIED: .planning/uat-evidence/v1.20/INDEX.md; .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md; .planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md]

The load-bearing planning truth is that Phase 87 is still `local_pass_pending_ci_provenance` on 2026-04-28, with SHA `367a164` lacking published GitHub Actions run URLs and the four OAuth evidence READMEs still carrying blank `ci_run_url` frontmatter. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md; .planning/uat-evidence/v1.20/oauth-google/README.md; .planning/uat-evidence/v1.20/INDEX.md] Phase 88 therefore must not file `GAUAT-03..06` as `PASS` in the launch-results document until that provenance exists; the honest default is `BLOCKED`, which also blocks a `validated` SEED-001 close and a launch-leg `go` disposition. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; .planning/REQUIREMENTS.md]

**Primary recommendation:** Plan Phase 88 as three commits: `A) GAUAT-07 evidence bundle`, `B) GAUAT-08 evidence bundle`, `C) results filing + SEED-001/88-VERIFICATION`, with commit C hard-gated on honest representation of Phase 87 provenance. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md]

## Project Constraints (from CLAUDE.md)

- Local test execution assumes a live Postgres on `localhost:5432` with `postgres/postgres`; missing DB should fail fast rather than silently skip coverage. [VERIFIED: CLAUDE.md]
- Sigra’s blessed path is Phoenix 1.8+ with Ecto, and security-critical auth behavior belongs in the library while host-app code stays generated and visible. [VERIFIED: CLAUDE.md]
- Testing expectations are comprehensive happy-path, error-path, and boundary-path coverage in flat, self-contained AAA style. [VERIFIED: CLAUDE.md]
- Repo edits should stay inside GSD workflow artifacts rather than ad-hoc changes outside planning/execution flow. [VERIFIED: CLAUDE.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| GAUAT-07 human witness flow (`sudo` -> TOTP -> regenerated codes shown once) | Browser / Client | API / Backend | The operator experiences the flow in `MfaSettingsLive`, but the security claim depends on `Auth.mfa_regenerate_backup_codes/3` delegating to `Sigra.MFA.regenerate_backup_codes/4`. [VERIFIED: test/example/lib/example_web/live/mfa_settings_live.ex; test/example/lib/example/accounts.ex; lib/sigra/mfa.ex] |
| GAUAT-07 invalidation and audit proof | API / Backend | Database / Storage | Old-code invalidation and `mfa.backup_codes_regenerate` are enforced and persisted server-side, then inspected via audit/state artifacts. [VERIFIED: lib/sigra/mfa.ex; test/example/test/example_web/smoke/backup_code_rotation_test.exs; test/example/lib/example/accounts/audit_event.ex] |
| GAUAT-08 getting-started walkthrough | Frontend Server (SSR) | Browser / Client | The walkthrough exercises generated Phoenix routes, mailbox preview, and auth pages from a fresh host app, with the browser only observing whether the generated server path works. [VERIFIED: guides/introduction/getting-started.md; scripts/ci/getting-started-contract.sh] |
| GAUAT-09 results filing and seed closure | CDN / Static | Browser / Client | The output is a static planning artifact set (`.planning/*.md`) consumed by launch messaging and future reviewers rather than a runtime code path. [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Mix` + `ExUnit` | `Elixir 1.19.5` / OTP 28 in the local research environment [VERIFIED: local command `elixir --version`] | Preflight the two mechanical surfaces before human evidence capture. | Existing Phase 88-relevant checks already live here: `backup_code_rotation_test.exs` proves old-code invalidation semantics, and `mfa_audit_atomicity_test.exs` proves audit co-fate semantics. [VERIFIED: test/example/test/example_web/smoke/backup_code_rotation_test.exs; test/sigra/mfa_audit_atomicity_test.exs] |
| Existing evidence-bundle schema (`README.md` + `manifest.json`) | Current repo shape only; no new dependency [VERIFIED: .planning/uat-evidence/v1.20/INDEX.md; .planning/uat-evidence/v1.20/email-phase-04/README.md; .planning/uat-evidence/v1.20/oauth-google/README.md] | Keep v1.20 evidence directories consistent and reviewer-friendly. | Phase 86 and 87 already established the v1.20 README/frontmatter pattern, so Phase 88 should extend the same index rather than inventing a different bundle shape. [VERIFIED: .planning/uat-evidence/v1.20/INDEX.md] |
| `scripts/ci/getting-started-contract.sh` | Current repo script; no external package [VERIFIED: scripts/ci/getting-started-contract.sh] | Mechanical floor for GAUAT-08 before a human timed run starts. | The script already validates internal guide links and required commands, and it passes locally today. [VERIFIED: scripts/ci/getting-started-contract.sh; local command `bash scripts/ci/getting-started-contract.sh`] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PostgreSQL | `14.17` locally available; repo docs also offer a disposable `postgres:16-alpine` container [VERIFIED: local command `psql --version`; CLAUDE.md] | Backing store for example-app auth/audit verification during GAUAT-07 and GAUAT-08. | Use for all preflight and witness runs that exercise the example app or a fresh host app. [VERIFIED: CLAUDE.md; scripts/uat/RUNBOOK.md] |
| Node.js / npm | `v22.14.0` / `11.1.0` locally available [VERIFIED: local command `node --version`; local command `npm --version`] | Only needed if Phase 87 provenance reruns require Playwright/evidence regeneration while Phase 88 is in flight. | Use when regenerating OAuth evidence after CI provenance appears; not required for the new human bundles themselves. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-authored human evidence bundles for GAUAT-07/08 | Extend `mix sigra.uat.report` to support `mfa-backup-rotation` and `getting-started-clean-machine` | The current mix task explicitly supports only `04`, `08`, `oauth-gen`, `oauth-google`, `oauth-link`, and `oauth-email-match`, so extending it in Phase 88 adds code churn to solve a one-off documentation problem. [VERIFIED: lib/mix/tasks/sigra.uat.report.ex] |
| Immediate results filing after local human runs | Wait to file anything until Phase 87 provenance arrives | Waiting keeps truth simpler, but it delays two independent human witness bundles that can be captured now and linked later. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md; .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md] |

**Installation:**
```bash
# No new packages are required for Phase 88 itself.
# Use the repo's existing Elixir/Postgres environment and the current evidence tooling.
```

## Architecture Patterns

### System Architecture Diagram

```text
GAUAT-07 operator
  -> Browser / MfaSettingsLive
  -> Example.Accounts.mfa_regenerate_backup_codes/3
  -> Sigra.MFA.regenerate_backup_codes/4
  -> Repo transaction (replace codes + sync credential + audit row)
  -> Evidence bundle: transcript + screenshots + invalidation proof + audit proof

GAUAT-08 operator
  -> Preflight: scripts/ci/getting-started-contract.sh
  -> Fresh Phoenix 1.8 host app + getting-started.md
  -> Browser + mailbox preview + generated auth flows
  -> Evidence bundle: transcript + env versions + friction log + timings

Phase 86/87 evidence bundles + new Phase 88 bundles
  -> .planning/v1.20-GA-UAT-RESULTS.md
  -> SEED-001 status update
  -> 88-VERIFICATION.md
  -> Phase 89 launch messaging gate
```

The sequential boundary is the results-filing slice; the two human witness bundles can be captured independently before the final launch-truth file is written. [VERIFIED: .planning/ROADMAP.md; .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]

### Recommended Project Structure
```text
.planning/
├── uat-evidence/v1.20/
│   ├── mfa-backup-rotation/
│   │   ├── README.md
│   │   ├── transcript.log
│   │   ├── reports/
│   │   └── screenshots/
│   └── getting-started-clean-machine/
│       ├── README.md
│       ├── transcript.log
│       ├── env.txt
│       └── friction-log.md
├── v1.20-GA-UAT-RESULTS.md
└── seeds/SEED-001-v1.0-ga-human-uat-gate.md

.planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/
└── 88-VERIFICATION.md
```

### Pattern 1: Transcript-First Human Evidence
**What:** Human witness packs should lead with timestamped transcript and explicit proof artifacts, with screenshots limited to the UI checkpoints that text cannot prove. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]  
**When to use:** Use for both Phase 88 witness activities, especially when the security claim is persisted-state or audit behavior rather than visual layout. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]  
**Example:**
```bash
# Source: .planning/phases/88.../88-CONTEXT.md D-88-01..10 + scripts/ci/getting-started-contract.sh
date -u +"START %Y-%m-%dT%H:%M:%SZ" | tee transcript.log
bash scripts/ci/getting-started-contract.sh | tee -a transcript.log
date -u +"END %Y-%m-%dT%H:%M:%SZ" | tee -a transcript.log
```

### Pattern 2: Human Run Behind Machine Preflight
**What:** Run the smallest existing automated contract before spending human time, then use the human run only for the residual proof CI cannot supply. [VERIFIED: docs/uat-ci-coverage.md; test/example/test/example_web/smoke/backup_code_rotation_test.exs; scripts/ci/getting-started-contract.sh]  
**When to use:** Before GAUAT-07, run the example-app smoke test and MFA audit test; before GAUAT-08, run the guide contract script. [VERIFIED: local command `MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs --no-color`; local command `bash scripts/ci/getting-started-contract.sh`]  
**Example:**
```bash
# Source: test/example/test/example_web/smoke/backup_code_rotation_test.exs + test/sigra/mfa_audit_atomicity_test.exs
MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs --no-color
cd test/example
CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' \
  MIX_ENV=test mix test test/example_web/smoke/backup_code_rotation_test.exs \
  --include example_app --no-color
```

### Pattern 3: Signoff Index, Not Duplicate Workflow Spec
**What:** `.planning/v1.20-GA-UAT-RESULTS.md` should only record release anchors, one row per GAUAT item, launch disposition, and reopen triggers. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]  
**When to use:** Always for GAUAT-09; details stay in evidence bundle READMEs and `docs/uat-ci-coverage.md`. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; docs/uat-ci-coverage.md]  
**Example:**
```markdown
| Requirement | Outcome | Evidence | Residual / exception | Launch impact |
|-------------|---------|----------|----------------------|---------------|
| GAUAT-03 | BLOCKED | `.planning/uat-evidence/v1.20/oauth-gen/README.md` | Local PASS at `367a164`; remote `ci_run_url` missing | blocks launch truth |
```

### Anti-Patterns to Avoid
- **Screenshot-only backup-code proof:** Old-code invalidation is a backend semantic guarantee, not a visual claim. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; test/example/test/example_web/smoke/backup_code_rotation_test.exs]
- **Warm-machine “clean-machine” run:** Reusing a hand-tuned app or relying on maintainer hints destroys the only residual signal GAUAT-08 is supposed to capture. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]
- **Filing PASS from local-only OAuth evidence:** Phase 87 explicitly remains local-only until run URLs exist and READMEs are regenerated. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md]

## Recommended Plan Slices / Commit Boundaries

### Slice A — GAUAT-07 `mfa-backup-rotation` evidence pack
**Commit goal:** Capture the human witness flow and its backend proof set without touching launch-truth docs yet. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]  
**Files to touch:**
- `.planning/uat-evidence/v1.20/mfa-backup-rotation/README.md` [VERIFIED: recommended from D-88-02 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/mfa-backup-rotation/transcript.log` [VERIFIED: D-88-02 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/mfa-backup-rotation/reports/*` for invalidation and audit proof [VERIFIED: D-88-02 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/mfa-backup-rotation/screenshots/*` [VERIFIED: D-88-03 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/INDEX.md` to add the new bundle row [VERIFIED: .planning/uat-evidence/v1.20/INDEX.md]
**Recommended verification:**
- `MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs --no-color` [VERIFIED: local command pass]
- `cd test/example && CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' MIX_ENV=test mix test test/example_web/smoke/backup_code_rotation_test.exs --include example_app --no-color` [VERIFIED: local command pass]
- Human witness: exact `MfaSettingsLive` flow at `/users/settings/mfa`, then query or inspect the latest `mfa.backup_codes_regenerate` audit row and prove a pre-regen plaintext backup code now fails. [VERIFIED: test/example/lib/example_web/live/mfa_settings_live.ex; lib/sigra/mfa.ex; test/example/test/example_web/smoke/backup_code_rotation_test.exs]

### Slice B — GAUAT-08 `getting-started-clean-machine` evidence pack
**Commit goal:** Capture the fresh-host walkthrough and any guide friction, again without filing final signoff yet. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]  
**Files to touch:**
- `.planning/uat-evidence/v1.20/getting-started-clean-machine/README.md` [VERIFIED: recommended from D-88-10 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/getting-started-clean-machine/transcript.log` [VERIFIED: D-88-10 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/getting-started-clean-machine/env.txt` with tool versions [VERIFIED: D-88-10 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/getting-started-clean-machine/friction-log.md` [VERIFIED: D-88-10 in 88-CONTEXT.md]
- `.planning/uat-evidence/v1.20/INDEX.md` to add the new bundle row [VERIFIED: .planning/uat-evidence/v1.20/INDEX.md]
**Recommended verification:**
- `bash scripts/ci/getting-started-contract.sh` [VERIFIED: scripts/ci/getting-started-contract.sh; local command pass]
- Record `start`, `first server boot`, `first successful register/login/reset cycle`, and `end` exactly as required by D-88-09. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]
- Run on a fresh Phoenix 1.8 host app with documented prerequisites, not on the mutable `test/example` app. [VERIFIED: guides/introduction/getting-started.md; .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]

### Slice C — GAUAT-09 results filing + seed closure + phase verification
**Commit goal:** Update the milestone signoff surfaces only after both human bundles exist and Phase 87 provenance is represented honestly. [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md]  
**Files to touch:**
- `.planning/v1.20-GA-UAT-RESULTS.md` [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/uat-evidence/v1.20/INDEX.md` final index refresh [VERIFIED: .planning/uat-evidence/v1.20/INDEX.md]
- `.planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-VERIFICATION.md` [VERIFIED: .planning/ROADMAP.md]
**Recommended verification:**
- `mix sigra.uat.report --phase=04 --check`
- `mix sigra.uat.report --phase=08 --check`
- `mix sigra.uat.report --phase=oauth-gen --check`
- `mix sigra.uat.report --phase=oauth-google --check`
- `mix sigra.uat.report --phase=oauth-link --check`
- `mix sigra.uat.report --phase=oauth-email-match --check` [VERIFIED: lib/mix/tasks/sigra.uat.report.ex]
- Grep that `.planning/v1.20-GA-UAT-RESULTS.md` has one explicit row for `GAUAT-01` through `GAUAT-08` and no `Pending` wording. [VERIFIED: .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]

## Evidence-Bundle Contents

### `mfa-backup-rotation`
- `README.md` summarizing operator, exact SHA, exact example-app route, and the four proof classes. [VERIFIED: D-88-02 in .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]
- `transcript.log` with timestamped steps and the exact pre-regen plaintext backup code label chosen for later invalidation proof. [VERIFIED: D-88-01..04 in 88-CONTEXT.md]
- `reports/old-code-reuse.txt` or `.json` proving the previously captured plaintext code now returns invalid after rotation. [VERIFIED: D-88-04 in 88-CONTEXT.md; test/example/test/example_web/smoke/backup_code_rotation_test.exs]
- `reports/audit-row.txt` or `.json` showing the latest `mfa.backup_codes_regenerate` event and its metadata. [VERIFIED: D-88-02 in 88-CONTEXT.md; lib/sigra/mfa.ex; test/example/lib/example/accounts/audit_event.ex]
- `screenshots/01-sudo.png`, `02-regenerate-modal.png`, `03-new-codes-shown-once.png`, `04-audit-ui-row.png` with redaction/cropping so raw codes are not re-exposed beyond the single allowed “shown once” capture. [VERIFIED: D-88-03..05 in 88-CONTEXT.md]

### `getting-started-clean-machine`
- `README.md` summarizing host OS, toolchain versions, app name used, elapsed time, and whether the target stayed under 30 minutes. [VERIFIED: D-88-08..10 in 88-CONTEXT.md; guides/introduction/getting-started.md]
- `transcript.log` with `start`, `first server boot`, `first successful register/login/reset cycle`, and `end`. [VERIFIED: D-88-09 in 88-CONTEXT.md]
- `env.txt` with `elixir --version`, `mix --version`, `node --version` if applicable, `psql --version`, and the Phoenix archive/version chosen for the fresh host. [VERIFIED: D-88-10 in 88-CONTEXT.md]
- `friction-log.md` listing any off-script source spelunking, maintainer hints, doc ambiguity, or stalls; “no friction” only if literally none occurred. [VERIFIED: D-88-10 in 88-CONTEXT.md]

## Truth Policy for `.planning/v1.20-GA-UAT-RESULTS.md`

Use `PASS` only when the row’s evidence is either remote-verifiable CI evidence or dated human evidence captured on the exact release-candidate SHA. [VERIFIED: D-88-11 in .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md] For 2026-04-28, GAUAT-01 and GAUAT-02 can be `PASS` from Phase 86 evidence, GAUAT-07 and GAUAT-08 can become `PASS` once their new human bundles exist, and GAUAT-03..06 must remain `BLOCKED` until Phase 87’s SHA `367a164` has published GitHub Actions provenance and regenerated README frontmatter with populated `ci_run_url`. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md; .planning/uat-evidence/v1.20/email-phase-04/README.md; .planning/uat-evidence/v1.20/oauth-google/README.md]

Recommended row wording for GAUAT-03..06 while provenance is pending: `Outcome = BLOCKED`, `Evidence = local bundle README + 87-VERIFICATION.md`, `Residual / exception = local PASS at 367a164; remote CI provenance missing`, `Launch impact = blocks launch truth`. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md] Do not translate those rows to `PASS` or `FAIL`; the missing condition is publication/provenance, not behavior regression or behavior success. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md]

Recommended disposition policy: if any of GAUAT-03..06 remain `BLOCKED`, the launch-leg disposition in Phase 88 should be `NO-GO` or explicitly `GO BLOCKED BY PROVENANCE`, and `SEED-001` should not be marked `validated`. [VERIFIED: D-88-11..14 in .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md] Only move `SEED-001` to `partially-validated` if maintainers explicitly decide that Phase 87 provenance lag is a pre-declared non-launch-critical exception and provide a `reopen_trigger` naming the missing CI URLs and README regeneration; no such exception exists in the current repo state. [VERIFIED: D-88-12 in .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md; .planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MFA rotation proof | Screenshot gallery as the primary claim | Existing smoke test semantics + transcript + explicit invalidation proof + audit-row proof | The security statement is “old plaintext no longer verifies and an audit row exists,” which is already modeled in code/tests and not visually inspectable. [VERIFIED: test/example/test/example_web/smoke/backup_code_rotation_test.exs; lib/sigra/mfa.ex] |
| Getting-started integrity | Ad-hoc human spot check with no preflight | `scripts/ci/getting-started-contract.sh` followed by the timed human run | The script already catches the mechanical failures that humans are bad at spotting consistently. [VERIFIED: scripts/ci/getting-started-contract.sh; local command `bash scripts/ci/getting-started-contract.sh`] |
| Launch results matrix | A second giant workflow spec | Compact signoff index that links to bundle READMEs and `docs/uat-ci-coverage.md` | The repo already distinguishes machine-coverage policy from milestone outcomes; duplicating both invites drift. [VERIFIED: docs/uat-ci-coverage.md; .planning/v1.12-UAT-EVIDENCE.md; .planning/phases/59-uat-ga-narrative-alignment/59-CONTEXT.md] |
| OAuth truth while CI URL is missing | Local-only `PASS` wording | `BLOCKED` row with explicit provenance exception | Phase 87’s own verification record says local closure is incomplete without remote run URLs and regenerated evidence frontmatter. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md] |

**Key insight:** Phase 88 closes a trust surface, not just a checklist; evidence integrity matters more than squeezing all row outcomes into green wording on the first pass. [VERIFIED: .planning/PROJECT.md; .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Filing OAuth rows as `PASS` from local bundles
**What goes wrong:** `.planning/v1.20-GA-UAT-RESULTS.md` over-claims closure for GAUAT-03..06 before Phase 87’s GitHub Actions run URLs exist. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md]  
**Why it happens:** The bundles and manifests are already on disk, which makes them look complete unless the blank `ci_run_url` frontmatter and Phase 87 status note are checked. [VERIFIED: .planning/uat-evidence/v1.20/oauth-google/README.md; .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md]  
**How to avoid:** Treat the final results-filing commit as gated on provenance truth, not just bundle presence. [VERIFIED: D-88-14 in 88-CONTEXT.md]  
**Warning signs:** `ci_run_url:` blank in OAuth READMEs, `status: local_pass_pending_ci_provenance` in `87-VERIFICATION.md`. [VERIFIED: .planning/uat-evidence/v1.20/oauth-google/README.md; .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md]

### Pitfall 2: Using the wrong ExUnit entrypoint for backup-code preflight
**What goes wrong:** The example-app smoke test appears broken because it is invoked from the repo root or without `--include example_app`. [VERIFIED: local command failure from repo root; local command exclusion from `test/example`]  
**Why it happens:** The smoke file lives under `test/example`, uses `Example.DataCase`, and is tag-gated. [VERIFIED: test/example/test/example_web/smoke/backup_code_rotation_test.exs]  
**How to avoid:** Run the smoke preflight from `test/example` with `--include example_app`. [VERIFIED: local command pass in `test/example`]  
**Warning signs:** `module Example.DataCase is not loaded` or `All tests have been excluded`. [VERIFIED: local command outputs from research session]

### Pitfall 3: Calling a warmed-up app “clean machine”
**What goes wrong:** GAUAT-08 records a fast, smooth walkthrough that silently benefited from prior Sigra knowledge or a pre-customized app. [VERIFIED: D-88-07..10 in 88-CONTEXT.md]  
**Why it happens:** The residual value of GAUAT-08 is friction discovery, and that disappears if the operator shortcuts the guide. [VERIFIED: .planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md; 88-CONTEXT.md]  
**How to avoid:** Record environment versions, timings, and every maintainer hint or source lookup as friction. [VERIFIED: D-88-09..10 in 88-CONTEXT.md]  
**Warning signs:** Missing `env.txt`, no timing milestones, or a transcript that starts after the host app is already created. [VERIFIED: D-88-09..10 in 88-CONTEXT.md]

## Code Examples

Verified patterns from repository sources:

### Backup-Code Rotation Preflight
```bash
# Source: test/example/test/example_web/smoke/backup_code_rotation_test.exs
cd test/example
CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' \
  MIX_ENV=test mix test test/example_web/smoke/backup_code_rotation_test.exs \
  --include example_app --no-color
```

### Getting-Started Mechanical Contract
```bash
# Source: scripts/ci/getting-started-contract.sh
bash scripts/ci/getting-started-contract.sh
```

### Audit-Row Probe for GAUAT-07
```bash
# Source: test/example/lib/example/accounts/audit_event.ex + lib/sigra/mfa.ex
cd test/example
MIX_ENV=dev mix run -e '
  import Ecto.Query
  alias Example.Repo
  alias Example.Accounts.AuditEvent

  AuditEvent
  |> where([a], a.action == "mfa.backup_codes_regenerate")
  |> order_by([a], desc: a.inserted_at)
  |> limit(1)
  |> Repo.one()
  |> IO.inspect(limit: :infinity)
'
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| One-off human GA matrix with waivers (`v1.4`) | Shift-left CI evidence for GAUAT-01..06 plus bounded human witness for GAUAT-07..08 | Phases 86 and 87 in v1.20 [VERIFIED: .planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md; .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-CONTEXT.md] | Phase 88 should consolidate evidence, not recreate Phase 86/87 workflows. [VERIFIED: 88-CONTEXT.md] |
| Outcome files duplicating workflow details | Compact outcome index + coverage policy separation | Phase 59 and v1.12 evidence posture [VERIFIED: .planning/phases/59-uat-ga-narrative-alignment/59-CONTEXT.md; .planning/v1.12-UAT-EVIDENCE.md; docs/uat-ci-coverage.md] | The final results doc should stay short and link outward. [VERIFIED: 88-CONTEXT.md] |

**Deprecated/outdated:**
- Treating local-only OAuth bundles as launch-ready evidence is outdated as of the 2026-04-28 Phase 87 verification state. [VERIFIED: .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md]

## Assumptions Log

All substantive claims in this research were verified against repo files or local command output during this session. [VERIFIED: repository sources and local command checks]

## Resolved Questions

1. **If Phase 87 provenance is still missing when Phase 88 executes, should SEED-001 stay open or move to `partially-validated`?**
   - Resolution: SEED-001 stays open/unvalidated by default. It may move to `partially-validated` only if maintainers have already pre-declared the affected Phase 87 rows as non-launch-critical and provide the explicit `reopen_trigger` required by D-88-12. No such exception exists in the current repo state, so unresolved Phase 87 provenance blocks closure by default. [VERIFIED: D-88-11..14 in 88-CONTEXT.md; .planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md; .planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md]
   - Planning consequence: Slice C must file `GAUAT-03..06` as `BLOCKED`, keep the launch leg blocked, and leave SEED-001 open/unvalidated unless the executor first closes the Phase 87 provenance gap or a maintainer-approved D-88-12 exception is added before execution. [VERIFIED: D-88-12..14 in 88-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | `mix test`, `mix run`, evidence authoring | ✓ [VERIFIED: local command `elixir --version`] | `1.19.5` [VERIFIED: local command `elixir --version`] | — |
| Mix / OTP | All Elixir commands | ✓ [VERIFIED: local command `elixir --version`] | OTP `28` [VERIFIED: local command `elixir --version`] | — |
| PostgreSQL | Example app and fresh-host walkthrough | ✓ [VERIFIED: local command `pg_isready -h localhost -p 5432 -U postgres`] | `14.17` local client [VERIFIED: local command `psql --version`] | Disposable `postgres:16-alpine` container documented in `CLAUDE.md` [VERIFIED: CLAUDE.md] |
| Node.js / npm | Only if Phase 87 evidence needs rerun with Playwright provenance | ✓ [VERIFIED: local command `node --version`; local command `npm --version`] | `v22.14.0` / `11.1.0` [VERIFIED: local command outputs] | Not needed for new Phase 88 human bundles [VERIFIED: 87-VERIFICATION.md] |
| Docker | Optional Postgres bootstrap or fresh-host convenience | ✓ [VERIFIED: local command `docker --version`] | `29.4.0` [VERIFIED: local command `docker --version`] | Existing local Postgres already accepts connections [VERIFIED: local command `pg_isready -h localhost -p 5432 -U postgres`] |

**Missing dependencies with no fallback:**
- None found during research. [VERIFIED: local environment commands]

**Missing dependencies with fallback:**
- None found during research. [VERIFIED: local environment commands]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit under `mix test` [VERIFIED: test/sigra/mfa_audit_atomicity_test.exs; test/example/test/example_web/smoke/backup_code_rotation_test.exs] |
| Config file | `mix.exs`-driven project config; no separate `pytest`/`jest`-style config governs these phase checks [VERIFIED: repo structure and command usage] |
| Quick run command | `bash scripts/ci/getting-started-contract.sh` or `MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs --no-color` [VERIFIED: scripts/ci/getting-started-contract.sh; local command pass] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GAUAT-07 | Old backup code invalidates after regeneration; audit semantics stay atomic | integration + smoke | `cd test/example && CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' MIX_ENV=test mix test test/example_web/smoke/backup_code_rotation_test.exs --include example_app --no-color` and `MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs --no-color` | ✅ [VERIFIED: files and local command passes] |
| GAUAT-08 | Guide still contains intact links/required commands | contract | `bash scripts/ci/getting-started-contract.sh` | ✅ [VERIFIED: script file and local command pass] |
| GAUAT-09 | Existing machine bundles still validate before filing final results | artifact integrity | `mix sigra.uat.report --phase=04 --check` etc. for all existing machine bundles | ✅ [VERIFIED: lib/mix/tasks/sigra.uat.report.ex] |

### Sampling Rate
- **Per task commit:** Run the slice-local preflight before capturing evidence. [VERIFIED: recommended from local command passes and 88-CONTEXT.md]
- **Per wave merge:** Re-run the slice-local preflight and validate evidence links in `.planning/uat-evidence/v1.20/INDEX.md`. [VERIFIED: .planning/uat-evidence/v1.20/INDEX.md]
- **Phase gate:** Slice C should not claim launch-ready truth until all eight GAUAT rows are explicit and Phase 87 provenance is honest. [VERIFIED: D-88-11..14 in 88-CONTEXT.md]

### Wave 0 Gaps
- [ ] There is no existing `mix sigra.uat.report` phase for `GAUAT-07`, `GAUAT-08`, or `GAUAT-09`; Phase 88 should hand-author those human bundles unless maintainers intentionally decide to extend the task. [VERIFIED: lib/mix/tasks/sigra.uat.report.ex]
- [ ] There is no existing Phase 88 verification artifact yet; Slice C must create `88-VERIFICATION.md`. [VERIFIED: phase directory listing]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: GAUAT-07 exercises authenticated MFA settings] | Use the real `MfaSettingsLive` + `Auth.mfa_regenerate_backup_codes/3` flow, not a mocked shortcut. [VERIFIED: test/example/lib/example_web/live/mfa_settings_live.ex; test/example/lib/example/accounts.ex] |
| V3 Session Management | yes [VERIFIED: getting-started walkthrough includes login/logout/reset cycle] | Verify session creation and logout through the generated host app walkthrough. [VERIFIED: guides/introduction/getting-started.md] |
| V4 Access Control | yes [VERIFIED: sensitive operations are sudo-gated and impersonation-blocked in the MFA settings flow] | Keep the human witness on the real sudo-gated surface and preserve impersonation protections. [VERIFIED: test/example/lib/example_web/live/mfa_settings_live.ex; test/example/lib/example/accounts.ex] |
| V5 Input Validation | yes [VERIFIED: TOTP and backup-code flows depend on server validation] | Rely on existing library validation paths and smoke tests rather than ad-hoc manual interpretation. [VERIFIED: lib/sigra/mfa.ex; test/example/test/example_web/smoke/backup_code_rotation_test.exs] |
| V6 Cryptography | yes [VERIFIED: backup codes are hashed and TOTP secrets are verified server-side] | Use library-owned regeneration semantics and avoid storing raw codes outside the one allowed “shown once” capture. [VERIFIED: lib/sigra/mfa.ex; 88-CONTEXT.md] |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Backup-code leakage in screenshots or notes | Information Disclosure | Redact/crop all but the single tightly-scoped “shown once” capture and avoid repeating raw codes in prose. [VERIFIED: D-88-05 in 88-CONTEXT.md] |
| False launch signoff from incomplete provenance | Tampering | Mark GAUAT-03..06 `BLOCKED` until `ci_run_url` is populated and remote runs exist. [VERIFIED: 87-VERIFICATION.md; 88-CONTEXT.md] |
| Human walkthrough contaminated by tribal knowledge | Repudiation | Record every off-script hint/source lookup in `friction-log.md` and preserve timestamps. [VERIFIED: D-88-10 in 88-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-CONTEXT.md` - locked decisions, evidence shape, truth policy
- `.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md` - current provenance caveat and exact blocked condition
- `.planning/ROADMAP.md` - phase goal, dependency shape, success criteria
- `.planning/REQUIREMENTS.md` - GAUAT-07..09 requirement wording
- `.planning/uat-evidence/v1.20/INDEX.md` and existing `README.md` files - v1.20 evidence schema and current CI-provenance gap
- `docs/uat-ci-coverage.md` - machine-vs-human policy surface
- `guides/introduction/getting-started.md` and `scripts/ci/getting-started-contract.sh` - GAUAT-08 subject and preflight contract
- `lib/sigra/mfa.ex`, `test/example/lib/example/accounts.ex`, `test/example/lib/example_web/live/mfa_settings_live.ex`, `test/example/lib/example/accounts/audit_event.ex` - authoritative MFA runtime touchpoints
- `test/example/test/example_web/smoke/backup_code_rotation_test.exs` and `test/sigra/mfa_audit_atomicity_test.exs` - existing proof surfaces for invalidation and audit atomicity
- Local commands run during research - environment availability and preflight pass/fail behavior

### Secondary (MEDIUM confidence)
- `CLAUDE.md` - project constraints and local test prerequisites
- `scripts/uat/RUNBOOK.md` - historical runbook pattern and example-app environment conventions
- `.planning/v1.12-UAT-EVIDENCE.md` and `.planning/v1.4-GA-UAT.md` - prior outcome-index shape and contrast

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependency selection is required; all recommended tools are already in-repo or locally verified. [VERIFIED: repo files and local commands]
- Architecture: HIGH - sequencing and touchpoints are explicitly defined in current phase context and current evidence surfaces. [VERIFIED: 88-CONTEXT.md; 87-VERIFICATION.md; code files]
- Pitfalls: HIGH - the major failure modes are already visible in the repo state, especially the Phase 87 provenance gap and the app-local test invocation requirements. [VERIFIED: 87-VERIFICATION.md; local command outputs]

**Research date:** 2026-04-28  
**Valid until:** 2026-05-28 for planning posture, or sooner if Phase 87 provenance state changes. [VERIFIED: 87-VERIFICATION.md]
