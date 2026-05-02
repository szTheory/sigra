# SECURITY — Phase 93: M2M Service Account Tokens (B2B-03)

**Audit date:** 2026-05-02
**ASVS level:** 2
**Block-on:** critical (open mitigations block ship)
**Phase status:** OPEN_THREATS — 1 BLOCKER (T-93-06) + 1 partial deviation (T-93-04)
**Total threats:** 16 (15 declared `mitigate`; 1 declared `mitigate or defer with documentation`)
**Threats CLOSED:** 14/16
**Threats OPEN:** 2/16

---

## Threat verification matrix

| ID | Category | Disposition | Status | Evidence |
|----|----------|-------------|--------|----------|
| T-93-01 | Information Disclosure (disclosure modal) | mitigate | CLOSED | LiveView modal `acknowledge_credential` clears `disclosed_credential = nil` at `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex:263`; modal at lines 539-595 has NO backdrop close form (other modals at 482, 533, 644, 686 do); confirm-button copy `I've saved this credential — close` at line 591 |
| T-93-01 (recipe arm) | Information Disclosure (curl examples) | mitigate | PARTIAL | `guides/recipes/m2m-service-accounts.md:36,46` uses `$SIGRA_CLIENT_SECRET` env-var notation (good). MISSING the explicit "Copy the `client_secret` IMMEDIATELY — it is never readable again" warning required by Plan 93-05 line 594. Disclosure-modal walkthrough section is absent. (Non-blocking — primary mitigation in LV template is closed.) |
| T-93-02 | Information Disclosure (enumeration) | mitigate | CLOSED | `lib/sigra/oauth/token.ex:8` precomputed `@dummy_hash`; `secure_compare` against dummy on lookup-miss (line 45), revoked-credential branch (line 50), and expired-credential branch (line 61); `:invalid_client` returned from all 5 sub-cases (lines 46, 51, 62, 78, 87). Tests: `grep -c ":invalid_client" test/sigra/oauth/token_test.exs` = 2 occurrences across constant-time test block, plus `lib/sigra/oauth/token.ex` has 10 `:invalid_client`/`secure_compare` matches |
| T-93-02-EOP | Elevation of Privilege (non-admin /service-accounts) | mitigate | CLOSED | Admin-role gate at `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex:88-91` with verbatim flash `You don't have permission to manage service accounts.` and redirect to members page |
| T-93-03 | Elevation of Privilege (revoke atomicity + JWT epoch) | mitigate | CLOSED | `lib/sigra/service_accounts.ex:65-78` wraps `Multi.update :service_account` (sets `revoked_at` + bumps `token_epoch`) AND `append_audit` in single `config.repo.transaction`; `lib/sigra/jwt.ex:478-500` `verify_service_account_epoch/2` rejects on `revoked_at != nil`, credential `revoked_at != nil`, expired credential, OR epoch mismatch with single `:epoch_mismatch` atom. Test proof: `test/sigra/jwt_test.exs:550-585` (revoke→epoch_mismatch) + 587-624 (credential revoke→error) |
| T-93-04 | Elevation of Privilege (cross-org claim tampering) | mitigate | DEVIATION (low risk) | **Plan literal text:** "uses `sa.organization_id` from the row — NOT the `org_id` claim — to populate scope.active_organization." **Implementation:** `lib/sigra/plug/fetch_bearer.ex:129` reads `claims["org_id"]` (signed claim), NOT `service_account.organization_id`. Functionally equivalent because (a) the JWT signature covers `org_id`, so post-signing tampering invalidates the token (HS256/RS256), and (b) `org_id` is set from `service_account.organization_id` at mint time (`lib/sigra/jwt.ex:442`), and SA `organization_id` is immutable in this implementation (no update path exposed). However, Plan 93-02 line 374 grep gate `grep -c "T-93-04\|invalid_token\|tamper" test/sigra/jwt_test.exs >= 1` returns 4 matches (incidental — there is no explicit T-93-04 cross-org test asserting that re-encoding `org_id` after signing fails verify). Recommend: add explicit cross-org test, OR change FetchBearer to read `service_account.organization_id` from the loaded SA row to match the plan's stated mitigation literally |
| T-93-04-SPOOF | Spoofing (compromised admin session) | mitigate | CLOSED | All 4 mutation paths require `current_password` re-verification: `priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex:151` (create_service_account), `:209` (create_credential), `:291` (revoke_service_account), `:348` (revoke_credential). `revoke_service_account` additionally requires `typed_confirm` matching SA name (line 291) |
| T-93-05 | Information Disclosure (audit metadata) | mitigate | CLOSED | `lib/sigra/service_accounts.ex:120-124` (credential_create metadata: only `service_account_id`, `client_id_prefix`, `expires_at`); `:73-76` (revoke metadata: `service_account_id`, `name`); `:264-270` (token_issued metadata: `service_account_id`, `credential_id`, `client_id_prefix`, `scopes`, `ip_address`); `client_id_prefix/1` at `:454-455` truncates to 12 chars. No `client_secret` key constructed anywhere in metadata builders. E2E proof: `test/example/test/example_web/integration/service_account_e2e_test.exs:111,135` asserts `metadata_forbidden_substring: "client_secret"` on both `credential_create` and `token_issued` audit rows |
| T-93-06 | DoS / EoP (rate-limit /oauth/token) | mitigate-or-defer-with-doc | **OPEN — BLOCKER** | `lib/sigra/install/features/core.ex:734-753` adds `/oauth/token` route with `pipe_through :api` only — NO rate-limit plug wired. `Sigra.Plug.RateLimit` exists at `lib/sigra/plug/rate_limit.ex:1` (Hammer-backed with Noop fallback) but is unused on this route. Controller `@moduledoc` at `priv/templates/sigra.install/core/oauth_token_controller.ex:2-6` does NOT contain the documented v1.22 deferral note required by Plan 93-03 line 406-413. Recipe at `guides/recipes/m2m-service-accounts.md` and `CHANGELOG.md` also do not document the deferral. Plan explicitly required EITHER rate-limit wired OR deferral note present — neither is present. See Required Action #1 |
| T-93-AUD-01 | Tampering (audit-row co-fated atomicity) | mitigate | CLOSED | `test/sigra/service_accounts_audit_atomicity_test.exs` covers all 5 SA mutations via Postgres CHECK fault injection — 5 tests at lines 281, 319, 355, 393, 436. Each asserts no partial row commits when audit insert fails. `lib/sigra/service_accounts.ex:65-78, 112-127, 160-175` all wrap mutation + audit in one `Multi`/`config.repo.transaction` |
| T-93-PAR-01 | Spoofing (crafted JWT bypasses epoch on SA branch) | mitigate | CLOSED | `lib/sigra/jwt.ex:453-456` forks on `claims["actor_type"]`; SA branch routes to `verify_service_account_epoch/2` at `:478-500` which checks `revoked_at`, credential `revoked_at`, expiry, AND epoch. Tests: `test/sigra/jwt_test.exs:550-585, 587-624` |
| T-93-PAR-02 | Information Disclosure (stale revoked-SA token authenticates) | mitigate | CLOSED | Same code as T-93-PAR-01 plus `lib/sigra/plug/fetch_bearer.ex:122-145` SA branch checks `service_account.revoked_at == nil` (line 128). Tests: `test/sigra/plug/fetch_bearer_test.exs:456-486` (valid SA scope), `:488-497` (expired SA JWT → nil scope) |
| T-93-GEN-01 | Tampering (generator emission-gating regression) | mitigate | CLOSED | `test/sigra/install/service_accounts_generator_test.exs` exercises 3 install variants (`--jwt --organizations`, `--jwt --no-organizations`, `--no-jwt --organizations`) via real `mix sigra.install`, asserts SA artifacts (incl. OAuthTokenController + router route) absent under `--no-organizations` (lines 136-204) |
| T-93-CC-01 | Information Disclosure (clipboard hook) | mitigate | CLOSED | `priv/templates/sigra.install/organizations/copy_to_clipboard_hook.js:31-52`: reads only `this.el.dataset.copyText` (line 31), calls `navigator.clipboard.writeText(text)` only inside the click listener (line 39), `console.warn` logs only the error object (line 51) — never `text` |
| T-93-E2E-01 | Tampering (lifecycle integration) | mitigate | CLOSED | `test/example/test/example_web/integration/service_account_e2e_test.exs` runs full create→mint→revoke→retry-401 lifecycle (per file purpose at lines 1-18) |
| T-93-E2E-02 | Information Disclosure (modal regression + audit leak) | mitigate | CLOSED | E2E test asserts `metadata_forbidden_substring: "client_secret"` on both `service_account.credential_create` (line 111) and `service_account.token_issued` (line 135) audit rows |
| T-93-E2E-03 | Repudiation (missing actor_type=service_account) | mitigate | CLOSED | E2E test asserts `actor_type_col: "service_account"` on `token_issued` (line 133-135) and `api.token_verify.failure` (line 222-232) audit rows |

