import { useEffect, useMemo, useRef, useState } from 'react'
import type { Node } from './render'
import { Canvas } from './Canvas'
import { Panel } from './Panel'

export type PropType = string | string[]
export type Primitive = {
  name: string; about: string; category: string; element: string
  props: Record<string, PropType>; events: Record<string, PropType | null>; children: boolean
  states: Record<string, Record<string, unknown>>; examples?: Record<string, Record<string, unknown>>; defaults: Record<string, unknown>; render: Node
  sources: Record<string, { name: string; url: string }[]>
}
export type Values = Record<string, unknown>
// A PUT either writes the file or says why it didn't.
export type SaveResult = { rejected?: string[]; error?: string }

const CATEGORIES = ['actions', 'inputs', 'selection', 'navigation', 'feedback', 'overlays', 'containment', 'data-display', 'layout', 'media']
const parse = (text: string): Primitive | null => { try { return JSON.parse(text) } catch { return null } }
const errorName = (e: string) => e.slice(0, e.indexOf(':'))

export default function App() {
  const [texts, setTexts] = useState<Record<string, string> | null>(null)
  const [errors, setErrors] = useState<string[]>([])
  const [sel, setSel] = useState<string | null>(null)
  const [q, setQ] = useState('')
  const [errorsOpen, setErrorsOpen] = useState(false)
  const [notice, setNotice] = useState('')
  const [preview, setPreview] = useState<{ name: string | null; values: Values }>({ name: null, values: {} })
  // Bumped on every outside change, so the panel drops a stale definition draft.
  const [outside, setOutside] = useState(0)
  const noticeTimer = useRef(0)
  const notify = (msg: string) => {
    setNotice(msg)
    clearTimeout(noticeTimer.current)
    noticeTimer.current = window.setTimeout(() => setNotice(''), 4000)
  }

  const load = async () => {
    const r = await fetch('/api/primitives').then(r => r.json())
    if (r.error) return notify(r.error)
    setTexts(Object.fromEntries(r.primitives.map((p: { name: string; text: string }) => [p.name, p.text])))
    setErrors(r.errors)
  }
  useEffect(() => {
    load()
    import.meta.hot?.on('primitives-changed', () => { setOutside(n => n + 1); load() })
  }, [])

  const save = async (name: string, content: Primitive): Promise<SaveResult> => {
    try {
      const r = await fetch(`/api/primitive/${encodeURIComponent(name)}`, { method: 'PUT', body: JSON.stringify(content) }).then(r => r.json())
      if (r.rejected || r.error) return r
      setTexts(t => ({ ...t, [name]: r.text }))
      setErrors(r.errors)
      return {}
    } catch (e) {
      notify(String(e))
      return { error: String(e) }
    }
  }

  const prims = useMemo(() => Object.fromEntries(Object.entries(texts ?? {}).map(([n, t]) => [n, parse(t)])), [texts])
  const bad = useMemo(() => new Set(errors.map(errorName)), [errors])
  const names = Object.keys(prims)
  const groups = [...CATEGORIES, 'other'].map(c => ({
    c,
    names: names.filter(n => (CATEGORIES.includes(prims[n]?.category ?? '') ? prims[n]!.category === c : c === 'other') && n.includes(q.trim().toLowerCase())),
  })).filter(g => g.names.length)
  const ordered = groups.flatMap(g => g.names)

  // One primitive is always selected while there are any.
  useEffect(() => { if (texts && (!sel || !(sel in texts))) setSel(ordered[0] ?? null) }, [texts, sel])

  if (!texts) return <div className="loading">{notice || 'Loading…'}</div>
  const prim = sel ? prims[sel] : null
  const values = preview.name === sel ? preview.values : {}
  const setValues = (v: Values) => setPreview({ name: sel, values: v })

  return (
    <div className="app">
      <header className="topbar">
        <span className="logo">speccy showcase</span>
        <span className="crumb" data-testid="count">{names.length} primitives</span>
        <span className="notice">{notice}</span>
        <button className={`badge ${errors.length ? 'bad' : ''}`} onClick={() => setErrorsOpen(o => !o)} title="Validation errors">
          {errors.length ? `${errors.length} error${errors.length > 1 ? 's' : ''}` : 'No errors'}
        </button>
        {errorsOpen && errors.length > 0 && (
          <div className="errors" onMouseLeave={() => setErrorsOpen(false)}>
            {errors.map(e => (
              <div key={e} className="error" onClick={() => { setSel(errorName(e)); setErrorsOpen(false) }}>{e}</div>
            ))}
          </div>
        )}
      </header>
      <div className="main">
        <aside className="items">
          <div className="items-head"><span>Primitives</span><span className="muted">{ordered.length}</span></div>
          <input className="in search" placeholder="Search" aria-label="search" value={q} onChange={e => setQ(e.target.value)} />
          <div className="items-list">
            {groups.map(g => (
              <div key={g.c} className="lgroup">
                <div className="lgroup-head">{g.c}</div>
                {g.names.map(n => (
                  <div key={n} className={`item ${n === sel ? 'sel' : ''}`} data-name={n} onClick={() => setSel(n)}>
                    <span className="nm">{n}</span>
                    {bad.has(n) && <span className="dot" title="Has validation errors" />}
                  </div>
                ))}
              </div>
            ))}
          </div>
        </aside>
        <Canvas prim={prim} name={sel} values={values} />
        {sel && (
          <Panel key={sel} name={sel} prim={prim} text={texts[sel]} errors={errors.filter(e => errorName(e) === sel)}
            values={values} setValues={setValues} save={save} outside={outside} />
        )}
      </div>
    </div>
  )
}
