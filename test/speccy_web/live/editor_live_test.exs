defmodule SpeccyWeb.EditorLiveTest do
  # The icon cache is a global setting.
  use SpeccyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Speccy.Icons.Cache
  alias Speccy.Workspace

  @moduletag :tmp_dir
  @wait 2000
  @add ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="M440-440H200v-80h240v-240h80v240h240v80H520v240h-80v-240Z"/></svg>)

  # The page as LazyHTML gives it back closes the SVG's tags its own way.
  @viewbox ~s(viewBox="0 -960 960 960")

  setup %{tmp_dir: tmp} = context do
    Application.put_env(:speccy, :icon_cache, Path.join(tmp, "icons"))
    on_exit(fn -> Application.delete_env(:speccy, :icon_cache) end)

    # The page fetches no icon unless a test asks it to: one it starts
    # would outlive a test that ends first, and its stub.
    unless context[:fetch] do
      Req.Test.stub(Cache, &Req.Test.text(&1, @add))
      for ref <- ~w(material/add material/delete), do: :ok = Cache.fetch(ref)
    end

    dir = Path.join(tmp, "tasks")
    File.cp_r!("test/fixtures/specs/tasks", dir)
    Phoenix.PubSub.subscribe(Speccy.PubSub, Workspace.topic(dir))
    {:ok, pid} = Workspace.open(dir)
    on_exit(fn -> DynamicSupervisor.terminate_child(Speccy.Workspace.Supervisor, pid) end)
    %{dir: dir, pid: pid}
  end

  # Once a test has seen the broadcast, a call to the workspace returns after
  # it was sent to the page too, so the page has it before the next render.
  defp changed(dir) do
    assert_receive {:spec_changed, _, _, _}, @wait
    Workspace.get(dir)
  end

  defp edit(dir, file, from, to) do
    path = Path.join(dir, file)
    File.write!(path, String.replace(File.read!(path), from, to))
  end

  test "with no spec, the page says how to open one", %{conn: conn, tmp_dir: tmp} do
    {:ok, _view, html} = live(conn, ~p"/?spec=#{Path.join(tmp, "nowhere")}")
    assert html =~ "No spec at or above"
    assert html =~ "SPECCY_OPEN"
  end

  test "the list holds the screens, components and data models, by kind, in name order",
       %{conn: conn, dir: dir} do
    {:ok, view, _} = live(conn, ~p"/?spec=#{dir}")

    assert view |> element("#items-screen") |> render() =~ "TaskScreen"

    assert view |> element("#items-component") |> render() =~
             ~r/Banner.*EmptyState.*Header.*TaskList.*TaskRow/s

    assert view |> element("#items-data") |> render() =~ "Task"
    refute has_element?(view, "#items-data a")
  end

  test "a screen's base and its states draw side by side, in the file's order, at its size",
       %{conn: conn, dir: dir} do
    {:ok, view, _} = live(conn, ~p"/?spec=#{dir}")
    html = view |> element("#world") |> render()

    assert html =~
             ~r/<figure(?![^>]*data-state).*The user&#39;s tasks.*data-state="loading".*data-state="empty".*data-state="problem"/s

    assert html =~ "The tasks are loading."
    assert length(Regex.scan(~r/class="wf wf-sized"/, html)) == 4
    assert html =~ "width: 402px; height: 874px"
    assert has_element?(view, "#world .wf[inert]")
    refute has_element?(view, "#world .wf:not([inert])")
    assert html =~ ~s(data-chain="header/title")
    assert html =~ ~s(data-file="screens/TaskScreen.json")
  end

  test "picking a component shows it, and the address keeps it", %{conn: conn, dir: dir} do
    {:ok, view, _} = live(conn, ~p"/?spec=#{dir}")

    view |> element("#items-component a", "Header") |> render_click()
    assert_patch(view, ~p"/?#{[item: "components/Header.json", spec: dir]}")
    assert has_element?(view, "#world figure[data-state=blank]")
    refute view |> element("#world") |> render() =~ "wf-sized"

    {:ok, view, _} = live(conn, ~p"/?#{[item: "components/Header.json", spec: dir]}")
    assert has_element?(view, "#world figure[data-state=blank]")
  end

  test "a frame's switcher draws one of its variations, or the frame as written",
       %{conn: conn, dir: dir} do
    {:ok, view, _} = live(conn, ~p"/?spec=#{dir}")
    problem = "figure[data-state=problem]"
    refute view |> element(problem) |> render() =~ "You&#39;re offline"

    view |> element("#{problem} button", "offline") |> render_click()
    assert view |> element(problem) |> render() =~ "You&#39;re offline"

    view |> element("#{problem} button", "as written") |> render_click()
    refute view |> element(problem) |> render() =~ "You&#39;re offline"
  end

  test "an outside edit redraws the frames", %{conn: conn, dir: dir} do
    {:ok, view, _} = live(conn, ~p"/?spec=#{dir}")
    edit(dir, "screens/TaskScreen.json", ~s("title": "Tasks"), ~s("title": "Chores"))
    changed(dir)
    assert view |> element("#world") |> render() =~ ">Chores<"
  end

  test "the problems follow the check, and a broken file's frames are flagged",
       %{conn: conn, dir: dir} do
    {:ok, view, _} = live(conn, ~p"/?spec=#{dir}")
    assert view |> element("#problems") |> render() =~ "No problems."

    edit(dir, "components/Header.json", ~s("layout": "row"), ~s("layout": 3))
    changed(dir)

    problems = view |> element("#problems") |> render()
    assert problems =~ "components/Header.json/layout"
    assert problems =~ ~r/badge-error[^>]*>\s*[a-z-]+\s*</

    # Every frame draws the header, from its last good version.
    assert length(Regex.scan(~r/components\/Header.json: last good version/, render(view))) ==
             4
  end

  @tag :fetch
  test "an icon not in the cache draws as its placeholder, then redraws when it arrives",
       %{conn: conn, dir: dir} do
    # `add` arrives; `delete` never does.
    Req.Test.stub(Cache, fn conn ->
      if conn.request_path =~ "/add/",
        do: Req.Test.text(conn, @add),
        else: Plug.Conn.send_resp(conn, 404, "")
    end)

    {:ok, view, html} = live(conn, ~p"/?spec=#{dir}")
    assert html =~ ~s(title="material/add")
    refute html =~ @viewbox

    html = render_async(view)
    assert html =~ @viewbox
    assert html =~ ~s(title="material/delete")
  end

  test "a workspace that dies is opened again", %{conn: conn, dir: dir, pid: pid} do
    {:ok, view, _} = live(conn, ~p"/?spec=#{dir}")
    ref = Process.monitor(pid)
    # :shutdown, so its watcher stops without logging.
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}
    # The page had the :DOWN before this render, and opened it again.
    render(view)
    new = GenServer.whereis({:via, Registry, {Speccy.Workspace.Registry, dir}})
    assert new && new != pid
    on_exit(fn -> DynamicSupervisor.terminate_child(Speccy.Workspace.Supervisor, new) end)

    edit(dir, "screens/TaskScreen.json", ~s("title": "Tasks"), ~s("title": "Chores"))
    changed(dir)
    assert view |> element("#world") |> render() =~ ">Chores<"
  end
end
