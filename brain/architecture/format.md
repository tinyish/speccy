# The spec format

What a speccy spec is on disk: the files, every object in them, and the
rules the checker enforces. It covers what the MVP holds (components,
screens, layout, states and variations, data shapes); what comes later is
listed at the end. Why each part is the way it is lives in
`decisions.md`, cited by key.

## How it is defined

JSON Schema files, one per kind of file, ship with speccy, and every file
names its own with `$schema`, so editors and agents get validation as
they type. The checker (`speccy check`, and the app on every change) runs
the schemas first, then the rules no schema can express: references
across files, prop values against what each primitive and component
takes, and the composition rules. Each error carries a stable code, the
file, the path inside it and a message. `speccy explain` prints this
document's sections, with references generated from the code: each
primitive's interface, the devices, the codes and the icon libraries.
(`json-schema-format`)

`$schema` is a public URL into speccy's repository, by format version and
kind of file (`schemas-public-url`):
`https://raw.githubusercontent.com/tinyish/speccy/main/priv/schemas/<format>/<kind>.schema.json`, where `<kind>` is `manifest`, `component`, `screen` or
`data`. The examples below shorten it to `…/<kind>.schema.json`.

## What stays in code

speccy holds what a product does and how it is put together, not its
logic. Computed values (a size formatted as "2.4 MB", an icon chosen by
file type), sorting, validation rules and the like are not expressed in
the format: the entity they belong to describes them in its `about`, and
the project's code is the source of truth for them. On the canvas, such
a value is an example written as a literal (`"2.4 MB"`), and its `about`
says how the real one is worked out (`logic-in-about`). Every entity can
carry an `about`: components, screens, data models and their fields,
props, instances, states, variations and devices.

## The spec folder

A spec is a folder in the project's repository:

```
<spec>/
  speccy.json          the manifest
  components/<Name>.json
  screens/<Name>.json
  data/<Name>.json
  assets/icons/<set>/<name>.svg
```

- **`speccy.json`**: `{ "$schema": …, "format": 1 }`. It marks the folder
  as a spec (`speccy open` looks for it) and says which version of the
  format the files follow. The format may break during the MVP; `format`
  is how the app notices a spec it can't read. It also holds the spec's
  own `devices` (see Devices).
- **One file per item**, named after it: the checker reports a file whose
  name doesn't match its item.
- **`assets/`** holds files a spec uses that aren't items: for now icons,
  one folder per icon set (see Icons); images and fonts can join later.
- **Primitives are not in the spec.** They are built into speccy as code,
  one Elixir module each: its interface as data (about, element, props
  and their types, events, states, defaults, examples) and a HEEx function
  component that draws its wireframe. The checker, `speccy explain` and the
  props panel read the interface from the modules, and
  the canvas and `speccy render` draw with the same components
  (`primitives-in-code`). A primitive's defaults are what an unset prop
  means (a toast with no `action` has none); sample content for
  drawing it lives in its examples.

## Names

- Components, screens and data models: PascalCase (`TaskRow`), unique
  across all three, and never a primitive's name (primitives are
  lowercase).
- Instance ids, props, data names, fields, states, variations and slots:
  camelCase starting with a letter (`header`, `leadingIcon`, `tasks`).
  No `.` or `/`, which paths use.
- Instance ids are unique across their file: the base, every state and
  every slot. A linked copy keeps its base instance's id.
- Icon sets and icons: lowercase, digits, `-` and `_` (`app`,
  `sync-done`, `wifi_off`), from their folder and file names. A spec's
  set can't take the name of a library speccy supports (`material`).
- Devices: lowercase, digits and `-` (`apple-tv-4k`), like presets.

## Types

What a prop or a field holds:

| Type         | Holds                                                           |
| ------------ | --------------------------------------------------------------- |
| `text`       | A string: copy.                                                 |
| `bool`       | true or false.                                                  |
| `number`     | A number.                                                       |
| `icon`       | An icon: `<set>/<name>`, or `<set>/<name>:<style>` (see Icons). Unset: no icon; there is no empty reference. |
| `text[]`     | A list of strings.                                              |
| `["a", "b"]` | One of these strings.                                           |
| `<Model>`    | One item of a data model (`Task`).                              |
| `<Model>[]`  | A list of them (`Task[]`).                                      |

