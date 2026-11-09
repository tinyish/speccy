import { useEffect, useRef, useState, type ReactNode } from 'react'
import type { Primitive, PropType, SaveResult, Values } from './App'

const show = (t: PropType | null) => (t === null ? 'none' : Array.isArray(t) ? t.join(' | ') : t)
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b)
const isObj = (v: unknown) => v !== null && typeof v === 'object' && !Array.isArray(v)

const Sec = ({ title, status, children }: { title: string; status?: ReactNode; children: ReactNode }) => (
  <section className="sec" data-sec={title}>
    <div className="sec-head">{title}{status !== undefined && <span className="status">{status}</span>}</div>
    <div className="sec-body">{children}</div>
  </section>
)

type Props = {
  name: string; prim: Primitive | null; text: string; errors: string[]
  values: Values; setValues: (v: Values) => void
  save: (name: string, content: Primitive) => Promise<SaveResult>; outside: number
}

export function Panel({ name, prim, text, errors, values, setValues, save, outside }: Props) {
  // The definition textarea's text while it differs from the file; null shows the file.
  const [draft, setDraft] = useState<string | null>(null)
  const [problems, setProblems] = useState<string[]>([])
  const [status, setStatus] = useState('')
  const timer = useRef(0)

  // An outside change replaces the draft, unless it holds an edit that couldn't be saved.
  useEffect(() => { if (!problems.length) setDraft(null) }, [outside])

  const onDraft = (t: string) => {
    setDraft(t)
    clearTimeout(timer.current)
    let obj: Primitive
    try { obj = JSON.parse(t) } catch (e) { setProblems([String(e instanceof Error ? e.message : e)]); setStatus('Not saved'); return }
    setProblems([])
    setStatus('Saving…')
    timer.current = window.setTimeout(async () => {
      const r = await save(name, obj)
      setProblems(r.rejected ?? (r.error ? [r.error] : []))
      setStatus(r.rejected || r.error ? 'Not saved' : 'Saved')
    }, 400)
  }
  const onTab = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key !== 'Tab') return
    e.preventDefault()
    const el = e.currentTarget, { selectionStart: s, selectionEnd: end, value } = el
    onDraft(value.slice(0, s) + '  ' + value.slice(end))
    requestAnimationFrame(() => el.setSelectionRange(s + 2, s + 2))
  }

  const saveDefault = async (k: string) => {
    if (!prim) return
    const r = await save(name, { ...prim, defaults: { ...prim.defaults, [k]: values[k] } })
    if (r.rejected || r.error) setStatus(`Default not saved: ${(r.rejected ?? [r.error]).join('; ')}`)
    else { setDraft(null); setProblems([]); reset(k) }
  }
  const reset = (k: string) => { const { [k]: _, ...rest } = values; setValues(rest) }

  const props = prim && isObj(prim.props) ? prim.props : {}
  return (
    <aside className="panel">
      {prim && <>
        <Sec title="Info">
          <div className="about">{prim.about}</div>
          <div className="kv"><span>element</span><span className="mono">{prim.element}</span></div>
          <div className="kv"><span>category</span><span>{prim.category}</span></div>
          <div className="kv"><span>children</span><span>{prim.children ? 'yes' : 'no'}</span></div>
          {isObj(prim.sources) && Object.entries(prim.sources).map(([kit, list]) => Array.isArray(list) && list.length > 0 && (
            <div key={kit} className="kv"><span>{kit}</span>
              <div className="links">{list.map(s => <a key={s.url} href={s.url} target="_blank" rel="noreferrer">{s.name}</a>)}</div>
            </div>
          ))}
        </Sec>
        <Sec title="Props">
          {Object.entries(props).map(([k, t]) => {
            const v = k in values ? values[k] : prim.defaults?.[k]
            const changed = k in values && !same(values[k], prim.defaults?.[k])
            return (
              <div key={k} className="prop" data-prop={k}>
                <div className="prop-head">
                  <span className="nm">{k}</span><span className="ty">{show(t)}</span>
                  <button className="tog" disabled={!changed} onClick={() => saveDefault(k)}>save as default</button>
                  <button className="tog" disabled={!(k in values)} onClick={() => reset(k)}>reset</button>
                </div>
                <Control type={t} value={v} label={k} onChange={x => setValues({ ...values, [k]: x })} />
              </div>
            )
          })}
          {!Object.keys(props).length && <div className="muted">No props</div>}
        </Sec>
        <Sec title="States">
          <Overrides sets={prim.states} />
          {!Object.keys(prim.states ?? {}).length && <div className="muted">No states</div>}
        </Sec>
        {isObj(prim.examples) && Object.keys(prim.examples!).length > 0 && <Sec title="Examples"><Overrides sets={prim.examples} /></Sec>}
        <Sec title="Events">
          {Object.entries(prim.events ?? {}).map(([k, t]) => <div key={k} className="event"><span className="nm">{k}</span><span className="ty">{show(t)}</span></div>)}
          {!Object.keys(prim.events ?? {}).length && <div className="muted">No events</div>}
        </Sec>
      </>}
      <Sec title="Definition" status={status}>
        <textarea className={`in def ${problems.length ? 'bad' : ''}`} aria-label="definition" spellCheck={false}
          value={draft ?? text} onChange={e => onDraft(e.target.value)} onKeyDown={onTab} />
        {[...problems, ...(draft === null ? errors : [])].map(p => <div key={p} className="err">{p}</div>)}
      </Sec>
    </aside>
  )
}

