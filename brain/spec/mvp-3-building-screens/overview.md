# MVP 3: building screens

Status: approved <!-- draft, approved (by Alberto) or built (when it lands) -->

The editor stops being read-only: instances are inserted, arranged, laid
out and given their copy, on the canvas and in a side panel, every edit
saved as it is made, with undo. Several are selected, moved,
duplicated, copied and pasted together, with Figma's gestures and keys.
Icons are picked from a dropdown, and `speccy icons` runs the same
search.

## What it delivers

Milestone 3 of [the MVP](../../prd/mvp.md): done when Alberto builds a
screen from nothing in the editor and the check passes it. Bead:
spec-yu5.

Alberto's rulings behind this design (2026-11-10):

- **Only the base frame is edited,** shown as written. State frames, and
  a base frame switched to a variation, are drawn and follow the base,
  and nothing in them can be selected until the milestone for states.
- **Deleting a base instance takes its linked copies** in every state,
  and the variation content that names it, as one edit and one undo.
- **A click inside a component instance selects the instance,** whole.
  Changing a part from outside, through a promoted prop, is milestone 4,
  and ⌘ reaching into a component comes with it.
- **Selecting works as in Figma:** a click selects the outermost
  instance, a double-click goes one level in, ⌘-click selects the
  deepest; Shift adds, and a drag from empty space draws a selection
  area.
- **Shortcuts are Figma's,** taken up as each feature lands
  (`conventions.md#figma-shortcuts`, `architecture/shortcuts.md`):
  here ⌘D, ⌘C, ⌘V, ⌘Z, V, H, Enter, Shift+Enter, Tab and Esc.
- **With several selected, the panel shows what they share,** "Mixed"
  where they differ, and a change goes to all of them.
- **Right-click opens a menu that fits what was clicked.** Here it
  offers copy, paste, duplicate and delete; later milestones add
  theirs.
- **Inserting is a drag from a palette.** A toolbar floats at the bottom
  of the canvas with "+", select and hand; "+" opens a searchable list
  of every primitive and the spec's components, each with its `about`,
  and a row is dragged onto the frame.
- **A layers tree** under the item list selects; arranging happens on the
  canvas only.
- **An edit that meets a file changed on disk is dropped,** and the
  editor says so. Nothing asks, and nothing is overwritten
  (`decisions.md#two-writers-like-files`, amended).
- **Bindings and data are a milestone of their own,** after components.
  Here a bound prop shows its path, read-only.
- **The icon picker and `speccy icons` are in this milestone.**

Where this design departs from `core.md`, which is frozen until the MVP
is built:

- **Conflicts are dropped, not asked about.** `core.md` holds the edit
  and asks: overwrite, or take the file.
- **Undo isn't cleared when a file changes outside.** An undo checks the
  disk as any write does; one that finds a file changed is refused, and
  the history is cleared then. `core.md` clears the entries that touch a
  changed file as it changes.
- **An edit names a file and its instances by id,** not by a chain, a
  frame and a variation: only instances written in the file on show, in
  its base, are edited. `conventions.md#address-by-id` holds; a chain is
  one id long until milestone 4.
- **A node's sources say only set, bound or default** for each prop.
  `core.md` also has the base, a copy and the variations, which come
  with the frames that have them.
- **Typing in place is a field the editor lays over the instance,** not
  the frame's own text made editable: frames stay `inert`, and no
  primitive's markup is known to the hook.
- **The editor has a layers tree, a toolbar with a palette, and a
  right-click menu.** `core.md` names none of them.
- **The props panel has no "reset all",** and picking a problem doesn't
  select what it is about.
- **An empty container draws at a small minimum size,** in the canvas
  and in `speccy render` alike, so it can be seen and dropped into.

## Design

Six hard parts, and the approach to each.

**1. Edits that are right by construction.** Every change is one
operation, a pure function from the spec to the files it changes
(`conventions.md#edits-are-operations`). There are eight: insert, move,
delete, duplicate, paste, set props, set fields, new screen. Resizing,
typing in place and every field of the panel are one of them, and each
takes several instances as one undo. Delete is the one with reach:
it removes the instance, what is inside it, their copies in every state
and the variation content that names them. Part 000.

**2. Two writers without a dialog.** Edits are written the moment a
gesture ends, so the only conflict is a file that changed on disk since
the workspace last read it. Before writing, the workspace reads each
file it is about to change; if any differs from what it holds, it writes
nothing, reads the spec again and tells the editor the edit wasn't
applied. A file drawn from its last good version can't be edited at
all: its edit would save over what the agent is in the middle of
writing. And no edit may write a file that fails its schema, since such
a file can't be drawn or edited again: the workspace checks that too.
Undo and redo are the same write with the same check. Part 001.

**3. One selection, three places.** The canvas, the layers tree and the
panel show the same selection, held by the LiveView as a list of ids.
An instance can be selected when it is written in the file on show:
its resolved node's `origin` has one entry, which is already what a
`data-chain` of one id says in the page. The panel reads the node,
never the file (`conventions.md#sources-not-dom`): Resolve says of each
prop whether it is set, bound or left to its default. Part 002.

**4. Gestures that never touch a frame.** Frames are `inert` and drawn
by the server, so the hook can't put handles or an editable text inside
one. Everything the hand sees (the selection's outline, resize handles,
the line that shows where a drop lands, the field for typing in place)
is drawn in one layer over the frames that the hook owns, from the
boxes the browser gives it. A gesture ends in one event naming ids,
never positions (`conventions.md#gestures-in-the-hook`). Part 003.

**5. Keys the window also wants.** The app runs inside a host whose own
Edit menu claims ⌘C, ⌘V and ⌘Z, and the end-to-end tests run without
that host. Copy and paste therefore answer the page's `copy` and
`paste` events, which the keys and the host's menu both end in, with
the system's clipboard holding the instances as JSON text. Undo is
caught as a key, and tried by hand in the window. Parts 003 and 004.

**6. One icon search.** The picker and `speccy icons` call the same
function over the shipped indexes and the spec's own sets. The picker's
previews are the SVGs the canvas draws, from the same cache, fetched in
the background the same way. Part 005.

## Parts

Each part is built and reviewed on its own, in order.

- [000-edit](000-edit.md): `Speccy.Edit`, the eight operations.
- [001-workspace](001-workspace.md): the workspace writes edits, checks
  the disk first, and keeps undo and redo.
- [002-panel](002-panel.md): selection, the layers tree, the props
  panel and a new screen. After it, a screen can be built without the
  canvas: select in the layers, edit in the panel.
- [003-canvas](003-canvas.md): the toolbar and its palette, and the
  hook's gestures: select one or several, insert, move, resize, type,
  delete, undo.
- [004-clipboard-and-menu](004-clipboard-and-menu.md): duplicate, copy
  and paste, and the right-click menu.
- [005-icons](005-icons.md): the icon search, `speccy icons` and the
  picker in the panel.

## Out of scope

- Editing in a state's frame, variations, copying an instance into a
  state: the milestone for states.
- Changing a part inside a component from a screen, filling a
  component's slots, creating a component and its props: milestone 4.
- Binding a prop, repeats, a screen's data and data models: the
  milestone for data and bindings.
- Renaming an instance's id or an item, and deleting an item.
- Dragging an absolute instance on the canvas: its offsets are set in
  the panel.
- Dragging in the layers tree.
- Figma's shortcuts for what speccy doesn't have yet: cut, select all,
  dragging out a copy, the zoom keys (`architecture/shortcuts.md`).
- How the app and the canvas look: a milestone of its own, once states
  have landed.
