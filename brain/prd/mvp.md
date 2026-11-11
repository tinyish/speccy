# speccy MVP

Status: approved

The first release of speccy: what ships in it, how we know it is ready,
the milestones that build it, and what comes after. It is the one source
of truth for what is built first: the most bare-bones product that proves
the architecture works, a vertical slice. The principles and success
measures it draws on are in [seed](seed.md).

## What the MVP is

A desktop editor for building screens from components, used by Alberto
and the coding agents he works with, and no one else yet. It is a test bench: how
components and screens are defined is expected to change while it is
used, and the MVP exists to try different answers on real screens and
refine them. It covers components, screens, their layout, their states
and the shape of the data they show; the rest of what a spec will hold
(where data comes from, interactions, flows, links to code) waits until
those are settled.

The MVP proves:

- A product's screens can be built entirely from components, with no
  one-off elements, and the 25 primitives are enough to compose those
  components.
- A designer in the editor and an agent reading the spec's files see the
  same thing, and either can write it: what one changes, the other sees.
- States written as compositions of their own, beside a base they
  copy from, each with a line on when it applies, are clear enough that
  an agent adds one correctly from a sentence.

## What ships

- **Primitives:** the 24 primitives of the catalog (button, input,
  checkbox, select, dialog, list, table, container and the rest) and an
  icon, built
  in, each drawn as a wireframe with its own states. The composition
  rules hold: nothing pressable inside something pressable, a tab only in
  a tab list, and the rest the catalog lists. No composed components
  ship.
- **Icons:** an icon is picked from a dropdown that searches a library
  as you type, shows a small preview beside each name, switches between
  libraries, and filters by style (outlined or filled) and category.
  Material is the first library speccy supports; its icons are fetched
  the first time something shows them and kept on the user's machine,
  never in the project. A team adds its own libraries as folders of
  drawings in the spec, and an agent can draw a new icon there that
  shows up in the dropdown straight away. Whether an icon is filled is
  part of which icon is chosen, so a state can fill a selected tab's
  icon.
- **Components:** defined in the editor from primitives and other
  components, with the props an instance fills (copy goes there), their
  own layout and their own states, and used as instances anywhere.
- **Screens:** made only of component instances, each for a device,
  with copy set on each instance. A device is one of a handful of
  presets, each a real current device (phones, a tablet, a laptop, a
  desktop display, watches and a TV), or
  one the spec defines with its own size, such as a watch or the display
  of an appliance. The editor draws each screen at its device's size.
- **Data shapes:** data models, each a set of fields; a screen says
  which data it shows, with sample values, an instance's prop can show a
  piece of it, and a list instance can repeat once per item. A component
  opened on its own shows placeholders for its data. Where the
  data comes from is not in the MVP.
- **Layout:** Figma's auto layout on everything that holds children, and
  width and height on every instance as fill, hug or fixed, resized on
  the canvas when fixed.
- **States:** a name, a line on when the state applies, and the
  screen or component as it is then: copies of the base's components it
  chooses, which stay in step with the base, and components of its own,
  with its own sample data. A copy differs from the base only in
  what is set on it: its props, its place, and which of its own states
  it is in. Changing a part inside a component, on one screen, gives the
  component a new prop with today's value as its default, as a developer
  would, so its other uses stay as they were. Every change on a
  component is listed in the props panel and can be reset one by one or
  all at once. A component is in one state at a time. A component
  added to the base reaches a state only when the user copies it there.
- **Variations:** a state, or the base, can hold variations, each a
  name, a line on when it applies, and different text and icons for any
  of its components, copies of the base's included (offline and error as
  one state with two variations). A component can also define variations
  of its own wording that any screen picks. Typing new text in a frame
  needs no setup: it goes into the variation the frame shows, made on the
  spot if there is none. The props panel shows where each piece of text
  comes from and switches it back to the base or to another variation.
  The base and each state are drawn as frames side by side and edited
  in place; a frame shows one variation at a time, switched on the
  frame, so covering small content changes adds neither states nor
  frames.
- **Canvas:** one screen or component at a time, its base and one frame
  per state side by side; the item list switches between them. Instances
  are inserted, reordered, moved into containers and resized on the
  canvas, and copy is edited in place on it; props and layout are edited
  in a side panel. An edit made in a state's frame changes that state,
  not the base. Pan, zoom and undo.
