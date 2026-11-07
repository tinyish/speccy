import { useEffect, useState, type ReactNode } from 'react'
import { useApp } from './store'
import {
  deleteState, fileScope, findInst, findItem, iface, instScope, nameOf, paths, renameInstance, renameKey, renameModel, renameOp, renameState, setField,
  allIds, DEVICES, FIELD_KEYS, type Action, type Inst, type Item, type Layout, type Model, type PropType, type Rec, type Spec,
} from './spec'
import { renameItem } from './Sidebar'

const fresh = (taken: object, base: string) => { let n = '', i = 1; while (base + n in taken) n = String(++i); return base + n }
const literalDefault = (t: string): unknown => (t === 'bool' ? false : t === 'number' ? 0 : '')

export function Field({ value, onCommit, placeholder, multiline, label }: { value: string; onCommit: (v: string) => void; placeholder?: string; multiline?: boolean; label?: string }) {
  const [v, setV] = useState(value)
  useEffect(() => setV(value), [value])
  const commit = () => { if (v !== value) onCommit(v) }
  const common = { value: v, placeholder, 'aria-label': label, onChange: (e: { target: { value: string } }) => setV(e.target.value), onBlur: commit }
  return multiline
    ? <textarea className="in" rows={2} {...common} />
    : <input className="in" {...common} onKeyDown={e => { if (e.key === 'Enter') e.currentTarget.blur(); if (e.key === 'Escape') { setV(value); e.currentTarget.blur() } }} />
}

function Section({ title, add, children }: { title: string; add?: () => void; children: ReactNode }) {
  const [open, setOpen] = useState(true)
  return (
    <section className="sec">
      <div className="sec-head" onClick={() => setOpen(!open)}>
        <span className="caret">{open ? '▾' : '▸'}</span>{title}
        {add && <button className="icon" title={`Add to ${title}`} onClick={e => { e.stopPropagation(); add() }}>+</button>}
      </div>
      {open && <div className="sec-body">{children}</div>}
    </section>
  )
}

function Seg<T extends string>({ options, value, onChange, required }: { options: T[]; value: T | undefined; onChange: (v: T | undefined) => void; required?: boolean }) {
  return (
    <div className="seg">
      {options.map(o => <button key={o} data-seg={o} className={value === o ? 'on' : ''} onClick={() => onChange(value === o && !required ? undefined : o)}>{o}</button>)}
    </div>
  )
}

function Select({ value, options, onChange, none, label, disabled }: { value: string; options: string[]; onChange: (v: string) => void; none?: string; label?: string; disabled?: boolean }) {
  return (
    <select className="in" value={value} aria-label={label} disabled={disabled} onChange={e => onChange(e.target.value)}>
      {none !== undefined && <option value="">{none}</option>}
      {!options.includes(value) && value && <option value={value}>{value}</option>}
      {options.map(o => <option key={o} value={o}>{o}</option>)}
    </select>
  )
}

function TypePicker({ value, onChange, none }: { value: string | null; onChange: (v: string | null) => void; none?: boolean }) {
  const { spec } = useApp()
  const list = !!value?.endsWith('[]')
  const base = value?.replace(/\[\]$/, '') ?? ''
  return (
    <>
      <Select value={base} options={['text', 'bool', 'number', ...spec.data.map(d => d.data)]} none={none ? 'none' : undefined} label="type"
        onChange={v => onChange(v ? v + (list ? '[]' : '') : null)} />
      <button className={`tog ${list ? 'on' : ''}`} title="List of these" disabled={value === null} onClick={() => onChange(list ? base : base + '[]')}>[ ]</button>
    </>
  )
}

// Editable name+type rows over a record that keeps its key order.
function Entries({ title, rec, onChange, base, none }: { title: string; rec: Rec<string | null>; onChange: (r: Rec<string | null>) => void; base: string; none?: boolean }) {
  const app = useApp()
  return (
    <Section title={title} add={() => onChange({ ...rec, [fresh(rec, base)]: none ? null : 'text' })}>
      {Object.entries(rec).map(([k, t]) => (
        <div key={k} className="row">
          <Field value={k} label={`${title} name`} onCommit={v => {
            if (!v || v in rec) return app.notify(`${v || 'An empty name'} can't be used`)
            onChange(renameKey(rec, k, v))
          }} />
          <TypePicker value={t} none={none} onChange={v => onChange({ ...rec, [k]: v })} />
          <button className="icon" title="Remove" onClick={() => { const r = { ...rec }; delete r[k]; onChange(r) }}>×</button>
        </div>
      ))}
      {!Object.keys(rec).length && <div className="muted small">None</div>}
    </Section>
  )
}

