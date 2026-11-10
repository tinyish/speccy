defmodule Speccy.Check do
  @moduledoc """
  Checks a loaded spec (`Speccy.Format.load/1`): every file against its
  kind's JSON Schema, then the rules no schema expresses (`format.md` § The
  checker's rules). A problem is `%{code, file, path, message}`, `path` a
  JSON Pointer inside `file`.

  The schemas run in `Speccy.Check.Schema`, the composition rules in
  `Speccy.Check.Composition`, the icon rules in `Speccy.Check.Icons`; the
  rest are here. The rules read only files
  that pass their schema; an item whose file doesn't is still known by name,
  for its own kind, so nothing that uses it is reported for it. Primitives
  are read through their interfaces, never by name.
  """

  alias Speccy.{Devices, Format, Icons, Primitives, Schemas}
  alias Speccy.Check.{Composition, Schema}
  alias Speccy.Check.Icons, as: IconRules

  @codes [
    "invalid-json": "The file can't be read as JSON",
    "wrong-schema": "`$schema` isn't the URL of this kind of file's schema",
    "missing-key": "A required key is missing",
    "unknown-key": "This object doesn't take this key",
    "bad-name": "A name or path isn't written as format.md's Names say",
    "bad-value": "This key doesn't take this value",
    "unknown-format": "`format` isn't a version this speccy reads",
    "name-mismatch": "The file isn't named after its item",
    "duplicate-name": "Another component, screen or data model has this name",
    "device-is-preset": "A spec's device can't take a preset's name",
    "icon-set-is-library": "A spec's icon set can't take the name of a library speccy supports",
    "unsafe-svg": "The SVG isn't safe to draw",
    "malformed-svg":
      "The SVG isn't well-formed UTF-8 XML with one `svg` root and nothing after it",
    "unknown-device": "`device` names no preset and none of the spec's devices",
    "unknown-orientation": "The device doesn't have this orientation",
    "unknown-type": "The type names no data model",
    "unknown-use": "`use` names no primitive or component",
    "unknown-prop": "Its primitive or component declares no such prop",
    "unknown-state": "Its primitive or component has no such state",
    "unknown-variation": "There is no such variation of that state, or of the component's base",
    "unknown-slot": "Its component has no slot of this name",
    "unknown-copy": "No base instance has this id",
    "unknown-data": "The screen has no data of this name",
    "inner-unresolved": "No instance inside the copied one has this id",
    "unknown-icon-set":
      "The icon's set is no library speccy supports and none of the spec's sets",
    "unknown-icon": "The icon's set has no icon of this name",
    "unknown-icon-style": "The icon has no such style; a spec's own set takes none",
    "content-unresolved":
      "No instance in the state has this id, or it has no text or icon prop of this name",
    "bind-unresolved": "The path doesn't resolve",
    "repeat-unresolved": "`repeat.each` doesn't resolve",
    "duplicate-id": "Another instance in the file, or a copy in the same state, has this id",
    "bound-and-literal": "A prop, state or variation is either literal or bound, not both",
    "bound-state-type": "A bound state or variation must read an enum of its names",
    "prop-type": "The value doesn't fit the prop's type",
    "sample-type": "The sample doesn't fit the data's type",
    "bind-type": "The path's type isn't the prop's",
    "repeat-not-list": "`repeat.each` isn't a list",
    "layout-on-leaf": "Layout fields only go on what holds children",
    "children-on-leaf": "Only primitives that hold children have children",
    "wrap-not-flow": "`wrap` only goes on a row or a column",
    "grid-field-off-grid":
      "`columns` and `rows`, and `lineGap` without `wrap`, only go on a grid",
    "grid-placement-off-grid": "Grid placement only goes on a grid's children",
    "outside-tracks": "The placement is outside the grid's tracks",
    "position-without-absolute": "`x`, `y` and `constraints` only go with `absolute`",
    "slot-misplaced":
      "`slot` only goes inside a component, on a container, list or dialog with no children of its own",
    "component-cycle": "The component is used inside itself",
    "pressable-in-pressable": "Something pressable is inside something pressable",
    "tab-outside-tablist": "A tab is only in a tablist",
    "tabpanel-without-tab": "No tab's `controls` names this tabpanel",
    "controls-unresolved": "`controls` names no instance in the file",
    "current-not-pressable": "`current` only goes on pressables and links"
  ]

  @doc "Every code with its message, in one list."
  def codes, do: @codes

  @layout ~w(layout wrap columns rows align gap lineGap padding clip)

  @doc "Every problem in `spec`, sorted by file, path and code."
  def run(%{files: files, icons: icons}) do
    {broken, read} = Enum.split_with(files, &match?({_, {:error, _}}, &1))
    read = Map.new(read, fn {path, json} -> {path, plain(json)} end)
    schema = Map.new(read, fn {path, json} -> {path, Schema.problems(path, json)} end)
    spec = index(files, read, Map.filter(read, &(schema[elem(&1, 0)] == [])), icons)

    (Enum.map(broken, fn {path, {:error, why}} -> problem(:"invalid-json", path, [], why) end) ++
       Enum.concat(Map.values(schema)) ++
       files(spec) ++ IconRules.run(icons, spec.icons) ++ items(spec) ++ Composition.run(spec))
    |> Enum.uniq_by(&{&1.code, &1.file, &1.path})
    |> Enum.sort_by(&{&1.file, &1.path, &1.code})
  end

  ## The spec's index

  defp index(files, read, valid, icons) do
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
      read: read,
      valid: valid,
      items: items,
      # Names per kind, files that fail their schema included.
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
      icons: Icons.sets(icons)
    }
  end

  defp name_key(:component), do: "component"
  defp name_key(:screen), do: "screen"
  defp name_key(:data), do: "data"

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

  ## Files

  defp files(spec) do
    names =
      for {name, kind, path} <- spec.items do
        [
          if(Path.basename(path, ".json") != name,
            do: problem(:"name-mismatch", path, [name_key(kind)], name)
          ),
          if(Enum.count(spec.items, &(elem(&1, 0) == name)) > 1,
            do: problem(:"duplicate-name", path, [name_key(kind)], name)
          )
        ]
      end

    manifest =
      case spec.valid["speccy.json"] do
        nil ->
          []

        json ->
          presets =
            for {name, _} <- json["devices"] || %{},
                Devices.get(name),
                do: problem(:"device-is-preset", "speccy.json", ["devices", name], name)

          [
            if(json["format"] != Schemas.format(),
              do: problem(:"unknown-format", "speccy.json", ["format"], json["format"])
            )
            | presets
          ]
      end

    Enum.reject(List.flatten(names) ++ manifest, &is_nil/1)
  end

  defp icon_values(env, v, t, at), do: IconRules.values(env.spec, env.file, v, t, at)

  ## Components and screens

  defp items(spec) do
    for {path, json} <- spec.valid, kind = Format.kind(path), kind != :manifest do
      if kind == :data,
        do:
          for(
            {f, t} <- json["fields"] || %{},
            do: unknown_type(%{spec: spec, file: path}, type(t), ["fields", f])
          ),
        else: item(spec, path, kind, json)
    end
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp item(spec, file, kind, json) do
    scope =
      case kind do
        :component -> Map.new(json["props"] || %{}, fn {k, v} -> {k, type(v)} end)
        :screen -> Map.new(json["data"] || %{}, fn {k, v} -> {k, v["type"]} end)
      end

    env = %{spec: spec, file: file, kind: kind, json: json, scope: scope, base: base(json)}
    states = json["states"] || %{}

    [
      own(env, json, []),
      types(env, kind, json),
      variations(env, json["variations"], ["variations"], frame(env, json["children"] || [])),
      walk(env, json["children"] || [], ["children"], json, scope),
      for {name, state} <- states do
        at = ["states", name]

        [
          walk(env, state["children"] || [], at ++ ["children"], json, scope),
          variations(
            env,
            state["variations"],
            at ++ ["variations"],
            frame(env, state["children"] || [])
          ),
          for {data, value} <- state["data"] || %{} do
            cond do
              !Map.has_key?(scope, data) ->
                problem(:"unknown-data", file, at ++ ["data", data], data)

              !fits?(value, scope[data], spec) ->
                problem(:"sample-type", file, at ++ ["data", data], scope[data])

              true ->
                icon_values(env, value, scope[data], at ++ ["data", data])
            end
          end
        ]
      end,
      duplicate_ids(env, json)
    ]
  end

  defp types(env, :component, json) do
    for {name, decl} <- json["props"] || %{} do
      at = ["props", name]

      [
        unknown_type(env, type(decl), at),
        cond do
          !is_map(decl) or !Map.has_key?(decl, "default") ->
            nil

          !fits?(decl["default"], decl["type"], env.spec) ->
            problem(:"prop-type", env.file, at ++ ["default"], decl["type"])

          true ->
            icon_values(env, decl["default"], decl["type"], at ++ ["default"])
        end
      ]
    end
  end

  defp types(env, :screen, json) do
    [
      cond do
        json["orientation"] == nil or env.spec.devices == :unknown ->
          nil

        device = env.spec.devices[json["device"]] ->
          if(json["orientation"] not in orientations(device),
            do: problem(:"unknown-orientation", env.file, ["orientation"], json["orientation"])
          )

        true ->
          nil
      end,
      if(env.spec.devices != :unknown and !Map.has_key?(env.spec.devices, json["device"]),
        do: problem(:"unknown-device", env.file, ["device"], json["device"])
      ),
      for {name, %{"type" => type} = data} <- json["data"] || %{} do
        [
          unknown_type(env, type, ["data", name, "type"]),
          cond do
            !Map.has_key?(data, "sample") ->
              nil

            !fits?(data["sample"], type, env.spec) ->
              problem(:"sample-type", env.file, ["data", name, "sample"], type)

            true ->
              icon_values(env, data["sample"], type, ["data", name, "sample"])
          end
        ]
      end
    ]
  end

  defp orientations(%{"orientations" => list}), do: list

  defp orientations(%{"width" => w, "height" => h}),
    do: [if(w > h, do: "landscape", else: "portrait")]

  defp unknown_type(env, type, at) do
    case model(type) do
      nil -> nil
      name -> if name not in env.spec.known.data, do: problem(:"unknown-type", env.file, at, type)
    end
  end

  # The data model a type names, if any.
  defp model(type) when is_binary(type) do
    case Regex.run(~r/^([A-Z][A-Za-z0-9]*)(\[\])?$/, type) do
      [_, name | _] -> name
      nil -> nil
    end
  end

  defp model(_), do: nil

  ## Instances

  defp walk(env, nodes, at, parent, scope) do
    nodes
    |> Enum.with_index()
    |> Enum.map(fn {node, i} ->
      p = at ++ [i]

      if Map.has_key?(node, "copy"),
        do: copy(env, node, p, parent),
        else: instance(env, node, p, parent, scope)
    end)
  end

  defp instance(env, node, p, parent, scope) do
    target = target(env.spec, node["use"])
    scope = repeat_scope(env, node["repeat"], scope)
    holds = holds?(target)

    [
      if(!target and node["use"] not in env.spec.known.component,
        do: problem(:"unknown-use", env.file, p ++ ["use"], node["use"])
      ),
      if(
        match?({:component, _}, target) and env.kind == :component and
          (node["use"] == env.json["component"] or
             env.json["component"] in Map.get(env.spec.reaches, node["use"], [])),
        do: problem(:"component-cycle", env.file, p ++ ["use"], node["use"])
      ),
      settings(env, node, node, target, p, parent),
      binds(env, node, target, p, scope),
      with %{"each" => each} <- node["repeat"] do
        case path_type(env, each, scope) do
          :error ->
            problem(:"repeat-unresolved", env.file, p ++ ["repeat", "each"], each)

          {:ok, t} ->
            if !list_type?(t),
              do: problem(:"repeat-not-list", env.file, p ++ ["repeat", "each"], each)

          :unknown ->
            nil
        end
      end,
      for {slot, fills} <- node["slots"] || %{} do
        [
          if(target && slot not in slots(target),
            do: problem(:"unknown-slot", env.file, p ++ ["slots", slot], slot)
          ),
          walk(env, fills, p ++ ["slots", slot], holder(target, slot) || :unknown, scope)
        ]
      end,
      if(
        Map.has_key?(node, "slot") and
          (env.kind != :component or match?({:component, _}, target) or
             match?({:primitive, %{slot: false}}, target) or node["children"] not in [nil, []]),
        do: problem(:"slot-misplaced", env.file, p ++ ["slot"], node["slot"])
      ),
      if(holds == false,
        do:
          for(
            key <- @layout,
            Map.has_key?(node, key),
            do: problem(:"layout-on-leaf", env.file, p ++ [key], key)
          )
      ),
      if(holds == false and Map.has_key?(node, "children"),
        do: problem(:"children-on-leaf", env.file, p ++ ["children"], nil)
      ),
      own(env, node, p),
      walk(env, node["children"] || [], p ++ ["children"], node, scope)
    ]
  end

  # A linked copy in a state: its base instance with what it sets.
  defp copy(env, node, p, parent) do
    case env.base[node["copy"]] do
      nil ->
        problem(:"unknown-copy", env.file, p ++ ["copy"], node["copy"])

      {base, _} ->
        inside = Map.new(nodes([base]) |> tl(), fn {n, _} -> {n["id"], n} end)

        [
          settings(env, node, override(base, node), target(env.spec, base["use"]), p, parent),
          for {id, set} <- node["inner"] || %{} do
            case inside[id] do
              nil ->
                problem(:"inner-unresolved", env.file, p ++ ["inner", id], id)

              n ->
                settings(
                  env,
                  set,
                  override(n, set),
                  target(env.spec, n["use"]),
                  p ++ ["inner", id],
                  :unknown
                )
            end
          end
        ]
    end
  end

  # What an instance, a copy or an `inner` entry sets (`set`), against what
  # it ends up as (`node`): props, state, variation, placement.
  defp settings(env, set, node, target, p, parent) do
    props = props(target)

    [
      if target do
        for {k, v} <- set["props"] || %{} do
          cond do
            !Map.has_key?(props, k) ->
              problem(:"unknown-prop", env.file, p ++ ["props", k], k)

            !fits?(v, props[k], env.spec) ->
              problem(:"prop-type", env.file, p ++ ["props", k], props[k])

            true ->
              icon_values(env, v, props[k], p ++ ["props", k])
          end
        end
      end,
      if(target != nil and Map.has_key?(set, "state") and set["state"] not in states(target),
        do: problem(:"unknown-state", env.file, p ++ ["state"], set["state"])
      ),
      if(
        target != nil and Map.has_key?(set, "variation") and
          set["variation"] not in variations(target, node["state"]),
        do: problem(:"unknown-variation", env.file, p ++ ["variation"], set["variation"])
      ),
      if(!node["absolute"],
        do:
          for(
            key <- ~w(x y constraints),
            Map.has_key?(set, key),
            do: problem(:"position-without-absolute", env.file, p ++ [key], key)
          )
      ),
      placement(env, set, node, p, parent)
    ]
  end

  defp placement(_env, _set, _node, _p, :unknown), do: nil

  defp placement(env, set, node, p, parent) do
    if (parent["layout"] || "column") != "grid" do
      for key <- ~w(column row columnSpan rowSpan),
          Map.has_key?(set, key),
          do: problem(:"grid-placement-off-grid", env.file, p ++ [key], key)
    else
      for {start, span, tracks} <- [
            {"column", "columnSpan", "columns"},
            {"row", "rowSpan", "rows"}
          ],
          n = count(parent[tracks]),
          n && (node[start] || 1) + (node[span] || 1) - 1 > n,
          key = if(Map.has_key?(set, start), do: start, else: span),
          Map.has_key?(set, key),
          do: problem(:"outside-tracks", env.file, p ++ [key], n)
    end
  end

  defp count(n) when is_integer(n), do: n
  defp count(list) when is_list(list), do: length(list)
  defp count(nil), do: nil

  # The layout fields an object with children sets on itself.
  defp own(env, node, p) do
    layout = node["layout"] || "column"

    [
      if(node["wrap"] == true and layout not in ["row", "column"],
        do: problem(:"wrap-not-flow", env.file, p ++ ["wrap"], layout)
      ),
      for(
        key <- ~w(columns rows),
        Map.has_key?(node, key),
        layout != "grid",
        do: problem(:"grid-field-off-grid", env.file, p ++ [key], key)
      ),
      if(Map.has_key?(node, "lineGap") and layout != "grid" and node["wrap"] != true,
        do: problem(:"grid-field-off-grid", env.file, p ++ ["lineGap"], "lineGap")
      )
    ]
  end

  defp binds(env, node, target, p, scope) do
    props = props(target)

    for {k, path} <- node["bind"] || %{} do
      at = p ++ ["bind", k]

      cond do
        target != nil and k not in ["state", "variation"] and !Map.has_key?(props, k) ->
          problem(:"unknown-prop", env.file, at, k)

        Map.has_key?(node["props"] || %{}, k) or
            (k in ["state", "variation"] and Map.has_key?(node, k)) ->
          problem(:"bound-and-literal", env.file, at, k)

        true ->
          case path_type(env, path, scope) do
            :error -> problem(:"bind-unresolved", env.file, at, path)
            :unknown -> nil
            {:ok, t} -> bind_type(env, node, target, k, t, at)
          end
      end
    end
  end

  defp bind_type(_env, _node, nil, _k, _t, _at), do: nil

  defp bind_type(env, node, target, k, t, at) do
    props = props(target)

    names =
      case k do
        "state" ->
          states(target)

        "variation" ->
          if(node["bind"]["state"],
            do: all_variations(target),
            else: variations(target, node["state"])
          )

        _ ->
          nil
      end

    cond do
      names ->
        if !(is_list(t) and t -- names == []),
          do: problem(:"bound-state-type", env.file, at, inspect(names))

      !compatible?(props[k], t) ->
        problem(:"bind-type", env.file, at, props[k])

      true ->
        nil
    end
  end

  defp compatible?(t, t), do: true
  defp compatible?("text", path) when is_list(path), do: true
  defp compatible?(prop, path) when is_list(prop) and is_list(path), do: path -- prop == []
  defp compatible?("model", path), do: model(path) != nil and !list_type?(path)
  defp compatible?("model[]", path), do: model(path) != nil and list_type?(path)
  defp compatible?(_, _), do: false

  # The type a bind path reads, from the scope's names into models' fields.
  defp path_type(env, path, scope) do
    [root | fields] = String.split(path, ".")

    case scope[root] do
      nil ->
        :error

      :unknown ->
        :unknown

      t ->
        Enum.reduce_while(fields, {:ok, t}, fn field, {:ok, t} ->
          name = if(!list_type?(t), do: model(t))

          case name && env.spec.models[name] do
            nil -> {:halt, if(name && name in env.spec.known.data, do: :unknown, else: :error)}
            fields -> if f = fields[field], do: {:cont, {:ok, f}}, else: {:halt, :error}
          end
        end)
    end
  end

  # A repeat's `as` reads one item of its list; :unknown when that can't be told.
  defp repeat_scope(env, %{"as" => as, "each" => each}, scope) do
    case path_type(env, each, scope) do
      {:ok, t} -> Map.put(scope, as, if(list_type?(t), do: item_type(t), else: :unknown))
      _ -> Map.put(scope, as, :unknown)
    end
  end

  defp repeat_scope(_env, _repeat, scope), do: scope

  defp list_type?(t), do: is_binary(t) and String.ends_with?(t, "[]")
  defp item_type(t) when is_binary(t), do: String.trim_trailing(t, "[]")

  ## Variations, ids

  defp variations(_env, nil, _at, _frame), do: []

  defp variations(env, vars, at, frame) do
    for {name, var} <- vars, {key, value} <- var["content"] || %{} do
      [id, prop] = String.split(key, ".")
      p = at ++ [name, "content", key]
      t = with %{} = node <- frame[id], do: props(target(env.spec, node["use"]))[prop]

      cond do
        frame[id] && !target(env.spec, frame[id]["use"]) -> nil
        t not in ["text", "icon"] -> problem(:"content-unresolved", env.file, p, key)
        !fits?(value, t, env.spec) -> problem(:"prop-type", env.file, p, t)
        true -> icon_values(env, value, t, p)
      end
    end
  end

  # id → instance, for every instance a frame shows: its own and its copies,
  # with everything inside them.
  defp frame(env, children) do
    for {node, _} <- nodes(children),
        {n, _} <-
          if(c = node["copy"],
            do: (env.base[c] && nodes([elem(env.base[c], 0)])) || [],
            else: [{node, nil}]
          ),
        into: %{},
        do: {n["id"], n}
  end

  defp duplicate_ids(env, json) do
    own = for {node, p} <- nodes(json), id = node["id"], do: {{nil, id}, p}

    copies =
      for {name, state} <- json["states"] || %{},
          {node, p} <- nodes(state["children"] || [], ["states", name, "children"]),
          id = node["copy"],
          do: {{name, id}, p}

    # Ids are unique across the file; a copy, within its state.
    for {{_, id}, [_ | dups]} <- Enum.group_by(own ++ copies, &elem(&1, 0), &elem(&1, 1)),
        p <- dups,
        do: problem(:"duplicate-id", env.file, p, id)
  end

  ## Reading targets

  @doc false
  def target(spec, use) do
    cond do
      !is_binary(use) -> nil
      module = Primitives.get(use) -> {:primitive, module.interface()}
      json = spec.components[use] -> {:component, json}
      true -> nil
    end
  end

  defp holds?({:primitive, i}), do: i.children
  defp holds?({:component, _}), do: false
  defp holds?(nil), do: nil

  defp props({:primitive, i}), do: Map.new(i.props)
  defp props({:component, json}), do: Map.new(json["props"] || %{}, fn {k, v} -> {k, type(v)} end)
  defp props(nil), do: %{}

  defp states({:primitive, i}), do: Enum.map(i.states, &elem(&1, 0))
  defp states({:component, json}), do: Map.keys(json["states"] || %{})

  defp variations({:primitive, _}, _state), do: []
  defp variations({:component, json}, nil), do: Map.keys(json["variations"] || %{})

  defp variations({:component, json}, state),
    do: Map.keys(get_in(json, ["states", state, "variations"]) || %{})

  defp all_variations(target),
    do: Enum.flat_map([nil | states(target)], &variations(target, &1))

  defp slots({:component, json}), do: for({node, _} <- nodes(json), s = node["slot"], do: s)
  defp slots(_), do: []

  # The layout a slot's fills sit in: its holder in the component.
  defp holder({:component, json}, slot),
    do: Enum.find_value(nodes(json), fn {node, _} -> node["slot"] == slot && node end)

  defp holder(_, _), do: nil

  ## Values and types

  defp type(%{"type" => t}), do: t
  defp type(t), do: t

  defp fits?(v, "text", _), do: is_binary(v)
  defp fits?(v, "bool", _), do: is_boolean(v)
  defp fits?(v, "number", _), do: is_number(v)
  defp fits?(v, "icon", _), do: Icons.parse(v) != :error
  defp fits?(v, "text[]", _), do: is_list(v) and Enum.all?(v, &is_binary/1)
  defp fits?(v, "model", _), do: is_map(v)
  defp fits?(v, "model[]", _), do: is_list(v) and Enum.all?(v, &is_map/1)
  defp fits?(v, enum, _) when is_list(enum), do: v in enum

  defp fits?(v, t, spec) do
    if list_type?(t) do
      is_list(v) and Enum.all?(v, &fits?(&1, item_type(t), spec))
    else
      case spec.models[t] do
        nil ->
          true

        fields ->
          is_map(v) and
            Enum.all?(v, fn {f, fv} ->
              Map.has_key?(fields, f) and (fv == nil or fits?(fv, fields[f], spec))
            end)
      end
    end
  end

  ## Helpers

  # id → {instance, path} for the base's instances, at any depth.
  @doc false
  def base(json),
    do: Map.new(nodes(json["children"] || [], ["children"]), fn {n, p} -> {n["id"], {n, p}} end)

  # Every instance (and copy) in a file or a list of them, with its path.
  @doc false
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

  # A base instance with a copy's (or an `inner` entry's) settings laid
  # over it, and the copy's `inner` laid over its children.
  @doc false
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

  defp plain(%Jason.OrderedObject{values: values}),
    do: Map.new(values, fn {k, v} -> {k, plain(v)} end)

  defp plain(list) when is_list(list), do: Enum.map(list, &plain/1)
  defp plain(value), do: value

  @doc "A problem: `code`, `file`, `path` (a list of keys and indexes) and a detail for its message."
  def problem(code, file, path, detail) do
    %{
      code: code,
      file: file,
      path: Enum.map_join(path, &("/" <> escape(&1))),
      message: message(code, detail)
    }
  end

  defp message(code, nil), do: Keyword.fetch!(@codes, code)

  defp message(code, detail) when is_binary(detail),
    do: "#{Keyword.fetch!(@codes, code)}: #{detail}"

  defp message(code, detail), do: message(code, inspect(detail))

  defp escape(key),
    do: key |> to_string() |> String.replace("~", "~0") |> String.replace("/", "~1")
end
