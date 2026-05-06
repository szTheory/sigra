---
phase: 96-oauth-refresh-rate-limit-headers-hard-03-api-01
plan: 03
status: complete
requirements-completed: [API-01]
---

# 96-03-SUMMARY.md

- **`Sigra.RateLimiter` & `Sigra.RateLimiters.Hammer`**: Enriched the limiter behaviour return shape to return full metadata (`count`, `remaining`, `reset_ms` on allow; `retry_after_ms`, `reset_ms` on deny). Computes `reset_ms` accurately via epoch-alignment to avoid a second Hammer hit.
- **`Sigra.Plug.RateLimit`**: Emits `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` directly from the single authoritative `check_rate` result. Preserves existing 429 semantics, rounding `Retry-After` accurately and continuing to emit `[:sigra, :security, :rate_limited]` telemetry.
- **`test/sigra/plug/rate_limit_headers_test.exs`**: Added a dedicated Postgres-independent unit suite to enforce the header shape contract for both allowed and denied paths, keeping `test/sigra/plug/rate_limit_test.exs` focused on backwards-compatible plug behavior.
- **Outcome**: API rate limiting now returns rich headers compliant with API-01, powered by a single backend hit per request. Tests are green.