export function Panel() {
  const app = useApp()
  const { spec, tab, sel } = app
  const x = sel.item ? findItem(spec, tab, sel.item) : undefined
  let content: ReactNode = <div className="hint">Select a {tab === 'data' ? 'model' : tab === 'screens' ? 'screen' : 'component'} or a layer.</div>
  if (x && tab === 'data') content = <ModelPanel m={x as Model} />
  else if (x) {
    const item = x as Item
    const inst = sel.inst ? findInst(item, sel.inst)?.inst : undefined
    content = inst ? <><InstPanel item={item} inst={inst} state={sel.state} /><Interactions item={item} inst={inst} /></>
      : sel.state ? <StatePanel item={item} state={sel.state} />
      : <ItemPanel item={item} />
  }
  return <aside className="panel">{content}</aside>
}

// Edits the selected item of the active tab inside an app edit.
const useEd = (name: string) => {
  const app = useApp()
  return (fn: (it: Item, s: Spec) => void) => app.edit(s => fn(findItem(s, app.tab, name) as Item, s))
}

const NumField = ({ value, placeholder, label, onCommit }: { value: unknown; placeholder?: string; label: string; onCommit: (n: number | undefined) => void }) => (
  <Field value={typeof value === 'number' ? String(value) : ''} placeholder={placeholder} label={label} onCommit={v => {
    if (!v.trim()) return onCommit(undefined)
    const n = Number(v)
    if (!isNaN(n) && n >= 0) onCommit(n)
  }} />
)

const LAYOUTS: Layout[] = ['row', 'column', 'stack', 'grid']
const ALIGNS = ['top-left', 'top', 'top-right', 'left', 'center', 'right', 'bottom-left', 'bottom', 'bottom-right']
// The pixel size an element is drawn at, for switching it to fixed.
const measure = (sel: string, k: 'width' | 'height') => {
  const el = document.querySelector<HTMLElement>(sel)
  return el ? (k === 'width' ? el.offsetWidth : el.offsetHeight) : 100
}

