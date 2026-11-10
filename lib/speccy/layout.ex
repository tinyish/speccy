defmodule Speccy.Layout do
  @moduledoc """
  Layout fields and sizes as CSS (`format.md` § Layout and § Instance),
  with `format.md`'s defaults. Pure: the browser works out the geometry,
  and nothing it computes is stored (`canvas-renders-dom`).
  """

  @doc "The CSS declarations of what holds children, from its layout fields."
  def box(layout) do
    flow = layout["layout"] || "column"
    gap = Map.get(layout, "gap", 8)
    line = layout["lineGap"] || if(is_number(gap), do: gap, else: 0)
    {v, h} = align(layout["align"])
    padding = padding(layout["padding"] || 8)
    grid? = flow in ["grid", "stack"]
    start = if grid?, do: &grid_pos/1, else: &flex_pos/1
    # Spreading takes the flow's own axis; a grid's is its columns.
    main = if flow == "column", do: v, else: h
    justify = if is_binary(gap), do: "space-#{gap}", else: start.(main)

    [
      if(grid?,
        do: "display: grid",
        else: "display: flex; flex-direction: #{flow}"
      ),
      layout["wrap"] && grid? == false && "flex-wrap: wrap",
      flow == "grid" && tracks("columns", layout["columns"]),
      flow == "grid" && tracks("rows", layout["rows"]),
      "justify-content: #{justify}",
      "align-items: #{start.(if flow == "column", do: h, else: v)}",
      grid? && "justify-items: #{start.(h)}; align-content: #{start.(v)}",
      gaps(flow, gap, line, layout["wrap"]),
      # A negative gap overlaps the items: each pulls back over the one
      # before it (`item/2`), and the first is pushed back into place.
      "padding: #{padding.(flow, gap)}",
      layout["clip"] && "overflow: hidden"
    ]
    |> join()
  end

  @doc "The CSS declarations of a node, from its place and the layout of the box it is in."
  def item(place, parent) do
    flow = parent["layout"] || "column"
    main = %{"row" => "width", "column" => "height"}[flow]
    absolute? = place["absolute"] == true
    gap = parent["gap"]

    [
      for(axis <- ~w(width height), do: size(axis, place[axis], main)),
      for(
        {key, css} <- [
          {"minWidth", "min-width"},
          {"maxWidth", "max-width"},
          {"minHeight", "min-height"},
          {"maxHeight", "max-height"}
        ],
        is_number(place[key]),
        do: "#{css}: #{px(place[key])}"
      ),
      # Out of the flow, an absolute node is placed in its container, not a cell.
      !absolute? && track("column", place["column"], place["columnSpan"]),
      !absolute? && track("row", place["row"], place["rowSpan"]),
      flow == "stack" && !absolute? && "grid-area: 1 / 1",
      (is_number(gap) and gap < 0 and main != nil and !absolute?) &&
        "margin-#{if main == "width", do: "left", else: "top"}: #{px(gap)}",
      absolute? && absolute(place)
    ]
    |> join()
  end

  defp size(axis, n, main) when is_number(n),
    do: ["#{axis}: #{px(n)}", axis == main && "flex-shrink: 0"]

  defp size("width", "fill", "width"), do: "flex: 1 1 0; min-width: 0"
  # An auto basis, so a fill inside a column that hugs hugs.
  defp size("height", "fill", "height"), do: "flex: 1 1 auto"

  # In a grid's cell.
  defp size("width", "fill", nil), do: "justify-self: stretch"

  defp size(_axis, "fill", _main), do: "align-self: stretch"
  defp size(axis, _hug, axis), do: "flex-shrink: 0"
  defp size(_axis, _hug, _main), do: nil

  defp absolute(place) do
    x = place["centerX"]
    y = place["centerY"]

    edges =
      for edge <- ~w(left right top bottom),
          is_number(place[edge]),
          do: "#{edge}: #{px(place[edge])}"

    [
      "position: absolute",
      edges,
      # An axis with no offset is at 0 from the left, or the top.
      !Enum.any?([x | Enum.map(~w(left right), &place[&1])], &is_number/1) && "left: 0",
      !Enum.any?([y | Enum.map(~w(top bottom), &place[&1])], &is_number/1) && "top: 0",
      # Between two edges, a size the drawing gives its part yields to them.
      both?(place, "left", "right", "width") && "width: auto",
      both?(place, "top", "bottom", "height") && "height: auto",
      is_number(x) && "left: 50%",
      is_number(y) && "top: 50%",
      (is_number(x) or is_number(y)) && "translate: #{center(x)} #{center(y)}"
    ]
  end

  defp both?(place, a, b, size),
    do: is_number(place[a]) and is_number(place[b]) and !is_number(place[size])

  defp center(nil), do: "0"
  defp center(n), do: "calc(-50% + #{px(n)})"

  # Along the flow, then across it; a spread or negative gap is no gap.
  defp gaps("stack", _gap, _line, _wrap), do: nil

  defp gaps(flow, gap, line, wrap) do
    {along, across} =
      if flow == "column", do: {"row-gap", "column-gap"}, else: {"column-gap", "row-gap"}

    [
      (is_number(gap) and gap >= 0) && "#{along}: #{px(gap)}",
      ((flow == "grid" or wrap == true) and line >= 0) && "#{across}: #{px(line)}"
    ]
  end

  defp tracks(_axis, nil), do: nil

  defp tracks(axis, n) when is_number(n),
    do: "grid-template-#{axis}: repeat(#{trunc(n)}, minmax(0, 1fr))"

  defp tracks(axis, list) when is_list(list),
    do: "grid-template-#{axis}: " <> Enum.map_join(list, " ", &track_size/1)

  defp track_size("fill"), do: "minmax(0, 1fr)"
  defp track_size("hug"), do: "max-content"
  defp track_size(n), do: px(n)

  defp track(_axis, nil, nil), do: nil
  defp track(axis, start, span), do: "grid-#{axis}: #{start || "auto"} / span #{span || 1}"

  # The padding as [top, right, bottom, left] pixels, with a negative gap's
  # pull-back added before the first item.
  defp padding(n) when is_number(n), do: padding([n, n, n, n])
  defp padding([v, h]), do: padding([v, h, v, h])

  defp padding([t, r, b, l]) do
    fn
      "row", gap when is_number(gap) and gap < 0 -> sides([t, r, b, l - gap])
      "column", gap when is_number(gap) and gap < 0 -> sides([t - gap, r, b, l])
      _, _ -> sides([t, r, b, l])
    end
  end

  defp sides([n, n, n, n]), do: px(n)
  defp sides([v, h, v, h]), do: "#{px(v)} #{px(h)}"
  defp sides(list), do: Enum.map_join(list, " ", &px/1)

  # `align`'s nine positions as {vertical, horizontal}.
  defp align(nil), do: align("top-left")

  defp align(position) do
    case String.split(position, "-") do
      [v, h] -> {v, h}
      ["center"] -> {"center", "center"}
      [side] when side in ["top", "bottom"] -> {side, "center"}
      [side] -> {"center", side}
    end
  end

  defp flex_pos(side) when side in ["top", "left"], do: "flex-start"
  defp flex_pos(side) when side in ["bottom", "right"], do: "flex-end"
  defp flex_pos("center"), do: "center"

  defp grid_pos(side) when side in ["top", "left"], do: "start"
  defp grid_pos(side) when side in ["bottom", "right"], do: "end"
  defp grid_pos("center"), do: "center"

  defp px(n) when is_integer(n), do: "#{n}px"
  defp px(n), do: "#{:erlang.float_to_binary(n / 1, [:short])}px"

  defp join(decls), do: decls |> List.flatten() |> Enum.filter(&is_binary/1) |> Enum.join("; ")
end
