// Drives the real showcase against a temporary copy of fixtures/primitives, then draws every primitive of a copy of the live
// catalog into screenshots/all/. Usage: node e2e.mjs, or node e2e.mjs catalog [name…] for the second part only.
import { chromium } from 'playwright'
import { createServer } from 'vite'
import { cpSync, mkdtempSync, realpathSync, readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import assert from 'node:assert/strict'

const here = import.meta.dirname
const shots = join(here, 'screenshots')
mkdirSync(shots, { recursive: true })
const copyOf = src => { const d = realpathSync(mkdtempSync(join(tmpdir(), 'speccy-showcase-'))); cpSync(src, d, { recursive: true, preserveTimestamps: true }); return d }
const snapshot = dir => readdirSync(dir).sort().map(f => `${f} ${createHash('sha1').update(readFileSync(join(dir, f))).digest('hex')} ${statSync(join(dir, f)).mtimeMs}`).join('\n')
const pass = msg => console.log('PASS', msg)

async function open(dir, port, viewport = { width: 1440, height: 900 }) {
  process.env.PRIMITIVES_DIR = dir
  const server = await createServer({ root: here, configFile: join(here, 'vite.config.ts'), server: { port }, logLevel: 'warn' })
  await server.listen()
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport })
  const errors = []
  page.on('pageerror', e => errors.push(e.message))
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()) })
  await page.goto(server.resolvedUrls.local[0])
  await page.waitForSelector('.item')
  return { server, browser, page, errors, close: async () => { await browser.close(); await server.close() } }
}

