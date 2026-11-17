defmodule Sigra.Brand.PackageMetadataTest do
  use ExUnit.Case, async: true

  @description "A library of hardened primitives plus generators that put ordinary authentication code for Phoenix in your repo."
  @source_url "https://github.com/sztheory/sigra"

  test "the package description matches the approved one-line copy" do
    assert Mix.Project.config()[:description] == @description
  end

  test "package links point to the canonical changelog, documentation, and source" do
    assert Mix.Project.config()[:package][:links] == %{
             "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
             "Documentation" => "https://hexdocs.pm/sigra",
             "GitHub" => @source_url
           }
  end

  test "the package file boundary remains unchanged" do
    assert Mix.Project.config()[:package][:files] ==
             ~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
  end
end
