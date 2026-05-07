# Phase 106: Replay verification closeout - Research

**Researched:** 2026-05-07 [VERIFIED: codebase grep]  
**Domain:** Verification/documentation closeout for webhook replay evidence and planning-truth reconciliation [VERIFIED: codebase grep]  
**Confidence:** HIGH [VERIFIED: codebase grep]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Closeout scope
- **D-106-01 — Phase 106 is a bounded verification closeout, not a broad planning-cleanup phase.** The main deliverable is `104-VERIFICATION.md`, written from the authoritative Phase 104 command history and replay proof bundle. [VERIFIED: codebase grep]
- **D-106-02 — Reconcile only the active truth set if it contradicts the new verification.** After `104-VERIFICATION.md` lands, update only the current planning surfaces that make present-tense claims about `WH-05`, such as `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and directly relevant current audit notes. [VERIFIED: codebase grep]
- **D-106-03 — Do not use Phase 106 for broad historical normalization.** Archived or non-authoritative artifacts should be left alone unless they still directly drive current milestone understanding. [VERIFIED: codebase grep]

### Authoritative truth policy
- **D-106-04 — `104-VERIFICATION.md` becomes the authoritative closeout artifact for `WH-05`.** Summary files and proof bundles remain important evidence inputs, but they are not sufficient on their own once the audit explicitly requires per-phase verification. [VERIFIED: codebase grep]
- **D-106-05 — Preserve implementation-vs-closeout honesty.** Planning artifacts should continue to make clear that `WH-05` was implemented in Phase 104 and verified/closed out in Phase 106. [VERIFIED: codebase grep]
- **D-106-06 — Keep the active truth set coherent after closeout.** `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and any live milestone audit note should not disagree about the present status of `WH-05`. [VERIFIED: codebase grep]

### Evidence freshness
- **D-106-07 — Default to lightweight refresh, not blind attestation and not automatic full rerun.** Phase 106 should verify the existing replay proof bundle and rerun a narrow CI-shaped smoke subset against current HEAD before writing `104-VERIFICATION.md`. [VERIFIED: codebase grep]
- **D-106-08 — Treat the 2026-05-07 replay proof bundle as immutable historical evidence.** Verify the presence and coherence of `.planning/uat-evidence/v1.23/webhook-delivery-replay/README.md`, `manifest.json`, and referenced screenshots instead of regenerating the bundle by default. [VERIFIED: codebase grep]
- **D-106-09 — Escalate to a full rerun only when the evidence may have gone stale.** If replay-relevant code, docs, templates, or proof inputs changed after the recorded proof run on 2026-05-07, or if artifact integrity cannot be confirmed, rerun the full replay verification lane before filing `104-VERIFICATION.md`. [VERIFIED: codebase grep]

### User preference carried forward
- **D-106-10 — Shift routine closeout decisions left within GSD by default.** Downstream planning should treat bounded reconciliation, lightweight refresh, and authoritative-verification-first as locked defaults unless a major contract, security, semver, or generated-host boundary would change. [VERIFIED: codebase grep]

### Claude's Discretion
- Exact command subset for the lightweight refresh, as long as it includes one current-head compile signal, one replay-focused smoke lane, and explicit proof-bundle integrity checks. [VERIFIED: codebase grep]
- Exact wording for superseding or clarifying any live milestone-audit note, provided it does not imply `WH-06` is complete. [VERIFIED: codebase grep]
- Exact formatting of `104-VERIFICATION.md`, provided it clearly separates historical proof evidence from any fresh closeout confirmation run during Phase 106. [VERIFIED: codebase grep]

### Deferred Ideas (OUT OF SCOPE)
- Broad historical normalization of archived milestone artifacts [VERIFIED: codebase grep]
- Full replay proof regeneration on every closeout by default [VERIFIED: codebase grep]
- Combining Phase 106 replay closeout with unrelated Phase 105 or Phase 107 planning hygiene [VERIFIED: codebase grep]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-05 | Maintainer or admin can manually replay a dead-lettered delivery from supported control surfaces while preserving truthful delivery history. [VERIFIED: codebase grep] | Use `104-VERIFICATION.md` as the authoritative requirement-closeout artifact, aggregate the executed Phase 104 command lanes, confirm current-head replay smoke still passes, and cite the durable replay proof bundle keyed by source/replay/root delivery IDs. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 106 should be planned as a repaired-form closeout, not as new webhook implementation work. The repo already treats per-phase `VERIFICATION.md` files as the milestone-authoritative proof surface, and the v1.23 audit names the missing `104-VERIFICATION.md` as the specific blocker keeping `WH-05` partial even though the summaries and replay bundle already exist. [VERIFIED: codebase grep]

