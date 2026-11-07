// Types of the spec format (prototypes/spec-format) and the pure helpers that edit it.

export type Rec<T> = Record<string, T>
export type Size = 'fill' | 'hug' | number
export type Layout = 'row' | 'column' | 'stack' | 'grid'
// The layout fields of anything that holds children.
export type Box = {
  layout?: Layout; wrap?: boolean; columns?: number; align?: string; gap?: number | 'auto'; padding?: number | number[]; clip?: boolean
  width?: Size; height?: Size
}
export type Inst = Box & {
  id: string; use: string; minWidth?: number; maxWidth?: number; minHeight?: number; maxHeight?: number; hidden?: boolean
  props?: Rec<unknown>; bind?: Rec<string>; children?: Inst[]; repeat?: { each: string; as: string; limit?: number }
}
export type Action = { set?: Rec<unknown>; enter?: string; exit?: string; emit?: string; call?: string; reload?: string; with?: string }
export type State = { about: string; set?: Rec<unknown> }
export type Device = 'desktop' | 'tablet' | 'mobile'
export const DEVICES: Rec<[number, number]> = { desktop: [1440, 1024], tablet: [834, 1194], mobile: [390, 844] }
export const BOX_KEYS = ['layout', 'wrap', 'columns', 'align', 'gap', 'padding', 'clip']
export const SIZE_KEYS = ['width', 'height', 'minWidth', 'maxWidth', 'minHeight', 'maxHeight']
// Instance fields a state can set besides props.
export const FIELD_KEYS = ['hidden', ...SIZE_KEYS, ...BOX_KEYS]
export type Item = Box & {
  component?: string; screen?: string; about?: string; device?: Device
  props?: Rec<string>; events?: Rec<string | null>; local?: Rec<string>; data?: Rec<{ type: string; from?: string }>
  children?: Inst[]; states?: Rec<State>; on?: Rec<Action[]>
}
export type Model = { data: string; fields: Rec<string>; operations: string[] }
export type PropType = string | string[]
export type Primitive = { element: string; children?: boolean; props: Rec<PropType>; events?: Rec<string | null> }
export type Spec = { primitives: Rec<Primitive>; data: Model[]; components: Item[]; screens: Item[] }
export type Kind = 'screens' | 'components' | 'data'

export const nameOf = (x: Item | Model): string => ('data' in x && typeof x.data === 'string' ? x.data : (x as Item).component ?? (x as Item).screen)!
export const pathOf = (kind: Kind, name: string) => `${kind}/${name}.json`
export const itemsOf = (spec: Spec, kind: Kind): (Item | Model)[] => spec[kind]
export const findItem = (spec: Spec, kind: Kind, name: string) => itemsOf(spec, kind).find(x => nameOf(x) === name)
export const comps = (spec: Spec) => Object.fromEntries(spec.components.map(c => [c.component!, c]))
export const models = (spec: Spec) => Object.fromEntries(spec.data.map(d => [d.data, d]))

// Rebuilds an object with one key renamed, keeping key order.
export const renameKey = <T,>(obj: Rec<T>, from: string, to: string): Rec<T> =>
  Object.fromEntries(Object.entries(obj).map(([k, v]) => [k === from ? to : k, v]))

export function walk(list: Inst[] | undefined, fn: (inst: Inst, parent: Inst | null) => void, parent: Inst | null = null) {
  for (const inst of list ?? []) { fn(inst, parent); walk(inst.children, fn, inst) }
}
export function allIds(item: Item) { const ids: string[] = []; walk(item.children, i => ids.push(i.id)); return ids }
export function findInst(item: Item, id: string) {
  let found: { inst: Inst; parent: Inst | null } | undefined
  walk(item.children, (inst, parent) => { if (inst.id === id) found = { inst, parent } })
  return found
}

// What an instance of `use` accepts and fires; null if unknown.
export function iface(spec: Spec, use: string) {
  const p = spec.primitives[use]
  if (p) return { props: p.props, events: p.events ?? {}, slots: !!p.children }
  const c = comps(spec)[use]
  if (c) return { props: (c.props ?? {}) as Rec<PropType>, events: c.events ?? {}, slots: false }
  return null
}

export function uniqueId(item: Item, base: string) {
  const ids = new Set(allIds(item))
  const clean = base.replace(/[^A-Za-z0-9_]/g, '')
  const b = clean ? clean[0].toLowerCase() + clean.slice(1) : 'item'
  let id = b
  for (let n = 2; ids.has(id); n++) id = `${b}${n}`
  return id
}

// A fresh instance as the toolbar drops it: copy in text-like props, a column for anything that holds children.
export function newInst(spec: Spec, id: string, use: string, init: Partial<Inst> = {}): Inst {
  const inst: Inst = { id, use }
  if (use === 'text') inst.props = { text: 'Text' }
  if (use === 'button') inst.props = { text: 'Button' }
  if (use === 'link') inst.props = { text: 'Link' }
  if (spec.primitives[use]?.children) inst.layout = 'column'
  return Object.assign(inst, init)
}

