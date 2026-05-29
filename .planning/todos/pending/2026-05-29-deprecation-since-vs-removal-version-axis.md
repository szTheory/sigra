---
created: 2026-05-29T00:00:00.000Z
title: Reconcile @doc since vs "Scheduled for removal" version axes on deprecated functions
area: lib (deprecation annotations) + versioning policy
files:
  - lib/sigra/mfa/trust.ex
  - lib/sigra/account.ex
---

## Context

Deferred during Phase 140 code review (140-REVIEW.md, WR-01 — Warning).
NOT fixed in-phase because the fix requires a versioning-policy decision, not a
mechanical edit, and the removal targets were a locked D-01/D-04 decision that
Phase 140 deliberately implemented. Tracked here so it is not lost; the natural
home for resolution is `/gsd-complete-milestone`, alongside the branch-name /
STATE.md version reconciliation already deferred there via D-12.

## Finding (WR-01)

The two live `@deprecated` functions now carry annotations on two different
version axes, producing a contradictory rendered ExDoc header (removal *before*
introduction):

- `Sigra.MFA.Trust.cookie_opts/0` — `@doc since: "0.6.0"` + "Scheduled for
  removal in 0.4.0".
- `Sigra.Account.audit_forced_password_change/2` — `@doc since: "0.9.0"` +
  "Scheduled for removal in 0.5.0".

Root cause: two coexisting version axes in the codebase.
- **Hex-published SemVer axis** — current Hex version is `0.3.0` (mix.exs:4).
  The removal targets (0.4.0, 0.5.0) were chosen on this axis (D-01/D-04).
- **Internal milestone/planning axis** — `@doc since:` values across the library
  run up to 0.11.0, keyed to the milestone numbering (v1.30 etc.), NOT the Hex
  release axis.

Gate 8 of the Phase 140 proof bundle actively proves the contradictory output is
published in the generated `doc/` tree.

## Decision needed (do NOT guess-fix)

Pick the canonical axis and reconcile, library-wide, one of:
1. `since:` values are wrong → re-key all `@doc since:` to the Hex SemVer axis
   (large, library-wide change — every annotated function, not just these two).
2. Removal targets should move to the milestone axis (contradicts the locked
   D-01/D-04 Hex-SemVer decision — unlikely correct).
3. Accept as-is and document the dual-axis convention in MAINTAINING.md so the
   rendered "since X / removal Y" inversion is understood as intentional.

Severity: documentation-clarity only. No runtime or security impact. Public-
contract clarity defect, not a bug.

## Lower-priority context (Info, no action required)

- **IN-01:** the Gate-5 broken-link prose fix labels the *public*
  `Sigra.Audit.Forwarders.oban_running?/1` as "internal." Unlike `verify_vault!/1`
  and `attach_forwarders/0` (genuinely `@doc false`), `oban_running?/1` is public
  and was never producing a broken-link warning — a mild over-correction in
  `lib/sigra/doctor.ex` prose. Optional cleanup.
- **IN-02:** `cookie_opts/0` keeps the identical deprecation string in both
  `@doc deprecated:` and `@deprecated`; a maintenance drift hazard. Phase 140
  edited them in lockstep, so currently consistent.

## Decision (v1.30 milestone close, 2026-05-29)

Resolved to **Option 3 — accept + document** at `/gsd-complete-milestone v1.30`.
Rationale: the removal targets (0.4.0 / 0.5.0) are correct on the authoritative
Hex SemVer axis; only the `@doc since:` labels sit on the internal milestone axis.
Re-keying every `since:` library-wide (Option 1) is real churn and out of scope
for a low-code consolidation close. The dual-axis convention is now documented in
`MAINTAINING.md` → "Dual version axes" so the rendered inversion reads as
intentional. **This todo stays open** as the tracking home for a future
dedicated library-wide `@doc since:` → Hex-axis reconciliation (do NOT guess-fix;
it remains a deliberate, separate change). No v1.30 code edit.