The default execution path should be: verify the immutable replay proof bundle on disk, run a narrow current-head smoke lane that targets replay behavior directly, write `104-VERIFICATION.md` in the same style as `98/99/103-VERIFICATION.md`, then reconcile only the live truth files that still speak in the present tense about `WH-05`. `PROJECT.md` currently marks `WH-05` complete while `REQUIREMENTS.md`, `STATE.md`, and the audit still disagree, so active-truth reconciliation is mandatory after verification lands. [VERIFIED: codebase grep]

A full replay rerun should be treated as an escalation path, not the default. Current artifact-integrity checks pass, the narrowed replay/admin/worker smoke lane passes on current HEAD, and the example receiver-proof tests pass; however, broad replay-area files are dirty in the working tree and the wider integration test lane currently fails on hostname-resolution validation before replay-specific assertions run, so the plan needs an explicit freshness gate instead of assuming “all current tests green” or “historic proof is enough.” [VERIFIED: command output]

**Primary recommendation:** Plan Phase 106 around one authoritative `104-VERIFICATION.md`, one narrowed current-head refresh lane, one artifact-integrity lane, and one bounded reconciliation pass across `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the live v1.23 audit note only. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Authoritative replay closeout artifact (`104-VERIFICATION.md`) | API / Backend | Database / Storage | The closeout is derived from executable Mix/ExUnit/Playwright commands plus persisted proof artifacts on disk, not from browser-only observation. [VERIFIED: codebase grep] |
| Immutable replay proof bundle integrity | Database / Storage | API / Backend | The proof bundle lives under `.planning/uat-evidence/v1.23/webhook-delivery-replay/` and is validated by file-presence plus manifest/README content checks. [VERIFIED: codebase grep] |
| Lightweight freshness confirmation on current HEAD | API / Backend | Frontend Server (SSR) | The default refresh lane is dominated by Mix compile and replay/admin tests, with example-host controller proof as the optional host-boundary check. [VERIFIED: command output] |
| Escalated full replay rerun | Frontend Server (SSR) | API / Backend | The full rerun depends on the generated-host Playwright proof plus receiver-proof/controller tests, which exercise the admin surface end to end after backend replay logic. [VERIFIED: codebase grep] |
| Active planning truth reconciliation | API / Backend | Database / Storage | The planner should update only live planning files and audit notes that currently contradict the authoritative replay closeout. [VERIFIED: codebase grep] |

## Project Constraints (from CLAUDE.md)

- Start file-changing work through a GSD workflow entry point; direct repo edits outside GSD are discouraged unless the user explicitly bypasses the workflow. [CITED: CLAUDE.md]
- `mix test` assumes a live PostgreSQL instance on `localhost:5432` with `postgres/postgres`; local runs fail fast instead of silently skipping DB-dependent tests. [CITED: CLAUDE.md]
- The documented full-suite command is `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test`. [CITED: CLAUDE.md]
- No project-specific skills were found under the supported skill directories. [CITED: CLAUDE.md]

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | `1.19.5` on OTP `28` | Compile signal and test orchestration for the closeout smoke lane. [VERIFIED: mix --version] | Every authoritative verification precedent in this repo records a root `mix compile --warnings-as-errors` step. [VERIFIED: codebase grep] |
| ExUnit replay/admin tests | repo-local tests | Current-head replay behavior confirmation without rerunning the entire milestone. [VERIFIED: codebase grep] | `test/sigra/webhooks_replay_test.exs`, `test/sigra/workers/webhook_delivery_test.exs`, and `test/sigra/admin/webhooks_test.exs` form the narrowed green replay lane on current HEAD. [VERIFIED: command output] |
| Replay proof bundle | generated `2026-05-07T19:17:47.834Z` | Historical authoritative evidence for source/replay/root lineage and receiver verification. [VERIFIED: codebase grep] | The v1.23 audit explicitly cites this bundle as existing evidence and only blocks on missing `104-VERIFICATION.md`. [VERIFIED: codebase grep] |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Example receiver-proof tests | repo-local tests | Confirm the host-boundary verification helpers still pass on current HEAD. [VERIFIED: codebase grep] | Use in the default refresh lane if the planner wants one current-head signal from the receiver-proof path without rerunning Playwright. [VERIFIED: command output] |
| Playwright | CLI `1.59.1`; package manifest `@playwright/test` `^1.48.0` | Full rerun of the canonical fail -> inspect -> repair -> replay -> succeed browser proof. [VERIFIED: command output] | Use only when replay-relevant drift or artifact-integrity failure forces full proof regeneration. [VERIFIED: codebase grep] |
| `rg` | installed locally | Artifact-integrity and planning-truth grep checks. [VERIFIED: command output] | Use for proof-bundle field checks and reconciliation assertions in `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the audit. [VERIFIED: codebase grep] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Narrowed replay smoke + artifact checks | Full replay rerun every time | Stronger freshness but higher runtime and more flake surface than the bounded closeout policy allows. [VERIFIED: codebase grep] |
| Active-truth reconciliation only | Full historical artifact normalization | Broader cleanup but directly conflicts with the locked Phase 106 scope. [VERIFIED: codebase grep] |
| Authoritative `104-VERIFICATION.md` | Leaving `104-04-SUMMARY.md` as proof | Simpler, but the v1.23 audit already rejects summary-only closeout for `WH-05`. [VERIFIED: codebase grep] |