// Figma's auto layout panel: flow, resizing, alignment, gap, padding and clip, over get/set of one box.
function LayoutSection({ get, set, mark, box, sizing, inState, at }: {
  get: (k: string) => unknown; set: (k: string, v: unknown) => void; mark: (k: string) => ReactNode
  box: boolean; sizing: 'all' | 'wh' | null; inState: boolean; at: string
}) {
  const [minMax, setMinMax] = useState(false)
  const p = get('padding') as number | number[] | undefined
  const [perSide, setPerSide] = useState(Array.isArray(p) && p.length === 4)
  const flag = (b: boolean) => (inState ? b : b || undefined) // a state needs an explicit false to undo the base
  const layout = (get('layout') as Layout | undefined) ?? 'column'
  const [t, r, b, l] = p === undefined ? [8, 8, 8, 8] : typeof p === 'number' ? [p, p, p, p] : p.length === 2 ? [p[0], p[1], p[0], p[1]] : p
  const pad = (t: number, r: number, b: number, l: number) => set('padding', t === r && r === b && b === l ? t : t === b && r === l ? [t, r] : [t, r, b, l])
  const gap = get('gap')
  const align = (get('align') as string | undefined) ?? 'top-left'
  const size = (k: 'width' | 'height', label: string) => {
    const v = get(k)
    const mode = typeof v === 'number' ? 'fixed' : v === 'fill' ? 'fill' : 'hug'
    const hug = inState ? 'hug' : undefined
    return (
      <div className="row" data-size={k}>
        <label>{label}</label>
        <NumField value={v} placeholder={mode === 'fill' ? 'Fill' : 'Hug'} label={k} onCommit={n => set(k, n ?? hug)} />
        <select className="in sm" aria-label={`${k} mode`} value={mode}
          onChange={e => set(k, e.target.value === 'fixed' ? measure(at, k) : e.target.value === 'fill' ? 'fill' : hug)}>
          <option value="hug">Hug</option><option value="fill">Fill</option><option value="fixed">Fixed</option>
        </select>
        {mark(k)}
      </div>
    )
  }
  const num = (k: string, label: string) => (
    <div className="row" key={k}><label>{label}</label><NumField value={get(k)} label={k} onCommit={n => set(k, n)} />{mark(k)}</div>
  )
  return (
    <Section title="Layout">
      {box && <div className="row"><label>Flow</label><Seg required options={LAYOUTS} value={layout} onChange={v => v && set('layout', v)} />{mark('layout')}</div>}
      {box && layout === 'row' && <div className="row"><label>Wrap</label><input type="checkbox" aria-label="wrap" checked={get('wrap') === true} onChange={e => set('wrap', flag(e.target.checked))} />{mark('wrap')}</div>}
      {box && layout === 'grid' && <div className="row"><label>Columns</label><NumField value={get('columns')} placeholder="2" label="columns" onCommit={n => set('columns', n || undefined)} />{mark('columns')}</div>}
      {sizing && <>{size('width', 'W')}{size('height', 'H')}</>}
      {sizing === 'all' && <button className={`tog wide ${minMax ? 'on' : ''}`} title="Min and max sizes" onClick={() => setMinMax(!minMax)}>Min / max</button>}
      {sizing === 'all' && minMax && [num('minWidth', 'Min W'), num('maxWidth', 'Max W'), num('minHeight', 'Min H'), num('maxHeight', 'Max H')]}
      {box && <>
        <div className="row"><label>Align</label>
          <div className="align">
            {ALIGNS.map(a => <button key={a} title={a} data-align={a} className={align === a ? 'on' : ''} onClick={() => set('align', a === 'top-left' && !inState ? undefined : a)}><i /></button>)}
          </div>{mark('align')}
        </div>
        <div className="row"><label>Gap</label>
          <NumField value={gap} placeholder={gap === 'auto' ? 'Auto' : '8'} label="gap" onCommit={n => set('gap', n)} />
          <button className={`tog ${gap === 'auto' ? 'on' : ''}`} title="Space between" onClick={() => set('gap', gap === 'auto' ? undefined : 'auto')}>Auto</button>{mark('gap')}
        </div>
        <div className="row"><label>Padding</label>
          {perSide
            ? <div className="sides">{(['top', 'right', 'bottom', 'left'] as const).map((side, i) => (
                <NumField key={side} value={[t, r, b, l][i]} label={`padding ${side}`} onCommit={n => { const s = [t, r, b, l]; s[i] = n ?? 0; pad(s[0], s[1], s[2], s[3]) }} />))}</div>
            : <><span className="pre">↔</span><NumField value={r} label="padding horizontal" onCommit={n => pad(t, n ?? 0, b, n ?? 0)} />
                <span className="pre">↕</span><NumField value={t} label="padding vertical" onCommit={n => pad(n ?? 0, r, n ?? 0, l)} /></>}
          <button className={`tog ${perSide ? 'on' : ''}`} title="Padding per side" onClick={() => setPerSide(!perSide)}>⊞</button>{mark('padding')}
        </div>
        <div className="row"><label>Clip</label><input type="checkbox" aria-label="clip content" checked={get('clip') === true} onChange={e => set('clip', flag(e.target.checked))} /><span className="muted">Clip content</span>{mark('clip')}</div>
      </>}
    </Section>
  )
}

