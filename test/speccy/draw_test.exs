defmodule Speccy.DrawTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Speccy.{Draw, Format, Primitives, Resolve, Spec}

  @specs "test/fixtures/specs"

  defp spec(name), do: Spec.new(Format.load(Path.join(@specs, name)))

  defp draw(tree, icons \\ %{}),
    do: render_component(&Draw.frame/1, tree: tree, icons: icons, size: nil)

  defp nodes(node), do: [node | Enum.flat_map(node.children, &nodes/1)]

  defp chain(node),
    do: node.origin |> Enum.map(& &1.id) |> Enum.reject(&is_nil/1) |> Enum.join("/")

  # One primitive alone in a frame, with props as drawn.
  defp alone(i, props) do
    node = %{
      kind: :primitive,
      use: i.name,
      id: "it",
      origin: [%{file: "screens/S.json", at: ["children", 0], id: "it"}],
      row: nil,
      props: props,
      bound: [],
      unknown: [],
      state: nil,
      place: %{},
      layout: %{},
      children: []
    }

    %{
      node
      | kind: :root,
        id: nil,
        use: "S",
        origin: [%{hd(node.origin) | id: nil, at: []}],
        children: [node]
    }
  end

  test "every primitive draws each of its examples and each of its states" do
    for module <- Primitives.all(), i = module.interface() do
      props = for {_, p} <- i.examples, do: Map.merge(i.defaults, p)
      states = for {_, s} <- i.states, do: Map.merge(i.defaults, s.props)

      for p <- [i.defaults | props ++ states] do
        html = draw(alone(i, p))

        assert [_] =
                 LazyHTML.from_fragment(html)
                 |> LazyHTML.query(~s([data-chain="it"]))
                 |> Enum.to_list(),
               i.name
      end
    end
  end

  test "a frame of the tasks fixture draws every node with its data-chain" do
    spec = spec("tasks")

    path = "screens/TaskScreen.json"

    for {state, _} <- Spec.frames(spec, path) do
      tree = Resolve.frame(spec, path, state)
      html = LazyHTML.from_fragment(draw(tree))

      for node <- nodes(tree) do
        found = LazyHTML.query(html, ~s([data-chain="#{chain(node)}"][data-file="#{path}"]))
        assert Enum.count(found) >= 1, "#{state} #{chain(node)}"
      end

      assert [root] = html |> LazyHTML.query(".wf") |> Enum.to_list()
      assert LazyHTML.attribute(root, "inert") == [""]
    end
  end

  test "every frame of every item of the clean fixtures draws" do
    for name <- ~w(tasks uploads),
        spec = spec(name),
        {_, kind, path} <- spec.items,
        kind != :data,
        {state, variations} <- Spec.frames(spec, path),
        variation <- [nil | variations] do
      assert draw(Resolve.frame(spec, path, state, variation)) =~ ~s(class="wf)
    end
  end

  test "a prop holding the wrong kind of value draws, never raises" do
    container = Primitives.get("container").interface()

    for role <- [%{"a" => 1}, ["tab"], 3] do
      assert draw(alone(container, %{"role" => role})) =~ ~s(data-chain="it")
    end
  end

  test "a frame that can't be resolved draws its code" do
    tree = Resolve.frame(spec("broken-schema"), "components/Bad.json")
    assert %{kind: :error, code: code} = tree

    [box] =
      LazyHTML.from_fragment(draw(tree)) |> LazyHTML.query(".wf > .wf-error") |> Enum.to_list()

    assert LazyHTML.text(box) =~ Atom.to_string(code)
  end

  test "an href is a path or a web address only" do
    assert Draw.href("/docs") == "/docs"
    assert Draw.href("https://example.com") == "https://example.com"
    assert Draw.href("//evil.example") == nil
    assert Draw.href("javascript:alert(1)") == nil
  end

  test "an error node draws its code" do
    spec = spec("broken-refs")
    tree = Resolve.frame(spec, "screens/Board.json")
    error = Enum.find(nodes(tree), &(&1.kind == :error))

    [box] =
      LazyHTML.from_fragment(draw(tree))
      |> LazyHTML.query(~s(.wf-error[data-chain="#{chain(error)}"]))
      |> Enum.to_list()

    assert LazyHTML.text(box) =~ Atom.to_string(error.code)
  end

  test "an icon not in `icons` draws its placeholder; one in it, its SVG" do
    spec = spec("tasks")
    svg = spec.svgs["assets/icons/app/alert.svg"]
    header = Resolve.frame(spec, "components/Header.json")
    banner = Resolve.frame(spec, "components/Banner.json")

    assert [placeholder] =
             LazyHTML.from_fragment(draw(header))
             |> LazyHTML.query(".wf-missing")
             |> Enum.to_list()

    assert LazyHTML.text(placeholder) =~ "add"
    assert LazyHTML.attribute(placeholder, "title") == ["material/add"]

    html = draw(banner, %{"app/alert" => svg})
    assert html =~ svg
    refute html =~ "wf-missing"
  end

  test "wireframe.css styles nothing outside .wf" do
    selectors =
      Draw.css()
      |> String.replace(~r{/\*.*?\*/}s, "")
      |> String.replace(~r/\{[^}]*\}/, "\n")
      # Commas inside :where(…) and :not(…) don't split selectors.
      |> then(&Regex.replace(~r/\([^()]*\)/, &1, "()"))
      |> then(&Regex.replace(~r/\([^()]*\)/, &1, "()"))
      |> String.split([",", "\n"], trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    assert length(selectors) > 50
    for selector <- selectors, do: assert(selector =~ ~r/^\.wf([ .:]|$)/, selector)
  end
end
