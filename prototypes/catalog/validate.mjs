// Checks primitives/<name>.json against RENDER.md. Usage: node validate.mjs [dir] (default: ./primitives beside this file).
// It also holds the template language (paths, expressions, conditions), which the showcase's renderer imports,
// so it has no static Node imports.

export const CATEGORIES = ['actions', 'inputs', 'selection', 'navigation', 'feedback', 'overlays', 'containment', 'data-display', 'layout', 'media']
export const CLASSES = new Set(`wf-row wf-col wf-gap wf-pad wf-grow wf-box wf-surface wf-overlay wf-btn wf-btn-primary wf-btn-sm wf-btn-lg wf-btn-icon wf-field wf-label wf-hint
  wf-muted wf-strong wf-small wf-icon wf-symbol wf-avatar wf-pill wf-dot wf-track wf-fill wf-thumb wf-divider wf-pressable wf-selected wf-error wf-disabled wf-scroll`.split(/\s+/))
const KEYS = ['name', 'about', 'category', 'element', 'props', 'events', 'children', 'states', 'defaults', 'render', 'sources']
const NODE_KEYS = new Set(['el', 'class', 'classIf', 'text', 'attrs', 'attrsIf', 'if', 'each', 'as', 'limit', 'children', 'slot'])
const TYPES = ['text', 'bool', 'number', 'text[]', 'model', 'model[]']
const LOOP = ['index', 'first', 'last']
const PARTS = /(\{[^{}]*\})/

const isObj = v => v !== null && typeof v === 'object' && !Array.isArray(v)
const isType = t => TYPES.includes(t) || (Array.isArray(t) && t.length > 0 && t.every(x => typeof x === 'string'))
const show = t => (Array.isArray(t) ? JSON.stringify(t) : t)
export const fits = (t, v) =>
  Array.isArray(t) ? t.includes(v)
  : t === 'text' ? typeof v === 'string'
  : t === 'bool' ? typeof v === 'boolean'
  : t === 'number' ? Number.isFinite(v)
  : t === 'text[]' ? Array.isArray(v) && v.every(x => typeof x === 'string')
  : t === 'model' ? isObj(v)
  : t === 'model[]' ? Array.isArray(v) && v.every(isObj)
  : false

// ---- The template language ----

// A path is name(.field | [path])*, e.g. item.label, row[col], items.length. Its segments: a string, or { path } for a
// [bracket], which holds a whole number or a path looked up in scope.
export function splitPath(p) {
  const segs = [], seg = /\.?(\w+)|\[([^[\]]+)\]/gy
  for (let m; seg.lastIndex < p.length && (m = seg.exec(p));) segs.push(m[1] ?? { path: m[2].trim() })
  if (seg.lastIndex !== p.length || !/^[A-Za-z_]/.test(p)) throw new Error(`bad path "${p}"`)
  return segs
}
const own = (v, k) =>
  typeof v === 'string' ? (k === 'length' || /^\d+$/.test(k) ? v[k] : undefined)
  : v !== null && typeof v === 'object' && Object.hasOwn(v, k) ? v[k] : undefined
export const get = (path, scope) => splitPath(path.trim()).reduce((v, s) => own(v, typeof s === 'string' ? s : /^\d+$/.test(s.path) ? s.path : str(get(s.path, scope))), scope)
export const str = v => (v == null ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v))
export const truthy = v => (Array.isArray(v) ? v.length > 0 : !!v)

