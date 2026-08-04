---
phase: 235
slug: terminal-ratification-measured-not-read
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-03
updated: 2026-08-03
---

# Phase 235 — Security

> Per-phase security contract for terminal ratification evidence, protected GitHub producers, offline attestation verification, and trusted staging.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Historical planning and CI evidence → terminal ledgers | Editable or stale records must not become completion claims without exact schema, identity, and digest checks. | Public run/job metadata, timestamps, conclusions, commands, hashes |
| GitHub REST and Actions → protected evidence producers | Remote responses are untrusted; workflow identity, permissions, pagination, chronology, and rate limits are enforced. | Public Actions metadata and authenticated read requests |
| Protected-main workflow → retained attested subject | Local repository content cannot establish protected provenance by itself. | Receipt bytes, signer workflow, repository/ref identity, bundle, trusted root |
| Retained evidence → offline verifier | Evidence must authenticate before parsing and remain valid with network access denied. | JSON receipts, attestations, trusted roots, SHA-256 digests |
| Measurement/readiness state → FAST-01 and GATE-05 status | Incomplete, stale, overlapping, or success-shaped data must not alter requirement status. | Population IDs, cutoffs, p50 statistics, verdicts, ownership rows |
| Workflow topology → contributor and closeout records | Direct owners, aggregates, event guards, and receipts must agree with executable configuration. | Workflow jobs/needs/guards, commands, documentation claims |
| Caller environment → verifier staging | PATH, temporary-directory variables, symlinks, and shared directories are hostile inputs. | Executable resolution, staging paths, retained evidence copies |
| Dirty worktree → phase execution | User-owned planning files and unrelated changes must survive verification unchanged and unstaged. | File bytes, git object hashes, porcelain path sets |

---

## Threat Register

