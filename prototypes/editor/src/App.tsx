import { useEffect, useRef, useState } from 'react'
import { AppCtx, type App as AppT, type DragUI, type Sel, type View } from './store'
import { deleteInstance, findInst, findItem, itemsOf, nameOf, pathOf, setField, tidy, type Item, type Kind, type Spec } from './spec'
import { Sidebar } from './Sidebar'
import { Canvas } from './Canvas'
import { Panel } from './Panel'

const KINDS: Kind[] = ['screens', 'components', 'data']
const files = (s: Spec) => new Map(KINDS.flatMap(k => itemsOf(s, k).map(x => [pathOf(k, nameOf(x)), JSON.stringify(tidy(x))] as const)))

// The item an error from check.mjs is about ("data Task: …" or "TaskRow: …").
export function errorItem(spec: Spec, e: string): { kind: Kind; name: string } | null {
  if (e.startsWith('data ')) return { kind: 'data', name: e.slice(5, e.indexOf(':')) }
  const name = e.slice(0, e.indexOf(':'))
  if (findItem(spec, 'screens', name)) return { kind: 'screens', name }
  if (findItem(spec, 'components', name)) return { kind: 'components', name }
  return null
}

export default function App() {
  const [spec, setSpec] = useState<Spec | null>(null)
  const [errors, setErrors] = useState<string[]>([])
  const [tab, setTab] = useState<Kind>('components')
  const [sel, setSel] = useState<Sel>({ item: null, inst: null, state: null })
  const [status, setStatus] = useState('Saved')
  const [notice, setNotice] = useState('')
  const [errorsOpen, setErrorsOpen] = useState(false)
  const [view, setView] = useState<View>({ x: 40, y: 60, z: 1 })
  const [drag, setDrag] = useState<DragUI>(null)
  const cur = useRef<Spec | null>(null)
  const saved = useRef(new Map<string, string>())
  const undo = useRef<Spec[]>([])
  const redo = useRef<Spec[]>([])
  const timer = useRef(0)
  const noticeTimer = useRef(0)

  const notify = (msg: string) => {
    setNotice(msg)
    clearTimeout(noticeTimer.current)
    noticeTimer.current = window.setTimeout(() => setNotice(''), 3500)
  }
  const commit = (s: Spec) => { cur.current = s; setSpec(s) }

  const load = async () => {
    const r = await fetch('/api/spec').then(r => r.json())
    if (r.error) return notify(r.error)
    const { errors, ...s } = r
    commit(s)
    saved.current = files(s)
    setErrors(errors)
  }

  const save = async () => {
    const now = files(cur.current!)
    const writes: { path: string; content?: unknown; delete?: boolean }[] = []
    // Deletes go first so a rename that only changes case survives a case-insensitive disk.
    for (const p of saved.current.keys()) if (!now.has(p)) writes.push({ path: p, delete: true })
    for (const [p, t] of now) if (saved.current.get(p) !== t) writes.push({ path: p, content: JSON.parse(t) })
    if (!writes.length) return setStatus('Saved')
    saved.current = now
    try {
      const r = await fetch('/api/spec', { method: 'POST', body: JSON.stringify(writes) }).then(r => r.json())
      if (r.error) throw new Error(r.error)
      setErrors(r.errors)
      setStatus('Saved')
    } catch (e) {
      setStatus('Save failed')
      notify(String(e))
    }
  }
  const schedule = () => {
    setStatus('Saving…')
    clearTimeout(timer.current)
    timer.current = window.setTimeout(save, 300)
  }
  const edit = (fn: (s: Spec) => void) => {
    const prev = cur.current!
    const next = structuredClone(prev)
    fn(next)
    undo.current.push(prev)
    redo.current = []
    commit(next)
    schedule()
  }
  const step = (from: Spec[], to: Spec[]) => {
    const s = from.pop()
    if (!s) return
    to.push(cur.current!)
    commit(s)
    schedule()
  }

  useEffect(() => {
    load()
    // An outside edit (say, a coding agent's) replaces the spec; undo history would overwrite it, so it goes.
    import.meta.hot?.on('spec-changed', () => { undo.current = []; redo.current = []; load() })
  }, [])

  const item = spec && sel.item ? findItem(spec, tab, sel.item) : undefined
  const select = (item: string | null, inst: string | null = null, state: string | null = null) => setSel({ item, inst, state })

  // The canvas shows one item, so one is always selected while there are any.
  useEffect(() => {
    if (spec && !item) setSel({ item: itemsOf(spec, tab)[0] ? nameOf(itemsOf(spec, tab)[0]) : null, inst: null, state: null })
  }, [spec, tab, item])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea, select')) return
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') {
        e.preventDefault()
        return e.shiftKey ? step(redo.current, undo.current) : step(undo.current, redo.current)
      }
      if (!item || tab === 'data') return
      const name = sel.item!
      const it = item as Item
      if (e.key === 'Escape') select(name, sel.inst ? findInst(it, sel.inst)?.parent?.id ?? null : null, sel.inst ? sel.state : null)
      if ((e.key === 'Delete' || e.key === 'Backspace') && sel.inst) {
        e.preventDefault()
        const { inst: id, state } = sel
        // In a state's frame, Delete hides the instance in that state instead of removing it.
        if (state) edit(s => setField(findItem(s, tab, name) as Item, state, id, 'hidden', true))
        else { edit(s => deleteInstance(findItem(s, tab, name) as Item, id)); select(name) }
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  if (!spec) return <div className="loading">{notice || 'Loading…'}</div>

  const errorItems = new Set(errors.map(e => { const x = errorItem(spec, e); return x ? `${x.kind}/${x.name}` : '' }))
  // A state that no longer exists (renamed or deleted) falls back to the base.
  const liveSel = { ...sel, state: sel.state && (item as Item | undefined)?.states?.[sel.state] ? sel.state : null }
  const app: AppT = { spec, tab, sel: liveSel, select, edit, notify, errorItems, view, setView, setDrag }

  return (
    <AppCtx.Provider value={app}>
      <div className="app">
        <header className="topbar">
          <span className="logo">speccy</span>
          <span className="crumb">{tab[0].toUpperCase() + tab.slice(1)}</span>
          <span className="notice">{notice}</span>
          <span className="zoom">{Math.round(view.z * 100)}%</span>
          <span className="status">{status}</span>
          <button className={`badge ${errors.length ? 'bad' : ''}`} onClick={() => setErrorsOpen(o => !o)} title="Checker errors">
            {errors.length ? `${errors.length} error${errors.length > 1 ? 's' : ''}` : 'No errors'}
          </button>
          {errorsOpen && errors.length > 0 && (
            <div className="errors" onMouseLeave={() => setErrorsOpen(false)}>
              {errors.map(e => (
                <div key={e} className="error" onClick={() => {
                  const x = errorItem(spec, e)
                  if (x) { setTab(x.kind); select(x.name) }
                  setErrorsOpen(false)
                }}>{e}</div>
              ))}
            </div>
          )}
        </header>
        <div className="main">
          <Sidebar onTab={k => { setTab(k); select(null) }} />
          <Canvas />
          <Panel />
        </div>
        {drag && <div className={`drag-ghost ${drag.remove ? 'remove' : ''}`} style={{ left: drag.x + 10, top: drag.y + 10 }}>{drag.remove ? `Remove ${drag.label}` : drag.label}</div>}
        {drag?.line && <div className="drop-line" style={drag.line} />}
        {drag?.into && <div className="drop-into" style={drag.into} />}
      </div>
    </AppCtx.Provider>
  )
}