function ItemPanel({ item }: { item: Item }) {
  const app = useApp()
  const name = nameOf(item)
  const ed = useEd(name)
  const ops = app.spec.data.flatMap(d => d.operations.map(o => `${d.data}.${o}`))
  const addState = () => { const n = fresh(item.states ?? {}, 'state'); ed(it => { it.states = { ...it.states, [n]: { about: '' } } }); app.select(name, null, n) }
  return (
    <>
      <Section title={item.screen ? 'Screen' : 'Component'}>
        <div className="row"><label>Name</label><Field value={name} label="name" onCommit={v => renameItem(app, name, v)} /></div>
        <div className="row col"><label>About</label><Field multiline label="about" value={item.about ?? ''} onCommit={v => ed(it => { it.about = v })} /></div>
        {item.screen && <div className="row"><label>Device</label><Select value={item.device ?? 'mobile'} options={Object.keys(DEVICES)} label="device" onChange={v => ed(it => { it.device = v as Item['device'] })} /></div>}
      </Section>
      <LayoutSection get={k => (item as Rec<unknown>)[k]} set={(k, v) => ed(it => { const r = it as Rec<unknown>; if (v === undefined) delete r[k]; else r[k] = v })}
        mark={() => null} box sizing={item.component ? 'wh' : null} inState={false} at={`[data-frame="${CSS.escape(name)}"][data-state=""] .frame`} />
      {item.component && <>
        <Entries title="Props" base="value" rec={item.props ?? {}} onChange={r => ed(it => { it.props = r as Rec<string> })} />
        <Entries title="Events" base="event" none rec={item.events ?? {}} onChange={r => ed(it => { it.events = r })} />
        <Entries title="Local" base="local" rec={item.local ?? {}} onChange={r => ed(it => { it.local = r as Rec<string> })} />
      </>}
      {item.screen && (
        <Section title="Data" add={() => ed(it => { it.data = { ...it.data, [fresh(it.data ?? {}, 'data')]: { type: 'text' } } })}>
          {Object.entries(item.data ?? {}).map(([k, d]) => (
            <div key={k} className="row wrap">
              <Field value={k} label="data name" onCommit={v => { if (v && !(v in item.data!)) ed(it => { it.data = renameKey(it.data!, k, v) }) }} />
              <TypePicker value={d.type} onChange={v => ed(it => { it.data![k].type = v! })} />
              <button className="icon" title="Remove" onClick={() => ed(it => { delete it.data![k] })}>×</button>
              <div className="row sub"><label>from</label>
                <Select value={d.from ?? ''} options={ops} none="—" label="from" onChange={v => ed(it => { if (v) it.data![k].from = v; else delete it.data![k].from })} />
              </div>
            </div>
          ))}
        </Section>
      )}
      <Section title="States" add={addState}>
        {Object.entries(item.states ?? {}).map(([s, st]) => (
          <div key={s} className="state-link" onClick={() => app.select(name, null, s)}><b>{s}</b> <span className="muted">{st.about}</span></div>
        ))}
        {!Object.keys(item.states ?? {}).length && <div className="muted small">No states. Each state is a frame on the canvas.</div>}
      </Section>
    </>
  )
}

function StatePanel({ item, state }: { item: Item; state: string }) {
  const app = useApp()
  const name = nameOf(item)
  const ed = useEd(name)
  const st = item.states![state]
  const names = Object.keys(item.states!)
  const i = names.indexOf(state)
  const move = (d: number) => ed(it => {
    const e = Object.entries(it.states!)
    if (i + d < 0 || i + d >= e.length) return
    ;[e[i], e[i + d]] = [e[i + d], e[i]]
    it.states = Object.fromEntries(e)
  })
  const add = () => { const n = fresh(item.states!, 'state'); ed(it => { it.states = { ...it.states, [n]: { about: '' } } }); app.select(name, null, n) }
  return (
    <>
      <Section title="State" add={add}>
        <div className="row"><label>Name</label><Field value={state} label="state name" onCommit={v => {
          if (!v || v in item.states!) return app.notify(`${v || 'An empty name'} can't be used`)
          ed(it => renameState(it, state, v))
          app.select(name, null, v)
        }} /></div>
        <div className="row col"><label>About</label><Field multiline label="state about" placeholder="When does this state apply?" value={st.about} onCommit={v => ed(it => { it.states![state].about = v })} /></div>
        <div className="row">
          <label>Order</label>
          <button className="icon" title="Move earlier (applies first)" onClick={() => move(-1)}>↑</button>
          <button className="icon" title="Move later" onClick={() => move(1)}>↓</button>
          <span className="grow" />
          <button className="tog danger" onClick={() => { ed(it => deleteState(it, state)); app.select(name) }}>Delete state</button>
        </div>
      </Section>
      <Section title="Overrides">
        {Object.entries(st.set ?? {}).map(([k, v]) => (
          <div key={k} className="override"><span className="mark" />{k} = {JSON.stringify(v)}
            <button className="icon" title="Reset to base" onClick={() => ed(it => { delete it.states![state].set![k] })}>↺</button>
          </div>
        ))}
        {!Object.keys(st.set ?? {}).length && <div className="muted small">Select an instance in this frame and change it to override it here.</div>}
      </Section>
    </>
  )
}

