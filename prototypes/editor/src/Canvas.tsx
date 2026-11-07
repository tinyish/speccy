import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode, type Ref } from 'react'
import { useApp, glyph, track, PRIMS } from './store'
import {
  applyStates, comps, DEVICES, findInst, findItem, iface, insertInstance, itemsOf, moveInstance, nameOf, newInst, setField, usesDeep,
  type Box, type Inst, type Item, type Layout, type Model, type Rec,
} from './spec'
import { renameItem } from './Sidebar'

type Val = { v?: unknown; bound?: string }
type Env = Rec<Val>
// A frame's context: which item and state it draws, and that state's overrides.
type FrameCtx = { owner: string; state: string | null; over: Rec<Rec<unknown>> }

export const LAYOUT_TOOLS = ['@row', '@column', '@stack', '@grid']
const DEFAULT_TOOLS = ['|', ...LAYOUT_TOOLS, '|', 'text', 'button', 'input']
const readTools = (): string[] => { try { return JSON.parse(localStorage.getItem('speccy.toolbar')!) ?? DEFAULT_TOOLS } catch { return DEFAULT_TOOLS } }
const toolUse = (t: string): [string, Partial<Inst>] =>
  t === '@grid' ? ['container', { layout: 'grid', columns: 2 }] : t.startsWith('@') ? ['container', { layout: t.slice(1) as Layout }] : [t, {}]
const toolName = (t: string) => (t.startsWith('@') ? t[1].toUpperCase() + t.slice(2) : t)

