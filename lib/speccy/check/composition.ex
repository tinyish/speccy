defmodule Speccy.Check.Composition do
  @moduledoc """
  The composition rules (`format.md` § The checker's rules): nothing
  pressable inside a pressable, a tab only in a tablist, a tabpanel named by
  a tab's `controls`, `controls` naming an id where the tree is drawn,
  `current` only on pressables. They run on the trees the canvas draws
  (`decisions.md#composition-on-drawn-frames`): every frame of every screen
  and component, as `Speccy.Resolve` resolves it. Primitives are read
  through their interfaces.
  """

  import Speccy.Check, only: [problem: 4]
  alias Speccy.{Format, Resolve, Spec}

  @doc "Every composition problem in the spec's components and screens."
  def run(spec) do
    found =
      for {path, json} <- spec.valid, kind = Format.kind(path), kind in [:screen, :component] do
        frames =
          for {state, _} <- Spec.frames(spec, path),
              do: {state, rules(spec, Resolve.frame(spec, path, state), kind == :component)}

        {path, json, frames}
      end

    # What each component's own frames find, by code and origin.
    own =
      for {path, _, frames} <- found, Format.kind(path) == :component, into: %{} do
        {path, MapSet.new(for {_, fs} <- frames, f <- fs, do: {f.code, f.origin})}
      end

    for {path, json, frames} <- found, f <- report(frames, json, own) do
      problem(f.code, path, f.at, detail(spec, f))
    end
  end

  # A state's copy reports only what it brings: what its base frame finds at
  # the same base place is left to the base. Nor is what a component's own
  # frames find reported again where it is used. One problem per code and place.
  defp report(frames, json, own) do
    base = MapSet.new(for {nil, fs} <- frames, f <- fs, do: {f.code, f.origin})
    ids = Spec.base(json)

    for(
      {state, fs} <- frames,
      f <- fs,
      state == nil or {f.code, based(f.origin, ids)} not in base,
      not Enum.any?(inside(f.origin), &({f.code, &1} in Map.get(own, hd(&1).file, []))),
      do: f
    )
    |> Enum.uniq_by(&{&1.code, &1.at})
  end

  # An origin's tails from its second entry: where it is in each component around it.
  defp inside([_ | []]), do: []
  defp inside([_ | rest]), do: [rest | inside(rest)]

  # An origin with a copy, or a part its `inner` names, at its base path.
  defp based([%{at: ["states" | _], id: id} = e | rest], ids) when is_map_key(ids, id),
    do: [%{e | at: elem(ids[id], 1)} | rest]

  defp based(origin, _ids), do: origin

  ## The rules

  defp rules(spec, tree, component?) do
    # A component's own frame has no surroundings: its tabs are taken to be in a tablist.
    seen =
      walk(spec, tree, %{pressable: false, tablist: component?, copy: nil}, []) |> Enum.reverse()

    tabs = for {n, %{role: "tab"} = f, _} <- seen, do: controls(n, f.i)
    named = MapSet.new(tabs)

    # Where each id is written, when some `controls` names one.
    scopes =
      if Enum.any?(seen, fn {n, f, _} -> is_binary(controls(n, f.i)) end),
        do:
          seen
          |> Enum.group_by(fn {n, _, _} -> Enum.drop(n.origin, -1) end, fn {n, _, _} -> n.id end)
          |> Map.new(fn {k, ids} -> {k, MapSet.new(ids)} end),
        else: %{}

    for {n, %{i: i} = f, inside} <- seen,
        i != nil,
        {code, what} <- [
          f.pressable and inside.pressable and {:"pressable-in-pressable", n.use},
          f.role == "tab" and not inside.tablist and {:"tab-outside-tablist", n.use},
          f.role == "tabpanel" and (not component? or tabs != []) and :unknown not in tabs and
            n.id not in named and {:"tabpanel-without-tab", n.use},
          unresolved(n, i, component?, scopes),
          current(n, i, f)
        ],
        do: finding(n, inside, code, what)
  end

  # A known `controls`, set away from its default, naming no id where the
  # tree is drawn. A component's own frame leaves one it gets through `bind`
  # to where it is used.
  defp unresolved(n, i, component?, scopes) do
    c = controls(n, i)

    is_binary(c) and c != "" and c != i.defaults[i.aria["controls"]] and
      not (component? and i.aria["controls"] in n.bound) and
      not visible?(scopes, n.origin, c) and {:"controls-unresolved", c}
  end

  # A known `current`, set away from its default, on what can't be pressed.
  defp current(n, i, f) do
    k = i.aria["current"]

    k != nil and k not in n.unknown and n.props[k] != i.defaults[k] and not f.pressable and
      {:"current-not-pressable", n.use}
  end

  # Each node with its facts and what it is inside, in tree order (reversed).
  defp walk(spec, node, inside, acc) do
    f = facts(spec, node)
    [e | _] = node.origin
    # A copy in a state, whose parts are reported at it.
    copy = if List.first(e.at) == "states" and "inner" not in e.at, do: e, else: inside.copy

    within = %{
      pressable: inside.pressable or f.pressable,
      tablist: inside.tablist or f.role == "tablist",
      copy: copy
    }

    Enum.reduce(node.children, [{node, f, inside} | acc], &walk(spec, &1, within, &2))
  end

  defp facts(spec, %{kind: :primitive} = n) do
    {:primitive, i} = Spec.target(spec, n.use)
    role = i.aria["role"]

    %{
      i: i,
      pressable:
        case i.pressable do
          {:prop, p} -> p in n.unknown or truthy?(n.props[p])
          always -> always
        end,
      role: if(role && role not in n.unknown, do: n.props[role])
    }
  end

  defp facts(_spec, _n), do: %{i: nil, pressable: false, role: nil}

  defp truthy?(v), do: v == true or (is_binary(v) and v != "")

  # A node's `controls`: its value, `:unknown`, or nil.
  defp controls(_n, nil), do: nil

  defp controls(n, i) do
    case i.aria["controls"] do
      nil -> nil
      c -> if c in n.unknown, do: :unknown, else: n.props[c]
    end
  end

  # Whether an id is written in the file the node is in, or in one around it
  # where the tree is drawn: never inside another component instance.
  defp visible?(scopes, origin, id),
    do: Enum.any?(0..(length(origin) - 1)//1, &(id in Map.get(scopes, Enum.take(origin, &1), [])))

  # A problem at the first entry of the node's origin, or at its copy when
  # it is a part of one the copy's `inner` doesn't name.
  defp finding(n, inside, code, what) do
    [e | _] = n.origin

    if inside.copy && List.first(e.at) == "children",
      do: %{code: code, origin: n.origin, at: inside.copy.at, what: what, copy: inside.copy.id},
      else: %{code: code, origin: n.origin, at: e.at, what: what, copy: nil}
  end

  # What was found, and where it is inside its place.
  defp detail(spec, %{origin: [e | rest]} = f) do
    under = if f.copy, do: ["inside #{f.copy}, at #{pointer(e.at)}"], else: []

    within =
      for r <- rest, do: "inside #{spec.valid[r.file]["component"]}, at #{pointer(r.at)}"

    Enum.join([f.what | under ++ within], ", ")
  end

  defp pointer(path), do: Enum.map_join(path, &"/#{&1}")
end
