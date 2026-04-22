# Phase 41: Backup codes & GA product closure — Context

**Gathered:** 2026-04-20  
**Status:** Ready for planning

<domain>

## Phase boundary

Deliver **GA-01**: backup-code **rotation** is a **real** persistence + UX path (no success flash without invalidating old hashes and issuing a new shown-once set), in **library + generated templates + example app**, with **merge-blocking automated proof** that **old codes stop working after rotation**, and **audit semantics that match the success path when audit is configured** (per roadmap success criteria).

Out of scope: GA-02..05 human matrix (phase 42); bulk MFA `log_safe/3` hybrid cleanup beyond this **single** high-value path (AUD-06 continues other MFA sites).

</domain>

<decisions>

## Implementation decisions

### D-41-01 — Re-authentication model (rotation gate)

- **Default policy:** **Do not** accept **consumption of a backup code** as proof to **rotate** backup codes. That pattern is a known footgun (anyone with a leaked sheet can wipe/replace recovery in one action; collapses recovery vs policy-admin semantics). **Explicit host-only opt-in** if ever added — never the generator default.
- **Lost authenticator, still has backup codes:** User may **sign in / recover session** with a backup code (existing login paths). **Rotation** of codes still requires **a possession factor that is not “the codes being rotated”** — i.e. **fresh TOTP** from a **working** enrollment **or** **passkey assertion** (see D-41-02). If they have **no** working TOTP and **no** passkey, they need **account / MFA recovery** (email reset, admin) — honest copy in UI and docs, not a fake rotate button.
- **Layered step-up (target):** (1) **Sudo / privileged session** at the **router** for the MFA settings surface — **align `test/example` with the install golden pattern** (`MFASettingsLive` under `pipe_through [:browser, :require_authenticated, :require_sudo]`). (2) **Inside** the regenerate action, require **either** **WebAuthn/passkey assertion** (when user has enrolled passkeys — preferred, phishing-resistant) **or** **TOTP** — presented as one settings flow with clear CTAs (matches Phase 21 “passkey-first where applicable” spirit on MFA surfaces).
- **Implementation order (coherent rollout):** Ship **transactionally correct rotation + TOTP branch + audit** first if needed for GA-01 velocity; add **passkey branch** in the same phase **before close** when the settings page already hosts passkey ceremonies (low integration cost). Do not ship **TOTP-only forever** as an undocumented weaker posture if passkeys are enabled for the user.

### D-41-02 — Library vs host API contract

- **Orchestrator (library):** Add **`Sigra.MFA.regenerate_backup_codes/4`** — `(config, user, verification, opts)` where **`verification`** is a **tagged** value, minimum **`{:totp, String.t()}`**, extended with **`{:passkey, completed_ceremony_payload}`** (exact shape follows existing `Sigra.Passkeys` / session controller patterns — planner picks struct/map consistent with other MFA settings mutations).
- **Return:** **`{:ok, %{backup_codes: codes}}`** — same envelope as **`mfa_confirm_enrollment`** so `MFASettingsLive` reuses the “show once / download / acknowledge” UX paths already present for enrollment.
- **Errors:** Reuse the same **families** as existing MFA verify/disable paths (`:invalid_code`, `:lockout`, `:not_enrolled`, etc.) so flashes, rate limits, and tests stay uniform.
- **Generated host `Auth` / `Accounts`:** Thin delegate only — **`def mfa_regenerate_backup_codes(user, verification, opts \\ [])`**, merges **`mfa_credential_schema`**, **`backup_code_schema`**, and other MFA opts from **`sigra_config()`** exactly like existing MFA delegates. **No macros.**
- **Persistence:** **`Sigra.MFA.BackupCodes.regenerate/4`** today does **`delete_all` + `insert_all` without an enclosing transaction** — Phase 41 **must** wrap the replace in **`Repo.transaction`** (or **`Ecto.Multi`**) so a failed insert cannot leave **zero** backup rows. This is independent of audit and is part of “honest GA”.

### D-41-03 — Audit: GA-01 vs AUD-06 split

- **When `:audit_schema` is nil / audit disabled:** Single DB transaction for delete + insert; **no** audit row required; tests do not assert audit.
- **When audit is configured:** **Same transaction** must include **`Sigra.Audit.log_multi_safe/3`** (or established `log_multi_safe` + **`emit_telemetry_from_changes/1`** pattern) so **`{:ok, %{backup_codes: _}}` implies** the **`mfa.backup_codes_regenerate`** audit row committed **with** the rotation. **Do not** rely on post-success **`log_safe`** for this path as the “final” implementation — it contradicts “audit rows match success path” and preserves C-1-style hybrid for the **one** operation GA-01 explicitly calls out.
- **AUD-06 scope:** Treat **other** MFA `log_safe` sites (enrollment post-commit, verify backup, disable, trust browser, etc.) as **follow-on batch work** per inventory. **Regenerate** is **not** deferred to AUD-06 once audit is on — Phase 41 owns atomicity for this path.

### D-41-04 — Verification / CI (GA-01 bar)

