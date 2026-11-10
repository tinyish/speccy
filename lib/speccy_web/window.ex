defmodule SpeccyWeb.Window do
  @moduledoc """
  The app's one window on the editor page, where there is a host to show it
  (`on?/0`). Every way to open a spec ends in `open/1`: File > Open… and ⌘O
  through `choose/0`, File > Open Recent, a `speccy open` reaching the
  running app (`{:open_file, [dir]}` from `Desktop.Env`), which this
  process takes, and, at launch, `SPECCY_OPEN`, the window's first page.
  When the host goes, this process quits the app.
  """
  use GenServer

  alias Speccy.Format
  alias SpeccyWeb.{Menu, Recent}

  @window :speccy_window

  @doc "Whether the window is on (`config/runtime.exs`)."
  def on?, do: Application.get_env(:speccy, :window, false)

  @doc "The window and this process, in that order, for the app's supervisor."
  def children do
    [
      {Desktop.Window,
       app: :speccy,
       id: @window,
       title: "speccy",
       size: {1280, 900},
       menubar: Menu,
       url: fn ->
         if dir = System.get_env("SPECCY_OPEN"),
           do: url(dir),
           else: SpeccyWeb.Endpoint.url() <> "/"
       end},
      __MODULE__
    ]
  end

  @doc """
  Shows the spec at or above `dir` in the window, in place of the one shown,
  and puts it first in the recent specs. A folder with no spec shows the
  page's message naming it, and isn't recorded.
  """
  def open(dir), do: Desktop.Window.load_url(@window, url(dir))

  # The page of the spec at or above `dir`, recorded in the recent specs.
  defp url(dir) do
    dir =
      case Format.find(dir) do
        {:ok, spec} ->
          Recent.add(spec)
          if menu = Process.whereis(Menu), do: send(menu, :recent)
          spec

        :error ->
          Path.expand(dir)
      end

    SpeccyWeb.Endpoint.url() <> "/?" <> URI.encode_query(spec: dir)
  end

  @doc """
  File > Open…: the folder picker, then `open/1` on what is chosen. The
  picker blocks its caller until dismissed, so it runs in a task of its own;
  Cancel leaves the spec shown.
  """
  def choose do
    choose =
      Application.get_env(:speccy, :choose_directory, &DesktopWebview.Dialog.choose_directory/1)

    Task.start(fn ->
      with dir when is_binary(dir) <- choose.(title: "Open a spec folder"), do: open(dir)
    end)
  end

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(nil) do
    Desktop.Env.subscribe()
    # In the app the host started the BEAM, and nothing else stops it when the host dies.
    if Process.whereis(DesktopWebview.Transport), do: DesktopWebview.Transport.subscribe()
    {:ok, nil}
  end

  @impl true
  def handle_info({:open_file, dirs}, state) do
    Enum.each(dirs, &open/1)
    {:noreply, state}
  end

  def handle_info({:edw_disconnected, _}, state) do
    Desktop.Window.quit()
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
