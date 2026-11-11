# MVP 3: duplicate, copy and paste, and the right-click menu

Bead: spec-yu5

The selection duplicated, copied and pasted, with Figma's keys, and a
menu on right-click that offers what fits what was clicked.

## Program design

### Duplicate

⌘D sends `duplicate` with the selection's ids; the LiveView runs
`{:duplicate, …}` and the copies become the selection.

### Copy and paste

The clipboard is the system's, and what it holds is text: the selected
instances as written, a JSON list, their keys in `format.md`'s order.
So a copy can be pasted into another screen, another spec, or a
message to an agent, and an agent's instances can be pasted in.

- The LiveView keeps that text on the canvas as `data-copy`:
  `Speccy.Edit.copy/3`'s instances, encoded by a function `Speccy.Format`
  gains for a list of instances
  (`conventions.md#json-through-format`), written again whenever the selection or the
  spec changes: a `copy` event must fill the clipboard before it
  returns, with no trip to the server.
- **Copy:** the hook answers the page's `copy` event, when no field of
  the app has the focus and something is selected, by putting
  `data-copy` on the clipboard as plain text.
- **Paste:** the hook answers the page's `paste` event, when no field
  has the focus, by sending `paste` with the clipboard's plain text.
  The LiveView decodes it (`Speccy.Format.decode/1`) and runs
  `{:paste, …}`: after the selection, in its parent, when there is one;
  else at the end of the frame. The pasted instances become the
  selection. Text that isn't instances does nothing.

The page's `copy` and `paste` events are used, not the ⌘C and ⌘V keys,
because the host's Edit menu owns those keys and turns them into these
events.

### The right-click menu

A right-click in the canvas opens a menu at the pointer, the app's own
interface, and the browser's is kept from opening. What it offers
depends on what was clicked, each item with its shortcut beside it:

| Clicked | Offers |
| --- | --- |
| An instance in the editable frame | Copy, Paste, Duplicate, Delete. The instance is selected first, unless it is already part of the selection. |
| The frame itself, or the canvas outside it | Paste. |

Each item runs what its shortcut does. Copy writes `data-copy` to the
clipboard, and Paste reads the clipboard, through the page's clipboard
interface, since no `copy` or `paste` event comes with a click. A click
elsewhere, or Esc, closes the menu.

The menu is built to grow: an item is a name, a shortcut and an event,
listed for the kind of thing clicked. Later milestones add theirs
(a component's actions, adding a state from the canvas).

### In the window

Copy and paste are the system's, so they are tried by hand in the
window: ⌘C and ⌘V, the Edit menu's Copy and Paste, and the right-click
menu's. WebKit may ask the user before a page reads the clipboard
outside a `paste` event; if the window does, the builder says so and
the menu's Paste is left out.

## Tests

- **Editor,** `Phoenix.LiveViewTest`: `duplicate` writes the copies and
  selects them; `data-copy` holds the selection's instances; `paste`
  with that text, on another screen, writes them there with ids that
  are free; `paste` with other text changes nothing.
- **End to end,** Playwright WebKit: ⌘D duplicates the selection; ⌘C on
  one screen and ⌘V on another pastes the instance; a right-click on an
  instance opens the menu, and its Delete removes the instance; a
  right-click on the canvas offers only Paste.

## Done when

- `mix precommit` passes, and `npm test` in `e2e/`.
- In the window, Alberto copies two instances with ⌘C, pastes them on
  another screen with ⌘V, and pastes the same clipboard into a text
  editor as JSON.