export function Canvas() {
  const app = useApp()
  const { spec, tab, view, setView } = app
  const vp = useRef<HTMLDivElement>(null)
  const space = useRef(false)
  const viewRef = useRef(view)
  viewRef.current = view
  const [tools, setToolsState] = useState(readTools)
  const [palette, setPalette] = useState(false)
  const setTools = (t: string[]) => {
    setToolsState(t)
    try { localStorage.setItem('speccy.toolbar', JSON.stringify(t)) } catch { /* the toolbar is a convenience */ }
  }

  const fit = () => {
    const el = vp.current
    if (!el) return
    const v = viewRef.current, box = el.getBoundingClientRect()
    const rects = [...el.querySelectorAll('.frame')].map(f => f.getBoundingClientRect())
    if (!rects.length) return
    const x0 = (Math.min(...rects.map(r => r.left)) - box.left - v.x) / v.z, y0 = (Math.min(...rects.map(r => r.top)) - box.top - v.y) / v.z
    const x1 = (Math.max(...rects.map(r => r.right)) - box.left - v.x) / v.z, y1 = (Math.max(...rects.map(r => r.bottom)) - box.top - v.y) / v.z
    const z = Math.min(1, (box.width - 120) / (x1 - x0), (box.height - 200) / (y1 - y0))
    setView(() => ({ z, x: (box.width - (x1 - x0) * z) / 2 - x0 * z, y: 70 - y0 * z }))
  }
  const item = app.sel.item && tab !== 'data' ? (findItem(spec, tab, app.sel.item) as Item | undefined) : undefined
  useEffect(() => { requestAnimationFrame(fit) }, [tab, app.sel.item, item?.device])

  useEffect(() => {
    const el = vp.current!
    const onWheel = (e: WheelEvent) => {
      e.preventDefault()
      if (e.ctrlKey || e.metaKey) {
        // Pinch arrives as ctrl+wheel with small deltas; a mouse notch is ~100, capped so one notch is ~15%.
        const d = Math.max(-50, Math.min(50, e.deltaY))
        const r = el.getBoundingClientRect(), px = e.clientX - r.left, py = e.clientY - r.top
        setView(v => {
          const z = Math.min(8, Math.max(0.05, v.z * Math.exp(-d * 0.003)))
          return { z, x: px - (px - v.x) * (z / v.z), y: py - (py - v.y) * (z / v.z) }
        })
      } else {
        const dx = e.deltaX, dy = e.deltaY
        setView(v => ({ ...v, x: v.x - dx, y: v.y - dy }))
      }
    }
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea, select')) return
      if (e.code === 'Space') { space.current = e.type === 'keydown'; el.classList.toggle('grab', space.current); e.preventDefault() }
      if (e.type === 'keydown' && e.shiftKey && e.code === 'Digit1') fit()
      if (e.type === 'keydown' && e.shiftKey && e.code === 'Digit0') {
        const r = el.getBoundingClientRect(), cx = r.width / 2, cy = r.height / 2
        setView(v => ({ z: 1, x: cx - (cx - v.x) / v.z, y: cy - (cy - v.y) / v.z }))
      }
    }
    el.addEventListener('wheel', onWheel, { passive: false })
    window.addEventListener('keydown', onKey)
    window.addEventListener('keyup', onKey)
    return () => { el.removeEventListener('wheel', onWheel); window.removeEventListener('keydown', onKey); window.removeEventListener('keyup', onKey) }
  }, [])

  // Pans on middle-drag or space+drag; returns true if it took the pointer.
  const pan = (e: React.PointerEvent) => {
    if (e.button !== 1 && !space.current) return false
    e.preventDefault()
    e.stopPropagation()
    let lx = e.clientX, ly = e.clientY
    track(e, 0, (x, y) => {
      // The deltas are taken now: setView's updater runs later, after lx/ly have moved on.
      const dx = x - lx, dy = y - ly
      lx = x; ly = y
      setView(v => ({ ...v, x: v.x + dx, y: v.y + dy }))
    }, () => {})
    return true
  }

  // Where a drag would land: a slot in a frame (with its index), a spot in the toolbar, or nowhere.
  type Target = { item: string; parent: string | null; index: number; line: CSSProperties } | { tool: number; line: CSSProperties } | null
  const target = (x: number, y: number, moving?: string): Target => {
    const el = document.elementFromPoint(x, y)
    if (!el) return null
    const bar = el.closest('.toolbar')
    if (bar) {
      if (moving) return null
      const tiles = [...bar.querySelectorAll<HTMLElement>('[data-ti]')]
      const rects = tiles.map(t => t.getBoundingClientRect())
      const at = rects.findIndex(r => x < r.left + r.width / 2)
      const edge = at < 0 ? (rects.at(-1)?.right ?? bar.getBoundingClientRect().left) + 1 : rects[at].left - 2
      const br = bar.getBoundingClientRect()
      return { tool: at < 0 ? tools.length : Number(tiles[at].dataset.ti), line: { left: edge, top: br.top + 6, width: 2, height: br.height - 12 } }
    }
    const slot = el.closest<HTMLElement>('[data-slot]')
    if (!slot || (moving && slot.closest(`[data-inst="${moving}"]`))) return null
    const frame = slot.closest<HTMLElement>('[data-frame]')!
    const layout = slot.dataset.layout
    const kids = [...slot.querySelectorAll<HTMLElement>(':scope > [data-index]')]
    const rects = kids.map(k => k.getBoundingClientRect())
    const row = layout === 'row' || layout === 'grid'
    let at = rects.findIndex(r => (layout === 'grid' ? y < r.top || (y < r.bottom && x < r.left + r.width / 2) : row ? x < r.left + r.width / 2 : y < r.top + r.height / 2))
    if (at < 0) at = kids.length
    const index = at < kids.length ? Number(kids[at].dataset.index) : kids.length ? Number(kids.at(-1)!.dataset.index) + 1 : 0
    const sr = slot.getBoundingClientRect()
    const near = rects[at] ?? rects.at(-1)
    const line: CSSProperties = row
      ? { left: near ? (at < rects.length ? near.left - 3 : near.right + 1) : sr.left + 4, top: near ? near.top : sr.top + 4, width: 2, height: near ? near.height : sr.height - 8 }
      : { left: sr.left + 4, top: near ? (at < rects.length ? near.top - 3 : near.bottom + 1) : sr.top + 4, width: sr.width - 8, height: 2 }
    return { item: frame.dataset.frame!, parent: slot.dataset.slot || null, index, line }
  }

  const insertTool = (tool: string, itemName: string, parent: string | null, index: number) => {
    const [use, init] = toolUse(tool)
    if (tab === 'components' && comps(spec)[use] && (use === itemName || usesDeep(spec, use).has(itemName)))
      return app.notify(`${itemName} can't contain ${use}: a component can't contain itself`)
    let id = ''
    app.edit(s => { id = insertInstance(s, findItem(s, tab, itemName) as Item, parent, index, use, init) })
    app.select(itemName, id, app.sel.state)
  }

  // Inserts into the selection's container: inside it if it holds children, else after it.
  const insertAtSelection = (tool: string) => {
    if (!item) return app.notify('Select a screen or component first')
    const hit = app.sel.inst ? findInst(item, app.sel.inst) : undefined
    if (!hit) return insertTool(tool, nameOf(item), null, item.children?.length ?? 0)
    if (iface(spec, hit.inst.use)?.slots) return insertTool(tool, nameOf(item), hit.inst.id, hit.inst.children?.length ?? 0)
    const list = hit.parent ? hit.parent.children! : item.children!
    insertTool(tool, nameOf(item), hit.parent?.id ?? null, list.indexOf(hit.inst) + 1)
  }

  // Drags a tool (from the toolbar or the palette) or an instance (moving it).
  const drag = (e: React.PointerEvent, src: { tool: string; from: number | 'palette' } | { move: string }, threshold: number, onClick?: () => void, onStart?: () => void) => {
    let last: Target = null, started = false
    const label = 'tool' in src ? toolName(src.tool) : src.move
    track(e, threshold, (x, y) => {
      if (!started) { started = true; onStart?.() }
      last = target(x, y, 'move' in src ? src.move : undefined)
      app.setDrag({ label, x, y, line: last?.line, remove: 'tool' in src && src.from !== 'palette' && !last })
    }, moved => {
      app.setDrag(null)
      if (!moved) return onClick?.()
      if (last && 'tool' in last && 'tool' in src) {
        const t = tools.filter((x, i) => (src.from === 'palette' ? x !== src.tool : i !== src.from))
        const before = tools.slice(0, last.tool).filter((x, i) => (src.from === 'palette' ? x !== src.tool : i !== src.from)).length
        return setTools([...t.slice(0, before), src.tool, ...t.slice(before)])
      }
      if (last && 'item' in last) {
        const t = last
        if ('tool' in src) return insertTool(src.tool, t.item, t.parent, t.index)
        let ok = true
        app.edit(s => { ok = moveInstance(findItem(s, tab, t.item) as Item, src.move, t.parent, t.index) })
        return ok ? undefined : app.notify("An instance can't move inside itself")
      }
      if ('tool' in src && src.from !== 'palette') setTools(tools.filter((_, i) => i !== src.from))
    })
  }

  const states = item ? [null, ...Object.keys(item.states ?? {})] : []
  return (
    <div className="viewport" ref={vp} onMouseDown={e => { if (e.button === 1) e.preventDefault() }}
      onPointerDown={e => { if (!pan(e) && item) app.select(nameOf(item)) }}>
      <div className="world" style={{ transform: `translate(${view.x}px, ${view.y}px) scale(${view.z})`, ['--iz' as string]: 1 / view.z }}>
        {tab === 'data'
          ? spec.data.map(m => <ModelFrame key={m.data} m={m} />)
          : item && states.map(st => <Frame key={st ?? ''} item={item} state={st} pan={pan} drag={drag} />)}
      </div>
      {tab !== 'data' && (
        <div className="toolbar" onPointerDown={e => e.stopPropagation()}>
          <button className="tile" data-tool="search" title="Search components" onClick={() => setPalette(true)}><Icon tool="search" /></button>
          {tools.map((t, i) => {
            if (t === '|') return tools[i - 1] === '|' || i === tools.length - 1 ? null : <div key={i} className="tdiv" data-ti={i} />
            if (!PRIMS.includes(t) && !LAYOUT_TOOLS.includes(t) && !comps(spec)[t]) return null
            return <div key={i} className="tile" data-ti={i} data-tool={t} title={toolName(t)} onPointerDown={e => drag(e, { tool: t, from: i }, 0)}><Icon tool={t} /></div>
          })}
        </div>
      )}
      {palette && <Palette onClose={() => setPalette(false)} pick={insertAtSelection} drag={drag} />}
    </div>
  )
}