**Installation:**
```bash
# No new dependencies are required for Phase 106.
# Use the existing Mix, Postgres, and Playwright tooling already present in the repo.
```

**Version verification:** Tool versions were verified with `mix --version`, `node --version`, `npm --version`, `npx playwright --version`, `psql --version`, and `pg_isready`. [VERIFIED: command output]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 104 summaries + replay proof bundle
        |
        v
Phase 106 integrity gate
  - file presence
  - manifest/README field checks
        |
        +---- fail integrity or replay-relevant drift ----> full rerun lane
        |                                                   - example proof tests
        |                                                   - Playwright replay proof
        |
        v
lightweight refresh lane
  - mix compile --warnings-as-errors
  - replay/admin/worker smoke
  - optional receiver-proof tests
        |
        v
104-VERIFICATION.md
  - historical evidence section
  - current-head confirmation section
        |
        v
active-truth reconciliation
  - PROJECT.md
  - ROADMAP.md
  - REQUIREMENTS.md
  - STATE.md
  - v1.23 audit note
        |
        v
milestone re-audit can mark WH-05 satisfied
```

The decision point between lightweight refresh and full rerun is the core planning concern for this phase. [VERIFIED: codebase grep]

### Recommended Project Structure
```text
.planning/
├── phases/104-failed-delivery-replay-controls/
│   ├── 104-VERIFICATION.md      # new authoritative replay closeout artifact
│   ├── 104-04-SUMMARY.md        # executed command history input
│   └── 104-VALIDATION.md        # Nyquist contract already marked compliant
├── uat-evidence/v1.23/webhook-delivery-replay/
│   ├── README.md                # human-readable proof bundle
│   ├── manifest.json            # machine-readable lineage proof
│   └── screenshots/             # referenced image artifacts
├── PROJECT.md                   # active present-tense milestone truth
├── ROADMAP.md                   # phase and gap-closure truth
├── REQUIREMENTS.md              # requirement traceability truth
├── STATE.md                     # session continuity truth
└── v1.23-MILESTONE-AUDIT.md     # live audit blocker record
```

### Pattern 1: Repaired-Form Verification Artifact
**What:** Write `104-VERIFICATION.md` in the same shape as `98-VERIFICATION.md`, `99-VERIFICATION.md`, and `103-VERIFICATION.md`: phase goal, requirement table, explicit evidence commands, attestation, and residuals when needed. [VERIFIED: codebase grep]  
**When to use:** Always for this phase; the audit already says summary files alone are insufficient. [VERIFIED: codebase grep]  
**Example:**
```bash
# Source: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md
mix compile --warnings-as-errors
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test \
  mix test test/sigra/webhooks_replay_test.exs \
           test/sigra/workers/webhook_delivery_test.exs \
           test/sigra/admin/webhooks_test.exs --no-color