// Sets an instance's prop or layout field: in the base, or as an override in `state` (undefined resets it).
export function setField(item: Item, state: string | null, id: string, key: string, v: unknown) {
  if (state) {
    const st = item.states![state]
    st.set ??= {}
    if (v === undefined) delete st.set[`${id}.${key}`]
    else st.set[`${id}.${key}`] = v
    return
  }
  const inst = findInst(item, id)!.inst
  if (FIELD_KEYS.includes(key)) {
    const r = inst as Rec<unknown>
    if (v === undefined || (key === 'hidden' && !v)) delete r[key]
    else r[key] = v
    return
  }
  if (inst.bind) delete inst.bind[key]
  if (v === undefined || v === '' || v === false) { if (inst.props) delete inst.props[key] }
  else (inst.props ??= {})[key] = v
}

// Inserts a new instance of `use` into parentId's children (null = the item root); returns its id.
export function insertInstance(spec: Spec, item: Item, parentId: string | null, index: number, use: string, init: Partial<Inst> = {}) {
  const id = uniqueId(item, init.layout ?? use)
  const inst = newInst(spec, id, use, init)
  const list = parentId === null ? (item.children ??= []) : (findInst(item, parentId)!.inst.children ??= [])
  list.splice(index, 0, inst)
  return id
}

// Moves an instance to parentId's children at index (counted before the move); false if that would put it inside itself.
export function moveInstance(item: Item, id: string, parentId: string | null, index: number) {
  const hit = findInst(item, id)
  if (!hit) return false
  if (parentId === id || (parentId && findInst({ children: [hit.inst] }, parentId))) return false
  const from = hit.parent ? hit.parent.children! : item.children!
  const to = parentId === null ? (item.children ??= []) : (findInst(item, parentId)!.inst.children ??= [])
  const old = from.indexOf(hit.inst)
  if (from === to && old < index) index--
  from.splice(old, 1)
  to.splice(index, 0, hit.inst)
  return true
}

// Removes an instance and its subtree, and every state set and `on` entry that pointed at them.
export function deleteInstance(item: Item, id: string) {
  const hit = findInst(item, id)
  if (!hit) return
  const gone = new Set([id]); walk(hit.inst.children, i => gone.add(i.id))
  const list = hit.parent ? hit.parent.children! : item.children!
  list.splice(list.indexOf(hit.inst), 1)
  const owner = (key: string) => gone.has(key.split('.')[0])
  for (const st of Object.values(item.states ?? {})) if (st.set) st.set = Object.fromEntries(Object.entries(st.set).filter(([k]) => !owner(k)))
  if (item.on) item.on = Object.fromEntries(Object.entries(item.on).filter(([k]) => !owner(k)))
}

export function renameInstance(item: Item, from: string, to: string) {
  const hit = findInst(item, from)
  if (!hit) return
  hit.inst.id = to
  const re = (key: string) => key.split('.')[0] === from ? to + key.slice(from.length) : key
  for (const st of Object.values(item.states ?? {})) if (st.set) st.set = Object.fromEntries(Object.entries(st.set).map(([k, v]) => [re(k), v]))
  if (item.on) item.on = Object.fromEntries(Object.entries(item.on).map(([k, v]) => [re(k), v]))
}

// Overrides per instance id from the active states, applied in written order (later wins).
export function applyStates(item: Item, active: string[]) {
  const out: Rec<Rec<unknown>> = {}
  for (const [name, st] of Object.entries(item.states ?? {})) {
    if (!active.includes(name)) continue
    for (const [key, v] of Object.entries(st.set ?? {})) {
      const [id, prop] = key.split('.')
      ;(out[id] ??= {})[prop] = v
    }
  }
  return out
}

export const fileScope = (item: Item): Rec<string> => ({
  ...item.props, ...item.local, ...Object.fromEntries(Object.entries(item.data ?? {}).map(([k, d]) => [k, d.type])),
})

export function typeOf(spec: Spec, path: string, scope: Rec<string>) {
  const [root, ...rest] = path.split('.')
  let t: string | undefined = scope[root]
  const m = models(spec)
  for (const seg of rest) t = t ? m[t]?.fields[seg] : undefined
  return t
}

// The names in scope at an instance: the file's, plus repeat aliases of its ancestors (and its own, if withSelf).
export function instScope(spec: Spec, item: Item, id: string, withSelf = true) {
  const find = (list: Inst[] | undefined, scope: Rec<string>): Rec<string> | null => {
    for (const inst of list ?? []) {
      let inner = scope
      const t = inst.repeat && typeOf(spec, inst.repeat.each, scope)
      if (inst.repeat && t?.endsWith('[]')) inner = { ...scope, [inst.repeat.as]: t.slice(0, -2) }
      if (inst.id === id) return withSelf ? inner : scope
      const r = find(inst.children, inner)
      if (r) return r
    }
    return null
  }
  return find(item.children, fileScope(item)) ?? fileScope(item)
}

