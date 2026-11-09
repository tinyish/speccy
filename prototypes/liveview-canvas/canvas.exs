# Throwaway spike: does a LiveView canvas feel right for speccy's editor?
# Run: elixir canvas.exs   (SPEC_DIR=/some/copy and PORT=4100 to override)
Mix.install([
  {:phoenix, "~> 1.8"},
  {:phoenix_live_view, "~> 1.1"},
  {:bandit, "~> 1.5"},
  {:jason, "~> 1.4"}
])

spec_dir =
  System.get_env("SPEC_DIR") ||
    (fn ->
       dir = Path.join(System.tmp_dir!(), "speccy-canvas-spike")
       File.rm_rf!(dir)
       File.cp_r!(Path.join(__DIR__, "../spec-format/example"), dir)
       dir
     end).()

port = String.to_integer(System.get_env("PORT") || "4100")
Application.put_env(:spike, :spec_dir, spec_dir)

Application.put_env(:spike, Spike.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: port],
  server: true,
  debug_errors: true,
  check_origin: false,
  secret_key_base: String.duplicate("speccy", 11),
  live_view: [signing_salt: "speccyspike"],
  pubsub_server: Spike.PubSub
)

defmodule Spike.Spec do
  @layout_keys ~w(hidden width height minWidth maxWidth minHeight maxHeight layout wrap columns align gap padding clip)

  def dir, do: Application.fetch_env!(:spike, :spec_dir)

  def load do
    comps =
      for f <- Path.wildcard(Path.join(dir(), "components/*.json")), into: %{} do
        c = f |> File.read!() |> Jason.decode!()
        {c["component"], c}
      end

    [file | _] = Path.wildcard(Path.join(dir(), "screens/*.json"))
    %{comps: comps, screen: file |> File.read!() |> Jason.decode!(), file: file}
  end

  def signature,
    do: Path.wildcard(Path.join(dir(), "**/*.json")) |> Enum.map(&File.read!/1) |> :erlang.md5()

  # shortcut: plain maps lose the file's key order (and so state order), fine for a spike
  def save(spec), do: File.write!(spec.file, Jason.encode!(spec.screen, pretty: true) <> "\n")

  def apply_state(screen, "base"), do: screen

  def apply_state(screen, name) do
    Enum.reduce(get_in(screen, ["states", name, "set"]) || %{}, screen, fn {key, val}, acc ->
      [id, field] = String.split(key, ".", parts: 2)
      update_inst(acc, id, &put_field(&1, field, val))
    end)
  end

  def edit(screen, "base", key, value) do
    [id, field] = String.split(key, ".", parts: 2)
    update_inst(screen, id, &put_field(&1, field, value))
  end

  def edit(screen, state, key, value),
    do: update_in(screen, ["states", state], &Map.update(&1, "set", %{key => value}, fn s -> Map.put(s, key, value) end))

  def reorder(%{"children" => kids} = node, id, before) do
    case Enum.find(kids, &(&1["id"] == id)) do
      nil ->
        %{node | "children" => Enum.map(kids, &reorder(&1, id, before))}

      moving ->
        rest = Enum.reject(kids, &(&1["id"] == id))
        at = (before && Enum.find_index(rest, &(&1["id"] == before))) || length(rest)
        %{node | "children" => List.insert_at(rest, at, moving)}
    end
  end

  def reorder(node, _, _), do: node

  defp put_field(inst, field, val) when field in @layout_keys, do: Map.put(inst, field, val)
  defp put_field(inst, field, val), do: Map.update(inst, "props", %{field => val}, &Map.put(&1, field, val))

  defp update_inst(%{"children" => kids} = node, id, fun),
    do: %{node | "children" => Enum.map(kids, &if(&1["id"] == id, do: fun.(&1), else: update_inst(&1, id, fun)))}

  defp update_inst(node, _, _), do: node

  # Instances -> render nodes. A value is {value, edit_key}; only literal props on the
  # screen's own instances are editable, everything inside a component is the component's.
  def build(inst, ctx) do
    if inst["hidden"] == true do
      []
    else
      literal = for {k, v} <- inst["props"] || %{}, into: %{}, do: {k, {v, ctx.screen? && "#{inst["id"]}.#{k}"}}
      bound = for {k, path} <- inst["bind"] || %{}, into: %{}, do: {k, lookup(ctx.vals, path)}
      vals = Map.merge(literal, bound)
      copies = if inst["repeat"], do: 3, else: 1
      1..copies |> Enum.map(fn _ -> build_one(inst, vals, ctx) end) |> Enum.reject(&is_nil/1)
    end
  end

  defp build_one(inst, vals, ctx) do
    base = %{
      sid: ctx.screen? && inst["id"],
      parent: ctx.screen? && ctx.parent,
      w: inst["width"],
      h: inst["height"],
      gap: inst["gap"],
      pad: inst["padding"],
      dir: inst["layout"] || "column"
    }

    kids = fn children, vals, screen? ->
      Enum.flat_map(children || [], &build(&1, %{ctx | vals: vals, screen?: screen?, parent: inst["id"]}))
    end

    case ctx.comps[inst["use"]] do
      nil ->
        primitive(inst["use"], inst, vals, base, kids)

      comp ->
        Map.merge(base, %{
          tag: :box,
          dir: comp["layout"] || "column",
          w: inst["width"] || comp["width"],
          h: inst["height"] || comp["height"],
          gap: comp["gap"],
          pad: comp["padding"],
          children: kids.(comp["children"], vals, false)
        })
    end
  end

  defp primitive(use, inst, vals, base, kids) do
    {text, edit} = text_of(vals["text"])
    use = if use == "input" and val(vals["type"]) == "checkbox", do: "checkbox", else: use

    case use do
      "text" -> Map.merge(base, %{tag: :text, text: text, edit: edit})
      "button" -> Map.merge(base, %{tag: :button, text: text, edit: edit, disabled: val(vals["disabled"])})
      "checkbox" -> Map.put(base, :tag, :checkbox)
      "input" -> Map.merge(base, %{tag: :input, placeholder: val(vals["placeholder"])})
      "dialog" -> if val(vals["open"]) == true, do: Map.merge(base, %{tag: :dialog, children: kids.(inst["children"], vals, base.sid != false)}), else: nil
      _ -> Map.merge(base, %{tag: :box, children: kids.(inst["children"], vals, base.sid != false)})
    end
  end

  defp val(nil), do: nil
  defp val({v, _}), do: v
  defp text_of({v, e}) when is_binary(v), do: {v, e}
  defp text_of({v, _}), do: {inspect(v), nil}
  defp text_of(nil), do: {"", nil}

  defp lookup(vals, path) do
    [head | rest] = String.split(path, ".")

    case {vals[head], rest} do
      {nil, _} -> {"{#{path}}", nil}
      {found, []} -> found
      {{m, _}, rest} when is_map(m) -> {get_in(m, rest) || "{#{path}}", nil}
      _ -> {"{#{path}}", nil}
    end
  end

  def frames(spec) do
    states = spec.screen["states"] || %{}

    [{"base", "The screen as defined."} | Enum.map(states, fn {k, s} -> {k, s["about"]} end)]
    |> Enum.map(fn {key, about} ->
      screen = apply_state(spec.screen, key)
      ctx = %{comps: spec.comps, vals: %{}, screen?: true, parent: "root"}
      nodes = Enum.flat_map(screen["children"] || [], &build(&1, ctx))
      %{key: key, about: about, nodes: nodes, dir: screen["layout"] || "column"}
    end)
  end