function Icon({ tool }: { tool: string }) {
  const p = { width: 16, height: 16, viewBox: '0 0 16 16', fill: 'none', stroke: 'currentColor', strokeWidth: 1.2 }
  if (tool === 'search') return <svg {...p}><circle cx="7" cy="7" r="4.5" /><path d="M10.5 10.5L14 14" /></svg>
  if (tool === '@row') return <svg {...p}><rect x="1.5" y="4" width="3.5" height="8" rx="1" /><rect x="6.25" y="4" width="3.5" height="8" rx="1" /><rect x="11" y="4" width="3.5" height="8" rx="1" /></svg>
  if (tool === '@column') return <svg {...p}><rect x="4" y="1.5" width="8" height="3.5" rx="1" /><rect x="4" y="6.25" width="8" height="3.5" rx="1" /><rect x="4" y="11" width="8" height="3.5" rx="1" /></svg>
  if (tool === '@stack') return <svg {...p}><rect x="2" y="2" width="8" height="8" rx="1" /><rect x="6" y="6" width="8" height="8" rx="1" /></svg>
  if (tool === '@grid') return <svg {...p}><rect x="2" y="2" width="5" height="5" rx="1" /><rect x="9" y="2" width="5" height="5" rx="1" /><rect x="2" y="9" width="5" height="5" rx="1" /><rect x="9" y="9" width="5" height="5" rx="1" /></svg>
  if (tool === 'text') return <svg {...p}><path d="M3 3.5h10M8 3.5V13" /></svg>
  if (tool === 'button') return <svg {...p}><rect x="1.5" y="4.5" width="13" height="7" rx="2.5" /><path d="M5.5 8h5" /></svg>
  if (tool === 'input') return <svg {...p}><rect x="1.5" y="4.5" width="13" height="7" rx="1.5" /><path d="M4.5 6.5v3" /></svg>
  if (PRIMS.includes(tool)) return <span className="tglyph">{glyph(tool)}</span>
  // A composed component: Figma's four-diamond component mark.
  return <svg {...p} fill="currentColor" stroke="none"><path d="M8 1l2.2 2.2L8 5.4 5.8 3.2zM8 10.6l2.2 2.2L8 15l-2.2-2.2zM3.2 5.8l2.2 2.2-2.2 2.2L1 8zM12.8 5.8L15 8l-2.2 2.2L10.6 8z" /></svg>
}

