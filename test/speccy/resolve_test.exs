defmodule Speccy.ResolveTest do
  use ExUnit.Case, async: true

  alias Speccy.{Format, Resolve, Spec}

  @specs "test/fixtures/specs"

  defp spec(name), do: Spec.new(Format.load(Path.join(@specs, name)))
  defp nodes(node), do: [node | Enum.flat_map(node.children, &nodes/1)]
  defp all(tree, id), do: Enum.filter(nodes(tree), &(&1.id == id))
  defp one(tree, id), do: hd(all(tree, id))
  defp ats(node), do: Enum.map(node.origin, & &1.at)

  test "a base frame, nesting three components deep" do
    tree = Resolve.frame(spec("tasks"), "screens/TaskScreen.json")

    assert %{kind: :root, use: "TaskScreen", state: nil, layout: %{"layout" => "column"}} = tree

    assert [%{kind: :component, use: "Header"}, %{kind: :component, use: "TaskList"}] =
             tree.children

    assert one(tree, "title").props["text"] == "Tasks"

    # Two rows, one per sample; each checkbox is TaskScreen's list, TaskList's row, TaskRow's own.
    assert [first, second] = all(tree, "done")
    assert {first.props["label"], second.props["checked"]} == {"Buy milk", true}
    assert first.bound |> Enum.sort() == ["checked", "label"]

    assert first.origin == [
             %{file: "screens/TaskScreen.json", at: ["children", 1], id: "list"},
             %{file: "components/TaskList.json", at: ["children", 0, "children", 0], id: "row"},
             %{file: "components/TaskRow.json", at: ["children", 0], id: "done"}
           ]

    assert Enum.map(all(tree, "row"), & &1.row) == [0, 1]
  end

  test "a state: a copy, an `inner` entry and an instance of its own" do
    tree = Resolve.frame(spec("uploads"), "screens/Uploads.json", "empty")

    assert %{kind: :component, state: "collapsed", props: %{"title" => "No uploads"}} =
             card = one(tree, "card")

    assert ats(card) == [["states", "empty", "children", 0]]
    assert card.place["height"] == 400
    assert ats(one(tree, "nothing")) == [["states", "empty", "children", 2]]

    hover = Resolve.frame(spec("broken-composition"), "screens/Home.json", "hover")
    assert %{props: %{"pressable" => true}} = tile = one(hover, "tile")
    assert ats(tile) == [["states", "hover", "children", 0]]
    assert %{props: %{"role" => "tab", "controls" => "nowhere"}} = face = one(hover, "face")
    assert ats(face) == [["states", "hover", "children", 0, "inner", "face"]]
    # A part `inner` doesn't name is written in the base.
    assert ats(one(hover, "go")) == [["children", 10, "children", 1]]
  end

  test "a component instance takes its component's size unless it sets its own" do
    tree = Resolve.frame(spec("uploads"), "screens/Uploads.json")

    # UploadItem is 320 wide and hugs; `pick` sets neither.
    assert one(tree, "pick").place == %{"width" => 320, "height" => "hug"}
    assert hd(all(tree, "item")).place["width"] == "fill"
  end

  test "a copy's offsets replace the base's as a set" do
    tree = Resolve.frame(spec("uploads"), "screens/Uploads.json", "empty")

    assert Map.take(one(tree, "badge").place, ~w(left right top bottom centerX centerY)) ==
             %{"left" => 16, "right" => 16, "bottom" => 16}
  end

  test "a state's data replaces a sample" do
    spec = spec("uploads")
    assert one(Resolve.frame(spec, "screens/Dial.json"), "count").props["value"] == 3
    assert one(Resolve.frame(spec, "screens/Dial.json", "last"), "count").props["value"] == 1
  end

  test "a repeat over a sample, with `limit`, and a bound state per row" do
    tree = Resolve.frame(spec("uploads"), "screens/Uploads.json")

    assert [%{row: 0, state: "uploading"} = up, %{row: 1, state: "done"}] = all(tree, "item")
    assert Enum.map(up.children, & &1.id) == ["name", "bar", "remove"]
    # Its bound variation is one of UploadItem's base's.
    assert one(up, "remove").props["label"] == "Drop"
    assert one(up, "name").props["text"] == "brief.pdf"

    # Two samples, at most one row.
    assert [%{row: 0}] = all(tree, "pick")
  end

  test "a component alone: placeholders, and three rows over an unknown list" do
    tree = Resolve.frame(spec("tasks"), "components/TaskList.json")

    assert [_, _, _] = rows = all(tree, "row")
    assert %{unknown: ["task"]} = hd(rows)
    assert %{props: %{"label" => "{task.title}"}} = done = one(tree, "done")
    assert Enum.sort(done.unknown) == ["checked", "label"]
  end

  test "a frame's variation wins over a component variation on the same prop" do
    spec = spec("uploads")
    title = &one(Resolve.frame(spec, "screens/Uploads.json", "empty", &1), "title")

    assert title.(nil).props["text"] == "All quiet"
    assert title.("returning").props["text"] == "Welcome back"
  end

  test "a slot holds its instance's fills, written in the instance's file" do
    tree = Resolve.frame(spec("uploads"), "screens/Uploads.json")

    assert [%{id: "list"} = list] = one(tree, "body").children

    assert list.origin == [
             %{file: "screens/Uploads.json", at: ["children", 0, "slots", "body", 0], id: "list"}
           ]
  end

  test "every frame of every fixture resolves, and what can't is an error node" do
    for dir <- Path.wildcard(Path.join(@specs, "*")) do
      spec = Spec.new(Format.load(dir))

      for {path, _} <- spec.read,
          {state, variations} <- Spec.frames(spec, path),
          variation <- [nil | variations],
          do: assert(%{} = Resolve.frame(spec, path, state, variation))
    end

    board = Resolve.frame(spec("broken-refs"), "screens/Board.json")
    assert %{kind: :error, code: :"unknown-use"} = one(board, "ghost")
    assert %{kind: :error, code: :"bind-unresolved"} = one(board, "lost")

    broken = Resolve.frame(spec("broken-refs"), "screens/Board.json", "broken")
    assert [%{kind: :error, code: :"unknown-copy"} | _] = broken.children

    ping = Resolve.frame(spec("broken-layout"), "components/Ping.json")
    assert [%{code: :"component-cycle"}] = for(%{kind: :error} = n <- nodes(ping), do: n)

    assert %{kind: :error, code: :"wrong-schema"} =
             Resolve.frame(spec("broken-schema"), "components/Bad.json")
  end
end
