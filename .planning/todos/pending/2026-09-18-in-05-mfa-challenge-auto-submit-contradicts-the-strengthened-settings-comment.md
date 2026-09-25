---
created: 2026-09-18T00:00:00.000Z
status: pending
title: "IN-05: mfa_challenge_live.ex does exactly what the strengthened mfa_settings_live.ex comment names as a defect"
area: installer
files:
  - priv/templates/sigra.install/core/mfa_challenge_live.ex
  - priv/templates/sigra.install/core/mfa_settings_live.ex

source: "Phase 239 code review (239-REVIEW.md, IN-05) — pre-existing on both sites (both predate aa1372cb), surfaced because 239-06's comment rewrite turned a latent inconsistency into a documented one."
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-18
---

## What

Plan 239-06 sharpened the **settings** screen's comment
(`priv/templates/sigra.install/core/mfa_settings_live.ex`, around `:606-610`):

```elixir
    # Auto-submit when 6 digits entered. Calls the confirm path
    # directly instead of dispatching via
    # `send(self(), …)`. The mailbox round-trip allowed a stale 6-digit
    # prefix to fire after the user typed a 7th character, wasting an
    # attempt against the MFA lockout counter.
```

The **challenge** screen (`priv/templates/sigra.install/core/mfa_challenge_live.ex`, around
`:358-360`) does exactly what that comment names as the defect:

```elixir
    # Auto-submit when 6 digits entered
    if String.length(code) == 6 and Regex.match?(~r/^\d{6}$/, code) do
      send(self(), {:auto_verify_totp, code})
    end
```

## Why this is a correctness question, not only a prose question

The **challenge** screen is the one guarded by the MFA **lockout** counter the settings comment
cites. Enrollment confirmation on the settings screen is not what burns lockout attempts — the
challenge is. So the same stale-prefix race the strengthened comment describes would, on the
challenge screen, burn a real attempt against a real lockout counter and could lock a legitimate user
out after fast typing.

That makes the sibling with the *weaker* comment the one carrying the *higher* consequence. Read
together, the two files now assert that Sigra knows about the race, fixed it where it is cheap, and
left it where it is expensive.

## Not fixed in Phase 239 — deliberately

The review classified IN-05 **pre-existing**: both sites predate `aa1372cb` and both sit outside the
reviewed `aa1372cb..HEAD` range as a code change. Phase 239's charter is a bookkeeping-token sweep
with a comment-only diff property on its re-bless commits (SC-3) — changing `send(self(), …)` to a
direct call is a **behaviour** change, which that property forbids outright. Phase 239 therefore
**deliberately did not fix** it, and the review itself recommends a tracked todo over an in-phase fix.

## Suggested shape

Either (a) make the challenge screen match the settings screen — call the verify path directly
instead of round-tripping through the mailbox — with a test that types a 7th character and asserts no
lockout attempt is consumed; or (b) if the round-trip on the challenge screen is deliberate for a
reason not written down, write that reason into `mfa_challenge_live.ex` so the two comments stop
contradicting each other. Do not resolve it by weakening the settings comment.
