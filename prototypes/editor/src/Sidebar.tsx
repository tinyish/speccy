import { useState } from 'react'
import { useApp, glyph, track, type App } from './store'
import {
  applyStates, componentUsed, findInst, findItem, iface, itemsOf, modelUsed, moveInstance, nameOf, renameComponent, renameModel,
  type Inst, type Item, type Kind, type Rec, type Spec,
} from './spec'

const TABS: [Kind, string, string][] = [['screens', 'Screens', '▭'], ['components', 'Components', '❖'], ['data', 'Data', '⛁']]
const BASE = { screens: 'Screen', components: 'Component', data: 'Model' }

export const nextName = (spec: Spec, kind: Kind, base: string) => {
  let n = 1
  while (findItem(spec, kind, `${base} ${n}`)) n++
  return `${base} ${n}`
}

// Renames an item of the active tab and everything that refers to it; false if the name can't be used.
export function renameItem(app: App, from: string, to: string) {
  const { spec, tab } = app
  to = to.trim()
  if (!to || to === from) return false
  if (findItem(spec, tab, to) || spec.primitives[to]) return app.notify(`${to} is already taken`), false
  if (/[./\\[\]]/.test(to)) return app.notify('Names cannot hold . / \\ [ or ]'), false
  app.edit(s => {
    if (tab === 'components') renameComponent(s, from, to)
    if (tab === 'data') renameModel(s, from, to)
    if (tab === 'screens') (findItem(s, 'screens', from) as Item).screen = to
  })
  if (app.sel.item === from) app.select(to)
  return true
}

export function Sidebar({ onTab }: { onTab: (k: Kind) => void }) {
  const app = useApp()
  const { spec, tab, sel } = app
  const [renaming, setRenaming] = useState<string | null>(null)

  const create = () => {
    const name = nextName(spec, tab, BASE[tab])
    app.edit(s => {
      if (tab === 'screens') s.screens.push({ screen: name, device: 'mobile', layout: 'column', children: [] })
      if (tab === 'components') s.components.push({ component: name, layout: 'column', children: [] })
      if (tab === 'data') s.data.push({ data: name, fields: { id: 'text' }, operations: [] })
    })
    app.select(name)
  }

  const remove = (name: string) => {
    if (tab === 'components' && componentUsed(spec, name)) return app.notify(`${name} is used; remove its instances first`)
    if (tab === 'data' && modelUsed(spec, name)) return app.notify(`${name} is used; remove its references first`)
    app.edit(s => { const list = itemsOf(s, tab); list.splice(list.findIndex(x => nameOf(x) === name), 1) })
    if (sel.item === name) app.select(null)
  }

  const item = sel.item && tab !== 'data' ? findItem(spec, tab, sel.item) as Item | undefined : undefined
  return (
    <>
      <nav className="rail">
        {TABS.map(([k, label, icon]) => (
          <button key={k} className={tab === k ? 'on' : ''} onClick={() => onTab(k)} title={label}>
            <span className="ri">{icon}</span>{label}
          </button>
        ))}
      </nav>
      <aside className="items">
        <div className="items-head">
          <span>{TABS.find(t => t[0] === tab)![1]}</span>
          <button className="icon" title="New" onClick={create}>+</button>
        </div>
        <div className="items-list">
          {itemsOf(spec, tab).map(x => {
            const name = nameOf(x)
            return (
              <div key={name} className={`item ${sel.item === name ? 'sel' : ''}`} onClick={() => app.select(name)} onDoubleClick={() => setRenaming(name)}>
                <span className="ico">{TABS.find(t => t[0] === tab)![2]}</span>
                {renaming === name
                  ? <input autoFocus defaultValue={name} onBlur={e => { setRenaming(null); renameItem(app, name, e.target.value) }}
                      onKeyDown={e => { if (e.key === 'Enter') e.currentTarget.blur(); if (e.key === 'Escape') setRenaming(null) }} />
                  : <span className="nm">{name}</span>}
                {app.errorItems.has(`${tab}/${name}`) && <span className="dot" title="Has checker errors" />}
                <button className="icon del" title="Delete" onClick={e => { e.stopPropagation(); remove(name) }}>×</button>
              </div>
            )
          })}
        </div>
        {item && <Layers item={item} />}
      </aside>
    </>
  )
}

