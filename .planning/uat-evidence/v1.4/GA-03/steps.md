# GA-03 — Live Google OAuth checklist

**GA-03 status:** **Waived** — formal rationale and compensating machine baseline are recorded in [`waiver.md`](./waiver.md). Live Google checklist items below were not executed for this closure.

**Redaction:** Use env var **names** (e.g. `GOOGLE_CLIENT_ID`) — never paste client secrets, refresh tokens, or auth codes into git (**D-38-P04**).

## Preconditions

- [ ] Dedicated **test** OAuth client configured in Google Cloud Console.
- [ ] Library **`Sigra.OAuthTest` / `MockStrategy`** baseline green on the same commit.

## Run

1. [ ] Register a new test user (or use disposable account policy).
2. [ ] Complete Google login / consent as exercised by product requirements.
3. [ ] Exercise **provider linking** path if in scope for this release.
4. [ ] Exercise **email-match confirmation** path if in scope.
5. [ ] Note any UX defects (consent chrome, errors, redirects).

## Record

| Run ID | Date | Owner | Outcome | Notes |
|--------|------|-------|---------|-------|
| | | | | |