All `closed` findings are backed by the matching `235-XX-SUMMARY.md` verification record and the implementation/contract named there. The ASVS L1 audit rechecked the complete plan-authored register and found no summary threat flags.

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-235-01-01 | Tampering | terminal ledger rows | high | mitigate | Exact schema/universe, inventory hash, live seam checks, immutable receipts, and negative mutations. | closed |
| T-235-01-02 | Repudiation | moved-family provenance | high | mitigate | Receiver, phase, command/run receipt, and direct owner are mandatory; aggregate-only evidence is rejected. | closed |
| T-235-01-03 | Information disclosure | persisted evidence | high | mitigate | Only public identifiers, commands, timestamps, hashes, and sanitized diagnostics are retained. | closed |
| T-235-01-04 | Denial of service | focused contract | medium | mitigate | Deterministic bounded local checks; no polling, sleeps, or network calls. | closed |
| T-235-02-01 | Tampering | measurement population/verdict | high | mitigate | Exact boundaries/identities, retained outcomes, minimum population, output equality, and threshold mutations. | closed |
| T-235-02-02 | Repudiation | live run/job receipts | high | mitigate | Durable public IDs, URLs, SHAs, timestamps, commands, hashes, conclusions, and exact-job diagnosis. | closed |
| T-235-02-03 | Information disclosure | GitHub credentials/output | high | mitigate | Credentials and authenticated state are excluded; only public metadata and sanitized hashes remain. | closed |
| T-235-02-04 | Denial of service | GitHub API collection | high | mitigate | Rate preflight, bounded fetch/retry/watch policy, and hard stop on 403/429. | closed |
| T-235-03-01 | Tampering | contributor topology claims | high | mitigate | Direct owners, five seams, aggregates, commands, and events are checked against executable sources. | closed |
| T-235-03-02 | Repudiation | SEED-005 / CI-PERF closeout | high | mitigate | Records must link and exactly match the ledger's count, p50, status, outcomes, and residual. | closed |
| T-235-03-03 | Information disclosure | docs and residual | high | mitigate | Only public IDs/URLs, commands, hashes, and sanitized diagnostics are copied. | closed |
| T-235-03-04 | Denial of service | verification suite | medium | mitigate | Focused local non-watch suites; no CI polling. | closed |
| T-235-04-01 | Tampering | FAST-01 statistics, receipt, count, verdict | high | mitigate | Independent recomputation, canonical bytes, SHA-256, and adversarial statistic/receipt mutations. | closed |
| T-235-04-02 | Tampering | GATE-05 ownership rows | high | mitigate | Exact ownership MapSets with extra, missing, duplicate, family, and event mutations. | closed |
| T-235-04-03 | Repudiation | contributor topology claim | high | mitigate | Scoped workflow extraction and unique prose assertions reject role/event contradictions. | closed |
| T-235-04-04 | Information disclosure | retained metric output | low | accept | Only committed aggregate statistics are retained; secrets and authenticated payloads are excluded. | closed |
| T-235-04-05 | Denial of service | deterministic contract suite | low | mitigate | Fixed checked-in files and bounded parsing; no network, watches, sleeps, or unbounded inputs. | closed |
| T-235-05-01 | Tampering | capture endpoint and source population | high | mitigate | Pinned capture/digest, canonical byte hashes, full-field reconciliation, and coherent-forgery mutations. | closed |
| T-235-05-02 | Spoofing | retained run identities | high | mitigate | Unique positive IDs, canonical URLs, and exact source/receipt identity equality. | closed |
| T-235-05-03 | Tampering | binding-pole receipts | high | mitigate | Digest-bound job bytes, derived selection, offline replay, byte-exact output, and substitution mutations. | closed |
| T-235-05-04 | Tampering | GATE-05 ownership semantics | high | mitigate | Complete family/event maps checked against jobs, aggregate dependencies, and receipt registry. | closed |
| T-235-05-05 | Repudiation | contributor closeout composition | high | mitigate | Closeout composes topology validation and rejects nil or contradictory records. | closed |
| T-235-05-06 | Information disclosure | raw run/job receipts | low | accept | Only public Actions metadata is retained; logs, secrets, headers, artifacts, and authenticated payloads are excluded. | closed |
| T-235-05-07 | Denial of service | evidence retrieval and parser | low | mitigate | Fixed IDs are fetched once; subsequent parsing is bounded and offline. | closed |
| T-235-06-01 | Tampering | canonical source population | high | mitigate | Exact command output and independent digest with closed-field, full-population reconciliation. | closed |
| T-235-06-02 | Spoofing | retained run identity | high | mitigate | Unique IDs, canonical repository URLs, events, chronology, conclusions, and SHAs from digest-checked bytes. | closed |
| T-235-06-03 | Tampering | median/max pole receipts | high | mitigate | Source-derived selections and exact job-byte replay through the mandated metrics script. | closed |
| T-235-06-04 | Tampering | ownership destinations | high | mitigate | All 93 semantic rows checked against inventory, workflow, phase evidence, and retained jobs. | closed |
| T-235-06-05 | Repudiation | evidence provenance | medium | mitigate | Closed receipt schemas preserve exact commands, outputs, digests, identities, events, and phase paths. | closed |
| T-235-06-06 | Information disclosure | GitHub receipts | low | accept | Only public Actions metadata needed for proof is stored. | closed |
| T-235-06-07 | Denial of service | GitHub evidence retrieval | low | mitigate | One bounded read per fixed command; no watchers or sleeps; hard rate-limit stop. | closed |
| T-235-07-01 | Tampering | paginated run/job population | high | mitigate | All pages, counts, exhaustion, unique IDs, and omitted-page/cap-hit mutations are verified. | closed |
| T-235-07-02 | Spoofing | receipt provenance | high | mitigate | Attestation binds exact subject to signer workflow, repository, and main ref. | closed |
| T-235-07-03 | Tampering | run/job timestamps | high | mitigate | Inverted run/job chronology is rejected before duration derivation. | closed |
| T-235-07-04 | Information disclosure | API and workflow output | high | mitigate | Public identifiers/times/conclusions/job names only; secrets and authenticated state are excluded. | closed |
| T-235-07-05 | Denial of service | GitHub API collection | medium | mitigate | Bounded REST, one preflight, hard rate-limit stop, and single-watcher ownership. | closed |
| T-235-07-SC | Tampering | pinned GitHub actions | high | mitigate | Verified first-party actions use immutable commit SHAs. | closed |
| T-235-08-01 | Spoofing | attestation signer/source | high | mitigate | Network-denied verification checks repository, signer, main ref, digest, bundle, and trusted root with adverse cases. | closed |
| T-235-08-02 | Tampering | complete run/job population | high | mitigate | Attested pages/totals/exhaustion/identities are reconciled; replacement and chronology mutations fail. | closed |
| T-235-08-03 | Tampering | event eligibility/execution | high | mitigate | Supported guards and matching terminal non-skipped job receipts are required per executed row. | closed |
| T-235-08-04 | Repudiation | FAST-01/GATE-05 status | high | mitigate | Requirement state is contract-bound to protected verdict and ownership evidence. | closed |
| T-235-08-05 | Information disclosure | retained API/attestation files | high | mitigate | Public metadata and cryptographic bundles only; credentials and raw authenticated logs are excluded. | closed |
| T-235-08-06 | Denial of service | remote capture monitoring | medium | mitigate | Bounded projections, one 60-second watcher, one summary/log fetch, one retry, and rate gate. | closed |
| T-235-08-07 | Spoofing | dispatched workflow correlation | high | mitigate | Exact workflow/event/SHA/time set difference requires one newly persisted run identity. | closed |
| T-235-09-01 | Tampering | fresh cutoff/window | high | mitigate | Outcome-independent full SHA/time cutoff with protected-main ancestry and mutation tests. | closed |
| T-235-09-02 | Tampering | run population/statistics | high | mitigate | Exhaustive unique terminal population, valid chronology, minimum count, stable ordering, strict comparator. | closed |
| T-235-09-03 | Spoofing | protected producer identity | high | mitigate | Input-free main-only least-privilege workflow with immutable pins and exact subject identity. | closed |
| T-235-09-04 | Repudiation | insufficient population | high | mitigate | Count, IDs, endpoint, command, rate state, and null verdict remain in a blocking machine-readable record. | closed |
| T-235-09-05 | Denial of service | GitHub collection | medium | mitigate | One preflight, finite pages, bounded retry, no watcher, and hard rate-limit stop. | closed |
| T-235-09-06 | Information disclosure | evidence artifacts | low | accept | Only public metadata, commands, digests, and diagnostics are retained. | closed |
| T-235-09-07 | Tampering | GATE-05 proof | high | mitigate | Offline verifier and contract protect ownership artifacts and status from unrelated edits. | closed |
| T-235-10-01 | Spoofing | dispatch run identity | high | mitigate | Exact workflow/event/SHA/time set difference, persisted ID, one watcher, and zero/multiple/stale rejection. | closed |
| T-235-10-02 | Tampering | fresh receipt/provenance | high | mitigate | Network-denied repository/signer/ref/digest/bundle/root verification and five adverse cases. | closed |
| T-235-10-03 | Tampering | p50 verdict | high | mitigate | Independent complete-population recomputation with count, conclusions, stable order, and strict comparator mutations. | closed |
| T-235-10-04 | Repudiation | requirement status | high | mitigate | Protected pass/miss is bound to checkbox, traceability, and residual; contradictions fail. | closed |
| T-235-10-05 | Tampering | GATE-05 proof | high | mitigate | Offline verifier and 93-row contract pass while ownership files/status stay excluded. | closed |
| T-235-10-06 | Information disclosure | external evidence | high | mitigate | Public metadata and cryptographic material only; secrets and authenticated state are excluded. | closed |
| T-235-10-07 | Denial of service | CI/API operations | medium | mitigate | One preflight/watcher/summary, failure-only logs, bounded discovery/retry, and hard rate-limit stop. | closed |
| T-235-11-01 | Tampering | mix ci test selection | high | mitigate | Exact ordinary/scaffold set equality, disjointness, union, tags, duplicates, and mutations. | closed |
| T-235-11-02 | Repudiation | coverage/performance claim | high | mitigate | Source-bound timing identity and immutable prior receipt digest in a closed JSON receipt. | closed |
| T-235-11-03 | Spoofing | PR run identity | high | mitigate | Exact event/head-SHA selection, one watcher, persisted IDs, and protected aggregate results. | closed |
| T-235-11-04 | Tampering | next cutoff | high | mitigate | Protected ancestry, exact merged blobs, merge identity/time, and outcome-independent selection. | closed |
| T-235-11-05 | Denial of service | GitHub observation | medium | mitigate | One rate preflight/watcher/summary, failure-only logs, bounded retry, hard rate-limit stop. | closed |
| T-235-11-06 | Information disclosure | retained evidence | low | accept | Only public run metadata and digests are retained. | closed |
| T-235-12-01 | Tampering | cutoff/independence | high | mitigate | Protected ancestry/time/blob checks, prior endpoint comparison, old-ID disjointness, and pinned digest. | closed |
| T-235-12-02 | Tampering | pagination/population | high | mitigate | Contiguous pages, terminal empty page, unique IDs, bounds, chronology, conclusions, and mutations. | closed |
| T-235-12-03 | Spoofing | protected producer | high | mitigate | Input-free main-only workflow, immutable pins, exact collector/output/schema, and least privilege. | closed |
| T-235-12-04 | Repudiation | readiness/verdict | high | mitigate | Separate schemas/namespaces keep readiness statistics/verdict null behind a protected population gate. | closed |
| T-235-12-05 | Denial of service | GitHub API | medium | mitigate | One rate preflight, bounded pages/retry, and hard 403/429 stop. | closed |
| T-235-12-06 | Information disclosure | artifacts | low | accept | Public run metadata and cryptographic evidence only. | closed |
| T-235-13-01 | Spoofing | dispatch/run identity | high | mitigate | Exact workflow/event/ref/SHA/time set difference, persisted ID, one watcher, zero/multiple rejection. | closed |
| T-235-13-02 | Tampering | attestation subject | high | mitigate | Network-denied repository/signer/ref/digest/root verification and adverse cases. | closed |
| T-235-13-03 | Tampering | population/verdict | high | mitigate | Complete independent population, cutoff/endpoint, disjointness, conclusions, canonical recomputation, count, strict comparator. | closed |
| T-235-13-04 | Repudiation | requirement status | high | mitigate | Exact protected evidence is bound to checkbox, traceability, and residual in both branches. | closed |
| T-235-13-05 | Tampering | GATE-05 proof | high | mitigate | Offline verifier, 93-row contract, byte/prose non-regression, and excluded edits. | closed |
| T-235-13-06 | Denial of service | external operations | medium | mitigate | One preflight/watcher/summary, bounded calls/retry, failure-only logs, and hard rate-limit stop. | closed |
| T-235-13-07 | Information disclosure | retained evidence | low | accept | Public metadata and cryptographic evidence only. | closed |
| T-235-14-01 | Spoofing | interpreter, PATH utility, script root | high | mitigate | Pinned Bash entrypoints, builtin root derivation, hostile utility shadows, empty sentinels, final markers. | closed |
| T-235-14-02 | Tampering | temporary staging selection | high | mitigate | Clear caller overrides, use a fixed platform parent, and test hostile path relationships. | closed |
| T-235-14-03 | Tampering | staging parent/work path | high | mitigate | Canonical containment, ownership, non-symlink/private-mode validation, and confined cleanup. | closed |
| T-235-14-04 | Tampering | staging race/symlink swap | high | mitigate | Atomic trusted `mktemp`, immediate post-create validation, and confined cleanup. | closed |
| T-235-14-05 | Repudiation | verifier regression result | high | mitigate | Both hostile self-tests require their final positive marker; early failure cannot pass. | closed |
| T-235-14-06 | Information disclosure | staged retained evidence | low | mitigate | Private work permissions, isolated HOME, cleared credentials/proxies, deterministic cleanup. | closed |
| T-235-14-07 | Denial of service | missing utilities/staging failure | medium | mitigate | Explicit prerequisites and nonzero diagnostics; no untrusted-storage fallback. | closed |
| T-235-14-08 | Elevation of privilege | Linux sudo isolation fallback | high | mitigate | Absolute `/usr/bin/sudo` invocation and cleanup; never PATH-resolved sudo. | closed |
| T-235-14-09 | Tampering | network-denied provenance semantics | high | mitigate | Exact repository, signer workflow, main ref, subject digest, trusted root, and adverse cases preserved. | closed |
| T-235-14-10 | Tampering | user-owned dirty planning files | high | mitigate | Byte/hash/status preservation after each task; no staging, restore, revert, format, or task commit. | closed |
| T-235-14-11 | Tampering | execution changed-path scope | high | mitigate | Pre/post normalized path-set subtraction must equal the exact implementation allowlist; real index untouched. | closed |

