# Phase 106: Replay verification closeout - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/phases/104-failed-delivery-replay-controls/104-VERIFICATION.md` | test | transform | `.planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md` | exact |
| `.planning/PROJECT.md` | config | transform | `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md` | role-match |
| `.planning/ROADMAP.md` | config | transform | `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md` | role-match |
| `.planning/REQUIREMENTS.md` | config | transform | `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md` | role-match |
| `.planning/STATE.md` | config | transform | `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md` | role-match |
| `.planning/v1.23-MILESTONE-AUDIT.md` | test | transform | `.planning/v1.22-MILESTONE-AUDIT.md` plus `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md` | exact |

## Pattern Assignments

### `.planning/phases/104-failed-delivery-replay-controls/104-VERIFICATION.md` (test, transform)

**Primary analog:** `.planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md`

**Frontmatter + section shape** ([103-VERIFICATION.md:1-18](/Users/jon/projects/sigra/.planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md:1)):
```md
---
phase: 103
verified: 2026-05-07T14:36:09Z
status: passed
score: 1/1 requirements verified
---

# Phase 103 — Verification

**Phase Goal:** Make webhook signing-secret rollover safe in production through explicit lifecycle state, overlap-window signing, truthful operator controls, and one end-to-end generated-host proof that preserves the public verification contract.

## Requirements
```

**Evidence block pattern with command/result pairing** ([103-VERIFICATION.md:18-31](/Users/jon/projects/sigra/.planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md:18)):
```md
## Evidence

- `mix compile --warnings-as-errors`
  Result: root Sigra compile passed after the Plan 04 receiver/proof changes.
- `cd test/example && mix compile --warnings-as-errors`
  Result: example host compile passed with the new proof helpers and controller changes.
- `cd test/example && CLOAK_KEY=... mix test ... --no-color`
  Result: `5 tests, 0 failures`.
- `cd test/example/priv/playwright && ... npx playwright test ...`
  Result: `6 passed`, including the canonical lifecycle proof.
- `test -f .planning/uat-evidence/v1.23/webhook-secret-rotation/README.md && test -f .planning/uat-evidence/v1.23/webhook-secret-rotation/manifest.json`
  Result: durable proof bundle exists on disk.
```

**Attestation + residuals pattern** ([103-VERIFICATION.md:33-47](/Users/jon/projects/sigra/.planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md:33)):
```md
## Attestation

Phase 103 is verified in its executed form:

1. ...
2. ...
3. ...
4. ...

## Residuals

- ...
- ...

**Status:** Complete — 2026-05-07
```

**Replay-specific command inputs to reuse** ([104-04-SUMMARY.md:59-68](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-04-SUMMARY.md:59), [104-VALIDATION.md:23-25](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-VALIDATION.md:23), [104-VALIDATION.md:62-64](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-VALIDATION.md:62)):
```md
- `mix compile --warnings-as-errors`
- `mix test test/sigra/workers/webhook_delivery_test.exs --no-color`
- `cd test/example && CLOAK_KEY=... PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/sigra_webhook_controller_test.exs test/example_web/accounts_webhook_proof_test.exs --no-color`
- `cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 SIGRA_EXAMPLE_URL=http://localhost:4000 CLOAK_KEY=... npx playwright test tests/admin-generated.spec.ts --project=admin-generated`
- `test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md`
- `test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json`
```

**Artifact-integrity field checks to carry into Evidence or Notes** ([104-VALIDATION.md:51-52](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-VALIDATION.md:51), [104-VALIDATION.md:64-64](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-VALIDATION.md:64)):
```md
rg -n '"source_delivery_id"|"replay_delivery_id"|"root_delivery_id"|"receiver_verification"|"screenshots"' .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json
rg -n "source delivery id|replay delivery id|root delivery id|receiver verification|screenshot" .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md
```

**Historical evidence fields to cite directly** ([README.md:11-33](/Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/README.md:11), [manifest.json:6-28](/Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json:6)):
```md
- source delivery id: aec010c1-3006-4e53-9bfe-7e0e302ee061
- replay delivery id: 105bf300-1110-498d-a985-5f103eca7f6d
- root delivery id: aec010c1-3006-4e53-9bfe-7e0e302ee061
- source delivery status: dead_lettered
- replay delivery status: delivered
```

Planner guidance: keep `104-VERIFICATION.md` in repaired-form. Separate the immutable 2026-05-07 proof bundle from any fresh Phase 106 smoke confirmation, matching the `103-VERIFICATION.md` evidence/result style.

---

### `.planning/PROJECT.md` (config, transform)

**Primary analog:** `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md`

**Truth-precedence rule already established in the live file** ([PROJECT.md:142-142](/Users/jon/projects/sigra/.planning/PROJECT.md:142)):
```md
**Backlog / hygiene:** ... **Planning precedence:** **`ROADMAP.md`** + phase **`*-VERIFICATION.md`** / **`*-VALIDATION.md`** over conflicting **`STATE.md`** notes.
```

**Active milestone scope block to preserve** ([PROJECT.md:129-176](/Users/jon/projects/sigra/.planning/PROJECT.md:129)):
```md
**Active next milestone:** **v1.23 Webhook operator trust & controls**