function Palette({ onClose, pick, drag }: {
  onClose: () => void; pick: (tool: string) => void
  drag: (e: React.PointerEvent, src: { tool: string; from: 'palette' }, threshold: number, onClick?: () => void, onStart?: () => void) => void
}) {
  const app = useApp()
  const [q, setQ] = useState('')
  const [hi, setHi] = useState(0)
  const all = [...LAYOUT_TOOLS, ...PRIMS, ...app.spec.components.map(c => c.component!)]
  const list = all.filter(t => toolName(t).toLowerCase().includes(q.toLowerCase()))
  const choose = (t: string) => { onClose(); pick(t) }
  return (
    <div className="modal" onPointerDown={e => { e.stopPropagation(); if (e.target === e.currentTarget) onClose() }}>
      <div className="palette">
        <input className="in pal-q" autoFocus placeholder="Search components" value={q} onChange={e => { setQ(e.target.value); setHi(0) }}
          onKeyDown={e => {
            if (e.key === 'ArrowDown') { e.preventDefault(); setHi(h => Math.min(list.length - 1, h + 1)) }
            if (e.key === 'ArrowUp') { e.preventDefault(); setHi(h => Math.max(0, h - 1)) }
            if (e.key === 'Enter' && list[hi]) choose(list[hi])
            if (e.key === 'Escape') onClose()
          }} />
        <div className="pal-list">
          {list.map((t, i) => {
            const [use, init] = toolUse(t)
            return (
              <div key={t} className={`pal-row ${i === hi ? 'hi' : ''}`} data-tool={t} onMouseEnter={() => setHi(i)}
                onPointerDown={e => drag(e, { tool: t, from: 'palette' }, 4, () => choose(t), onClose)}>
                <div className="pal-prev"><div className="pal-scale">
                  <Node inst={newInst(app.spec, 'preview', use, init)} ctx={{ owner: '', state: null, over: {} }} env={{}} stack={[]} parent="column" own={false} />
                </div></div>
                <span className="pal-name">{toolName(t)}</span>
                <span className="muted">{t.startsWith('@') ? 'layout' : PRIMS.includes(t) ? 'primitive' : 'component'}</span>
              </div>
            )
          })}
          {!list.length && <div className="muted pal-empty">Nothing matches</div>}
        </div>
      </div>
    </div>
  )
}

