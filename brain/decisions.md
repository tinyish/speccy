# Decisions

What was decided about speccy, and why. Each decision has a key, its
heading, that items, docs and agents cite it by, such as
`decisions.md#<key>`. An entry is a short description: what was decided,
when, and why, in a few lines. It is not a long document; what it changes
lands in the PRD or the architecture doc, and the entry says where. An
entry amended later carries both dates and says only what holds now.

## principles

2026-11-09. speccy has three principles: agentic-first (agents can learn
the spec from its files, write it, check it and see it, with no person in
between), as flexible as code, and an open format (plain, documented text
in the project's repository, nothing proprietary). As flexible as code
means every construct has one obvious counterpart in code and back, so
agents translate between them one to one: a change a developer makes in
one line is one change in speccy. Why: Alberto's guideline when settling
overrides, and the tests the format and editor have been decided by. In:
`prd/seed.md`, `architecture/format.md`.

## behavior-not-ui

2026-11-06, amended 2026-11-07. speccy specs behavior and its link to
code, not visual design: tokens, styling, visual variants and motion stay
in Figma. Layout is the exception, because what sits where, and how big,
shapes behavior (`figma-auto-layout`). Why: visual design is Figma's
ground; behavior and closeness to code are where Figma falls short. In:
`architecture/format.md`.

## logic-in-about

2026-11-09. speccy doesn't express logic: computed values, sorting,
validation and the like are described in the `about` of the entity they
belong to, and the project's code is their source of truth. Every entity
can carry an `about`, props, data fields and instances included; on the
canvas a computed value is an example literal. Why: a copy of code's
logic in the spec would be a second, weaker copy that drifts. Props and
fields taking either a type or `{ type, about }` are the architect's
call. In: `architecture/format.md`.

## mvp-scope

2026-11-08, amended 2026-11-09. The MVP is a desktop editor for Alberto
and coding agents only. It covers components, screens, their layout,
their states and variations, and data shapes: data models, screens saying
what they show with sample values, binding and repeating. Where data
comes from (operations), interactions and flows come after it, in that
order. Only the primitives ship; composed components are built in the
editor. It is ready when speccy's own editor is specced in speccy. Why:
the MVP is a test bench for how components and screens are defined;
without data shapes, tables, trees and lists couldn't be specced, while
data sources only matter once something calls them. In: `prd/mvp.md`.

## no-code-mappings-in-mvp

2026-11-06. The MVP has no links from spec objects to code; how fine
they are is decided after it. Why: links would have to follow every
change to how components and screens are defined while that is still
moving. In: `prd/mvp.md`.

## no-one-offs

2026-11-06. Everything on a screen is an instance of a component; there
are no one-off elements, as Figma allows. Why: behavior is specced once,
on the component, and every piece of a screen has a definition an agent
and the code can point to. In: `architecture/format.md`.

## components-own-behavior

2026-11-06. A composed component defines its own states (and, later,
interactions and rules), and every screen that uses it gets them;
screens add only their own. Why: behavior is specced once and reused,
like the component. In: `architecture/format.md`.

## copy-inline-data-bound

2026-11-06. Copy is written on instances; data is an object of its own
that instances bind to. Why: copy reads best in context, while data is
behavior agents guess at, so the spec says once what a screen shows. In:
`architecture/format.md`.

## samples-on-screens

2026-11-09. Sample data lives on the screen that shows it, beside what it
declares it shows, and its states replace it from there. Data models
hold only their fields. A component opened on its own shows placeholders
for its data props, such as `{task.title}`. Why: each screen chooses
examples that fit it, in one place. In: `architecture/format.md`.

## json-schema-format

2026-11-09. The format is defined by JSON Schema files, one per kind of
file, that every file names with `$schema`; the checker runs them, then
the rules a schema can't express (references, prop types per primitive,
composition rules), and reports errors with stable codes. `speccy
explain` is generated from them. Why: agents and editors validate as they
type, and the docs can't drift from the format. In:
`architecture/format.md`.

## named-slots

2026-11-09. A component can mark inner containers as named slots
(`"slot": "content"`), and an instance fills them by name with its own
instances. Why: cards, dialogs and tab panels are one shell with
different insides; without slots the library needs a component per use.
In: `architecture/format.md`.

## figma-auto-layout

2026-11-07, amended 2026-11-09. Components and screens carry Figma's
auto layout: flow (row, column, stack, grid), wrap on rows and columns,
alignment, gaps that are numbers (negative allowed) or spread (between,
around, evenly), a gap between wrapped lines or grid rows, padding,
clipping, grids with tracks of pixels, fill or hug and children placed
and spanned, children that ignore auto layout (placed by position and
constraints), and width and height as fill, hug or fixed with minimums
and maximums. Canvas stacking, text baseline alignment and strokes in
layout stay out as visual. Why: designers expect Figma's controls, and
these change where things sit. Field names are the architect's calls.
In: `architecture/format.md`.

