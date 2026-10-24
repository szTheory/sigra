---
phase: "255"
slug: "make-failures-reproducible-and-report-the-result"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-10-24"
source_head: 04b16705abfabb90b6d06f8f09eb9631e812dc58
register_authored_at_plan_time: true
---

# Phase 255 — Security

L1 audit of the 24 unique threats authored in the seven plans. Every mitigation is present in the scoped implementation and its tests/records. No new threat register or accepted-risk waiver was introduced.

## Trust Boundaries

Preserved inputs enter an owned replay root; command/report output enters explicit diagnostic staging; synthetic authenticated contexts enter sanitized retained ZIPs; the controller addresses exact owned GitHub runs; the immutable package crosses a create-only remote evidence branch.

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation evidence | Status |
|---|---|---|---|---|---|---|
| T-255-01 | Tampering | replay package | high | mitigate | scripts/ci/ci-comparison-replay.py:preflight_sources/materialize_inputs; nine replay tests, receipt hashes and package digest. | closed |
| T-255-02 | Elevation of privilege | archive materialization | high | mitigate | safe_path/verify_package reject traversal, absolute paths, duplicate members, symlinks and size excess; hostile archive tests. | closed |
| T-255-03 | Repudiation | result identity | medium | mitigate | INPUTS.json pins analysis separately from observations; original-input hash test and exact semantic replay pass. | closed |
| T-255-SC | Tampering | package-manager installs | high | mitigate | No dependency or lockfile change in captured Phase 255 source scope; existing pinned tools/actions only. | closed |
| T-255-04 | Elevation of privilege | reproduction rendering | high | mitigate | ci-command-record.py:render_reproduction uses shlex.join and argv subprocesses; real metacharacter test passes. | closed |
| T-255-05 | Information disclosure | bundle stager | high | mitigate | ci-diagnostic-bundle.py uses explicit manifest/provenance and scans serialized ZIPs; 11 bundle tests pass. | closed |
| T-255-06 | Tampering | invocation paths | high | mitigate | Exclusive invocation roots, path/hash validation, no recursive diagnostic copy; symlink/stale/identity negative tests pass. | closed |
| T-255-07 | Repudiation | primary outcome | medium | mitigate | Recorder preserves primary code/signal separately from cleanup; four real-process tests pass. | closed |
| T-255-08 | Tampering | Mix receiver coverage | high | mitigate | Native Mix report observes ordinary/scaffold/dep-off receivers, including all six scaffold modules; skipped-receiver negative control passes. | closed |
| T-255-09 | Tampering | dependency restoration | medium | mitigate | sigra-dep-off.sh retains guard status across restoration; 22 process assertions include SIGINT and exact lock restoration. | closed |
| T-255-10 | Repudiation | seed/reproduction | medium | mitigate | CiTimingFormatter records suite seed and failed identities; focused ExUnit tests and native per-receiver records. | closed |
| T-255-11 | Tampering | resource cleanup | high | mitigate | ci-browser-local.py token-checks DB shared-object comment and process group; native port/owned cleanup/unrelated DB checks passed. | closed |
| T-255-12 | Tampering | selected workloads | high | mitigate | Shared browserInvocations definitions plus native --list identities across all five seams and event modes; current Node checks pass. | closed |
| T-255-13 | Information disclosure | setup configuration | medium | mitigate | Configuration allowlists and PG credential redaction; local-runner password sentinel test passes. | closed |
| T-255-14 | Information disclosure | custom-context trace | high | mitigate | Explicit synthetic trace registry, auth-field sanitization with raw/derived hashes, pre-sanitization sentinel withholding; native three-trace safe bundle verified. | closed |
| T-255-15 | Tampering | sequential outputs | medium | mitigate | Invocation-specific report roots and explicit collector; actual fail-then-pass native record preserves prior output. | closed |
| T-255-16 | Repudiation | pre-context errors | medium | mitigate | Reporter onError and independent command streams; actual discovery/startup/browser-launch/SIGTERM cases record unavailable trace reasons. | closed |
| T-255-17 | Elevation of privilege | canary mutation | high | mitigate | FREEZE.json binds production and isolated read-only non-publishing fixture commit; exact owned cancellation guard; no main/tag/release mutation. | closed |
| T-255-18 | Spoofing | retrieved artifacts | high | mitigate | Actual downloaded success/failure/cancelled ZIPs verified against run/source/attempt/invocation and member hashes in RESULT.json. | closed |
| T-255-19 | Denial of service | polling/dispatch | medium | mitigate | charge_request persists request/invocation/push/retry reservations and enforces original deadline/core stop; actual 37/120, 3/4, 1/2, zero retries. | closed |
| T-255-20 | Repudiation | cancellation evidence | high | mitigate | Actual cancelled run 40124112173, verified pre-cancel partial output; final-output.log/final-trace.zip explicitly missing. | closed |
| T-255-21 | Tampering | package distribution | high | mitigate | Create-only digest-named remote ref, immutable commit, 1 successful push and bounded 2 attempts; second genuine remote fetch/offline replay passed. | closed |
| T-255-22 | Information disclosure | durable input archive | high | mitigate | Pinned approved replay members and secret/path scanning before publication; real-looking-credential negative test and exact hash check pass. | closed |
| T-255-23 | Repudiation | report claims | high | mitigate | Six semantic report tests reject false speed pass, numeric missing statistics, source substitution and sample inflation. | closed |

## Evidence Boundaries and Limitations

- The first reported rate read has no retained raw receipt/time; the ledger explicitly charges it conservatively and marks the reported remaining count unverified. All later controller calls use durable precharge; this exception is not described as precharged proof. The final bounded usage and real terminal outcomes are independently checked.
- Early stopped/parser attempts remain stopped in their original committed records. Controller-only repairs preserve the original fixture, spent charges and deadline; they did not consume a replacement invocation.
- Cancellation final files are missing. A partial artifact does not prove a finalizer ran.
- Traces remain restricted to registered synthetic contexts. Original auth-bearing bytes stay outside Git in protected local storage; derived artifacts record both hashes/redaction fields. This is not a claim that arbitrary authenticated traces are safe.
- Published replay helper parent and later verification-controller source differ and are explicitly recorded; the actual remote checkout's calculation passed without network and with identical input hashes.

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Blocking Open | Run By |
|---|---|---|---|---|
| 2026-10-24 | 24 | 24 | 0 | Codex L1 source/test/evidence audit |

## Sign-Off

All authored threats have mitigations. No high/critical open threat was found in this L1 check. The authored-register/L1 short-circuit applies; the independent code review still runs next.
