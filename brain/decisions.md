# Decisions

What was decided about speccy, and why. Each decision has a key, its
heading, that items, docs and agents cite it by, such as
`decisions.md#<key>`. An entry is a short description: what was decided,
when, and why, in a few lines. It is not a long document; what it changes
lands in the PRD or the architecture doc, and the entry says where.

## behavior-not-ui

2026-11-06. speccy specs behavior and its link to code, not UI: tokens,
styling, layout, responsive layout and motion stay in Figma. Its
components carry only the UI it takes to say what they do. Why: visual
design is Figma's ground and speccy doesn't compete there; behavior and
closeness to code are where Figma falls short. In: `objects.md`.

## arrangement-and-sizing

2026-11-06. The one layout a component or screen carries is arrangement
and sizing: its children's direction, order and nesting, and whether each
fills, fits or is fixed; a user can change it. Alignment, gaps, padding
and pixel values stay in Figma. Why: what sits where, and what grows,
shapes behavior such as focus order and what stays visible. In:
`objects.md`.

## primitives-out-of-the-box

2026-11-06. speccy ships core components every app has as primitives;
more complex components are composed from them. Reading components out
of a codebase is a later feature, not the MVP's. Why: where components
come from is a bigger conversation, and primitives let the MVP start
without one. In: `objects.md`.

## components-own-behavior

2026-11-06. A composed component defines its own states, interactions and
rules, and every screen that uses it gets them; screens add only their
own. Why: behavior is specced once and reused, like the component. In:
`objects.md`.

## screen-states-are-changes

2026-11-06. A screen's state is a named set of changes to its base:
which instances show or hide, their data and copy, and the state each is
in. Why: the screen is defined once, and an agent reads exactly what
differs instead of diffing copies. In: `objects.md`.

## copy-inline-data-bound

2026-11-06. Copy is written on instances and in state changes; data is
an object of its own that instances bind to. Why: copy reads best in
context, while data is behavior agents guess at, so the spec says once
what a screen shows and from where. In: `objects.md`.

## edge-cases-are-conditions

2026-11-06. Edge cases are not objects: each is the condition that puts a
screen or component into a state. Why: no extra object to keep in sync,
and every edge case has to say what the UI does about it. In:
`objects.md`.

## no-code-mappings-in-mvp

2026-11-06. The MVP has no code mappings; how fine they are is decided
after it. Why: the MVP proves how components and screens are defined,
and links to code would have to follow every change to that definition.
In: `objects.md`.

## primitives-are-html

2026-11-06. speccy's primitives are a subset of the elements HTML
defines, such as text, button and input. Why: their behavior is already
defined and known to every agent and engineer, so speccy doesn't invent
a component library. In: `objects.md`.

## first-primitives

2026-11-06. The first primitives are container, text, button, input,
textarea, select, link, list, form and dialog; others join when a screen
needs one. Why: enough to compose forms, lists and dialogs, few enough to
define each carefully. In: `objects.md`.

## no-one-offs

2026-11-06. Everything on a screen is an instance of a component; there
are no one-off elements, as Figma allows. Why: behavior is specced once,
on the component, and every piece of a screen has a definition an agent
and the code can point to. In: `objects.md`.

## states-stack-in-order

2026-11-06. When several states hold at once, all apply in the order
they are written, and the later wins where two change the same thing.
Why: simple and predictable, the order is visible in the file, and
combinations (offline and error) need no states of their own. In:
`objects.md`.

## states-described-not-conditioned

2026-11-06. A state has a name, a one-line description of when it
applies, and its formal changes; there is no condition language, and
interactions enter and exit states. Why: a formal condition adds little
an agent can't read from a sentence, and it forced modelling everything
a state depends on (being offline needed a fake data model). In:
`objects.md`, `prototypes/spec-format`.

## figma-auto-layout

2026-11-07. Components and screens carry Figma's full auto layout: flow
(row, column, stack, grid), wrap, alignment, gap, padding, clipping, and
width and height as fill, hug or fixed pixels with minimums and maximums;
screens name their device (desktop, tablet, mobile). Supersedes
`arrangement-and-sizing`. Why: designers expect Figma's controls, and the
editor needs real layout to be usable. In: `objects.md`,
`prototypes/spec-format`.

## no-pattern-primitives

2026-11-07. The expanded primitives hold only reusable controls; patterns
with app content (page headers, empty states, activity feeds, metrics and
the like) are left out, and teams compose them from primitives. Why: their
content is app-specific, so fixed props would rarely fit. In:
`prototypes/catalog`.

## primitives-bind-models

2026-11-07. A primitive with a structured value (nested items, table
rows, calendar items, chart data) takes a data model chosen by the
instance that binds it, written `model` or `model[]`, instead of a new
built-in type. Why: it reuses data models rather than starting a second
type system. In: `prototypes/catalog`; the checker doesn't support it yet.

## primitives-unique-behavior

2026-11-08. A primitive must have capabilities and behavior unique enough
to be its own thing; everything an end user can compose from primitives
is not one. That leaves 25, from the Material 3 and Untitled UI kits:
variants fold into one primitive as options (switch into checkbox,
sheet into dialog, tooltip into popover, tag and badge into button), and
composable ones (tabs, navigation, alert, card…) are listed as `composed`,
the seed of a component library to build later. Why: a small set of
primitives with real behavior keeps the spec close to code and leaves
everything else to composition. In: `prototypes/catalog`.

## mvp-scope

2026-11-08. The MVP is an editor for Alberto and coding agents only, and
covers components, screens, their layout and their states; data models,
interactions and flows come after it, in that order. Only the 24
primitives ship: composed components are built in the editor. It is ready
when speccy's own editor is specced in speccy. Why: the MVP is a test
bench for how components and screens are defined, and composing the
library and speccy's own screens is that test. In: `prd/mvp.md`.

## agents-edit-files

2026-11-08. In the MVP, agents read and write the spec's files directly,
like code, and the editor shows their changes live; there is no agent
interface. Why: the format trial showed an agent learns it from its
files, so both kinds of author are proven with nothing agent-specific to
build. In: `prd/mvp.md`.
