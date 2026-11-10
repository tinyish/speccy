defmodule Speccy.Workspace do
  @moduledoc """
  One open spec, a process per spec folder: holds the spec as last read,
  each file's last good content (valid JSON that passes its schema), the
  `Speccy.Spec` built from the good contents, and the check's problems,
  run on what was read. It watches the folder and writes nothing.

  On any event in the folder it waits for a quiet moment, then reads the
  whole spec again, since an agent leaves a file half-written between two
  writes and editors save through a temp file and a rename. If anything
  read differs, it rebuilds, re-checks and broadcasts
  `{:spec_changed, spec, problems, stale}` on `Speccy.PubSub`, on
  `topic(dir)`. `stale` is the sorted paths of the files drawn
  from their last good version because what was read isn't valid JSON or
  fails its schema.

  A folder is known by its expanded path. A workspace that dies stays
  dead; `open/1` starts a fresh one.
  """

  # Temporary: one that keeps dying must not take every other open spec with it.
  use GenServer, restart: :temporary

  alias Speccy.{Check, Format, Spec}

  @quiet 50

  @doc "Starts the workspace of the spec folder `dir`, or finds it."
  def open(dir) do
    case DynamicSupervisor.start_child(__MODULE__.Supervisor, {__MODULE__, Path.expand(dir)}) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @doc "`{spec, problems, stale}` of the open spec folder `dir`, as broadcast."
  def get(dir), do: GenServer.call(name(dir), :get)

  @doc "The PubSub topic the workspace of `dir` broadcasts on."
  def topic(dir), do: "workspace:" <> Path.expand(dir)

  def start_link(dir), do: GenServer.start_link(__MODULE__, dir, name: name(dir))

  defp name(dir), do: {:via, Registry, {__MODULE__.Registry, Path.expand(dir)}}

  @impl true
  def init(dir) do
    {:ok, watcher} = FileSystem.start_link(dirs: [dir], latency: 0)
    FileSystem.subscribe(watcher)
    # FSEvents takes a moment to start: one more read, unless an event comes
    # first, catches a change made before it did.
    timer = make_ref()
    Process.send_after(self(), {:quiet, timer}, 1000)
    {:ok, read(%{dir: dir, good: %{}, timer: timer}, Format.load(dir))}
  end

  @impl true
  def handle_call(:get, _from, state),
    do: {:reply, {state.spec, state.problems, state.stale}, state}

  @impl true
  def handle_info({:file_event, _, :stop}, state), do: {:stop, :watcher_stopped, state}

  # Each event restarts the quiet timer; a timer it replaced is ignored when it fires.
  def handle_info({:file_event, _, _}, state) do
    timer = make_ref()
    Process.send_after(self(), {:quiet, timer}, @quiet)
    {:noreply, %{state | timer: timer}}
  end

  def handle_info({:quiet, timer}, %{timer: timer} = state) do
    loaded = Format.load(state.dir)

    if loaded == state.loaded do
      {:noreply, state}
    else
      state = read(state, loaded)
      message = {:spec_changed, state.spec, state.problems, state.stale}
      Phoenix.PubSub.broadcast(Speccy.PubSub, topic(state.dir), message)
      {:noreply, state}
    end
  end

  def handle_info({:quiet, _}, state), do: {:noreply, state}

  defp read(state, loaded) do
    checked = Spec.new(loaded)
    # A deleted file's last good version goes with it.
    good =
      state.good
      |> Map.take(Map.keys(loaded.files))
      |> Map.merge(Map.take(loaded.files, Map.keys(checked.valid)))

    stale = for {path, json} <- good, json != loaded.files[path], do: path

    spec =
      if stale == [],
        do: checked,
        else: Spec.new(%{loaded | files: Map.merge(loaded.files, good)})

    Map.merge(state, %{
      loaded: loaded,
      good: good,
      spec: spec,
      problems: Check.run(checked),
      stale: Enum.sort(stale)
    })
  end
end
