// Checks a spec in this format: every reference resolves and every value has the right type.
// Usage: node check.mjs [spec dir]
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const BASE = ['text', 'bool', 'number']
const LAYOUTS = ['row', 'column', 'stack', 'grid']
const ALIGNS = ['top-left', 'top', 'top-right', 'left', 'center', 'right', 'bottom-left', 'bottom', 'bottom-right']
const DEVICES = ['desktop', 'tablet', 'mobile']
const px = v => typeof v === 'number' && v >= 0
// Layout fields of anything that holds children, and the sizing of any instance: field -> [valid?, what it takes].
const BOX = {
  layout: [v => LAYOUTS.includes(v), LAYOUTS.join(', ')],
  wrap: [v => typeof v === 'boolean', 'true or false'],
  columns: [v => Number.isInteger(v) && v > 0, 'a whole number above 0'],
  align: [v => ALIGNS.includes(v), ALIGNS.join(', ')],
  gap: [v => px(v) || v === 'auto', 'a number or auto'],
  padding: [v => px(v) || (Array.isArray(v) && [2, 4].includes(v.length) && v.every(px)), 'a number, [vertical, horizontal] or [top, right, bottom, left]'],
  clip: [v => typeof v === 'boolean', 'true or false'],
}
const SIZE = [v => v === 'fill' || v === 'hug' || px(v), 'fill, hug or a number']
const SIZING = { width: SIZE, height: SIZE, minWidth: [px, 'a number'], maxWidth: [px, 'a number'], minHeight: [px, 'a number'], maxHeight: [px, 'a number'] }
const FILE_KEYS = ['component', 'screen', 'about', 'device', 'props', 'events', 'local', 'data', 'width', 'height', ...Object.keys(BOX), 'children', 'states', 'on']
const INSTANCE_KEYS = ['id', 'use', ...Object.keys(SIZING), ...Object.keys(BOX), 'hidden', 'props', 'bind', 'children', 'repeat']
// Errors in the layout fields of `o`, which may use `fields`.
const badLayout = (o, fields) => {
  const out = []
  for (const [k, [ok, takes]] of Object.entries(fields)) if (k in o && !ok(o[k])) out.push(`${k} is ${takes}, got ${JSON.stringify(o[k])}`)
  if (o.wrap && (o.layout ?? 'column') !== 'row') out.push('wrap only applies to a row')
  if (o.columns && o.layout !== 'grid') out.push('columns only apply to a grid')
  return out
}

const readJson = path => JSON.parse(readFileSync(path, 'utf8'))

export function load(dir) {
  const read = sub => readdirSync(join(dir, sub)).filter(f => f.endsWith('.json')).map(f => readJson(join(dir, sub, f)))
  // Primitives are speccy's own catalogue, not part of a spec, so they live beside this file.
  return { primitives: readJson(fileURLToPath(new URL('primitives.json', import.meta.url))), data: read('data'), components: read('components'), screens: read('screens') }
}