```

### Pattern 2: Freshness Gate Before Writing Verification
**What:** Decide between lightweight refresh and full rerun by checking artifact integrity first, then looking for replay-relevant drift in replay docs/tests/runtime files. [VERIFIED: codebase grep]  
**When to use:** Before drafting `104-VERIFICATION.md`. [VERIFIED: codebase grep]  
**Example:**
```bash
# Source: Phase 104 summary + replay proof bundle conventions
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json
rg -n '"source_delivery_id"|"replay_delivery_id"|"root_delivery_id"|"receiver_verification"|"screenshots"' \
  .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json
git diff --name-only -- \
  guides/flows/webhooks.md \
  guides/recipes/webhook-verification.md \
  lib/sigra/webhooks.ex \
  lib/sigra/workers/webhook_delivery.ex \
  lib/sigra/admin/webhooks/actions.ex \
  lib/sigra/admin/webhooks/detail.ex \
  lib/sigra/admin/webhooks/failures.ex \
  test/sigra/webhooks_replay_test.exs \
  test/sigra/admin/webhooks_test.exs \
  test/sigra/workers/webhook_delivery_test.exs \
  test/example/priv/playwright/tests/admin-generated.spec.ts
```

### Pattern 3: Bounded Active-Truth Reconciliation
**What:** Reconcile only the files that are still authoritative for the current milestone. [VERIFIED: codebase grep]  
**When to use:** Immediately after `104-VERIFICATION.md` is written. [VERIFIED: codebase grep]  
**Example:**
```bash
# Source: Phase 102 reconciliation summary pattern
rg -n 'WH-05|104-VERIFICATION|Phase 104|Phase 106|partial|Pending|complete' \
  .planning/PROJECT.md \
  .planning/ROADMAP.md \
  .planning/REQUIREMENTS.md \
  .planning/STATE.md \
  .planning/v1.23-MILESTONE-AUDIT.md
```

### Anti-Patterns to Avoid
- **Summary-only closeout:** The v1.23 audit already marks that as insufficient for `WH-05`. [VERIFIED: codebase grep]
- **Broad archive cleanup:** Phase 106 explicitly forbids turning this into historical normalization. [VERIFIED: codebase grep]
- **Full rerun by reflex:** Current artifact checks pass, the narrowed replay lane passes, and the example receiver-proof tests pass, so full rerun should stay conditional. [VERIFIED: command output]
- **Using the wide replay integration lane as the default smoke:** `test/sigra/webhooks_integration_test.exs` currently fails on hostname-resolution validation before replay-specific assertions, so it is a poor default freshness signal for this closeout phase. [VERIFIED: command output]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Authoritative replay proof | New ad hoc markdown narrative from memory | `104-VERIFICATION.md` derived from the four Phase 104 summaries plus the replay proof bundle | The repo’s milestone audits key off `VERIFICATION.md`, not informal summaries. [VERIFIED: codebase grep] |
| Evidence freshness decision | Vague “looks recent enough” judgment | Explicit integrity checks plus a narrowed replay smoke lane and diff-based escalation rule | This keeps closeout honest without forcing unnecessary reruns. [VERIFIED: codebase grep] |
| Historical cleanup | Repo-wide planning normalization | Active-truth-only reconciliation modeled on Phase 102 | The locked scope forbids archaeology beyond current authoritative truth. [VERIFIED: codebase grep] |
| Replay proof regeneration | Rebuilding screenshots/manifest by default | Reuse the immutable 2026-05-07 bundle unless the freshness gate fails | The bundle already contains the lineage and receiver-verification fields the audit cites. [VERIFIED: codebase grep] |

**Key insight:** The hard part of Phase 106 is not producing new proof, but preventing the planner from either under-shooting into summary-only bookkeeping or over-shooting into unnecessary replay repro work. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Treating `104-04-SUMMARY.md` as the final artifact
**What goes wrong:** The milestone re-audit still leaves `WH-05` partial because the authoritative per-phase verification file is missing. [VERIFIED: codebase grep]  
**Why it happens:** Phase 104 already has commands and a proof bundle, which makes the gap look cosmetic even though the audit marks it as blocking. [VERIFIED: codebase grep]  
**How to avoid:** Make `104-VERIFICATION.md` the first-class deliverable and cite the summary files only as inputs. [VERIFIED: codebase grep]  
**Warning signs:** Planning language says “copy summary into verification” without also updating traceability and audit truth. [VERIFIED: codebase grep]

### Pitfall 2: Picking the wrong current-head smoke lane
**What goes wrong:** The plan either runs too little and becomes blind attestation, or runs the broad integration lane and fails on unrelated hostname-resolution drift. [VERIFIED: command output]  
**Why it happens:** Replay code now overlaps with current endpoint-policy and URL-validation work, so some broader tests are noisy for a bounded closeout. [VERIFIED: command output]  
**How to avoid:** Default to `mix compile --warnings-as-errors` plus `webhooks_replay`, `workers/webhook_delivery`, and `admin/webhooks` tests, with example receiver-proof tests as the host-boundary supplement. [VERIFIED: command output]  
**Warning signs:** `test/sigra/webhooks_integration_test.exs` is used as the only freshness signal or the plan requires Playwright without first checking artifact integrity. [VERIFIED: command output]

### Pitfall 3: Reconciling too narrowly or too broadly
**What goes wrong:** Either active files keep contradicting each other, or the phase expands into archive-wide cleanup and slips scope. [VERIFIED: codebase grep]  
**Why it happens:** `PROJECT.md` already marks `WH-05` complete while `REQUIREMENTS.md`, `STATE.md`, and the live audit still disagree. [VERIFIED: codebase grep]  
**How to avoid:** Reconcile `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the live v1.23 audit note only; leave old milestone artifacts alone. [VERIFIED: codebase grep]  
**Warning signs:** The plan proposes editing archived `milestones/` files or ignores `PROJECT.md` because it “already looks green.” [VERIFIED: codebase grep]

