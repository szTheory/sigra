defmodule Sigra.AuditSecurityTest do
  use ExUnit.Case, async: true

  # Wave 0 scaffold for D-17 reserved-prefix enforcement and D-15
  # internal-only routing. Plan 02 implements both.

  alias Sigra.Audit

  defmodule StubRepo do
    @moduledoc false
    def insert(changeset) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end
  end

  @reserved ~w(auth. session. mfa. oauth. api. account. sigra.)

  test "public log/3 rejects each of the 7 reserved prefixes (D-17)" do
    for prefix <- @reserved do
      assert {:error, cs} =
               Audit.log(prefix <> "foo.bar",
                 repo: StubRepo,
                 audit_schema: Sigra.Test.AuditEvent
               ),
             "expected #{prefix}foo.bar to be rejected on public log/3"

      refute cs.valid?
    end
  end

  test "__log_internal__/3 is hidden from docs (D-15)" do
    Code.ensure_loaded!(Sigra.Audit)
    {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Sigra.Audit)

    log_internal_doc =
      Enum.find(docs, fn
        {{:function, :__log_internal__, _arity}, _, _, _, _} -> true
        _ -> false
      end)

    assert log_internal_doc, "expected __log_internal__/3 to exist on Sigra.Audit"
    {_, _, _, doc, _} = log_internal_doc
    assert doc == :hidden or doc == :none
  end

  test "reserved_prefixes are configurable (D-18)" do
    # Host apps can extend the reserved list. Plan 02 implements this via
    # config :sigra, :audit, reserved_prefixes: [...]. The test verifies the
    # default list is honored at minimum.
    Application.put_env(:sigra, :audit, reserved_prefixes: ~w(admin. auth.))

    on_exit(fn -> Application.delete_env(:sigra, :audit) end)

    assert {:error, _} =
             Audit.log("admin.user.banned",
               repo: StubRepo,
               audit_schema: Sigra.Test.AuditEvent
             )
  end
end
