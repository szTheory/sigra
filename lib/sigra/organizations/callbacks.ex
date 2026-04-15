defmodule Sigra.Organizations.Callbacks do
  @moduledoc """
  Behaviour for organization lifecycle hook callbacks.

  Implement these callbacks in your generated organizations wrapper module
  to customize behavior. All callbacks have no-op default implementations
  via `defoverridable` when using `use Sigra.Organizations`.

  ## Callbacks

  | Callback | Can modify? | Use case |
  |----------|-------------|----------|
  | `before_create_organization/2` | Changeset | Add validation, set fields |
  | `after_create_organization/2` | Read-only | Create related records |
  | `before_delete_organization/2` | Can abort | Check billing state |
  | `after_delete_organization/2` | Read-only | Cancel subscriptions |
  | `before_add_member/4` | Can abort | Check seat limits |
  | `after_add_member/3` | Read-only | Update seat counts |
  | `before_role_change/3` | Can abort | Billing role checks |
  | `after_member_remove/2` | Read-only | Revoke external access |

  Returning `{:error, reason}` from any `before_*` callback aborts the
  enclosing `Ecto.Multi` transaction.
  """

  @callback before_create_organization(Ecto.Changeset.t(), scope :: map()) ::
              {:ok, Ecto.Changeset.t()} | {:error, term()}

  @callback after_create_organization(org :: struct(), scope :: map()) ::
              :ok | {:error, term()}

  @callback before_delete_organization(org :: struct(), scope :: map()) ::
              :ok | {:error, term()}

  @callback after_delete_organization(org :: struct(), scope :: map()) ::
              :ok | {:error, term()}

  @callback before_add_member(org :: struct(), user :: struct(), role :: atom(), scope :: map()) ::
              :ok | {:error, term()}

  @callback after_add_member(membership :: struct(), org :: struct(), scope :: map()) ::
              :ok | {:error, term()}

  @callback before_role_change(membership :: struct(), new_role :: atom(), scope :: map()) ::
              :ok | {:error, term()}

  @callback after_member_remove(membership :: struct(), scope :: map()) ::
              :ok | {:error, term()}
end
