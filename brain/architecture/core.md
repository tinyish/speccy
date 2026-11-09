# Core

How speccy fits together, from above: enough to see how the pieces
work together and to build prototypes from. What it must do is in `prd/`;
how it's built and written is in `conventions.md`. What a spec is on disk
is in [format](format.md).

It is a mirror of the code, kept in sync the way AGENTS.md says; where the
two disagree, the code wins.

<!-- Keep the line below: the arch-docs skill maintains it. -->
Synced to `f2fb960`

## The shape

One Elixir application, run two ways: as the desktop editor, a Phoenix
LiveView app in elixir-desktop's window, and as the `speccy` command,
which starts without a window or a web server. Both rest on the same
pure core; only the editor holds a spec open.

```map
agent     "a coding agent"                                 -> files : reads · writes JSON and SVG
agent     -> cli : check · render · explain · icons · open
files     "the spec folder, in the project's repo"         -> workspace : changes on disk
workspace "one process per open spec · undo · watcher"     -> files : writes
workspace -> core : load · edit · check
editor    "LiveView · item list · canvas · props panel"    -> workspace : committed edits
workspace -> editor : spec changed · problems
canvas    "JS hook · pan · zoom · drag · type in place"    -> editor : committed edits
editor    -> core : resolve and draw a frame
cli       "the speccy command · no app needed"             -> core : load · check · resolve · draw
core      "pure · format · resolve · layout · check · edit · primitives" -> icons : SVGs
icons     "shipped indexes · ~/.speccy cache · spec sets"
```

| Part | Does | Lives |
| --- | --- | --- |
| **agent** | Reads and writes the spec's files like code, and runs `speccy` to check and look at its work. | the user's terminal or IDE |
| **files** | The spec: `speccy.json`, components, screens, data and icons, as [format](format.md) defines them. | the project's repository |
| **workspace** | Owns an open spec: reads its files, applies edits, writes them, keeps undo, watches the folder and re-checks on every change. | a GenServer in the app, one per open spec |
| **editor** | The window's one page: the item list, the canvas with a frame per state, the props panel and the problems list. | a LiveView in the app |
| **canvas** | Everything the hand feels: pan, zoom, selection outlines, drag previews and drop targets, resizing and typing in place. Sends only the finished edit. | a JS hook in the page |
| **core** | Pure functions: decode and encode files, resolve a frame into a tree to draw, lay it out, check a spec, apply an edit, and the 25 primitives. No processes, no IO. | modules in the app, shared by the editor and the CLI |
| **cli** | `speccy check`, `render`, `explain`, `icons`, `open`. | the same release, started in command mode |
| **icons** | Searches icons and hands back SVGs: supported libraries from shipped indexes and a per-user cache, the spec's own sets from its `assets/`. | core for the index and spec sets; a fetch on cache misses |

## What carries the weight

- **The files are the model.** The app holds each file as the JSON it
  read, decoded with its key order kept, and nothing else: no structs,
  no database, no second copy to keep in step. Edits change that JSON
  and write it back; what the canvas draws is worked out from it every
  time. Why: the format is expected to break while the MVP is used
  (`mvp.md`), agents write the same files, and a translation layer would
  be one more thing to change each time. Key order is kept because it
  is meaning: states and variations are drawn in the order written.
- **A pure core under a thin shell.** Resolving, laying out, checking
  and editing are functions from JSON to JSON or to a tree, in the same
  modules for the editor and the CLI. Only the workspace, the LiveView,
  the icon fetch and the CLI's arguments touch processes or IO. Why: the
  check and the drawing can't differ between what Alberto sees and what
  an agent renders, and nearly everything is testable without a window.
- **Instances are addressed by id.** An edit names its file and the
  chain of instance ids from the file's root to the part it changes,
  never positions in lists. Why: an agent may reorder a file between
  two edits; ids are unique in a file and survive that.
