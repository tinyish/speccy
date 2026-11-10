defmodule Speccy.Spec do
  @moduledoc """
  The one reading of a loaded spec (`Speccy.Format.load/1`) that the check
  and Resolve share, built once per load and never written to
  (`conventions.md#files-are-the-model`), and the readers of it.

  `new/1` returns a map:

  - `ordered`: path → the file's JSON as loaded, key order kept, or
    `{:error, message}`
  - `read`: path → the same as plain maps, for every file that is valid JSON
  - `schema`: path → the file's schema problems
  - `valid`: path → plain JSON, for the files with no schema problem
  - `items`: `{name, kind, path}` for every item read, valid or not
  - `known`: kind → the names of its items, files that fail their schema included
  - `paths`, `components`: component name → its path, and → its JSON, valid ones only
  - `models`: data model name → field → type
  - `devices`: the presets and the manifest's devices, or `:unknown`
  - `reaches`: component → every component reachable through its instances
  - `icons`: the spec's icon sets (`Speccy.Icons.sets/1`)
  - `svgs`: path → each of the spec's SVGs as loaded

  Primitives are read through their interfaces, never by name.
  """

  alias Speccy.{Devices, Format, Icons, Primitives}
  alias Speccy.Check.Schema

  @doc "The reading of a loaded spec."
  def new(%{files: files, icons: icons}) do
    read =
      for {path, json} <- files, !match?({:error, _}, json), into: %{}, do: {path, plain(json)}

    schema = Map.new(read, fn {path, json} -> {path, Schema.problems(path, json)} end)
    valid = Map.filter(read, &(schema[elem(&1, 0)] == []))

    items =
      for {path, json} <- read,
          kind = Format.kind(path),
          kind != :manifest,
          is_map(json) and is_binary(json[name_key(kind)]),
          do: {json[name_key(kind)], kind, path}

    by_kind = fn kind ->
      for {name, ^kind, path} <- items, valid[path], into: %{}, do: {name, {path, valid[path]}}
    end

    manifest = valid["speccy.json"]
    components = by_kind.(:component)

    %{
      ordered: files,
      read: read,
      schema: schema,
      valid: valid,
      items: items,
      known:
        Map.new(
          [:component, :data],
          &{&1, for({name, ^&1, _} <- items, into: MapSet.new(), do: name)}
        ),
      paths: Map.new(components, fn {name, {path, _}} -> {name, path} end),
      components: Map.new(components, fn {name, {_, json}} -> {name, json} end),
      models:
        Map.new(by_kind.(:data), fn {name, {_, json}} ->
          {name, Map.new(json["fields"] || %{}, fn {f, t} -> {f, type(t)} end)}
        end),
      # A manifest that can't be read or fails its schema says nothing about devices.
      devices:
        if(manifest || !Map.has_key?(files, "speccy.json"),
          do: Map.merge((manifest || %{})["devices"] || %{}, Map.new(Devices.all())),
          else: :unknown
        ),
      reaches: reaches(components),
      icons: Icons.sets(icons),
      svgs: icons
    }
  end

  @doc "The key an item of `kind` is named by."
  def name_key(:component), do: "component"
  def name_key(:screen), do: "screen"
  def name_key(:data), do: "data"

  # Each component → every component reachable through its instances.
  defp reaches(components) do
    uses =
      Map.new(components, fn {name, {_, json}} ->
        {name,
         for(
           {node, _} <- nodes(json),
           node["use"] in Map.keys(components),
           uniq: true,
           do: node["use"]
         )}
      end)

    Map.new(uses, fn {name, direct} -> {name, closure(direct, uses, MapSet.new())} end)
  end

  defp closure([], _uses, seen), do: seen

  defp closure([name | rest], uses, seen) do
    if name in seen,
      do: closure(rest, uses, seen),
      else: closure(uses[name] ++ rest, uses, MapSet.put(seen, name))
  end

  defp plain(%Jason.OrderedObject{values: values}),
    do: Map.new(values, fn {k, v} -> {k, plain(v)} end)

  defp plain(list) when is_list(list), do: Enum.map(list, &plain/1)
  defp plain(value), do: value

  ## Frames

  @doc """
  The frames of the valid screen or component at `path`: `[{state | nil,
  [variation]}]`, the base first, then each state, both in the file's
  order. `[]` for a path not in `valid`.
  """
  def frames(spec, path) do
    if spec.valid[path] do
      json = spec.ordered[path]
      # A doubled key's last value, as `valid` holds it.
      states = Map.new(json["states"] || [])

      [{nil, names(json["variations"])}] ++
        for state <- names(json["states"]), do: {state, names(states[state]["variations"])}
    else
      []
    end
  end

  defp names(object), do: Enum.uniq(for {name, _} <- object || [], do: name)

  ## Targets

  @doc "What `use` names: `{:primitive, interface}`, `{:component, json}` or nil."
  def target(spec, use) do
    cond do
      !is_binary(use) -> nil
      module = Primitives.get(use) -> {:primitive, module.interface()}
      json = spec.components[use] -> {:component, json}
      true -> nil
    end
  end

  @doc "Whether a target holds children; nil when there is no target."
  def holds?({:primitive, i}), do: i.children
  def holds?({:component, _}), do: false
  def holds?(nil), do: nil

  @doc "A target's props: name → type."
  def props({:primitive, i}), do: Map.new(i.props)
  def props({:component, json}), do: Map.new(json["props"] || %{}, fn {k, v} -> {k, type(v)} end)
  def props(nil), do: %{}

  @doc "A target's states' names."
  def states({:primitive, i}), do: Enum.map(i.states, &elem(&1, 0))
  def states({:component, json}), do: Map.keys(json["states"] || %{})

  @doc "A target's variations' names, of its base (`state` nil) or of `state`."
  def variations({:primitive, _}, _state), do: []
  def variations({:component, json}, nil), do: Map.keys(json["variations"] || %{})

  def variations({:component, json}, state),
    do: Map.keys(get_in(json, ["states", state, "variations"]) || %{})

  @doc "A target's slots' names."
  def slots({:component, json}), do: for({node, _} <- nodes(json), s = node["slot"], do: s)
  def slots(_), do: []

  @doc "The instance in a component that holds `slot`, whose layout its fills sit in."
  def holder({:component, json}, slot),
    do: Enum.find_value(nodes(json), fn {node, _} -> node["slot"] == slot && node end)

  def holder(_, _), do: nil

  @doc "A prop's or a field's type, from its declaration."
  def type(%{"type" => t}), do: t
  def type(t), do: t

  ## Instances

  @doc "id → `{instance, path}` for a file's base instances, at any depth."
  def base(json),
    do: Map.new(nodes(json["children"] || [], ["children"]), fn {n, p} -> {n["id"], {n, p}} end)

  @doc "Every instance (and copy) in a file or a list of them, with its path."
  def nodes(%{} = json) do
    nodes(json["children"] || [], ["children"]) ++
      for {name, s} <- json["states"] || %{},
          n <- nodes(s["children"] || [], ["states", name, "children"]),
          do: n
  end

  def nodes(list) when is_list(list), do: nodes(list, [])

  defp nodes(list, at) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {node, i} ->
      p = at ++ [i]

      [{node, p}] ++
        nodes(node["children"] || [], p ++ ["children"]) ++
        Enum.flat_map(node["slots"] || %{}, fn {s, fills} -> nodes(fills, p ++ ["slots", s]) end)
    end)
  end

  @doc """
  A base instance with a copy's (or an `inner` entry's) settings laid
  over it, and the copy's `inner` laid over its children.
  """
  def override(base, set) do
    inner = set["inner"] || %{}

    base
    |> Map.merge(Map.drop(set, ["copy", "inner", "props"]))
    |> Map.put("props", Map.merge(base["props"] || %{}, set["props"] || %{}))
    |> Map.update("children", nil, &inner(&1, inner))
    |> Map.update("slots", nil, fn slots ->
      Map.new(slots, fn {k, v} -> {k, inner(v, inner)} end)
    end)
    |> Map.reject(fn {_, v} -> v == nil end)
  end

  defp inner(nodes, inner) when inner == %{}, do: nodes

  defp inner(nodes, inner),
    do: Enum.map(nodes, &override(&1, Map.put(inner[&1["id"]] || %{}, "inner", inner)))
end