*Status: open · closed · open — below high threshold (non-blocking). `threats_open` counts only open high/critical threats.*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-235-01 | T-235-04-04 | Aggregate metric output is already committed public project evidence; secrets and authenticated payloads are prohibited. | Phase 235 plan disposition | 2026-08-02 |
| AR-235-02 | T-235-05-06 | Raw run/job receipts contain only public Actions metadata required by the ledger; sensitive response material is excluded. | Phase 235 plan disposition | 2026-08-02 |
| AR-235-03 | T-235-06-06 | GitHub receipts retain only public proof fields, with logs, headers, environment data, and artifacts excluded. | Phase 235 plan disposition | 2026-08-02 |
| AR-235-04 | T-235-09-06 | Fresh-window artifacts contain public metadata, commands, digests, and sanitized diagnostics only. | Phase 235 plan disposition | 2026-08-03 |
| AR-235-05 | T-235-11-06 | Remediation evidence retains only public run metadata and cryptographic digests. | Phase 235 plan disposition | 2026-08-03 |
| AR-235-06 | T-235-12-06 | Readiness/protected artifacts contain public metadata and cryptographic evidence only. | Phase 235 plan disposition | 2026-08-03 |
| AR-235-07 | T-235-13-07 | Final retained evidence contains public metadata and cryptographic proof only; credentials, proxies, and raw logs are excluded. | Phase 235 plan disposition | 2026-08-04 |

---

## Verification Evidence

- Register origin: all 14 `235-XX-PLAN.md` files contain parseable `<threat_model>` blocks.
- Threat flags: no `## Threat Flags` entries were reported by any of the 14 completed summaries.
- Deterministic controls: phase summaries record passing focused ExUnit contracts, hermetic collector/verifier suites, workflow lint, metrics self-tests, and offline attestation verification.
- Final boundary hardening: `235-14-SUMMARY.md` records both hostile-environment verifier self-tests, both live offline verifiers, and focused planning contracts passing.
- Severity/disposition inventory: 88 total threats; 66 high, 11 medium, 11 low; 81 mitigated and 7 accepted; 0 open.

## Security Audit 2026-08-03

| Metric | Count |
|--------|-------|
| Threats found | 88 |
| Closed | 88 |
| Open | 0 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-03 | 88 | 88 | 0 | Codex / `gsd-secure-phase` ASVS L1 |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-03
