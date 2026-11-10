// WKWebView hands a trackpad pinch to the page as Safari's gesture events, not as the
// ctrl+wheel Chromium sends: replay each step as ctrl+wheel so the spike's hook zooms.
let pinch = 1
document.addEventListener('gesturestart', e => { e.preventDefault(); pinch = 1 })
document.addEventListener('gestureend', e => e.preventDefault())
document.addEventListener('gesturechange', e => {
  e.preventDefault()
  // the hook zooms by exp(-deltaY * 0.01)
  const deltaY = -100 * Math.log(e.scale / pinch)
  pinch = e.scale
  document.getElementById('canvas')?.dispatchEvent(new WheelEvent('wheel',
    { deltaY, ctrlKey: true, clientX: e.clientX, clientY: e.clientY, bubbles: true, cancelable: true }))
})

// ?selftest: drive the hook with DOM events inside this webview and post the timings.
if (new URLSearchParams(location.search).has('selftest')) addEventListener('load', async () => {
  const $ = s => document.querySelector(s)
  const sleep = ms => new Promise(r => setTimeout(r, ms))
  const frame = () => new Promise(requestAnimationFrame)
  const waitFor = (test, ms = 5000) => new Promise((resolve, reject) => {
    if (test()) return resolve()
    const mo = new MutationObserver(() => { if (test()) { mo.disconnect(); resolve() } })
    mo.observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true })
    setTimeout(() => { mo.disconnect(); reject(new Error('timeout')) }, ms)
  })
  const median = xs => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)]
  const hud = () => $('#hud')
  // the hook writes "<what>: <ms>ms round trip (server <ms>ms)" when the server replies
  const roundTrip = async run => {
    hud().textContent = ''
    await run()
    await waitFor(() => hud().textContent)
    const [, rt, server] = hud().textContent.match(/([\d.]+)ms round trip \(server ([\d.]+)ms\)/)
    await sleep(60)
    return { rt: +rt, server: +server }
  }
  const view = () => { const m = $('.world').style.transform.match(/translate\(([-\d.]+)px, ([-\d.]+)px\) scale\(([\d.]+)\)/); return { x: +m[1], y: +m[2], z: +m[3] } }
  const pointer = (type, target, x, y, button = 0) => target.dispatchEvent(new PointerEvent(type,
    { clientX: x, clientY: y, button, buttons: 1 << button, pointerId: 1, isPrimary: true, bubbles: true, cancelable: true }))
  const canvas = () => $('#canvas')
  const report = {}

  try {
    await waitFor(() => $('.phx-connected') && $('.world')?.style.transform)
    report.ua = navigator.userAgent
    report.editing = $('.path').textContent
    report.frames = document.querySelectorAll('[data-frame]').length
    report.hasFocus = document.hasFocus()
    report.gestureEvents = typeof GestureEvent !== 'undefined'
    report.touchEvents = 'ontouchstart' in window

    // Reorder: drag the base frame's first top-level instance below its last.
    const reorders = []
    for (let i = 0; i < 10; i++) {
      reorders.push(await roundTrip(async () => {
        const items = [...document.querySelectorAll('[data-frame=base] > [data-drag]')]
        const a = items[0].getBoundingClientRect(), last = items.at(-1).getBoundingClientRect()
        const x = a.left + a.width / 2, y = a.top + 5
        pointer('pointerdown', items[0], x, y)
        pointer('pointermove', window, x, y + 20)
        pointer('pointermove', window, x, last.bottom + 5)
        pointer('pointerup', window, x, last.bottom + 5)
      }))
    }
    report.reorder = { rt: median(reorders.map(r => r.rt)), server: median(reorders.map(r => r.server)), n: reorders.length }

    // Copy edit in place: double-click, the text becomes contenteditable and focused, Enter commits.
    const edit = async (frameKey, key, value) => {
      let focused
      const r = await roundTrip(async () => {
        const t = $(`[data-frame=${frameKey}] [data-edit="${key}"]`)
        t.dispatchEvent(new MouseEvent('dblclick', { bubbles: true, cancelable: true, detail: 2 }))
        focused = t.isContentEditable && document.activeElement === t && getSelection().toString() === t.textContent
        t.textContent = value
        t.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }))
      })
      return { ...r, focused }
    }
    const edits = []
    for (let i = 0; i < 10; i++) edits.push(await edit('base', 'header.title', `Tasks ${i}`))
    report.edit = { rt: median(edits.map(r => r.rt)), server: median(edits.map(r => r.server)), n: edits.length, focusedAndSelected: edits.every(e => e.focused) }
    report.stateEdit = await edit('empty', 'empty.message', `Nothing here yet (${Date.now()})`)

    // An outside write to the file, until the base frame shows it (includes the spike's 300 ms poll).
    const outside = []
    for (let i = 0; i < 5; i++) {
      const value = `Outside ${i}`, t0 = performance.now()
      await fetch('/selftest/outside', { method: 'POST', body: JSON.stringify({ key: 'header.title', value }) })
      await waitFor(() => $('[data-frame=base] [data-edit="header.title"]')?.textContent === value)
      outside.push(performance.now() - t0)
      await sleep(100)
    }
    report.outside = { median: median(outside), n: outside.length }

    // Pan and zoom: wheel, ctrl+wheel, a pinch as gesture events, space+drag, middle-drag.
    const wheel = init => { const e = new WheelEvent('wheel', { clientX: 400, clientY: 300, bubbles: true, cancelable: true, ...init }); canvas().dispatchEvent(e); return e.defaultPrevented }
    let v0 = view()
    const gaps = []
    let t = performance.now()
    for (let i = 0; i < 120; i++) { await frame(); const now = performance.now(); gaps.push(now - t); t = now; wheel({ deltaX: 2, deltaY: 1 }) }
    const v1 = view()
    report.wheelPan = { moved: [v0.x - v1.x, v0.y - v1.y], frameMs: { median: median(gaps), max: Math.max(...gaps) } }
    v0 = view(); report.ctrlWheelZoom = { prevented: wheel({ deltaY: -50, ctrlKey: true }), ratio: view().z / v0.z }
    v0 = view(); wheel({ deltaY: 50, metaKey: true }); report.metaWheelZoom = { ratio: view().z / v0.z }
    const gesture = (type, scale) => { const e = new Event(type, { bubbles: true, cancelable: true }); Object.defineProperties(e, { scale: { value: scale }, clientX: { value: 400 }, clientY: { value: 300 } }); canvas().dispatchEvent(e); return e.defaultPrevented }
    v0 = view(); gesture('gesturestart', 1); gesture('gesturechange', 1.2); const prevented = gesture('gesturechange', 1.5); gesture('gestureend', 1.5)
    report.pinchZoom = { prevented, ratio: view().z / v0.z }
    v0 = view()
    window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Space', key: ' ', bubbles: true, cancelable: true }))
    pointer('pointerdown', canvas(), 500, 500); pointer('pointermove', window, 540, 530); pointer('pointerup', window, 540, 530)
    window.dispatchEvent(new KeyboardEvent('keyup', { code: 'Space', key: ' ', bubbles: true }))
    let v = view(); report.spacePan = [v.x - v0.x, v.y - v0.y]
    v0 = v; pointer('pointerdown', canvas(), 500, 500, 1); pointer('pointermove', window, 470, 480); pointer('pointerup', window, 470, 480)
    v = view(); report.middlePan = [v.x - v0.x, v.y - v0.y]
    report.ok = true
  } catch (e) { report.error = String(e.stack || e) }
  await fetch('/selftest/report', { method: 'POST', body: JSON.stringify(report) })
})