function InstPanel({ item, inst, state }: { item: Item; inst: Inst; state: string | null }) {
  const app = useApp()
  const { spec } = app
  const name = nameOf(item)
  const ed = useEd(name)
  const id = inst.id
  const edI = (fn: (i: Inst, it: Item) => void) => ed(it => fn(findInst(it, id)!.inst, it))
  const i = iface(spec, inst.use)
  const tset = state ? item.states?.[state]?.set ?? {} : {}
  const value = (k: string) => (`${id}.${k}` in tset ? tset[`${id}.${k}`] : FIELD_KEYS.includes(k) ? (inst as Rec<unknown>)[k] : inst.props?.[k])
  const setF = (k: string, v: unknown) => ed(it => setField(it, state, id, k, v))
  const mark = (k: string) => `${id}.${k}` in tset
    ? <><span className="mark" title={`Set by ${state}`} /><button className="icon reset" title="Reset to base" onClick={() => setF(k, undefined)}>↺</button></>
    : null
  const scope = instScope(spec, item, id)
  const listPaths = paths(spec, instScope(spec, item, id, false)).filter(([, t]) => t.endsWith('[]')).map(([p]) => p)

  return (
    <>
      {state && <div className="state-banner">Editing <b>{state}</b>: changes go to its overrides</div>}
      <Section title="Instance">
        <div className="row"><label>id</label>{state ? <span className="ro">{id}</span> : <Field value={id} label="instance id" onCommit={v => {
          if (!/^[A-Za-z_][\w-]*$/.test(v) || allIds(item).includes(v)) return app.notify(`${v || 'An empty id'} can't be used`)
          ed(it => renameInstance(it, id, v))
          app.select(name, v)
        }} />}</div>
        <div className="row"><label>use</label><span className="ro">{inst.use}</span></div>
        <div className="row"><label>Hidden</label><input type="checkbox" aria-label="hidden" checked={value('hidden') === true} onChange={e => setF('hidden', state ? e.target.checked : e.target.checked || undefined)} />{mark('hidden')}</div>
      </Section>
      <LayoutSection get={value} set={setF} mark={mark} box={!!i?.slots} sizing="all" inState={!!state}
        at={`[data-frame="${CSS.escape(name)}"][data-state="${CSS.escape(state ?? '')}"] [data-inst="${CSS.escape(id)}"]`} />
      <Section title="Props">
        {Object.entries(i?.props ?? {}).filter(([p]) => p !== 'hidden').map(([p, t]) => propRow(p, t))}
        {!Object.keys(i?.props ?? {}).length && <div className="muted small">No props</div>}
      </Section>
      {!state && (
        <Section title="Repeat" add={inst.repeat || !listPaths.length ? undefined : () => edI(x => { x.repeat = { each: listPaths[0], as: 'item' } })}>
          {inst.repeat ? (
            <>
              <div className="row"><label>each</label><Select value={inst.repeat.each} options={listPaths} label="repeat each" onChange={v => edI(x => { x.repeat!.each = v })} />
                <button className="icon" title="Stop repeating" onClick={() => edI(x => { delete x.repeat })}>×</button></div>
              <div className="row"><label>as</label><Field value={inst.repeat.as} label="repeat as" onCommit={v => v && edI(x => { x.repeat!.as = v })} /></div>
              <div className="row"><label>limit</label><NumField value={inst.repeat.limit} placeholder="As many as fit" label="repeat limit"
                onCommit={n => edI(x => { if (n) x.repeat!.limit = Math.round(n); else delete x.repeat!.limit })} /></div>
            </>
          ) : <div className="muted small">{listPaths.length ? 'Not repeated' : 'No lists in scope'}</div>}
        </Section>
      )}
    </>
  )

  function propRow(p: string, t: PropType) {
    const bound = inst.bind?.[p]
    const enumT = Array.isArray(t)
    const literalOk = enumT || ['text', 'bool', 'number'].includes((t as string).replace(/\[\]$/, ''))
    const options = enumT ? [] : paths(spec, scope).filter(([, pt]) => pt === t).map(([x]) => x)
    const binding = (bound !== undefined && !(`${id}.${p}` in tset)) || !literalOk
    const v = value(p)
    const control = binding
      ? <Select value={bound ?? ''} options={options} none="—" label={`${p} binding`} disabled={!!state}
          onChange={x => edI(y => { if (y.props) delete y.props[p]; if (x) (y.bind ??= {})[p] = x; else if (y.bind) delete y.bind[p] })} />
      : enumT ? <Select value={String(v ?? '')} options={t} none="—" label={p} onChange={x => setF(p, x || undefined)} />
      : t === 'bool' ? <input type="checkbox" aria-label={p} checked={v === true} onChange={e => setF(p, state ? e.target.checked : e.target.checked || undefined)} />
      : t === 'number' ? <NumField value={v} label={p} onCommit={n => setF(p, n)} />
      : (t as string).endsWith('[]') ? <Field value={((v as unknown[]) ?? []).join(', ')} label={p} placeholder="a, b, c" onCommit={x => setF(p, x ? x.split(',').map(s => s.trim()) : undefined)} />
      : <Field value={String(v ?? '')} label={p} onCommit={x => setF(p, x || undefined)} />
    return (
      <div key={p} className="row prop" data-prop={p}>
        <label title={JSON.stringify(t)}>{p}</label>
        {control}
        {!enumT && literalOk && !state && (
          <button className={`tog bind ${binding ? 'on' : ''}`} title={options.length ? 'Bind to data' : 'Nothing of this type in scope'} disabled={!binding && !options.length}
            onClick={() => edI(y => {
              if (binding) { if (y.bind) delete y.bind[p] } else { if (y.props) delete y.props[p]; (y.bind ??= {})[p] = options[0] }
            })}>{'{ }'}</button>
        )}
        {mark(p)}
      </div>
    )
  }
}

