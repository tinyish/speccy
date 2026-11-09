// Draws a primitive's render node with prop values, per ../catalog/RENDER.md.
import { Component, createElement, type ReactNode } from 'react'
import { get, holds, interp, str } from '../../catalog/validate.mjs'

export { holds, interp }

export type Node = {
  el: string; class?: string; classIf?: Record<string, string>; text?: string; attrs?: Record<string, unknown>
  attrsIf?: Record<string, Record<string, unknown>>
  if?: string; each?: string | number; as?: string; limit?: number | string; children?: Node[]; slot?: boolean
}
type Scope = Record<string, unknown>

const VOID = new Set(['area', 'br', 'col', 'embed', 'hr', 'img', 'input', 'source', 'track', 'wbr'])
const FORM = new Set(['input', 'textarea', 'select'])
// HTML attribute names React wants in camelCase.
const ATTR: Record<string, string> = {
  class: 'className', for: 'htmlFor', tabindex: 'tabIndex', readonly: 'readOnly', maxlength: 'maxLength', minlength: 'minLength',
  colspan: 'colSpan', rowspan: 'rowSpan', contenteditable: 'contentEditable', autocomplete: 'autoComplete', autofocus: 'autoFocus',
  spellcheck: 'spellCheck', datetime: 'dateTime', inputmode: 'inputMode', enterkeyhint: 'enterKeyHint',
}

const style = (s: string) => Object.fromEntries(s.split(';').filter(d => d.includes(':')).map(d => {
  const [k, ...v] = d.split(':'), key = k.trim()
  return [key.startsWith('--') ? key : key.replace(/-([a-z])/g, (_, c: string) => c.toUpperCase()), v.join(':').trim()]
}))

export const Bad = ({ msg }: { msg: string }) => <span className="wf-bad" title={msg}>⚠ {msg}</span>

export function render(node: unknown, values: Scope): ReactNode {
  return one(node, values, 'root')
}

function one(n: unknown, scope: Scope, key: string): ReactNode {
  try {
    if (n === null || typeof n !== 'object' || Array.isArray(n)) throw new Error('a node must be an object')
    const node = n as Node
    if (node.each === undefined) return element(node, scope, key)
    const each = typeof node.each === 'number' ? node.each : get(node.each, scope)
    if (each === undefined) return null
    // A number n repeats n times, with 1…n as the item.
    let list: unknown[] = typeof each === 'number' ? Array.from({ length: Math.max(0, Math.floor(each)) }, (_, i) => i + 1) : each
    if (!Array.isArray(list)) throw new Error(`each "${node.each}" is not a list or a number`)
    const limit = node.limit === undefined ? Infinity : Number(typeof node.limit === 'string' ? interp(node.limit, scope) : node.limit)
    if (limit < list.length) list = list.slice(0, limit)
    const as = node.as ?? 'item'
    return list.map((item, index) => element(node, { ...scope, [as]: item, index, first: index === 0, last: index === list.length - 1 }, `${key}.${index}`))
  } catch (e) {
    return <Bad key={key} msg={e instanceof Error ? e.message : String(e)} />
  }
}

function element(n: Node, scope: Scope, key: string): ReactNode {
  if (n.if !== undefined && !holds(n.if, scope)) return null
  if (typeof n.el !== 'string' || !/^[a-z][a-z0-9-]*$/.test(n.el)) throw new Error(`el ${JSON.stringify(n.el)} is not a tag`)
  const props: Scope = { key }
  // attrsIf sets apply after attrs, in order, each when its condition holds; a later one overrides.
  const sets = [n.attrs ?? {}, ...Object.entries(n.attrsIf ?? {}).filter(([c]) => holds(c, scope)).map(([, a]) => a)]
  for (const [k, v] of sets.flatMap(a => Object.entries(a))) {
    if (/^on/i.test(k)) continue // never a handler from a file
    const val = typeof v === 'string' ? interp(v, scope) : v
    if (k === 'style') { if (typeof val === 'string') props.style = style(val) }
    else props[ATTR[k] ?? k] = val
  }
  if (n.el === 'textarea' && n.text !== undefined) props.value = interp(String(n.text), scope) // React takes a textarea's text as its value
  const classIf = Object.entries(n.classIf ?? {}).filter(([, c]) => holds(c, scope)).map(([k]) => k)
  if (n.class !== undefined || classIf.length) props.className = [props.className, n.class !== undefined && str(interp(n.class, scope)), ...classIf].filter(Boolean).join(' ')
  // Controlled-looking but read-only: the preview shows values, it doesn't take input.
  if (FORM.has(n.el) && ('value' in props || 'checked' in props)) {
    props.readOnly = true
    if ('value' in props) props.value = str(props.value)
    if ('checked' in props) props.checked = !!props.checked
  }
  if (props.contentEditable) props.suppressContentEditableWarning = true
  if (VOID.has(n.el)) return createElement(n.el, props)
  if (n.children !== undefined && !Array.isArray(n.children)) throw new Error('children must be a list')
  return createElement(n.el, props,
    n.text !== undefined && n.el !== 'textarea' ? str(interp(String(n.text), scope)) : null,
    ...(n.children ?? []).map((c, i) => one(c, scope, String(i))),
    ...(n.slot ? [0, 1].map(i => <div key={`slot${i}`} className="wf-slot">child</div>) : []))
}

// Catches what slips past the checks above (React itself refusing a node), so one bad frame doesn't take the page down.
export class Guard extends Component<{ children: ReactNode }, { error: string | null }> {
  state = { error: null as string | null }
  static getDerivedStateFromError(e: unknown) { return { error: e instanceof Error ? e.message : String(e) } }
  render() { return this.state.error ? <Bad msg={this.state.error} /> : this.props.children }
}