// 1. Fixtures: every feature, against a copy.
const [mode, ...only] = process.argv.slice(2)
if (mode !== 'catalog') await fixtures()
async function fixtures() {
const copy = copyOf(join(here, 'fixtures/primitives'))
const json = name => JSON.parse(readFileSync(join(copy, `${name}.json`), 'utf8'))
const write = (name, content) => writeFileSync(join(copy, `${name}.json`), JSON.stringify(content, null, 2) + '\n')
const before = snapshot(copy)
const { page, errors: pageErrors, close } = await open(copy, 5320)
const pick = name => page.click(`.item[data-name="${name}"]`)
const frame = title => page.locator(`[data-frame="${title}"] .frame`)
const frames = () => page.locator('.frame-wrap').evaluateAll(f => f.map(x => x.dataset.frame))
const def = page.locator('textarea[aria-label=definition]')
const status = () => page.locator('[data-sec=Definition] .status').textContent()
const editDef = async fn => { const p = JSON.parse(await def.inputValue()); fn(p); await def.fill(JSON.stringify(p, null, 2)); await page.waitForTimeout(700) }

try {
  for (const n of ['tree-view', 'dialog', 'slider', 'button', 'checkbox']) { await pick(n); await page.waitForSelector('.frame') }
  await page.waitForTimeout(1000)
  assert.equal(snapshot(copy), before)
  pass('loading and selecting every fixture wrote nothing (hashes and mtimes unchanged)')

  assert.deepEqual(await frames(), ['default', 'checked', 'indeterminate', 'invalid', 'disabled'])
  assert.equal(await frame('default').locator('.wf-selected').count(), 0)
  assert.equal(await frame('checked').locator('.wf-selected').count(), 1)
  assert.equal(await frame('disabled').locator('.wf-disabled').count(), 1)
  assert.match(await page.locator('[data-sec=Info]').textContent(), /selection.*Checkboxes.*Switch.*Checkbox.*Toggle/s)
  assert.equal(await page.locator('[data-sec=Info] a', { hasText: 'Toggle' }).getAttribute('target'), '_blank')
  await page.screenshot({ path: join(shots, 'checkbox.png') })
  pass('checkbox shows a frame per state, each drawn per its state; Info links to both kits in a new tab')

  // 2. Preview a prop: every frame follows, the file doesn't.
  await page.fill('input[aria-label=label]', 'Dark mode')
  await page.check('input[aria-label=checked]')
  assert.equal(await page.locator('.frame', { hasText: 'Dark mode' }).count(), 5)
  assert.equal(await frame('default').locator('.wf-selected').count(), 1)
  assert.equal(json('checkbox').defaults.label, 'Remember me')
  pass('previewing label "Dark mode" and checked redrew all five frames and wrote nothing')
  await page.click('[data-prop=label] button:has-text("save as default")')
  await page.waitForTimeout(400)
  assert.equal(json('checkbox').defaults.label, 'Dark mode')
  assert.equal(json('checkbox').defaults.checked, false)
  assert.equal(readFileSync(join(copy, 'checkbox.json'), 'utf8').endsWith('}\n'), true)
  await page.click('[data-prop=checked] button:has-text("reset")')
  assert.equal(await frame('default').locator('.wf-selected').count(), 0)
  pass('"save as default" wrote label to the file (pretty, trailing newline); reset dropped the checked preview')
  await page.selectOption('select[aria-label=role]', 'switch')
  assert.equal(await frame('checked').locator('.wf-pill.wf-selected .wf-thumb').count(), 1)
  assert.equal(await frame('default').locator('.wf-box').count(), 0)
  await page.click('[data-prop=role] button:has-text("reset")')
  pass('previewing role switch drew the switch track and thumb in place of the box')

  // 3. Edit the definition: saved and redrawn.
  await editDef(p => { p.defaults.hint = 'Edited in the showcase'; p.states.loud = { label: 'LOUD' } })
  assert.equal(await status(), 'Saved')
  assert.equal(json('checkbox').defaults.hint, 'Edited in the showcase')
  assert.deepEqual(await frames(), ['default', 'checked', 'indeterminate', 'invalid', 'disabled', 'loud'])
  assert.match(await frame('default').textContent(), /Edited in the showcase/)
  assert.match(await frame('loud').textContent(), /LOUD/)
  pass('a definition edit (new hint, new state) was saved to the copy and drawn: a "loud" frame appeared')

  // 4. Invalid edits are refused and say why.
  const saved = readFileSync(join(copy, 'checkbox.json'), 'utf8')
  await editDef(p => { p.render.children[1].class = 'wf-hint wf-shiny'; p.states.checked.checked = 'yes' })
  assert.equal(await status(), 'Not saved')
  const why = await page.locator('[data-sec=Definition] .err').allTextContents()
  assert.deepEqual(why, ['checkbox: state checked: checked should be bool, got "yes"', 'checkbox: render.children[1]: unknown class wf-shiny'])
  await page.locator('[data-sec=Definition] .err').last().scrollIntoViewIfNeeded()
  await page.screenshot({ path: join(shots, 'rejected.png') })
  await def.fill('{ "name": ')
  await page.waitForTimeout(600)
  assert.equal(await status(), 'Not saved')
  assert.match(await page.locator('[data-sec=Definition] .err').first().textContent(), /JSON/)
  assert.equal(readFileSync(join(copy, 'checkbox.json'), 'utf8'), saved)
  pass(`an unknown class and a wrong state type were refused (${why.length} reasons shown), so was broken JSON; the file is unchanged`)

  // 5. Outside changes show up live.
  await pick('slider')
  write('slider', { ...json('slider'), defaults: { ...json('slider').defaults, label: 'Volume by agent' } })
  await page.locator('.frame', { hasText: 'Volume by agent' }).first().waitFor({ timeout: 5000 })
  assert.match(await def.inputValue(), /Volume by agent/)
  write('badge', { ...json('button'), name: 'badge', category: 'data-display', about: 'Added by an agent.' })
  await page.locator('.item[data-name=badge]').waitFor({ timeout: 5000 })
  assert.equal(await page.locator('[data-testid=count]').textContent(), '6 primitives')
  pass('an outside edit to slider.json redrew it live; a new badge.json appeared in the list (6 primitives)')
  write('broken', { ...json('button'), name: 'broken', render: { el: 'div', class: 'wf-sparkle' } })
  await page.locator('.item[data-name=broken] .dot').waitFor({ timeout: 5000 })
  await page.click('.badge')
  await page.click('.error:has-text("broken: render: unknown class wf-sparkle")')
  assert.equal(await page.locator('.item.sel').getAttribute('data-name'), 'broken')
  pass('an invalid outside file got a red dot; the top bar error list selected it')

  // 6. Model props, slots, nested lists.
  await pick('tree-view')
  const items = json('tree-view').defaults.items
  await page.fill('textarea[aria-label=items]', JSON.stringify([...items, { label: 'README.md' }], null, 2))
  await frame('default').locator('text=README.md').waitFor()
  await page.fill('textarea[aria-label=items]', '[{"label":')
  assert.match(await page.locator('[data-prop=items] .err').textContent(), /JSON/)
  assert.equal(await frame('default').locator('text=README.md').count(), 1)
  assert.equal(await frame('default').locator('.wf-selected', { hasText: 'index.ts' }).count(), 1)
  await page.screenshot({ path: join(shots, 'tree-view.png') })
  pass('tree-view draws nested items with the selected one marked; a model[] preview edit redrew it, a broken one shows its parse error')
  await pick('dialog')
  assert.equal(await frame('open').locator('.wf-slot').count(), 2)
  await page.screenshot({ path: join(shots, 'dialog.png') })
  pass('dialog\'s open frame draws two placeholder boxes in its slot')
  await pick('button')
  assert.deepEqual(await page.locator('[data-example]').evaluateAll(f => f.map(x => x.dataset.frame)), Object.keys(json('button').examples))
  assert.match(await page.locator('[data-sec=Examples]').textContent(), /icon only selected.*selected: true/)
  assert.equal(await frame('icon only').locator('button.wf-btn-icon .wf-symbol').textContent(), 'favorite')
  pass('button draws its examples after its states, and the panel lists them under Examples')

  assert.deepEqual(pageErrors, [])
  pass('no page errors')
} finally {
  await close()
}

}

