import { describe, expect, it } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import { render, interp, holds } from './render'
import { Canvas } from './Canvas'
import type { Primitive } from './App'
import button from '../fixtures/primitives/button.json'
import container from '../../catalog/primitives/container.json'

const html = (node: unknown, values: Record<string, unknown> = {}) => renderToStaticMarkup(<>{render(node, values)}</>)

describe('render', () => {
  it('gives a lone {…} raw and stringifies it inside text', () => {
    expect(interp('{checked}', { checked: true })).toBe(true)
    expect(interp('{count} items', { count: 3 })).toBe('3 items')
    expect(interp('{m.label}!', { m: { label: 'Hi' } })).toBe('Hi!')
    expect(html({ el: 'input', attrs: { type: 'checkbox', checked: '{on}' } }, { on: true })).toBe('<input type="checkbox" readOnly="" checked=""/>')
    expect(html({ el: 'input', attrs: { type: 'checkbox', checked: '{on}' } }, { on: false })).toBe('<input type="checkbox" readOnly=""/>')
    expect(html({ el: 'textarea', text: '{t}' }, { t: 'Hi' })).toBe('<textarea readOnly="">Hi</textarea>')
  })

  it('evaluates expressions and [lookups]', () => {
    const v = { start: 20, end: 60, min: 0, max: 200, items: ['a', 'b', 'c'], row: { Name: 'Maya' }, col: 'Name', code: '4821' }
    expect(interp('{(start - min) / (max - min) * 100}', v)).toBe(10)
    expect(interp('+{items.length - 1}', v)).toBe('+2')
    expect(interp('{row[col]}', v)).toBe('Maya')
    expect(interp('{code[1]}{code.length}', v)).toBe('84')
    expect(html({ el: 'div', class: 'wf-track', attrs: { style: 'width: {end - start}%' } }, v)).toBe('<div style="width:40%" class="wf-track"></div>')
  })

  it('tests conditions: path, !, =, !=, in, with {…} on the right', () => {
    const v = { on: true, zero: 0, empty: '', items: [], size: 'sm', cur: 'b', picked: ['a', 'b'], m: { label: 'src', children: [1] }, open: [{ label: 'src' }] }
    const cases: [string, boolean][] = [
      ['on', true], ['zero', false], ['empty', false], ['items', false], ['!on', false],
      ['size=sm', true], ['size!=sm', false], ['!size=sm', false], ['size=md', false],
      ['size in xs, sm', true], ['cur in {picked}', true], ['!cur in {picked}', false], ['size in {picked}', false],
      ['m={open}', false], ['m in {open}', true], ['size={size}', true],
    ]
    for (const [c, want] of cases) expect([c, holds(c, v)]).toEqual([c, want])
  })

  it('adds classIf classes whose condition holds', () => {
    expect(html({ el: 'b', class: 'wf-pill', classIf: { 'wf-selected': 'item={cur}', 'wf-disabled': 'off' }, each: 'items' }, { items: ['a', 'b'], cur: 'b', off: false }))
      .toBe('<b class="wf-pill"></b><b class="wf-pill wf-selected"></b>')
    expect(html({ el: 'i', classIf: { 'wf-strong': 'on' } }, { on: true })).toBe('<i class="wf-strong"></i>')
    expect(html({ el: 'i', classIf: { 'wf-strong': 'on' } }, { on: false })).toBe('<i></i>')
  })

  it('repeats each with as, index, first, last, numbers and limit, nested over item.children', () => {
    const node = {
      el: 'ul', children: [{
        el: 'li', each: 'items', text: '{index}:{item.label}',
        children: [{ el: 'i', each: 'item.children', as: 'c', text: '{c.label}@{index}', if: '!c.label={cur}' }],
      }],
    }
    const items = [{ label: 'a', children: [{ label: 'a1' }, { label: 'a2' }] }, { label: 'b' }]
    expect(html(node, { items, cur: 'a1' })).toBe('<ul><li>0:a<i>a2@1</i></li><li>1:b</li></ul>')
    expect(html({ el: 'b', each: 'n', text: '{item}{first}{last} ' }, { n: 3 })).toBe('<b>1truefalse </b><b>2falsefalse </b><b>3falsetrue </b>')
    expect(html({ el: 'b', each: 2, text: '{index}' })).toBe('<b>0</b><b>1</b>')
    expect(html({ el: 'b', each: 'xs', limit: '{max}', text: '{item}' }, { xs: ['a', 'b', 'c'], max: 2 })).toBe('<b>a</b><b>b</b>')
    expect(html({ el: 'b', each: 'xs', limit: 1, text: '{item}{last}' }, { xs: ['a', 'b'] })).toBe('<b>atrue</b>')
  })

  it('draws placeholder boxes in a slot', () => {
    expect(html({ el: 'div', slot: true })).toBe('<div><div class="wf-slot">child</div><div class="wf-slot">child</div></div>')
  })

  it('draws Material Symbols glyphs, and an icon-only button square with its icon and accessible name', () => {
    const b = (over: Record<string, unknown>) => html(button.render, { ...button.defaults, ...over })
    expect(b(button.examples['with icons'])).toContain('<span aria-hidden="true" class="wf-symbol">save</span><span>Save changes</span><span aria-hidden="true" class="wf-symbol">expand_more</span>')
    const icon = b(button.examples['icon only'])
    expect(icon).toMatch(/^<div[^>]*><div[^>]*><button type="button" aria-label="Favourite" aria-pressed="false" class="wf-btn wf-btn-icon"><span aria-hidden="true" class="wf-symbol">favorite<\/span><\/button>/)
    expect(b({ text: '' })).toContain('class="wf-btn wf-btn-icon"><span aria-hidden="true" class="wf-icon"></span></button>')
    expect(b(button.examples['removable tag'])).toContain('aria-label="Remove" class="wf-btn wf-btn-icon wf-btn-sm"><span aria-hidden="true" class="wf-symbol">close</span>')
  })

  it('applies attrsIf in order: container roles, pressable, current, selected, controls', () => {
    const c = (over: Record<string, unknown>) => html(container.render, { ...container.defaults, ...over }).replace(/<div class="wf-slot">child<\/div>/g, '')
    expect(c({})).toBe('<div style="flex-wrap:wrap" class="wf-row wf-gap wf-pad wf-box"></div>')
    expect(c({ href: '/x' })).toBe('<div style="flex-wrap:wrap" class="wf-row wf-gap wf-pad wf-box"></div>')
    expect(c(container.examples.card)).toBe('<div style="flex-wrap:wrap" role="button" tabindex="0" class="wf-row wf-gap wf-pad wf-box wf-pressable"></div>')
    expect(c({ pressable: true, href: '/x' })).toContain('role="link" tabindex="0"')
    expect(c(container.examples['nav item, current'])).toBe('<div style="flex-wrap:wrap" role="button" tabindex="0" aria-current="page" class="wf-row wf-gap wf-pad wf-box wf-pressable wf-box wf-selected"></div>')
    expect(c({ ...container.examples['tab, selected'], controls: 'p1' })).toBe('<div style="flex-wrap:wrap" role="tab" tabindex="0" aria-controls="p1" aria-selected="true" class="wf-row wf-gap wf-pad wf-box wf-pressable wf-selected"></div>')
    expect(c({ pressable: true, controls: 'p1' })).toContain('aria-controls="p1" aria-expanded="false"')
    expect(c(container.examples.navigation)).toContain('role="navigation"')
    expect(c(container.examples.alert)).toContain('role="alert"')
  })

  it('draws a frame per example after the states, marked as an example', () => {
    const out = renderToStaticMarkup(<Canvas prim={button as unknown as Primitive} name="button" values={{}} />)
    const titles = [...out.matchAll(/data-frame="([^"]+)"( data-example="true")?/g)].map(m => (m[2] ? `example ${m[1]}` : m[1]))
    expect(titles).toEqual(['default', 'selected', 'disabled', 'open', ...Object.keys(button.examples).map(e => `example ${e}`)])
    expect(out).toContain('<div class="frame-title" title="icon only"><span class="ex">example · </span>icon only</div>')
  })

  it('draws an error box for a bad node instead of throwing', () => {
    const bads = [null, { el: 'not a tag' }, { el: 'div', each: 's' }, { el: 'div', children: 'x' }, { el: 'div', text: '{a +}' }, { el: 'div', if: 'f(x)' }]
    for (const bad of bads) {
      const out = html({ el: 'div', children: [{ el: 'b', text: 'ok' }, bad] }, { s: 'text' })
      expect(out).toMatch(/^<div><b>ok<\/b><span class="wf-bad"/)
    }
    expect(html({ el: 'button', attrs: { onclick: 'alert(1)' } })).toBe('<button></button>')
  })
})
