# Requirements: Sigra v1.28 DATA-LIFECYCLE

**Defined:** 2026-05-27
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

## v1 Requirements

### Export Contract

- [x] **EXP-01**: Operator can export a versioned Sigra-owned auth/account payload that includes account lifecycle fields, sessions, identities, audit rows, MFA credentials, passkey records, backup-code summary, and organization memberships when the generated schemas are available.
- [x] **EXP-02**: Operator can inspect explicit omission notes when optional export schemas are not configured, so partial exports are truthful instead of silent.

### Account Lifecycle

- [x] **LIFE-01**: User deletion scheduling enqueues `Sigra.Workers.AccountDeletion` for the scheduled time when Oban and generated-host context are available, while safely degrading when job context is absent.
- [x] **LIFE-02**: User deletion cancel and execute paths only apply to actively scheduled deletions; already-finalized users return `{:error, :not_scheduled}`.
- [x] **LIFE-03**: Soft-delete finalization clears scheduled deletion state and pending/original email fields without claiming the user row was hard-deleted.

### Generated Host And Docs

- [x] **HOST-01**: Generated host templates, example app, and install golden fixture preserve the same export and lifecycle semantics as the library code.
- [ ] **DOC-01**: Account lifecycle, audit export, and testing docs explain Sigra-owned data boundaries, host-owned data boundaries, omission behavior, and deletion strategy consequences.

### Proof

- [ ] **PROOF-01**: Targeted tests prove export shape, optional-schema degradation, deletion lifecycle truth, worker scheduling behavior, and generated-host parity.

## Future Requirements

### Suite Integration

- **SUITE-01**: Sigra can integrate with companion szTheory libraries through explicit adapters and recipes after the data-lifecycle trust surface is closed.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Legal or compliance certification | Sigra can provide truthful export and lifecycle seams, but certification remains host/operator responsibility. |
| Generic BI or reporting export | This milestone is limited to Sigra-owned auth/account data, not arbitrary application analytics. |
| SCIM or broad directory lifecycle automation | v1.27 intentionally shipped JIT login reconciliation without directory-sync ownership. |
| Hosted control-plane behavior | Sigra remains a Phoenix library and generated-host contract, not a hosted identity provider. |
| Host-app regulatory ownership | Host applications own their own domain data, retention policy, and legal interpretation. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EXP-01 | Phase 127 | Complete |
| EXP-02 | Phase 127 | Complete |
| LIFE-01 | Phase 128 | Complete |
| LIFE-02 | Phase 128 | Complete |
| LIFE-03 | Phase 128 | Complete |
| HOST-01 | Phase 129 | Complete |
| DOC-01 | Phase 129 | Pending |
| PROOF-01 | Phase 130 | Pending |

**Coverage:**
- v1 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after v1.28 milestone activation*