// 7. The live catalog, from a copy: every primitive draws without error boxes, each into screenshots/all/<name>.png, and nothing is written.
const live = join(here, '../catalog/primitives')
const c2 = copyOf(live)
const b2 = snapshot(c2)
const all = join(shots, 'all')
mkdirSync(all, { recursive: true })
{
  const { page, errors, close } = await open(c2, 5321, { width: 2600, height: 1400 })
  try {
    const names = (await page.locator('.item').evaluateAll(r => r.map(x => x.dataset.name))).filter(n => !only.length || only.includes(n))
    const bad = []
    for (const n of names) {
      await page.click(`.item[data-name="${n}"]`)
      await page.waitForTimeout(150)
      await page.evaluate(() => document.fonts.ready) // Material Symbols glyphs
      const k = await page.locator('.wf .wf-bad').count()
      if (k || !(await page.locator('.frame').count())) bad.push(`${n} (${k} error boxes)`)
      // Just the frames and their titles, at the zoom fit chose (1 unless they don't fit).
      const boxes = await page.locator('.frame-wrap').evaluateAll(f => f.map(x => x.getBoundingClientRect()).map(r => [r.left, r.top, r.right, r.bottom]))
      const x = Math.min(...boxes.map(b => b[0])) - 16, y = Math.min(...boxes.map(b => b[1])) - 30
      await page.screenshot({ path: join(all, `${n}.png`), clip: { x, y, width: Math.max(...boxes.map(b => b[2])) + 16 - x, height: Math.max(...boxes.map(b => b[3])) + 16 - y } })
    }
    assert.equal(snapshot(c2), b2)
    console.log(`catalog: ${names.length} primitives drawn into screenshots/all/, ${await page.locator('.item .dot').count()} with validation errors; nothing written`)
    assert.deepEqual(bad, [])
    pass('every catalog primitive drew without error boxes')
    assert.deepEqual([...new Set(errors)], [])
    pass('no page errors on the catalog')
  } finally {
    await close()
  }
}
