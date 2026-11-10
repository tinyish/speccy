defmodule Speccy.PrimitivesTest do
  use ExUnit.Case, async: true

  alias Speccy.Primitives

  @fields ~w(name about category element props events states defaults examples children slot pressable aria)a
  @types ~w(text bool number icon text[] model model[])

  test "the registry lists 25 primitives, each found by its unique name" do
    names = Enum.map(Primitives.all(), & &1.interface().name)

    assert length(names) == 25
    assert names == Enum.uniq(names)

    for {name, module} <- Enum.zip(names, Primitives.all()),
        do: assert(Primitives.get(name) == module)

    assert Primitives.get("Banner") == nil
  end

  test "every interface has the required fields, format.md's types and only its own props" do
    for module <- Primitives.all(), i = module.interface() do
      assert i |> Map.keys() |> Enum.sort() == Enum.sort(@fields), i.name
      props = Map.new(i.props)

      for {prop, type} <- i.props do
        assert type in @types or (is_list(type) and Enum.all?(type, &is_binary/1)),
               "#{i.name}.#{prop}: #{inspect(type)}"
      end

      for {_, state} <- i.states, do: assert(is_binary(state.about) and state.about != "")

      used =
        Map.keys(i.defaults) ++
          Enum.flat_map(i.states, &Map.keys(elem(&1, 1).props)) ++
          Enum.flat_map(i.examples, &Map.keys(elem(&1, 1))) ++ Map.values(i.aria)

      assert Enum.uniq(used) -- Map.keys(props) == [], i.name
      # Defaults are what an unset prop means: behaviour, never sample content.
      for {prop, _} <- i.defaults do
        assert props[prop] in ["bool", "number"] or is_list(props[prop]), "#{i.name}.#{prop}"
      end

      assert is_boolean(i.children) and is_boolean(i.slot)
      assert !i.slot or i.children, i.name
      assert is_boolean(i.pressable) or props[elem(i.pressable, 1)] in ["bool", "text"], i.name
    end
  end

  test "an interface as JSON keeps its ordered lists' order" do
    for module <- Primitives.all(), i = module.interface() do
      json = Primitives.json(i) |> Jason.encode!() |> Jason.decode!(objects: :ordered_objects)

      assert Enum.map(json.values, &elem(&1, 0)) ==
               ~w(name about category element props events states defaults examples children slot pressable aria)

      assert Enum.map(json["props"].values, &elem(&1, 0)) == Enum.map(i.props, &elem(&1, 0))
      assert Enum.map(json["states"].values, &elem(&1, 0)) == Enum.map(i.states, &elem(&1, 0))
    end

    assert Primitives.json(Primitives.get("list").interface())["pressable"] == %{
             "prop" => "selectable"
           }
  end
end