const KINDS = ['set', 'enter', 'exit', 'emit', 'call', 'reload'] as const

function Interactions({ item, inst }: { item: Item; inst: Inst }) {
  const app = useApp()
  const { spec } = app
  const name = (item.component ?? item.screen)!
  const ed = useEd(name)
  const events = iface(spec, inst.use)?.events ?? {}
  const states = Object.keys(item.states ?? {})
  const local = item.local ?? {}
  const emits = item.events ?? {}
  const ops = spec.data.flatMap(d => d.operations.map(o => `${d.data}.${o}`))
  const loaded = Object.entries(item.data ?? {}).filter(([, d]) => d.from).map(([k]) => k)

  return (
    <Section title="Interactions">
      {!Object.keys(events).length && <div className="muted small">{inst.use} fires no events</div>}
      {Object.entries(events).map(([ev, payload]) => {
        const key = `${inst.id}.${ev}`
        const acts = item.on?.[key] ?? []
        const hscope = payload ? { ...fileScope(item), event: payload } : fileScope(item)
        const pathsOfType = (t?: string) => paths(spec, hscope).filter(([, pt]) => !t || pt === t).map(([p]) => p)
        const edA = (fn: (list: Action[]) => void) => ed(it => { it.on ??= {}; fn((it.on[key] ??= [])) })
        const fresh = (k: (typeof KINDS)[number]): Action | null => {
          if (k === 'set') { const l = Object.keys(local)[0]; return l ? { set: { [l]: literalDefault(local[l]) } } : null }
          if (k === 'enter' || k === 'exit') return states[0] ? { [k]: states[0] } : null
          if (k === 'emit') { const e = Object.keys(emits)[0]; if (!e) return null; const w = emits[e] ? pathsOfType(emits[e]!)[0] : undefined; return w ? { emit: e, with: w } : { emit: e } }
          if (k === 'call') return ops[0] ? { call: ops[0] } : null
          return loaded[0] ? { reload: loaded[0] } : null
        }
        return (
          <div key={ev} className="event" data-event={ev}>
            <div className="ev-head">
              <span className="ev">{ev}</span>{payload && <span className="muted">carries {payload}</span>}
              <select className="in add" aria-label={`add action to ${ev}`} value="" onChange={e => { const a = fresh(e.target.value as (typeof KINDS)[number]); if (a) edA(l => l.push(a)) }}>
                <option value="">+ action</option>
                {KINDS.map(k => <option key={k} value={k} disabled={!fresh(k)}>{k}</option>)}
              </select>
            </div>
            {acts.map((a, i) => {
              const up = (fn: (a: Action) => void) => edA(l => fn(l[i]))
              const kind = KINDS.find(k => k in a)!
              let body: ReactNode
              if (kind === 'set') {
                const [l, val] = Object.entries(a.set!)[0] ?? ['', '']
                const isRef = typeof val === 'object' && val !== null
                body = <>
                  <Select value={l} options={Object.keys(local)} label="local" onChange={x => up(y => { y.set = { [x]: literalDefault(local[x]) } })} />
                  <span>=</span>
                  <Select value={isRef ? 'event' : 'value'} options={payload ? ['value', 'event'] : ['value']} label="value kind"
                    onChange={x => up(y => { y.set = { [l]: x === 'event' ? { ref: 'event' } : literalDefault(local[l]) } })} />
                  {!isRef && (local[l] === 'bool'
                    ? <input type="checkbox" checked={val === true} onChange={e => up(y => { y.set = { [l]: e.target.checked } })} />
                    : <Field value={String(val ?? '')} label="value" onCommit={x => up(y => { y.set = { [l]: local[l] === 'number' ? Number(x) : x } })} />)}
                </>
              } else if (kind === 'enter' || kind === 'exit') {
                body = <Select value={a[kind]!} options={states} label="state" onChange={x => up(y => { y[kind] = x })} />
              } else if (kind === 'emit') {
                const t = emits[a.emit!]
                body = <>
                  <Select value={a.emit!} options={Object.keys(emits)} label="emit" onChange={x => up(y => { y.emit = x; delete y.with; const w = emits[x] && pathsOfType(emits[x]!)[0]; if (w) y.with = w })} />
                  {t && <><span>with</span><Select value={a.with ?? ''} options={pathsOfType(t)} none="—" label="with" onChange={x => up(y => { if (x) y.with = x; else delete y.with })} /></>}
                </>
              } else if (kind === 'call') {
                body = <>
                  <Select value={a.call!} options={ops} label="operation" onChange={x => up(y => { y.call = x })} />
                  <span>with</span><Select value={a.with ?? ''} options={pathsOfType()} none="—" label="with" onChange={x => up(y => { if (x) y.with = x; else delete y.with })} />
                </>
              } else body = <Select value={a.reload!} options={loaded} label="data" onChange={x => up(y => { y.reload = x })} />
              return (
                <div key={i} className="action">
                  <span className="kind">{kind}</span>{body}
                  <span className="grow" />
                  <button className="icon" title="Move up" onClick={() => edA(l => { if (i > 0) [l[i - 1], l[i]] = [l[i], l[i - 1]] })}>↑</button>
                  <button className="icon" title="Move down" onClick={() => edA(l => { if (i < l.length - 1) [l[i + 1], l[i]] = [l[i], l[i + 1]] })}>↓</button>
                  <button className="icon" title="Remove action" onClick={() => edA(l => { l.splice(i, 1) })}>×</button>
                </div>
              )
            })}
          </div>
        )
      })}
    </Section>
  )
}

