defmodule Speccy.CLIRenderTest do
  # `render` finds the spec from the working directory, which is the VM's own.
  use ExUnit.Case, async: false

  alias Speccy.{CLI, Draw}
  alias Speccy.Icons.Cache

  @moduletag :tmp_dir
  @tasks Path.expand("test/fixtures/specs/tasks")
  @add ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="M440-440H200v-80h240v-240h80v240h240v80H520v240h-80v-240Z"/></svg>)

  setup %{tmp_dir: dir} do
    Application.put_env(:speccy, :icon_cache, Path.join(dir, "icons"))
    on_exit(fn -> Application.delete_env(:speccy, :icon_cache) end)

    # `add` arrives; `delete` never does.
    Req.Test.stub(Cache, fn conn ->
      if conn.request_path =~ "/add/",
        do: Req.Test.text(conn, @add),
        else: Plug.Conn.send_resp(conn, 404, "")
    end)

    :ok
  end

  defp render(argv, dir \\ @tasks) do
    {output, status} = File.cd!(dir, fn -> CLI.run(["render" | argv]) end)
    {IO.iodata_to_binary(output), status}
  end

  defp page(name, argv, dir) do
    out = Path.join(dir, name)
    assert render(argv ++ ["--out", out]) == {out <> "\n", 0}
    File.read!(out)
  end

  test "render writes one page: the stylesheet, the frame at its device's size, its icons",
       %{tmp_dir: dir} do
    html = page("base.html", ["TaskScreen"], dir)

    assert html =~ ~r/^<!doctype html>.*<title>TaskScreen<\/title>/s
    assert html =~ Draw.css()
    assert html =~ ~s(class="wf wf-sized")
    assert html =~ "width: 402px; height: 874px"
    assert html =~ ~s(data-chain="header/title")
    assert html =~ ">Buy milk<"
    # Fetched before drawing, into the cache; what doesn't arrive is a named placeholder.
    assert html =~ @add
    assert File.exists?(Path.join(dir, "icons/material"))
    assert html =~ ~s(title="material/delete")
  end

  test "a landscape screen is drawn turned", %{tmp_dir: dir} do
    out = Path.join(dir, "uploads.html")

    assert render(["Uploads", "--out", out], Path.expand("test/fixtures/specs/uploads")) ==
             {out <> "\n", 0}

    assert File.read!(out) =~ "width: 1920px; height: 1080px"
  end

  test "a state and a variation draw what they change", %{tmp_dir: dir} do
    base = page("base.html", ["TaskScreen"], dir)
    problem = page("problem.html", ["TaskScreen", "--state", "problem"], dir)

    offline =
      page("offline.html", ["TaskScreen", "--state", "problem", "--variation", "offline"], dir)

    refute base =~ ~s(data-chain="banner")
    assert problem =~ "Something went wrong."
    assert problem =~ ">These may be out of date.<"
    assert offline =~ "<title>TaskScreen · problem · offline</title>"
    assert offline =~ "You&#39;re offline."
    assert offline =~ File.read!(Path.join(@tasks, "assets/icons/app/offline.svg"))
  end

  test "with no --out it writes a temp file and prints its path" do
    assert {path, 0} = render(["Header"])
    path = String.trim_trailing(path)
    assert Path.dirname(path) == Path.expand(System.tmp_dir!())
    assert File.read!(path) =~ ~s(data-file="components/Header.json")
    File.rm!(path)
  end

  test "an unknown item, state or variation, or no spec, exits 2", %{tmp_dir: dir} do
    assert render(["Nope"]) == {"No screen or component named Nope\n", 2}
    assert render(["Task"]) == {"No screen or component named Task\n", 2}

    assert render(["TaskScreen", "--state", "nope"]) ==
             {"No state nope in screens/TaskScreen.json\n", 2}

    assert {"No variation offline in screens/TaskScreen.json\n", 2} =
             render(["TaskScreen", "--variation", "offline"])

    assert render(
             ["Legacy", "--state", "retrying"],
             Path.expand("test/fixtures/specs/agent-order")
           ) ==
             {"components/Legacy.json fails its schema, so its states and variations can't be read\n",
              2}

    assert {"No spec found" <> _, 2} = render(["TaskScreen"], dir)
    assert {"Usage" <> _, 2} = render([])
    assert {"Usage" <> _, 2} = render(["TaskScreen", "--colour"])
  end
end