---

## Open / partially open threats — required actions

### T-93-06 — OPEN BLOCKER

**Threat:** Credential-stuffing against `/oauth/token` is unbounded. An attacker with a known `client_id` (or just guessing prefixes) can hammer the endpoint at full TCP throughput.

**Plan disposition:** `mitigate (or defer with documentation)`

**Current state in code:**
- `lib/sigra/install/features/core.ex:734-753` emits `/oauth/token` route with `pipe_through :api` — no rate-limit plug.
- `lib/sigra/plug/rate_limit.ex` EXISTS as a usable Hammer-backed library plug.
- `priv/templates/sigra.install/core/oauth_token_controller.ex:2-6` `@moduledoc` does NOT contain the deferral note Plan 93-03 line 406-413 prescribed.
- `guides/recipes/m2m-service-accounts.md` and `CHANGELOG.md` do not document this as accepted/deferred risk.

**Required action — choose one:**

1. **Wire `Sigra.Plug.RateLimit`** into the `/oauth/token` pipeline at `lib/sigra/install/features/core.ex:734-753`. Recommended: `:limit 10, :window 60_000` per Plan 93-03 line 590. Add a host-app pipeline like:
   ```elixir
   pipeline :sigra_oauth_token do
     plug :accepts, ["json"]
     plug Sigra.Plug.RateLimit, limit: 10, window: 60_000, error_handler: <App>.Auth.JsonErrorHandler
   end
   ```
   Or document a direct `plug` line inside the route scope.

