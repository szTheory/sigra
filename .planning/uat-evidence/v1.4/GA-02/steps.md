# GA-02 — Human mail client checklist

**Redaction:** Do not paste live tokens, magic links with secrets, or full mailbox exports — short notes and screenshots with redaction per **D-38-P04**.

## Preconditions

- [ ] Build/version under test recorded (Hex + git SHA in matrix header).
- [ ] CI HTML baseline green for the same change (`EmailsSecurityHtmlTest`, `EmailsLifecycleHtmlTest`, `example_unit_smoke`).

## Clients (use all three or document substitutes in waiver)

### 1. Gmail (web)

- [ ] Open message in **Gmail web** (standard and **dark mode** if feasible).
- [ ] Verify **CTA** renders and is tappable; **footer / security copy** present; **plain-text part** present if multipart claims it.
- [ ] Note **spam tab** placement if observed.

### 2. Outlook (web or desktop per team norm)

- [ ] Open same template path in **Outlook**.
- [ ] Verify headings, CTA, footer strings match intent; note clipping/wrapping issues.

### 3. Apple Mail (macOS or iOS per team norm)

- [ ] Open in **Apple Mail**.
- [ ] Verify layout vs Gmail/Outlook; note dark-mode quirks.

## Record

| Date | Owner | Outcome | Run / build ref | Notes |
|------|-------|---------|-----------------|-------|
| | | | | |