Primitive props typed `model` or `model[]` take any data model, chosen by
what the instance binds to them (`primitives-bind-models`).

## Devices

A screen is for a device: one of speccy's presets, or one the spec
defines in `speccy.json` under `devices` (`device-presets-and-custom`):

```json
{
  "$schema": "…/manifest.schema.json",
  "format": 1,
  "devices": {
    "watch": {
      "about": "The wrist unit: a round touch display with a crown.",
      "width": 240,
      "height": 240,
      "shape": "round",
      "input": ["touch", "rotary"],
      "safeArea": [12, 12, 12, 12],
      "orientations": ["portrait"]
    }
  }
}
```

| Key               |                                                                                                                                                                         |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `about`           | A line on what it is. Required.                                                                                                                                         |
| `width`, `height` | Its screen in CSS pixels (points, dp), in its first orientation. Required.                                                                                                               |
| `shape`           | `rect` or `round`. Unset: `rect`.                                                                                                                                       |
| `cornerRadius`    | With `rect`: its corners' radius in pixels, one for all or `[top-left, top-right, bottom-right, bottom-left]`, in its first orientation. Unset: 0.                      |
| `input`           | How people operate it, any of `touch`, `pointer`, `keyboard`, `rotary` (a crown or dial), `dpad` (a remote or arrow keys), `gamepad` (a game controller), `voice`.      |
| `safeArea`        | Insets the system covers (a notch, a home indicator, a bezel): pixels, `[vertical, horizontal]` or `[top, right, bottom, left]`, in its first orientation. Unset: none. |
| `orientations`    | Which it supports, first being its own: `portrait`, `landscape`. Turning swaps width and height and rotates the safe area. Unset: only the one its size implies.        |

Presets have the same fields and ship with speccy, ten at launch, each a
real device named after its model (`device-presets-and-custom`): an
iPhone and a large iPhone, a Pixel, a Galaxy, an iPad, a MacBook, Apple's
Studio Display, an Apple Watch, a round Wear OS watch, and Apple TV 4K,
a 1920×1080 landscape screen operated by `dpad`, `gamepad` and `voice`,
inside tvOS's safe area for overscan. There are no generic sizes.

Sizes, safe areas and corner radii come from the vendors' specs when the
code is written, and the presets are refreshed with speccy's releases.
A spec's device can't take a preset's name. The MVP's editor uses only a
device's size; `shape`, `cornerRadius`, `input`, `safeArea` and
`orientations` are checked and kept, and drawn once the editor supports
them.

## Data model (`data/<Name>.json`)

```json
{
  "$schema": "…/data.schema.json",
  "data": "Task",
  "about": "Something the user has to do.",
  "fields": { "title": "text", "done": "bool" }
}
```

| Key      |                                                                                                                    |
| -------- | ------------------------------------------------------------------------------------------------------------------ |
| `data`   | Its name. Required.                                                                                                |
| `about`  | A line on what it is. Required.                                                                                    |
| `fields` | Field name → type, or → `{ "type": …, "about": … }` to describe it. A field can be another model or a list of one. |

Only the shape: where data comes from and the operations on it come with
interactions (`mvp-scope`). Sample values are on screens
(`samples-on-screens`).

## Component (`components/<Name>.json`)

```json
{
  "$schema": "…/component.schema.json",
  "component": "Banner",
  "about": "A notice across the screen about something that affects all of it.",
  "props": { "message": "text" },
  "layout": "row",
  "children": [
    {
      "id": "message",
      "use": "text",
      "width": "fill",
      "bind": { "text": "message" }
    }
  ]
}
```

| Key               |                                                                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `component`       | Its name. Required.                                                                                                                      |
| `about`           | A line on what it does. Required.                                                                                                        |
| `props`           | Prop name → type, or → `{ "type": …, "about": …, "default": … }`: what an instance gives it, and what it gets when the instance doesn't. |
| `width`, `height` | The root's own size, when every instance should share it.                                                                                |
| layout fields     | How the root arranges `children` (see Layout).                                                                                           |
| `children`        | Its instances.                                                                                                                           |
| `variations`      | The base's variations (see States and variations).                                                                                       |
| `states`          | Its states (see States).                                                                                                                 |

A component has no data of its own: data reaches it through its props
(`TaskRow` takes `task: Task`). Opened on its own, it shows placeholders
for data props, such as `{task.title}`.

