---
phase: 09-audit-logging
audited: 2026-04-09
auditor: gsd-secure-phase
asvs_level: 2
verdict: CONCERNS
threats_total: 10
threats_mitigated: 7
threats_partial: 3
threats_unmitigated: 0
blockers: 0
plan_threat_ids:
  - T-9-01
  - T-9-02
  - T-9-03
  - T-9-04
  - T-9-05
  - T-9-06
  - T-9-07
  - T-9-08
  - T-9-09
---

# Phase 9: Audit Logging - Security Audit

**Verdict:** CONCERNS (non-blocking) — all threats declared in the phase threat register are mitigated as planned, but two classes of partial mitigations are documented follow-ups (C-1 non-atomic hybrid, forbidden-key flat-scan only) and one new soft concern is flagged below.

**Scope:** Verification of the `<threat_model>` blocks declared in 09-01..09-05-PLAN.md against the implemented code. No net-new vulnerability scanning.

## Threat Register Classification

| Threat | STRIDE | Disposition | Status | Evidence |
|---|---|---|---|---|
| T-9-01 | Tampering (table immutability) | accept | MITIGATED | `lib/sigra/audit.ex` exposes no update path. Only delete path is `cleanup/1` (line 292) → `do_cleanup/3` (line 300-311). No `Repo.update` calls for audit rows. Migration `priv/templates/sigra.install/create_audit_events.exs` omits `updated_at` (line 18 `timestamps(updated_at: false)`). |
| T-9-01 (Spoofing) | Spoofing (plan 09-02 variant — reserved prefix forgery) | mitigate | MITIGATED | `lib/sigra/audit/changeset.ex:79-87` `validate_reserved_prefix/3` rejects any action starting with `auth. session. mfa. oauth. api. account. sigra.` unless `allow_reserved: true`. Public `log/3` (audit.ex:46) calls `changeset_opts(opts, false)`; `log_multi/3` (audit.ex:77) additionally raises `ArgumentError` at composition time (line 82-86). Only `__log_internal__/3` and `log_safe/3` pass `allow_reserved: true`. |
| T-9-02 | DoS (metadata blob) | mitigate | MITIGATED | `lib/sigra/audit/changeset.ex:89-111` `validate_metadata_size/2` JSON-encodes metadata and rejects payloads exceeding `:max_metadata_bytes` (default 8192). Configurable via Application env (`audit.ex:325-330`). |
| T-9-03 | Information Disclosure (sensitive data in metadata) | mitigate | PARTIAL | `lib/sigra/audit/changeset.ex:113-135` rejects maps containing any of 15 forbidden keys (password/token/secret variants) in both atom and string form. **Partial:** flat-scan only per assumption A5 — a nested map like `%{context: %{password: "x"}}` bypasses the validator. Documented as deferred in RESEARCH §Assumptions A5. All observed metadata call sites (grep above) use only flat IDs/counts/reasons/methods, so there is no in-library exposure. |
| T-9-04 | Repudiation (silent retention failure) | mitigate | MITIGATED | `lib/sigra/workers/audit_cleanup.ex:30-32` uses `max_attempts: 1` so failures surface in Oban dashboard (no silent retry loop). `lib/sigra/audit.ex:300` short-circuits with `:ok` when `retention_days` is `nil` (forever default per D-09). Inline fallback `Sigra.Audit.cleanup/1` (line 292) preserves path when Oban absent. Startup warning wired in `lib/sigra/application.ex` per VERIFICATION.md link table. |
| T-9-05 | Repudiation (missing audit on partial failure) | mitigate | PARTIAL | `lib/sigra/audit.ex:162-171` `do_log_multi/4` appends `:audit` step inside the same `Ecto.Multi` as the business op. Verified at 3 integration sites: `auth.ex:560` (confirm_email), `auth.ex:676` (verify_confirmation_code), `auth.ex:833` (reset_password). **Partial — documented caveat C-1:** remaining ~82 call sites (auth session/security, mfa, oauth, api_token, account, lockout, suspicious_login) use `log_safe/3` which runs a separate `repo.insert` AFTER the business op commits. On audit insert failure `log_safe/3` swallows the error and emits `[:sigra, :audit, :log_safe_error]` diagnostic telemetry (audit.ex:134-142), leaving a gap: the business op succeeds but audit row is lost. Documented as follow-up F-1. |
| T-9-06 | Tampering (cursor enumeration/forgery) | accept | MITIGATED | `lib/sigra/audit/cursor.ex:11-14` encodes `Base64URL("<usec>|<uuid>")` with NO signing by design. Attack surface: a forged cursor feeds `WHERE inserted_at < ?` — yields a different pagination window, no data disclosure beyond what the caller is already authorized to read via `list/2`. Authorization to call `list/2` is the host app's responsibility. Disposition `accept` is correct per D-13. `decode/1` (lines 18-27) validates format via `with` chain; malformed cursors return `{:error, :invalid_cursor}` which `list/2` coerces to `nil` (audit.ex:224-234) — safe fallback to first page. |
| T-9-07 | Tampering (D-27 api.token_verify success not audited) | accept | MITIGATED | Verified in `lib/sigra/api_token.ex:159-190` — only failure paths call `log_safe("api.token_verify.failure", ...)`. Success path does not write an audit row. Trade-off documented in D-27. Observability of successful verifications remains available via telemetry. |
| T-9-08 | Tampering (malicious Oban job args → atom table exhaustion / arbitrary module load) | mitigate | MITIGATED | `lib/sigra/workers/audit_cleanup.ex:36-37` uses `String.to_existing_atom/1` for both `repo` and `audit_schema` from `args`. An attacker who could enqueue a job (already inside the host app's trust boundary) cannot grow the atom table or coerce arbitrary module loads. Also rejected: atoms not already loaded. |
| T-9-09 | Repudiation (false-green tests) | mitigate | MITIGATED | Plan 09-05 mandates `:telemetry_test.attach_event_handlers/2` observability tests and `Repo.aggregate(:count)` rollback assertions. Per VERIFICATION.md §Behavioral Spot-Checks, 1166/1167 tests pass deterministically. The partial hybrid (C-1) is captured as a documented follow-up, not a test lie. |

## Focused Concerns (beyond declared threat register)

### F-A (INFO) — log_multi ArgumentError on reserved prefix is composition-time, not runtime
`lib/sigra/audit.ex:82-86` raises `ArgumentError` during `log_multi/3` composition if a developer passes a reserved prefix. This cannot be triggered by attacker-controlled input in normal Sigra use (action strings are compile-time literals at call sites). No DoS path identified — rejected concern from `<threat_focus>` item 8.

### F-B (INFO) — log_safe error swallowing is intentional and constrained
`log_safe/3` returns `:ok` even on changeset failure (audit.ex:134-142). This is the documented fail-open pattern for non-Multi integration sites (D-36). A malicious developer crafting bad metadata cannot cause auth DoS through this path; at worst they silently lose their own audit row and produce a `log_safe_error` telemetry signal. Not a security regression relative to the threat model but reinforces T-9-05 partial (C-1) rather than creating a new issue.

### F-C (LOW) — Forbidden-key scan does not traverse nested maps
`lib/sigra/audit/changeset.ex:129-133` flat-scans only. A developer (not attacker — metadata is internal-supplied) could accidentally write `metadata: %{details: %{password: "x"}}` and the validator would miss it. All current Sigra-internal call sites use flat metadata, so no in-library exposure. Recommend deep scan in a hardening pass; tracked implicitly by RESEARCH A5.

### F-D (LOW) — Metadata from caller-supplied strings passes through without sanitization
`lib/sigra/api_token.ex:105` `metadata: %{name: attrs.name, scopes: attrs.scopes}` — `attrs.name` is user-supplied. No forbidden-key risk (it's a value, not a key), no injection risk (JSONB/`:map` via Ecto parameter binding), and the 8KB cap bounds DoS. Worst case: an operator reading audit logs in a terminal sees user-controlled text. Acceptable given display is operator-tool responsibility.

### F-E (INFO) — Telemetry leakage surface
`lib/sigra/audit.ex:189-195` emits `[:sigra, :audit, :log]` with `%{action, actor_id, outcome}` — no metadata copy, no IP/UA. The diagnostic `[:sigra, :audit, :log_safe_error]` (line 135-139) includes `cs.errors` which could contain the submitted forbidden-key value in the error message (`"contains forbidden keys: [:password]"` — key name only, not the value; changeset.ex:119-124 does not include the value). Safe. Rejects `<threat_focus>` item 7.

### F-F (INFO) — SQL injection / query composition
`lib/sigra/audit/query.ex` uses parameter pins (`^id`, `^a`, `^pattern`) exclusively. `action_prefix` escapes LIKE wildcards (`escape_like/1`, lines 68-70). No `fragment/2` calls. No string interpolation into queries. Rejects `<threat_focus>` item 5.

### F-G (INFO) — Enumeration timing
`list/2` / `query/1` do not branch on secret-dependent data, and `actor_id` is UUID (not email). Pagination timing is bounded by index scan `(actor_id, inserted_at)`. No enumeration vector. Rejects `<threat_focus>` item 6.

## Unregistered Threat Flags

None. SUMMARY.md §Threat Flags for each wave reports "None" or references only declared threats. 09-04-SUMMARY §Threat Flags and 09-02-SUMMARY §Threat Flags explicitly confirm no new surface.

## Recommendations (non-blocking)

1. **[FOLLOW-UP F-1 from VERIFICATION.md]** Migrate remaining ~82 `log_safe/3` call sites to `__log_internal__/3` + `Ecto.Multi` to close T-9-05 fully. Requires subsystem-test audit-awareness work first.
2. **[F-C / RESEARCH A5]** Harden `Sigra.Audit.Changeset.find_forbidden/1` to traverse nested maps (recursive walk with depth cap). Low-risk accidental-leakage fix; not caller-exploitable in current call sites.
3. **[C-2]** Run tagged `:cursor_portability` test against a real Ecto sandbox on PG and SQLite once the canonical test repo (F-2) lands.
4. **[human_needed from VERIFICATION.md]** Confirm by real-boot smoke that `Sigra.Application` boot warning fires exactly once when `retention_days` is set with Oban absent. Not a mitigation gap — just pending human verification.

## Files Audited (read-only)

- `lib/sigra/audit.ex`
- `lib/sigra/audit/changeset.ex`
- `lib/sigra/audit/cursor.ex`
- `lib/sigra/audit/query.ex`
- `lib/sigra/workers/audit_cleanup.ex`
- `lib/sigra/auth.ex` (audit call sites)
- `lib/sigra/mfa.ex` (audit call sites)
- `lib/sigra/oauth.ex` (audit call sites)
- `lib/sigra/api_token.ex` (audit call sites)
- `lib/sigra/account.ex` (audit call sites)
- `lib/sigra/lockout.ex`, `lib/sigra/suspicious_login.ex`
- `priv/templates/sigra.install/create_audit_events.exs`
- `priv/templates/sigra.install/audit_event.ex`

---

*Audit complete. Verdict: CONCERNS (non-blocking).* No threat in the declared register is unmitigated. Two partial mitigations (T-9-03 flat-scan, T-9-05 hybrid) are documented as follow-ups with explicit owners. No escalation required.
