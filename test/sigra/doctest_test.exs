defmodule Sigra.DoctestTest do
  @moduledoc """
  Exercises doctests for the modules carrying the Phase 10 DX-02 doctest
  density: `Sigra.Config`, `Sigra.Auth`, `Sigra.Testing`. Pure helpers
  only — repo-using functions are covered by dedicated unit tests.
  """

  use ExUnit.Case, async: true

  doctest Sigra.Config
  doctest Sigra.Auth
  doctest Sigra.Testing
end
