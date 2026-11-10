defmodule Speccy.IconsTest do
  use ExUnit.Case, async: true

  alias Speccy.{Format, Icons, Primitives}

  @sets %{"app" => ["logo"]}

  test "a reference parses into its set, name and style" do
    assert Icons.parse("material/home") == {:ok, {"material", "home", nil}}
    assert Icons.parse("material/home:filled") == {:ok, {"material", "home", "filled"}}
    assert Icons.parse("app/sync-done") == {:ok, {"app", "sync-done", nil}}

    for bad <- ["material", "material/", "Material/home", "material/home:", "a/b/c", 5],
        do: assert(Icons.parse(bad) == :error)
  end

  test "a reference resolves to its style, the set's first when none is written" do
    assert Icons.resolve("material/home", @sets) == {:ok, {"material", "home", "outlined"}}
    assert Icons.resolve("material/home:filled", @sets) == {:ok, {"material", "home", "filled"}}
    assert Icons.resolve("app/logo", @sets) == {:ok, {"app", "logo", nil}}

    assert Icons.resolve("material/nope", @sets) == {:error, :"unknown-icon"}
    assert Icons.resolve("material/home:rounded", @sets) == {:error, :"unknown-icon-style"}
    assert Icons.resolve("app/nope", @sets) == {:error, :"unknown-icon"}
    assert Icons.resolve("app/logo:filled", @sets) == {:error, :"unknown-icon-style"}
    assert Icons.resolve("brand/logo", @sets) == {:error, :"unknown-icon-set"}
  end

  test "the spec's sets come from its SVGs" do
    spec = Format.load("test/fixtures/specs/tasks")
    assert Icons.sets(spec.icons) == %{"app" => ["alert", "offline"]}
  end

  test "Material's index holds its pinned version, its styles and each icon's" do
    index = Icons.library("material")

    assert Icons.libraries() == ["material"]
    assert index["version"] =~ ~r/^[0-9a-f]{40}$/
    assert index["styles"] == ["outlined", "filled"]
    assert index["svg"]["filled"] =~ index["version"]
    assert map_size(index["icons"]) > 3000

    assert %{"categories" => [_ | _], "tags" => [_ | _], "styles" => ["outlined", "filled"]} =
             index["icons"]["home"]
  end

  test "every icon in the primitives' examples resolves" do
    for module <- Primitives.all(),
        {_, props} <- module.interface().examples,
        {prop, "icon"} <- module.interface().props,
        ref = props[prop],
        do: assert({:ok, _} = Icons.resolve(ref, %{}))
  end

  test "a clean SVG is safe" do
    assert Icons.safe(File.read!("test/fixtures/specs/tasks/assets/icons/app/alert.svg")) == :ok
  end
end