- **Everything drawn knows where it came from.** Each node of a
  resolved frame carries its source: the file, the instance chain, and
  for each value, whether it came from the base, a copy, a component
  variation, a state's variation, a binding or a default. Why: the props
  panel shows where each value comes from and resets it, and an edit to
  a part inside a component has to know which props to add on the way
  down (`overrides-promote-props`).
- **A broken spec still draws.** Resolving never fails: an unknown
  component, a dangling copy or a bad binding draws as an error box with
  its check code, and a file that isn't valid JSON keeps its last good
  version on the canvas, flagged. Why: agents leave a spec broken
  between two writes, and the editor must keep working through it.
- **Write only what was read.** The workspace remembers the content of
  each file as it last read or wrote it, and checks the disk still
  matches before every write. A mismatch is a conflict the user settles
  (`two-writers-like-files`). Why: nothing an agent wrote is overwritten
  silently, without a merge engine.

## The core

What each part of the pure core does. Module names are a starting point,
not a contract.

- **Format** (`Speccy.Format`): finds a spec (the folder holding
  `speccy.json`), reads every file into a map of file path → decoded
  JSON (`Jason`, ordered objects), and encodes a file the way
  [format](format.md#writing-files) says: 2-space JSON, `$schema` first,
  keys in each kind's table order. Encoding a file the app didn't change
  is never needed, so an agent's key order survives until the app edits
  that file.
- **Resolve** (`Speccy.Resolve`): turns one frame, an item with the
  base or one state and, optionally, a variation, into a tree of nodes
  ready to draw. In order: take the frame's children (a state's linked
  copies become their base instance with the copy's settings and its
  `inner` laid over them); fill data (the screen's samples, replaced by
  the state's `data`; placeholders such as `{task.title}` for a
  component opened alone); resolve bindings and repeats; lay content on
  top (the instance's component variation, then the state's variation,
  which wins); and expand every component instance into the component's
  own resolved tree, in the instance's `state`, with its slots filled.
  Each node keeps its source (above).
- **Layout** (`Speccy.Layout`): turns layout fields and sizes into CSS
  on each node: `row` and `column` into flex, `grid` into CSS grid,
  `stack` into a grid with every child in one cell, `absolute` into
  absolute positions, fill and hug into flex-grow and fit-content.
  The browser computes the geometry; nothing computed is stored
  (`canvas-renders-dom`).
- **Primitives** (`Speccy.Primitives.*`): one module per primitive, 25
  in all (`primitives-in-code`). Each holds its interface as data (about, element and role, props and
  their types, events, states, defaults, examples, and the facts the
  composition rules need, such as pressable) and a HEEx function
  component that draws its wireframe from the props its interface
  declares. One registry module lists them. The checker, the props
  panel, `speccy explain` and the JSON Schemas read the interface; the
  canvas and `speccy render` draw with the components.
