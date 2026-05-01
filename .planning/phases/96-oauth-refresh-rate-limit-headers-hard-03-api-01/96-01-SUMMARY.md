# 96-01-SUMMARY.md

- **`Sigra.OAuth.Strategies.Github`**, **`Apple`**, **`Facebook`**, **`Generic`**: Implemented `refresh/3` that delegates to `Assent.Strategy.OAuth2.refresh_access_token/2` and returns a typed `{:ok, token}` or `{:error, error}`.
- **`Sigra.OAuth.RefreshClassifier`**: Added `Assent.InvalidResponseError` matching for invalid grants and other error bodies, ensuring consistent classification.
- **`test/sigra/oauth/refresh_test.exs`**: Added dedicated Postgres suite using `TestServer` to simulate valid refresh and `invalid_grant` paths across all 4 non-Google providers, proving `refresh_token/2` returns correct typed outcomes.
- **`test/sigra/oauth/oauth_test.exs`**: Updated the existing mock strategy tests to also use `TestServer`, maintaining isolation from real HTTP calls and proving `refresh_token/2` compatibility handling.
- **Outcome**: Tests are green (`54/0` in `oauth` tests).
