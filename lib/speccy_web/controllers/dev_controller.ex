defmodule SpeccyWeb.DevController do
  @moduledoc """
  Pages for judging the wireframes by eye, in development only: every
  primitive drawn in each of its examples and states, and every frame of
  one item of a fixture spec.
  """
  use SpeccyWeb, :controller

  alias Speccy.{Format, Icons, Primitives, Resolve, Spec}

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
    json = spec.valid[path] || %{}

    frames =
      for {state, _variations} <- Spec.frames(spec, path),
          do: {state || "base", Resolve.frame(spec, path, state)}

    render(conn, :frame,
      path: path,
      items: for({_, kind, p} <- Enum.sort(spec.items), kind != :data, do: p),
      spec_name: Path.basename(dir),
      frames: frames,
      size: size(spec, json),
      icons: for({p, svg} <- spec.svgs, Icons.safe(svg) == :ok, into: %{}, do: {ref(p), svg}),
      page_title: path
    )
  end

  defp item_path({_, :screen, path}), do: path
  defp item_path(_), do: nil

  # A screen's device size, turned for landscape; nil for a component.
  defp size(spec, %{"device" => device} = json) when is_map(spec.devices) do
    case spec.devices[device] do
      %{"width" => w, "height" => h} = d ->
        turned =
          json["orientation"] == "landscape" and
            hd(d["orientations"] || ["portrait"]) == "portrait"

        if turned, do: {h, w}, else: {w, h}

      _ ->
        nil
    end
  end

  defp size(_spec, _json), do: nil

  # A spec icon's reference: `assets/icons/app/alert.svg` is `app/alert`.
  # (Library icons arrive with part 003; until then they draw their placeholder.)
  defp ref(path), do: "#{Path.basename(Path.dirname(path))}/#{Path.basename(path, ".svg")}"
end