- **The spec lives with the code:** plain text files in the project's
  repository, which an agent reads and writes like any other code. The
  editor saves every edit to them as it is made and shows changes made
  outside it without a reload. The editor never saves over a file that
  changed on disk: an edit that meets one is dropped, and the editor
  says so. A
  check reports anything that breaks the format or the composition
  rules.
- **A command line for agents:** installed with the app and run without
  it open. It checks the spec, with a stable code for each kind of error;
  draws any screen or component, in any state, as a page an agent can
  open or as a picture; explains the format and each primitive, from the
  same catalog the editor uses; searches icons the way the dropdown
  does, so an agent reuses one before drawing its own; and opens the app
  on a spec.

## Ready to ship when

- speccy's own editor is specced in speccy: its screen, with each panel,
  the canvas and the palette as components, and at least an empty and an
  error state, all built from the 25 primitives. Every gap in the format
  that it hits is either closed or written down.
- An agent given only the spec's files adds a component and a state to
  that spec from a one-sentence request, in its first attempt, with the
  check passing; the editor shows both without a reload.
- The check reports no errors on the finished spec.
- No edit is lost silently: every edit made in the editor is there after
  a reload, and nothing an agent wrote is overwritten.

## Milestones

### 1. The format and its check

Status: built

The format for components, screens, layout and states, with the 25
primitives and the composition rules, and a check anyone can run on a
spec. It comes first because the editor and the agents both rest on it.

Done when an agent writes a screen with one state from a sentence and the
check passes it, and the check flags a button placed inside a pressable
card.

### 2. The editor draws the spec

Status: built

The editor opens a project's spec and draws its screens and components on
the canvas from the primitives' wireframes, the base and each state side
by side, and redraws when the files change. The command line draws any
frame as a page an agent can open. The desktop window comes last, once
the canvas works in a browser.

Done when an agent's edit to a screen appears on the canvas without a
reload.

### 3. Building screens

Status:

Inserting, arranging and laying out instances and editing their copy, on
the canvas and in the side panel, saved as it is made, with undo.
Several are selected, moved, duplicated, copied and pasted together,
with the gestures and keys a designer knows from Figma, and a
right-click offers what fits what was clicked. Icons are picked from the
dropdown, and the command line searches them the same way.

Done when Alberto builds a screen from nothing in the editor and the
check passes it.

### 4. Components

Status:

Defining a component from primitives in the editor, giving it props, and
using it on screens.

Done when a tabs component built in the editor is used on two screens,
and a change to it shows on both.

### 5. Data and bindings

Status:

Editing what a screen shows in the editor: its data and sample values,
data models, binding an instance's prop to a piece of data, and
repeating a list once per item.

Done when Alberto gives a screen a list of sample items in the editor,
binds a repeated row to it, and the canvas draws one row per item.

### 6. States

Status:

Adding, describing, ordering and editing states in their frames, on
screens and components.

Done when Alberto adds an empty and an error state to a screen in the
editor, and an agent asked what each changes answers from the files
alone.

### 7. The look

Status:

How the app and the canvas look, revisited as a whole once every panel
and gesture has landed.

Done when Alberto has gone through the editor and its wireframes and
says they look right.

### 8. speccy in speccy

Status:

Specifying speccy's own editor in speccy, closing the format gaps it
hits along the way.

Done when every check under Ready to ship holds.

## After the MVP

Next, in this order: where data comes from and the operations on it;
interactions, which enter and exit states and change data; and flows,
screens joined by those interactions, with a view of many screens at once
on the canvas.

Later, in no fixed order: an agent interface with proposals Alberto
approves, links to code and drift shown on the spec, a library of
composed components (tabs, navigation, card, alert and the others the
catalog lists), reading components out of a codebase, and teams beyond
Alberto.

## Assumptions and open questions

- **Components have props, not events.** With interactions out, a
  component's interface is the props its instances fill; its events and
  local state wait for interactions. Assumed.
- **The format can break.** It is expected to change while the MVP is
  used, and a spec written before a change doesn't have to keep working
  after it. Assumed.
- **Format gaps are closed when a screen needs them.** The gaps the
  catalog's coverage audit found (rich options, scrolling, keyboard
  focus, nesting and the rest) are closed as speccy's own screens hit
  them, not up front. Assumed.
