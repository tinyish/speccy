# MVP 2: the editor draws the spec

Status: approved <!-- draft, approved (by Alberto) or built (when it lands) -->

The editor opens a spec, draws each screen and component on the canvas,
its base and each state side by side, and redraws when the files change.

## What it delivers

Milestone 2 of [the MVP](../../prd/mvp.md): done when an agent's edit to
a screen appears on the canvas without a reload. It also delivers
`speccy render` as a page, and the desktop window, last. Bead: spec-eai.

Where this design departs from `core.md`, which is frozen until the MVP
is built:

- **The check depends on Resolve.** The composition rules run on
  Resolve's trees, not on a walk of their own
  (`decisions.md#composition-on-drawn-frames`). `core.md` has the check
  and Resolve side by side.
- **A new module, `Speccy.Spec`,** holds the one reading of a spec that
  Check and Resolve share. `core.md` doesn't name it.
- **`Speccy.Spec` is held between calls,** by the workspace, rebuilt on
  every load. `conventions.md#files-are-the-model` forbids a cache of
  derived data outside a function call; part 000 amends it to allow
  this one reading.
- **Resolve reads only files that pass their schema.** A file that
  fails it is treated as a file that isn't valid JSON: the canvas keeps
  its last good version, flagged. `core.md` says this only of invalid
  JSON, and asks Resolve to survive anything a spec holds.
- **Watching reads the whole spec again** after a short quiet moment.
  `core.md` has it read the one changed file.
- **Nodes carry where they are written, not where each value came
  from.** The props panel needs per-value origins in milestone 3;
  `core.md` has every node carry them.
- **Every frame of the item on show is drawn.** `core.md` skips frames
  outside the view.
- **`speccy render` writes HTML only.** `core.md` also has it write a
  PNG.
- **The format changes:** an absolute instance is placed by offsets
  from its container's edges, not by `x`, `y` and `constraints`, which
  can't be drawn without stored sizes (part 002).
- **Inlined icons keep their ids.** `core.md` gives each inlined copy
  ids of its own.
- **The workspace writes nothing.** Edits, undo and conflicts are
  milestone 3.
- **The endpoint keeps other pages out.** LiveView checks origin in every
  environment, and with the window on, `Desktop.Auth` asks for the
  per-launch key the window's URL carries (part 007). `core.md` doesn't
  say how the local server is guarded.

## Design

Five hard parts, and the approach to each.

**1. One reading of a spec.** The check builds a private picture of the
spec on every run, and what a state's copy means lives inside it.
Resolve needs the same picture, so it moves to `Speccy.Spec`, built once
per load. The check keeps its rules and loses its helpers. Part 000.

**2. Resolve, and the composition rules on its trees.** Resolve turns
one frame into a tree of nodes, each instance in the one state it is in,
with the screen's sample data. The composition rules run on those trees,
one per frame the canvas can show, and the check's own walk is deleted.
So the check and the canvas can't disagree, a problem is reported at the
place its node was written, and the cost is the size of what is drawn.
What this gives up is in the decision. Part 001.

**3. Drawing.** Each primitive's module gets its drawing beside its
interface, styled only by `wireframe.css`. Layout fields and sizes
become CSS on each node; the browser does the geometry. A gallery page
draws every primitive's examples, for Alberto to judge by eye. Part 002.

**4. Watching without getting it wrong.** An agent leaves a file
half-written between two writes, and editors save through a temp file
and a rename. So on any change in the folder the workspace waits for a
short quiet moment, reads the whole spec again and, if anything differs,
checks and broadcasts. A file that isn't valid JSON, or fails its
schema, keeps its last good version, flagged. Nothing is tracked file by
file: specs are dozens of small files.

**5. Icons that arrive late.** Drawing is pure and is handed the SVGs it
needs. The page gathers the icon references of the frames on show, reads
the cached ones, draws a named placeholder for the rest, fetches those
in the background and redraws as each arrives.

## Parts

Each part is built and reviewed on its own, in order. 000 to 002 and
007 have a file; the rest are specified here.

- [000-spec](000-spec.md): `Speccy.Spec`, and the check moved onto it.
  No behaviour changes.
- [001-resolve](001-resolve.md): Resolve, the composition rules on its
  trees, the old walk deleted.
- [002-drawing](002-drawing.md): a format change to how an absolute
  instance is placed, then Layout, the 25 primitives' drawings,
  `wireframe.css` and the gallery.

### 003 Icons

`Speccy.Icons` gains what drawing needs. Reading the cache and fetching
into it are the two functions with IO, together the icon fetch that
`conventions.md#pure-core` allows; they live in a module of their own,
`Speccy.Icons.Cache`, and the rest stays pure.

- `refs(tree)`: every icon reference a resolved tree draws.
- `svg(ref, spec, cache_dir)`: the SVG for a reference, or `:missing`:
  a spec set's file from the loaded spec (only one the check accepts,
  `Icons.safe/1`), a library's from
  `<cache_dir>/<library>/<version>/<name>[.<style>].svg`.
- `fetch(ref, cache_dir)`: fetches a library icon from the library's
  pinned version with `Req` and writes it to the cache; one fetch at a
  time per reference. The default cache is `~/.speccy/icons/`.
- An icon is inlined as its bytes, sized by CSS. Its ids are not
  rewritten: `core.md` asks for that, in case two icons on a page share
  an id, and it is left out until a real screen hits it.

