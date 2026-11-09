# speccy MVP

Status: draft

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
refine them. It covers components, screens, their layout and their
states; the rest of what a spec will hold (data, interactions, flows,
links to code) waits until those are settled.

The MVP proves:

- A product's screens can be built entirely from components, with no
  one-off elements, and the 24 primitives are enough to compose those
  components.
- A designer in the editor and an agent reading the spec's files see the
  same thing, and either can write it: what one changes, the other sees.
- States written as named changes to a base, each with a line on when it
  applies, are clear enough that an agent adds one correctly from a
  sentence.

## What ships

- **Primitives:** the 24 primitives of the catalog (button, input,
  checkbox, select, dialog, list, table, container and the rest), built
  in, each drawn as a wireframe with its own states. The composition
  rules hold: nothing pressable inside something pressable, a tab only in
  a tab list, and the rest the catalog lists. No composed components
  ship.
- **Components:** defined in the editor from primitives and other
  components, with the props an instance fills (copy goes there), their
  own layout and their own states, and used as instances anywhere.
- **Screens:** made only of component instances, each for a device
  (desktop, tablet or mobile), with copy set on each instance.
- **Layout:** Figma's auto layout on everything that holds children, and
  width and height on every instance as fill, hug or fixed, resized on
  the canvas when fixed.
- **States:** a name, a line on when the state applies, and only what it
  changes; drawn as frames beside the base and edited in place. States
  that hold together apply in the order written.
- **Canvas:** one screen or component at a time, its base and one frame
  per state side by side; the item list switches between them. Instances
  are inserted, reordered, moved into containers and resized on the
  canvas, and copy is edited in place on it; props and layout are edited
  in a side panel. An edit made in a state's frame changes that state,
  not the base. Pan, zoom and undo.
- **The spec lives with the code:** plain text files in the project's
  repository, which an agent reads and writes like any other code. The
  editor saves every edit to them as it is made and shows changes made
  outside it without a reload. A check reports anything that breaks the
  format or the composition rules.
- **A command line for agents:** installed with the app and run without
  it open. It checks the spec, with a stable code for each kind of error;
  draws any screen or component, in any state, as a page an agent can
  open or as a picture; explains the format and each primitive, from the
  same catalog the editor uses; and opens the app on a spec.

## Ready to ship when

- speccy's own editor is specced in speccy: its screen, with each panel,
  the canvas and the palette as components, and at least an empty and an
  error state, all built from the 24 primitives. Every gap in the format
  that it hits is either closed or written down.
- An agent given only the spec's files adds a component and a state to
  that spec from a one-sentence request, in its first attempt, with the
  check passing; the editor shows both without a reload.
- The check reports no errors on the finished spec.
- No edit made in the editor is lost: every one is there after a reload,
  including one made while an agent changed another part of the spec.

## Milestones

### 1. The format and its check

Status:

The format for components, screens, layout and states, with the 24
primitives and the composition rules, and a check anyone can run on a
spec. It comes first because the editor and the agents both rest on it.

Done when an agent writes a screen with one state from a sentence and the
check passes it, and the check flags a button placed inside a pressable
card.

### 2. The editor draws the spec

Status:

The editor opens a project's spec and draws its screens and components on
the canvas from the primitives' wireframes, the base and each state side
by side, and redraws when the files change.

Done when an agent's edit to a screen appears on the canvas without a
reload.

### 3. Building screens

Status:

Inserting, arranging and laying out instances and editing their copy, on
the canvas and in the side panel, saved as it is made, with undo.

Done when Alberto builds a screen from nothing in the editor and the
check passes it.

### 4. Components

Status:

Defining a component from primitives in the editor, giving it props, and
using it on screens.

Done when a tabs component built in the editor is used on two screens,
and a change to it shows on both.

### 5. States

Status:

Adding, describing, ordering and editing states in their frames, on
screens and components.

Done when Alberto adds an empty and an error state to a screen in the
editor, and an agent asked what each changes answers from the files
alone.

### 6. speccy in speccy

Status:

Specifying speccy's own editor in speccy, closing the format gaps it
hits along the way.

Done when every check under Ready to ship holds.

## After the MVP

Next, in this order: data models that screens show and instances bind to;
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
- **Lists are written out.** With no data, a list holds its items as
  instances with copy on each, not one item repeated over data. Assumed.
- **The format can break.** It is expected to change while the MVP is
  used, and a spec written before a change doesn't have to keep working
  after it. Assumed.
- **Format gaps are closed when a screen needs them.** The gaps the
  catalog's coverage audit found (rich options, scrolling, keyboard
  focus, nesting and the rest) are closed as speccy's own screens hit
  them, not up front. Assumed.
- **Two writers on one item.** What happens when the editor and an agent
  change the same component or screen at once is open; the MVP needs only
  that nothing written in the editor is lost.
