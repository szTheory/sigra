# GA-03 — Waiver / intermediate-branch rules (**D-42-02**)

A **waiver** for skipping fresh live Google smoke on an **intermediate** branch is permitted only if **all** of the following are recorded:

1. **Link** the **last pinned live run** (date, owner, transcript pointer, build SHA).
2. **Diff since** that run: list OAuth-related dependency or code changes; if none material, state explicitly.
3. **Residual risk:** consent UX, refresh/token edge cases not covered by **`Sigra.OAuthTest`**.

**No GA tag** on a release line without fresh live smoke **or** a formal **Waived** row with vendor/policy infeasibility and compensating evidence.

For the **waiver** form fields, mirror GA-02: reason, compensating controls, residual risk, expiry_or_next_trigger, owner, date.
