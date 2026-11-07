# Prototype: the spec format

Throwaway. It tests whether speccy's objects (see `brain/objects.md`)
can be written as JSON files in a repo that both an editor and a coding
agent read and write, using the task screen as the example.

Run `node check.mjs` to check the spec and `node --test` for the
checker's own tests. Node 22 or later, no dependencies. `example/` holds
a frozen copy of the task example that the tests (here and in the
editor) run on, so they don't depend on what the live spec holds; check
it with `node check.mjs example`.

## The format

- **`primitives.json`**: speccy's own catalogue, shared by every spec
  (it is read from beside `check.mjs`, not from the spec folder), of
  HTML-subset primitives: the
  props each takes (with their types), the events it fires (with what
  they carry), and whether it holds children.
- **`data/`**: one file per data model: its fields and the operations a
  screen can call on it.
- **`components/`**: one file per composed component: the `props` it
  takes, the `events` it fires, its `local` state, its `children`, `states` and `on`.
- **`screens/`**: one file per screen. A screen has the same shape as a
  component, except it has `data` (loaded from a data operation) instead
  of `props`, `events` and `local`, and a `device` (`desktop`, `tablet` or
  `mobile`: 1440×1024, 834×1194 or 390×844) that sets its size.

Inside a component or screen:

- **`children`** are instances: an `id`, the component they `use`,
  `props` written as literals (copy goes here), `bind` from a path into
  data, `hidden`, and `repeat` to render one per list item (`each`, `as`
  and an optional `limit` on how many show). Only container, list, form
  and dialog hold children.
- **Layout** follows Figma's auto layout. Anything that holds children (a
  file's root, and container, list, form and dialog instances) can have
  `layout` (`row`, `column`, `stack` for children layered on each other,
  or `grid`), `wrap` (row only), `columns` (grid only), `align` (one of
  nine: `top-left`, `top`, `top-right`, `left`, `center`, `right`,
  `bottom-left`, `bottom`, `bottom-right`), `gap` (a number, or `auto`
  for space between), `padding` (a number, `[vertical, horizontal]` or
  `[top, right, bottom, left]`) and `clip`. Every instance, and a
  component's root, can have `width` and `height` (`fill`, `hug`, or a
  number of pixels, which fixes it), and an instance `minWidth`,
  `maxWidth`, `minHeight` and `maxHeight`. Unset, a box is a top-left
  column with gap and padding of 8, and an instance hugs its content.
- **`states`** are named overrides of the base: an `about` saying in a
  line when the state applies, and the instance props and layout fields
  it `set`s (`"list.hidden": true`, `"row.height": 64`). There is no condition language: people and
  agents read the `about`. Every state that holds applies, in the order
  written; when two set the same prop, the later one wins.
- **`on`** maps an instance's event (`"row.delete"`) to actions: `set`
  local state, `enter` or `exit` one of the file's states, `emit` one of
  the component's own events, `call` a data operation, or `reload` loaded
  data. In a handler, `event` is what the
  event carries.

The rule underneath: **only states change instance props.** Actions
never set them; an interaction enters or exits a state, and a state
nothing enters applies whenever its `about` says.

## Not covered

No JSON Schema file: `check.mjs` is the schema. Paths and input
payloads are simple on purpose (a checkbox's change carries text,
and operations have no types).

## Findings

**The trial.** A fresh agent with no docs and no context, only these
files, was asked to add an offline state to TaskScreen: a banner above
the list, with the list still visible. In four tool calls it added a
`Device` data model, the `Banner` component and the `offline` state, and
the checker passed with no changes to it. The format can be learned from
its own files, and a new state reads in four lines.

**What it had to guess:**

1. **Overlapping states.** Nothing says what happens when two states
   hold at once (offline and error), or which wins when both set the
   same prop. The agent dodged it by not touching the list.
2. **Values from the environment.** Being offline isn't data loaded from
   an operation, but that is the only kind of data a screen has, so it
   modelled the device as `Device.get`, which brings loading and error
   statuses that mean nothing here. Nor does anything say whether loaded
   data updates live or only on reload.
3. **Data with no source.** The checker accepts `data` without `from`,
   but what that means is undefined.
4. **Operations are bare names.** No inputs or outputs, so nothing says
   `Device.get` returns one Device.
5. **States can't say why.** There's no `about` on a state.

**What changed after it.** Alberto settled the two model questions:
states that hold together all apply, in the order written, the later
winning (1); and a state has no formal condition, only an `about` saying
when it applies (2 and 5). That made `Device` unnecessary, so it is gone,
and interactions now `enter` and `exit` states instead of setting a flag
a condition read. Items 3 and 4 are still open, as small format fixes.