// The selected item's instance tree, once for the base and once per state, as each state leaves it.
function Layers({ item }: { item: Item }) {
  const app = useApp()
  const name = nameOf(item)
  const states: (string | null)[] = [null, ...Object.keys(item.states ?? {})]

  let last: { parent: string | null; index: number; line?: React.CSSProperties; into?: React.CSSProperties } | null = null
  // Drags a layer to before/after another, or into one that holds children.
  const drag = (e: React.PointerEvent, id: string) => track(e, 4, (x, y) => {
    const t = target(x, y, id)
    app.setDrag({ label: id, x, y, line: t?.line, into: t?.into })
  }, moved => {
    app.setDrag(null)
    const t = moved && last
    if (!t) return
    app.edit(s => { moveInstance(findItem(s, app.tab, name) as Item, id, t.parent, t.index) })
  })
  const target = (x: number, y: number, id: string) => {
    last = null
    const row = document.elementFromPoint(x, y)?.closest<HTMLElement>('.layer')
    if (!row) return null
    const tid = row.dataset.id!
    const dragged = findInst(item, id)!.inst
    if (findInst({ children: [dragged] }, tid)) return null // into itself
    const hit = findInst(item, tid)!
    const r = row.getBoundingClientRect()
    const slots = iface(app.spec, hit.inst.use)?.slots
    const list = hit.parent ? hit.parent.children! : item.children!
    const at = list.indexOf(hit.inst)
    const indent = r.left + Number(row.dataset.depth) * 14 + 24
    if (slots && y > r.top + r.height / 3 && y < r.bottom - r.height / 3) {
      last = { parent: tid, index: hit.inst.children?.length ?? 0, into: { left: r.left + 2, top: r.top, width: r.width - 4, height: r.height } }
    } else {
      const after = y > r.top + r.height / 2
      last = { parent: hit.parent?.id ?? null, index: at + (after ? 1 : 0), line: { left: indent, top: (after ? r.bottom : r.top) - 1, width: r.right - indent - 4, height: 2 } }
    }
    return last
  }

  return (
    <div className="layers">
      <div className="items-head"><span>Layers</span></div>
      <div className="layers-list">
        {states.map(st => {
          const over = st ? applyStates(item, [st]) : {}
          const on = app.sel.state === st
          return (
            <div key={st ?? ''} className="lgroup" data-group={st ?? 'Base'}>
              <div className={`lgroup-head ${on && !app.sel.inst ? 'sel' : ''}`} onClick={() => app.select(name, null, st)}>{st ?? 'Base'}</div>
              <Tree list={item.children ?? []} depth={0} st={st} over={over} name={name} drag={drag} />
            </div>
          )
        })}
      </div>
    </div>
  )
}

function Tree({ list, depth, st, over, name, drag }: { list: Inst[]; depth: number; st: string | null; over: Rec<Rec<unknown>>; name: string; drag: (e: React.PointerEvent, id: string) => void }) {
  const app = useApp()
  return list.map(i => {
    const hidden = (over[i.id]?.hidden ?? i.hidden) === true
    const sel = app.sel.inst === i.id && app.sel.state === st
    return (
      <div key={i.id}>
        <div className={`layer ${sel ? 'sel' : ''} ${hidden ? 'dim' : ''}`} data-id={i.id} data-depth={depth} style={{ paddingLeft: 12 + depth * 14 }}
          onPointerDown={e => { app.select(name, i.id, st); drag(e, i.id) }}>
          <span className="ico">{glyph(i.use)}</span><span className="nm">{i.id}</span><span className="use">{i.use}</span>
        </div>
        {i.children && <Tree list={i.children} depth={depth + 1} st={st} over={over} name={name} drag={drag} />}
      </div>
    )
  })
}