2. **Document T-93-06 as accepted v1.22 follow-up** in:
   - `priv/templates/sigra.install/core/oauth_token_controller.ex` `@moduledoc` (per Plan 93-03 line 408-413 verbatim text)
   - `guides/recipes/m2m-service-accounts.md` (new "Operational hardening" section recommending host-app rate-limit)
   - `CHANGELOG.md` (under v1.21 known limitations)
   - This `SECURITY.md` accepted-risks log (see template below)

### T-93-04 — DEVIATION (low actual risk; doc-vs-code mismatch)

**Threat:** Cross-org tampering by mutating the `org_id` claim post-signing.

**Plan disposition:** `mitigate` — Plan 93-02 lines 25, 168, 445 prescribe reading `sa.organization_id` from the SA row.

**Current state in code:**
- `lib/sigra/plug/fetch_bearer.ex:129` reads `claims["org_id"]` (signed) instead of `service_account.organization_id` (loaded).
- Equivalent defense via signature: post-signing mutation of `org_id` invalidates HS256/RS256 signature → `Sigra.JWT.verify_access` returns `:invalid_token`.
- However, no explicit test asserts post-signing `org_id` tampering returns `:invalid_token`. The grep gate (`grep -c "T-93-04\|invalid_token\|tamper" test/sigra/jwt_test.exs`) returns 4 incidental matches but no test name references T-93-04 or "tamper".

**Required action — choose one:**

1. **Bring code into compliance with plan** — change `lib/sigra/plug/fetch_bearer.ex:129` from `load_organization(config, claims["org_id"])` to `load_organization(config, service_account.organization_id)` (using the row already loaded on line 127). This is a one-line change and matches the plan literally.

2. **Add explicit T-93-04 test** to `test/sigra/jwt_test.exs` that takes a freshly minted SA JWT, splits it on `.`, base64-decodes the payload, mutates `org_id`, re-encodes WITHOUT re-signing, and asserts `JWT.verify_access(cfg, tampered_jwt) == {:error, :invalid_token}`. AND amend SECURITY.md to record the deviation as accepted (this file).

---

## Accepted risks log

_None recorded yet. If T-93-06 is deferred (option 2), add the entry below in this section:_

```
| Risk ID | Threat | Decision | Owner | Re-eval date |
|---------|--------|----------|-------|--------------|
| AR-93-06 | T-93-06 OAuth token endpoint has no Sigra-wired rate limit | DEFERRED to v1.22 — host apps responsible for rate-limiting /oauth/token until Sigra ships first-class wiring. Attack surface bounded by HTTPS + host infrastructure (Cloudflare/Nginx/ELB). | <maintainer> | v1.22 release |
```

---

## Unregistered flags (from SUMMARY ## Threat Flags)

| Plan | Flag content | Mapping |
|------|-------------|---------|
| 01-08, 10 | (no `## Threat Flags` section emitted) | n/a — no new attack surface declared |
| 07 | "None. These are test files only; no new production code was added." | n/a |
| 09 | "No new network endpoints, auth paths, or trust boundary changes introduced by this plan. All mutations route through `Sigra.ServiceAccounts` functions (established in 93-01) with sudo re-verification before each write." | Maps to T-93-02-EOP, T-93-04-SPOOF (already in register) |

**No unregistered flags.** All declared attack surface from SUMMARYs maps cleanly to existing threat IDs.

---

## Auxiliary observations (non-STRIDE; informational)

- **CR-01 closure verified:** `lib/sigra/oauth/token.ex:65, 73-80` correctly bind `verify_secret(stored_hash, submitted_hash, credential)` and `Token.secure_compare(stored_hash, submitted_hash)`. The earlier auth-bypass (passing `submitted_hash` twice) is fixed by commit `bf5a8a8`.
- **22/22 truths in `93-VERIFICATION.md`** post-`bf5a8a8` confirms test execution; security audit overlays the threat-model dimension.
- **REVIEW.md WR-01..WR-04 + INFO items** are non-STRIDE code-quality findings. They do not reopen any threat in this register. Track separately.

---

## Verdict

**Recommend:** Do NOT ship phase 93 as-is.
- T-93-06 must resolve to "wired" or "documented accepted risk in this file" before merge.
- T-93-04 deviation is low actual risk (signature-protected) but should be reconciled (1-line code change OR explicit test + accepted deviation note here) for traceability.

After resolution, re-run `/gsd-secure-phase 93` to update this file and flip status to SECURED.
