defmodule Speccy.Icons.CacheTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Speccy.{Draw, Format, Icons, Resolve, Spec}
  alias Speccy.Icons.Cache

  @moduletag :tmp_dir

  # Material's SVG for `add`, as its pinned URL serves it: no fill, so the wireframe's colour.
  @add ~s(<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 -960 960 960" width="24"><path d="M440-440H200v-80h240v-240h80v240h240v80H520v240h-80v-240Z"/></svg>)
  @version Icons.library("material")["version"]

  defp spec(name), do: Spec.new(Format.load(Path.join("test/fixtures/specs", name)))

  defp cache(dir, file, svg) do
    path = Path.join([dir, "material", @version, file])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, svg)
  end

  test "a spec icon's SVG comes from the loaded spec", %{tmp_dir: dir} do
    spec = spec("tasks")
    assert Cache.svg("app/alert", spec, dir) == spec.svgs["assets/icons/app/alert.svg"]
  end

  test "a library icon's SVG comes from the cache, in its resolved style", %{tmp_dir: dir} do
    cache(dir, "add.outlined.svg", @add)

    assert Cache.svg("material/add", spec("tasks"), dir) == @add
    assert Cache.svg("material/add:outlined", spec("tasks"), dir) == @add
    assert Cache.svg("material/add:filled", spec("tasks"), dir) == :missing
  end

  test "what isn't there, or doesn't resolve, is missing", %{tmp_dir: dir} do
    spec = spec("tasks")

    for ref <- ["material/delete", "app/nope", "brand/logo", "material/nope", "nope", nil],
        do: assert(Cache.svg(ref, spec, dir) == :missing, inspect(ref))
  end

  test "an unsafe SVG is never handed back, from the spec or the cache", %{tmp_dir: dir} do
    spec = spec("broken-icons")
    assert Cache.svg("app/script", spec, dir) == :missing
    assert Cache.svg("app/malformed", spec, dir) == :missing
    # The spec's own `material` set never stands in for the library.
    assert Cache.svg("material/home", spec, dir) == :missing

    cache(
      dir,
      "add.outlined.svg",
      File.read!("test/fixtures/specs/broken-icons/assets/icons/app/script.svg")
    )

    assert Cache.svg("material/add", spec, dir) == :missing
  end

  test "fetch gets a library icon from its pinned version into the cache", %{tmp_dir: dir} do
    Req.Test.stub(Cache, fn conn ->
      assert conn.request_path ==
               "/google/material-design-icons/#{@version}/symbols/web/add/materialsymbolsoutlined/add_fill1_24px.svg"

      Req.Test.text(conn, @add)
    end)

    assert Cache.fetch("material/add:filled", dir) == :ok
    assert File.read!(Path.join([dir, "material", @version, "add.filled.svg"])) == @add
    assert Cache.svg("material/add:filled", spec("tasks"), dir) == @add
    assert File.ls!(Path.join([dir, "material", @version])) == ["add.filled.svg"]
  end

  test "fetch writes nothing it can't use, and fetches nothing cached", %{tmp_dir: dir} do
    Req.Test.stub(Cache, fn conn ->
      if conn.request_path =~ "/add/",
        do: Req.Test.text(conn, ~s(<svg xmlns="http://www.w3.org/2000/svg"><script/></svg>)),
        else: Plug.Conn.send_resp(conn, 404, "")
    end)

    assert {:error, {:"unsafe-svg", _}} = Cache.fetch("material/add", dir)
    assert Cache.fetch("material/delete", dir) == {:error, {:status, 404}}
    assert Cache.fetch("app/alert", dir) == {:error, :"unknown-icon-set"}
    refute File.exists?(Path.join(dir, "material"))

    Req.Test.stub(Cache, fn _ -> flunk("fetched a cached icon") end)
    cache(dir, "add.outlined.svg", @add)
    assert Cache.fetch("material/add", dir) == :ok
  end

  test "two fetches of one icon make one request", %{tmp_dir: dir} do
    test = self()

    Req.Test.stub(Cache, fn conn ->
      send(test, {:request, self()})
      receive do: (:go -> Req.Test.text(conn, @add))
    end)

    first = Task.async(fn -> Cache.fetch("material/add", dir) end)
    assert_receive {:request, fetching}, 2000
    second = Task.async(fn -> Cache.fetch("material/add", dir) end)
    send(fetching, :go)

    assert Task.await_many([first, second]) == [:ok, :ok]
    refute_received {:request, _}
  end

  test "a frame draws its spec icon and its cached library icon, and names the uncached one",
       %{tmp_dir: dir} do
    Req.Test.stub(Cache, fn _ -> flunk("reached for the network") end)
    spec = spec("tasks")
    tree = Resolve.frame(spec, "screens/TaskScreen.json", "problem")
    cache(dir, "add.outlined.svg", @add)

    icons =
      for ref <- Icons.refs(tree),
          svg = Cache.svg(ref, spec, dir),
          svg != :missing,
          into: %{},
          do: {ref, svg}

    html = render_component(&Draw.frame/1, tree: tree, icons: icons, size: nil)

    assert html =~ spec.svgs["assets/icons/app/alert.svg"]
    assert html =~ @add
    # The library's SVG sets no fill, so the wireframe gives it its colour.
    assert Draw.css() =~ ~r/\.wf \.wf-glyph > svg:not\(\[fill\]\) \{\s*fill: currentColor;/

    # One placeholder per task row, each named.
    missing = html |> LazyHTML.from_fragment() |> LazyHTML.query(".wf-missing")
    assert Enum.count(missing) == 2
    assert LazyHTML.attribute(missing, "title") == ["material/delete", "material/delete"]
    assert String.split(LazyHTML.text(missing)) == ["delete", "delete"]
  end
end
