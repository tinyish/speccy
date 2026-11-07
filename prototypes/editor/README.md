# Prototype: the spec editor

Throwaway. A Figma-like editor (Figma's dark UI) for the spec format in
`../spec-format`. The selected screen or component is drawn as frames on
a canvas, one for its base and one per state. You build it by dragging
layouts and components from a toolbar, and edit its auto layout, states,
interactions and bindings in a side panel. Every edit is written straight
to the spec's JSON files and checked with its `check.mjs`.

## Run

```sh
npm install
npm run dev                       # edits ../spec-format
SPEC_DIR=/some/copy npm run dev   # edits another spec directory
```

- `npm run build`: type-checks (strict) and builds.
- `npm test`: vitest over the pure spec-editing helpers (`src/spec.ts`).
- `npm run e2e`: copies `../spec-format` to a temp dir, with
  `example/`'s task example in place of the live spec, and drives the
  real app on it with Playwright and real mouse events. It checks:
  - loading writes nothing
  - panning and zoom speed
  - inserting, reordering and moving by drag, on the canvas and in the
    layers
  - resize handles
  - gap, padding, align and wrap
  - editing in a state frame
  - the toolbar and the palette
  - repeat limits, the device switch and renaming from a frame title
  - outside edits, and `check.mjs` at the end

  It retakes the screenshots in `screenshots/`.

## Using it

- **Left:** the items of the tab. Below them are the selected item's
  layers, once for the base and once per state, as each state leaves
  them; hidden layers are dimmed. Drag layers to reorder them, or into a
  container.
- **Canvas:** the base frame and a frame per state, side by side. Click an
  instance in a state's frame and edit it, and the change goes to that
  state's `set`; the panel marks overridden fields in purple with a
  reset. Click a state's frame or title to name it, describe it, reorder
  it or delete it. Drag instances to reorder them or move them into
  another container. A fixed width or height gets resize handles.
- **Screen titles:** click the name to rename it, and click the size to
  switch between Desktop, Tablet and Mobile.
- **Toolbar:** search opens a palette of every component, with live
  previews. Enter or click inserts into the selection's container, or drag
  a result onto the canvas or into the toolbar. Drag toolbar icons onto
  the canvas; drag one away and drop it anywhere that isn't a drop target
  to remove it. The toolbar's contents are kept in localStorage.
- **Shortcuts:**
  - space+drag or middle-drag to pan; wheel or two-finger scroll also pans
  - Cmd/Ctrl+wheel or pinch to zoom
  - Shift+1 zooms to fit, Shift+0 to 100%
  - Esc selects the parent
  - Delete removes the selected instance, or hides it in a state's frame
  - Cmd+Z / Shift+Cmd+Z undo and redo

## How it works

- **Server:** `vite.config.ts` holds a small plugin.
  - `GET /api/spec` returns the spec and its errors, through `load` and
    `check` from the spec dir's `check.mjs`.
  - `POST /api/spec` writes and deletes (and so renames) item files,
    skipping any whose content is unchanged, and returns fresh errors.
  - It watches the spec dir and pushes a `spec-changed` HMR event for
    changes it didn't make itself; the editor then reloads the spec and
    keeps the selection.
- **Saving:** the editor diffs each item's JSON against what it last saved
  and sends only what changed, 300 ms after the last edit. Files are
  written with keys in the format's order and empty parts dropped.
- **Drawing:** the canvas draws layout with CSS flex and grid. A repeat
  with no limit draws as many copies as fit its container along its
  direction (3 when the container hugs).

## Not done

- **Toolbar:** dropping on empty canvas no longer creates a component,
  because a drop there now means "remove this icon". Use "+" in the list.
- **No editing shortcuts:** no copy, paste, duplicate or multi-select.
- **Renames:** renaming a take, emit, local, data entry or model field
  doesn't update the paths and actions that use it (the checker flags
  them). Renaming an instance id, a state, an item or an operation does.
- **File names:** item files are assumed to be named after their item.
- **Outside changes:** one clears undo history, and an edit still inside
  its 300 ms autosave window when one arrives is lost.
- **States:** bound props and repeats can't be overridden in a state.
  States set literals and layout fields only, by the format.
- **Canvas drawing:**
  - An open dialog floats over its frame and can stick out of a short one.
  - Repeats only fit copies in a row or column that doesn't wrap; in grids
    and stacks they draw 3.
  - Frames can't be moved: they sit side by side.
- **Checker:** `check.mjs` is imported once per server run, so changes to
  the checker itself need a restart.
