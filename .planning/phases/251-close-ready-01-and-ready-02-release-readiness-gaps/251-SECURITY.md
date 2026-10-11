---
phase: "251"
slug: "close-ready-01-and-ready-02-release-readiness-gaps"
status: open_threats
threats_open: 4
asvs_level: 1
---

# Phase 251 Security Verification

Independent audit: 18 of 22 planned mitigations closed; four high-severity acceptance bypasses remain open. No risks were accepted or waived. Structured evidence: `251-SECURITY-AUDIT-GAPS.json`.

| Threat | Severity | Status | Evidence |
|---|---|---|---|
| T-251-01 | high | CLOSED | verify-247-readiness.mjs:238-293,316-347 exact tuple/CI/readiness/dry-run identities |
| T-251-02 | high | CLOSED | verify-247-readiness.mjs:255-281,328-347 complete contemporaneous approval history |
| T-251-03 | high | CLOSED | verify-247-readiness.mjs:407-427,557-575,905-930 complete stable PR identity joins |
| T-251-04 | high | CLOSED | verify-247-readiness.mjs:590-612,669-727 scoped dirty-byte capture and readback |
| T-251-05 | high | CLOSED | verify-v149-traceability.mjs:162-220 pinned historical owner/amendment bytes |
| T-251-06 | high | CLOSED | verify-v149-traceability.mjs:703-719,879-911 owner-derived verdicts and checkbox contradiction checks |
| T-251-07 | high | CLOSED | verify-v149-traceability.mjs:943-946,1136-1158 source-derived audit checks |
| T-251-08 | high | CLOSED | verify-247-readiness.mjs:356-405,760-769 persisted preflight/source identity gate |
| T-251-09 | high | CLOSED | validate-release-readiness.mjs:811-818 full identity disposition invalidation; test:632-659 |
| T-251-10 | high | CLOSED | validate-release-readiness.mjs:109-131,470-482 identity completeness/duplicates/null guards |
| T-251-11 | high | OPEN | verify-247-readiness.mjs:225-232 derives assertions from check.result instead of cited blob content; a forged README guide-link pass removes the missing-link finding. |
| T-251-12 | high | OPEN | verify-v149-traceability.mjs:536-567 validates stored assertion booleans; fabricated passing blobs and assertions are accepted. |
| T-251-13 | high | OPEN | verify-v149-traceability.mjs:602-633 does not require every worktree status entry in disposition joins; removing a dirty-path ID still yields READY-02 satisfied and 8/9. |
| T-251-14 | high | OPEN | verify-v149-traceability.mjs:406-443 reads commit:path but does not resolve the preservation ref or compare decision/source-byte proof; nonexistent ref still yields READY-02 satisfied and 8/9. |
| T-251-15 | high | CLOSED | verify-247-readiness.mjs:407-427,557-575,1121-1126 complete paginated stable PR snapshots |
| T-251-16 | high | CLOSED | verify-247-readiness.mjs:238-293 original interval and tuple-bound approval |
| T-251-17 | high | CLOSED | verify-247-readiness.mjs:108-123,152-204 exact published guide identity and trusted 404 findings |
| T-251-18 | medium | CLOSED | verify-247-readiness.mjs:736-757 packet digest/capture ID consistency |
| T-251-19 | high | CLOSED | verify-v149-traceability.mjs:446-470,902-911 owner/packet references |
| T-251-20 | high | CLOSED | verify-v149-traceability.mjs:879-947,1136-1158 owner-derived count/status |
| T-251-21 | medium | CLOSED | validate-release-readiness.test.mjs:632,687,716 and verify-247-readiness.test.mjs:676,805 retained regression evidence; dispositions remain subject to new audit gaps |
| T-251-SC | high | CLOSED | Existing Node/Git/gh only; no install tasks or commands. |

READY-01 remains authorization_pending. READY-02 acceptance is subject to the demonstrated independent-audit join and preservation bypasses until repaired. Prior report bytes remain recoverable at f3214912e056e50ea373b8e235a7f107231e83b3 (SHA-256 776ce7cfb1f2bb109bd06199d8acae0172b17618e1343d3cdfb1168bff6e1ad6).