end

defmodule Spike.CanvasLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(300, :poll)
    {:ok, assign(socket, spec: Spike.Spec.load(), sig: Spike.Spec.signature())}
  end

  # Someone else (an agent) changed the files: reload.
  def handle_info(:poll, socket) do
    sig = Spike.Spec.signature()
    if sig == socket.assigns.sig, do: {:noreply, socket}, else: {:noreply, assign(socket, spec: Spike.Spec.load(), sig: sig)}
  end

  def handle_event("reorder", %{"id" => id, "before" => before}, socket),
    do: commit(socket, &Spike.Spec.reorder(&1, id, before))

  def handle_event("edit", %{"frame" => frame, "key" => key, "value" => value}, socket),
    do: commit(socket, &Spike.Spec.edit(&1, frame, key, value))

  defp commit(socket, fun) do
    t0 = System.monotonic_time(:microsecond)
    spec = %{socket.assigns.spec | screen: fun.(socket.assigns.spec.screen)}
    Spike.Spec.save(spec)
    ms = (System.monotonic_time(:microsecond) - t0) / 1000
    {:reply, %{ms: ms}, assign(socket, spec: spec, sig: Spike.Spec.signature())}
  end

  def render(assigns) do
    assigns = assign(assigns, frames: Spike.Spec.frames(assigns.spec))

    ~H"""
    <div id="canvas" phx-hook="Canvas" class="canvas">
      <div class="world">
        <div :for={f <- @frames} class="frame-wrap">
          <div class="frame-title"><b>{f.key}</b> {f.about}</div>
          <div class={"frame #{f.dir}"} data-frame={f.key}>
            <.wf :for={n <- f.nodes} n={n} frame={f.key} />
          </div>
        </div>
      </div>
    </div>
    <div id="hud" phx-update="ignore">drag a top-level instance in base · double-click copy to edit · ⌘/ctrl+wheel zooms</div>
    <div class="path">editing {Spike.Spec.dir()}</div>
    """
  end

  attr :n, :map
  attr :frame, :string

  def wf(%{n: %{tag: tag}} = assigns) when tag in [:box, :dialog] do
    ~H"""
    <div class={"box #{@n.dir} #{@n.tag}"} {common(@n, @frame)}>
      <.wf :for={c <- @n.children} n={c} frame={@frame} />
    </div>
    """
  end

  def wf(%{n: %{tag: :text}} = assigns),
    do: ~H"""
    <span class="txt" data-edit={@n.edit} {common(@n, @frame)}>{@n.text}</span>
    """

  def wf(%{n: %{tag: :button}} = assigns),
    do: ~H"""
    <button class="btn" disabled={@n.disabled} {common(@n, @frame)}><span data-edit={@n.edit}>{@n.text}</span></button>
    """

  def wf(%{n: %{tag: :input}} = assigns),
    do: ~H"""
    <input class="inp" placeholder={@n.placeholder} readonly {common(@n, @frame)} />
    """

  def wf(%{n: %{tag: :checkbox}} = assigns),
    do: ~H"""
    <input type="checkbox" disabled {common(@n, @frame)} />
    """

  defp common(n, frame) do
    px = fn v -> if is_number(v), do: "#{v}px" end
    style = [{"width", px.(n.w)}, {"height", px.(n.h)}, {"gap", px.(n.gap)}, {"padding", px.(n.pad)}]

    [
      id: n.sid && "#{frame}-#{n.sid}",
      "data-sid": n.sid,
      "data-parent": n.parent,
      "data-drag": frame == "base" && n.sid && "1",
      "data-w": n.w in ["fill", "hug"] && n.w,
      "data-h": n.h in ["fill", "hug"] && n.h,
      style: for({k, v} <- style, v, do: "#{k}:#{v};") |> Enum.join()
    ]
    |> Enum.filter(fn {_, v} -> v not in [nil, false, ""] end)
  end
