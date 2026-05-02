---
phase: 93
slug: m2m-service-account-tokens-b2b-03
status: verified
threats_open: 0
asvs_level: 2
created: 2026-05-02
updated: 2026-05-02
---

# Phase 93 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> M2M service-account tokens (B2B-03) — RFC 6749 §4.4 `client_credentials` grant
> on Sigra's existing JWT path.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| External HTTP client → `OAuthTokenController.create/2` | Untrusted Basic-auth header + form-encoded `client_id`/`client_secret`/`grant_type`/`scope` cross here. | Untrusted credential pair, untrusted scope string. |
| Controller → `Sigra.OAuth.Token.client_credentials/2` | Already-extracted credentials cross into the library; library does verification. | Verified-shape but unauthenticated credential pair. |
| `Sigra.OAuth.Token` → `Sigra.ServiceAccounts.issue_token/4` → `Sigra.JWT.generate_service_account_tokens/3` | Verified-credential context crosses; the JWT mint owns the audit Multi (D-93-22 / D-93-01 contract). | Trusted SA + credential structs; emits signed JWT + audit row co-fated. |
| External HTTP request bearing JWT → `Sigra.Plug.FetchBearer` | Untrusted JWT crosses; HMAC/RS256 signature + per-credential `revoked_at` + per-SA `token_epoch` checks gate scope construction. | Verified-by-signature claims; only trusted after epoch+revoke checks pass. |
| `FetchBearer` → `Sigra.Scope.build/3` SA branch | Verified claims load the SA row; `scope.active_organization` is read from THE ROW, not the claim — defense against cross-org tampering. | Trusted scope state with `actor_type: :service_account`. |
| Host application code → `Sigra.ServiceAccounts` API | Untrusted attrs map crosses (e.g., `:name`, `:scopes` originate from LiveView form params); changesets validate. | Untrusted maps, validated downstream. |
| `Sigra.ServiceAccounts` → `audit_events` table | Audit metadata payload crosses; D-93-21 metadata schemas + D-23 forbidden-keys defense in `Sigra.Audit.Changeset`. | Sanitised metadata; `client_secret` explicitly omitted. |
| `Sigra.ServiceAccounts.create_credential/4` → caller (LiveView) | Plaintext `client_secret` returned in tuple's third element; the only place the secret exists outside the bcrypt-hashed DB row. | Plaintext credential — display once, never persist. |
| LiveView socket assigns → browser DOM → OS clipboard | `client_secret` crosses into socket assigns then into `navigator.clipboard.writeText` only on explicit click. | Plaintext credential, gated on user gesture. |
| Generator feature flags → emitted source tree | A flag-flip must produce the right artifact set (`--jwt --organizations` gating). | Untrusted flag combo → trusted file emission. |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-93-01 | Information Disclosure | Plaintext `client_secret` in `OrganizationServiceAccountsLive` disclosure modal / recipe / clipboard hook | mitigate | LV `acknowledge_credential` clears `disclosed_credential = nil` (`priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex:263`); modal at lines 539-595 has no backdrop/Esc dismissal; confirm copy at line 591; `CopyToClipboard` hook reads only `dataset.copyText` and logs only error (`copy_to_clipboard_hook.js:31-52`); recipe uses `$SIGRA_CLIENT_SECRET` env-var notation throughout. | closed |
| T-93-02 | Information Disclosure (enumeration) | `Sigra.OAuth.Token.client_credentials/2` enumeration via timing/error codes | mitigate | `Plug.Crypto.secure_compare/2` against `@dummy_hash` even on `client_id` lookup-miss (`lib/sigra/oauth/token.ex:8,45,50,61`); single `:invalid_client` atom for all 5 sub-cases (unknown id, wrong secret, revoked credential, expired credential, revoked SA). | closed |
| T-93-02-EOP | Elevation of Privilege | Non-admin org member access to `/service-accounts` | mitigate | Admin-role gate in LV `handle_params/3` at `organization_service_accounts_live.ex:88-91` redirects non-admins to members page with verbatim flash. Mirrors Members LV / Settings LV gating. | closed |
| T-93-03 | Elevation of Privilege | `Sigra.ServiceAccounts.revoke/3` atomicity + JWT epoch invalidation | mitigate | Atomic Multi bumps `token_epoch` AND sets `revoked_at` AND writes audit in one transaction (`lib/sigra/service_accounts.ex:65-78`); `Sigra.JWT.verify_service_account_epoch/2` enforces both checks on every verify (`lib/sigra/jwt.ex:478-500`); tests at `test/sigra/jwt_test.exs:550-585,587-624`. | closed |
| T-93-04 | Elevation of Privilege | Cross-org tampering of `org_id` JWT claim — FetchBearer SA branch source-of-truth for `active_organization` | accept | See Accepted Risk **AR-93-01** below. Functionally equivalent: signature protects `org_id`, JWT mint sets it from SA row at `lib/sigra/jwt.ex:442`, SA `organization_id` is immutable post-create. | closed |
| T-93-04-SPOOF | Spoofing | Compromised admin session revoking SA without re-auth checkpoint | mitigate | Every destructive LV action gates on inline `current_password` verification (4 mutation handlers at `organization_service_accounts_live.ex:151,209,291,348`); revoke also requires typed-confirm of the SA name. | closed |
| T-93-05 | Information Disclosure | `client_secret` in `service_account.{credential_create,token_issued}` audit metadata | mitigate | D-93-21 metadata builders explicitly omit `client_secret`; only `client_id_prefix` (12 chars) is persisted (`lib/sigra/service_accounts.ex:73-76,120-124,264-270`); D-23 `Sigra.Audit.Changeset` forbidden-keys backstop; E2E asserts `metadata_forbidden_substring: "client_secret"` (`test/example/test/example_web/integration/service_account_e2e_test.exs:111,135`). | closed |
| T-93-06 | Denial of Service / Elevation of Privilege | Rate-limit `/oauth/token` against credential stuffing | accept | See Accepted Risk **AR-93-02** below. Mitigating control: T-93-02 constant-time `secure_compare` already closes the credential-enumeration leak; remaining surface is unbounded request volume, deferred to v1.22. | closed |
| T-93-AUD-01 | Tampering | Audit-row co-fated atomicity for 5 SA mutations (D-AUD-08) | mitigate | Postgres CHECK fault injection proves rollback for `create`/`revoke`/`credential_create`/`credential_revoke`/`token_issued` (`test/sigra/service_accounts_audit_atomicity_test.exs:281,319,355,393,436` — 5 tests, 0 failures). | closed |
| T-93-PAR-01 | Spoofing | Crafted JWT bypasses epoch check if SA branch skips them | mitigate | `Sigra.JWT` actor_type fork routes SA tokens through `verify_service_account_epoch/2` enforcing all 4 checks (`lib/sigra/jwt.ex:453-456`); test 4 in `test/sigra/jwt_test.exs` SA describe block proves epoch_mismatch path. | closed |
| T-93-PAR-02 | Information Disclosure | Stale revoked-SA token continues to authenticate | mitigate | `verify_service_account_epoch/2` + `FetchBearer` checks `service_account.revoked_at == nil` (`lib/sigra/plug/fetch_bearer.ex:128`); test in `fetch_bearer_test.exs` SA describe block. | closed |
| T-93-GEN-01 | Tampering | Generator emission gating regression (`--jwt --organizations`) | mitigate | Three install variants exercised via real `mix sigra.install` invocations + grep assertions on resulting tree, including `OAuthTokenController` gating (`test/sigra/install/service_accounts_generator_test.exs:136-204`). | closed |
| T-93-CC-01 | Information Disclosure | Malformed `CopyToClipboard` hook leaks secret to other DOM nodes / console | mitigate | Hook narrowly scopes to `this.el.dataset.copyText`, calls `navigator.clipboard.writeText` only on explicit click, logs only failures (not the text) to `console.warn` (`priv/templates/sigra.install/organizations/copy_to_clipboard_hook.js:31-52`). | closed |
| T-93-E2E-01 | Tampering | Lifecycle integration bug across create→mint→verify→revoke seams | mitigate | Generated-host E2E walks the full SA lifecycle; SAME credential mints a token AND survives a revocation cycle, asserting `retry_conn.status == 401` post-revoke (`test/example/test/example_web/integration/service_account_e2e_test.exs`, 263 lines, 2/2 pass on re-run 2026-05-02). | closed |
| T-93-E2E-02 | Information Disclosure | Disclosure-modal regression / audit metadata leak across full lifecycle | mitigate | E2E re-renders LV after `acknowledge_credential` and `refute html_after_ack =~ client_secret`; both `service_account.credential_create` AND `service_account.token_issued` audit rows asserted to forbid `client_secret` in metadata (`service_account_e2e_test.exs:111,135` D-93-21 defense-in-depth). | closed |
| T-93-E2E-03 | Repudiation | Audit rows missing `actor_type=service_account` discriminator (SOC2/ISO compliance) | mitigate | E2E asserts `action` AND `actor_type` AND metadata key shape on each lifecycle half (`service_account_e2e_test.exs:133-135,222-232` — D-93-19 + D-93-21). | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-93-01 | T-93-04 | `Sigra.Plug.FetchBearer` SA branch reads `claims["org_id"]` (HMAC/RS256-signed) rather than re-reading `service_account.organization_id` from the row, deviating from Plan 93-02's literal mitigation prose. The deviation is functionally equivalent because: (1) the JWT signature protects `org_id` from post-mint tampering; (2) `Sigra.JWT.generate_service_account_tokens/3` sets the `org_id` claim from `service_account.organization_id` at mint time (`lib/sigra/jwt.ex:442`); (3) `service_account.organization_id` is immutable post-create (no migration or context API exposes a mutator). The cross-org-tamper attack surface is therefore absent. Tracked for explicit cross-org tamper test in a future hardening pass; not a v1.21 blocker. | Jon (qiksnare13@gmail.com) | 2026-05-02 |
| AR-93-02 | T-93-06 | `/oauth/token` is not rate-limited at the framework layer in v1.21. `Sigra.Plug.RateLimit` exists (`lib/sigra/plug/rate_limit.ex:1`, Hammer-backed with Noop fallback) but is intentionally not wired into the OAuth scope at `lib/sigra/install/features/core.ex:734-753` for this release. The credential-enumeration leak is closed by T-93-02's constant-time `secure_compare` (single `:invalid_client` atom for all 5 failure sub-cases); the residual surface is unbounded credential-stuffing request volume, which adopters can mitigate today via reverse-proxy / WAF / CDN rate-limiting at the edge. Sigra ships a planned v1.22 follow-up to wire `Sigra.Plug.RateLimit, scope: :ip, limit: 10, period: 60_000` directly into the generated OAuth pipeline. Documented in: this log, `priv/templates/sigra.install/core/oauth_token_controller.ex` `@moduledoc`, `guides/recipes/m2m-service-accounts.md` "Rate limiting" section, and `CHANGELOG.md` [Unreleased]. | Jon (qiksnare13@gmail.com) | 2026-05-02 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-02 | 16 | 16 (14 mitigate + 2 accept) | 0 | Claude (gsd-security-auditor) via `/gsd-secure-phase 93` |

### 2026-05-02 — initial audit (State B)

- **Inputs:** 10 PLAN.md threat models (`93-01` through `93-10`), 10 SUMMARY.md threat-flag sections, 93-VERIFICATION.md (status: complete, 22/22), 93-REVIEW.md (CR-01 + CR-02 closed in commit `bf5a8a8`).
- **Result:** 14 threats CLOSED with cited file:line evidence; 2 threats accepted with documented rationale (T-93-04 deviation, T-93-06 deferral).
- **Implementation gates re-verified:** `MIX_ENV=dev mix compile --warnings-as-errors` exit 0; 79 library tests pass; 2/2 generated-host E2E tests pass.
- **Cross-checks:**
  - REVIEW.md CR-01 (auth bypass at `oauth/token.ex:62`) — fix verified at `lib/sigra/oauth/token.ex:65,73-80`.
  - REVIEW.md CR-02 (catch-all rescue) — non-STRIDE finding, tracked separately, does not reopen any threat.
  - REVIEW.md WR-01..WR-04 / IN-01..IN-03 — no STRIDE re-opening; tracked separately as code-quality findings.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-02