function ModelFrame({ m }: { m: Model }) {
  const app = useApp()
  const selected = app.sel.item === m.data
  return (
    <div className="frame-wrap" data-frame={m.data}>
      <div className={`frame-title ${selected ? 'sel' : ''}`}>{m.data}</div>
      <div className={`frame model ${selected ? 'sel' : ''}`} onPointerDown={e => { e.stopPropagation(); app.select(m.data) }}>
        <div className="mc-head">Fields</div>
        {Object.entries(m.fields).map(([f, t]) => <div key={f} className="mc-row"><span>{f}</span><span className="muted">{t}</span></div>)}
        <div className="mc-head">Operations</div>
        {m.operations.map(o => <div key={o} className="mc-row"><span>{o}()</span></div>)}
        {!m.operations.length && <div className="mc-row muted">none</div>}
      </div>
    </div>
  )
}

const rootStyle = (item: Item): CSSProperties => {
  if (item.screen) { const [w, h] = DEVICES[item.device ?? 'mobile']; return { ...boxStyle(item), width: w, height: h, overflow: 'hidden' } }
  const fixedW = typeof item.width === 'number'
  return { ...boxStyle(item), width: fixedW ? item.width : 'max-content', minWidth: fixedW ? undefined : 320, height: typeof item.height === 'number' ? item.height : undefined }
}

function Frame({ item, state, pan, drag }: {
  item: Item; state: string | null; pan: (e: React.PointerEvent) => boolean
  drag: (e: React.PointerEvent, src: { move: string }, threshold: number) => void
}) {
  const app = useApp()
  const name = nameOf(item)
  const [renaming, setRenaming] = useState(false)
  const [menu, setMenu] = useState(false)
  const ctx: FrameCtx = { owner: name, state, over: state ? applyStates(item, [state]) : {} }
  const selected = app.sel.state === state && !app.sel.inst
  const pick = (e: React.PointerEvent) => {
    if (pan(e)) return
    e.stopPropagation()
    const hit = (e.target as Element).closest<HTMLElement>('[data-inst]')?.dataset.inst ?? null
    app.select(name, hit, state)
    if (hit) drag(e, { move: hit }, 4)
  }
  const device = item.device ?? 'mobile'
  const layout = item.layout ?? 'column'
  return (
    <div className="frame-wrap" data-frame={name} data-state={state ?? ''}>
      <div className={`frame-title ${selected ? 'sel' : ''}`} onPointerDown={e => { if (!pan(e)) { e.stopPropagation(); app.select(name, null, state) } }}>
        {state ? <span className="ft-name">{state}</span>
          : renaming ? <input className="ft-input" autoFocus defaultValue={name} onBlur={e => { setRenaming(false); renameItem(app, name, e.target.value) }}
              onKeyDown={e => { if (e.key === 'Enter') e.currentTarget.blur(); if (e.key === 'Escape') setRenaming(false) }} />
          : <span className="ft-name" title="Rename" onClick={() => setRenaming(true)}>{name}</span>}
        {item.screen && <span className="ft-size" onClick={() => !state && setMenu(!menu)}>{device[0].toUpperCase() + device.slice(1)} {DEVICES[device].join('×')}</span>}
        {menu && (
          <div className="menu" onMouseLeave={() => setMenu(false)}>
            {Object.entries(DEVICES).map(([d, [w, h]]) => (
              <div key={d} className={`menu-item ${d === device ? 'on' : ''}`} onClick={() => { setMenu(false); app.edit(s => { (findItem(s, 'screens', name) as Item).device = d as Item['device'] }) }}>
                {d[0].toUpperCase() + d.slice(1)} <span className="muted">{w}×{h}</span>
              </div>
            ))}
          </div>
        )}
      </div>
      <div className={`frame ${selected ? 'sel' : ''}`} style={rootStyle(item)} data-slot="" data-layout={layout} onPointerDown={pick}>
        {(item.children ?? []).map((inst, i) => <Node key={inst.id} inst={inst} index={i} ctx={ctx} env={{}} stack={[name]} parent={layout} />)}
      </div>
    </div>
  )
}