// Every path reachable from the scope, with its type: roots and their model fields (task.title).
export function paths(spec: Spec, scope: Rec<string>) {
  const m = models(spec)
  const out: [string, string][] = []
  const go = (path: string, t: string, depth: number) => {
    out.push([path, t])
    if (depth < 3) for (const [f, ft] of Object.entries(m[t]?.fields ?? {})) go(`${path}.${f}`, ft, depth + 1)
  }
  for (const [k, t] of Object.entries(scope)) go(k, t, 0)
  return out
}

// Components `name` uses, directly or through other components.
export function usesDeep(spec: Spec, name: string, seen = new Set<string>()) {
  const c = comps(spec)[name]
  walk(c?.children, i => { if (comps(spec)[i.use] && !seen.has(i.use)) { seen.add(i.use); usesDeep(spec, i.use, seen) } })
  return seen
}

const filesOf = (spec: Spec) => [...spec.components, ...spec.screens]

export function componentUsed(spec: Spec, name: string) {
  return filesOf(spec).some(f => { let hit = false; walk(f.children, i => { hit ||= i.use === name }); return hit && nameOf(f) !== name })
}
export function renameComponent(spec: Spec, from: string, to: string) {
  for (const f of filesOf(spec)) walk(f.children, i => { if (i.use === from) i.use = to })
  comps(spec)[from].component = to
}

const typeRefs = (spec: Spec) => {
  const out: [Rec<unknown>, string, string][] = [] // [object, key, type]
  for (const d of spec.data) for (const k in d.fields) out.push([d.fields, k, d.fields[k]])
  for (const f of filesOf(spec)) {
    for (const r of [f.props, f.local, f.events]) for (const k in r ?? {}) if (r![k]) out.push([r!, k, r![k]!])
    for (const k in f.data ?? {}) out.push([f.data![k], 'type', f.data![k].type])
  }
  return out
}
const opRefs = (spec: Spec) => {
  const out: [Rec<unknown>, string, string][] = []
  for (const f of filesOf(spec)) {
    for (const d of Object.values(f.data ?? {})) if (d.from) out.push([d, 'from', d.from])
    for (const acts of Object.values(f.on ?? {})) for (const a of acts) if (a.call) out.push([a, 'call', a.call])
  }
  return out
}
export function modelUsed(spec: Spec, name: string) {
  return typeRefs(spec).some(([, , t]) => t.replace(/\[\]$/, '') === name) || opRefs(spec).some(([, , r]) => r.split('.')[0] === name)
}
export function renameModel(spec: Spec, from: string, to: string) {
  for (const [obj, k, t] of typeRefs(spec)) if (t.replace(/\[\]$/, '') === from) obj[k] = to + t.slice(from.length)
  for (const [obj, k, r] of opRefs(spec)) if (r.split('.')[0] === from) obj[k] = to + r.slice(from.length)
  models(spec)[from].data = to
}
export function renameOp(spec: Spec, model: string, from: string, to: string) {
  for (const [obj, k, r] of opRefs(spec)) if (r === `${model}.${from}`) obj[k] = `${model}.${to}`
  const m = models(spec)[model]
  m.operations = m.operations.map(o => (o === from ? to : o))
}

// Renames a state and every enter/exit of it.
export function renameState(item: Item, from: string, to: string) {
  item.states = renameKey(item.states ?? {}, from, to)
  for (const acts of Object.values(item.on ?? {})) for (const a of acts) {
    if (a.enter === from) a.enter = to
    if (a.exit === from) a.exit = to
  }
}
export function deleteState(item: Item, name: string) {
  delete item.states![name]
  for (const k in item.on ?? {}) item.on![k] = item.on![k].filter(a => a.enter !== name && a.exit !== name)
}

// The JSON a file is written as: keys in the format's order, empty parts dropped.
const FILE_KEYS = ['component', 'screen', 'about', 'device', 'props', 'events', 'local', 'data', 'width', 'height', ...BOX_KEYS, 'children', 'states', 'on']
const INST_KEYS = ['id', 'use', ...SIZE_KEYS, ...BOX_KEYS, 'hidden', 'props', 'bind', 'children', 'repeat']
const empty = (v: unknown) => v === undefined || v === '' || (typeof v === 'object' && v !== null && Object.keys(v).length === 0)
const ordered = (o: Rec<unknown>, keys: string[], fix: (k: string, v: unknown) => unknown) =>
  Object.fromEntries(keys.filter(k => !empty(o[k])).map(k => [k, fix(k, o[k])]).filter(([, v]) => !empty(v)))
const tidyInst = (i: Inst): Inst => ordered(i, INST_KEYS, (k, v) => (k === 'children' ? (v as Inst[]).map(tidyInst) : v)) as Inst
export function tidy(x: Item | Model): unknown {
  if ('fields' in x) return { data: x.data, fields: x.fields, operations: x.operations }
  return ordered(x as Rec<unknown>, FILE_KEYS, (k, v) =>
    k === 'children' ? (v as Inst[]).map(tidyInst)
    : k === 'states' ? Object.fromEntries(Object.entries(v as Rec<State>).map(([n, s]) => [n, empty(s.set) ? { about: s.about } : s]))
    : k === 'on' ? Object.fromEntries(Object.entries(v as Rec<Action[]>).filter(([, a]) => a.length))
    : v)
}
