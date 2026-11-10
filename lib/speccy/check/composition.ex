defmodule Speccy.Check.Composition do
  @moduledoc """
  The composition rules (`format.md` § The checker's rules): nothing
  pressable inside a pressable, a tab only in a tablist, a tabpanel named by
  a tab's `controls`, `controls` naming an id in its file, `current` only on
  pressables. They look through component instances.

  A plain walk of each file, its base and every state, carrying whether it
  is inside something pressable and inside a tablist. A component instance
  is walked in place, with the values its instance gives its props, and
  what the walk finds inside is reported at the instance. Each component is
  also walked alone, with its props' defaults; what it reports alone isn't
  reported again where it is used. Primitives are read through their
  interfaces. A value bound to data is unknown, and counts as set.
  """

  import Speccy.Check, only: [problem: 4, target: 2, nodes: 1, base: 1, override: 2]

  @doc "Every composition problem in the spec's components and screens."
  def run(spec) do
    # Each component alone, those that use fewer components first, so one is
    # walked after the ones it uses.
    alone =
      spec.components
      |> Enum.sort_by(fn {name, _} -> Enum.count(spec.reaches[name]) end)
      |> Enum.reduce(%{}, fn {name, json}, done ->
        file = spec.paths[name]
        env = Map.new(json["props"] || %{}, fn {p, decl} -> {p, default(decl, p, file, 0)} end)
        # Alone, nothing says where it sits: not in a pressable, and its
        # tabs are taken to be in a tablist.
        items =
          frames(walker(spec, done, file, json, env), json, %{pressable: false, tablist: true})

        Map.put(done, name, %{
          items: items,
          tab?: :tab in items,
          problems: MapSet.new(for {:problem, code, at, _} <- items, do: {code, at})
        })
      end)

    components =
      for {name, a} <- alone, do: report(a.items, spec.paths[name], spec.components[name], a.tab?)

    screens =
      for {path, json} <- spec.valid, Speccy.Format.kind(path) == :screen do
        w = walker(spec, alone, path, json, %{})
        report(frames(w, json, %{pressable: false, tablist: false}), path, json, true)
      end

    List.flatten(components ++ screens)
  end

  # `level` counts the component instances the walk is inside; `fills` is
  # the instance being walked in place: its walker, slots and path.
  defp walker(spec, alone, file, json, env) do
    %{spec: spec, alone: alone, file: file, env: env, base: base(json)}
    |> Map.merge(%{level: 0, fills: nil, stack: []})
  end

  # What a walked file reports: its problems, its tabpanels no tab names
  # (a component's only when it has tabs of its own; without, they count
  # where it is used), and `controls` written in it naming no id in it.
  defp report(items, file, json, panels?) do
    ids = MapSet.new(for {node, _} <- nodes(json), id = node["id"] || node["copy"], do: id)
    named = for {:controls, {:lit, v, _, _, _}, true} <- items, do: v

    for item <- items do
      case item do
        {:problem, code, at, detail} ->
          problem(code, file, at, detail)

        {:tabpanel, id, at} ->
          if panels? and id not in named, do: problem(:"tabpanel-without-tab", file, at, id)

        {:controls, {:lit, v, ^file, at, _}, _} ->
          if v not in ids, do: problem(:"controls-unresolved", file, at, v)

        _ ->
          nil
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  ## Walking

  # The base and every state, each copy in a state as its base instance
  # with the copy's settings laid over it.
  defp frames(w, json, ctx) do
    ([{json["children"] || [], ["children"]}] ++
       for(
         {name, s} <- json["states"] || %{},
         do: {s["children"] || [], ["states", name, "children"]}
       ))
    |> Enum.flat_map(fn {list, at} -> walk(w, list, at, ctx) end)
  end

  defp walk(w, list, at, ctx) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {node, i} ->
      case node do
        %{"copy" => id} ->
          case w.base[id] do
            nil -> []
            {base, base_at} -> node(w, override(base, node), at ++ [i], base_at, ctx)
          end

        node ->
          node(w, node, at ++ [i], at ++ [i], ctx)
      end
    end)
  end

  # `at` is where the node is reported; `base_at` where its children are.
  defp node(w, node, at, base_at, ctx) do
    case target(w.spec, node["use"]) do
      {:primitive, i} -> primitive(w, node, i, at, base_at, ctx)
      {:component, json} -> instance(w, node, json, at, ctx)
      nil -> fills(w, node, at, ctx, [])
    end
  end

  defp primitive(w, node, i, at, base_at, ctx) do
    value = &value(w, node, i, &1, at)

    pressable? =
      case i.pressable do
        {:prop, prop} -> truthy?(value.(prop))
        always -> always
      end

    role =
      case i.aria["role"] && value.(i.aria["role"]) do
        {:lit, v, _, _, _} when is_binary(v) -> v
        _ -> nil
      end

    inner = %{
      pressable: ctx.pressable or pressable?,
      tablist: ctx.tablist or role == "tablist"
    }

    here = [
      pressable? and ctx.pressable and {:problem, :"pressable-in-pressable", at, node["use"]},
      role == "tab" and :tab,
      role == "tab" and not ctx.tablist and {:problem, :"tab-outside-tablist", at, nil},
      role == "tabpanel" and {:tabpanel, node["id"], at},
      i.aria["current"] && current(value.(i.aria["current"]), i, pressable?, at),
      controls(i.aria["controls"] && value.(i.aria["controls"]), role)
    ]

    Enum.filter(here, & &1) ++
      held(w, node["slot"], inner) ++
      walk(w, node["children"] || [], base_at ++ ["children"], inner)
  end

  # A slot's holder, inside a component walked in place: the instance's
  # fills for it sit here, and belong to the instance's file.
  defp held(%{fills: {outer, slots, at}}, slot, ctx) when is_binary(slot),
    do:
      for(item <- walk(outer, slots[slot] || [], at ++ ["slots", slot], ctx), do: {:outer, item})

  defp held(_w, _slot, _ctx), do: []

  # `current` set away from its default, on what can't be pressed.
  defp current({:lit, v, origin, _, _}, i, false, at) when origin != :default,
    do: v != i.defaults[i.aria["current"]] && {:problem, :"current-not-pressable", at, v}

  defp current(_value, _i, _pressable?, _at), do: nil

  defp controls({:lit, v, origin, _, _} = lit, role)
       when is_binary(v) and v != "" and origin != :default,
       do: {:controls, lit, role == "tab"}

  defp controls(_value, _role), do: nil

  # A component instance, walked in place with the instance's values.
  defp instance(w, node, json, at, ctx) do
    name = json["component"]
    a = w.alone[name]

    # A component not walked alone yet, or already being walked, is in a
    # cycle (`component-cycle`): only its fills are walked.
    if a == nil or name in w.stack do
      fills(w, node, at, ctx, [])
    else
      file = w.spec.paths[name]

      env =
        Map.new(json["props"] || %{}, fn {prop, decl} ->
          {prop, prop_value(w, node, prop, decl, at, file)}
        end)

      within = %{
        w
        | file: file,
          env: env,
          base: base(json),
          level: w.level + 1,
          fills: {w, node["slots"] || %{}, at},
          stack: [name | w.stack]
      }

      # What sits in its slots is the instance's file's own; of what is
      # inside the component, one problem per code is enough here.
      {filled, inside} = Enum.split_with(frames(within, json, ctx), &match?({:outer, _}, &1))
      found = for item <- inside, mine <- relay(item, w, node, at, name, a), do: mine
      held = for {n, _} <- nodes(json), slot = n["slot"], do: slot

      Enum.uniq_by(found, fn
        {:problem, code, _, _} -> code
        item -> item
      end) ++ for({:outer, item} <- filled, do: item) ++ fills(w, node, at, ctx, held)
    end
  end

  # What the walk inside an instance found, as the instance's file sees it.
  defp relay({:problem, code, inner, _}, _w, _node, at, name, a) do
    if {code, inner} in a.problems,
      do: [],
      else: [{:problem, code, at, "inside #{name}, at #{Enum.map_join(inner, &"/#{&1}")}"}]
  end

  defp relay({:tabpanel, _, _}, _w, node, at, _name, a),
    do: if(a.tab?, do: [], else: [{:tabpanel, node["id"], at}])

  # `controls` counts here when its value was written at this level or above.
  defp relay({:controls, {:lit, _, _, _, level}, _} = item, w, _node, _at, _name, _a),
    do: if(level <= w.level, do: [item], else: [])

  defp relay(:tab, _w, _node, _at, _name, _a), do: [:tab]

  # The fills of the slots not in `held`, in the instance's own place.
  defp fills(w, node, at, ctx, held) do
    for {slot, list} <- node["slots"] || %{},
        slot not in held,
        item <- walk(w, list, at ++ ["slots", slot], ctx),
        do: item
  end

  ## Values

  # A prop's value where it is read: `{:lit, value, file, path, level}` with
  # where it was written (`:default` for a primitive's own), :unknown when it
  # comes from data, nil when unset.
  defp value(w, node, i, prop, at) do
    state = with {_, s} <- List.keyfind(i.states, node["state"], 0), do: s.props

    cond do
      path = (node["bind"] || %{})[prop] ->
        eval(path, w.env)

      Map.has_key?(node["props"] || %{}, prop) ->
        {:lit, node["props"][prop], w.file, at ++ ["props", prop], w.level}

      is_map(state) and Map.has_key?(state, prop) ->
        {:lit, state[prop], :default, nil, w.level}

      Map.has_key?(i.defaults, prop) ->
        {:lit, i.defaults[prop], :default, nil, w.level}

      true ->
        nil
    end
  end

  defp prop_value(w, node, prop, decl, at, file) do
    cond do
      path = (node["bind"] || %{})[prop] ->
        eval(path, w.env)

      Map.has_key?(node["props"] || %{}, prop) ->
        {:lit, node["props"][prop], w.file, at ++ ["props", prop], w.level}

      true ->
        default(decl, prop, file, w.level)
    end
  end

  defp default(%{"default" => v}, prop, file, level),
    do: {:lit, v, file, ["props", prop, "default"], level}

  defp default(_decl, _prop, _file, _level), do: nil

  # A bind path's value in `env`, into its fields; :unknown outside it.
  defp eval(path, env) do
    [root | fields] = String.split(path, ".")

    case Map.fetch(env, root) do
      :error ->
        :unknown

      {:ok, {:lit, v, file, at, level}} ->
        {:lit, Enum.reduce(fields, v, &((is_map(&2) && &2[&1]) || nil)), file, at, level}

      {:ok, other} ->
        other
    end
  end

  defp truthy?(:unknown), do: true
  defp truthy?({:lit, v, _, _, _}), do: v == true or (is_binary(v) and v != "")
  defp truthy?(_), do: false
end
