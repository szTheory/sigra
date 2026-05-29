---
phase: 140-deprecation-hygiene-verification-docs-close
reviewed: 2026-05-29T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - guides/recipes/deployment.md
  - lib/sigra/account.ex
  - lib/sigra/doctor.ex
  - lib/sigra/mfa/trust.ex
  - lib/sigra/optional_deps.ex
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 140: Code Review Report

**Reviewed:** 2026-05-29
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 140 is a documentation-and-annotation-hygiene phase. The actual diff against
`4963efa` is narrow and behavior-free:

- `lib/sigra/account.ex` — appended `"Scheduled for removal in 0.5.0."` to the
  `@deprecated` string on `audit_forced_password_change/2`.
- `lib/sigra/mfa/trust.ex` — appended `"Scheduled for removal in 0.4.0."` to both
  the `@doc deprecated:` and `@deprecated` strings on `cookie_opts/0`.
- `lib/sigra/doctor.ex` — replaced backtick-wrapped fully-qualified references to
  hidden (`@doc false`) `Sigra.Application` functions with plain prose to clear
  ExDoc broken-link warnings (`mix docs --warnings-as-errors`).
- `lib/sigra/optional_deps.ex` — same broken-link prose fix.
- `guides/recipes/deployment.md` — appended an `## Operator diagnostics` section
  documenting `mix sigra.doctor`.

I verified each change against the surrounding live code. No runtime behavior is
changed and no security regression is introduced. I confirmed the exit-code
contract and the four state labels in the new `deployment.md` section against the
actual `Mix.Tasks.Sigra.Doctor` formatter and `Sigra.Doctor.diagnose/1` — both
match (the task renders the internal `:loaded_active` state as the user-visible
label `loaded`, which is what the doc states). I confirmed the prose fixes in
`doctor.ex`/`optional_deps.ex` no longer leave any backtick-linked reference to a
`@doc false` function; the one remaining auto-link target,
`Sigra.OptionalDeps.encryption_active?/1`, is public and therefore linkable.

The one substantive concern is a version-axis conflict that this phase's
deprecation strings make user-visible in rendered docs.

## Warnings

### WR-01: Deprecation removal target precedes the function's `@doc since:` version on a conflicting version axis

**File:** `lib/sigra/mfa/trust.ex:42-44`, `lib/sigra/account.ex:542-543`
**Issue:**
Both deprecated functions now carry a `@doc since:` and a `Scheduled for removal in …`
target that live on two *different* version axes, producing a rendered docstring
that says a function is removed before it was introduced:

- `cookie_opts/0`: `@doc since: "0.6.0"` (line 42) + `Scheduled for removal in 0.4.0`
  (lines 43-44) → "available since 0.6.0, removed in 0.4.0".
- `audit_forced_password_change/2`: `@doc since: "0.9.0"` (line 542) + `Scheduled
  for removal in 0.5.0` (line 543) → "available since 0.9.0, removed in 0.5.0".

The removal targets were a deliberate, user-confirmed decision on the **Hex SemVer
axis** (current Hex `@version` is `0.3.0` in `mix.exs:4`; the phase context
`140-CONTEXT.md` D-02/D-03 explicitly chose 0.4.0/0.5.0 as forthcoming minors).
The problem is the `@doc since:` values, which across the whole library range up to
`0.11.0` (see `grep "@doc since:" lib/`) while Hex is at `0.3.0` — i.e. `since:` is
keyed to the *internal planning/milestone* axis, not Hex SemVer. ExDoc renders both
`since` and `deprecated` on the same function header, so an external reader of the
published docs sees a self-contradictory timeline. This is a public-contract clarity
defect, not a runtime bug, hence WARNING rather than BLOCKER.

This is also internally inconsistent with the phase's own framing: `140-CONTEXT.md`
says "Express targets as Hex SemVer 0.x minors," but leaves the `since:` annotations
(planning axis) untouched on the same functions, so the two annotations now openly
contradict each other in the rendered output that Gate 8 proves is published.

**Fix:**
Reconcile the two annotations onto one axis. Lowest-touch option that keeps the
user-confirmed Hex-SemVer removal targets is to correct the stale `@doc since:`
values to the Hex axis on just these two functions:

```elixir
# lib/sigra/mfa/trust.ex — cookie_opts/0
@doc since: "0.2.0"   # the Hex version this stub actually shipped in (verify against CHANGELOG)
@doc deprecated: "Use cookie_opts/1 ... Scheduled for removal in 0.4.0."
@deprecated "Use cookie_opts/1 ... Scheduled for removal in 0.4.0."

# lib/sigra/account.ex — audit_forced_password_change/2
@doc since: "0.2.5"   # the Hex version it actually shipped in (verify against CHANGELOG)
@deprecated "Use clear_password_change_requirement/3 ... Scheduled for removal in 0.5.0."
```

If instead the intent is to keep removal targets readable in the published docs
without claiming an introduction version newer than the removal version, drop the
removal version from the SemVer axis and phrase it relatively (e.g. "scheduled for
removal in the next minor / in the minor after next"). Either way, the two version
annotations on each function must stop contradicting each other. The broader
library-wide `@doc since:` axis mismatch is pre-existing and out of scope here; only
these two functions need fixing because this phase added the conflicting second
annotation to them.

## Info

### IN-01: Public function `oban_running?/1` described as "internal" in doctor.ex prose

**File:** `lib/sigra/doctor.ex:30, 39, 63`
**Issue:**
The broken-link fix rewrote references to `Sigra.Audit.Forwarders.oban_running?/1`
as "the internal `oban_running?/1` in `Sigra.Audit.Forwarders`". But that function
is *not* `@doc false` — it is a public, `@spec`'d function
(`lib/sigra/audit/forwarders.ex:89-90`). Unlike `verify_vault!/1` and
`attach_forwarders/0` (which genuinely are `@doc false`), the original backtick
auto-link to `oban_running?/1` would not have produced a broken-link ExDoc warning,
and calling it "internal" is inaccurate. This is a cosmetic over-correction made
while clearing the genuine warnings on the two truly-hidden functions; harmless to
behavior.
**Fix:** Restore the auto-link for the public function (it links cleanly), or drop
the word "internal" for it: e.g. "…the `oban_running?/1` mirror in
`Sigra.Audit.Forwarders`". Keep the "internal" qualifier only for the genuinely
`@doc false` functions (`verify_vault!/1`, `attach_forwarders/0`).

### IN-02: Duplicate deprecation string maintained in two annotations on cookie_opts/0

**File:** `lib/sigra/mfa/trust.ex:43-44`
**Issue:**
`cookie_opts/0` carries the identical deprecation message in both `@doc deprecated:`
(line 43) and `@deprecated` (line 44). The phase edited both copies in lockstep, so
they currently agree, but the duplication is a maintenance hazard: a future edit to
one string (e.g. changing the removal target) can silently drift from the other,
and ExDoc/compiler will not flag the mismatch. This pattern is unique to this
function — `audit_forced_password_change/2` uses only `@deprecated`.
**Fix:** Keep `@deprecated` (drives the compiler deprecation warning) as the single
source and let it also populate the ExDoc "deprecated" callout, or if both are
intentionally required for the rendering you want, add a one-line comment noting the
two strings must be kept identical so future maintainers update both.

---

_Reviewed: 2026-05-29_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
