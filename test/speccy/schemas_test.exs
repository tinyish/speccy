defmodule Speccy.SchemasTest do
  use ExUnit.Case, async: true

  alias Speccy.{Format, Schemas}

  test "priv/schemas holds what Speccy.Schemas builds (run `mix speccy.schemas` after a format change)" do
    for kind <- Schemas.kinds() do
      assert File.read!(Schemas.path(kind)) == Schemas.encode(kind), kind
    end
  end

  test "each schema's $id is its public URL" do
    for kind <- Schemas.kinds() do
      assert Schemas.build(kind)["$id"] ==
               "https://raw.githubusercontent.com/tinyish/speccy/main/priv/schemas/1/#{kind}.schema.json"
    end
  end

  test "each kind of object has the same keys in Format as in its schemas" do
    root = &Schemas.build/1
    defs = Schemas.kinds() |> Enum.map(&root.(&1)["$defs"]) |> Enum.reduce(&Map.merge/2)
    typed = &get_in(root.(&1), ["properties", &2, "additionalProperties", "then"])
    instance = defs["instance"]["properties"]

    # A kind that is several schema objects has the keys of them all.
    objects = %{
      manifest: [root.("manifest")],
      device: [defs["device"]],
      data: [root.("data")],
      component: [root.("component")],
      screen: [root.("screen")],
      # Only a prop has a default, not a data field.
      typed: [typed.("data", "fields"), typed.("component", "props")],
      sample: [get_in(root.("screen"), ~w(properties data additionalProperties))],
      # Only a linked copy has copy and inner; only an instance has the rest.
      instance: [defs["instance"], defs["copy"]],
      repeat: [instance["repeat"]],
      constraints: [instance["constraints"]],
      # Only a screen's state has data.
      state: [defs["componentState"], defs["screenState"]],
      variation: [defs["variation"]]
    }

    for {kind, {keys, _}} <- Format.kinds() do
      schema =
        for object <- objects[kind], key <- Map.keys(object["properties"]), uniq: true, do: key

      assert Enum.sort(schema) == Enum.sort(keys), "#{kind}"
    end
  end

  test "every fixture file names its kind's schema" do
    for {path, json} <-
          Path.wildcard("test/fixtures/specs/*") |> Enum.flat_map(&Format.load(&1).files),
        match?(%Jason.OrderedObject{}, json),
        path != "components/Bad.json" do
      assert json["$schema"] == Schemas.url(Format.kind(path)), path
    end
  end
end
