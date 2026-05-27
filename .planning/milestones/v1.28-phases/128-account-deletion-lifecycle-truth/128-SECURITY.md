---
phase: 128
slug: account-deletion-lifecycle-truth
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-27
verified: 2026-05-27
---

# Phase 128 - Security

Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Generated host -> Sigra.Auth | Host code supplies repo, user schema, token/session schemas, scope, and audit context into the library contract. | Repository modules, schema modules, scope/audit context, user lifecycle input. |
| Sigra.Account.Deletion -> Oban | Library code serializes worker args and schedules asynchronous deletion execution. | User ID, deletion strategy, scheduled time, generated-host context args. |
| Oban worker -> Repo/User schema | Background job args are rehydrated into modules and IDs used to reload and mutate user lifecycle state. | Serialized module names, required job args, user lifecycle state. |
| Lifecycle state -> Export/status surfaces | Raw `deleted_at` and `scheduled_deletion_at` fields determine user-visible lifecycle truth through `Deletion.status/1`. | Deletion markers and pending email staging fields. |

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-128-01 | Repudiation | `Sigra.Account.Deletion.schedule/3` enqueue path | mitigate | Full-context schedule test pins the `repo.insert/1` Oban changeset worker, queue, scheduled time, replace rule, and serialized context args. Evidence: `test/sigra/account/deletion_test.exs:85`, `:117`, `:118`, `:121`, `:125`, `:134`, `:135`. | closed |
| T-128-02 | Denial of Service | `maybe_enqueue_deletion_job/4` optional infrastructure | mitigate | Enqueue remains post-transaction and non-fatal; missing Oban or missing `:user_schema` returns `:ok`, while unexpected insert/build failures are logged and do not fail scheduling. Evidence: `lib/sigra/account/deletion.ex:306`, `:315`, `:318`, `:322`, `:327`, `:331`, `:334`; `test/sigra/account/deletion_test.exs:158`. | closed |
| T-128-03 | Tampering | `Sigra.Workers.AccountDeletion.perform/1` stale jobs | mitigate | Worker reloads the user and gates execution through `Deletion.scheduled?/1`; stale finalized jobs return `{:ok, :not_scheduled}`. Evidence: `lib/sigra/workers/account_deletion.ex:132`, `:137`, `:163`; `test/sigra/workers/account_deletion_test.exs:116`, `:119`, `:127`. | closed |
| T-128-04 | Information Disclosure | Soft-delete finalization | mitigate | Soft-delete finalization clears `pending_email`, `original_email`, and `scheduled_deletion_at` while preserving `deleted_at` and the user row. Evidence: `lib/sigra/account/deletion.ex:266`, `:271`, `:272`, `:273`; `test/sigra/account/deletion_test.exs:262`, `:264`, `:265`, `:266`, `:267`. | closed |
| T-128-05 | Denial of Service | Worker arg strategy conversion | mitigate | Worker uses `String.to_existing_atom/1` for strategy conversion and does not convert job args with `String.to_atom/1`. Evidence: `lib/sigra/workers/account_deletion.ex:130`. | closed |
| T-128-06 | Spoofing | Worker module resolution | mitigate | Worker uses required-key validation plus `Module.safe_concat/1` for repo/schema/module args; shared worker helper exposes required-arg fetch. Evidence: `lib/sigra/workers/account_deletion.ex:66`, `:67`, `:68`, `:69`, `:70`, `:71`, `:72`, `:73`, `:76`, `:77`, `:82`, `:88`, `:114`, `:115`, `:120`, `:126`; `lib/sigra/workers.ex:75`, `:76`. | closed |

## Accepted Risks Log

No accepted risks.

## Unregistered Threat Flags

None. `128-01-SUMMARY.md` reports no threat flags.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-27 | 6 | 6 | 0 | Codex + gsd-security-auditor |

## Verification

| Command | Result |
|---------|--------|
| `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs` | Passed: 35 tests, 0 failures. |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-27
