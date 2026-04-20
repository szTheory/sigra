# GA-02 — Waiver template

Use only when human triple-client verification is **not** executed but a **formal Waived** row is required. Pair with CI HTML diff evidence for the same change.

| Field | Value |
|--------|--------|
| **reason** | Why MUAs were not exercised (e.g. schedule, vendor-only proof). |
| **compensating controls** | e.g. Litmus / Email on Acid / screenshot bundle **plus** CI snapshot diff IDs. |
| **residual risk** | e.g. spam tab, dark mode, client-specific clipping — state honestly. |
| **expiry_or_next_trigger** | Next release boundary or HTML-affecting change that requires re-validation. |
| **owner** | |
| **date** | |

**Rules:** Do not claim “triple-client verified” from screenshots alone (**D-42-02**).
