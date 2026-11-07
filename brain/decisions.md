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
