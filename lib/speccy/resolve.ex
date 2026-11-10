defmodule Speccy.Resolve do
  @moduledoc """
  Turns one frame of a screen or a component into the tree the canvas
  draws, and the composition rules check. Pure, and it never raises on what
  a valid file holds (`conventions.md#resolve-is-total`): what can't be
  resolved is an error node carrying the check's code. It reads only
  `spec.valid`.

  A node is a map: `kind` (`:root`, `:primitive`, `:component` or
  `:error`), `use`, `id`, `origin` (where it is written, `%{file, at, id}`
  outermost first), `row`, `props` (as drawn), `bound`, `unknown`, `state`,
  `place`, `layout`, `children`, and `code` on an error node.
  """

  alias Speccy.{Format, Spec}

  @doc """
  The root node of the frame of `path` in `state` (nil for the base) and
  `variation` (nil for the frame as written).
  """
  def frame(spec, path, state \\ nil, variation \\ nil) do
    json = spec.valid[path]
    kind = json && Format.kind(path)
    root = %{file: path, at: [], id: nil}

    if kind in [:screen, :component] do
      st = get_in(json, ["states", state])
      state = st && state

      ctx = %{
        spec: spec,
        file: path,
        # Only a state holds copies.
        base: if(st, do: Spec.base(json), else: %{}),
        scope: scope(kind, json, st),
        strong: MapSet.new(),
        content: content(json, st, variation),
        prefix: [],
        copy: nil,
        fills: nil,
        stack: if(kind == :component, do: [json["component"]], else: [])
      }

      {list, at} = frame_children(json, st, state)

      blank()
      |> Map.merge(%{
        kind: :root,
        use: json[Spec.name_key(kind)],
        origin: [root],
        state: state,
        place: Map.take(json, ~w(width height)),
        layout: Map.take(json, Format.layout()),
        children: children(ctx, list, at)
      })
    else
      Map.merge(blank(), %{kind: :error, origin: [root], code: code(spec, path)})
    end
  end

  defp blank do
    %{
      kind: nil,
      use: nil,
      id: nil,
      origin: [],
      row: nil,
      props: %{},
      bound: [],
      unknown: [],
      state: nil,
      place: %{},
      layout: %{},
      children: []
    }
  end

  defp frame_children(json, nil, _state), do: {json["children"] || [], ["children"]}

  defp frame_children(_json, st, state),
    do: {st["children"] || [], ["states", state, "children"]}

  # A screen's samples, each replaced by the state's data; a component's
  # props alone, their defaults or unknown.
  defp scope(:screen, json, st) do
    Map.new(json["data"] || %{}, fn {k, d} -> {k, Map.get(d, "sample", :unknown)} end)
    |> Map.merge((st || %{})["data"] || %{})
  end

  defp scope(:component, json, _st) do
    Map.new(json["props"] || %{}, fn {k, d} ->
      {k, if(is_map(d) and Map.has_key?(d, "default"), do: d["default"], else: :unknown)}
    end)
  end

  # id → prop → value, from the frame's variation: its state's, else the base's.
  defp content(json, st, variation) do
    var = (st && get_in(st, ["variations", variation])) || get_in(json, ["variations", variation])

    for {key, v} <- (var || %{})["content"] || %{},
        [id, prop] <- [String.split(key, ".", parts: 2)],
        reduce: %{} do
      acc -> Map.update(acc, id, %{prop => v}, &Map.put(&1, prop, v))
    end
  end

  # The code of a file's first problem, by path, if it has one.
  defp code(spec, path) do
    case {spec.ordered[path], spec.schema[path]} do
      {{:error, _}, _} -> :"invalid-json"
      {_, [_ | _] = problems} -> Enum.min_by(problems, &{&1.path, &1.code}).code
      _ -> nil
    end
  end

  ## Instances

  defp children(ctx, list, at) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {n, i} -> instance(ctx, n, at ++ [i]) end)
  end

  # A linked copy: its base instance with the copy's settings, walked at the
  # base's path, written at the copy's (`at/3`).
  defp instance(ctx, %{"copy" => id} = n, p) do
    case ctx.base[id] do
      nil ->
        [error(ctx, n, p, nil, :"unknown-copy")]

      {b, bp} ->
        ctx = %{ctx | copy: {p, bp, Map.keys(n["inner"] || %{})}}
        instance(ctx, Spec.override(b, n), bp)
    end
  end

  defp instance(ctx, n, p) do
    case n["repeat"] do
      %{"each" => each, "as" => as} = r ->
        case eval(ctx.scope, each) do
          :error ->
            [error(ctx, n, p, nil, :"repeat-unresolved")]

          :unknown ->
            rows(ctx, n, p, as, List.duplicate(:unknown, min(3, r["limit"] || 3)))

          nil ->
            []

          list when is_list(list) ->
            rows(ctx, n, p, as, Enum.take(list, r["limit"] || length(list)))

          _ ->
            [error(ctx, n, p, nil, :"repeat-not-list")]
        end

      _ ->
        [single(ctx, n, p, nil)]
    end
  end

  defp rows(ctx, n, p, as, items) do
    for {item, row} <- Enum.with_index(items) do
      ctx = %{ctx | scope: Map.put(ctx.scope, as, item), strong: MapSet.delete(ctx.strong, as)}
      single(ctx, n, p, row)
    end
  end

  defp single(ctx, n, p, row) do
    binds = Map.new(n["bind"] || %{}, fn {k, path} -> {k, eval(ctx.scope, path)} end)
    target = Spec.target(ctx.spec, n["use"])

    cond do
      :error in Map.values(binds) -> error(ctx, n, p, row, :"bind-unresolved")
      target == nil -> error(ctx, n, p, row, unknown_use(ctx.spec, n["use"]))
      n["use"] in ctx.stack -> error(ctx, n, p, row, :"component-cycle")
      true -> expand(ctx, n, p, row, binds, target)
    end
  end

  defp expand(ctx, n, p, row, binds, {:primitive, i} = target) do
    {state, s} = List.keyfind(i.states, name(binds, n, "state"), 0, {nil, %{props: %{}}})
    {props, bound, unknown, _} = values(ctx, n, binds, Map.merge(i.defaults, s.props), target)

    node(ctx, n, p, row, %{
      kind: :primitive,
      props: props,
      bound: bound,
      unknown: unknown,
      state: state,
      layout: if(i.children, do: :maps.with(Format.layout(), n), else: %{}),
      children:
        if(i.children,
          do: children(ctx, n["children"] || [], p ++ ["children"]) ++ fills(ctx, n["slot"]),
          else: []
        )
    })
  end

  defp expand(ctx, n, p, row, binds, {:component, json} = target) do
    name = json["component"]
    state = name(binds, n, "state")
    st = get_in(json, ["states", state])
    state = st && state
    decl = json["props"] || %{}
    start = for {k, %{"default" => v}} <- decl, into: %{}, do: {k, v}
    {props, bound, unknown, strong} = values(ctx, n, binds, start, target)
    origin = origin(ctx, n, p)
    {list, at} = frame_children(json, st, state)

    inner = %{
      ctx
      | file: ctx.spec.paths[name],
        base: if(st, do: Spec.base(json), else: %{}),
        scope:
          Map.new(decl, fn {k, _} -> {k, if(k in unknown, do: :unknown, else: props[k])} end),
        strong: strong,
        content: content(json, st, name(binds, n, "variation")),
        prefix: origin,
        copy: nil,
        fills: {ctx, n["slots"] || %{}, p},
        stack: [name | ctx.stack]
    }

    node(ctx, n, p, row, %{
      kind: :component,
      props: props,
      bound: bound,
      unknown: unknown,
      state: state,
      # The component's own size, unless the instance sets its own.
      place: Map.merge(Map.take(json, ~w(width height)), :maps.with(Format.place(), n)),
      layout: Map.take(json, Format.layout()),
      children: children(inner, list, at)
    })
  end

  # A slot's holder holds its instance's fills, resolved where the instance is.
  defp fills(%{fills: {outer, slots, at}}, slot) when is_binary(slot),
    do: children(outer, slots[slot] || [], at ++ ["slots", slot])

  defp fills(_ctx, _slot), do: []

  # A node's props: `start`, then its literal and bound values, then its
  # frame's content, except where it binds a prop to one an outer frame's
  # content set (`strong`): that frame's wins. Also returns the props that
  # carry such a value on, for a component's scope.
  # Most nodes bind nothing, and no content sets them.
  defp values(%{content: c}, %{"id" => id} = n, binds, start, _target)
       when binds == %{} and not is_map_key(c, id),
       do: {Map.merge(start, n["props"] || %{}), [], [], MapSet.new()}

  defp values(ctx, n, binds, start, target) do
    bind = n["bind"] || %{}
    strong? = &(hd(String.split(&1, ".")) in ctx.strong)
    bound = Map.drop(binds, ["state", "variation"])

    content =
      Map.reject(ctx.content[n["id"]] || %{}, fn {k, _} -> bind[k] && strong?.(bind[k]) end)

    unknown = for {k, :unknown} <- bound, !Map.has_key?(content, k), do: k

    props =
      start
      |> Map.merge(n["props"] || %{})
      |> Map.merge(for {k, v} <- bound, v not in [nil, :unknown], into: %{}, do: {k, v})
      |> Map.merge(
        for k <- unknown, Spec.props(target)[k] == "text", into: %{}, do: {k, "{#{bind[k]}}"}
      )
      |> Map.merge(content)

    strong = MapSet.new(Map.keys(content) ++ for({k, _} <- bound, strong?.(bind[k]), do: k))
    {props, Map.keys(bound), unknown, strong}
  end

  # A bound or literal state or variation's name; empty or unknown is none.
  defp name(binds, n, key) do
    v = Map.get(binds, key, n[key])
    if is_binary(v) and v != "", do: v
  end

  defp node(ctx, n, p, row, fields) do
    Map.merge(
      %{
        blank()
        | use: n["use"],
          id: n["id"] || n["copy"],
          origin: origin(ctx, n, p),
          row: row,
          place: :maps.with(Format.place(), n)
      },
      fields
    )
  end

  defp error(ctx, n, p, row, code), do: node(ctx, n, p, row, %{kind: :error, code: code})

  defp origin(ctx, n, p),
    do:
      ctx.prefix ++
        [%{file: ctx.file, at: at(ctx, n["id"] || n["copy"], p), id: n["id"] || n["copy"]}]

  # Under a copy: the copy is written at its path in the state, a part its
  # `inner` names at that entry, any other part at its base path.
  defp at(%{copy: {copy_at, base_at, inner}}, id, p) do
    cond do
      p == base_at -> copy_at
      id in inner -> copy_at ++ ["inner", id]
      true -> p
    end
  end

  defp at(_ctx, _id, p), do: p

  # A `use` that names a component whose file isn't valid carries that file's problem.
  defp unknown_use(spec, use) do
    case Enum.find(spec.items, &match?({^use, :component, _}, &1)) do
      {_, _, path} -> code(spec, path)
      nil -> :"unknown-use"
    end
  end

  # A bind path's value in `scope`, into its fields: `:unknown` through an
  # unknown, nil through nil, `:error` where it can't go.
  defp eval(scope, path) do
    [root | fields] = String.split(path, ".")

    case Map.fetch(scope, root) do
      :error ->
        :error

      {:ok, v} ->
        Enum.reduce_while(fields, v, fn
          _, :unknown -> {:halt, :unknown}
          _, nil -> {:halt, nil}
          f, %{} = map -> {:cont, map[f]}
          _, _ -> {:halt, :error}
        end)
    end
  end
end
