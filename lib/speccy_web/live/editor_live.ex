defmodule SpeccyWeb.EditorLive do
  @moduledoc """
  The editor page: the open spec's items, every frame of the screen or
  component on show, side by side, and the check's problems, redrawn when
  the spec's workspace broadcasts a change. The spec comes from `?spec=` or
  `SPECCY_OPEN`, the item on show from `?item=` (its file's path). Pan and
  zoom live in the canvas hook (`conventions.md#gestures-in-the-hook`).

  Library icons not in the cache draw as their placeholder, are fetched in
  the background, and redraw as each arrives.
  """
  use SpeccyWeb, :live_view

  alias Speccy.{Draw, Format, Icons, Resolve, Spec, Workspace}
  alias Speccy.Icons.Cache

  @kinds [{"Screens", :screen}, {"Components", :component}, {"Data models", :data}]

  @impl true
  def mount(params, _session, socket) do
    given = present(params["spec"]) || present(System.get_env("SPECCY_OPEN"))

    socket =
      assign(socket,
        given: given,
        # Kept in the item links only when the spec came from the address.
        query: if(present(params["spec"]), do: %{spec: params["spec"]}, else: %{}),
        dir: nil,
        item: nil,
        frames: [],
        chosen: %{},
        tried: MapSet.new(),
        page_title: "No spec"
      )

    case given && Format.find(given) do
      {:ok, dir} ->
        # Subscribed before the first read, so no change between them is lost.
        if connected?(socket), do: Phoenix.PubSub.subscribe(Speccy.PubSub, Workspace.topic(dir))
        {:ok, socket |> assign(dir: dir) |> open()}

      _ ->
        {:ok, socket}
    end
  end

  # A workspace that dies stays dead: open it again.
  defp open(socket) do
    {:ok, pid} = Workspace.open(socket.assigns.dir)
    monitor = if connected?(socket), do: Process.monitor(pid)
    {spec, problems, stale} = Workspace.get(socket.assigns.dir)
    assign(socket, spec: spec, problems: problems, stale: stale, monitor: monitor)
  end

  @impl true
  def handle_params(params, _uri, %{assigns: %{dir: dir}} = socket) when is_binary(dir) do
    item = present(params["item"]) || first(socket.assigns.spec)
    socket = if item == socket.assigns.item, do: socket, else: assign(socket, chosen: %{})
    {:noreply, socket |> assign(item: item) |> draw()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  # The base, and "as written", send no value.
  def handle_event("variation", params, socket) do
    chosen = Map.put(socket.assigns.chosen, params["state"], params["variation"])
    {:noreply, socket |> assign(chosen: chosen) |> draw()}
  end

  @impl true
  def handle_info({:spec_changed, spec, problems, stale}, socket),
    do: {:noreply, socket |> assign(spec: spec, problems: problems, stale: stale) |> draw()}

  def handle_info({:DOWN, ref, :process, _, _}, %{assigns: %{monitor: ref}} = socket),
    do: {:noreply, socket |> open() |> draw()}

  @impl true
  def handle_async({:icon, _}, {:ok, :ok}, socket), do: {:noreply, draw(socket)}
  # A fetch that fails leaves its placeholder.
  def handle_async({:icon, _}, _, socket), do: {:noreply, socket}

  # The frames of the item on show, resolved again, and the icons they draw.
  defp draw(socket) do
    %{spec: spec, item: path, chosen: chosen, stale: stale} = socket.assigns
    json = spec.valid[path] || %{}

    frames =
      for {state, variations} <- frames(spec, path) do
        variation = if chosen[state] in variations, do: chosen[state]
        tree = Resolve.frame(spec, path, state, variation)
        files = files(tree)

        %{
          state: state,
          about: if(state, do: get_in(json, ["states", state, "about"]), else: json["about"]),
          variations: variations,
          variation: variation,
          tree: tree,
          stale: Enum.filter(stale, &(&1 in files))
        }
      end

    refs = frames |> Enum.flat_map(&Icons.refs(&1.tree)) |> Enum.uniq()
    icons = Cache.svgs(refs, spec)

    socket
    |> assign(
      frames: frames,
      icons: icons,
      size: Spec.size(spec, path),
      page_title: name(spec, path) || Path.basename(socket.assigns.dir)
    )
    |> fetch(refs -- Map.keys(icons))
  end

  # A file that is read but fails its schema has no frames: its base draws
  # as the error it is.
  defp frames(spec, path) do
    case Spec.frames(spec, path) do
      [] -> if spec.read[path], do: [{nil, []}], else: []
      frames -> frames
    end
  end

  defp files(node), do: Enum.map(node.origin, & &1.file) ++ Enum.flat_map(node.children, &files/1)

  # Each missing icon is fetched once per page, once connected; what doesn't
  # arrive stays a placeholder.
  defp fetch(socket, refs) do
    Enum.reduce(refs, socket, fn ref, socket ->
      if ref in socket.assigns.tried,
        do: socket,
        else:
          socket
          |> update(:tried, &MapSet.put(&1, ref))
          |> start_async({:icon, ref}, fn -> Cache.fetch(ref) end)
    end)
  end

  # The first screen by name, else the first component.
  defp first(spec) do
    Enum.find_value([:screen, :component], fn kind ->
      case items(spec, kind) do
        [{_, path} | _] -> path
        [] -> nil
      end
    end)
  end

  defp items(spec, kind), do: Enum.sort(for {name, ^kind, path} <- spec.items, do: {name, path})

  defp name(spec, path), do: Enum.find_value(spec.items, fn {n, _, p} -> p == path && n end)

  defp present(""), do: nil
  defp present(value), do: value

  @impl true
  def render(%{dir: nil} = assigns) do
    ~H"""
    <main class="hero min-h-screen bg-base-200">
      <div class="hero-content max-w-lg flex-col items-start">
        <h1 class="text-2xl font-semibold">
          {if @given, do: "No spec at or above #{@given}", else: "No spec open"}
        </h1>
        <p>
          Open a spec by starting speccy with <code class="font-mono">SPECCY_OPEN</code>
          set to its folder, or by adding <code class="font-mono">?spec=&lt;folder&gt;</code>
          to this page's address. A spec's folder holds a <code class="font-mono">speccy.json</code>.
        </p>
      </div>
    </main>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <style>
      <%= raw(Draw.css()) %>
    </style>
    <div class="flex h-screen bg-base-200 text-sm">
      <nav id="items" class="w-56 shrink-0 overflow-y-auto border-r border-base-300 bg-base-100 p-3">
        <p class="truncate px-2 pb-2 font-semibold" title={@dir}>{Path.basename(@dir)}</p>
        <section :for={{title, kind} <- kinds()} id={"items-#{kind}"} class="pb-3">
          <h2 class="px-2 pb-1 text-xs uppercase tracking-wide opacity-60">{title}</h2>
          <ul class="menu menu-sm w-full p-0">
            <li :for={{name, path} <- items(@spec, kind)}>
              <span :if={kind == :data}>{name}</span>
              <.link
                :if={kind != :data}
                patch={~p"/?#{Map.put(@query, :item, path)}"}
                class={path == @item && "menu-active"}
              >
                {name}
              </.link>
            </li>
          </ul>
        </section>
      </nav>

      <%!-- clip, not hidden: focus never scrolls the canvas under the hook's transform --%>
      <main id="canvas" phx-hook=".Canvas" class="relative flex-1 overflow-clip">
        <p :if={@frames == []} class="p-6 opacity-60">Pick a screen or a component.</p>
        <div
          id="world"
          phx-mounted={JS.ignore_attributes("style")}
          class="absolute left-0 top-0 flex origin-top-left items-start gap-12"
        >
          <figure :for={f <- @frames} class="shrink-0 space-y-2" data-state={f.state}>
            <figcaption class="flex max-w-md flex-wrap items-center gap-2">
              <span class="font-semibold">{f.state || "base"}</span>
              <span :if={f.about} class="opacity-70">{f.about}</span>
              <span
                :for={file <- f.stale}
                class="badge badge-warning badge-sm"
                title="This file can't be read as it is now; its last good version is drawn"
              >
                {file}: last good version
              </span>
              <span :if={f.variations != []} class="join">
                <.button
                  :for={v <- [nil | f.variations]}
                  class={["btn btn-xs join-item", v == f.variation && "btn-active"]}
                  phx-click="variation"
                  phx-value-state={f.state}
                  phx-value-variation={v}
                >
                  {v || "as written"}
                </.button>
              </span>
            </figcaption>
            <div class="w-fit shadow">
              <Draw.frame tree={f.tree} icons={@icons} size={@size} />
            </div>
          </figure>
        </div>
      </main>

      <aside
        id="problems"
        class="w-80 shrink-0 overflow-y-auto border-l border-base-300 bg-base-100 p-3"
      >
        <h2 class="pb-2 font-semibold">
          Problems <span class="badge badge-sm">{length(@problems)}</span>
        </h2>
        <p :if={@problems == []} class="opacity-60">No problems.</p>
        <ul class="space-y-2">
          <li :for={p <- @problems} class="space-y-0.5">
            <p><span class="badge badge-error badge-sm font-mono">{p.code}</span></p>
            <p class="break-all font-mono text-xs opacity-70">{p.file}{p.path}</p>
            <p>{p.message}</p>
          </li>
        </ul>
      </aside>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Canvas">
      // Pan (wheel, space-drag, middle-drag) and zoom (Cmd/Ctrl-wheel) as a
      // CSS transform on the world, kept in the page.
      export default {
        mounted() {
          const view = {x: 40, y: 40, z: 1}
          const world = this.el.querySelector("#world")
          const apply = () => world.style.transform = `translate(${view.x}px, ${view.y}px) scale(${view.z})`
          apply()

          this.abort = new AbortController()
          const on = {signal: this.abort.signal}

          this.el.addEventListener("wheel", e => {
            e.preventDefault()
            if (e.ctrlKey || e.metaKey) {
              const r = this.el.getBoundingClientRect(), px = e.clientX - r.left, py = e.clientY - r.top
              const z = Math.min(4, Math.max(0.1, view.z * Math.exp(-e.deltaY * 0.01)))
              view.x = px - (px - view.x) * z / view.z
              view.y = py - (py - view.y) * z / view.z
              view.z = z
            } else {
              view.x -= e.deltaX
              view.y -= e.deltaY
            }
            apply()
          }, {passive: false, ...on})

          // Space is the canvas's, even with a button focused: kept from
          // scrolling the page and from pressing the button.
          let space = false, pan = null
          window.addEventListener("keydown", e => {
            if (e.code !== "Space") return
            e.preventDefault()
            space = true
            this.el.style.cursor = "grab"
          }, on)
          window.addEventListener("keyup", e => {
            if (e.code !== "Space") return
            space = false
            this.el.style.cursor = ""
          }, on)

          this.el.addEventListener("pointerdown", e => {
            if (e.button !== 1 && !space) return
            e.preventDefault()
            pan = {x: e.clientX, y: e.clientY}
          }, on)
          window.addEventListener("pointermove", e => {
            if (!pan) return
            view.x += e.clientX - pan.x
            view.y += e.clientY - pan.y
            pan = {x: e.clientX, y: e.clientY}
            apply()
          }, on)
          window.addEventListener("pointerup", () => pan = null, on)
        },
        destroyed() { this.abort.abort() }
      }
    </script>
    """
  end

  defp kinds, do: @kinds
end
