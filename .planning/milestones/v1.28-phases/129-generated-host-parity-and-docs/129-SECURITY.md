---
phase: 129
slug: generated-host-parity-and-docs
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-27
---

# Phase 129 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| generated host -> Sigra.DataExport | Host app passes repo, user, and schema modules into library-owned auth-data export. | User auth/account data and schema module references. |
| generated UI/email -> user/operator | Strategy-neutral deletion copy communicates lifecycle consequences to users and operators. | Account lifecycle status and deletion-strategy messaging. |
| templates -> golden fixture | Installer templates become committed golden evidence for generated-host behavior. | Generated source and user-facing copy. |
| docs -> operator | Documentation shapes operator understanding of export completeness and deletion consequences. | Public guidance about data export, retention, and deletion semantics. |
| library-owned data -> host-owned data | Sigra owns auth/account export; host app owns domain-data export and retention. | Sigra-owned auth/account records vs host-owned domain records. |
| optional schemas -> export reader | Missing optional generated schemas must be communicated as explicit omissions. | Export omission notes for optional Sigra-owned sections. |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-129-01 | Information Disclosure | `auth.ex` and `accounts.ex` export wrappers | mitigate | Wrappers call `Sigra.DataExport.export_auth_data/3`; tests assert delegation and refute payload construction in generated host code. Evidence: `priv/templates/sigra.install/core/auth.ex:1078`, `test/example/lib/example/accounts.ex:1285`, `test/sigra/templates/settings_live_test.exs:203`. | closed |
| T-129-04 | Information Disclosure / Repudiation | Optional schema defaults in core generated wrapper and docs | mitigate | Core wrapper defaults only always-core schemas and merges caller opts; tests refute unguarded optional export schema defaults; docs state bounded Sigra-owned auth/account export and host-owned domain boundary. Evidence: `priv/templates/sigra.install/core/auth.ex:1093`, `test/sigra/install/isolation_test.exs:91`, `guides/flows/audit-logging.md:124`. | closed |
| T-129-02 | Repudiation / Information Disclosure | Lifecycle and testing docs plus settings/reactivation/email copy | mitigate | Generated, example, golden, and docs describe configured strategy consequences and avoid broad permanent-removal claims. Evidence: `priv/templates/sigra.install/core/settings_live.ex:173`, `priv/templates/sigra.install/core/reactivation_live.ex:43`, `priv/templates/sigra.install/core/emails.ex:697`, `guides/flows/account-lifecycle.md:151`, `test/sigra/guides_dx02_test.exs:330`. | closed |
| T-129-03 | Tampering / Repudiation | Install golden fixture | mitigate | Golden fixture mirrors generated template wrapper/copy; summary records rebless plus golden diff verification. Evidence: `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex:1077`, `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/settings_live.ex:173`, `129-01-SUMMARY.md:113`. | closed |
| T-129-05 | Repudiation | Audit export and testing docs | mitigate | Docs and tests explain explicit `omissions` for missing optional Sigra-owned schemas. Evidence: `guides/flows/audit-logging.md:128`, `guides/recipes/testing.md:83`, `test/sigra/guides_dx02_test.exs:304`. | closed |

*Status: open - closed*
*Disposition: mitigate (implementation required) - accept (documented risk) - transfer (third-party)*

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-27 | 5 | 5 | 0 | Codex / gsd-security-auditor |

## Security Audit 2026-05-27

| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed | 5 |
| Open | 0 |

`129-01-SUMMARY.md` and `129-02-SUMMARY.md` both report `Threat Flags: None`; no unregistered flags were found.

## Verification Run

- `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/isolation_test.exs test/sigra/install/golden_diff_test.exs test/sigra/guides_dx02_test.exs --max-failures 1` - passed, 66 tests, 0 failures.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-27