function ModelPanel({ m }: { m: Model }) {
  const app = useApp()
  const ed = (fn: (x: Model, s: Spec) => void) => app.edit(s => fn(findItem(s, 'data', m.data) as Model, s))
  return (
    <>
      <Section title="Model">
        <div className="row"><label>Name</label><Field value={m.data} label="model name" onCommit={v => {
          if (!v || findItem(app.spec, 'data', v) || /[.[\]/\\]/.test(v)) return app.notify(`${v || 'An empty name'} can't be used`)
          app.edit(s => renameModel(s, m.data, v))
          app.select(v)
        }} /></div>
      </Section>
      <Entries title="Fields" base="field" rec={m.fields} onChange={r => ed(x => { x.fields = r as Rec<string> })} />
      <Section title="Operations" add={() => ed(x => { x.operations.push(fresh(Object.fromEntries(x.operations.map(o => [o, 1])), 'op')) })}>
        {m.operations.map(o => (
          <div key={o} className="row">
            <Field value={o} label="operation" onCommit={v => { if (v && !m.operations.includes(v)) app.edit(s => renameOp(s, m.data, o, v)) }} />
            <button className="icon" title="Remove" onClick={() => ed(x => { x.operations = x.operations.filter(y => y !== o) })}>×</button>
          </div>
        ))}
        {!m.operations.length && <div className="muted small">None</div>}
      </Section>
    </>
  )
}