// An expression: numbers, paths, + - * / and parentheses. Parsed to { n } | { p } | { o, a, b }.
const TOKEN = /\s*(?:(\d+(?:\.\d+)?)|([A-Za-z_]\w*(?:\.\w+|\[[^[\]]+\])*)|([-+*/()]))\s*/y
export function parseExpr(src) {
  const toks = []
  TOKEN.lastIndex = 0
  for (let m; TOKEN.lastIndex < src.length;) {
    if (!(m = TOKEN.exec(src))) throw new Error(`can't read "${src}"`)
    toks.push(m[1] ? { n: Number(m[1]) } : m[2] ? { p: m[2] } : { t: m[3] })
  }
  let k = 0
  const factor = () => {
    const t = toks[k++]
    if (t && t.t === '(') { const e = sum(); if (toks[k++]?.t !== ')') throw new Error(`missing ) in "${src}"`); return e }
    if (!t || t.t) throw new Error(`expected a number or a path in "${src}"`)
    return t
  }
  const chain = (next, ops) => () => { let a = next(); while (ops.includes(toks[k]?.t)) a = { o: toks[k++].t, a, b: next() }; return a }
  const sum = chain(chain(factor, '*/'), '+-')
  const e = sum()
  if (k < toks.length) throw new Error(`unexpected "${toks[k].t ?? toks[k].p ?? toks[k].n}" in "${src}"`)
  return e
}
export const exprPaths = e => ('p' in e ? [e.p] : 'o' in e ? [...exprPaths(e.a), ...exprPaths(e.b)] : [])
const OPS = { '+': (a, b) => a + b, '-': (a, b) => a - b, '*': (a, b) => a * b, '/': (a, b) => a / b }
// A lone path gives its raw value; arithmetic works on numbers.
export const evalExpr = (e, scope) => ('n' in e ? e.n : 'p' in e ? get(e.p, scope) : OPS[e.o](Number(evalExpr(e.a, scope)), Number(evalExpr(e.b, scope))))

// "{expr}" alone gives the raw value; inside other text each {expr} is stringified.
export function interp(s, scope) {
  const whole = /^\{([^{}]+)\}$/.exec(s)
  return whole ? evalExpr(parseExpr(whole[1]), scope) : s.replace(/\{([^{}]+)\}/g, (_, e) => str(evalExpr(parseExpr(e), scope)))
}

// A condition: !cond, left, left=right, left!=right, left in right. Left is an expression, right a literal or {…}.
export function parseCond(c) {
  c = c.trim()
  if (c.startsWith('!')) return { not: parseCond(c.slice(1)) }
  const m = /^(.*?)\s*(!=|=|\sin\s)\s*(.*)$/.exec(c)
  return m ? { left: parseExpr(m[1]), op: m[2].trim(), right: m[3] } : { left: parseExpr(c) }
}
// Equal as text; a model on the right matches when each of its fields matches the left's (so { "label": "x" } finds an item).
const match = (l, r) => (isObj(r) ? isObj(l) && Object.keys(r).every(k => match(l[k], r[k])) : str(l) === str(r))
export function holds(cond, scope) {
  const c = typeof cond === 'string' ? parseCond(cond) : cond
  if (c.not) return !holds(c.not, scope)
  const l = evalExpr(c.left, scope)
  if (!c.op) return truthy(l)
  const r = interp(c.right, scope)
  if (c.op === 'in') return (Array.isArray(r) ? r : str(r).split(',').map(x => x.trim())).some(x => match(l, x))
  return match(l, r) === (c.op === '=')
}

// ---- Files ----

// Reads every <name>.json in dir: its text, and its parsed value (an Error when it isn't JSON).
export function load(dir) {
  const { readdirSync, readFileSync } = process.getBuiltinModule('node:fs')
  const texts = {}, prims = {}
  for (const f of readdirSync(dir).filter(f => f.endsWith('.json')).sort()) {
    const name = f.slice(0, -5)
    texts[name] = readFileSync(`${dir}/${f}`, 'utf8')
    try { prims[name] = JSON.parse(texts[name]) } catch (e) { prims[name] = e }
  }
  return { texts, prims }
}

// primitives: { [file name]: parsed file | Error }. Returns "name: problem" lines.
export function validate(primitives) {
  const out = []
  for (const [file, p] of Object.entries(primitives)) check(file, p, msg => out.push(`${file}: ${msg}`))
  return out
}