**Selected scope:**
- **WH-04** — overlap-safe signing-secret rotation with replay-safe rollover
- **WH-05** — operator replay of dead-lettered deliveries
- **WH-06** — enforceable outbound endpoint policy plus allowlisting and deployment-boundary guidance

### Active — v1.23 Webhook operator trust & controls

- [ ] **WH-04** ...
- [x] **WH-05** ...
- [ ] **WH-06** ...
```

**Reconciliation framing to mirror** ([102-VERIFICATION.md:12-19](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md:12)):
```md
**Phase Goal:** Convert the generated-host webhook story from partial proof to full adopter evidence, then reconcile the active planning truth surface so milestone closeout is honest and replayable.

| Planning truth is reconciled | Pass | `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, ... now tell one post-gap-closure story. |
```

Planner guidance: update only the v1.23 active milestone wording and `WH-05` completion language. Preserve the existing scope bullets and the explicit precedence rule. Do not broaden into archived milestone sections.

---

### `.planning/ROADMAP.md` (config, transform)

**Primary analog:** `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md`

**Phase block structure to preserve** ([ROADMAP.md:90-103](/Users/jon/projects/sigra/.planning/ROADMAP.md:90)):
```md
### Phase 106: Replay verification closeout

**Goal:** Close the replay-control evidence gap by turning Phase 104's recorded commands and proof bundle into authoritative milestone verification.

**Depends on:** Phases 98-104.

**Requirements:** WH-05.

**Gap Closure:** Closes the Phase 104 verification blocker from the v1.23 milestone audit.

**Success criteria:**
1. `104-VERIFICATION.md` exists ...
2. The phase evidence chain for replay controls is coherent ...
3. `WH-05` can be marked satisfied ...
```

**Verification grep pattern for roadmap reconciliation** ([102-03-SUMMARY.md:20-27](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md:20)):
```md
- `rg -n '^\- \[x\] \*\*Phase 102: Generated-host proof and planning reconciliation\*\*' .planning/ROADMAP.md`
```

Planner guidance: if ROADMAP changes at all, keep them bounded to the Phase 106/107 truth boundary and use grep-verifiable wording. Do not rewrite older phase narratives.

---

### `.planning/REQUIREMENTS.md` (config, transform)

**Primary analog:** `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md`

**Traceability table pattern to preserve** ([REQUIREMENTS.md:53-59](/Users/jon/projects/sigra/.planning/REQUIREMENTS.md:53)):
```md
## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WH-04 | Phase 103 | Pending |
| WH-05 | Phase 106 | Pending |
| WH-06 | Phase 107 | Pending |
```

**Verification grep pattern for requirement reconciliation** ([102-03-SUMMARY.md:25-27](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md:25)):
```md
- `rg -n '^\| WH-03 \| 99, 100, 101, 102 \| (Complete|Validated|Verified) \|' .planning/REQUIREMENTS.md`
```

Planner guidance: preserve the existing table shape and update only the `WH-05` row/status language needed to reflect authoritative verification. Keep `WH-06` explicitly pending.

---

### `.planning/STATE.md` (config, transform)

**Primary analog:** `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md`

**Status/frontmatter pattern to preserve** ([STATE.md:1-13](/Users/jon/projects/sigra/.planning/STATE.md:1)):
```yaml
---
milestone: v1.23
status: "v1.23 in progress 2026-05-07 — Phase 104 complete; ready to plan Phase 105"
last_updated: "2026-05-07T19:20:00Z"
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 4
  completed_plans: 4
  percent: 67
---
```

**Current-position block to update in place** ([STATE.md:30-36](/Users/jon/projects/sigra/.planning/STATE.md:30)):
```md
Milestone: **v1.23 — Webhook operator trust & controls**

Phase: **104 complete; Phase 105 next**
Plan: **Phase 105 — Webhook egress policy and deployment controls**
Status: Phase 104 shipped manual dead-letter replay, truthful replay lineage, and a generated-host fail -> repair -> replay proof bundle; the next open step is planning outbound policy controls.
```

**Verification grep pattern for continuity reconciliation** ([102-03-SUMMARY.md:25-27](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md:25)):
```md
- `rg -n '^status: ".*(phase 102|v1\.22).*(complete|verified|closeout|reconciled)' .planning/STATE.md`
```

Planner guidance: update status/next-step wording so it mentions Phase 106 closeout of Phase 104 evidence before Phase 105/107 follow-on work. Preserve the file’s handoff structure and do not turn `STATE.md` into a second roadmap.

---

### `.planning/v1.23-MILESTONE-AUDIT.md` (test, transform)

**Primary analogs:** `.planning/v1.22-MILESTONE-AUDIT.md` and `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md`

**Superseded-audit frontmatter pattern** ([v1.22-MILESTONE-AUDIT.md:1-5](/Users/jon/projects/sigra/.planning/v1.22-MILESTONE-AUDIT.md:1)):
```md
---
milestone: v1.22
audited: 2026-05-06T00:00:00-04:00
status: superseded
scores:
```

