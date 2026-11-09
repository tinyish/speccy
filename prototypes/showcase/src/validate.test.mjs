import { describe, expect, it } from 'vitest'
import { load, validate } from '../../catalog/validate.mjs'

const fixtures = load(`${import.meta.dirname}/../fixtures/primitives`).prims

describe('validate', () => {
  it('passes the fixtures', () => {
    expect(Object.keys(fixtures).length).toBeGreaterThan(3)
    expect(validate(fixtures)).toEqual([])
  })

  it('reports an unknown class, a bad path and a wrong state type', () => {
    const p = structuredClone(fixtures.checkbox)
    p.render.children[0].class = 'wf-row wf-shiny'
    p.render.children[1].text = '{nope} and {hint}'
    p.states.checked.checked = 'yes'
    expect(validate({ checkbox: p })).toEqual([
      'checkbox: state checked: checked should be bool, got "yes"',
      'checkbox: render.children[0]: unknown class wf-shiny',
      'checkbox: render.children[1].text: nope is not a prop, an item or index/first/last',
    ])
  })

  it('checks keys, types, defaults, each, if, slot, enum classes and the name', () => {
    const p = structuredClone(fixtures.checkbox)
    delete p.about
    p.props.size = ['sm', 'md']
    p.props.odd = 'date'
    p.render.class = 'wf-{size}'
    p.render.children = [{ el: 'li', each: 'label', bogus: 1 }, { el: 'b', if: 'size=xl' }, { el: 'i', slot: true }, { el: 'u', text: '{index}' }]
    expect(validate({ toggle: p })).toEqual([
      'toggle: missing about',
      'toggle: name "checkbox" does not match the file name',
      'toggle: prop odd: unknown type "date"',
      'toggle: defaults: missing size',
      'toggle: defaults: missing odd',
      'toggle: render: unknown class wf-sm',
      'toggle: render: unknown class wf-md',
      'toggle: render.children[0]: unknown key bogus',
      'toggle: render.children[0]: each "label" is not a list or number prop, or an item\'s field',
      'toggle: render.children[1].if: xl is not one of ["sm","md"]',
      'toggle: render.children[2]: slot needs children: true',
      'toggle: render.children[3].text: index is not a prop, an item or index/first/last',
    ])
    expect(validate({ x: new SyntaxError('Unexpected end') })).toEqual(['x: invalid JSON: Unexpected end'])
  })

  it('checks v2: conditions, classIf, expressions, limit, lookups, first/last', () => {
    const p = structuredClone(fixtures.checkbox)
    p.props.items = 'model[]'
    p.props.cols = 'text[]'
    p.defaults.items = []
    p.defaults.cols = []
    p.render.children = [
      { el: 'b', if: 'label in {nope}', classIf: { 'wf-selected': 'checked', 'wf-shiny': 'hint!=x', 'wf-strong': 'gone' } },
      { el: 'li', each: 'items', limit: '{label.length - 1}', text: '{item[cols]} {item[col]} {(index + 1) / cols.length} {first}' },
      { el: 'i', text: '{label +} {label * 2', attrs: { title: '{last}' } },
      { el: 'i', each: 'items', limit: 'two', classIf: { 'wf-selected': '!item in {cols}' } },
      { el: 'i', limit: 3 },
      { el: 'i', each: 4, text: '{item} of {cols.length}' },
    ]
    expect(validate({ checkbox: p })).toEqual([
      'checkbox: render.children[0]: unknown class wf-shiny',
      'checkbox: render.children[0].classIf.wf-strong: gone is not a prop, an item or index/first/last',
      'checkbox: render.children[0].if: nope is not a prop, an item or index/first/last',
      'checkbox: render.children[1].text: item[col] is not a prop, an item or index/first/last',
      'checkbox: render.children[2].text: expected a number or a path in "label +"',
      'checkbox: render.children[2].text: unbalanced { } in "{label +} {label * 2"',
      'checkbox: render.children[2].attrs.title: last is not a prop, an item or index/first/last',
      'checkbox: render.children[3]: limit must be a whole number or {…}',
      'checkbox: render.children[4]: limit without each',
    ])
  })

  it('checks examples like states, and attrsIf conditions and values', () => {
    const p = structuredClone(fixtures.button)
    p.examples.odd = { size: 'xl', nope: 1 }
    p.examples.flat = 'sm'
    p.render.attrsIf = { 'size=sm': { title: '{text}', role: null }, 'gone': { title: '{nope}' }, 'size=xl': { tabindex: [0] } }
    expect(validate({ button: p })).toEqual([
      'button: example odd: size should be ["sm","md","lg"], got "xl"',
      'button: example odd: nope is not a prop',
      'button: example flat must be an object of prop values',
      'button: render.attrsIf: gone is not a prop, an item or index/first/last',
      'button: render.attrsIf.gone.title: nope is not a prop, an item or index/first/last',
      'button: render.attrsIf: xl is not one of ["sm","md","lg"]',
      'button: render: attrsIf.size=xl.tabindex must be a string, number, bool or null',
    ])
    delete p.examples
    delete p.render.attrsIf
    expect(validate({ button: p })).toEqual([])
  })
})
