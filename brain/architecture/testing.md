# Testing

How speccy is tested, and what proves it works. Specs and milestones say
which tests each part adds; this says what kind of test goes where, and
how they run. Milestone 1 sets up every level it needs; the rest join
with the milestone that first needs them.

## Levels

- **Core:** ExUnit, `async: true`, under `test/speccy/`. The pure core
  on spec folders in `test/fixtures/specs/<name>/`, real spec folders as
  `format.md` defines them, never JSON built inline in a test:
  - Format: a file the app wrote decodes and encodes back to the same
    bytes, and key order survives.
  - Check: every code has a fixture that triggers it, asserted by code,
    file and path, and the clean fixtures report nothing
    (`codes-in-one-list`).
  - Resolve and Layout: a frame of a fixture resolves to the expected
    tree, values and sources, and layout fields give the expected CSS;
    broken fixtures resolve to error nodes, never a raise
    (`resolve-is-total`).
  - Edit: an operation on a fixture gives the expected files, compared
    as JSON.
  - Primitives: every interface has the required fields and only
    `format.md`'s types, and, once primitives draw, every primitive
    draws each of its interface's examples.
  - Schemas: what `Speccy.Schemas` builds equals what is in
    `priv/schemas/`; the drift guard.
  Never covers files on disk, processes or the page.
- **Workspace:** ExUnit with `@tag :tmp_dir`, a fixture copied into it.
  Edits write files; a file changed from outside reloads and is
  broadcast; a write after an outside change is held as a conflict; undo
  and redo; what the app didn't change is never rewritten. Waits on the
  PubSub message, never a sleep (`no-sleeps`).
- **Editor:** `Phoenix.LiveViewTest`, under `test/speccy_web/`, on a
  workspace over a temp copy: an event from the hook becomes the right
  edit in the files, the panel shows each value's source and resets it,
  the problems list follows the check. Never covers the hook's gestures.
- **CLI:** each command run in-process (`Speccy.CLI.main/1`) on fixtures,
  asserting its output and exit status; `render` checks the HTML file and
  that it holds the wireframe stylesheet. The packaged launcher is
  covered once, by its prototype, and then by hand on each release.
- **Icons:** search on the shipped index; the fetch and its cache
  against `Req.Test`, never the network; unsafe SVG fixtures refused by
  the check.
- **End to end:** Playwright, WebKit (the engine of elixir-desktop's
  macOS view), under `e2e/`, against the app run as a local web server
  on a temp copy of a fixture, with real mouse and keyboard events. One
  test per gesture the hook owns, and one per milestone "done when" a
  script can see, such as an agent's edit appearing without a reload.
  It also checks that a frame on the canvas and the same frame from
  `speccy render` place every node in the same box.

## Running

- `mix test`: core, workspace, editor, CLI and icons; seconds.
- `mix precommit`: compile with warnings as errors, unused deps, format
  and `mix test`; passes before any change is handed over.
- `npm test` in `e2e/`: starts the server on a temp copy and runs
  Playwright WebKit; before handing over any change to the canvas or
  the editor.
- `mix speccy.schemas`: writes `priv/schemas/` again after a format
  change; the drift guard fails until it is run.

## Evals

The MVP rests on agents writing a spec from its files alone, which no
test passes or fails. The agent eval measures it:

- **Set:** one-sentence requests in `evals/agent/`, each with the fixture
  spec it starts from: add a screen with a state (milestone 1's "done
  when"), add a component, add a state to an existing screen, add a
  variation, change a part inside a component on one screen. A request
  joins when a milestone makes it possible, or when a format change could
  break it.
- **Run:** a fresh agent (`claude -p`), given only a temp copy of the
  spec and `speccy` on its PATH, no repository and no docs; its result is
  run through `speccy check` and the request's own assertions on the
  files (what was added, and nothing else changed).
- **Bar:** every request passes on the first attempt. A failure is a
  format gap: closed in the format, or written down, as milestone 6
  asks.
- **When:** by hand, at each milestone that changes the format and
  before the MVP is marked built; not on every change, since each run
  costs a model's tokens.

## Not tested

- **How wireframes and the app look:** Alberto judges them by eye; tests
  check structure and boxes, never pixels.
- **elixir-desktop's own window** (menus, folder picker, the view):
  covered by its prototype and by Alberto's use; e2e runs the same page
  in WebKit outside it.
- **PNGs from `speccy render`:** only that a file is written when Chrome
  is present; Chrome's screenshot isn't speccy's code.
- **Material's live servers:** the fetch is tested against `Req.Test`;
  the pinned version is checked by hand when it is bumped.