### Pitfall 4: Accidentally implying `WH-06` is also closed
**What goes wrong:** A milestone re-audit or truth-file update overstates v1.23 completion and hides the still-open Phase 105 operator-truth gap. [VERIFIED: codebase grep]  
**Why it happens:** `WH-05` and `WH-06` live in the same audit and adjacent roadmap phases. [VERIFIED: codebase grep]  
**How to avoid:** Phrase all closeout updates as “Phase 104 implemented `WH-05`; Phase 106 authoritatively verified it” while leaving `WH-06` explicitly pending/unsatisfied. [VERIFIED: codebase grep]  
**Warning signs:** Any reconciliation text says “v1.23 complete” or removes the Phase 105 blocker from the audit. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from repo precedents:

### Lightweight Refresh Lane
```bash
# Source: current-head command verification on 2026-05-07
mix compile --warnings-as-errors
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test \
  mix test test/sigra/webhooks_replay_test.exs \
           test/sigra/workers/webhook_delivery_test.exs \
           test/sigra/admin/webhooks_test.exs --no-color
cd test/example && \
  CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= \
  PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test \
  mix test test/example_web/controllers/sigra_webhook_controller_test.exs \
           test/example_web/accounts_webhook_proof_test.exs --no-color
```

### Artifact Integrity Lane
```bash
# Source: Phase 104 plan/summary conventions + current proof bundle
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/subscription-detail.png
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/failed-source-row.png
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/source-delivery-detail.png
test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/replay-delivery-detail.png
rg -n '"source_delivery_id"|"replay_delivery_id"|"root_delivery_id"|"receiver_verification"|"screenshots"' \
  .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json
rg -n 'source delivery id|replay delivery id|root delivery id|receiver verification|Artifacts:' \
  .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md
```