const resolve = (path: string, env: Env): Val => {
  const [root, ...rest] = path.split('.')
  const e = env[root]
  if (!e) return { bound: path }
  if (e.bound) return { bound: [e.bound, ...rest].join('.') }
  return rest.length ? { bound: path } : e
}

const place = (a = 'top-left') => {
  const v = a.startsWith('top') ? 'start' : a.startsWith('bottom') ? 'end' : 'center'
  const h = a.endsWith('left') ? 'start' : a.endsWith('right') ? 'end' : 'center'
  return [v, h]
}

// CSS for a box that holds children; unset, it's a top-left column with gap and padding of 8.
export function boxStyle(b: Box): CSSProperties {
  const layout = b.layout ?? 'column'
  const [v, h] = place(b.align)
  const p = b.padding ?? 8
  const s: CSSProperties = {
    padding: Array.isArray(p) ? p.map(n => `${n}px`).join(' ') : p,
    gap: b.gap === 'auto' ? 0 : b.gap ?? 8,
    overflow: b.clip ? 'hidden' : undefined,
  }
  if (layout === 'row' || layout === 'column') {
    const row = layout === 'row'
    return { ...s, display: 'flex', flexDirection: layout, flexWrap: row && b.wrap ? 'wrap' : 'nowrap', justifyContent: b.gap === 'auto' ? 'space-between' : row ? h : v, alignItems: row ? v : h, alignContent: v }
  }
  return { ...s, display: 'grid', gridTemplateColumns: layout === 'grid' ? `repeat(${b.columns ?? 2}, minmax(0, 1fr))` : undefined, justifyItems: h, alignItems: v, alignContent: v }
}

// CSS for an instance's width and height inside a parent with `parent` layout.
function sizeStyle(x: Inst, parent: Layout): CSSProperties {
  const s: CSSProperties = { minWidth: x.minWidth, maxWidth: x.maxWidth, minHeight: x.minHeight, maxHeight: x.maxHeight }
  const main = parent === 'row' ? 'width' : parent === 'column' ? 'height' : null
  for (const k of ['width', 'height'] as const) {
    const v = x[k]
    const min = k === 'width' ? 'minWidth' : 'minHeight'
    if (typeof v === 'number') { s[k] = v; if (k === main) s.flexShrink = 0 }
    else if (v === 'fill') {
      // Width splits the space evenly (basis 0); height keeps an auto basis because a column with auto
      // height would collapse a 0-basis child to nothing (so fill in a hugging parent hugs).
      if (k === main) { s.flex = k === 'width' ? '1 1 0' : '1 1 auto'; s[min] ??= 0 }
      else if (main || k === 'height') s.alignSelf = 'stretch' // the cross axis of a flex box, or a grid cell's height
      else s.justifySelf = 'stretch'
    } else if (k === main) s.flexShrink = 0
  }
  if (parent === 'stack') s.gridArea = '1 / 1'
  return s
}

