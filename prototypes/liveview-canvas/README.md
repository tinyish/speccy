# Spike: a LiveView canvas

Throwaway. It tests whether Elixir + Phoenix LiveView (clay's stack) can
carry speccy's canvas: one screen, its base and a frame per state, drawn
as real HTML; drag to reorder, pan and zoom, and copy edited in place,
all written straight to the spec's JSON files.

## Run

```sh
elixir canvas.exs                       # http://127.0.0.1:4100
SPEC_DIR=/some/copy PORT=4200 elixir canvas.exs
```

Elixir 1.18+; `Mix.install` fetches Phoenix, LiveView and Bandit on the
first run. With no `SPEC_DIR` it edits a fresh temp copy of
`../spec-format/example`, never the live spec, and prints its path: edit
those files by hand to play the agent.

- Drag a top-level instance in the base frame to reorder it.
- Double-click copy to edit it in place; Enter saves, Esc cancels. In a
  state's frame the edit goes to that state's `set`.
- Wheel pans, Cmd/Ctrl+wheel zooms, space+drag or middle-drag pans.
- The bottom-left box shows each commit's round trip.

## How it splits

Everything you feel is client-side, in one JS hook: pan and zoom, the
drag preview and drop target, and the contenteditable. The server sees
only the committed result (`reorder`, `edit`), applies it to the spec,
writes the file and re-renders every frame; LiveView sends the diff. It
polls the spec folder every 300 ms and reloads when anything else changed
it.

## Findings

Driven with Playwright on the task example (Chromium, then WebKit, the
engine elixir-desktop's macOS webview uses):

| | Chromium | WebKit |
|---|---|---|
| Reorder, round trip (server) | 14.5 ms (1.8) | 9.0 ms (1.4) |
| Copy edit, round trip (server) | 17.3 ms (0.3) | 3.0 ms (0.5) |
| Outside file edit shown | 185 ms | 26 ms |

Both pass every check: five frames drawn, the file's order changes after
a drag, an edit in the base writes the prop, an edit in the empty frame
writes `states.empty.set` and leaves the base alone, no console errors.
The outside-edit time is mostly the 300 ms poll.

## Not done

- Not run inside elixir-desktop's window; WebKit in Playwright stands in.
- The primitives are drawn by hand (text, button, input, checkbox, list,
  container, dialog), not from the catalog's render templates.
- Bound values show as `{task.title}`, and a repeat draws three copies.
- Files are rewritten with sorted keys (plain maps), so state order is
  alphabetical and diffs are noisy.
- No undo, insert, resize, nesting by drag or layout panel.
