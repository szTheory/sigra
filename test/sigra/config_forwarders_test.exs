defmodule Sigra.ConfigForwardersTest do
  use ExUnit.Case, async: true

  # Wave 0 test scaffold for the :forwarders key in Sigra.Config audit: schema.
  # Tests are RED until lib/sigra/config.ex is extended in Plan 03 Task 2.
  #
  # Asserts the canonical D-05/D-06/D-09 shape accepted by Sigra.Config.new!/1:
  #   audit: [forwarders: [[module: SomeMod, dispatch: :auto, id: :default, ...impl_keys]]]
  #
  # Per D-08 + oauth[:providers] precedent (lib/sigra/config.ex:40), arbitrary
  # impl-specific keys (:endpoint, :api_key, :repo, etc.) pass through
  # the top-level schema unvalidated; each impl validates its own in attach/1.

  alias Sigra.Config

  # Minimal required opts for Config.new!/1 (repo + user_schema are required)
  defp base_opts do
    [repo: SomeRepo, user_schema: SomeUserSchema]
  end

  describe "audit[:forwarders] default (D-09)" do
    test "Test 1 — Config.new!([]) returns audit[:forwarders] == [] by default" do
      # Arrange / Act
      config = Config.new!(base_opts())

      # Assert — default is empty list = zero overhead (D-09)
      assert Keyword.get(config.audit, :forwarders, :missing) == []
    end
  end

  describe "audit[:forwarders] accepts valid shape (D-06)" do
    test "Test 2 — valid single forwarder entry is accepted and preserved" do
      # Arrange
      forwarder_entry = [module: Sigra.Audit.Forwarders.Noop, dispatch: :sync, id: :test]

      opts = base_opts() ++ [audit: [forwarders: [forwarder_entry]]]

      # Act
      config = Config.new!(opts)

      # Assert — config carries the same forwarder list
      forwarders = Keyword.get(config.audit, :forwarders)
      assert is_list(forwarders)
      assert length(forwarders) == 1
      entry = hd(forwarders)
      assert Keyword.get(entry, :module) == Sigra.Audit.Forwarders.Noop
      assert Keyword.get(entry, :dispatch) == :sync
      assert Keyword.get(entry, :id) == :test
    end
  end

  describe "audit[:forwarders] rejects malformed entries (D-06)" do
    test "Test 3 — rejects entry missing required :module key" do
      opts = base_opts() ++ [audit: [forwarders: [[dispatch: :sync]]]]

      # Act + Assert — NimbleOptions.ValidationError on missing :module
      assert_raise NimbleOptions.ValidationError, ~r/:module/i, fn ->
        Config.new!(opts)
      end
    end

    test "Test 4 — rejects invalid :dispatch value" do
      opts = base_opts() ++ [audit: [forwarders: [[module: SomeMod, dispatch: :wrong]]]]

      # Act + Assert — NimbleOptions.ValidationError on invalid :dispatch
      assert_raise NimbleOptions.ValidationError, ~r/:dispatch/i, fn ->
        Config.new!(opts)
      end
    end
  end

  describe "audit[:forwarders] arbitrary impl-specific keys pass through (D-08)" do
    test "Test 5 — impl-specific keys (:endpoint, :api_key) are accepted" do
      # Per oauth[:providers] precedent at lib/sigra/config.ex:40 and
      # RESEARCH.md §3 option 1: arbitrary impl-specific keys pass through
      # the top-level schema unvalidated; each impl validates its own at attach time.
      opts =
        base_opts() ++
          [
            audit: [
              forwarders: [
                [
                  module: SomeMod,
                  dispatch: :sync,
                  id: :x,
                  endpoint: "https://example.threadline.app/api",
                  api_key: "secret_key_abc123"
                ]
              ]
            ]
          ]

      # Act — must NOT raise NimbleOptions.ValidationError for unknown keys
      config = Config.new!(opts)

      # Assert — config accepted the entry
      forwarders = Keyword.get(config.audit, :forwarders)
      assert is_list(forwarders)
      assert length(forwarders) == 1
    end
  end
end
