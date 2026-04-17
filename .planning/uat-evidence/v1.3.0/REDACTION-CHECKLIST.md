# UAT evidence redaction checklist (v1.3.0)

Apply before every `git add` under `.planning/uat-evidence/`.

Do **not** paste raw magic links, live OAuth or mail tokens, or `.env` file contents into this tree (D-38-P04).

- Crop secrets out of screenshots
- Shorten or remove query tokens from URLs
- Never commit .env
- Prefer mailbox HTML source copy over full-window screenshot when possible