**Supersession note pattern** (`rg` hit at [v1.22-MILESTONE-AUDIT.md:74-75](/Users/jon/projects/sigra/.planning/v1.22-MILESTONE-AUDIT.md:74)):
```md
> Superseded by `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md` on 2026-05-06.
> This file remains the historical gap record captured before Phases 100, 101, and 102 closed the listed issues.
```

**Closeout language to mirror** ([102-VERIFICATION.md:10-19](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md:10)):
```md
Supersedes: .planning/v1.22-MILESTONE-AUDIT.md

| Planning truth is reconciled | Pass | ... The historical `gaps_found` audit is retained only as a superseded record. |
```

**Current blocker lines that should be narrowed, not deleted wholesale** ([v1.23-MILESTONE-AUDIT.md:68-72](/Users/jon/projects/sigra/.planning/v1.23-MILESTONE-AUDIT.md:68), [v1.23-MILESTONE-AUDIT.md:108-112](/Users/jon/projects/sigra/.planning/v1.23-MILESTONE-AUDIT.md:108)):
```md
| `WH-05` | `104` | partial | All four `104-0x-SUMMARY.md` files claim completion and include green verification commands plus a replay proof bundle, but `104-VERIFICATION.md` is missing. |

| `104` | `104-VERIFICATION.md` missing; `104-VALIDATION.md` says `nyquist_compliant: true`, `wave_0_complete: true` | blocker |
| `105` | `105-VERIFICATION.md` missing; `105-VALIDATION.md` says `nyquist_compliant: false`, `wave_0_complete: false` | blocker |
```

Planner guidance: copy the v1.22 supersession pattern only if Phase 106 truly converts the live audit from active blocker to historical record. If `WH-06` remains open, prefer a bounded edit that clears the Phase 104 / `WH-05` blocker while preserving the live `WH-06` findings.

## Shared Patterns

### Repaired-Form Verification Artifact
**Sources:** [103-VERIFICATION.md:1-47](/Users/jon/projects/sigra/.planning/phases/103-overlap-safe-webhook-secret-rotation/103-VERIFICATION.md:1), [98-VERIFICATION.md:1-35](/Users/jon/projects/sigra/.planning/phases/98-reliable-delivery-pipeline/98-VERIFICATION.md:1), [99-VERIFICATION.md:1-36](/Users/jon/projects/sigra/.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md:1)
**Apply to:** `104-VERIFICATION.md`
```md
---
phase: <number>
verified: <timestamp>
status: passed
score: <n>/<n> requirements verified
---

# Phase <n> — Verification
## Requirements
## Evidence
## Attestation
## Residuals   # include only if needed
**Status:** Complete — <date>
```

### Artifact-Integrity + Proof-Bundle Checks
**Sources:** [104-VALIDATION.md:51-52](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-VALIDATION.md:51), [104-VALIDATION.md:64-64](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-VALIDATION.md:64), [104-04-SUMMARY.md:63-68](/Users/jon/projects/sigra/.planning/phases/104-failed-delivery-replay-controls/104-04-SUMMARY.md:63)
**Apply to:** `104-VERIFICATION.md`, any Phase 106 plan summaries
```md
- `test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md`
- `test -f .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json`
- `rg -n '"source_delivery_id"|"replay_delivery_id"|"root_delivery_id"|"receiver_verification"|"screenshots"' .planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json`
- `rg -n "source delivery id|replay delivery id|root delivery id|receiver verification|screenshot" .planning/uat-evidence/v1.23/webhook-delivery-replay/README.md`
```

### Bounded Active-Truth Reconciliation
**Sources:** [102-03-SUMMARY.md:16-31](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md:16), [102-VERIFICATION.md:18-19](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md:18)
**Apply to:** `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, `v1.23-MILESTONE-AUDIT.md`
```md
- Reconciled `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` so ... no longer contradict each other.
- Converted `.planning/v1.22-MILESTONE-AUDIT.md` into a superseded historical gap record so it no longer competes with the closeout verdict.
- This reconciliation is intentionally bounded to the active ... truth set and the phase artifacts needed for honest closeout.
```

### Verification Commands For Reconciliation Assertions
**Sources:** [102-03-SUMMARY.md:22-27](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md:22), [102-VERIFICATION.md:29-30](/Users/jon/projects/sigra/.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md:29)
**Apply to:** Phase 106 summary/verification docs
```md
- `test -f .planning/phases/104-failed-delivery-replay-controls/104-VERIFICATION.md`
- `rg -n 'WH-05|104-VERIFICATION|Phase 106|verified|reconciled' .planning/PROJECT.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md .planning/v1.23-MILESTONE-AUDIT.md`
```

## No Analog Found

None. Every planned file has a usable closeout/reconciliation analog in the existing `.planning` corpus.

## Metadata

**Analog search scope:** `.planning/phases/98-*`, `.planning/phases/99-*`, `.planning/phases/102-*`, `.planning/phases/103-*`, `.planning/phases/104-*`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/v1.23-MILESTONE-AUDIT.md`, `.planning/uat-evidence/v1.23/webhook-delivery-replay/`
**Files scanned:** 14
**Pattern extraction date:** 2026-05-07
