# What caused the registration timeout

The original server crashed while handling the same account as failing test 161. It raised:

```text
UndefinedFunctionError: function Ecto.Queryable.to_query/1 is undefined
(module Ecto.Queryable is not available)
```

The stack runs through Ecto's email uniqueness check, `Example.Accounts.User.registration_changeset`, and `RegistrationLive.handle_event/3`. The user insert never happened, so the LiveView never enabled the form's login POST. The browser subsequently timed out waiting to leave the registration page.

This finding is supported by the original archived log, not inferred from a passing replay. The sole crash follows save 161; the generated account identifies dark registration 33 and was created between test 160 finishing and test 161 failing. Registrations 160 and 162 each inserted an account and sent a login POST. Across all 192 original registrations, the only missing insert/POST belongs to 161. The authenticated extraction and safe stack excerpt are in [evidence.json](evidence.json).

The original server log was printed after the tests failed. Its 05:19:23 timestamp is the log-dump time. It must not be treated as proof that the crash happened after the browser failure.

The saved Linux run contrasts with that failure: 161 saves, 161 user inserts and 161 login POSTs; no Queryable exception. The selected 161st case also created both confirmation tokens and passed. This remains a passing diagnostic, not a demonstrated fix.

## What is still unknown

Why the module was unavailable at that instant is not established. The original development endpoint enables Phoenix's code reloader. Its locked source purges consolidated protocols, including Ecto.Queryable; LiveView event processing runs outside the HTTP reloader sequence. That is a specific candidate cause. The original log does not record a purge or failed module load, so it does not prove this candidate.

Two isolated local probes used Elixir 1.19.5, OTP 28 and Ecto 3.13.5 without starting the application, database, browser, container or network. The first passed 40,000 query calls during purge/delete; the refined probe passed 400,000 schema query calls with 5,000 reload/purge cycles. Both controls passed 2,000 calls, and all worker processes exited normally. These probes did not reproduce the module error. Their scripts and actual logs are retained alongside this report.

The next useful check is an isolated test of the actual Phoenix reloader with module deletion, code-path changes and OTP load results traced alongside a query. A failing module load would identify where the module disappeared. Another full browser replay or longer timeout would not answer that question.

## Scope and status

No product fix was applied. No browser or CI ran, no external request was made, and no old allowance was reopened. CIREL-01 and Phase 253 remain incomplete; CIREL-02 stays complete. No numbered plan was added.

Recheck this analysis without running the app:

```sh
python3 -B .planning/debug/phase253-registration-timeout/analyze.py
```

Continue the focused investigation:

```text
$gsd-debug continue phase253-registration-timeout
```
