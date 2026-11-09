# Renderable primitives

One JSON file per primitive in `primitives/<name>.json`, built from
`catalog.json`. Each holds what speccy knows about the primitive plus
enough to draw it as a wireframe. The showcase (`../showcase`) renders and
edits these files; `validate.mjs` checks them.

## File

```json
{
  "name": "checkbox",
  "about": "A box the user ticks, or a switch they flip, to turn one option on or off.",
  "category": "selection",
  "element": "input type=checkbox (role=switch when role is switch)",
  "props": { "role": ["checkbox", "switch"], "label": "text", "checked": "bool", "disabled": "bool" },
  "events": { "change": "bool" },
  "children": false,
  "states": {
    "checked": { "checked": true },
    "disabled": { "disabled": true }
  },
  "defaults": { "role": "checkbox", "label": "Remember me", "checked": false, "disabled": false },
  "render": { "...": "a node, see below" },
  "sources": { "material": [], "untitled": [] }
}
```

- `name`, `about`, `category`, `element`, `props`, `events`, `children`,
  `sources`: copied from the catalog entry. Prop types are `text`, `bool`,
  `number`, `text[]`, an enum array (`["sm","md"]`), `model` or `model[]`.
- `states`: each of the entry's states, as the prop values that put the
  primitive in it. A state with no matching prop gets one (a `bool` named
  after it, or the prop that carries it, such as `error: "text"`).
- `examples` (optional): more frames to show, as `{ "<name>": { prop
  overrides } }`, checked like states. States are behaviour; an example is
  anything else worth seeing, such as a size, icons or an icon-only button.
  The showcase draws them after the state frames, marked "example".
- `defaults`: a sample value for every prop, so the primitive renders
  meaningfully with nothing set: realistic short copy, 3 to 5 items for
  lists. A `model` is an object and a `model[]` an array of objects, with
  the fields its notes name (`label`, `children`, `date`…).

## Render nodes

A node is an object:

| Key | Meaning |
|---|---|
| `el` | An HTML tag (`div`, `span`, `button`, `input`, `ul`, `li`, `label`, `table`…). Required. |
| `class` | Space-separated wireframe classes (below). |
| `classIf` | More classes, each added when its condition holds: `{ "wf-selected": "item={value}", "wf-disabled": "disabled" }`. |
| `text` | Text content, with `{…}` interpolation. |
| `attrs` | HTML attributes, values interpolated: `type`, `placeholder`, `value`, `checked`, `disabled`, `role`, `aria-*`, `style`. |
| `attrsIf` | More attributes, each set applied after `attrs` when its condition holds, in order, a later set overriding an earlier one, and `null` dropping an attribute: `{ "pressable": { "role": "button", "tabindex": 0 }, "!pressable": { "role": null }, "role!=none": { "role": "{role}" } }`. |
| `if` | Render only when the condition holds. |
| `each` | Repeat this node once per element of a list (`"items"`, or `"item.children"` inside another `each`), or `n` times for a number (a number prop, or a literal like `5`). |
| `as` | Name for the element inside `each` (default `item`). Over a number, it is 1…n. |
| `limit` | With `each`: render at most this many, a whole number or `"{…}"`. |
| `children` | Child nodes. |
| `slot` | `true` on the node where a primitive with `children: true` places its child instances. The showcase draws placeholder boxes there. |

Inside an `each`, besides its alias, `{index}` is the position (from 0),
and `{first}` and `{last}` are true on the first and last element drawn
(after `limit`). The `if`, `class`, `classIf` and everything else on an
`each` node are worked out once per element, with these in scope; `limit`
applies before `if`. A nested `each` hides the outer one's `index`,
`first` and `last`.

### Paths

A path names a value: a prop (`label`), an `each` alias (`item`), or
`index`, `first`, `last`. It reaches into objects with `.field`
(`item.label`) and looks a field up with `[path]`, where the bracket holds
a path evaluated in scope or a whole number: `{row[col]}` reads the field
of `row` that `col` names; `{value[index]}` reads one character. `.length`
gives the length of a list or text. A missing field gives nothing (empty
text, false).

### Interpolation and expressions

