defmodule SpeccyWeb.DevController do
  @moduledoc """
  Pages for judging the wireframes by eye, in development only: every
  primitive drawn in each of its examples and states, and every frame of
  one item of a fixture spec.
  """
  use SpeccyWeb, :controller

  alias Speccy.{Format, Icons, Primitives, Resolve, Spec}
  alias Speccy.Icons.Cache

  @fixtures "test/fixtures/specs"

  def primitives(conn, _params) do
    categories =
      Primitives.all()
      |> Enum.map(& &1.interface())
      |> Enum.chunk_by(& &1.category)
      |> Enum.map(fn [i | _] = interfaces ->
        {i.category, Enum.map(interfaces, &{&1.name, cells(&1)})}
      end)

    render(conn, :primitives, categories: categories, page_title: "Primitives")
  end

  # Each example, then each state on the first example.
  defp cells(i) do
    examples = if i.examples == [], do: [{"default", %{}}], else: i.examples
    base = Map.merge(i.defaults, elem(hd(examples), 1))
    # An overlay is drawn over a screen-sized frame, the way it shows.
    size = if i.category == "overlays", do: {420, 280}

    Enum.map(examples, fn {name, props} -> {name, tree(i, Map.merge(i.defaults, props)), size} end) ++
      Enum.map(i.states, fn {name, s} ->
        {"state: #{name}", tree(i, Map.merge(base, s.props)), size}
      end)
  end

  defp tree(i, props) do
    # Something to hold, for what holds children.
    children =
      if i.children,
        do: for(n <- 1..2, do: node("text", %{"text" => "Child #{n}"}, [])),
        else: []

    %{node(nil, %{}, [node(i.name, props, children)]) | kind: :root, layout: %{"padding" => 16}}
  end

  defp node(use, props, children) do
    %{
      kind: :primitive,
      use: use,
      id: use,
      origin: [%{file: "gallery", at: [], id: use}],
      row: nil,
      props: props,
      bound: [],
      unknown: [],
      state: nil,
      place: %{},
      layout: %{},
      children: children
    }
  end

  def frame(conn, params) do
    dir = Path.join(@fixtures, Path.basename(params["spec"] || "tasks"))
    spec = Spec.new(Format.load(dir))
    path = params["file"] || Enum.find_value(Enum.sort(spec.items), &item_path/1)

    frames =
      for {state, _variations} <- Spec.frames(spec, path),
          do: {state || "base", Resolve.frame(spec, path, state)}

    render(conn, :frame,
      path: path,
      items: for({_, kind, p} <- Enum.sort(spec.items), kind != :data, do: p),
      spec_name: Path.basename(dir),
      frames: frames,
      size: Spec.size(spec, path),
      # Library icons draw only once cached; the editor page fetches them.
      icons: Cache.svgs(Enum.flat_map(frames, &Icons.refs(elem(&1, 1))), spec),
      page_title: path
    )
  end

  defp item_path({_, :screen, path}), do: path
  defp item_path(_), do: nil
end
