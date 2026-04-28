# Google OAuth Setup

Use this checklist after `mix sigra.install` and `mix sigra.gen.oauth --providers google`.

1. In Google Cloud Console, create or select the project that will own your app's OAuth credentials.
2. Open `APIs & Services -> OAuth consent screen` and configure the app name, support email, and developer contact email.
3. Add the scopes your Sigra flow needs. For the default Google provider wiring, keep `openid`, `email`, and `profile`.
4. Open `APIs & Services -> Credentials` and create an `OAuth client ID` for a web application.
5. Add your normal app callback URI, for example `http://localhost:4000/auth/google/callback`.
6. Add the smoketest callback URI `http://127.0.0.1:4001/callback`.
7. Export the generated credentials where your app reads them:

```bash
export GOOGLE_CLIENT_ID="..."
export GOOGLE_CLIENT_SECRET="..."
```

8. Ensure your app's Sigra config points at those values under `oauth: [providers: [google: ...]]`.
9. Start your app environment so the config is available.
10. Run the real round-trip check:

```bash
mix sigra.oauth.smoketest --provider=google
```

The task prints a Google authorize URL, waits on `127.0.0.1:4001`, and finishes with:

```text
OK — got back valid id_token with sub=... and email=...
```
