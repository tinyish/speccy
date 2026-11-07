import { test } from 'node:test'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import { load, check } from './check.mjs'

const spec = () => load(fileURLToPath(new URL('example', import.meta.url)))

test('the task screen spec is valid', () => {
  assert.deepEqual(check(spec()), [])
})

test('broken references and wrong types are caught', () => {
  const s = spec()
  const screen = s.screens.find(x => x.screen === 'TaskScreen')
  const row = s.components.find(x => x.component === 'TaskRow')
  const header = s.components.find(x => x.component === 'Header')
  screen.children.find(i => i.id === 'list').bind.tasks = 'todos'
  screen.states.empty.set['nope.hidden'] = true
  header.on['add.press'][0].emit = 'added'
  row.on['delete.press'][0].enter = 'confirm'
  delete screen.states.error.about
  row.children.find(i => i.id === 'title').bind.text = 'task.done'
  const errors = check(s).join('\n')
  for (const e of ["bind tasks to todos, which doesn't resolve", "sets nope.hidden, which isn't an instance prop",
    "emits added, which isn't in events", "enters confirm, which isn't a state", 'state error: needs an about', 'prop text is text, bound to task.done which is bool']) assert.match(errors, new RegExp(e))
})

test('bad layout values are caught', () => {
  const s = spec()
  const screen = s.screens.find(x => x.screen === 'TaskScreen')
  const row = s.components.find(x => x.component === 'TaskRow')
  const list = screen.children.find(i => i.id === 'list')
  list.width = 'wide'
  screen.layout = 'diagonal'
  screen.gap = -4
  row.children.find(i => i.id === 'confirm').children.find(i => i.id === 'actions').padding = [1, 2, 3]
  row.children.find(i => i.id === 'title').gap = 8
  row.children.find(i => i.id === 'confirm').wrap = true
  screen.states.loading.set['list.height'] = 'tall'
  screen.device = 'watch'
  const errors = check(s).join('\n')
  for (const e of ['instance list: width is fill, hug or a number, got "wide"', 'TaskScreen: layout is row, column, stack, grid, got "diagonal"',
    'TaskScreen: gap is a number or auto, got -4', 'instance actions: padding is', 'instance title: text holds no children, so it has no gap',
    'instance confirm: wrap only applies to a row', 'state loading: list.height is fill, hug or a number, got "tall"', 'TaskScreen: device is desktop']) assert.ok(errors.includes(e), e)
})