## Screen (`screens/<Name>.json`)

```json
{
  "$schema": "…/screen.schema.json",
  "screen": "TaskScreen",
  "about": "The user's tasks: add, complete and delete them.",
  "device": "iphone-18-pro",
  "data": {
    "tasks": {
      "type": "Task[]",
      "sample": [
        { "title": "Buy milk", "done": false },
        { "title": "Call Sam", "done": true }
      ]
    }
  },
  "layout": "column",
  "children": ["…instances…"],
  "states": { "…": "…" }
}
```

| Key           |                                                                                                                     |
| ------------- | ------------------------------------------------------------------------------------------------------------------- |
| `screen`      | Its name. Required.                                                                                                 |
| `about`       | A line on what it is for. Required.                                                                                 |
| `device`      | A preset or one of the spec's devices (see Devices), which sets its size. Required.                                 |
| `orientation` | `portrait` or `landscape`, one its device has. Unset: the device's first.                                           |
| `data`        | Name → `{ type, sample }`: what the screen shows, and the sample values the canvas draws. `sample` must fit `type`. |
| layout fields | How the screen arranges `children`.                                                                                 |
| `children`    | Its instances.                                                                                                      |
| `variations`  | The base's variations.                                                                                              |
| `states`      | Its states.                                                                                                         |

## Instance

An entry in `children` (the base's or a state's) or in a slot: one use of
a primitive or a component. In a state, an entry can instead be a linked
copy of a base instance (see States).

```json
{
  "id": "list",
  "use": "TaskList",
  "width": "fill",
  "height": "fill",
  "bind": { "tasks": "tasks" }
}
```

| Key                                              |                                                                                                                                                                                                                                                |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                                             | Unique in the file. Required.                                                                                                                                                                                                                  |
| `about`                                          | What this use of it is for, or behavior the format doesn't express (how a value is computed).                                                                                                                                                  |
| `use`                                            | A primitive or a component. Required.                                                                                                                                                                                                          |
| `props`                                          | Prop → literal value. Copy goes here.                                                                                                                                                                                                          |
| `bind`                                           | Prop → path. In a component, a path starts at one of its props; in a screen, at one of its data; inside a `repeat`, also at its `as`. Paths go into fields with `.` (`task.title`). A prop is either literal or bound, not both.               |
| `repeat`                                         | `{ "each": <path to a list>, "as": <name>, "limit": <n>? }`: one copy per item, at most `limit`. `each` is read from outside the repeat, so it never starts at its own `as`; `as` may reuse a name already in scope, which it hides inside the repeat. |
| `state`                                          | The one state of its component or primitive it is in (see States). Unset: the base. Can be bound like a prop (`"bind": { "state": "u.status" }`), so each repeated row takes its state from its own data.                                      |
| `variation`                                      | A variation of that state, or of the component's base. Can be bound the same way.                                                                                                                                                              |
| `slots`                                          | Slot name → instances, for a component with slots (`named-slots`).                                                                                                                                                                             |
| `slot`                                           | Inside a component only, on a container, list or dialog with no children of its own: makes it the slot of that name.                                                                                                                           |
| `width`, `height`                                | `fill`, `hug` or a number of pixels. Unset: `hug`.                                                                                                                                                                                             |
| `minWidth`, `maxWidth`, `minHeight`, `maxHeight` | Pixels.                                                                                                                                                                                                                                        |
| `column`, `row`, `columnSpan`, `rowSpan`         | In a grid: the track it starts at (from 1) and how many it spans. Unset: the next free cell, spanning 1.                                                                                                                                       |
| `absolute`                                       | true: out of its container's flow (Figma's "ignore auto layout"), placed by `x`, `y` and `constraints`.                                                                                                                                        |
| `x`, `y`                                         | With `absolute`: pixels from its container's top-left.                                                                                                                                                                                         |
| `constraints`                                    | With `absolute`: `{ "horizontal": …, "vertical": … }`, how it follows its container's size. Horizontal: `left`, `right`, `center`, `left-right`, `scale`; vertical: `top`, `bottom`, `center`, `top-bottom`, `scale`. Unset: `left` and `top`. |
| layout fields                                    | Only on primitives that hold children (container, list, form, dialog, menu, popover).                                                                                                                                                          |
| `children`                                       | Only on primitives that hold children: its instances, arranged by its layout fields.                                                                                                                                                          |

