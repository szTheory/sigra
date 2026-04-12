defmodule Sigra.Install.InjectionTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Injection
  alias Sigra.Install.Injector

  @tmp_dir "tmp/injection_test"

  setup do
    File.mkdir_p!(@tmp_dir)
    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    :ok
  end

  test "%Injection{} enforces all four keys" do
    assert_raise ArgumentError, fn ->
      struct!(Injection, target: "x.ex", marker: "m", anchor: :at_top)
    end
  end

  test "%Injection{} constructs with all four fields accessible" do
    inj = %Injection{
      target: "router.ex",
      marker: "# sigra:auth",
      anchor: :before_last_end,
      content: "plug Sigra.Plug.FetchScope"
    }

    assert inj.target == "router.ex"
    assert inj.marker == "# sigra:auth"
    assert inj.anchor == :before_last_end
    assert inj.content == "plug Sigra.Plug.FetchScope"
  end

  test "apply/2 injects at :at_top then returns :already_present on re-apply" do
    target = Path.join(@tmp_dir, "sample.ex")
    File.write!(target, "defmodule Sample do\nend\n")

    inj = %Injection{
      target: target,
      marker: "# sigra:test-marker",
      anchor: :at_top,
      content: "# sigra:test-marker\n# injected line"
    }

    assert {:ok, :injected} = Injector.apply(inj)
    assert File.read!(target) =~ "# sigra:test-marker"

    assert {:ok, :already_present} = Injector.apply(inj)
  end

  test "apply/2 returns {:error, {:target_missing, path}} on missing file" do
    inj = %Injection{
      target: Path.join(@tmp_dir, "nope.ex"),
      marker: "# x",
      anchor: :at_top,
      content: "# x"
    }

    assert {:error, {:target_missing, _}} = Injector.apply(inj)
  end
end