type NodeProps = { inst: Inst; index?: number; ctx: FrameCtx; env: Env; stack: string[]; parent: Layout; own?: boolean; copy?: number; elRef?: Ref<HTMLDivElement> }

// One instance as a wireframe. `own` instances belong to the frame's item and are selectable; a
// composed component's insides are drawn with own=false so a click lands on the instance itself.
function Node(props: NodeProps) {
  const { inst, index, ctx, env, stack, parent, copy, elRef, own = true } = props
  const app = useApp()
  if (inst.repeat && copy === undefined) return <Repeat {...props} />
  const o = own ? ctx.over[inst.id] ?? {} : {}
  const x = { ...inst, ...o } as Inst // layout fields with this frame's state applied
  if (x.hidden === true) return null
  const val = (p: string): Val => (p in o ? { v: o[p] } : inst.bind?.[p] ? resolve(inst.bind[p], env) : { v: inst.props?.[p] })
  const show = (v: Val, fallback = '') => (v.bound ? <span className="bound">{`{${v.bound}}`}</span> : String(v.v ?? fallback))
  const selected = own && !copy && app.sel.item === ctx.owner && app.sel.state === ctx.state && app.sel.inst === inst.id
  const inner = x.layout ?? 'column'
  const kids = (list: Inst[] | undefined, nextEnv: Env, nextStack: string[], nextOwn: boolean, l: Layout) =>
    (list ?? []).map((c, i) => <Node key={c.id} inst={c} index={i} ctx={ctx} env={nextEnv} stack={nextStack} parent={l} own={nextOwn} />)
  const attrs = own ? { 'data-inst': inst.id, 'data-index': index } : {}
  const slot = own && !copy ? inst.id : undefined
  const handles = selected && (typeof x.width === 'number' || typeof x.height === 'number') ? <Handles x={x} ctx={ctx} /> : null
  const cls = (c: string) => `n ${c} ${selected ? 'sel' : ''}`
  const style = sizeStyle(x, parent)
  const use = inst.use

  if (use === 'container' || use === 'list' || use === 'form')
    return <div ref={elRef} {...attrs} className={cls(`n-${use}`)} style={{ ...style, ...boxStyle(x) }} data-slot={slot} data-layout={inner}>{kids(inst.children, env, stack, own, inner)}{handles}</div>
  if (use === 'dialog') {
    if (val('open').v !== true) return <div ref={elRef} {...attrs} className={cls('n-dialog')} style={style}><span className="chip">{glyph('dialog')} dialog · {inst.id}</span></div>
    return (
      <div ref={elRef} {...attrs} className={cls('n-dialog open')} style={style}>
        <span className="tag">dialog</span>
        <div className="dlg-body" style={boxStyle(x)} data-slot={slot} data-layout={inner}>{kids(inst.children, env, stack, own, inner)}</div>
        {handles}
      </div>
    )
  }
  const c = comps(app.spec)[use]
  if (!PRIMS.includes(use)) {
    if (!c) return <div ref={elRef} {...attrs} className={cls('n-comp')} style={style}><span className="chip bad">? {use}</span></div>
    if (stack.includes(use)) return <div ref={elRef} {...attrs} className={cls('n-comp')} style={style}><span className="chip bad">↻ {use}</span></div>
    const next: Env = {}
    for (const t of Object.keys(c.props ?? {})) { const v = val(t); if (v.bound || v.v !== undefined) next[t] = v }
    const l = c.layout ?? 'column'
    // The instance is the component's root box; its own width/height win over the root's.
    const size = sizeStyle({ ...x, width: x.width ?? c.width, height: x.height ?? c.height }, parent)
    return <div ref={elRef} {...attrs} className={cls('n-comp')} style={{ ...boxStyle(c), ...size }}>{kids(c.children, next, [...stack, use], false, l)}{handles}</div>
  }

  let body: ReactNode
  let k = `n-${use}`
  if (use === 'text') body = show(val('text'))
  else if (use === 'button' || use === 'link') { body = show(val('text'), use === 'button' ? 'Button' : 'Link'); if (val('disabled').v === true) k += ' disabled' }
  else if (use === 'input' && ['checkbox', 'radio'].includes(String(val('type').v))) {
    k = `n-${val('type').v}`
    body = val('checked').v === true ? '✓' : '' // a bound checkbox is drawn empty: no room for {path}
  } else if (use === 'input' || use === 'textarea') {
    const value = val('value'), ph = val('placeholder')
    body = value.v !== undefined || value.bound ? show(value) : <span className="ph">{show(ph)}</span>
  } else if (use === 'select') {
    const value = val('value'), opts = val('options')
    body = <>{value.v !== undefined || value.bound ? show(value) : opts.bound ? show(opts) : String((opts.v as string[] | undefined)?.[0] ?? '')}<span className="chev">⌄</span></>
  }
  return <div ref={elRef} {...attrs} className={cls(k)} style={style}>{body}{handles}</div>
}