export function check(spec) {
  const errors = []
  const models = Object.fromEntries(spec.data.map(d => [d.data, d]))
  const comps = Object.fromEntries(spec.components.map(c => [c.component, c]))

  const validType = t => typeof t === 'string' && (BASE.includes(t.replace(/\[\]$/, '')) || !!models[t.replace(/\[\]$/, '')])
  // What an instance of `use` accepts and emits; every instance can be hidden.
  const iface = use => {
    const p = spec.primitives[use]
    if (p) return { props: { hidden: 'bool', ...p.props }, events: p.events ?? {}, slots: !!p.children }
    const c = comps[use]
    if (c) return { props: { hidden: 'bool', ...c.props }, events: c.events ?? {}, slots: false }
  }
  // The type a dotted path points at, or undefined if it doesn't resolve.
  const typeOf = (path, scope) => {
    const [root, ...rest] = path.split('.')
    let t = scope[root]
    for (const seg of rest) t = models[t]?.fields[seg]
    return t
  }
  const literalFits = (v, t) =>
    Array.isArray(t) ? t.includes(v)
    : t === 'text' ? typeof v === 'string'
    : t === 'bool' ? typeof v === 'boolean'
    : t === 'number' ? typeof v === 'number'
    : t?.endsWith('[]') && BASE.includes(t.slice(0, -2)) ? Array.isArray(v)
    : false // data types can only be bound, never written as literals

  for (const d of spec.data) {
    for (const [f, t] of Object.entries(d.fields)) if (!validType(t)) errors.push(`data ${d.data}: field ${f} has unknown type ${t}`)
  }

  for (const file of [...spec.components, ...spec.screens]) {
    const name = file.component ?? file.screen
    const err = msg => errors.push(`${name}: ${msg}`)
    for (const k of Object.keys(file)) if (!FILE_KEYS.includes(k)) err(`unknown key ${k}`)
    if (file.screen && (file.props || file.events || file.local)) err('a screen has data, not props, events or local')
    if (file.component && file.data) err('a component gets its data through props')
    if (spec.primitives[name]) err('has the same name as a primitive')
    for (const e of badLayout(file, { ...BOX, width: SIZE, height: SIZE })) err(e)
    if (file.screen && (file.width || file.height)) err('a screen takes its size from its device, not width or height')
    if (file.component && file.device) err('only a screen has a device')
    if (file.screen && !DEVICES.includes(file.device)) err(`device is ${DEVICES.join(', ')}, got ${JSON.stringify(file.device)}`)

    const data = file.data ?? {}
    for (const [k, d] of Object.entries(data)) {
      if (!validType(d.type)) err(`data ${k} has unknown type ${d.type}`)
      const [m, op] = (d.from ?? '').split('.')
      if (d.from && !models[m]?.operations.includes(op)) err(`data ${k} comes from unknown operation ${d.from}`)
    }
    const local = file.local ?? {}
    const scope = { ...file.props, ...local, ...Object.fromEntries(Object.entries(data).map(([k, d]) => [k, d.type])) }
    for (const [k, t] of Object.entries(scope)) if (!validType(t)) err(`${k} has unknown type ${t}`)

    // Walk instances, collecting them by id.
    const ids = {}
    const walk = (list, scope) => {
      for (const inst of list ?? []) {
        const at = `instance ${inst.id}`
        for (const k of Object.keys(inst)) if (!INSTANCE_KEYS.includes(k)) err(`${at}: unknown key ${k}`)
        if (ids[inst.id]) err(`${at}: id used twice`)
        const i = iface(inst.use)
        if (!i) { err(`${at}: uses unknown component ${inst.use}`); continue }
        const fields = i.slots ? { ...SIZING, ...BOX } : SIZING
        ids[inst.id] = { ...i, fields }
        for (const e of badLayout(inst, fields)) err(`${at}: ${e}`)
        for (const k of Object.keys(BOX)) if (k in inst && !i.slots) err(`${at}: ${inst.use} holds no children, so it has no ${k}`)
        if (inst.children && !i.slots) err(`${at}: ${inst.use} can't hold children`)
        if (inst.repeat && 'limit' in inst.repeat && !(Number.isInteger(inst.repeat.limit) && inst.repeat.limit > 0)) err(`${at}: repeat limit is a whole number above 0, got ${JSON.stringify(inst.repeat.limit)}`)
        let inner = scope
        if (inst.repeat) {
          const t = typeOf(inst.repeat.each, scope)
          if (!t?.endsWith('[]')) err(`${at}: repeat over ${inst.repeat.each}, which is not a list`)
          else inner = { ...scope, [inst.repeat.as]: t.slice(0, -2) }
        }
        for (const [p, v] of Object.entries(inst.props ?? {})) {
          if (!(p in i.props)) err(`${at}: ${inst.use} has no prop ${p}`)
          else if (!literalFits(v, i.props[p])) err(`${at}: prop ${p} is ${JSON.stringify(i.props[p])}, got ${JSON.stringify(v)}`)
        }
        for (const [p, path] of Object.entries(inst.bind ?? {})) {
          const t = typeOf(path, inner)
          if (!(p in i.props)) err(`${at}: ${inst.use} has no prop ${p}`)
          else if (!t) err(`${at}: bind ${p} to ${path}, which doesn't resolve`)
          else if (t !== i.props[p]) err(`${at}: prop ${p} is ${i.props[p]}, bound to ${path} which is ${t}`)
        }
        walk(inst.children, inner)
      }
    }
    walk(file.children, scope)

    for (const [s, st] of Object.entries(file.states ?? {})) {
      for (const k of Object.keys(st)) if (!['about', 'set'].includes(k)) err(`state ${s}: unknown key ${k}`)
      if (typeof st.about !== 'string' || !st.about) err(`state ${s}: needs an about saying when it applies`)
      for (const [target, v] of Object.entries(st.set ?? {})) {
        const [id, prop] = target.split('.')
        const field = ids[id]?.fields[prop]
        const t = ids[id]?.props[prop]
        if (field) { if (!field[0](v)) err(`state ${s}: ${target} is ${field[1]}, got ${JSON.stringify(v)}`) }
        else if (!t) err(`state ${s}: sets ${target}, which isn't an instance prop or layout field`)
        else if (!literalFits(v, t)) err(`state ${s}: ${target} is ${JSON.stringify(t)}, got ${JSON.stringify(v)}`)
      }
    }

    for (const [key, actions] of Object.entries(file.on ?? {})) {
      const [id, ev] = key.split('.')
      const at = `on ${key}`
      if (!ids[id] || !(ev in ids[id].events)) { err(`${at}: ${id} has no event ${ev}`); continue }
      const payload = ids[id].events[ev]
      const hscope = payload ? { ...scope, event: payload } : scope
      for (const a of actions) {
        const kind = ['set', 'emit', 'call', 'reload', 'enter', 'exit'].filter(k => k in a)
        if (kind.length !== 1) { err(`${at}: an action needs exactly one of set, emit, call, reload, enter, exit`); continue }
        const target = a.enter ?? a.exit
        if (target && !file.states?.[target]) err(`${at}: ${kind[0]}s ${target}, which isn't a state`)
        if (a.set) for (const [k, v] of Object.entries(a.set)) {
          if (!(k in local)) err(`${at}: sets ${k}, which isn't local state`)
          else if (v?.ref ? typeOf(v.ref, hscope) !== local[k] : !literalFits(v, local[k])) err(`${at}: ${k} is ${local[k]}, got ${JSON.stringify(v)}`)
        }
        if (a.emit) {
          if (!(a.emit in (file.events ?? {}))) err(`${at}: emits ${a.emit}, which isn't in events`)
          else if (file.events[a.emit] && typeOf(a.with ?? '', hscope) !== file.events[a.emit]) err(`${at}: ${a.emit} carries ${file.events[a.emit]}, got ${a.with}`)
        }
        if (a.call) {
          const [m, op] = a.call.split('.')
          if (!models[m]?.operations.includes(op)) err(`${at}: calls unknown operation ${a.call}`)
          if (a.with && !typeOf(a.with, hscope)) err(`${at}: with ${a.with}, which doesn't resolve`)
        }
        if (a.reload && !data[a.reload]?.from) err(`${at}: reloads ${a.reload}, which isn't loaded data`)
      }
    }
  }
  return errors
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const errors = check(load(process.argv[2] ?? fileURLToPath(new URL('.', import.meta.url))))
  console.log(errors.length ? errors.join('\n') : 'ok')
  process.exit(errors.length ? 1 : 0)
}
