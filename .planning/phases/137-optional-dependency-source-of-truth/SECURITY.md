# SECURITY — Phase 137: Optional Dependency Source of Truth

**Audit date:** 2026-05-29
**Disposition:** SECURED — 9/9 threats CLOSED
**ASVS Level:** default
**Nature:** Pure refactor consolidating scattered `Code.ensure_loaded?(Mod)` runtime guards into `Sigra.OptionalDeps` SOT. No new external trust boundary.

## Threat Verification

| Threat ID | Category | Disposition | Status | Evidence |
|-----------|----------|-------------|--------|----------|
| T-137-01 | Information Disclosure | mitigate | CLOSED | `lib/sigra/optional_deps.ex:198-207` — `encryption_active?/1` is config-driven, uses `module.__sigra_encryption_mode__() != :stub` (line 205), NOT `Code.ensure_loaded?(Cloak)`. Mirrors `application.ex:194-195` (`== :stub`) and replicates `encrypted_binary_module/1` derivation exactly (`optional_deps.ex:212-224` vs `application.ex:218-230`). `git grep "Code.ensure_loaded?(Cloak)" lib/` finds only doc references (lines 37, 192), no actual call. Stub → false confirmed by code path. |
| T-137-02 | Tampering | mitigate | CLOSED | All 9 predicates are one-to-one un-memoized `Code.ensure_loaded?(Mod)` wrappers (`optional_deps.ex:79,91,101,112,123,134,145,156,170`). Header comment (lines 65-68) asserts NO caching/ETS/persistent_term; no such constructs present in module body. Drift-catching equality tests in `test/sigra/optional_deps_test.exs`. |
| T-137-03 | Information Disclosure (timing) | mitigate | CLOSED | `crypto.ex:244-251` else-branch `no_user_verify(); false` byte-preserved; only guard token swapped. `hashers/bcrypt.ex:39-45` Argon2 timing fallback preserved; `:48-54` raise guard preserved. Plan 02 commit `14f7180` diff = 4 lines (guard tokens only). |
| T-137-04 | Tampering / DoS | mitigate | CLOSED | `jwt/signer.ex:18-24` `unless ... do raise RuntimeError` intact. All 5 oauth strategies raise on Assent absence: `apple.ex:76-78`, `facebook.ex:80`, `github.ex:77`, `generic.ex:83`, `google.ex:74`. Plan 02 commit `a945a9b` diff = 7 lines (guard tokens only). |
| T-137-05 | Tampering (scope fence) | mitigate | CLOSED | Plan 02 commits (`14f7180`, `a945a9b`) touched ONLY the 10 enumerated Bucket A files; plan 03 (`7467d75`, `523b631`) ONLY the 4 compound files. No `workers/*`, `credo/*`, or `testing.ex` in any phase-137 plan commit. (Note: `doctor.ex`/`account.ex`/`mfa/trust.ex` in the broader commit range belong to Phase 138, out of this audit's scope.) |
| T-137-06 | DoS / availability | mitigate | CLOSED | `delivery.ex:114` retains literal `and Process.whereis(Oban) != nil` liveness half + 3-line explanatory comment (110-112). `forwarders.ex:99` `:error` branch retains same liveness half. Only the load half delegated. |
| T-137-07 | Tampering | mitigate | CLOSED | `forwarders.ex:91-94` `{:ok, oban_override}` branch unchanged — `Process.whereis(oban_override) != nil`, no load check. Plan 03 forwarders diff = 6 lines (the `:error` guard line + comment honesty update only). |
| T-137-08 | Tampering | mitigate | CLOSED | `deletion.ex:307` Oban leg delegates (`with true <- Sigra.OptionalDeps.oban_available?()`); `:308` internal-worker leg stays literal `Code.ensure_loaded?(Sigra.Workers.AccountDeletion)`. No predicate invented for the internal worker. |
| T-137-SC | Tampering (installs) | accept | CLOSED | `mix.exs` untouched across all phase-137 plan commits (`git log mix.exs de3f3f8~1..` empty). No install task added — `lib/mix/tasks/sigra.install.ex` is pre-existing, unmodified. All referenced deps pre-existing. Documented as accepted: no install task, no legitimacy checkpoint required. |

## Out-of-Scope Literals Confirmed Correctly Fenced

Remaining `Code.ensure_loaded?` calls in scope files are intentional and verified literal:
- `account/deletion.ex:308` — internal conditionally-compiled worker (Bucket C, T-137-08).
- `audit/forwarders.ex:139` — compile-time `@worker_module` wrapper (Bucket B, D-04).
- `application.ex:77` — boot-warning `cond` (Open Question 1, documented in SOT `@moduledoc` lines 28-30).

## Unregistered Flags

None. All three plan SUMMARY.md `## Threat Flags` sections report "None"; no new attack surface appeared during implementation that lacks a threat mapping.

## Accepted Risks Log

- **T-137-SC** — No package installs in Phase 137. All 9 referenced optional deps pre-existing in `mix.exs` (8 `optional: true`, `req` transitive). No install/setup task added. `mix.exs` byte-unchanged. Accepted.
