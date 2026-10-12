# Phase 250 gap-planning source and edge audit

Captured from the six `gaps:` entries in `250-VERIFICATION.md`. Plans 250-01 through 250-05 and their summaries remain historical; only 250-06 through 250-12 are selected by `--gaps-only`. Current state is 8/14 truths and 5/9 requirements with 31 blockers. These plans require authentic owner passes and a strict 9/9 audit for completion. A missing source or declined execution-time authority interrupts the dependent plan with durable diagnostics; it is never an alternate successful outcome.

Before revision, all nine dirty planning paths were preserved with exact path/status/bytes under `refs/gsd/preservation/phase-250-gap-planning-pre-revision1-20261010T184304Z` at commit `15c1afd319f7d59012cd9173195e0833b8135c77`. The manifest is `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-GAP-PLANNING-PRESERVATION-MANIFEST.json` in that ref; read-back and source hash/status recheck passed. Original clean capture HEAD was `792218bd6b21281f44d4207e45a4e55958cc847b` on `phase-244-playwright-measurement`.

## Four-source coverage

| Source | ID or item | Planned resolution | Status |
|---|---|---|---|
| GOAL | Reconcile Phase 247–249 verification, prove hosted terminal receipt pair, close strict 9/9 audit | 08–09, 06–07, 10–12 | COVERED |
| REQ | READY-01 exact candidate, package and dry-run | 08–09 | COVERED |
| REQ | READY-02 fresh PR/inherited-work disposition and clean source | 08–09 | COVERED |
| REQ | AUTO-01 protected environment/exact-source gate | 07, 11 | COVERED |
| REQ | AUTO-02 source-bound success/failure/cancellation receipts | 06–07, 11 | COVERED |
| REQ | REL-01 public 1.6.0 package/docs/source | 10, 11–12 | COVERED |
| REQ | REL-02 complete current-main CI, receipt, clean inventory, PR dispositions | 10–12 | COVERED |
| RESEARCH | Shared sanitized receipt builder and trusted default-branch observer | 06–07 | COVERED |
| RESEARCH | No-publish, on-demand canary; exact dispatch/cancel and artifact retrieval | 06–07 | COVERED |
| RESEARCH | Immutable candidate approval, exact CI/dry-run and complete population join | 08–09 | COVERED |
| RESEARCH | Distinct package and main SHA; accepted historical loss | 10, 12 | COVERED |
| RESEARCH | Source snapshot order: owner reports before summary/requirements, strict audit last | 07, 09–12 | COVERED |
| RESEARCH | ASVS L1 least privilege, no credential values, API budget and single CI watcher | 06–07, 10 | COVERED |
| RESEARCH | Local fixtures plus hosted proof; Mix wrapper validation remains honest | 06–07, 11–12 | COVERED |
| CONTEXT | D-01 fresh exact-identity owner snapshots | 07, 09–10, 12 | COVERED |
| CONTEXT | D-02 reconciled approved READY tuple | 08–09 | COVERED |
| CONTEXT | D-03 Phase 248 environment and both hosted outcomes | 07 | COVERED |
| CONTEXT | D-04 Phase 249 public/current proof and accepted loss | 10, 12 | COVERED |
| CONTEXT | D-05 isolated no-publish canary | 06–07 | COVERED |
| CONTEXT | D-06 shared receipt builder, exact cancel/retrieval | 06–07 | COVERED |
| CONTEXT | D-07 trusted observer and untrusted-source boundary | 06–07 | COVERED |
| CONTEXT | D-08 on-demand automation without human UAT | 06–07 | COVERED |
| CONTEXT | D-09 original requirement ownership | 11–12 | COVERED |
| CONTEXT | D-10 source-first traceability and strict final audit | 11–12 | COVERED |

Deferred general freshness-service redesign, periodic canary, new auth/UI/docs/release features and unrelated todos remain excluded by `250-CONTEXT.md`.

## Six verification-gap truths

| Gap | Plan | Required outcome |
|---|---|---|
| 1 — READY-01/02 exact approved tuple and dispositions | 08–09 | Recover a candidate's own exact browser/CI, dry-run and ledger identities before tuple approval; require both READY verdicts satisfied and zero blockers. Child CI remains separately dated supplemental evidence for a parent tuple. |
| 2 — hosted failure and cancellation terminal receipts | 06–07 | Diagnose both failed-run symptoms, authorize a new bounded run, retrieve both artifacts and refresh AUTO owner report. |
| 3 — Phase 249 public/current proof | 10 | Source URL succeeds, focused mobile and full admin-eval harness pass, complete exact-main workflow plus all applicable jobs pass, PRs #302/#306/#307/#308/#309 receive current dispositions, and REL-01/02 are satisfied. |
| 4 — strict audit and traceability | 11–12 | Summary/requirement rows match passed owner reports; exact-lock TAP wrapper passes; source-derived audit is passed at 9/9 with zero blockers, orphans and contradictions. |
| 5 — controller exact artifact retrieval | 06–07 | Hosted, unique source and observer artifacts pass exact ID/digest/JSON validation. |
| 6 — on-demand proof after local contracts | 06–07 | No recurring schedule; live proof follows local repair, a fresh preflight and explicit new authorization. |

