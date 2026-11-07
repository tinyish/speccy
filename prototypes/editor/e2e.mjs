// Drives the real editor against a temporary copy of ../spec-format. Usage: node e2e.mjs
import { chromium } from 'playwright'
import { createServer } from 'vite'
import { execFileSync } from 'node:child_process'
import { cpSync, rmSync, mkdtempSync, realpathSync, readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import assert from 'node:assert/strict'

const here = import.meta.dirname
const copy = realpathSync(mkdtempSync(join(tmpdir(), 'speccy-e2e-'))) // check.mjs only runs as main from its real path
cpSync(join(here, '../spec-format'), copy, { recursive: true, preserveTimestamps: true })
// Run on the task example, not on whatever the live spec holds.
for (const sub of ['data', 'components', 'screens']) {
  rmSync(join(copy, sub), { recursive: true, force: true })
  cpSync(join(here, '../spec-format/example', sub), join(copy, sub), { recursive: true, preserveTimestamps: true })
}
writeFileSync(join(copy, 'screens/Screen 1.json'), JSON.stringify({ screen: 'Screen 1', device: 'mobile', layout: 'column' }, null, 2) + '\n') // renamed below
const shots = join(here, 'screenshots')
mkdirSync(shots, { recursive: true })

const files = dir => readdirSync(dir, { recursive: true }).filter(f => statSync(join(dir, f)).isFile()).sort()
const snapshot = dir => files(dir).map(f => `${f} ${createHash('sha1').update(readFileSync(join(dir, f))).digest('hex')} ${statSync(join(dir, f)).mtimeMs}`).join('\n')
const json = f => JSON.parse(readFileSync(join(copy, f), 'utf8'))
const check = () => { try { return execFileSync('node', [join(copy, 'check.mjs'), copy]).toString().trim() } catch (e) { return e.stdout.toString().trim() } }
const pass = msg => console.log('PASS', msg)

process.env.SPEC_DIR = copy
const server = await createServer({ root: here, configFile: join(here, 'vite.config.ts'), server: { port: 5310 }, logLevel: 'warn' })
await server.listen()
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
const pageErrors = []
page.on('pageerror', e => pageErrors.push(e.message))
page.on('console', m => { if (m.type() === 'error') pageErrors.push(m.text()) })

const tab = name => page.click(`.rail button[title=${name}]`)
const section = title => page.locator('.sec', { has: page.locator('.sec-head', { hasText: title }) })
const saved = async () => { await page.waitForTimeout(400); await page.locator('.status', { hasText: /^Saved$/ }).waitFor() }
const center = async loc => { const b = await loc.boundingBox(); return { x: b.x + b.width / 2, y: b.y + b.height / 2, b } }
// A real mouse drag from one point to another.
const dragTo = async (from, to, button = 'left') => {
  await page.mouse.move(from.x, from.y)
  await page.mouse.down({ button })
  await page.mouse.move(to.x, to.y, { steps: 12 })
  await page.mouse.up({ button })
}
const view = () => page.evaluate(() => {
  const m = document.querySelector('.world').style.transform.match(/translate\(([-\d.]+)px, ([-\d.]+)px\) scale\(([\d.]+)\)/)
  return { x: +m[1], y: +m[2], z: +m[3] }
})
const field = async (label, value) => { await page.fill(`input[aria-label="${label}"]`, String(value)); await page.press(`input[aria-label="${label}"]`, 'Enter') }

try {
  // 1. Loading and looking around writes nothing.
  const before = snapshot(copy)
  await page.goto(server.resolvedUrls.local[0])
  await page.waitForSelector('.frame')
  for (const t of ['Screens', 'Data', 'Components']) { await tab(t); await page.waitForSelector('.frame') }
  await tab('Screens')
  await page.click('.item:has-text("TaskScreen")')
  await page.click('[data-group=loading] .lgroup-head')
  await page.waitForTimeout(1200)
  assert.equal(snapshot(copy), before)
  pass('opening every tab and selecting items and states wrote nothing (hashes and mtimes unchanged)')

  // 2. Pan with the middle button and with space+drag; zoom at a sane speed.
  const vp = await page.locator('.viewport').boundingBox()
  const empty = { x: vp.x + 40, y: vp.y + vp.height - 120 }
  let v0 = await view()
  await dragTo(empty, { x: empty.x + 120, y: empty.y - 60 }, 'middle')
  let v1 = await view()
  assert.deepEqual([Math.round(v1.x - v0.x), Math.round(v1.y - v0.y)], [120, -60])
  pass('middle-drag panned by exactly the mouse movement (120, -60)')
  v0 = v1
  await page.keyboard.down('Space')
  const onFrame = await center(page.locator('[data-frame=TaskScreen][data-state=""] .frame'))
  await dragTo(onFrame, { x: onFrame.x - 80, y: onFrame.y + 40 })
  await page.keyboard.up('Space')
  v1 = await view()
  assert.deepEqual([Math.round(v1.x - v0.x), Math.round(v1.y - v0.y)], [-80, 40])
  assert.equal(await page.locator('.n.sel').count(), 0)
  pass('space+drag panned by (-80, 40), even starting on a frame, and selected nothing')
  await page.mouse.move(vp.x + 300, vp.y + 300)
  v0 = await view()
  await page.keyboard.down('Control'); await page.mouse.wheel(0, -100); await page.keyboard.up('Control')
  v1 = await view()
  const notch = v1.z / v0.z
  assert.ok(notch > 1.05 && notch < 1.3, `one wheel notch zoomed ×${notch}`)
  for (let i = 0; i < 10; i++) { await page.keyboard.down('Control'); await page.mouse.wheel(0, -4); await page.keyboard.up('Control') }
  const pinch = (await view()).z / v1.z
  assert.ok(pinch > 1.05 && pinch < 1.25, `ten pinch events zoomed ×${pinch}`)
  pass(`ctrl+wheel: one mouse notch zooms ×${notch.toFixed(3)}, ten small pinch steps ×${pinch.toFixed(3)}`)

  // 3. Build a component: layout containers from the toolbar, then reorder and move by dragging.
  await tab('Components')
  await page.click('.items-head .icon[title=New]')
  const name = (await page.locator('.item.sel .nm').textContent()).trim()
  const file = `components/${name}.json`
  const base = page.locator(`[data-frame="${name}"][data-state=""]`)
  const tile = t => center(page.locator(`.toolbar [data-tool="${t}"]`))
  await page.waitForTimeout(300)
  await dragTo(await tile('@row'), await center(base.locator('.frame')))
  await base.locator('[data-inst=row]').waitFor()
  await dragTo(await tile('text'), await center(base.locator('[data-inst=row]')))
  const rowBox = (await base.locator('[data-inst=row]').boundingBox())
  await dragTo(await tile('button'), { x: rowBox.x + rowBox.width - 4, y: rowBox.y + rowBox.height / 2 })
  const fr = await base.locator('.frame').boundingBox()
  await dragTo(await tile('@column'), { x: fr.x + fr.width / 2, y: fr.y + fr.height - 4 })
  await saved()
  let c = json(file)
  assert.deepEqual(c.children.map(i => i.id), ['row', 'column'])
  assert.deepEqual(c.children[0].children.map(i => i.id), ['text', 'button'])
  pass('dropped row, text, button and column from the toolbar into the right places')
  const textEl = await center(base.locator('[data-inst=text]'))
  await dragTo(await center(base.locator('[data-inst=button]')), { x: textEl.b.x + 2, y: textEl.y })
  await saved()
  assert.deepEqual(json(file).children[0].children.map(i => i.id), ['button', 'text'])
  pass('dragged the button before the text inside the row')
  await dragTo(await center(base.locator('[data-inst=text]')), await center(base.locator('[data-inst=column]')))
  await saved()
  c = json(file)
  assert.deepEqual([c.children[0].children.map(i => i.id), c.children[1].children.map(i => i.id)], [['button'], ['text']])
  pass('dragged the text out of the row into the column')
  await dragTo(await center(page.locator('.layer[data-id=column]').first()), await (async () => { const b = await page.locator('.layer[data-id=row]').first().boundingBox(); return { x: b.x + 40, y: b.y + 3 } })())
  await saved()
  assert.deepEqual(json(file).children.map(i => i.id), ['column', 'row'])
  pass('dragged the column layer above the row in the layers panel')

  // 4. A fixed width, resized by its handle.
  await base.locator('[data-inst=button]').click()
  await page.selectOption('select[aria-label="width mode"]', 'fixed')
  await saved()
  const w0 = json(file).children[1].children[0].width
  assert.equal(typeof w0, 'number')
  const z = (await view()).z
  const h = await center(base.locator('[data-inst=button] .handle.hw'))
  await dragTo(h, { x: h.x + 60 * z, y: h.y })
  await saved()
  const w1 = json(file).children[1].children[0].width
  assert.ok(Math.abs(w1 - (w0 + 60)) <= 1, `${w0} -> ${w1}`)
  assert.equal(Math.round((await base.locator('[data-inst=button]').boundingBox()).width / z), w1)
  pass(`switched the button to Fixed (${w0}px) and dragged its handle to ${w1}px; the canvas draws it at ${w1}px`)

  // 5. Gap, padding, align and wrap, seen on the canvas.
  await base.locator('[data-inst=row]').click({ position: { x: 2, y: 2 } })
  await field('gap', 20)
  await field('padding horizontal', 24)
  await field('padding vertical', 4)
  await page.click('.align [data-align=center]')
  await page.check('input[aria-label=wrap]')
  await saved()
  const row = json(file).children[1]
  assert.deepEqual([row.gap, row.padding, row.align, row.wrap], [20, [4, 24], 'center', true])
  const css = await base.locator('[data-inst=row]').evaluate(e => { const s = getComputedStyle(e); return [s.rowGap, s.padding, s.justifyContent, s.alignItems, s.flexWrap] })
  assert.deepEqual(css, ['20px', '4px 24px', 'center', 'center', 'wrap'])
  pass(`set gap 20, padding 4/24, align center, wrap: file has them and the canvas draws ${css.join(' / ')}`)
  await page.screenshot({ path: join(shots, 'layout-panel.png') })

  // 6. Edit an instance in a state frame: it writes to that state's set.
  await page.click('.items .item.sel') // back to the item, then add a state
  await section('States').locator('.sec-head .icon').click()
  await page.fill('textarea[aria-label="state about"]', 'Narrow layout.')
  await page.locator('textarea[aria-label="state about"]').blur()
  const st = page.locator(`[data-frame="${name}"][data-state=state]`)
  await st.locator('[data-inst=button]').click()
  await page.check('input[aria-label=hidden]')
  await st.locator('[data-inst=row]').waitFor()
  await st.locator('[data-inst=row]').click({ position: { x: 2, y: 2 } })
  await field('gap', 4)
  await saved()
  c = json(file)
  assert.deepEqual(c.states.state, { about: 'Narrow layout.', set: { 'button.hidden': true, 'row.gap': 4 } })
  assert.equal(c.children[1].gap, 20)
  assert.equal(await st.locator('[data-inst=button]').count(), 0)
  assert.equal(await base.locator('[data-inst=button]').count(), 1)
  assert.equal(await page.locator('[data-size] .mark, .row .mark').count() > 0, true)
  pass('in the state frame: hiding the button and setting the row gap wrote {"button.hidden": true, "row.gap": 4} to the state; the base is untouched')

  // 7. Toolbar: drag an icon out to remove it; add a component from the palette; Enter inserts.
  await dragTo(await tile('input'), { x: 1300, y: 500 })
  assert.equal(await page.locator('.toolbar [data-tool=input]').count(), 0)
  assert.ok(!JSON.parse(await page.evaluate(() => localStorage.getItem('speccy.toolbar'))).includes('input'))
  pass('dragging the input icon out of the toolbar removed it (and from localStorage)')
  await page.click('.toolbar [data-tool=search]')
  await page.waitForSelector('.palette')
  await page.screenshot({ path: join(shots, 'palette.png') })
  await page.fill('.pal-q', 'TaskRo')
  const bar = await page.locator('.toolbar').boundingBox()
  await dragTo(await center(page.locator('.pal-row[data-tool=TaskRow]')), { x: bar.x + bar.width - 6, y: bar.y + bar.height / 2 })
  await page.locator('.toolbar [data-tool=TaskRow]').waitFor()
  assert.equal(await page.locator('.toolbar [data-tool=TaskRow]').getAttribute('title'), 'TaskRow')
  pass('dragged TaskRow from the palette into the toolbar: it shows with the component icon and a tooltip')
  await base.locator('[data-inst=column]').click({ position: { x: 2, y: 2 } })
  await page.click('.toolbar [data-tool=search]')
  await page.fill('.pal-q', 'link')
  await page.press('.pal-q', 'Enter')
  await saved()
  assert.deepEqual(json(file).children[0].children.map(i => i.id), ['text', 'link'])
  pass('palette: typing "link" and Enter inserted a link into the selected column')
  await page.click('.toolbar [data-tool=search]')
  await page.fill('.pal-q', 'textarea')
  await dragTo(await center(page.locator('.pal-row[data-tool=textarea]')), await center(base.locator('[data-inst=row]')))
  await saved()
  assert.deepEqual(json(file).children[1].children.map(i => i.use), ['button', 'textarea'])
  pass('dragged textarea from the palette onto the row on the canvas')

  // 8. Lists: as many rows as fit, or exactly the limit.
  await page.click('.item:has-text("TaskList")')
  const rows = () => page.locator('[data-frame=TaskList][data-state=""] .n-comp').count()
  const fitRows = await rows()
  assert.equal(fitRows, 3) // its frame hugs, so nothing bounds the list: the default 3
  await page.locator('[data-frame=TaskList][data-state=""] [data-inst=row]').first().click()
  await field('repeat limit', 2)
  await saved()
  assert.equal(await rows(), 2)
  assert.equal(json('components/TaskList.json').children[0].children[0].repeat.limit, 2)
  await field('repeat limit', '')
  await saved()
  pass(`TaskList (a hugging frame) draws ${fitRows} rows with no limit and exactly 2 with limit 2`)

  // 9. Screens: device switch, and every state side by side.
  await tab('Screens')
  await page.click('.item:has-text("TaskScreen")')
  const ts = page.locator('[data-frame=TaskScreen][data-state=""]')
  assert.match(await ts.locator('.frame-title').textContent(), /TaskScreen\s*Mobile 390×844/)
  await ts.locator('.ft-size').click()
  await page.click('.menu-item:has-text("Tablet")')
  await saved()
  assert.equal(json('screens/TaskScreen.json').device, 'tablet')
  assert.equal(await ts.locator('.frame').evaluate(e => e.offsetWidth), 834)
  await ts.locator('.ft-size').click()
  await page.click('.menu-item:has-text("Mobile")')
  await saved()
  assert.equal(json('screens/TaskScreen.json').device, 'mobile')
  pass('the size menu switched TaskScreen to Tablet (834px wide, written) and back to Mobile')
  await page.click('.item:has-text("Screen 1")')
  await page.click('[data-frame="Screen 1"][data-state=""] .ft-name')
  await page.fill('.ft-input', 'Home')
  await page.press('.ft-input', 'Enter')
  await saved()
  assert.equal(json('screens/Home.json').screen, 'Home')
  assert.ok(!files(copy).includes('screens/Screen 1.json'))
  pass('clicking the frame title renamed Screen 1 to Home (file moved)')
  await page.click('.item:has-text("TaskScreen")')
  const screenRows = await ts.locator('.n-comp .chip').count()
  assert.ok(screenRows > 3, `${screenRows} rows`)
  assert.deepEqual(await page.locator('[data-frame=TaskScreen]').evaluateAll(f => f.map(x => x.dataset.state)), ['', 'offline', 'loading', 'empty', 'error'])
  pass(`TaskScreen shows base + 4 state frames; its list fills the screen with ${screenRows} rows`)
  await page.keyboard.press('Shift+Digit1')
  await page.click('.items .item.sel')
  await page.waitForTimeout(300)
  await page.screenshot({ path: join(shots, 'screens.png') })

  // 10. Components screenshot: TaskRow with its states.
  await tab('Components')
  await page.click('.item:has-text("TaskRow")')
  await page.waitForTimeout(400)
  await page.screenshot({ path: join(shots, 'components.png') })

  // 11. Outside edits show up live; the checker is happy.
  const bannerPath = join(copy, 'components/Banner.json')
  writeFileSync(bannerPath, JSON.stringify({ ...json('components/Banner.json'), about: 'Edited by an agent.' }, null, 2) + '\n')
  await page.click('.item:has-text("Banner")')
  await page.waitForFunction(() => document.querySelector('textarea[aria-label=about]')?.value === 'Edited by an agent.', null, { timeout: 5000 })
  pass('an outside edit to Banner.json showed up in the open editor')
  assert.equal(check(), 'ok')
  pass('check.mjs on the copy prints "ok" after all of it')
  console.log(readFileSync(join(copy, file), 'utf8'))

  assert.deepEqual(pageErrors, [])
  pass('no page errors')
  console.log('spec copy at', copy)
} finally {
  await browser.close()
  await server.close()
}