- **Authoritative merge-blocking proof:** At least **one Postgres-backed integration test** in **`test/example`** (new module, e.g. `*_backup_code_rotation_test.exs`) using **`Example.DataCase`** that: (1) establishes MFA + **known plaintext** backup codes via the **same code paths** production uses, (2) **asserts an old code verifies/consumes successfully before rotation**, (3) calls the **real** `Accounts.mfa_regenerate_backup_codes/3` (or final name), (4) **asserts old plaintext no longer verifies** and DB rows reflect replacement. This is the **GA-01** gate — not Playwright alone.
- **Optional library mirror:** If substantial logic remains testable without the example app, duplicate the **semantic** “old codes dead” assertion under **`test/sigra/**`** — optional, not a substitute for the example integration.
- **LiveView tests:** Thin — event wiring, error flashes, disabled/impersonation paths — **after** context API is stable; **do not** duplicate crypto/DB proofs at LV layer.
- **Playwright (`ga-uat-shift-left.spec.ts`):** Extend to **happy-path smoke** (panel + submit + sees new codes) **after** backend is real — **belt-and-suspenders**, not the GA-01 owner. Update **`docs/uat-ci-coverage.md` SEED-7** to point GA-01’s **cryptographic** closure at **`example_unit_smoke` / `library_tests`**, with Playwright residual narrowed to browser UX if desired.
- **`install_golden`:** Use for **generator parity** (templates + router sudo alignment) — orthogonal to “old codes fail” invariant.

### D-41-05 — Ecosystem & principles (rationale locked for planners)

- **Elixir/Phoenix idioms:** Router **`pipe_through`** for sudo (already used for passkey management routes), **explicit** `Auth` delegates to **`Sigra.MFA`**, **Ecto.Multi + transaction** for atomic writes, **behaviour-ready** extension points later (`step_up` policy module) rather than macro injection — matches Sigra’s published architecture.
- **Lessons from other stacks:** Treat “view/regenerate recovery material” as **high sensitivity** (Django/allauth-style defense in depth). Avoid Devise-era “gem primitive only, no policy” — Sigra ships **opinionated defaults** + clear escape hatches. Okta/GitHub-class products separate **account recovery** from **credential admin** — backup codes stay **recovery-oriented** (Phase 21), not peers for **policy** changes.
- **Principle of least surprise:** Remove the current **misleading success flash** when nothing rotated; any `{:error, _}` maps to honest flash + form state.

### Claude's discretion

- Exact module name for the integration test file and minor metadata keys on the audit row beyond `count`.
- Whether passkey step-up reuses an existing internal helper vs a small new wrapper in `Sigra.MFA` — must remain consistent with wax ceremony error handling elsewhere on MFA settings.

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **GA-01** (Phase 41)
- `.planning/ROADMAP.md` — Phase 41 row + success criteria
- `.planning/PROJECT.md` — v1.4 GA + audit narrative

### Prior phase context

- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-CONTEXT.md` — backup codes visually **recovery** tier; passkey-first MFA challenge patterns
- `.planning/phases/40-tooling-release-ergonomics/40-CONTEXT.md` — semver discipline when adding supported public `lib/` API

### Live code (rotation + audit + templates)

- `lib/sigra/mfa/backup_codes.ex` — `regenerate/4` (must gain transactional wrapper)
- `lib/sigra/mfa.ex` — `audit_backup_codes_regenerate/3` (superseded as **sole** mechanism when audit on — fold into Multi)
- `lib/sigra/audit.ex` — `log_safe/3` vs `log_multi_safe/3` contracts
- `priv/templates/sigra.install/core/mfa_settings_live.ex` — regenerate TODO + UX
- `test/example/lib/example_web/live/mfa_settings_live.ex` — example mirror
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex` — **reference** `require_sudo` placement for `MFASettingsLive` (lines 117–122)
- `test/example/lib/example_web/router.ex` — **must align** sudo posture with golden for `/users/settings/mfa`

### GA / CI mapping

- `docs/uat-ci-coverage.md` — SEED-7 row (update after implementation)

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Sigra.MFA.BackupCodes.regenerate/4`** — already generates codes, telemetry span present; needs transaction + orchestration caller.
- **`Sigra.MFA.audit_backup_codes_regenerate/3`** — audit event name `mfa.backup_codes_regenerate` already chosen.
- **Enrollment UI paths** in `MFASettingsLive` — `%{backup_codes: codes}` render + acknowledge patterns.
- **Install golden router** — sudo + MFA settings scope already models the intended security posture.

### Established patterns

- Generated **`Accounts`** MFA functions pass **`mfa_credential_schema`**, **`backup_code_schema`**, **`sigra_config()`** into **`Sigra.MFA.*`**.
- **Passkey** settings POSTs already use **`require_sudo`** in both example and golden (partial alignment).

### Integration points

- **Example router** — move `MFASettingsLive` into **`require_sudo`** scope to match golden + D-41-01.
- **Generator `router.ex` template** — same alignment for greenfield installs.
- **Playwright** — depends on real rotation handler before expanding assertions.

</code_context>

<specifics>

## Specific ideas

- Subagent research synthesis (2026-04-20): consensus for **transactional rotation**, **no backup-code-as-proof for rotation**, **Multi + `log_multi_safe` when audit on**, and **Example.DataCase integration test** as the GA-01 owner — folded into decisions above. One subagent suggested mirroring **`mfa_disable`** by allowing backup-code verification for rotation; **rejected** for default product posture (see D-41-01).

</specifics>

<deferred>

## Deferred ideas

- **AUD-06:** Remaining MFA `log_safe` hybrid sites (enrollment, verify backup consumption, disable, trust, etc.) — explicit batch after AUD-04 inventory.
- **Optional:** Labelled **escape hatch** for hosts who insist on backup-code-gated rotation — document risk; not generator-default.

</deferred>

---

*Phase: 41-backup-codes-ga-product-closure*  
*Context gathered: 2026-04-20*