function check(file, p, err) {
  if (p instanceof Error) return err(`invalid JSON: ${p.message}`)
  if (!isObj(p)) return err('not a JSON object')
  for (const k of KEYS) if (!(k in p)) err(`missing ${k}`)
  if ('name' in p && p.name !== file) err(`name ${JSON.stringify(p.name)} does not match the file name`)
  for (const k of ['about', 'element']) if (k in p && typeof p[k] !== 'string') err(`${k} must be text`)
  if ('category' in p && !CATEGORIES.includes(p.category)) err(`unknown category ${JSON.stringify(p.category)}`)
  if ('children' in p && typeof p.children !== 'boolean') err('children must be true or false')
  if ('sources' in p && !isObj(p.sources)) err('sources must be an object')
  const obj = k => (isObj(p[k]) ? p[k] : (k in p && err(`${k} must be an object`), {}))

  const props = obj('props')
  for (const [k, t] of Object.entries(props)) if (!isType(t)) err(`prop ${k}: unknown type ${JSON.stringify(t)}`)
  for (const [k, t] of Object.entries(obj('events'))) if (t !== null && !isType(t)) err(`event ${k}: unknown payload type ${JSON.stringify(t)}`)
  const value = (where, k, v) => {
    if (!(k in props)) err(`${where}: ${k} is not a prop`)
    else if (isType(props[k]) && !fits(props[k], v)) err(`${where}: ${k} should be ${show(props[k])}, got ${JSON.stringify(v)}`)
  }
  // examples is optional, and checked like states: frames for what isn't a state (sizes, icons…).
  for (const [key, one] of [['states', 'state'], ['examples', 'example']])
    for (const [s, set] of Object.entries(obj(key))) {
      if (!isObj(set)) err(`${one} ${s} must be an object of prop values`)
      else for (const [k, v] of Object.entries(set)) value(`${one} ${s}`, k, v)
    }
  const defaults = obj('defaults')
  for (const k of Object.keys(props)) if (!(k in defaults)) err(`defaults: missing ${k}`)
  for (const [k, v] of Object.entries(defaults)) value('defaults', k, v)

  // A path starts at an each alias (any field), index/first/last (inside an each) or a prop: a model's fields
  // can't be checked; text takes .length or one [lookup], text[] the same or a [lookup] then that; brackets must resolve too.
  const resolves = (path, scope) => {
    let segs
    try { segs = splitPath(path.trim()) } catch { return false }
    const [head, ...rest] = segs
    if (rest.some(s => typeof s !== 'string' && !/^\d+$/.test(s.path) && !resolves(s.path, scope))) return false
    if (scope.has(head)) return true
    if (LOOP.includes(head)) return scope.size > 0 && !rest.length
    const t = props[head]
    if (t === undefined) return false
    if (!rest.length || t === 'model' || t === 'model[]') return true
    const textRest = r => !r.length || (r.length === 1 && (r[0] === 'length' || typeof r[0] !== 'string'))
    return t === 'text' ? textRest(rest) : t === 'text[]' && (textRest(rest) || (typeof rest[0] !== 'string' && textRest(rest.slice(1))))
  }
  const expr = (src, at, scope) => {
    try { for (const path of exprPaths(parseExpr(src))) if (!resolves(path, scope)) err(`${at}: ${path} is not a prop, an item or index/first/last`) }
    catch (e) { err(`${at}: ${e.message}`) }
  }
  const interp = (s, at, scope) => {
    for (const [, e] of s.matchAll(/\{([^{}]*)\}/g)) expr(e, at, scope)
    if (/[{}]/.test(s.replace(/\{[^{}]*\}/g, ''))) err(`${at}: unbalanced { } in ${JSON.stringify(s)}`)
  }
  const cond = (c, at, scope) => {
    if (typeof c !== 'string') return err(`${at}: a condition must be a string`)
    let parsed
    try { parsed = parseCond(c) } catch (e) { return err(`${at}: ${e.message}`) }
    while (parsed.not) parsed = parsed.not
    for (const path of exprPaths(parsed.left)) if (!resolves(path, scope)) err(`${at}: ${path} is not a prop, an item or index/first/last`)
    if (parsed.op === undefined) return
    interp(parsed.right, at, scope)
    // A literal compared with an enum prop must be one of its values.
    const t = 'p' in parsed.left ? props[parsed.left.p] : undefined
    if (Array.isArray(t) && !parsed.right.includes('{'))
      for (const v of parsed.op === 'in' ? parsed.right.split(',').map(x => x.trim()) : [parsed.right])
        if (!t.includes(v)) err(`${at}: ${v} is not one of ${show(t)}`)
  }
  // Every class a token can become: {enum} expands to each of its values.
  const classes = (token, at) =>
    token.split(PARTS).filter(Boolean).reduce((outs, part) => {
      if (!PARTS.test(part)) return outs.map(o => o + part)
      const t = props[part.slice(1, -1).trim()]
      if (!Array.isArray(t)) { err(`${at}: ${part} in a class must be an enum prop`); return [] }
      return outs.flatMap(o => t.map(v => o + v))
    }, [''])

  const node = (n, at, aliases) => {
    if (!isObj(n)) return err(`${at}: a node must be an object`)
    for (const k of Object.keys(n)) if (!NODE_KEYS.has(k)) err(`${at}: unknown key ${k}`)
    if (typeof n.el !== 'string' || !/^[a-z][a-z0-9-]*$/.test(n.el)) err(`${at}: el must be an HTML tag`)
    let scope = aliases
    if ('each' in n) {
      if (typeof n.each === 'number') { if (!(Number.isInteger(n.each) && n.each >= 0)) err(`${at}: each must be a whole number`) }
      else {
        const segs = typeof n.each === 'string' && (() => { try { return splitPath(n.each.trim()) } catch { return null } })()
        const ok = segs && (segs.length > 1 ? resolves(n.each, aliases) : aliases.has(segs[0]) || ['text[]', 'model[]', 'number'].includes(props[segs[0]]))
        if (!ok) err(`${at}: each ${JSON.stringify(n.each)} is not a list or number prop, or an item's field`)
      }
      if ('as' in n && (typeof n.as !== 'string' || !/^[A-Za-z_]\w*$/.test(n.as))) err(`${at}: as must be a name`)
      scope = new Set([...aliases, typeof n.as === 'string' ? n.as : 'item'])
      if ('limit' in n) {
        if (typeof n.limit === 'string' && /^\{[^{}]+\}$/.test(n.limit)) interp(n.limit, `${at}.limit`, aliases)
        else if (!(Number.isInteger(n.limit) && n.limit >= 0)) err(`${at}: limit must be a whole number or {…}`)
      }
    } else for (const k of ['as', 'limit']) if (k in n) err(`${at}: ${k} without each`)
    if ('text' in n) typeof n.text === 'string' ? interp(n.text, `${at}.text`, scope) : err(`${at}: text must be a string`)
    const classList = (s, where) => {
      for (const token of s.split(/\s+/).filter(Boolean))
        for (const c of classes(token, where)) if (!CLASSES.has(c)) err(`${at}: unknown class ${c}`)
    }
    if ('class' in n) typeof n.class === 'string' ? classList(n.class, `${at}.class`) : err(`${at}: class must be a string`)
    if ('classIf' in n) {
      if (!isObj(n.classIf)) err(`${at}: classIf must be an object of class: condition`)
      else for (const [c, v] of Object.entries(n.classIf)) { classList(c, `${at}.classIf`); cond(v, `${at}.classIf.${c}`, scope) }
    }
    const attrs = (a, where) => {
      if (!isObj(a)) return err(`${at}: ${where} must be an object`)
      for (const [k, v] of Object.entries(a)) {
        if (typeof v === 'string') interp(v, `${at}.${where}.${k}`, scope)
        else if (v !== null && typeof v !== 'number' && typeof v !== 'boolean') err(`${at}: ${where}.${k} must be a string, number, bool or null`)
      }
    }
    if ('attrs' in n) attrs(n.attrs, 'attrs')
    if ('attrsIf' in n) {
      if (!isObj(n.attrsIf)) err(`${at}: attrsIf must be an object of condition: attrs`)
      else for (const [c, a] of Object.entries(n.attrsIf)) { cond(c, `${at}.attrsIf`, scope); attrs(a, `attrsIf.${c}`) }
    }
    if ('if' in n) cond(n.if, `${at}.if`, scope)
    if ('slot' in n) {
      if (n.slot !== true) err(`${at}: slot must be true`)
      else if (p.children !== true) err(`${at}: slot needs children: true`)
    }
    if ('children' in n) {
      if (!Array.isArray(n.children)) err(`${at}: children must be a list of nodes`)
      else n.children.forEach((c, i) => node(c, `${at}.children[${i}]`, scope))
    }
  }
  if ('render' in p) node(p.render, 'render', new Set())
}

if (globalThis.process?.getBuiltinModule && process.argv[1]) {
  const fs = process.getBuiltinModule('node:fs'), { fileURLToPath } = process.getBuiltinModule('node:url')
  if (fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
    const dir = process.getBuiltinModule('node:path').resolve(process.argv[2] ?? `${import.meta.dirname}/primitives`)
    let errors
    try { errors = validate(load(dir).prims) } catch (e) { errors = [String(e.message ?? e)] }
    console.log(errors.length ? errors.join('\n') : 'ok')
    process.exit(errors.length ? 1 : 0)
  }
}
