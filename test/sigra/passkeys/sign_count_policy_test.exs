defmodule Sigra.Passkeys.SignCountPolicyTest do
  use ExUnit.Case, async: true

  alias Sigra.Passkeys.SignCountPolicy

  test "zero to zero is allowed for synced passkeys" do
    assert SignCountPolicy.evaluate(0, 0, :warn) == :ok
  end

  test "increasing counter is accepted" do
    assert SignCountPolicy.evaluate(4, 5, :warn) == :ok
  end

  test "warn mode flags regressions" do
    assert SignCountPolicy.evaluate(10, 9, :warn) == {:regression, :warn}
  end

  test "require_reauth mode flags regressions" do
    assert SignCountPolicy.evaluate(10, 9, :require_reauth) == {:regression, :require_reauth}
  end

  test "revoke mode flags regressions" do
    assert SignCountPolicy.evaluate(10, 9, :revoke) == {:regression, :revoke}
  end
end
