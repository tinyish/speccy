# MVP 2: drawing

Bead: spec-eai

A resolved tree drawn as HTML: `Speccy.Layout` turns layout fields and
sizes into CSS, each primitive's module draws its wireframe, and
`wireframe.css` styles them. A gallery shows every primitive for Alberto
to judge by eye.

## Program design

### Layout

`Speccy.Layout`, in `lib/speccy/layout.ex`, pure, two functions that
return a CSS declaration string:

- `box(layout)`: for what holds children (a root, a component, a
  primitive whose interface has `children: true`), from its layout
  fields.
- `item(place, parent_layout)`: for any node, from its `place` and the
  layout of the box it sits in.

The defaults are `format.md` § Layout's. The browser computes the
geometry; nothing computed is stored (`canvas-renders-dom`).

`box`:

| Field | CSS |
| --- | --- |
| `layout: row`, `column` | `display: flex`, `flex-direction` |
| `wrap` | `flex-wrap: wrap` |
| `layout: stack` | `display: grid`, every child in `grid-area: 1 / 1` |
| `layout: grid` | `display: grid`; `columns` and `rows` as `grid-template-columns` and `-rows`: a number `n` is `repeat(n, minmax(0, 1fr))`; in a list, a number is pixels, `fill` is `minmax(0, 1fr)`, `hug` is `max-content` |
| `align` | the nine positions, as `justify-content` and `align-items` on the box's two axes (and `justify-items`, `align-content` in a stack or grid) |
| `gap` | a number: `gap` along the flow, or `column-gap` in a grid; `between`, `around`, `evenly`: `justify-content: space-between`, `space-around`, `space-evenly`, with no gap |
| `lineGap` | the gap across the flow of a wrapping box, or `row-gap` in a grid; unset: the same as `gap` |
| `padding` | `padding`, one, two or four values |
| `clip` | `overflow: hidden` |

`item`:

| Field | CSS |
| --- | --- |
| `width`, `height` a number | pixels, and `flex-shrink: 0` on the box's main axis |
| `fill` on the main axis | `flex: 1 1 0` with a zero minimum for width; `flex: 1 1 auto` for height, so a fill inside a hugging column hugs |
| `fill` on the cross axis, or in a grid cell | `align-self: stretch`, or `justify-self: stretch` |
| `hug`, or unset | the content's size, and `flex-shrink: 0` on the main axis |
| `minWidth` … `maxHeight` | pixels |
| `column`, `row`, `columnSpan`, `rowSpan` | `grid-column` and `grid-row`, `<start> / span <n>` |
| `absolute` | see Absolute placement, below |

`prototypes/editor/src/Canvas.tsx` (`boxStyle`, `sizeStyle`) drew the
same fields in the React prototype and is the reference for what looked
right; this table wins where they differ.

### Absolute placement, a format change

`x`, `y` and `constraints` can't be drawn: pinning to the right, the
middle or both edges needs the container's size at the moment `x` and
`y` were set, and the format stores no sizes. They are replaced by
offsets from the container's edges, as code writes them. This part
makes the change before it draws anything.

| Key | |
| --- | --- |
| `left`, `right`, `top`, `bottom` | With `absolute`: pixels from that edge of its container. `left` and `right` together stretch it between them, and so do `top` and `bottom`. |
| `centerX`, `centerY` | With `absolute`: pixels from the container's middle on that axis, 0 for centred. Not with `left` or `right` (`top` or `bottom`) on the same axis. |

An axis with none of them is at 0 from the left, or the top. Figma's
`scale` has no counterpart; it joins `format.md` § Not in the MVP as a
gap.

It changes, in the same change (`conventions.md#format-md-is-the-format`):

- `format.md` § Instance: the `x`, `y` and `constraints` rows become the
  two above; § The checker's rules and § States and variations, which
  also name the old keys, name the new ones.
- `Speccy.Schemas` and `Speccy.Format`'s key order: the six keys in, the
  three out, with `Format`'s `constraints` kind and its line in the
  drift guard (`test/speccy/schemas_test.exs`); the schema refuses `centerX` beside `left` or `right`, and
  `centerY` beside `top` or `bottom`.
- `Speccy.Check`: `position-without-absolute` covers the six keys.
- Every fixture that uses `x`, `y` or `constraints`.
- Not the format's version: it stays at 1, on Alberto's ruling. The
  convention asks a breaking change to bump `format`, but no spec
  outside this repository's fixtures exists yet to keep working.

`item` then draws an absolute node as `position: absolute` with `left`,
`right`, `top` and `bottom` as written, `centerX` as `left: 50%` with a
`translate` of half its width plus the offset, and `centerY` the same on
the other axis; its box gets `position: relative`.

### Drawing

`Speccy.Draw.frame(assigns)`, a function component in
`lib/speccy/draw.ex`: takes `tree` (a resolved root), `icons` (reference
→ SVG, from part 003; until then, every icon draws its placeholder) and
`size` (`{width, height}` for a screen's device, nil to hug). It renders
the frame's root, `class="wf"` and `inert`, and walks the tree:

- **A primitive** is drawn by its module's `draw/1`, which gets the
  node's `props`, the `Layout.item` and `Layout.box` styles as `style`,
  its children already rendered as the `inner_block`, and the node's
  `data-file` and `data-chain`. The module puts `style` and the `data-`
  attributes on its outermost element. It reads its props from the
  assigns and declares no `attr` per prop
  (`conventions.md#a-primitive-is-a-module`).
- **A component** is a `div` with its styles, holding its children.
- **An error node** is a box with its code, class `wf-error`.
- **An icon** is its SVG from `icons`, inlined, or a placeholder box
  with the icon's name when it isn't there.

Each of the 25 modules in `lib/speccy/primitives/` gains `draw/1`: the
element its interface's `element` names, with the ARIA its props set,
drawn in every state its interface lists. A wireframe, not a design:
boxes, lines, text and icons in one grey ink. `prototypes/showcase` and
`prototypes/catalog` drew all 25 and are the reference for what each
should show.

`wireframe.css`, in `lib/speccy/primitives/`: plain CSS, every rule
under `.wf`, every class named `wf-…`
(`conventions.md#app-ui-the-phoenix-way`). It starts by resetting
everything under `.wf` to the browser's defaults, so Tailwind's base
styles never reach a frame. It is read at compile time, so the editor's
page and `speccy render` use the same text.

### The gallery

A route in development only, `/dev/primitives`: every primitive, by
category, drawn in each of its interface's examples and in each of its
states, with the example's name under it.

## Tests

- **The format change:** a fixture pins one instance right, stretches
  one and centres one, and passes the check; `centerX` beside `left`
  fails its schema; a position key without `absolute` reports
  `position-without-absolute`; the schema drift guard passes.
- **Layout:** `box` and `item` for each row of the tables above, on the
  fixtures' own values, asserting the declarations.
- **Primitives:** every primitive draws each of its examples and each
  of its states without raising (`testing.md` § Core).
- **Draw:** a resolved frame of the `tasks` fixture draws every node
  with its `data-chain`; an error node draws its code; an icon not in
  `icons` draws its placeholder; nothing outside `.wf` is styled by
  `wireframe.css` (every selector starts with `.wf`).

## Done when

- `mix precommit` passes.
- Alberto has looked at `/dev/primitives` and at one screen of the
  `tasks` fixture drawn from a test page, and says the wireframes read.
