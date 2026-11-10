import { test, expect } from '@playwright/test'
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')

// A temp copy of the tasks fixture, never the fixture itself, removed after the test.
const temps = []
function copy() {
  const temp = mkdtempSync(join(tmpdir(), 'speccy-e2e-'))
  temps.push(temp)
  const dir = join(temp, 'tasks')
  cpSync(join(root, 'test/fixtures/specs/tasks'), dir, { recursive: true })
  return dir
}
test.afterEach(() => { for (const temp of temps.splice(0)) rmSync(temp, { recursive: true, force: true }) })

async function open(page, dir) {
  await page.goto('/?' + new URLSearchParams({ spec: dir }))
  await expect(page.locator('.phx-connected')).toBeAttached()
}

const base = '#world figure:not([data-state]) .wf'

test('an edit to a screen file from outside shows on the canvas without a reload', async ({ page }) => {
  const dir = copy()
  await open(page, dir)
  const title = page.locator(`${base} [data-chain="header/title"]`)
  await expect(title).toHaveText('Tasks')
  await page.evaluate(() => (window.sameDocument = true))

  const file = join(dir, 'screens/TaskScreen.json')
  writeFileSync(file, readFileSync(file, 'utf8').replace('"title": "Tasks"', '"title": "Chores"'))

  await expect(title).toHaveText('Chores')
  expect(await page.evaluate(() => window.sameDocument)).toBe(true)
})

test('wheel, space-drag and middle-drag pan; Cmd/Ctrl-wheel zooms at the pointer', async ({ page }) => {
  await open(page, copy())
  const frame = page.locator(base)
  const box = () => frame.boundingBox()
  const c = await page.locator('#canvas').boundingBox()
  const x = c.x + c.width / 2, y = c.y + c.height / 2
  await page.mouse.move(x, y)

  const moved = async (gesture, dx, dy) => {
    const a = await box()
    await gesture()
    await expect.poll(async () => { const b = await box(); return [b.x - a.x, b.y - a.y] }).toEqual([dx, dy])
  }

  await moved(() => page.mouse.wheel(30, 100), -30, -100)

  await moved(async () => {
    await page.keyboard.down('Space')
    await page.mouse.down()
    await page.mouse.move(x + 50, y + 40)
    await page.mouse.up()
    await page.keyboard.up('Space')
  }, 50, 40)

  // Space still pans with a variation's button focused, and doesn't press it.
  await moved(() => page.mouse.wheel(900, 0), -900, 0)
  const offline = page.locator('figure[data-state=problem] button', { hasText: 'offline' })
  await offline.click()
  await expect(page.locator('figure[data-state=problem]')).toContainText("You're offline")
  // WebKit doesn't focus a clicked button; the keyboard can.
  await offline.focus()
  await page.evaluate(() => { window.clicks = 0; addEventListener('click', e => e.target.closest('button') && window.clicks++, true) })
  await page.mouse.move(x, y)
  await moved(async () => {
    await page.keyboard.down('Space')
    await page.mouse.down()
    await page.mouse.move(x + 30, y + 20)
    await page.mouse.up()
    await page.keyboard.up('Space')
  }, 30, 20)
  expect(await page.evaluate(() => window.clicks)).toBe(0)

  await page.mouse.move(x, y)
  await moved(async () => {
    await page.mouse.down({ button: 'middle' })
    await page.mouse.move(x - 20, y + 10)
    await page.mouse.up({ button: 'middle' })
  }, -20, 10)

  // exp(-deltaY * 0.01): -100 doubles and a bit, and the point under the pointer stays put.
  for (const key of ['Control', 'Meta']) {
    const a = await box()
    await page.mouse.move(x, y)
    await page.keyboard.down(key)
    await page.mouse.wheel(0, -100)
    await page.keyboard.up(key)
    const z = Math.E
    await expect.poll(async () => (await box()).width).toBeCloseTo(a.width * z, 1)
    const b = await box()
    expect(b.x).toBeCloseTo(x - (x - a.x) * z, 1)
    expect(b.y).toBeCloseTo(y - (y - a.y) * z, 1)
    // And back.
    await page.keyboard.down(key)
    await page.mouse.wheel(0, 100)
    await page.keyboard.up(key)
    await expect.poll(async () => (await box()).width).toBeCloseTo(a.width, 1)
  }
})

// Every drawn node's box, relative to its frame's root and at its scale, in
// document order; a node not shown, such as a closed dialog, has none.
const boxes = (page, selector) =>
  page.evaluate(selector => {
    const root = document.querySelector(selector)
    const r = root.getBoundingClientRect()
    const z = r.width / root.offsetWidth
    return [root, ...root.querySelectorAll('[data-chain]')].map(n => {
      if (!n.getClientRects().length) return [n.dataset.file, n.dataset.chain, 0, 0, 0, 0]
      const b = n.getBoundingClientRect()
      return [n.dataset.file, n.dataset.chain, (b.x - r.x) / z, (b.y - r.y) / z, b.width / z, b.height / z]
    })
  }, selector)

test('a frame on the canvas and the same frame from speccy render place every node in the same box', async ({ page, browser }) => {
  const dir = copy()
  const out = join(dir, '..', 'TaskScreen.html')
  // First, so the icons it fetches are in the cache the canvas reads.
  execFileSync(join(root, 'bin/speccy'), ['render', 'TaskScreen', '--out', out], { cwd: dir })
  const rendered = await browser.newPage()
  await rendered.goto('file://' + out)
  const missing = await rendered.locator('.wf .wf-missing').count()

  await open(page, dir)
  await expect(page.locator(`${base} .wf-missing`)).toHaveCount(missing)

  const want = await boxes(rendered, '.wf')
  const got = await boxes(page, base)
  expect(got.length).toBe(want.length)
  expect(want.length).toBeGreaterThan(10)
  got.forEach((g, i) => {
    const w = want[i]
    expect(g.slice(0, 2)).toEqual(w.slice(0, 2))
    for (let k = 2; k < 6; k++) expect(Math.abs(g[k] - w[k]), `${w[1]} [${k}]`).toBeLessThan(0.5)
  })
})
