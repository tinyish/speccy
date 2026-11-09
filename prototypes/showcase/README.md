# speccy showcase

A throwaway prototype: a tiny Storybook for speccy's primitives. It shows
every `../catalog/primitives/<name>.json` drawn as a wireframe, per the
contract in `../catalog/RENDER.md`, and edits the files in place.

## Run

```sh
npm install
npm run dev            # http://localhost:5173, on ../catalog/primitives
PRIMITIVES_DIR=/some/dir npm run dev   # on another folder
npm test               # renderer and validate.mjs (vitest)
npm run e2e            # Playwright on a temp copy of fixtures/, then a copy of the live catalog
npm run build          # tsc + vite build
node ../catalog/validate.mjs [dir]     # "ok", or one line per error
```

- **Left:** search, primitives by category, a red dot on any with validation errors.
- **Canvas:** a `default` frame (defaults only), one per state (defaults + its
  overrides), then one per example, titled "example · <name>".
  Glyphs (`wf-symbol`) use Material Symbols Outlined from Google Fonts; offline,
  their names show as text. Wheel pans, ctrl/⌘+wheel or pinch zooms, middle-drag or
  space+drag pans, shift+1 fits.
- **Right:** Info (with Figma links), Props (preview controls, "save as
  default", "reset"), States, Examples (when there are any), Events, and Definition: the whole file as
  JSON. A definition edit is saved 400ms after you stop typing if it parses
  and passes `validate.mjs`; otherwise it isn't written and the panel says why.
- Files added or changed by anyone else show up live. Loading writes nothing.

`src/render.tsx` (the renderer) and `src/wireframe.css` (the `wf-*` classes)
are meant to be reused by the editor.

## Not done

- No undo; no creating, renaming or deleting primitives from the UI.
- Conditions have no `<`/`>` and no and/or: dialog and popover nest
  an `if` inside another (a `display:contents` wrapper) to test two props.
- No or in `classIf`: container needs `wf-selected` when selected or when
  current, so it is keyed twice (`wf-selected`, and `wf-box wf-selected`,
  repeating a class the node already has).
- No text functions: date-picker finds a date's day as
  `date[8] * 10 + date[9]` (character lookups on an ISO date). It works for
  the sample data and reads as a trick.
- `wf-scroll` gets a 240px max height so it has something to clip at.
- A plain `button` is reset to its content; `wf-btn` draws one.
- A save that races an outside change to the same file wins; nothing merges.
- `npm run e2e` draws every live primitive into `screenshots/all/`
  (`node e2e.mjs catalog [name…]` for just that part).
