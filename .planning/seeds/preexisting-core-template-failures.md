# Pre-existing core-template test failures (surfaced during v1.38 Phase 183)

**Status:** OPEN — NOT introduced by v1.38 brand milestone (both byte-identical to the `main` merge-base).
**Found:** 2026-06-13 while running the full `mix test` gate in Phase 183.

## 1. auth.ex undefined `app_name` (REAL generated-template bug — higher priority)
- **Test:** `test/mix/tasks/sigra.install_test.exs:166` ("renders auth context template")
- **Cause:** `priv/templates/sigra.install/core/auth.ex:554` references EEx binding `app_name` (`product_name: "<%= app_name %>"`, `email_from_name: "<%= app_name %>"`) but the render binding does not provide it → `CompileError: undefined variable "app_name"`.
- **Impact:** A host app generated from this template branch would fail to compile its auth context. Shipping-relevant.
- **Recommended:** `/gsd-debug` — determine the correct binding (likely `app_name` should be derived from the app module/name in the installer binding, or the template should use an existing var).

## 2. core template count drift
- **Test:** `test/sigra/install/isolation_test.exs:86` — asserts `priv/templates/sigra.install/core/*` contains exactly 49 templates; actual is 52.
- **Cause:** 3 core templates added at/before the merge-base without bumping the assertion count.
- **Impact:** Test-bookkeeping only (unless the 3 extra files are unintended).
- **Recommended:** `/gsd-quick` — confirm the 3 extra templates are intended, then update the count to 52 (or remove strays).

Both are out of scope for the brand milestone (logo propagation never touched `core/`).
