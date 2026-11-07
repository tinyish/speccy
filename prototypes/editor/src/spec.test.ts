import { test, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { insertInstance, moveInstance, setField, deleteInstance, renameInstance, applyStates, instScope, paths, findItem, findInst, tidy, renameModel, type Spec, type Item } from './spec'

const dir = join(import.meta.dirname, '../../spec-format/example')
const read = (f: string) => JSON.parse(readFileSync(join(dir, f), 'utf8'))
const all = (sub: string) => readdirSync(join(dir, sub)).map(f => read(`${sub}/${f}`))
const load = (): Spec => ({ primitives: JSON.parse(readFileSync(join(dir, '../primitives.json'), 'utf8')), data: all('data'), components: all('components'), screens: all('screens') })
const item = (s: Spec, kind: 'components' | 'screens', name: string) => findItem(s, kind, name) as Item

test('insert adds an instance at the index with a unique, readable id', () => {
  const s = load(), row = item(s, 'components', 'TaskRow')
  expect(insertInstance(s, row, null, 1, 'button')).toBe('button')
  expect(insertInstance(s, row, null, 0, 'button')).toBe('button2')
  expect(insertInstance(s, row, 'actions', 2, 'text')).toBe('text')
  expect(row.children!.map(i => i.id).slice(0, 3)).toEqual(['button2', 'done', 'button'])
  expect(findInst(row, 'actions')!.inst.children!.map(i => i.id)).toEqual(['cancel', 'yes', 'text'])
  expect(insertInstance(s, row, null, 0, 'TaskList')).toBe('taskList')
})

test('insert takes initial fields, and names a layout container after its layout', () => {
  const s = load(), row = item(s, 'components', 'TaskRow')
  expect(insertInstance(s, row, null, 0, 'container', { layout: 'grid', columns: 2 })).toBe('grid')
  expect(row.children![0]).toEqual({ id: 'grid', use: 'container', layout: 'grid', columns: 2 })
})

test('move reorders within a container, moves across containers, and refuses to move into itself', () => {
  const s = load(), row = item(s, 'components', 'TaskRow')
  const ids = () => row.children!.map(i => i.id)
  expect(moveInstance(row, 'done', null, 3)).toBe(true) // index counted before the move: lands before confirm
  expect(ids()).toEqual(['title', 'delete', 'done', 'confirm'])
  expect(moveInstance(row, 'delete', null, 0)).toBe(true)
  expect(ids()).toEqual(['delete', 'title', 'done', 'confirm'])
  expect(moveInstance(row, 'title', 'actions', 1)).toBe(true)
  expect(findInst(row, 'actions')!.inst.children!.map(i => i.id)).toEqual(['cancel', 'title', 'yes'])
  expect(moveInstance(row, 'confirm', 'actions', 0)).toBe(false)
  expect(moveInstance(row, 'confirm', 'confirm', 0)).toBe(false)
})

test('setField writes the base, or an override in a state', () => {
  const s = load(), row = item(s, 'components', 'TaskRow')
  setField(row, null, 'title', 'width', 120)
  setField(row, null, 'delete', 'text', 'Remove')
  setField(row, 'confirming', 'title', 'hidden', true)
  expect(findInst(row, 'title')!.inst.width).toBe(120)
  expect(findInst(row, 'delete')!.inst.props).toEqual({ text: 'Remove' })
  expect(row.states!.confirming.set).toEqual({ 'confirm.open': true, 'title.hidden': true })
  setField(row, 'confirming', 'title', 'hidden', undefined)
  setField(row, null, 'title', 'width', undefined)
  expect(row.states!.confirming.set).toEqual({ 'confirm.open': true })
  expect('width' in findInst(row, 'title')!.inst).toBe(false)
})

test('delete removes the subtree and cleans state sets and on entries', () => {
  const s = load(), row = item(s, 'components', 'TaskRow')
  deleteInstance(row, 'confirm')
  expect(findInst(row, 'yes')).toBeUndefined()
  expect(row.states!.confirming.set).toEqual({})
  expect(Object.keys(row.on!)).toEqual(['done.change', 'delete.press'])
})

test('rename id updates state sets and on keys', () => {
  const s = load(), screen = item(s, 'screens', 'TaskScreen')
  renameInstance(screen, 'list', 'tasks')
  expect(screen.states!.loading.set).toEqual({ 'tasks.hidden': true, 'loading.hidden': false })
  expect(Object.keys(screen.on!)).toContain('tasks.toggle')
  expect(Object.keys(screen.on!)).not.toContain('list.toggle')
})

test('stacked states apply in written order, the later winning', () => {
  const s = load(), screen = item(s, 'screens', 'TaskScreen')
  screen.states!.offline.set!['list.hidden'] = false // offline is written before error
  expect(applyStates(screen, ['error', 'offline']).list).toEqual({ hidden: true })
  expect(applyStates(screen, ['offline']).list).toEqual({ hidden: false })
  expect(applyStates(screen, [])).toEqual({})
  screen.states!.error.set!['list.height'] = 120 // states set layout fields like props
  expect(applyStates(screen, ['error']).list).toEqual({ hidden: true, height: 120 })
})

test('in-scope paths include props, repeat aliases and model fields', () => {
  const s = load()
  const list = item(s, 'components', 'TaskList')
  expect(instScope(s, list, 'row')).toEqual({ tasks: 'Task[]', task: 'Task' })
  expect(instScope(s, list, 'row', false)).toEqual({ tasks: 'Task[]' })
  const row = item(s, 'components', 'TaskRow')
  expect(paths(s, instScope(s, row, 'title'))).toEqual([['task', 'Task'], ['task.id', 'text'], ['task.title', 'text'], ['task.done', 'bool']])
})

test('renaming a model updates types and operation references', () => {
  const s = load()
  renameModel(s, 'Task', 'Todo')
  expect(item(s, 'components', 'TaskList').props).toEqual({ tasks: 'Todo[]' })
  expect(item(s, 'screens', 'TaskScreen').data!.tasks).toEqual({ type: 'Todo[]', from: 'Todo.list' })
  expect(item(s, 'screens', 'TaskScreen').on!['header.add']).toEqual([{ call: 'Todo.add', with: 'event' }])
})

test('tidy orders keys and drops empty parts', () => {
  const x = tidy({ children: [{ use: 'text', id: 'a', props: {} }], component: 'X', about: '', on: { 'a.press': [] }, states: { s: { about: 'when', set: {} } } })
  expect(JSON.stringify(x)).toBe('{"component":"X","children":[{"id":"a","use":"text"}],"states":{"s":{"about":"when"}}}')
})