### Escalation Lane
```bash
# Source: .planning/phases/104-failed-delivery-replay-controls/104-04-SUMMARY.md
cd test/example/priv/playwright && \
  EXAMPLE_DB_PROBE_ENABLED=1 \
  SIGRA_EXAMPLE_URL=http://localhost:4000 \
  CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= \
  npx playwright test tests/admin-generated.spec.ts --project=admin-generated
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Summary files and proof bundles as de facto closeout | `VERIFICATION.md` as the authoritative phase closeout artifact | Established by existing repaired-form verification precedents and enforced again by the v1.23 audit on 2026-05-07 | The planner must produce a real verification artifact, not a summary transplant. [VERIFIED: codebase grep] |
| Broad retrospective cleanup phases like Phase 26 | Bounded active-truth reconciliation like Phase 102 and Phase 106 | Bounded webhook closeout pattern visible by 2026-05-06 in Phase 102 | Current truth gets repaired without reopening archive archaeology. [VERIFIED: codebase grep] |
| Wide integration-only freshness signal | Targeted replay smoke plus artifact integrity, with full rerun only on drift | Supported by current-head command results on 2026-05-07 | The plan can stay fast and honest even while adjacent webhook work is in flight. [VERIFIED: command output] |

**Deprecated/outdated:**
- Summary-only `WH-05` closeout: rejected by `.planning/v1.23-MILESTONE-AUDIT.md`. [VERIFIED: codebase grep]
- Using `STATE.md`’s “Phase 105 next” text as the sole source of truth: it is already stale relative to the existence of Phase 106. [VERIFIED: codebase grep]

## Assumptions Log

All claims in this research were verified or cited in this session — no user confirmation needed. [VERIFIED: codebase grep]

## Open Questions

1. **Should the live v1.23 audit be edited in-place or only annotated as superseded for the `WH-05` portion?**
   - What we know: Phase 102 previously converted a live audit into a superseded historical gap record once closeout truth landed, and Phase 106 explicitly allows wording discretion for the current audit note. [VERIFIED: codebase grep]
   - What's unclear: Whether the planner should choose a partial supersession note for the `WH-05` section only or a broader audit refresh after both Phases 106 and 107 close. [VERIFIED: codebase grep]
   - Recommendation: Plan a minimal in-place clarification that `WH-05` is now authoritatively verified while `WH-06` remains unsatisfied, and avoid a full audit rewrite in Phase 106. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Mix / Elixir | compile + replay smoke | ✓ [VERIFIED: command output] | `Mix 1.19.5`, OTP `28` [VERIFIED: command output] | — |
| PostgreSQL | DB-backed ExUnit lanes | ✓ [VERIFIED: command output] | `psql 14.17`; `pg_isready` accepted on `localhost:5432` [VERIFIED: command output] | Existing local test DB only; no code-only fallback for DB tests. [CITED: CLAUDE.md] |
| Node / npm / npx | Playwright escalation lane | ✓ [VERIFIED: command output] | Node `v22.14.0`, npm `11.1.0`, npx `11.1.0` [VERIFIED: command output] | — |
| Playwright | full replay rerun | ✓ [VERIFIED: command output] | CLI `1.59.1` [VERIFIED: command output] | Skip unless freshness gate fails. [VERIFIED: codebase grep] |
| `gsd-sdk query` interface | optional workflow bookkeeping only | ✗ [VERIFIED: command output] | current installed `gsd-sdk` does not expose `query` subcommands [VERIFIED: command output] | Read planning files directly; this phase is not blocked by the missing interface. [VERIFIED: command output] |

**Missing dependencies with no fallback:**
- None for the default lightweight-refresh path. [VERIFIED: command output]

**Missing dependencies with fallback:**
- `gsd-sdk query` workflow helpers are unavailable, but direct file reads and normal shell commands fully cover this closeout phase. [VERIFIED: command output]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + example-host ExUnit + Playwright escalation lane. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs`, `config/test.exs`, `test/example/mix.exs`, `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase grep] |
| Quick run command | `mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs --no-color`. [VERIFIED: command output] |
| Full suite command | `mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs --no-color && cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/sigra_webhook_controller_test.exs test/example_web/accounts_webhook_proof_test.exs --no-color && cd /Users/jon/projects/sigra && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md && test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json`. [VERIFIED: command output] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WH-05 | Replay logic remains green on current HEAD in the library/admin seams most directly exercised by Phase 104. [VERIFIED: command output] | unit/integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_replay_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs --no-color` [VERIFIED: command output] | ✅ [VERIFIED: codebase grep] |
| WH-05 | Receiver-proof path still reflects the replay contract and proof helpers. [VERIFIED: command output] | integration | `cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/sigra_webhook_controller_test.exs test/example_web/accounts_webhook_proof_test.exs --no-color` [VERIFIED: command output] | ✅ [VERIFIED: codebase grep] |
| WH-05 | Historical proof bundle remains coherent and reviewer-auditable. [VERIFIED: command output] | artifact integrity | `test -f .../README.md && test -f .../manifest.json && rg -n '"source_delivery_id"|"replay_delivery_id"|"root_delivery_id"|"receiver_verification"|"screenshots"' .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json` [VERIFIED: command output] | ✅ [VERIFIED: codebase grep] |
| WH-05 | Full end-to-end replay proof can be regenerated if freshness gate fails. [VERIFIED: codebase grep] | browser/integration | `cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 SIGRA_EXAMPLE_URL=http://localhost:4000 CLOAK_KEY=... npx playwright test tests/admin-generated.spec.ts --project=admin-generated` [VERIFIED: codebase grep] | ✅ [VERIFIED: codebase grep] |

