# MVP 2: Resolve, and the composition rules on its trees

Bead: spec-eai

`Speccy.Resolve` turns one frame into the tree the canvas draws, and the
composition rules run on those trees in place of their own walk
(`decisions.md#composition-on-drawn-frames`).

## Program design

### Resolve

`Speccy.Resolve.frame(spec, path, state \\ nil, variation \\ nil)`, in
`lib/speccy/resolve.ex`: `spec` a `Speccy.Spec`, `path` a screen's or a
component's file, `state` one of its states or nil for the base,
`variation` one of that frame's variations or nil for the frame as
written. It returns the frame's root node. It is pure, and it never
raises on what a valid file holds (`conventions.md#resolve-is-total`).
It reads only `spec.valid`: for a path that isn't there, it returns one
error node with the file's first problem code.

A node is a plain map:

| Key | Holds |
| --- | --- |
| `kind` | `:root`, `:primitive`, `:component` or `:error` |
| `use` | the primitive's or component's name; the item's name on the root |
| `id` | the instance's id; nil on the root |
| `origin` | where it is written: a list of `%{file, at, id}`, outermost first. One entry for an instance of the frame's own file; one more for each component it is inside. `at` is the path of the instance in that file, as the check reports paths; for a copy, the copy's path in the state; for a part a copy names in `inner`, that `inner` entry's path |
| `row` | its index in a repeat, or nil |
| `props` | prop → value, as drawn: defaults, then the primitive's state's props, then the instance's literal and bound values, then content from variations |
| `bound` | the props whose value came through `bind` |
| `unknown` | the bound props with no value to show, because there is no sample; a `text` one holds its placeholder in `props`, such as `{task.title}` |
| `state` | the state it is in, or nil |
| `place` | its size and placement fields as written: `width`, `height`, the min and max sizes, grid placement, `absolute` and its offsets (part 002) |
| `layout` | its layout fields as written, on a root, a component and a primitive that holds children |
| `children` | its nodes |
| `code` | on an error node, the check code |

The steps, in order:

1. **The frame's children.** The base's `children`, or the state's. A
   linked copy becomes its base instance with the copy's settings and
   its `inner` laid over it (`Speccy.Spec.override/2`); a copy naming no
   base instance is an error node, `unknown-copy`.
2. **Data.** A screen's scope is its `data` samples, each replaced by
   the state's `data` for that name. A component opened on its own has
   its props as its scope: a prop with a `default` has that value, the
   rest are unknown. Data with no `sample` is unknown.
3. **Bindings and repeats.** A bound prop takes the value at its path;
   a path through an unknown is unknown, and a `text` prop then shows
   the path in braces. A bound `state` or `variation` takes the name at
   its path, an empty or unknown one meaning the base. A `repeat` makes one node
   per item of its list, at most `limit`, with `as` in scope; over an
   unknown list it makes three rows, or `limit` when lower, with `as`
   unknown. A path that doesn't resolve makes the instance an error
   node, `bind-unresolved` or `repeat-unresolved`.
4. **Content.** The frame's variation: each `content` entry
   `<id>.<prop>` sets that prop on the node with that id in the frame's
   own file. Where an instance's component variation (step 5) set the
   same prop, the frame's wins.
5. **Expansion.** A component instance becomes a `:component` node: its
   `layout` is the component root's, its `place` the instance's over
   the component's own `width` and `height`, and
   its children are the component's own resolved frame, in the
   instance's state and variation, with the instance's values as the
   component's props, and its slots filled: a holder's children are the instance's
   fills for that slot, resolved in the instance's scope, with the
   instance's file as their origin. An unknown `use` is an error node,
   `unknown-use`; a component already being expanded, `component-cycle`.

### The composition rules

`Speccy.Check.Composition.run(spec)` keeps its name and what it returns.
Its walk, and everything in the module but the rules, is deleted.

For every valid screen and component, and each of its frames as written
(the base and each state, no variation), it resolves the frame and walks
the tree once, carrying whether it is inside something pressable and
inside a tablist.

- **Pressable:** a primitive whose interface says so, or whose
  `{:prop, p}` prop is truthy or unknown.
- **`pressable-in-pressable`:** a pressable node inside a pressable one.
- **`tab-outside-tablist`:** a node whose role is `tab`, not inside a
  node whose role is `tablist`.
- **`tabpanel-without-tab`:** a node whose role is `tabpanel` and whose
  id no tab in the tree names in `controls`. A tab whose `controls` is
  unknown names every panel.
- **`controls-unresolved`:** a `controls` that is known, set away from
  the primitive's default, and names no node's id in the tree.
- **`current-not-pressable`:** `current` away from the primitive's
  default on a node that isn't pressable.

A component's own frame has no surroundings, so three things wait for
where it is used: a tab at its top is taken to be in a tablist; its
tabpanels are checked only when the frame holds a tab; and a `controls`
it gets through `bind` is not checked.

Reporting:

- A problem is reported in the frame's own file, at the first entry of
  the node's `origin`. Its message names what was found, by its `use`
  (`button`), also when it is under a copy or named by `inner`. When the node is inside a component, the message
  says so, with the rest of the origin: `inside Offer, at /children/0`.
- A problem a component's own frames already report is not reported
  again where the component is used: one whose `origin`, from its
  second entry or any later one, equals the origin of a problem with
  the same code in that component's frames, is dropped.
- One problem per code and place.

### What goes

- The walk in `lib/speccy/check/composition.ex`.
- `format.md` § The checker's rules: the sentences on how the rules
  look through component instances are replaced by what this part does,
  and the three placeholder rows join § Component. `speccy explain`
  prints `format.md`, so it changes in this part and not before.

## Tests

- **Resolve,** on fixtures, asserting trees: a base frame; a state with
  a copy, an `inner` entry and an instance of its own; a state's `data`
  replacing a sample; a repeat over a sample, with `limit`; a bound
  `state` per row; a component alone, with placeholders and three rows;
  a component variation and a frame's variation setting the same prop,
  the frame's winning; slots filled, their origin the instance's file;
  nesting three components deep, the origin three entries long.
- **Resolve is total:** every broken fixture resolves every frame
  without raising, and `unknown-use`, `unknown-copy`, `component-cycle`
  and `bind-unresolved` each draw as an error node.
- **Composition:** every expectation in `test/speccy/check_test.exs`
  holds, apart from the ones this design changes on purpose, each
  changed with a comment saying why. The cases of spec-pmq.1 (a tab's
  `controls` bound to data), spec-pmq.2 (a fault under a state's copy,
  reported in the state), spec-pmq.5 (a `controls` default naming a
  panel where the component is used) and spec-pmq.3 (`current` and
  `role` reaching a primitive through a component's prop) each have a
  fixture and pass.
- **Cost:** every component of the `deep-nesting` fixture gains two
  states that copy its children, and its test's time grows with the
  frames drawn, not multiplied by states (Alberto, 2026-11-10: about
  25 ms against 9 ms before, three frames per component, accepted).
  The fixture stays six levels deep: a tree's size is what is drawn,
  and four wide and ten deep is a million nodes on any canvas. What this
  part removes is the multiplying by states.

## Done when

- `mix precommit` passes, and the suite takes no longer than it does
  today.
- A check of five levels of nesting, four instances and two states per
  level, takes under 20 ms (204 ms with the walk).
- `lib/speccy/check/composition.ex` holds rules and reporting only.