// Named sets of prop values: states or examples.
const Overrides = ({ sets }: { sets: Primitive['states'] | undefined }) => Object.entries(sets ?? {}).map(([s, set]) => (
  <div key={s} className="state">
    <div className="nm">{s}</div>
    {Object.entries(set ?? {}).map(([k, v]) => <div key={k} className="override mono">{k}: {JSON.stringify(v)}</div>)}
  </div>
))

// One control per prop type, editing the preview value only.
function Control({ type, value, label, onChange }: { type: PropType; value: unknown; label: string; onChange: (v: unknown) => void }) {
  if (Array.isArray(type)) return (
    <select className="in" aria-label={label} value={String(value ?? '')} onChange={e => onChange(e.target.value)}>
      {type.map(o => <option key={o} value={o}>{o}</option>)}
    </select>
  )
  if (type === 'bool') return <input type="checkbox" className="check" aria-label={label} checked={!!value} onChange={e => onChange(e.target.checked)} />
  if (type === 'number') return <input type="number" className="in" aria-label={label} value={Number.isFinite(value) ? String(value) : ''} onChange={e => { if (e.target.value !== '') onChange(Number(e.target.value)) }} />
  if (type === 'text[]') return <textarea className="in" rows={4} aria-label={label} value={Array.isArray(value) ? value.join('\n') : ''} onChange={e => onChange(e.target.value.split('\n'))} />
  if (type === 'model' || type === 'model[]') return <JsonControl many={type === 'model[]'} value={value} label={label} onChange={onChange} />
  return <input className="in" aria-label={label} value={String(value ?? '')} onChange={e => onChange(e.target.value)} />
}

function JsonControl({ many, value, label, onChange }: { many: boolean; value: unknown; label: string; onChange: (v: unknown) => void }) {
  const pretty = (v: unknown) => JSON.stringify(v, null, 2) ?? ''
  const [text, setText] = useState(() => pretty(value))
  const [error, setError] = useState('')
  // Follows the value when it changes from outside (reset, a new default), not while typing.
  useEffect(() => { try { if (!same(JSON.parse(text), value)) setText(pretty(value)) } catch { setText(pretty(value)) } setError('') }, [JSON.stringify(value)])
  const edit = (t: string) => {
    setText(t)
    try {
      const v = JSON.parse(t)
      if (many ? !(Array.isArray(v) && v.every(isObj)) : !isObj(v)) return setError(many ? 'must be a list of objects' : 'must be an object')
      setError('')
      onChange(v)
    } catch (e) { setError(e instanceof Error ? e.message : String(e)) }
  }
  return <>
    <textarea className={`in mono ${error ? 'bad' : ''}`} rows={Math.min(10, text.split('\n').length + 1)} aria-label={label} spellCheck={false} value={text} onChange={e => edit(e.target.value)} />
    {error && <div className="err">{error}</div>}
  </>
}