## device-presets-and-custom

2026-11-09. A screen's `device` names one of speccy's presets (about
fourteen at launch: generic desktop, laptop, tablet, mobile, watch, round
watch and tv, plus the current flagship of each major line, refreshed
with speccy's releases and sized from vendor specs) or a device
the spec defines once in `speccy.json`. A device has a size and may say
its shape (rect, with an optional corner radius, or round), how it is
operated (touch, pointer, keyboard, rotary, d-pad, gamepad, voice), its
safe area and its orientations; a screen may pick an orientation. The
MVP editor uses only the size. Why: watches and integrated devices need
their own sizes, and how a device is operated shapes focus and input
behavior. In: `architecture/format.md`, `prd/mvp.md`.

## states-described-not-conditioned

2026-11-06. A state has a name and a one-line `about` saying when it
applies; there is no condition language, and interactions (later) enter
and exit states. Edge cases (offline, timeouts, long text, thousands of
items) are states like any other, so each says what the UI does about
it. Why: a formal condition adds little an agent can't read from a
sentence, and it forced modelling everything a state depends on. In:
`architecture/format.md`.

## states-are-compositions

2026-11-09. A state is a composition of its own beside its file's base:
linked copies of the base instances it chooses, instances only it has,
and its own sample data. A linked copy shows whatever its base instance
shows, after every change, except what is set on the copy: its props,
its state and variation, and its place (order, size, grid placement,
absolute position); a copied container's children are changed through
`inner`. Replaced states as patches on the base (`set`, `hidden`, states
stacking in order). Why: a state should hold components the base lacks
without hiding them in the base, and read as the frame it is. `inner` is
the architect's call. In: `architecture/format.md`, `prd/mvp.md`.

## state-membership-explicit

2026-11-09. An instance added to the base appears in no state until the
user copies it there; the editor may offer shortcuts to copy base changes
into states, always as an action the user takes. Why: designers' main
frustration with Figma is that a change to a base component immediately
ripples into, and breaks, every instance. In: `architecture/format.md`,
`prd/mvp.md`.

## one-state-per-instance

2026-11-09. An instance is in one state of its component at a time
(`state`, with an optional `variation`), and both can be bound to data
like any prop, so each row of a repeat takes its state from its own data.
A combination that matters, such as an error while focused, is a state
of its own. Why: two compositions can't be laid over each other, and in
code a component's state is usually a prop fed by data. The checker
requiring an enum field of state names, with empty meaning the base, is
the architect's call. In: `architecture/format.md`.

## variations

2026-11-09. A variation is a named content change, text and icons only,
within a state or the base, each with its own `about`; offline and error
are one state with two variations. A state's variation can change any
instance in its state, linked copies included; a component can also
define variations, for small fixed sets of wording any screen picks.
Variations are not frames: a frame shows its state as written or one
variation, switched on the frame, and typing in a frame writes into the
variation shown, made on the spot if none is. The props panel says where
each text or icon value comes from and resets or switches it. Why:
small content changes shouldn't need a state, a frame, or a component
change; in Figma the same coverage bloats the canvas or is left out. The
switcher on the frame's title, creating a variation when none is shown,
and a state's variation winning over a component's are the architect's
calls. In: `architecture/format.md`, `prd/mvp.md`.

## overrides-promote-props

2026-11-09. Every override has the shape code would give it. Any
instance can set any prop its component declares. Changing a part inside
a component from outside adds a prop to the component with today's value
as its default, binds the part to it and sets it on that instance, at
every level of nesting, as a developer would. Every instance lists what
is set on it, each resettable, and "reset all". Why: code can only change
a component's insides through props, and Figma-style deep overrides
have no code counterpart (`principles`). Considered, in the override
stress test: declared props only, deep overrides, exposed parts. The
editor proposing promoted props' names is the architect's call. In:
`architecture/format.md`, `prd/mvp.md`.

## primitives

2026-11-06, amended 2026-11-09. speccy ships 25 primitives, merged from
the Material 3 and Untitled UI kits, each mapping to an HTML element or
role: a primitive must have behavior unique enough to be its own thing.
Variants fold into one primitive as options (switch into checkbox, sheet
into dialog, tooltip into popover, tag and badge into button); anything
composable (tabs, navigation, alert, card…) is left to composition, and
patterns with app content (page headers, empty states, feeds) are left
out. Reading components out of a codebase is a later feature. Why: a
small set with real, known behavior keeps the spec close to code and
leaves the rest to composition. In: `prototypes/catalog`,
`architecture/format.md`.

## primitives-bind-models

2026-11-07. A primitive with a structured value (table rows, tree items)
takes a data model chosen by the instance that binds it, written `model`
or `model[]`, instead of a new built-in type. Why: it reuses data models
rather than starting a second type system. In: `architecture/format.md`.

## primitives-in-code

2026-11-09. Primitives are defined in code, not JSON files: one Elixir
module each, holding its interface as data (about, element, props and
types, events, states, defaults, examples) and a HEEx function component
that draws it. The checker, `speccy explain`, the props panel and the
JSON Schemas read the interface from the modules; the canvas and `speccy
render` draw with the same components. The JSON catalog and its render
template language (`prototypes/catalog`) stay as the research record and
are not ported. Why: primitives are built in, HEEx does what the
template language was invented for, and one renderer can't drift from
itself. In: `architecture/format.md`.

## icon-primitive

2026-11-09. `icon` is a primitive: one glyph, decorative unless labelled,
not pressable. An `icon` prop type (`<set>/<name>`, with an optional
`:<style>`) carries icon names, button's included; the style is part of
the reference, so a state can fill a selected tab's icon. Why: banners,
list rows and status need an icon that isn't a button. In: `prd/mvp.md`,
`architecture/format.md`.

## icon-libraries

2026-11-09. Every icon is an SVG, from a library speccy supports
(Material first) or from the spec's own sets in `assets/icons/<set>/`,
where agents draw new ones. speccy ships each supported library's index;
its SVGs are fetched the first time an icon is drawn and cached per user
in `~/.speccy/`, never in the project. The picker searches as you type,
previews each icon, switches library and filters by style and category;
`speccy icons` runs the same search for agents. No icon fonts: a font
can't hold agents' SVGs, and fonts name glyphs differently per library;
SF Symbols' license allows only mock-ups of Apple-platform software, so
teams bring exported SVGs. Why: most icons go unused, library files
don't belong in a project's history, and agents should reuse before they
draw. Shipping the index and pinning each library's version are the
architect's calls. In: `prd/mvp.md`, `architecture/format.md`.

## elixir-desktop-app

2026-11-09. speccy is a desktop app in Elixir and Phoenix LiveView,
packaged with elixir-desktop, like clay. LiveView owns the spec, its
files and the checker; the canvas's pan, zoom, drag previews and
in-place editing run in the page as JS hooks, and only committed edits
reach the server. The React prototypes are rewritten. Why: it keeps the
way open for speccy to become a Clay-capable app, and the LiveView canvas
spike (`prototypes/liveview-canvas`) committed edits in under 20 ms in
Chromium and WebKit. In: `architecture/core.md` when it is written.

## canvas-renders-dom

2026-11-09. The canvas renders primitives as real HTML elements, laid
out by the browser's flex and grid, inside one transformed world for pan
and zoom; no canvas or WebGL engine. Borrowed from penpot: draw only
frames in view, keep drags out of saved state, never store computed
geometry. Why: penpot left the DOM for a Rust and Skia engine to draw
large, effect-heavy vector files, which took it about two years; speccy
draws wireframes of HTML primitives, few per view, and real HTML keeps
the canvas close to code. In: `architecture/core.md` when it is written.

## canvas-one-item

2026-11-09. The canvas shows one screen or component at a time, a frame
for its base and one per state; there is no board of all screens and no
overview until flows, which span many screens. Instances are arranged
on the canvas and copy is edited in place on it; props and layout are in
the side panel. Why: states are what the MVP proves, and few frames per
view keep the canvas simple. In: `prd/mvp.md`.

## agent-cli

2026-11-08, amended 2026-11-09. Agents read and write the spec's files
directly, like code, and the editor shows their changes live; there is
no agent interface in the MVP. The app installs a `speccy` command that
runs without the app open: `check` (errors with stable codes), `render`
(a frame in any state as a self-contained HTML file, and a PNG through
headless Chrome when the machine has it), `explain` (the format and each
primitive, generated from the code), `icons` (icon search) and `open`.
It has no edit commands. Why: a fresh agent learned the format from its
files alone; penpot's agents work best when they can look at their
result and read docs generated from the real types; and edit commands
would be a second way to write a format that is still changing. In:
`prd/mvp.md`.

## two-writers-like-files

2026-11-09. When an agent changes a file the editor has open, the editor
behaves like any code editor: with no unsaved edits it reloads the file;
with unsaved edits it asks before saving, overwrite or take the file.
Nothing merges. Why: the spec is files in a project, and people already
know how editors handle files changed on disk; a merge engine (penpot's
rebase, or Ink & Switch's Automerge) would be a feature to build for a
case autosave makes rare. Considered and dropped: merging change records
with Automerge later. In: `architecture/format.md`, `prd/mvp.md`.
