defmodule DesktopCanvas.Application do
  # The liveview-canvas page in elixir-desktop's WKWebView window, with File > Open….
  use Application

  def start(_type, _args) do
    Application.put_env(:spike, :spec_dir, System.get_env("SPEC_DIR") || fresh_copy())
    query = if System.get_env("SELFTEST"), do: "?selftest", else: ""

    children = [
      {Phoenix.PubSub, name: DesktopCanvas.PubSub},
      DesktopCanvas.Endpoint,
      {Desktop.Window, app: :desktop_canvas, id: DesktopCanvas.Window, title: "speccy canvas",
       size: {1280, 900}, menubar: DesktopCanvas.Menu, url: fn -> DesktopCanvas.Endpoint.url() <> "/" <> query end}
    ]

    IO.puts("editing #{Spike.Spec.dir()}")
    Supervisor.start_link(children, strategy: :one_for_one, name: DesktopCanvas.Supervisor)
  end

  # Like the spike: a temp copy of the example, never the live spec.
  defp fresh_copy do
    dir = Path.join(System.tmp_dir!(), "speccy-desktop-canvas")
    File.rm_rf!(dir)
    File.cp_r!(Path.expand("../../spec-format/example", __DIR__), dir)
    dir
  end

  def choose_folder do
    case DesktopWebview.Dialog.choose_directory(title: "Open a spec folder") do
      dir when is_binary(dir) -> open(dir)
      other -> IO.puts("open: #{inspect(other)}")
    end
  end

  def open(dir) do
    if Path.wildcard(Path.join(dir, "screens/*.json")) == [] do
      IO.puts("open: #{dir} has no screens/*.json, ignored")
    else
      Application.put_env(:spike, :spec_dir, dir)
      IO.puts("open: editing #{dir}")
      # The spike's LiveView reads the folder at mount; a reload remounts it on the new one.
      Desktop.Window.reload(DesktopCanvas.Window)
    end
  end
end

defmodule DesktopCanvas.Menu do
  use Desktop.Menu

  def mount(menu), do: {:ok, menu}

  def handle_event("open", menu) do
    DesktopCanvas.Application.choose_folder()
    {:noreply, menu}
  end

  def handle_info(_, menu), do: {:noreply, menu}

  def render(assigns) do
    ~H"""
    <menubar>
      <menu label="File"><item onclick="open">Open…</item></menu>
    </menubar>
    """
  end
end

defmodule DesktopCanvas.Layout do
  # The spike's root layout, with this page's own script ahead of the LiveView.
  use Phoenix.Component

  @js File.read!(Path.join(__DIR__, "page.js"))
  @external_resource Path.join(__DIR__, "page.js")

  def root(assigns) do
    page = assigns.inner_content
    Spike.Layout.root(assign(assigns, :inner_content, body(%{page: page, js: @js})))
  end

  defp body(assigns),
    do: ~H"""
    {Phoenix.HTML.raw("<script>" <> @js <> "</script>")}{@page}
    """
end

defmodule DesktopCanvas.SelfTest do
  # The page's self-test (?selftest): an outside edit for it to time, and its report.
  import Plug.Conn

  def init(what), do: what

  def call(conn, what) do
    if System.get_env("SELFTEST"), do: run(conn, what), else: send_resp(conn, 404, "")
  end

  defp run(conn, :outside) do
    {:ok, body, conn} = read_body(conn)
    %{"key" => key, "value" => value} = Jason.decode!(body)
    spec = Spike.Spec.load()
    Spike.Spec.save(%{spec | screen: Spike.Spec.edit(spec.screen, "base", key, value)})
    send_resp(conn, 204, "")
  end

  defp run(conn, :report) do
    {:ok, body, conn} = read_body(conn, length: 1_000_000)
    IO.puts("selftest " <> body)
    send_resp(conn, 204, "")
  end
end

defmodule DesktopCanvas.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {DesktopCanvas.Layout, :root}
    plug :protect_from_forgery
  end

  scope "/" do
    pipe_through :browser
    live "/", Spike.CanvasLive
  end

  post "/selftest/outside", DesktopCanvas.SelfTest, :outside
  post "/selftest/report", DesktopCanvas.SelfTest, :report
end

defmodule DesktopCanvas.Endpoint do
  # Spike.Endpoint, on this router.
  use Phoenix.Endpoint, otp_app: :desktop_canvas
  @session [store: :cookie, key: "_spike", signing_salt: "speccyspike"]
  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session]]
  plug Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}
  plug Plug.Static, at: "/assets/lv", from: {:phoenix_live_view, "priv/static"}
  plug Plug.Session, @session
  plug DesktopCanvas.Router
end