end

defmodule Spike.Layout do
  use Phoenix.Component

  @css """
  :root { --bg:#08090a; --panel:#0f1011; --line:#23252a; --text:#f7f8f8; --muted:#8a8f98; --accent:#5e6ad2; }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--text); font:13px Inter, system-ui, sans-serif; overflow:hidden; }
  .canvas { position:fixed; inset:0; overflow:hidden; touch-action:none; }
  .world { position:absolute; left:0; top:0; transform-origin:0 0; display:flex; gap:48px; align-items:flex-start; }
  .frame-title { color:var(--muted); margin-bottom:8px; max-width:390px; }
  .frame-title b { color:var(--text); font-weight:500; margin-right:6px; }
  .frame { position:relative; width:390px; height:844px; background:var(--panel); border:1px solid var(--line); border-radius:6px; overflow:hidden; display:flex; gap:8px; padding:8px; }
  .row { display:flex; flex-direction:row; align-items:center; } .column { display:flex; flex-direction:column; }
  .box { gap:8px; padding:8px; border:1px dashed #2a2c33; border-radius:6px; min-width:0; }
  .row > [data-w=fill] { flex:1 1 0; } .column > [data-w=fill] { align-self:stretch; }
  .row > [data-h=fill] { align-self:stretch; } .column > [data-h=fill] { flex:1 1 0; min-height:0; }
  .dialog { position:absolute; left:24px; right:24px; top:40%; background:#16171a; border:1px solid var(--line); z-index:2; }
  .btn { font:inherit; color:var(--text); background:#1c1d21; border:1px solid var(--line); border-radius:6px; padding:4px 10px; }
  .btn:disabled { opacity:.45; }
  .inp { font:inherit; color:var(--text); background:transparent; border:1px solid var(--line); border-radius:6px; padding:4px 8px; width:120px; }
  [data-drag] { cursor:grab; }
  .dragging { position:relative; z-index:5; opacity:.85; outline:1px solid var(--accent); cursor:grabbing; }
  .drop-before { box-shadow: 0 -2px 0 var(--accent); } .drop-after { box-shadow: 0 2px 0 var(--accent); }
  [contenteditable=true] { outline:1px solid var(--accent); cursor:text; }
  #hud, .path { position:fixed; left:12px; color:var(--muted); background:var(--panel); border:1px solid var(--line); border-radius:6px; padding:6px 10px; }
  #hud { bottom:12px; } .path { bottom:48px; font-size:11px; }
  """

  # Everything interactive is client-side; the server only sees the committed result.
  @js """
  const Canvas = {
    mounted() {
      this.view = { x: 40, y: 40, z: 0.8 }
      const world = () => this.el.querySelector('.world')
      this.apply = () => { world().style.transform = `translate(${this.view.x}px, ${this.view.y}px) scale(${this.view.z})` }
      this.apply()
      const hud = (what, t0, server) => { document.getElementById('hud').textContent =
        `${what}: ${(performance.now() - t0).toFixed(1)}ms round trip (server ${server.toFixed(1)}ms)` }

      this.el.addEventListener('wheel', e => {
        e.preventDefault()
        const v = this.view
        if (e.ctrlKey || e.metaKey) {
          const r = this.el.getBoundingClientRect(), px = e.clientX - r.left, py = e.clientY - r.top
          const z = Math.min(4, Math.max(0.1, v.z * Math.exp(-e.deltaY * 0.01)))
          v.x = px - (px - v.x) * z / v.z; v.y = py - (py - v.y) * z / v.z; v.z = z
        } else { v.x -= e.deltaX; v.y -= e.deltaY }
        this.apply()
      }, { passive: false })

      let space = false, drag = null, pan = null
      window.addEventListener('keydown', e => { if (e.code === 'Space' && !e.target.isContentEditable) { space = true; e.preventDefault() } })
      window.addEventListener('keyup', e => { if (e.code === 'Space') space = false })

      const clearDrop = () => this.el.querySelectorAll('.drop-before,.drop-after').forEach(n => n.classList.remove('drop-before', 'drop-after'))

      this.el.addEventListener('pointerdown', e => {
        if (e.target.isContentEditable) return
        if (e.button === 1 || space) { pan = { x: e.clientX, y: e.clientY }; return }
        const item = e.button === 0 && e.target.closest('[data-drag]')
        if (item) drag = { item, sx: e.clientX, sy: e.clientY, on: false }
      })

      window.addEventListener('pointermove', e => {
        if (pan) { this.view.x += e.clientX - pan.x; this.view.y += e.clientY - pan.y; pan = { x: e.clientX, y: e.clientY }; this.apply(); return }
        if (!drag) return
        const dx = e.clientX - drag.sx, dy = e.clientY - drag.sy
        if (!drag.on && Math.hypot(dx, dy) < 4) return
        drag.on = true
        drag.item.classList.add('dragging')
        drag.item.style.transform = `translate(${dx / this.view.z}px, ${dy / this.view.z}px)`
        const parent = drag.item.parentElement
        const row = getComputedStyle(parent).flexDirection === 'row'
        const sibs = [...parent.children].filter(c => c !== drag.item && c.dataset.sid)
        const pos = row ? e.clientX : e.clientY
        const target = sibs.find(s => { const r = s.getBoundingClientRect(); return pos < (row ? r.left + r.width / 2 : r.top + r.height / 2) })
        clearDrop()
        if (target) target.classList.add('drop-before'); else if (sibs.length) sibs[sibs.length - 1].classList.add('drop-after')
        drag.before = target ? target.dataset.sid : null
      })

      window.addEventListener('pointerup', () => {
        pan = null
        if (!drag) return
        const d = drag; drag = null
        clearDrop()
        if (!d.on) return
        const t0 = performance.now()
        this.pushEvent('reorder', { id: d.item.dataset.sid, before: d.before }, r => {
          d.item.style.transform = ''; d.item.classList.remove('dragging'); hud('reorder', t0, r.ms)
        })
      })

      this.el.addEventListener('dblclick', e => {
        const t = e.target.closest('[data-edit]')
        if (!t) return
        const frame = t.closest('[data-frame]').dataset.frame, old = t.textContent
        let finished = false
        t.contentEditable = 'true'; t.focus(); getSelection().selectAllChildren(t)
        const done = save => {
          if (finished) return; finished = true
          t.contentEditable = 'false'
          if (!save) { t.textContent = old; return }
          const value = t.textContent
          if (value === old) return
          const t0 = performance.now()
          this.pushEvent('edit', { frame, key: t.dataset.edit, value }, r => hud('edit', t0, r.ms))
        }
        t.addEventListener('keydown', ev => { if (ev.key === 'Enter') { ev.preventDefault(); done(true) } else if (ev.key === 'Escape') done(false) })
        t.addEventListener('blur', () => done(true), { once: true })
      })
    },
    updated() { this.apply() }
  }
  const token = document.querySelector("meta[name='csrf-token']").getAttribute('content')
  const liveSocket = new LiveView.LiveSocket('/live', Phoenix.Socket, { hooks: { Canvas }, params: { _csrf_token: token } })
  liveSocket.connect()
  """

  def root(assigns) do
    assigns = assign(assigns, css: @css, js: @js)

    ~H"""
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>speccy canvas spike</title>
        <script src="/assets/phoenix/phoenix.min.js"></script>
        <script src="/assets/lv/phoenix_live_view.min.js"></script>
        {Phoenix.HTML.raw("<style>" <> @css <> "</style>")}
      </head>
      <body>
        {@inner_content}
        {Phoenix.HTML.raw("<script>" <> @js <> "</script>")}
      </body>
    </html>
    """
  end
end

defmodule Spike.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {Spike.Layout, :root}
    plug :protect_from_forgery
  end

  scope "/" do
    pipe_through :browser
    live "/", Spike.CanvasLive
  end
end

defmodule Spike.Endpoint do
  use Phoenix.Endpoint, otp_app: :spike
  @session [store: :cookie, key: "_spike", signing_salt: "speccyspike"]
  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session]]
  plug Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}
  plug Plug.Static, at: "/assets/lv", from: {:phoenix_live_view, "priv/static"}
  plug Plug.Session, @session
  plug Spike.Router
end

{:ok, _} = Supervisor.start_link([{Phoenix.PubSub, name: Spike.PubSub}, Spike.Endpoint], strategy: :one_for_one)
IO.puts("speccy canvas spike on http://127.0.0.1:#{port}, editing #{spec_dir}")
unless System.get_env("NO_HALT"), do: Process.sleep(:infinity)