- **Check** (`Speccy.Check`): runs the JSON Schemas on every file
  (`JSV`, draft 2020-12), then the rules no schema expresses
  ([format](format.md#the-checkers-rules)), and returns a list of
  problems: a stable code, the file, the path inside it and a message.
  It reads the whole spec each time; specs are dozens of small files.
- **Edit** (`Speccy.Edit`): every change the editor makes is one
  operation (insert an instance, move it, resize it, set a prop or a
  layout field, add, order or describe a state, copy an instance into a
  state, type text in a frame, reset an override, and the rest), applied
  as a function from the spec to the files it changes. An operation can
  change several files at once: promoting a prop writes the component
  and the screen that sets it, and undoes as one.
- **Schemas** (`Speccy.Schemas`): builds the JSON Schema of each kind of
  file from the format's definition and the primitives' interfaces. A
  mix task writes them into the repository under `priv/schemas/<format>/`,
  and a test fails when what's written differs from what the code builds,
  so the files can't drift from the modules. Spec files name them by
  their public URL in the repository, which is public
  (`schemas-public-url`); a format that breaks gets a new folder, so
  specs on the old one keep validating against it.

## Styles

The app and the specs it draws look different on purpose, so a button
in a frame is never mistaken for one of the editor's
(`wireframes-apart-from-app`):

- **The app's own interface** (item list, panels, problems, frame
  titles, dialogs) is built the Phoenix way: Phoenix's core components
  with Tailwind and daisyUI, its styles and components in one place,
  `core_components.ex` and `app.css`.
- **The primitives draw wireframes**, in a look of their own, from
  `wireframe.css` beside their modules: plain CSS, every rule under
  `.wf`, each frame's root. It starts by resetting everything inside a
  frame to the browser's defaults, so Tailwind's base styles never reach
  a frame. It is compiled into the app; the editor's page loads it and
  `speccy render` inlines it, so a frame draws the same in both.
- **Frames are inert.** A frame is marked `inert`, so nothing drawn in it
  acts; the canvas hook handles every pointer on it.
- **Editor marks stay out of frames.** Selection outlines and drag
  previews are the app's, drawn in a layer above the frames, never
  inside one, so a rendered frame never shows them.

## The editor

One LiveView page in elixir-desktop's window (WKWebView on macOS):

- **Item list**: the spec's screens, components and data models; picking
  one shows it on the canvas (`canvas-one-item`).
- **Canvas**: the item's base and one frame per state, side by side, each
  at its device's size for a screen. A frame is the resolved tree drawn
  with the primitives' components inside a world that the hook pans and
  zooms with a CSS transform. A frame's title switches which variation
  it shows. Frames outside the view aren't drawn.
- **Props panel**: the selected instance's props, bindings, state,
  variation, size and layout, each value with where it comes from and a
  reset, and "reset all" (`overrides-promote-props`).
- **Problems**: the check's list for the whole spec; picking one selects
  what it's about. Error boxes on the canvas show the same problems.

The split between server and page is the one the LiveView spike proved
(`prototypes/liveview-canvas`, under 20 ms a commit): the hook owns every
gesture until it ends, then pushes one event (`move`, `resize`, `insert`,
`edit-text`…) naming the frame and the instance chain from the node's
`data-` attributes. The LiveView turns it into an edit operation for the
workspace; the workspace's broadcast brings the new spec back, the
LiveView re-resolves the frames on show, and LiveView sends only the
diff. Selection and the shown item, state and variation are LiveView
assigns; pan and zoom stay in the page.

```flow
canvas -> editor : drop · move banner before list in the problem frame
editor -> workspace : edit operation
workspace -> core : apply the edit · check
workspace -> files : write the changed file, if the disk still matches
workspace -> editor : spec changed · problems
editor -> canvas : the frames' diff
```

The same app also runs as a plain local web server in development, so
tests and agents drive the editor in a browser (Playwright, WebKit).

## The workspace

One GenServer per open spec, under a supervisor, holding the files'
decoded JSON, the content each was last read or written with, the check's
problems and the undo stack. Editors subscribe to it over Phoenix PubSub.

- **Edits**: apply the operation with `Speccy.Edit`, write each changed
  file whose disk content still matches, push one undo entry (each file's
  content before and after), re-check, broadcast.
- **Watching**: the folder is watched (`file_system`, FSEvents on macOS);
  a changed file is read again, and if it differs from what the app last
  wrote, the workspace reloads it, clears undo entries that touch it,
  re-checks and broadcasts (`two-writers-like-files`).
- **Conflicts**: an edit lives in the page until the gesture or the
  typing ends, so the only unsaved edits are ones in progress. When a
  write finds the disk changed since it was read, the edit is held and
  the editor asks: overwrite the file with the edit, or take the file and
  drop the edit.
- **Undo and redo**: each entry writes the files back to their content
  before the edit, through the same check that the disk still matches.
- **Opening**: the app keeps recent specs in `~/.speccy/`; opening one
  starts its workspace.

## The command line

The `speccy` command is a shell launcher in the bundle,
`Contents/MacOS/speccy`, that runs the same release with `eval`
(`RELEASE_DISTRIBUTION=none`): it loads the code without starting the
application, so no window, endpoint or workspace starts; it runs one
command on the pure core, prints and exits. The prototype answered in
0.15 s, beside a running app too (`prototypes/cli-bundle`).

- **`check [<spec>]`**: the problems, one per line with code, file, path
  and message, or as JSON with `--json`; exits non-zero on any error.
- **`render <item> [--state s] [--variation v] [--out f]`**: the frame
  as one self-contained HTML file (the wireframe stylesheet and every
  icon inlined), or a PNG when `--out` ends in `.png`, taken with the
  machine's Chrome in headless mode; with no Chrome, it says so and
  writes the HTML.
- **`explain [<topic>]`**: the format and each primitive, as Markdown,
  generated from the schemas and the primitives' interfaces.
- **`icons <query> [--set] [--style] [--category]`**: the picker's
  search, printing references.
- **`open [<spec>]`**: opens the app on a spec, handled by the launcher
  without the release: it starts the host with the folder. A running
  app's host takes it over its single-instance socket and the app gets
  `{:open_file, [path]}` from `Desktop.Env`; a closed app starts with it,
  passed on as `SPECCY_OPEN` by the release's `env.sh`, since the
  release's `start` drops extra arguments.

The app installs the command for the user (a link on their PATH, as code
editors do), from the app's menu.

## Icons

- **Supported libraries** (Material first): each one's index (names,
  categories, tags and styles) is built by a mix task from the library at
  a pinned version and shipped in `priv/icons/`. SVGs are fetched from
  that pinned version the first time something draws them (`Req`) and
  kept in `~/.speccy/icons/<library>/<version>/` (`icon-libraries`). On
  the canvas, a missing SVG draws as a placeholder with its name and the
  frame redraws when it arrives; `speccy render` fetches before drawing,
  with a short timeout.
