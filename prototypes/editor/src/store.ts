import { createContext, useContext, type CSSProperties } from 'react'
import type { Kind, Rec, Spec } from './spec'

export type Sel = { item: string | null; inst: string | null; state: string | null }
export type View = { x: number; y: number; z: number }
// What the floating drag ghost and the blue insertion line show.
export type DragUI = { label: string; x: number; y: number; line?: CSSProperties; into?: CSSProperties; remove?: boolean } | null
export type App = {
  spec: Spec
  tab: Kind
  sel: Sel
  select: (item: string | null, inst?: string | null, state?: string | null) => void
  edit: (fn: (s: Spec) => void) => void
  notify: (msg: string) => void
  errorItems: Set<string>
  view: View
  setView: (fn: (v: View) => View) => void
  setDrag: (d: DragUI) => void
}

export const AppCtx = createContext<App>(null!)
export const useApp = () => useContext(AppCtx)

export const PRIMS = ['container', 'text', 'button', 'input', 'textarea', 'select', 'link', 'list', 'form', 'dialog']
export const GLYPH: Rec<string> = { container: '□', text: 'T', button: '▭', input: '⌶', textarea: '¶', select: '▾', link: '↗', list: '☰', form: '▤', dialog: '◳' }
export const glyph = (use: string) => GLYPH[use] ?? '◇'

// Follows the pointer after a pointerdown until it's released. Moves start once past `threshold` px;
// onUp says whether they did, so a press that never moved can count as a click.
export function track(e: { clientX: number; clientY: number }, threshold: number, onMove: (x: number, y: number) => void, onUp: (moved: boolean) => void) {
  const sx = e.clientX, sy = e.clientY
  let moved = threshold === 0
  const move = (m: PointerEvent) => {
    if (!moved && Math.hypot(m.clientX - sx, m.clientY - sy) < threshold) return
    moved = true
    onMove(m.clientX, m.clientY)
  }
  const up = () => {
    window.removeEventListener('pointermove', move)
    window.removeEventListener('pointerup', up)
    onUp(moved)
  }
  window.addEventListener('pointermove', move)
  window.addEventListener('pointerup', up)
}
