defmodule SpeccyWeb.WindowTest do
  # The recent specs, the window's flag and SPECCY_OPEN are global settings.
  use SpeccyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias SpeccyWeb.{Menu, Recent, Window}

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    Application.put_env(:speccy, :recent, Path.join(tmp, "home/.speccy/recent.json"))
    on_exit(fn -> Application.delete_env(:speccy, :recent) end)
    :ok
  end

  # A spec folder of its own: what makes one is its speccy.json.
  defp spec(tmp, name) do
    dir = Path.join(tmp, name)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "speccy.json"), "{}")
    dir
  end

  describe "the recent specs" do
    test "an open goes to the front", %{tmp_dir: tmp} do
      [a, b] = for name <- ~w(a b), do: spec(tmp, name)
      Recent.add(a)
      Recent.add(b)
      assert Recent.list() == [b, a]
    end

    test "a folder opened again moves up and isn't doubled", %{tmp_dir: tmp} do
      [a, b, c] = for name <- ~w(a b c), do: spec(tmp, name)
      for dir <- [a, b, c, a], do: Recent.add(dir)
      assert Recent.list() == [a, c, b]
    end

    test "the eleventh drops the oldest", %{tmp_dir: tmp} do
      dirs = for i <- 1..11, do: spec(tmp, "s#{i}")
      for dir <- dirs, do: Recent.add(dir)
      assert Recent.list() == dirs |> Enum.reverse() |> Enum.take(10)
    end

    test "a folder with no spec is dropped when read", %{tmp_dir: tmp} do
      [a, b] = for name <- ~w(a b), do: spec(tmp, name)
      Recent.add(a)
      Recent.add(b)
      File.rm!(Path.join(a, "speccy.json"))
      assert Recent.list() == [b]
    end
  end

  describe "opening, without a host" do
    setup %{tmp_dir: tmp} do
      test = self()

      # The picker: tells the test which task it runs in, then answers.
      chooser = fn answer ->
        fn _opts ->
          send(test, {:picker, self()})
          answer
        end
      end

      Application.put_env(:speccy, :choose_directory, chooser.(spec(tmp, "picked")))
      on_exit(fn -> Application.delete_env(:speccy, :choose_directory) end)
      %{chooser: chooser}
    end

    # Waits for the picker's task to end, and with it the open.
    defp picked do
      assert_receive {:picker, task}, 1000
      ref = Process.monitor(task)
      assert_receive {:DOWN, ^ref, _, _, _}, 1000
    end

    test "records the spec at or above the folder; a folder with no spec isn't recorded",
         %{tmp_dir: tmp} do
      a = spec(tmp, "a")
      File.mkdir_p!(Path.join(a, "screens"))
      Window.open(Path.join(a, "screens"))
      Window.open(Path.join(tmp, "nowhere"))
      assert Recent.list() == [a]
    end

    test "File > Open… opens what is picked; Cancel opens nothing",
         %{tmp_dir: tmp, chooser: chooser} do
      Menu.handle_event("open", %Desktop.Menu{})
      picked()
      assert Recent.list() == [Path.join(tmp, "picked")]

      Application.put_env(:speccy, :choose_directory, chooser.(nil))
      Recent.add(spec(tmp, "a"))
      Menu.handle_event("open", %Desktop.Menu{})
      picked()
      assert Recent.list() == [Path.join(tmp, "a"), Path.join(tmp, "picked")]
    end

    test "File > Open Recent opens the one picked", %{tmp_dir: tmp} do
      [a, b] = for name <- ~w(a b), do: spec(tmp, name)
      Recent.add(a)
      Recent.add(b)
      {:ok, menu} = Menu.mount(%Desktop.Menu{assigns: %{}})
      assert menu.assigns.recent == [b, a]

      Menu.handle_event("recent 1", menu)
      assert Recent.list() == [a, b]
    end

    test "SPECCY_OPEN at launch is the window's first page", %{tmp_dir: tmp} do
      a = spec(tmp, "a")
      [{Desktop.Window, opts}, Window] = Window.children()
      assert opts[:url].() =~ ~r"/$"
      assert Recent.list() == []

      System.put_env("SPECCY_OPEN", a)
      on_exit(fn -> System.delete_env("SPECCY_OPEN") end)
      assert opts[:url].() =~ "/?" <> URI.encode_query(spec: a)
      assert Recent.list() == [a]
    end

    test "a speccy open reaching the running app", %{tmp_dir: tmp} do
      [a, b] = for name <- ~w(a b), do: spec(tmp, name)
      Recent.add(a)
      pid = start_supervised!(Window)

      Desktop.Env.notify_subscribers({:open_file, [b]})
      # Env's cast reaches the window before this call's reply.
      :sys.get_state(Desktop.Env)
      :sys.get_state(pid)
      assert Recent.list() == [b, a]
    end

    test "⌘O in the window's page runs File > Open…", %{conn: conn, tmp_dir: tmp} do
      Application.put_env(:speccy, :window, true)
      on_exit(fn -> Application.put_env(:speccy, :window, false) end)

      {:ok, view, html} = live(conn, "/?k=#{Desktop.Auth.login_key()}")
      assert html =~ ~s(id="shortcuts")
      # The page names the menu, not the ways in for a browser.
      assert html =~ "(⌘O)"
      refute html =~ "SPECCY_OPEN"
      render_hook(view, "open", %{})
      picked()
      assert Recent.list() == [Path.join(tmp, "picked")]
    end

    test "out of the window, the page leaves ⌘O to the browser", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      refute html =~ ~s(id="shortcuts")
    end
  end

  describe "keeping other pages out" do
    @describetag :capture_log

    setup do
      Application.put_env(:speccy, :window, true)
      on_exit(fn -> Application.put_env(:speccy, :window, false) end)
    end

    test "the window's key is needed once per session", %{conn: conn} do
      assert conn |> get("/") |> response(401)

      conn = get(conn, "/?k=#{Desktop.Auth.login_key()}")
      assert html_response(conn, 200) =~ "No spec open"
      assert conn |> recycle() |> get("/") |> html_response(200) =~ "No spec open"
    end

    test "a wrong key is refused", %{conn: conn} do
      assert conn |> get("/?k=WRONG") |> response(401)
    end

    test "LiveView's socket refuses a foreign origin", %{conn: conn} do
      socket = fn origin ->
        conn |> put_req_header("origin", origin) |> get("/live/websocket?vsn=2.0.0")
      end

      assert socket.("http://evil.example").status == 403
      assert socket.("http://localhost:4000").status != 403
    end

    test "a request for another host is refused", %{conn: conn} do
      assert %{conn | host: "evil.example"}
             |> get("/?k=#{Desktop.Auth.login_key()}")
             |> response(403)
    end
  end
end