`{…}` holds an expression: paths, number literals, `+ - * /` and
parentheses, nothing else (no calls, no unary minus, no strings):
`{(start - min) / (max - min) * 100}`, `+{names.length - max}`. Arithmetic
works on numbers; a lone path keeps its value as is.

`"{label}"` alone gives the raw value (a bool stays a bool, so
`"checked": "{checked}"` works); inside other text each `{…}` is
stringified (`"{count} items"`): nothing for a missing value, JSON for an
object or list. Enum props can be used in classes:
`"class": "wf-btn wf-{variant}"` is fine only if every resulting class
exists below; prefer `classIf` for anything else.

### Conditions

`if` and `classIf` take a condition:

| Form | Holds when |
|---|---|
| `left` | `left` is truthy. False, null, missing, `""`, `0` and an empty list are false. |
| `!cond` | `cond` doesn't hold (it negates the whole rest: `!item in {values}`). |
| `left=right` | They are equal. |
| `left!=right` | They are not. |
| `left in right` | `left` equals an element of `right`: a list, or text split on commas (`size in sm, md`). |

`left` is a path (or an expression). `right` is literal text, or holds
`{…}`: a lone `{path}` gives its raw value (so `item in {values}` tests a
list), and anything else is interpolated (`index={current}`). Values are
equal when their text is equal (`1` equals `"1"`); when the right side is
an object, the left must be an object whose fields equal each of the
right's, so a model can be found by some of its fields: with
`value: { "label": "Docs" }`, `item={value}` holds for the item labelled
Docs whatever else it has.

Keep templates small: the fewest nodes that show what the primitive is and
how each state differs. Use real elements (a `button` for a button, an
`input type=range` for a slider) when a wireframe class can't say it
better.

## Wireframe classes

The only classes a template may use. The showcase styles them; the editor
will reuse the same sheet.

| Class | Look |
|---|---|
| `wf-row`, `wf-col` | Flex row or column, items centered on the cross axis. |
| `wf-gap` | 8px gap. |
| `wf-pad` | 8px padding. |
| `wf-grow` | Fills the remaining space. |
| `wf-box` | Thin border, shared radius. |
| `wf-surface` | Raised card: border, radius, slightly lighter fill. |
| `wf-overlay` | Floating card (menus, dialogs, popovers): surface plus shadow. |
| `wf-btn` | Outlined button. |
| `wf-btn-primary` | Filled button (with `wf-btn`). |
| `wf-btn-sm`, `wf-btn-lg` | Small or large button (with `wf-btn`); medium is the default. |
| `wf-btn-icon` | Icon-only button (with `wf-btn`): even padding, so it is square at each size. |
| `wf-field` | Input-like box with padding. |
| `wf-label` | Small label above a field. |
| `wf-hint` | Small muted helper text. |
| `wf-muted` | Muted text. |
| `wf-strong` | Bold text. |
| `wf-small` | Small text. |
| `wf-icon` | 16px placeholder square for an icon. |
| `wf-symbol` | Its text drawn as a Material Symbols Outlined glyph (`save`, `close`, `expand_more`; names at fonts.google.com/icons), 16px, 14 in `wf-btn-sm`, 20 in `wf-btn-lg`. Use `aria-hidden` and give the control its name elsewhere. The name names a glyph; its look stays in Figma. |
| `wf-avatar` | 32px circle placeholder. |
| `wf-pill` | Rounded pill (chips, tags, badges). |
| `wf-dot` | 8px circle. |
| `wf-track` | Thin horizontal bar (slider, progress track). |
| `wf-fill` | Accent-filled part of a track; width via `style`. |
| `wf-thumb` | 16px circle handle. |
| `wf-divider` | 1px rule. |
| `wf-pressable` | Something the user presses that isn't a button (a card, a nav item, a tab): a subtle raised box and a pointer. |
| `wf-selected` | Accent border/fill: the selected or active item. |
| `wf-error` | Error color for border and text. |
| `wf-disabled` | Faded, not interactive. |
| `wf-scroll` | Clips and scrolls overflow. |

Inline `style` is allowed for what a class can't say (a fill width, a grid
template); keep it to layout, never colors.