- **Spec sets**: read from `assets/icons/<set>/` with the rest of the
  spec, and watched the same way, so an agent's new icon shows in the
  picker at once. The checker refuses unsafe SVGs before anything inlines
  them.
- An icon draws as inline SVG, so `currentColor` takes the wireframe's
  colour.

## Packaging

A macOS app in elixir-desktop's host-first layout, built by
`desktop_deployment`: a native WKWebView host (`desktop_webview`) in
`Contents/MacOS/`, which starts the Erlang release in
`Contents/Resources/beam/`, and the `speccy` launcher beside the host.
The host runs single-instance. `desktop`, `desktop_webview` and
`desktop_deployment` come from GitHub, and the host is built from source
with Swift until it is published; the build's own steps are in the
prototype's README. macOS only for the MVP: its only user is
Alberto. `~/.speccy/` holds what belongs to the user and not to any
project: the icon cache and recent specs.

## Prototype first

1. **The canvas in elixir-desktop's own window.** Run the spike's canvas
   hook inside elixir-desktop's WKWebView host instead of Playwright's: pan,
   zoom, drag and typing in place, and the native menu and folder
   picker. If the view drops input or lags, the design keeps the same
   split but the hook works around the view.

## The architect's calls

Settled here without a decision of Alberto's, to check first: the files'
JSON as the only model, with key order kept; one pure core shared by the
editor and the CLI; edits addressed by instance-id chains; resolved nodes
carrying their sources; drawing broken specs with error boxes, and
keeping a bad file's last good version; checking the disk before every
write; one workspace process per open spec; undo as file contents
before and after, cleared for a file changed outside; the check running
on the whole spec each time; schemas generated from code and kept in the
repository, guarded by a test; the wireframe stylesheet as plain CSS
under `.wf`, reset to the browser's defaults and inlined by render;
frames drawn `inert`; editor marks in a layer above the frames; the CLI
as the same release in command
mode through `eval`, with `open` handed to the host; fetching Material SVGs from the library's pinned version; macOS
only for the MVP; and the libraries named (Jason, JSV, file_system,
Req).

## Open

Nothing at the moment.
