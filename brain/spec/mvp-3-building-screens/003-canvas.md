# MVP 3: the toolbar and the canvas's gestures

Bead: spec-yu5

The hand on the canvas: a toolbar with a palette to insert from, and
the hook's gestures to select one instance or several, insert, move,
resize, type, delete and undo. Selecting works as it does in Figma, and
every key is Figma's (`conventions.md#figma-shortcuts`). Each gesture
lives in the hook until it ends, then sends one event
(`conventions.md#gestures-in-the-hook`).

## Program design

### The toolbar and the palette

A toolbar floats at the bottom centre of the canvas, the app's own
interface (`conventions.md#app-ui-the-phoenix-way`), outside the world
the hook pans: "+", select and hand.

- **Select and hand** are the two tools, select by default, switched by
  their buttons or by V and H; the LiveView holds which, and the canvas
  carries it as `data-tool`. With the hand, a drag on the canvas pans,
  as space-drag does, and nothing is selected or moved.
- **"+"** opens the palette above the toolbar, and closes it: a search
  field, then a row for each primitive, grouped by its interface's
  category, then one for each of the spec's components. A row is the
  name and its `about`, and carries the name as `data-use`. Typing in
  the search keeps the rows whose name or `about` holds the text.

### The layer

One element in the world, above the frames, that the hook owns
(`phx-update="ignore"`): the selection's outlines, the resize handles,
the selection area, the line that shows where a drop lands, and the
field for typing in place. The hook draws it from the boxes of the
frame's elements, and again after every patch, pan and zoom. Nothing is
drawn inside a frame.

The canvas carries `data-selected`, the selected ids. The hook finds
the base frame's elements whose `data-chain` is one of them (a repeat
has one per row) and outlines each.

Gestures act only in the base frame shown as written; the LiveView
marks that frame's figure `data-editable`. Elsewhere a click selects
nothing.

An element stands for an instance that can be selected when its
`data-chain` is one id: not empty, as the frame's root's is, and with
no `/`. Such an element's parent is the nearest one
above it, or the frame; its children are the nearest ones below it.
`Speccy.Draw` adds `data-holds` to a primitive that holds children.

### Selecting

| Gesture | Selects |
| --- | --- |
| Click | Of the selectable elements at or above the pointer: the one that shares a parent with something selected, when there is one; else the outermost. A click on the frame itself, or outside it, clears the selection. |
| Double-click | The child of the selection that is under the pointer: one level in. With no such child, it types in place (below). |
| ⌘-click | The deepest selectable element under the pointer. |
| Shift with any of them | Adds that instance to the selection, or takes it out. |
| Drag from the frame itself or from outside it | A selection area: on letting go, the frame's outermost instances that the area touches. With Shift they are added. |
| Enter | The selection's children; with none, it types in place. |
| Shift+Enter | The selection's parent. |
| Tab, Shift+Tab | The next sibling of the selection, and the one before. |
| Esc | Nothing: it clears the selection. |

Each sends `select` with the ids.

### Changing

| Gesture | Does | Event |
| --- | --- | --- |
| Drag an instance | Moves it, and with it everything selected when it is part of the selection: a line shows where they would land, and letting go sends the move. A drop where they already are sends nothing. | `move` `{ids, into, before}` |
| Drag a palette row | Inserts: the same line, the same drop. A drop outside the frame does nothing. | `insert` `{use, into, before}` |
| Drag a handle | Resizes, with one instance selected: it has a handle on its right edge when its width is a number, on its bottom edge when its height is, and on the corner when both are. The outline follows the pointer; letting go sends the size in whole pixels, the pointer's travel divided by the zoom. | `set` `{ids, fields}` |
| Delete, Backspace | Deletes the selection. | `delete` `{ids}` |
| ⌘Z, ⇧⌘Z | Undo, redo (`decisions.md#shortcuts-in-page`). | `undo`, `redo` |

The keys do nothing while a field of the app has the focus.

**Where a drop lands.** The container is the deepest element under the
pointer that is the frame's root, or can be selected and has
`data-holds`, and isn't a dragged instance or inside one. A container
inside a component instance is neither, so a drop over one lands
beside the instance. Among that container's children, the
drop is before the first whose middle the pointer hasn't passed along
the container's flow (its computed `flex-direction`; for a grid or a
stack, the order they are drawn in), or at the end. `into` is the
container's id, nil for the root; `before` the child's id, nil for the
end.

**Typing in place.** The hook sends `text` with the instance's id. The
LiveView answers with the target's first prop of type `text`, in
declared order, and its literal value, or with nothing when there is
none or it is bound. The hook then lays a text field over the element,
holding the value; Enter or leaving the field sends `props` with the
new text, Esc drops it.

### In the LiveView

Each event becomes one call of the edit function part 002 added:
`insert`, `move`, `delete`, `props` and `set` as the operation of that
name on the file on show; `undo` and `redo` as the workspace's. An
undo or redo that returns `:conflict` shows the flash an edit does; one
that returns `:nothing` shows none.

### An empty container

`wireframe.css` gives a primitive that holds children, with none, a
small minimum size and a dashed outline, so an empty container can be
seen and dropped into. It draws so in `speccy render` too.

### In the window

The end-to-end tests run the page in WebKit without elixir-desktop's
host, whose own Edit menu also claims ⌘Z. Whether ⌘Z and ⇧⌘Z reach the
page in the window is tried by hand. If the host takes them, the
builder stops and says so: where undo then lives is a decision.

## Tests

- **Editor,** `Phoenix.LiveViewTest`: each event from the hook becomes
  the right change in the file (`testing.md` § Editor); `text` answers
  with the first text prop and its value, and with nothing for a bound
  one; `undo` after an edit restores the file.
- **End to end,** Playwright WebKit, one test per gesture
  (`testing.md` § End to end), on a temp copy of the `tasks` fixture
  with a container nested two deep added to it:
  - click selects the outermost and outlines it, double-click goes one
    level in, ⌘-click selects the deepest, a click on a sibling stays
    at that level, Esc clears;
  - Shift-click adds a second; a selection area selects what it
    touches;
  - Enter, Shift+Enter and Tab move the selection;
  - a drag reorders two instances; a drag moves two selected instances
    into a container, in their order;
  - a palette row dragged onto the frame inserts it there;
  - a handle resizes a fixed width, at a zoom other than 1;
  - a double-click on a text, typing and Enter change the copy;
  - Delete removes the selection, ⌘Z brings it back;
  - a click in a state's frame selects nothing;
  - H, then a drag, pans; V goes back.
- **The milestone's "done when",** as a script: a new screen, a
  container dragged in, a text and a button dragged into it, the text
  typed over, a gap set in the panel, and the problems list empty.

## Done when

- `mix precommit` passes, and `npm test` in `e2e/`.
- Alberto builds a screen from nothing in the editor, and the check
  passes it.
- In the window, ⌘Z undoes and ⇧⌘Z redoes.
