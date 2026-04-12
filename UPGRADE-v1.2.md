# Upgrading to Sigra v1.2

> Status: skeleton. v1.2 has not shipped. This document defines the
> forward contract that v1.1 generated code must respect so that
> the v1.2 upgrade is purely additive.

## Reserved fields in v1.1

Sigra v1.1 reserves the following fields in generated code so the
v1.2 upgrade can be purely additive:

- `%<YourApp>.Accounts.Scope{impersonating_from: nil}` — populated
  by v1.2 `Sigra.Plug.Impersonation`. Type: `%User{} | nil`.

Do not remove these fields from your generated `scope.ex`. If you
do, v1.2 will fail to compile against your generated `user_auth.ex`
and associated plugs, and the library-side invariant test
(`Sigra.Install.ScopeTemplateInvariantsTest`) will turn red on your
next CI run.

## v1.2 population contract

(Filled in when v1.2 ships.)

## If you need to remove a reserved field

(Filled in when v1.2 ships.)