### Sampling Rate
- **Per task commit:** Run the quick run command after edits to `104-VERIFICATION.md` or truth files that cite replay verification. [VERIFIED: codebase grep]
- **Per wave merge:** Run the full suite command plus the README/manifest grep assertions. [VERIFIED: codebase grep]
- **Phase gate:** If replay-relevant files changed or artifact integrity fails, run the Playwright escalation lane before `/gsd-verify-work`. [VERIFIED: codebase grep]

### Wave 0 Gaps
- None — existing tests and proof-artifact checks cover the bounded closeout phase. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: codebase grep] | No auth model changes are planned in this closeout phase. [VERIFIED: codebase grep] |
| V3 Session Management | no [VERIFIED: codebase grep] | No session behavior changes are planned in this closeout phase. [VERIFIED: codebase grep] |
| V4 Access Control | no [VERIFIED: codebase grep] | The phase verifies existing replay/operator controls but does not change authorization rules. [VERIFIED: codebase grep] |
| V5 Input Validation | yes [VERIFIED: codebase grep] | Validate artifact presence, manifest fields, and truth-file wording through explicit shell checks before attesting completion. [VERIFIED: command output] |
| V6 Cryptography | no [VERIFIED: codebase grep] | The phase cites existing signature-verification proof rather than changing crypto behavior. [VERIFIED: codebase grep] |

### Known Threat Patterns for verification closeout work

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale evidence presented as current proof | Repudiation | Separate historical-evidence and current-head-refresh sections inside `104-VERIFICATION.md`, and gate the latter with fresh command output. [VERIFIED: codebase grep] |
| Proof bundle tampering or accidental omission | Tampering | Require file-presence checks plus manifest/README field greps before writing the closeout artifact. [VERIFIED: command output] |
| Overstating milestone completion and masking `WH-06` | Repudiation | Reconcile only `WH-05` truth and preserve explicit `WH-06` pending/unsatisfied language. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)
- `CLAUDE.md` — workflow constraints and local test prerequisites. [CITED: CLAUDE.md]
- `.planning/phases/106-replay-verification-closeout/106-CONTEXT.md` — locked scope, freshness policy, and reconciliation boundaries. [VERIFIED: codebase grep]
- `.planning/v1.23-MILESTONE-AUDIT.md` — exact `WH-05` blocker and summary-only insufficiency. [VERIFIED: codebase grep]
- `.planning/phases/104-failed-delivery-replay-controls/104-01-SUMMARY.md` through `104-04-SUMMARY.md` — executed command history for replay closeout inputs. [VERIFIED: codebase grep]
- `.planning/uat-evidence/v1.23/webhook-delivery-replay/README.md` and `manifest.json` — durable replay proof bundle contents. [VERIFIED: codebase grep]
- `.planning/phases/98-reliable-delivery-pipeline/98-VERIFICATION.md`, `.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md`, `.planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md` — authoritative verification artifact shape. [VERIFIED: codebase grep]
- Current shell verification on 2026-05-07 — compile success, narrowed replay lane success, example receiver-proof success, artifact-integrity success, and broad integration-lane failure details. [VERIFIED: command output]

### Secondary (MEDIUM confidence)
- None. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)
- None. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all recommended tools and commands were verified locally in this session. [VERIFIED: command output]
- Architecture: HIGH - the closeout shape is strongly constrained by existing phase context, verification precedents, and the v1.23 audit. [VERIFIED: codebase grep]
- Pitfalls: HIGH - each pitfall is backed either by the current audit state or by command results from the current workspace. [VERIFIED: command output]

**Research date:** 2026-05-07 [VERIFIED: codebase grep]  
**Valid until:** 2026-05-14 because adjacent webhook work is active and replay-area files are currently dirty. [VERIFIED: command output]
