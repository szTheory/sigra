defmodule Sigra.EnvTest do
  use ExUnit.Case, async: true
  doctest Sigra.Env

  describe "current/0" do
    test "returns the current Mix env in a test environment" do
      assert Sigra.Env.current() == :test
    end

    test "is an atom" do
      assert is_atom(Sigra.Env.current())
    end
  end
end