## Spec-less edge probe

The supplied deterministic `edge-coverage.json` has 11 applicable entries; three `unclassified` entries remain unresolved and flagged below. No row was dismissed or auto-promoted. There is no Phase 250 SPEC with a supplied Edge Coverage section.

| Requirement | Edge | Explicit plan predicate |
|---|---|---|
| READY-01 | idempotency | Plan 08 repeats immutable capture; Plan 09 requires equivalent verdict and identity on unchanged input. |
| READY-01 | concurrency | Plans 08–09 compare refs before/after capture and block mixed samples. |
| READY-02 | adjacency | Plan 09 keeps equal/adjacent observations distinct by source ID and timestamp. |
| READY-02 | empty | Plan 09 distinguishes authoritative zero items from null/failed query. |
| READY-02 | ordering | Plan 09 sorts by stable numeric PR ID/path and rejects duplicates. |
| REL-02 | adjacency | Plan 10 preserves distinct equal/adjacent PR/CI observations. |
| REL-02 | empty | Plan 10 blocks null/failed PR/worktree queries; zero requires authoritative complete query. |
| REL-02 | ordering | Plan 10 sorts IDs and checks repeated capture order and full disposition bijection. |
| AUTO-01 | unclassified | **FLAGGED ASSUMPTION:** the probe gave no question; Phase 248's existing protected-environment exact-source contract is the only current predicate. Reclassify if a concrete edge emerges; do not call this resolved. |
| AUTO-02 | unclassified | **FLAGGED ASSUMPTION:** the probe gave no question; hosted failure/cancellation proof has explicit source/attempt/artifact checks. Do not call the unclassified row resolved. |
| REL-01 | unclassified | **FLAGGED ASSUMPTION:** the probe gave no question; public URL/checksum/docs/tag source joins are explicit. Do not call the unclassified row resolved. |

## Prohibition recall and precision

The adversarial pass over all six requirements considered forged completion, published canary output, cancellation of a production run, credential disclosure, rewriting historical loss, unchecked duplicate rows, unstable CI evidence, and routine data/query errors. Routine correctness is handled by the edge predicates and task fixtures. Generic credential/injection issues refer to the ASVS threat registers and security review; no duplicate canon prohibition is minted. The bespoke retained items are descriptor-less, flagged-unverified in plan `must_haves.prohibitions`: no publishing authority for the canary (250-06), no false recovered-HANDOFF claim (250-12), and no forged 9/9 while owner evidence is absent (250-12). No `check_*` descriptor was fabricated and no prohibition was auto-dismissed.

## Active hook decisions

- The current API-coverage detector returned `detected:true` from the existing Phase 250 plan scope. `COVERAGE.md` records the complete scoped GitHub Actions/repository and Hex/HexDocs evidence surface, with explicit exclusions for release, publish, secret-value and unowned-run operations. It is a coverage decision, not hosted proof or a new runnable plan.
- `assumption-delta scan 250 --json` returned `detected:false`; no primary identity model is generalized. The plan still keeps package-source, candidate, current-main and artifact identities separate.
- No Payload, Prisma, Drizzle, Supabase or TypeORM schema path is in the phase scope; no schema push task applies.
- Graph context is disabled in this project. Estimate calibration returned factor 1, zero samples and `confidence: low`; all new estimate blocks preserve that measured confidence.
- New threat IDs continue after existing `T-250-16`, from `T-250-17` to `T-250-31`. `T-250-SC` is the shared reserved row in each plan.

## Artifacts this phase produces

Plan 06 repairs the canary helper, source workflow and fixture tests. Plan 07 writes an exact authority packet, fresh preflight/proof, Phase 248 snapshot and passing owner report. Plan 08 recovers an exact-candidate browser/CI/dry-run/ledger route before the tuple checkpoint; Plan 09 writes authentic approval/Playwright evidence plus passing READY ledger, reconciliation and owner report. Plan 10 writes public/current diagnostics, a scoped CI repair, full-harness and exact-main workflow gate, Phase 249 snapshot and passing owner report. Plans 11–12 reconcile summary frontmatter, requirements, passing wrapper validation and the strict passed 9/9 milestone audit. A missing external artifact is recorded as a named interruption rather than generated or waived.
