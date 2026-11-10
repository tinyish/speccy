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

  test "every fixture file names its kind's schema" do
    for {path, json} <-
          Path.wildcard("test/fixtures/specs/*") |> Enum.flat_map(&Format.load(&1).files),
        match?(%Jason.OrderedObject{}, json),
        path != "components/Bad.json" do
      assert json["$schema"] == Schemas.url(Format.kind(path)), path
    end
  end
end
