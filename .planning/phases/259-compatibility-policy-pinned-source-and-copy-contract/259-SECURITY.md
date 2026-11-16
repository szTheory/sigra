---
phase: "259"
slug: compatibility-policy-pinned-source-and-copy-contract
status: verified
threats_open: 0
asvs_level: 1
created: "2026-11-15"
---

# Phase 259 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Vendored brand/ tree to repo | Pinned brand book assets and metadata enter the repo | binary asset metadata (author names, paths, emails) |
| Planning and docs to public repo | ADRs, guides and test fixtures are published | maintainer identity, adopter details |
| Example host to generated host | Enumeration parity is proven on the example host only | account-existence signals |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-259-01 | Repudiation | phase 259 | medium | mitigate | policy_docs_test dated confirmation; instruction_pointers_test claim regex | closed |
| T-259-02 | Info Disclosure | phase 259 | high | mitigate | privacy grep clean; source_pin_test real-tree scan; run-time identity derivation | closed |
| T-259-03 | Tampering | phase 259 | low | mitigate | zero diff on mix.exs, doc/, CHANGELOG.md | closed |
| T-259-04 | Tampering | phase 259 | high | mitigate | brand.sha256 72/72; .gitattributes -text; source_pin drift test | closed |
| T-259-05 | Info Disclosure | phase 259 | high | mitigate | source_pin_test binary-aware metadata scan with planted controls | closed |
| T-259-06 | Tampering | phase 259 | medium | mitigate | fragment-built patterns; single scan exclusion; planted controls | closed |
| T-259-07 | Info Disclosure | phase 259 | low | mitigate | og:image host derived at run time, absent from shipped diff | closed |
| T-259-08 | Tampering | phase 259 | low | mitigate | login_submit_selector_test exactly-one-match plus planted controls | closed |
| T-259-09 | Repudiation | phase 259 | low | mitigate | honesty line in 259-04-SUMMARY | closed |
| T-259-10 | Tampering | phase 259 | medium | mitigate | install_snippet_test three-segment shape and controls | closed |
| T-259-11 | Repudiation | phase 259 | low | mitigate | install_snippet_test non-vacuity | closed |
| T-259-12 | Tampering | phase 259 | high | mitigate | frozen_surface_test extend_only; regen_guard refuses under CI | closed |
| T-259-13 | Tampering | phase 259 | high | mitigate | legacy_profiles_test exact equality plus positive control | closed |
| T-259-14 | Elevation of Privilege | phase 259 | medium | mitigate | no Code.eval*, Code.string_to_quoted only | closed |
| T-259-15 | Repudiation | phase 259 | medium | mitigate | frozen_surface_test per-category non-vacuity | closed |
| T-259-16 | Elevation of Privilege | phase 259 | medium | mitigate | no eval; EEx handled by regex | closed |
| T-259-17 | Info Disclosure | phase 259 | medium | mitigate | diff privacy grep clean incl. TSVs | closed |
| T-259-18 | Repudiation | phase 259 | low | mitigate | copy_inventory_test; parse failures raise | closed |
| T-259-19 | Info Disclosure | phase 259 | high | accept | passkey sign-in options known_divergence (ADR 006 row, registry, todo) | closed |
| T-259-20 | Info Disclosure | phase 259 | medium | accept | registration known_divergence (ADR 006 row, todos) | closed |
| T-259-21 | Repudiation | phase 259 | high | mitigate | per-row compare dimensions; not_proven rows; example-host limitation noted | closed |
| T-259-22 | Tampering | phase 259 | high | mitigate | leak positive control in enumeration_parity_test | closed |
| T-259-23 | Info Disclosure | phase 259 | medium | mitigate | fixture addresses only | closed |
| T-259-24 | Repudiation | phase 259 | medium | mitigate | copy_contract_test lexicon scan with shrink-only baseline | closed |
| T-259-25 | Tampering | phase 259 | high | mitigate | copy_contract_test no-new/no-stale baseline gate | closed |
| T-259-26 | Info Disclosure | phase 259 | medium | mitigate | generated-scope sign-in vocabulary scan | closed |
| T-259-27 | Repudiation | phase 259 | low | mitigate | vocabulary_docs_test scoping and anchors | closed |
| T-259-28 | Tampering (process) | phase 259 | medium | mitigate | instruction_pointers_test retired-pointer negative grep | closed |
| T-259-29 | Repudiation | phase 259 | medium | mitigate | instruction_pointers_test alignment phrases absent | closed |
| T-259-30 | Tampering | phase 259 | medium | mitigate | instruction_pointers_test pins named CLAUDE.md line (numstat bound is a plan-time gate) | closed |
| T-259-31 | Repudiation | phase 259 | high | mitigate | claims_docs_test scope paragraph and retired-phrase map | closed |
| T-259-32 | Info Disclosure | phase 259 | low | mitigate | claims_docs_test planning-citation allow-list | closed |
| T-259-33 | Tampering | phase 259 | low | mitigate | copy_contract_test green, no baselined line edited | closed |
| T-259-34 | Repudiation | phase 259 | high | mitigate | name_clearance_test title phrase and forbidden wording | closed |
| T-259-35 | Info Disclosure | phase 259 | high | mitigate | owner handle derived at run time and asserted absent | closed |
| T-259-36 | Repudiation | phase 259 | high | mitigate | register cross-checked against registry | closed |
| T-259-37 | Tampering | phase 259 | medium | mitigate | single exclusion in privacy gates | closed |
| T-259-38 | Repudiation | phase 259 | low | mitigate | parity test asserts real todo paths | closed |
| T-259-39 | Repudiation | phase 259 | low | mitigate | vocabulary_docs_test anchor resolution | closed |
| T-259-40 | Repudiation | phase 259 | medium | mitigate | claims_docs_test empty sweep allow-list | closed |
| T-259-41 | Repudiation | phase 259 | low | mitigate | voice.terms read from pinned brand.json | closed |
| T-259-42 | Info Disclosure | phase 259 | high | mitigate | reset view calls context unconditionally; parity row green | closed |
| T-259-43 | Tampering | phase 259 | medium | mitigate | parity non-vacuity dimensions | closed |
| T-259-44 | Repudiation | phase 259 | high | mitigate | row note: generated host not compared; todo wired; zero lib/priv diff | closed |
| T-259-45 | Info Disclosure | phase 259 | medium | accept | timing not compared; existing timing/rate-limit todos | closed |
| T-259-46 | Info Disclosure | phase 259 | high | mitigate | confirmation resend uses session user only; parity row with result dimension | closed |
| T-259-47 | Denial of Service | phase 259 | medium | mitigate | nil-safe session_user/1 | closed |
| T-259-48 | Tampering | phase 259 | medium | mitigate | parity non-vacuity and result dimension | closed |
| T-259-49 | Elevation of Privilege | phase 259 | medium | mitigate | confirm_user_by_code reached only for session user | closed |
| T-259-50 | Repudiation | phase 259 | high | mitigate | example-host-only evidence stated; generated-confirm todo exists | closed |
| T-259-51 | Repudiation | phase 259 | high | mitigate | separate id classes; planted controls | closed |
| T-259-52 | Tampering | phase 259 | high | mitigate | not_proven tolerance removed; planted control | closed |
| T-259-53 | Tampering | phase 259 | medium | mitigate | positive control keeps other parity rows same | closed |
| T-259-54 | Repudiation | phase 259 | high | mitigate | todo with file:line evidence referenced by registry | closed |
| T-259-55 | Tampering | phase 259 | medium | mitigate | todo labels readings as source reads, not executed | closed |
| T-259-56 | Info Disclosure | phase 259 | medium | mitigate | repo-relative paths only | closed |
| T-259-57 | Info Disclosure | phase 259 | high | mitigate | claims bounded to example app and single attempt | closed |
| T-259-58 | Repudiation | phase 259 | medium | mitigate | retired false clause pinned; register-vs-registry cross-check | closed |
| T-259-59 | Info Disclosure | phase 259 | low | mitigate | citation check over README and guides | closed |
| T-259-60 | Tampering | phase 259 | medium | mitigate | empty shrink-only sweep allow-list | closed |

*Status: open - closed - open below block_on threshold (non-blocking)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-259-01 | T-259-19 | Passkey sign-in options leak account existence; a zero-shipped-bytes phase cannot fix it. Registered known_divergence, asserted to still differ, fixed as shipped-byte work before Phase 262 (ADR 005 amendment; todo 2026-11-13-passkey-options-email-existence-oracle). | Plan-time disposition, confirmed by owner 2026-11-15 | 2026-11-15 |
| AR-259-02 | T-259-20 | Registration leaks account existence (auto-sign-in versus flash). Registered known_divergence; fix tracked by todos 2026-11-13-duplicate-registration-timing-oracle and 2026-11-13-lockout-and-rate-limit-enumeration-channels. | Plan-time disposition, confirmed by owner 2026-11-15 | 2026-11-15 |
| AR-259-03 | T-259-45 | Timing and rate-limit channels are not compared by the parity tests; recorded in the row note and the existing timing todos. | Plan-time disposition | 2026-11-15 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-15 | 60 | 60 | 0 | gsd-security-auditor (ASVS 1, block_on high); 343 brand tests + 60 example-host tests green, brand.sha256 72/72 |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-15