// A repeat draws its `limit` copies, or as many as fit its container along the container's direction.
function Repeat(props: NodeProps) {
  const limit = props.inst.repeat!.limit
  const [n, setN] = useState(3)
  const first = useRef<HTMLDivElement>(null)
  useLayoutEffect(() => {
    const el = first.current, box = el?.parentElement
    if (limit || !el || !box) return
    const cs = getComputedStyle(box)
    if (cs.display !== 'flex' || cs.flexWrap === 'wrap') return
    const row = cs.flexDirection === 'row'
    const size = (e: HTMLElement) => (row ? e.offsetWidth : e.offsetHeight)
    const kids = [...box.children].filter(c => getComputedStyle(c).position !== 'absolute') as HTMLElement[]
    const gap = parseFloat(row ? cs.columnGap : cs.rowGap) || 0
    const avail = row ? box.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight) : box.clientHeight - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom)
    const used = kids.reduce((t, c) => t + size(c), 0) + gap * (kids.length - 1)
    const step = size(el) + gap
    if (step <= 0) return
    const next = Math.max(1, Math.min(50, n + Math.floor((avail - used) / step)))
    if (next !== n) setN(next)
  })
  return Array.from({ length: limit ?? n }, (_, c) => <Node key={c} {...props} copy={c} elRef={c === 0 ? first : undefined} />)
}

// Drag handles on the selected instance's fixed sides; dragging writes the new number on release.
function Handles({ x, ctx }: { x: Inst; ctx: FrameCtx }) {
  const app = useApp()
  const start = (e: React.PointerEvent, keys: ('width' | 'height')[]) => {
    e.stopPropagation()
    const el = (e.currentTarget as HTMLElement).parentElement!
    const z = app.view.z, from = { width: el.offsetWidth, height: el.offsetHeight }
    const sx = e.clientX, sy = e.clientY
    const size = (k: 'width' | 'height', px: number, py: number) => Math.max(1, Math.round(from[k] + (k === 'width' ? px - sx : py - sy) / z))
    let px = sx, py = sy
    track(e, 0, (mx, my) => {
      px = mx; py = my
      for (const k of keys) el.style[k] = `${size(k, px, py)}px` // live, without an edit per pixel
    }, () => app.edit(s => {
      const it = findItem(s, app.tab, ctx.owner) as Item
      for (const k of keys) setField(it, ctx.state, x.id, k, size(k, px, py))
    }))
  }
  const w = typeof x.width === 'number', h = typeof x.height === 'number'
  return <>
    {w && <span className="handle hw" title="Drag to resize" onPointerDown={e => start(e, ['width'])} />}
    {h && <span className="handle hh" title="Drag to resize" onPointerDown={e => start(e, ['height'])} />}
    {w && h && <span className="handle hwh" title="Drag to resize" onPointerDown={e => start(e, ['width', 'height'])} />}
  </>
}
