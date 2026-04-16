# Requirements: Sigra v1.2 Admin Dashboard

**Defined:** 2026-04-16
**Core Value:** Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence, without wiring together 4+ libraries or maintaining security-sensitive code themselves.

## v1.2 Requirements

### Admin Access Foundation

- [ ] **ADMIN-01**: Developer can install a default-on admin surface, and opt out with `--no-admin`, using the existing generator feature-manifest pattern.
- [ ] **ADMIN-02**: Host app can define who is a platform admin and who is an org admin through an explicit policy contract; Sigra never infers admin access from signup order or hidden defaults.
- [ ] **ADMIN-03**: Admin routes, LiveViews, exports, and mutation endpoints enforce admin access server-side; hiding UI controls alone is never the protection boundary.
- [ ] **ADMIN-04**: Org admins can only see and act on users, sessions, memberships, and audit data inside their allowed organization scope; platform admins can access cross-org views explicitly.
- [ ] **ADMIN-05**: Admin navigation and page chrome make the active scope visible so operators can tell whether they are acting globally or within an organization.

### User Operations

- [ ] **USER-01**: Admin can find a user quickly by email, id, name, or organization membership through searchable, paginated admin views.
- [ ] **USER-02**: Admin can filter the user list by the auth and support states that matter operationally: confirmation, MFA/passkey status, lockout state, deletion state, provider mix, and registration date range.
- [ ] **USER-03**: Admin can open a user detail surface that summarizes the user's current sign-in and security state, including sessions, MFA/passkeys, linked identities, organizations, and recent audit activity.
- [ ] **USER-04**: Admin can revoke one session or all active sessions for a user from the admin UI with clear confirmation and audit coverage.
- [ ] **USER-05**: The admin user-management surface works well on mobile and desktop for the main jobs-to-be-done, not just as a compressed desktop table.

### Impersonation

- [ ] **IMPR-01**: Platform admin can start an impersonation session for an allowed user through a controller-owned flow that rotates session state and preserves the real admin as the actor.
- [ ] **IMPR-02**: Org admin can impersonate only users within their allowed organization scope; out-of-scope impersonation attempts fail server-side and audit as denied.
- [ ] **IMPR-03**: Every impersonation session is time-bounded, non-nestable, and visibly marked with a persistent banner plus an always-available end-session action.
- [ ] **IMPR-04**: While impersonating, Sigra forbids sensitive account-security mutations server-side, including password changes, MFA/passkey management, API-key management, and account deletion.
- [ ] **IMPR-05**: Ending impersonation returns the admin to their original context without destroying the original admin session.

### Audit Exploration

- [ ] **AUD-01**: Audit records generated during admin and impersonation workflows preserve the real actor, effective user, organization scope, and impersonation context as canonical queryable fields.
- [ ] **AUD-02**: Admin can investigate audit history from global, per-user, and per-organization views using URL-addressable filters for actor, effective user, organization, action family, and time range.
- [ ] **AUD-03**: Admin can distinguish impersonation activity from normal user activity in the audit explorer without reading raw metadata blobs.
- [ ] **AUD-04**: Admin can export the currently filtered audit slice as evidence in a stable, scope-respecting format such as CSV.

### Verification and Review Artifacts

- [ ] **VFY-01**: Sigra ships automated browser/system coverage for critical admin flows, including user search/detail, session revocation, impersonation start/stop, and audit filtering/export.
- [ ] **VFY-02**: The admin milestone produces review artifacts that make UX progress easy to inspect asynchronously, including Playwright HTML reports plus screenshots, traces, and retained video where useful.
- [ ] **VFY-03**: Automated verification covers both browser and direct-path behavior so authorization, scope, impersonation, and export rules are proven outside the browser happy path.
- [ ] **VFY-04**: Automated review coverage includes mobile and dark-mode checkpoints for the admin UI so responsive and low-light usability regressions are visible in CI artifacts.

## Future Requirements

### Admin Enhancements

- **ADMIN-06**: Admin can perform carefully-scoped bulk operations such as lock, unlock, or password-reset on multiple users at once.
- **ADMIN-07**: Admin dashboard includes richer analytics widgets beyond operational counters and recent security events.
- **ADMIN-08**: Admin branding expands into a full theming system with runtime customization.

### Impersonation Enhancements

- **IMPR-06**: Impersonation can require reason capture, approval workflows, or read-only mode for stricter environments.

### Audit Enhancements

- **AUD-05**: Large audit exports can run asynchronously through background jobs with delivery notifications.

### Verification Enhancements

- **VFY-05**: Sigra publishes a richer long-lived artifact portal or visual diff workflow beyond the base Playwright report bundle.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Generic back-office CMS or business admin tooling | v1.2 is an auth-first admin surface, not a broad internal-tools platform |
| SPA frontend or separate admin frontend stack | Existing Phoenix/LiveView stack is sufficient and avoids split architecture |
| Third-party admin framework or impersonation package | Sigra needs library-owned security semantics and generated-code ergonomics |
| Search backend such as Elasticsearch/OpenSearch for audit v1.2 | Postgres/Ecto should carry the initial investigation and export workflows |
| Full theming engine | Basic branding hooks are enough for the internal/admin use case |
| Broad bulk user operations in the first admin release | High risk, high verification burden, and not central to the first JTBD slice |
| Human-only UAT as the primary release gate | This milestone is explicitly automation-first; manual review should be lightweight and artifact-driven |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ADMIN-01 | Phase 27 | Pending |
| ADMIN-02 | Phase 27 | Pending |
| ADMIN-03 | Phase 27 | Pending |
| ADMIN-04 | Phase 27 | Pending |
| ADMIN-05 | Phase 27 | Pending |
| USER-01 | Phase 28 | Pending |
| USER-02 | Phase 28 | Pending |
| USER-03 | Phase 28 | Pending |
| USER-04 | Phase 28 | Pending |
| USER-05 | Phase 28 | Pending |
| IMPR-01 | Phase 29 | Pending |
| IMPR-02 | Phase 29 | Pending |
| IMPR-03 | Phase 29 | Pending |
| IMPR-04 | Phase 29 | Pending |
| IMPR-05 | Phase 29 | Pending |
| AUD-01 | Phase 30 | Pending |
| AUD-02 | Phase 30 | Pending |
| AUD-03 | Phase 30 | Pending |
| AUD-04 | Phase 30 | Pending |
| VFY-01 | Phase 31 | Pending |
| VFY-02 | Phase 31 | Pending |
| VFY-03 | Phase 31 | Pending |
| VFY-04 | Phase 31 | Pending |

**Coverage:**
- v1.2 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-16*
*Last updated: 2026-04-16 after v1.2 research synthesis*