`Req` joins `mix.exs` (`core.md` names it).

Tests: `refs` on a fixture's tree; `svg` for a spec icon, a cached
library icon and a missing one; `fetch` against `Req.Test`, writing to a
temp cache; an unsafe spec SVG is never returned.

Done when a frame with a spec icon, a cached library icon and an
uncached one draws the first two and a named placeholder for the third,
with no network.

### 004 `speccy render`

`speccy render <item> [--state <s>] [--variation <v>] [--out <file>]`
in `Speccy.CLI`: resolves the frame, draws it, and writes one
self-contained HTML file: `wireframe.css` and every icon inlined, the
frame at its device's size for a screen. Library icons not in the cache
are fetched first, with a short timeout; one that doesn't arrive draws
as its placeholder. With no `--out` it writes to a temp file and prints
the path. Exit 2 when the item, state or variation doesn't exist. No
PNG.

`speccy explain` and the usage text gain the command.

Tests, in process (`Speccy.CLI.run/1`) on fixtures: the file holds the
stylesheet and the frame's nodes; a state and a variation draw what they
change; an unknown item exits 2.

Done when an agent can run it on any screen of the `tasks` fixture and
open the page.

### 005 The workspace

`Speccy.Workspace`, a GenServer per open spec under a
`DynamicSupervisor`, named by its folder. `file_system` joins `mix.exs`
(`core.md` names it).

- State: the loaded spec as last read, each file's last good content
  (the last that was valid JSON and passed its schema), the
  `Speccy.Spec` built from the good contents, and the check's problems,
  which are run on what was read, so a broken file's problems show while
  its last good version draws.
- `open(dir)` starts or finds it; `get(dir)` returns the spec and the
  problems; it broadcasts `{:spec_changed, spec, problems}` on
  `Speccy.PubSub`, topic `"workspace:" <> dir`.
- Watching: on any event under the folder, (re)start a quiet timer of
  50 ms; when it fires, `Speccy.Format.load/1` the folder again and, if
  the contents differ from what is held, rebuild, re-check and
  broadcast.

Tests (`@tag :tmp_dir`, a fixture copied in, waiting on the PubSub
message, never a sleep): an outside edit to a file is broadcast; a file
written as invalid JSON keeps its last good version and reports
`invalid-json`; fixing it brings the new version; a new file and a
deleted file are both seen; a write of identical bytes broadcasts
nothing.

Done when those pass.

### 006 The editor page

One LiveView at `/`, replacing the generator's home page (delete it, its
controller and test, `DNSCluster`, and the generator's moduledoc in
`lib/speccy.ex`). The spec to open comes from `SPECCY_OPEN` or the
`?spec=` parameter; with neither, the page says how to open one.

- **Item list:** the spec's screens, components and data models, by
  kind, in name order; picking a screen or a component shows it. The
  shown item is in the URL, so a reload keeps it.
- **Canvas:** a frame for the item's base and one per state, in the
  file's order, side by side, each with its title (the state's name and
  `about`). A screen's frame has its device's size, in its orientation;
  a component's hugs its content, or takes the component's `width` and
  `height`. A frame with variations has a switcher on its title: as
  written, or one variation; the choice is a LiveView assign. Each
  frame's root is `.wf` and `inert`.
- **Problems:** the check's list for the whole spec, each with its code,
  file, path and message; a file drawn from its last good version is
  flagged on its frames. Error nodes draw as boxes with their code.
- **The hook:** pan (wheel, space-drag, middle-drag) and zoom
  (Cmd/Ctrl-wheel) with a CSS transform on the world, kept in the page.
  No selection and no other gesture.
- The page subscribes to the workspace and re-resolves the frames on
  show when it broadcasts.
- Every drawn node has `data-file` and `data-chain` (its ids, joined by
  `/`), for milestone 3's gestures and for the e2e box comparison.

Tests: `Phoenix.LiveViewTest` on a workspace over a temp copy (the list,
the frames and their order, the switcher, the problems, a broken file's
flag). End to end, Playwright WebKit under `e2e/` (`testing.md`): an
edit to a screen's file from outside shows on the canvas without a
reload, which is the milestone's "done when"; pan and zoom; a frame on
the canvas and the same frame from `speccy render` place every node in
the same box.

Done when Alberto opens the `tasks` fixture, sees every screen and
component with its states, and an edit he makes to a file in his editor
shows without a reload.

### 007 The desktop window

Starts only after the prototype spec-6u4 has run, and takes its findings.
The app in elixir-desktop's host-first layout, as `core.md` § Packaging
says: the window on the editor page, a menu with Open (a folder picker)
and recent specs kept in `~/.speccy/`, and `speccy open [<spec>]` handed
to the host. `Desktop.Auth` guards the page with the window's per-launch
key and LiveView checks origin, dev's `check_origin: false` included, so
no other page on the machine can reach the editor and its files. Its
program design is [007-window](007-window.md), approved before it is
built.

## Out of scope

- Selecting, inserting, moving, resizing, typing in place, the props
  panel, undo and saving: milestones 3 to 5.
- Where each value on a node came from (the base, a copy, a variation,
  a default).
- `speccy render` as a PNG, `speccy icons`, the icon picker.
- Skipping frames outside the view.
- Figma's `scale` for an absolute child: 002 writes it down as a gap.
