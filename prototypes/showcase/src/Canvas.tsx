import { useEffect, useRef, useState } from 'react'
import { Guard, render } from './render'
import type { Primitive, Values } from './App'

type View = { x: number; y: number; z: number }

// The selected primitive as frames side by side: default, one per state, then one per example. Pan and zoom as in ../editor.
export function Canvas({ prim, name, values }: { prim: Primitive | null; name: string | null; values: Values }) {
  const vp = useRef<HTMLDivElement>(null)
  const space = useRef(false)
  const [view, setView] = useState<View>({ x: 60, y: 60, z: 1 })

  const fit = () => {
    const el = vp.current
    const world = el?.querySelector<HTMLElement>('.world')
    if (!el || !world) return
    const box = el.getBoundingClientRect(), w = world.offsetWidth, h = world.offsetHeight
    const z = Math.min(1, (box.width - 120) / w, (box.height - 140) / h)
    setView({ z, x: Math.max(60, (box.width - w * z) / 2), y: 70 })
  }
  useEffect(() => { requestAnimationFrame(fit) }, [name])

  useEffect(() => {
    const el = vp.current!
    const onWheel = (e: WheelEvent) => {
      e.preventDefault()
      if (e.ctrlKey || e.metaKey) {
        // Pinch arrives as ctrl+wheel with small deltas; a mouse notch is ~100, capped so one notch is ~15%.
        const d = Math.max(-50, Math.min(50, e.deltaY))
        const r = el.getBoundingClientRect(), px = e.clientX - r.left, py = e.clientY - r.top
        setView(v => {
          const z = Math.min(8, Math.max(0.05, v.z * Math.exp(-d * 0.003)))
          return { z, x: px - (px - v.x) * (z / v.z), y: py - (py - v.y) * (z / v.z) }
        })
      } else {
        const dx = e.deltaX, dy = e.deltaY
        setView(v => ({ ...v, x: v.x - dx, y: v.y - dy }))
      }
    }
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea, select')) return
      if (e.code === 'Space') { space.current = e.type === 'keydown'; el.classList.toggle('grab', space.current); e.preventDefault() }
      if (e.type === 'keydown' && e.shiftKey && e.code === 'Digit1') fit()
    }
    el.addEventListener('wheel', onWheel, { passive: false })
    window.addEventListener('keydown', onKey)
    window.addEventListener('keyup', onKey)
    return () => { el.removeEventListener('wheel', onWheel); window.removeEventListener('keydown', onKey); window.removeEventListener('keyup', onKey) }
  }, [])

  // Pans on middle-drag or space+drag.
  const pan = (e: React.PointerEvent) => {
    if (e.button !== 1 && !space.current) return
    e.preventDefault()
    let lx = e.clientX, ly = e.clientY
    const move = (m: PointerEvent) => {
      const dx = m.clientX - lx, dy = m.clientY - ly
      lx = m.clientX; ly = m.clientY
      setView(v => ({ ...v, x: v.x + dx, y: v.y + dy }))
    }
    const up = () => { window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up) }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
  }

  const base = prim && typeof prim.defaults === 'object' ? { ...prim.defaults, ...values } : {}
  const over = (sets: Primitive['states'] | undefined, example: boolean) =>
    Object.entries(sets ?? {}).map(([s, set]): [string, Values, boolean] => [s, { ...base, ...set }, example])
  const frames: [string, Values, boolean][] = prim ? [['default', base, false], ...over(prim.states, false), ...over(prim.examples, true)] : []
  return (
    <div className="viewport" ref={vp} onMouseDown={e => { if (e.button === 1) e.preventDefault() }} onPointerDown={pan}>
      {name && !prim && <div className="empty">{name}.json is not valid JSON: fix it in Definition</div>}
      <div className="world" style={{ transform: `translate(${view.x}px, ${view.y}px) scale(${view.z})`, ['--iz' as string]: 1 / view.z }}>
        {prim && frames.map(([title, v, example]) => (
          <div key={`${example}${title}`} className="frame-wrap" data-frame={title} data-example={example || undefined}>
            <div className="frame-title" title={title}>{example && <span className="ex">example · </span>}{title}</div>
            <div className="frame">
              <Guard key={JSON.stringify([prim.render, v])}><div className="wf">{render(prim.render, v)}</div></Guard>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
