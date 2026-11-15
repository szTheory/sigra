defmodule Sigra.Install.AssetParityTest do
  @moduledoc """
  BGEN-01: every asset the installer copies out of `priv/templates/sigra.install/`
  must stay in step with the hand-maintained copy in `test/example/` (and with the
  committed golden tree where the golden tree carries it).

  The example is a hand mirror of the installer templates, so it drifts silently:
  `core/sigra_auth.css` was 32,072 bytes in the template and 13,867 bytes in the
  example. This file is the guard that makes that drift a red test.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("../../..", __DIR__)

  describe "core/sigra_auth.css" do
    test "the example copy is byte-identical to the installer template" do
      template_rel = "priv/templates/sigra.install/core/sigra_auth.css"
      example_rel = "test/example/priv/static/assets/sigra_auth.css"

      template = read!(template_rel)
      example = read!(example_rel)

      assert parity(template, example) == :ok,
             mismatch_message(template_rel, example_rel, parity(template, example))
    end
  end

  describe "parity/2 positive controls" do
    test "equal binaries are reported as parity" do
      assert parity("body { color: red; }\n", "body { color: red; }\n") == :ok
    end

    test "one appended byte is reported as a mismatch at the appended offset" do
      a = "body { color: red; }\n"
      b = a <> "x"

      assert parity(a, b) == {:mismatch, byte_size(a), byte_size(a), byte_size(b)}
    end

    test "one changed byte in the middle is reported at that offset with equal sizes" do
      a = "body { color: red; }\n"
      b = String.replace(a, "red", "rex")
      # "red" starts at byte 14, so its third byte (the planted change) is byte 16.
      {red_start, _len} = :binary.match(a, "red")

      assert parity(a, b) == {:mismatch, red_start + 2, byte_size(a), byte_size(b)}
    end
  end

  # -- helpers ----------------------------------------------------------------

  # Pure comparator: `:ok` when equal, otherwise the first differing byte offset
  # with both sizes, so a failure names how far apart the two files are.
  defp parity(a, b) when is_binary(a) and is_binary(b) do
    if a == b do
      :ok
    else
      {:mismatch, first_diff_offset(a, b, 0), byte_size(a), byte_size(b)}
    end
  end

  defp first_diff_offset(<<byte, rest_a::binary>>, <<byte, rest_b::binary>>, offset),
    do: first_diff_offset(rest_a, rest_b, offset + 1)

  defp first_diff_offset(_a, _b, offset), do: offset

  defp mismatch_message(template_rel, example_rel, {:mismatch, offset, size_a, size_b}) do
    "#{example_rel} has diverged from the installer template #{template_rel}: " <>
      "first differing byte at offset #{offset}; template #{size_a} bytes, example #{size_b} bytes. " <>
      "Resync with: cp #{template_rel} #{example_rel}"
  end

  defp mismatch_message(_template_rel, _example_rel, :ok), do: "byte parity holds"

  defp read!(rel), do: @repo_root |> Path.join(rel) |> File.read!()
end
