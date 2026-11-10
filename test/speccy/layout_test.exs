defmodule Speccy.LayoutTest do
  use ExUnit.Case, async: true

  alias Speccy.{Format, Layout, Spec}

  @specs "test/fixtures/specs"
  @tasks Spec.new(Format.load(Path.join(@specs, "tasks"))).valid
  @uploads Spec.new(Format.load(Path.join(@specs, "uploads"))).valid

  defp uploads, do: @uploads["screens/Uploads.json"]

  defp child(json, path),
    do: get_in(json, Enum.map(path, &if(is_integer(&1), do: Access.at(&1), else: &1)))

  describe "box" do
    test "a grid: its tracks, alignment, gaps and padding" do
      assert Layout.box(uploads()) ==
               "display: grid; grid-template-columns: minmax(0, 1fr) 240px; " <>
                 "grid-template-rows: repeat(2, minmax(0, 1fr)); justify-content: center; " <>
                 "align-items: start; justify-items: center; align-content: start; " <>
                 "column-gap: 16px; row-gap: 8px; padding: 16px"

      assert Layout.box(child(uploads(), ["children", 3])) =~
               "grid-template-columns: repeat(1, minmax(0, 1fr)); grid-template-rows: max-content"
    end

    test "a wrapping row that spreads its items: no gap along it, its lineGap across" do
      assert Layout.box(child(uploads(), ["children", 2])) ==
               "display: flex; flex-direction: row; flex-wrap: wrap; " <>
                 "justify-content: space-between; align-items: center; row-gap: 4px; padding: 8px"
    end

    test "a clipping row, its padding two values" do
      assert Layout.box(@uploads["components/UploadItem.json"]) ==
               "display: flex; flex-direction: row; justify-content: flex-start; " <>
                 "align-items: center; column-gap: 8px; padding: 4px 8px; overflow: hidden"

      assert Layout.box(@uploads["screens/Dial.json"]) =~
               "flex-wrap: wrap; justify-content: center; align-items: center; " <>
                 "column-gap: 8px; row-gap: 4px; padding: 8px; overflow: hidden"
    end

    test "a column takes format.md's defaults" do
      assert Layout.box(@tasks["screens/TaskScreen.json"]) ==
               "display: flex; flex-direction: column; justify-content: flex-start; " <>
                 "align-items: flex-start; row-gap: 8px; padding: 8px"
    end

    # The fixtures hold no stack, no negative gap and no `evenly`.
    test "a stack layers its children, aligned" do
      assert Layout.box(%{"layout" => "stack", "align" => "bottom-right"}) ==
               "display: grid; justify-content: end; align-items: end; " <>
                 "justify-items: end; align-content: end; padding: 8px"
    end

    test "a negative gap overlaps the items, the first pushed back into place" do
      box = %{"layout" => "row", "gap" => -8}
      assert Layout.box(box) =~ "padding: 8px 8px 8px 16px"
      refute Layout.box(box) =~ "gap"
      assert Layout.item(%{}, box) == "flex-shrink: 0; margin-left: -8px"
    end

    test "a track count JSON writes as a decimal" do
      assert Layout.box(%{"layout" => "grid", "columns" => 2.0}) =~
               "grid-template-columns: repeat(2, minmax(0, 1fr))"
    end

    test "a spread gap, and a wrapping column's lineGap" do
      assert Layout.box(%{"gap" => "evenly"}) =~ "justify-content: space-evenly"

      assert Layout.box(%{"wrap" => true, "gap" => 4, "lineGap" => 12}) =~
               "flex-wrap: wrap; justify-content: flex-start; align-items: flex-start; " <>
                 "row-gap: 4px; column-gap: 12px"
    end
  end

  describe "item" do
    @column %{"layout" => "column"}
    @row %{"layout" => "row"}

    test "fill across a column stretches; a hugging height doesn't shrink" do
      header = child(@tasks["screens/TaskScreen.json"], ["children", 0])
      assert Layout.item(header, @column) == "align-self: stretch; flex-shrink: 0"
    end

    test "fill along a column grows with an auto basis" do
      list = child(@tasks["screens/TaskScreen.json"], ["children", 1])
      assert Layout.item(list, @column) == "align-self: stretch; flex: 1 1 auto"
    end

    test "fill along a row grows from zero" do
      name = child(@uploads["components/UploadItem.json"], ["children", 0])
      assert Layout.item(name, @row) == "flex: 1 1 0; min-width: 0"
    end

    test "a fixed size, and the minimums and maximums" do
      assert Layout.item(%{"width" => 120}, @row) == "width: 120px; flex-shrink: 0"

      item = child(uploads(), ["children", 0, "slots", "body", 0, "children", 0])

      assert Layout.item(item, @column) ==
               "align-self: stretch; flex-shrink: 0; min-width: 200px; max-width: 600px; " <>
                 "min-height: 40px; max-height: 80px"
    end

    test "in a grid: placed and spanned, and fill stretches in its cell" do
      assert Layout.item(child(uploads(), ["children", 0]), uploads()) ==
               "grid-column: 1 / span 1; grid-row: 1 / span 2"

      copy = child(uploads(), ["states", "empty", "children", 0])

      assert Layout.item(copy, uploads()) ==
               "justify-self: stretch; height: 400px; min-width: 100px; max-width: 900px; " <>
                 "min-height: 100px; max-height: 800px; grid-column: 1 / span 2; " <>
                 "grid-row: 1 / span 1"
    end

    test "in a stack, every child in the one cell" do
      assert Layout.item(%{}, %{"layout" => "stack"}) == "grid-area: 1 / 1"
    end

    test "absolute: pinned to an edge, out of its grid cell" do
      assert Layout.item(child(uploads(), ["children", 1]), uploads()) ==
               "position: absolute; right: 8px; top: 8px"
    end

    test "absolute: stretched between two edges" do
      copy = child(uploads(), ["states", "empty", "children", 1])

      assert Layout.item(copy, uploads()) ==
               "position: absolute; left: 16px; right: 16px; bottom: 16px; width: auto"
    end

    test "absolute: centred on both axes" do
      nothing = child(uploads(), ["states", "empty", "children", 2])

      assert Layout.item(nothing, uploads()) ==
               "position: absolute; left: 50%; top: 50%; " <>
                 "translate: calc(-50% + 0px) calc(-50% + 0px)"
    end

    test "absolute with no offset: at the top-left" do
      assert Layout.item(%{"absolute" => true, "centerX" => -4}, @column) ==
               "flex-shrink: 0; position: absolute; top: 0; left: 50%; " <>
                 "translate: calc(-50% + -4px) 0"

      assert Layout.item(%{"absolute" => true}, @column) ==
               "flex-shrink: 0; position: absolute; left: 0; top: 0"
    end
  end
end
