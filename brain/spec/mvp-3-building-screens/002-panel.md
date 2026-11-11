# MVP 3: selection, the layers tree and the props panel

Bead: spec-yu5

The selection, shown in a layers tree and edited in a props panel, and
a way to start a screen. After this part a screen can be
built with no canvas gesture: insert comes with part 003, so its tests
start from a fixture.

## Program design

### What a node says about its props

`Speccy.Resolve` adds one key to a node, `source`: prop → `:set` for a
prop the instance writes in `props`, `{:bind, path}` for one it binds.
A prop in neither is left to its default. The panel reads it, and never
the file (`conventions.md#sources-not-dom`).

### Selection

`SpeccyWeb.EditorLive` holds `selected`, a list of instances' ids. An
instance can be selected when its node, in the base frame's tree, has
one entry in `origin`: it is written in the file on show. The event
`"select"` with `%{"ids" => ids}` sets it, leaving out any id the base
tree doesn't hold. It is emptied when the item on show changes, and a
redraw drops the ids it no longer finds.

Every edit goes through one function of the LiveView: it calls
`Speccy.Workspace.edit/2` with the file on show, selects the returned
ids, and on an error puts a flash: for `:conflict`, that the edit wasn't
applied because the file changed on disk; for `:stale`, that the file
can't be edited until it reads again; for `:invalid`, that the result
wouldn't be a valid file; for the rest, that it couldn't be
applied. The redraw comes from the workspace's broadcast, as today.

### The layers tree

Under the item list, a section "Layers": the base frame's nodes that
can be selected, indented by depth, each its id and its `use`; a
repeat's rows appear once. A click selects that one; a click with
Shift adds it to the selection, or takes it out. The selected rows are
highlighted.

### The props panel

The right column holds the panel above the problems list. It shows the
selection: one instance, several, or with nothing selected the item
itself. Every
field commits when it changes (a text field on blur or Enter), as one
`:props` or `:set` operation. A value a field can't read, such as
letters where tracks are expected, is not sent.

These are the page's first text fields, and milestone 2's canvas hook
takes every Space for panning: from this part on it leaves the key
alone while a field of the app has the focus.

For an instance:

- **Header:** its id and `use`, and `about` as a text field.
- **Props:** one field for each prop its target declares, in declared
  order, by type: `text` a text field; `bool` a checkbox; `number` a
  number field; one of a list of strings, a select; `text[]` a text
  area, one item per line; `icon` a text field holding the reference,
  until part 005. A prop left to its default shows the default as the
  field's placeholder. A set prop has a reset beside it, which removes
  it. A bound prop shows its path and no field. A prop of a model's
  type appears only when bound.
- **State and variation:** a select each, of the target's states and of
  that state's variations, with "none"; hidden when the target has
  none, read-only when bound.
- **Size:** width and height, each `fill`, `hug` or a number of pixels;
  the four minimums and maximums; in a grid, `column`, `row` and the
  spans; `absolute`, and with it the six offsets. Clearing `absolute`
  removes the offsets in the same operation.
- **Layout,** when it holds children: `layout`, `wrap`, `columns` and
  `rows` (a number, or tracks separated by commas), `align` (the nine
  positions), `gap` (a number, or `between`, `around`, `evenly`),
  `lineGap`, `padding` (one, two or four numbers) and `clip`. A field
  shows `format.md` § Layout's default as its placeholder.

For several instances, as Figma does it: how many are selected, then
only what they share. A field's value is theirs when they agree, and
"Mixed", as its placeholder, when they differ; a change is written to
all of them, as one operation and one undo.

- **Props:** the props every one of them declares, with the same type.
  One that any of them binds shows as bound.
- **State and variation:** when they all have the same `use`.
- **Size:** always.
- **Layout:** when every one of them holds children.

For the item: `about`; for a screen, `device` (the presets and the
spec's own) and `orientation`; for a component, `width` and `height`;
and Layout.

### A new screen

A "+" beside the item list's Screens heading opens a form: name, about
and device. Submitting runs `{:new_screen, …}` and shows the new
screen. A refused name shows under its field.

## Tests

- **Resolve:** `source` on a node with a set prop, a bound prop and one
  left to its default.
- **Editor,** `Phoenix.LiveViewTest` on a workspace over a temp copy:
  - A click in the layers selects; the panel shows that instance's
    props; a repeat's instance is listed once.
  - Two instances selected with Shift: the panel shows the props both
    declare, "Mixed" where they differ, and a width set there is
    written to both, undone by one undo.
  - Changing a text prop writes it to the file; its reset removes it.
  - A bound prop shows its path and has no field.
  - Changing width to a number, then to `fill`, writes each.
  - A layout field on a container, and one on the screen with nothing
    selected.
  - A new screen appears in the list, is on show, and its file passes
    the check.
  - An edit that meets a file changed on disk shows the flash and
    leaves the file as the outside change left it.

## Done when

- `mix precommit` passes.
- On the `tasks` fixture, Alberto selects the header in the layers,
  changes its title in the panel, and the canvas and the file both
  show it.