## Layout

Figma's auto layout (`figma-auto-layout`), on a file's root and on any
instance that holds children:

| Key               | Takes                                                                                                                                       | Default when unset     |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `layout`          | `row`, `column`, `stack` (children layered), `grid`                                                                                         | `column`               |
| `wrap`            | true or false; rows (wrapping into new rows) and columns (into new columns)                                                                 | false                  |
| `columns`, `rows` | Grids only: a whole number of equal tracks, or a list of tracks, each pixels, `fill` (a share of what's left) or `hug` (its content)        | 1 row, grows as needed |
| `align`           | `top-left`, `top`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom`, `bottom-right`                                          | `top-left`             |
| `gap`             | Between items along the flow, or between a grid's columns: pixels (negative overlaps them), or `between`, `around`, `evenly` to spread them | 8                      |
| `lineGap`         | Between wrapped lines, or between a grid's rows: pixels                                                                                     | `gap`                  |
| `padding`         | Pixels, `[vertical, horizontal]` or `[top, right, bottom, left]`                                                                            | 8                      |
| `clip`            | true or false                                                                                                                               | false                  |

Not carried: Figma's canvas stacking (which overlapping child is on
top), baseline alignment of text and whether strokes count in layout,
which are visual (`figma-auto-layout`).

Computed positions and sizes are never stored: the canvas works them out
when it draws (`canvas-renders-dom`).

## States and variations

A state is a composition of its own, beside its file's base: what the
screen or component is in that situation. It holds linked copies of the
base's instances it chooses, and instances of its own
(`states-are-compositions`). A copy follows its base except for what is
set on it, and everything set on it is listed and can be reset
(`overrides-promote-props`).

```json
"children": [
  { "id": "header", "use": "Header", "width": "fill", "props": { "title": "Tasks" } },
  { "id": "list", "use": "TaskList", "width": "fill", "height": "fill", "bind": { "tasks": "tasks" } }
],
"states": {
  "empty": {
    "about": "The tasks have loaded and there are none.",
    "data": { "tasks": [] },
    "children": [
      { "copy": "header" },
      { "id": "empty", "use": "EmptyState", "width": "fill", "props": { "message": "No tasks yet. Add one above." } }
    ]
  },
  "problem": {
    "about": "Something stops the list from working.",
    "children": [
      { "copy": "header" },
      { "id": "banner", "use": "Banner", "width": "fill", "props": { "message": "Something went wrong." } },
      { "copy": "list", "state": "stale" }
    ],
    "variations": {
      "offline": {
        "about": "The device has no connection.",
        "content": { "banner.message": "You're offline. Changes will sync when you're back." }
      },
      "error": {
        "about": "The tasks failed to load.",
        "content": { "banner.message": "We couldn't load your tasks." }
      }
    }
  }
}
```

| Key          |                                                                                                            |
| ------------ | ---------------------------------------------------------------------------------------------------------- |
| `about`      | When it applies, in a line. Required. There is no condition language (`states-described-not-conditioned`). |
| `data`       | Screens only: data name → sample value in this state, replacing the screen's sample for that name.         |
| `children`   | The state's instances: linked copies and its own, arranged by the file's root layout.                      |
| `variations` | Name → `{ about, content }` (see below).                                                                   |

**Linked copies.** `{ "copy": "<base id>" }` puts a base instance in the
state. It shows whatever the base instance shows, now and after any
change to it: its props, bindings, slots and, for a container, all its
children. It may differ only in:

- `props`: any prop its component (or primitive) declares;
- `state` and `variation`: which of its component's (or primitive's)
  states and variations it is in;
- its place: where it sits among the state's instances (inside the
  state's own containers too), `width`, `height`, the min and max sizes,
  grid placement, and `absolute` with `x`, `y` and `constraints`;
- its text and icons, in one of its state's variations (below).

A copied container brings its children, linked. To change one of them,
the copy names it in `inner`, by id, with the same fields a copy can set:

```json
{
  "copy": "files",
  "inner": { "item": { "props": { "removeIcon": "material/lock" } } }
}
```

A copy is written `copy` first, then the fields it sets in the order
of the Instance table, then `inner`. A base instance is copied at most
once per state, and a copy keeps its base's id. Membership is explicit: an instance added to the base appears
in no state until it is copied there; the editor can offer to copy it
into states, as an action the user takes (`state-membership-explicit`).

**Changing a part inside a component** works the way it does in code:
through a prop. When someone changes a part of a component from outside
it (the Remove button's icon inside an UploadItem, on one screen), the
edit adds a prop to the component, `removeIcon: { "type": "icon",
"default": "material/close" }`, binds the part to it, and sets it on
that instance. The component's other uses keep the default, so nothing
else changes. Reaching through nested components adds a prop at each
level, as passing a prop down does in code. The editor does this in one
gesture and proposes the prop's name; an agent writes the same three
edits. This holds for the base's instances as much as for copies.

**Seeing and resetting.** The properties panel lists everything set on
an instance: for a copy, what differs from its base instance (props,
state, variation, place, and its state's variation content); for any
instance, the props it sets away from their defaults. Each can be reset
on its own, or all at once.

**Own instances** are ordinary instances, which only that state has.
Their ids are unique across the file: the base, every state and every
slot.

**Variations** are content changes within their state: `content` maps
`<id>.<prop>` to a literal, for `text` and `icon` props of any instance in
the state, its own and its linked copies alike. The base can have
`variations` too, changing its instances' content without a structural
state. A linked copy's content can change two ways
(`variations`):

- in a variation of the screen's (or component's) state: one-off wording
  that belongs to that place. Typing a copy's text in a frame writes it
  into the variation the frame shows; with the state shown as written, a
  new variation is created and shown.
- by putting the copy into one of its own component's variations
  (`variation`): a small fixed set of wording the component owns and any
  screen can pick.

When both set the same prop, the state's variation wins. Everything else
about a copy still follows its base.

In the properties panel, a `text` or `icon` prop says where its value
comes from (the base, a variation of its component, or a variation of
the state) and offers to reset it to the base or switch it to another
of those variations.

**On an instance,** `state` names one state of its component, or of its
primitive (a button's `disabled`), and `variation` one of that state's
variations, or of the component's base when there is no `state`. An
instance is in one state at a time: a combination that matters (an error
while focused) is a state of its own (`one-state-per-instance`).

The canvas draws one frame for the base and one per state, side by side.
Variations are not frames of their own: a frame shows its state as
written, or one of its variations, switched on the frame, so small
content changes are covered without a state, or a frame, each
(`variations`).

## Icons

`icon` is a primitive (`icon-primitive`): one glyph, decorative unless it
has a `label`, which names it for assistive tech. It is not pressable; a
pressable icon is an icon-only button. Its `icon` prop, and button's
`leadingIcon` and `trailingIcon`, have the type `icon`.

A reference is `<set>/<name>`, with an optional `:<style>`:
`material/wifi_off`, `material/home:filled`, `app/sync-done`. A set
without styles never takes one; with none written, a set's first style
applies (`outlined` for Material). Every set is SVG
(`icon-libraries`).

There are two kinds of set (`icon-libraries`):

- **Supported libraries**, Material Symbols to start. speccy ships each
  one's index (names, categories, tags and which styles each icon has,
  built from the library at a pinned version), so the picker, `speccy
icons` and the checker work offline. The SVGs themselves are fetched
  the first time something draws an icon, from the library's pinned
  version, and kept in `~/.speccy/icons/<library>/<version>/`, never in the
  project. An icon not cached and not reachable draws as a placeholder
  with its name; nothing fails.
- **The spec's own sets**, folders in `assets/icons/`: a library a team
  drops in, or `app`, where people and agents draw their own. An icon is
  its file, `<name>.svg`. These sets have names only, so the picker
  filters them by name, not by style or category.

A spec's SVG is untrusted, and the app inlines it into a page, so the
checker accepts only what a drawn icon needs and reports, and the app
won't draw, anything else: one `svg` root and nothing after it, UTF-8,
no DOCTYPE, entities or processing instructions, and only the shape
elements and attributes an icon uses (paths, basic shapes, groups,
`defs`, gradients, clip paths, masks, `title`, `desc`; no `use`, `symbol`
or `class`),
with references only inside the file (`#…`). No `<style>`, CSS
functions other than `url(#…)`, scripts, event attributes,
`foreignObject` or animation. What `speccy explain icon` asks of a drawn
icon: a `0 0 24 24` viewBox, one colour drawn as `currentColor`, no
fixed width or height.

`speccy icons <query>` runs the picker's search (names and tags) over
every set, filtered by `--set`, `--style` and `--category`, and prints the
references, so an agent reuses an icon before drawing one.

## The checker's rules

Beyond the schemas, the checker reports:

- References: `use`, `copy`, `state` and `variation`, `slots` names,
  `bind` paths, `repeat.each`, variations' `content` keys, state `data`
  names and data types all resolve, and every icon
  reference names an icon and a style its set has.
- Icons: a spec's SVGs are safe and drawable (see Icons).
- Bound states: a `state` or `variation` bound to data reads a field
  whose type is one of the component's state (or variation) names, as an
  enum (`["uploading", "done", "error"]`), and every sample value names
  one; a field that can be empty means the base. A variation written
  beside a bound `state` is one of the base's, since the state can be
  any; for a state's own variation, bind the variation too.
- Copies: `inner` names only instances inside the copied one; a copy's
  `props` are props its component declares; a prop's `default` fits its
  type.
- Types: every literal, sample, state `data` and `content` value fits the type of what it
  sets; a bound prop's path has the prop's type; `repeat.each` is a list.
- Placement: layout fields only on what holds children; `wrap` only on a
  row or column, `columns`, `rows` and `lineGap` without `wrap` only on a
  grid; grid placement fields only on a grid's children, within its
  tracks when they are counted; `x`, `y` and `constraints` only with
  `absolute`; `slot` only inside a component, on a
  container, list or dialog with no children of its own; a component used inside itself, directly or not.
- The composition rules of the catalog (`prototypes/catalog/README.md`):
  nothing pressable inside a pressable, a tab only in a tablist, a
  tabpanel named by a tab's `controls`, `controls` naming an existing id
  of the file the tree is drawn in (never one inside a component instance),
  `current` only on pressables and links. Pressable means what HTML
  calls interactive content: button, link, every input control
  (input, checkbox, radio-group, select, slider, date-picker,
  file-upload, otp-input), tree-view and video always; a
  container when `pressable`, a list or table when `selectable`, a toast
  when it has an `action`. The rules look through component instances:
  what a component holds counts where its instance sits. A value bound
  to data counts as set: a bound `pressable` makes its container
  pressable, and a tab whose `controls` is bound names some tabpanel. A
  menu is not pressable: its children are the area a context menu wraps,
  not its items.
- Keys: no object writes the same key twice.
- Files: names match items, names are unique, `format` is one the app
  reads; a screen's `device` names a preset or a spec device, and its
  `orientation` is one that device has.

Codes are kebab-case and stable once shipped (`unknown-use`,
`prop-type`, `bind-unresolved`, `pressable-in-pressable`…); the full list
is written with the checker.

## Writing files

The app writes each file as 2-space JSON, keys in the order the tables
above list them, `$schema` first, and skips files whose content didn't
change, so a diff shows only what someone changed. Agents may write keys
in any order; the app keeps theirs until it next saves that file.

**Two writers.** It works as any editor does with files in a project.
When a file the app has open changes on disk and the app has no unsaved
edits to it, the app reloads it. When it does have unsaved edits, it asks
before saving: overwrite the file with its edits, or take the file and
drop them. Nothing merges and nothing is overwritten without asking
(`two-writers-like-files`).

## Not in the MVP

Reserved for what comes after it: a data model's operations and a
screen's `from` (where data comes from); a component's `events` and
`local`, and `on` (interactions); flows; links to code. Primitives
already list their `events`, unused until interactions.

## The architect's calls

Settled here without a decision of Alberto's, to check first: the
manifest and its `format`; names and their cases; the `data.` prefix for
how a linked copy is written and which fields it may set; a state's
`data` replacing whole samples; a frame's in-place edit creating a
variation when none is shown; a state's variation winning over a
component variation on the same prop; `inner` for changing a copied
container's children; promoted props' names and defaults; variations
on the base; `state` on primitives naming their
built-in states; `state` and `variation` as two fields; repeats drawing
one copy per sample item; the
error shape and code style; how files are written; `assets/` as a
folder; icon reference syntax and the default style; shipping each
library's index and caching its SVGs per version; the rules for a drawn
SVG; spec sets filtering by name only; device fields and their names,
and how turning a device changes its size and safe area; the `apple-tv-4k`
preset's size, input and safe area.

## Open

Nothing at the moment.
