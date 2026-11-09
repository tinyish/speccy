# The spec's objects

What a speccy spec is made of, and how the pieces fit together. The spec
is built from structured objects that agents can read and code can be
checked against.

speccy specs behavior, not UI. How things look is Figma's job, and
speccy doesn't compete with it; it covers where Figma falls short: what
the product does, and how close the spec sits to the code that does it.
So its objects carry only as much UI as it takes to say what something
does.

This is a working map, not a settled model: the MVP is an editor for
building screens from components, and it exists to try out the answers
below and refine how components and screens are defined. Why each answer
was chosen is in `decisions.md`.

## The pieces

### Structure

- **Components**: the parts a user sees and acts on, described by what
  they do, not how they look: what kind of thing each is (a button, a
  list, a field, a dialog), its parts and how they are arranged, the
  data it takes, what a user can do to it, and its states. Defined once,
  used many times, and each one close to the component in code that
  builds it. speccy ships the core components every app has as
  primitives, and more complex components are built from them (see
  below).
- **Screens**: each view, its purpose and the component instances it
  contains, each with its data set, arranged the same way a component
  arranges its parts. Everything on a screen is an instance of a
  component: there are no one-off elements, as Figma allows. Something
  used once is still a component, used once.
- **Flows**: paths users take through the product, step by step: screens
  joined by the interactions that move between them.

### Behavior

- **States**: empty, loading, error, success, disabled and partial data,
  per screen and component.
- **Interactions**: what each tap, submit, hover or swipe does, and what
  happens next: another state, another screen, or a change in data.
- **Rules**: conditions and validation, such as role-based visibility or
  field limits.
- **Edge cases**: offline, timeouts, permission denied, long text, zero or
  thousands of items. Not objects of their own: each is a state of a
  screen or component, described by when it applies ("the device has no
  connection"), so every edge case says what the UI does about it.
- **Accessibility**: focus order, labels and keyboard paths: how the
  product behaves for someone not using a pointer or a screen.

### Content

- **Copy**: labels, error messages, empty-state text and tone, versioned.
  Written on the instance, or in a state's changes, where it is read in
  context.
- **Data model**: what each screen displays, its fields, types and source.
  An object of its own that instances bind to, so a screen says once
  what it shows and from where, and its states can refer to it (an empty
  list).

```
data Task: title text, done bool

TaskScreen
  shows: Task[] from tasks
  TaskList  ← tasks
    TaskRow.title ← task.title
  EmptyState "No tasks yet"
```

### Context

- **Users and roles**: who sees what, and how permissions change the UI.
- **Acceptance criteria**: the testable "done when" for each flow or
  screen.
- **Decisions**: why a choice was made, so it isn't undone.

### Linking

- **Code mappings**: the component or file that implements each object.
- **Status**: specced, in progress, implemented, drifted or approved.

## Left to Figma

How the product looks stays out of the spec: tokens (colors, type),
styling, visual variants, responsive layout, motion and contrast. Where
one of them changes behavior, such as a menu that collapses on small
screens, the behavior goes in the spec as a rule or a state; the look
doesn't. Layout is the exception: the spec keeps it, because what sits
where, and how big, shapes behavior.

## Layout

The layout a component or screen carries follows Figma's auto layout, so
a designer meets the controls they know:

- **What holds children** sets their flow (a row, a column, a stack
  layered on top of each other, or a grid), wrapping, alignment, the gap
  between them, padding and clipping.
- **Every instance** sets its width and height: it fills the space, hugs
  its content, or has a fixed size in pixels, with optional minimums and
  maximums.
- **A screen** names the device it is for: desktop, tablet or mobile.

What sits where, and how big, feeds behavior such as focus order and
what stays visible; a state can change layout as well as content.

```
TaskScreen   mobile, column
  Header     width fill, height hug
  TaskList   width fill, height fill
  Footer     width fill, height hug

Header       row, align center, gap 8, padding 12
  text       width fill
  button     width hug
```

## Screen states

A screen is defined once, as its base. Each of its states (empty,
loading, error) is a named set of changes to that base: which instances
show or hide, what data and copy they get, and which state each instance
is in. A state has a name, a short description of when it applies,
and only what differs, so an agent reads exactly what changes and why.
There is no formal condition: people and agents read the description.
An interaction can enter or leave a state. When several
states hold at once, all of them apply, in the order they are written;
if two change the same thing, the later one wins.

```
TaskScreen
  base: Header, TaskList, Footer

  state empty    "The tasks have loaded and there are none."
    hide TaskList
    show EmptyState "No tasks yet"
  state offline  "The device has no connection."
    show Banner "You're offline"
  state error    "The tasks failed to load."
    TaskList → error
    show Retry
```

## Primitives and composed components

speccy comes with components out of the box for the core of every app:
the primitives, a subset of the elements HTML already defines, such as
text, a button or an input, with the behavior HTML gives them. The
first set is the interactive core; others are added when a screen can't
be built without them.

```
container  div        arranges children
text       p, span    shows copy or data
button     button     action; enabled/disabled
input      input      text, checkbox, radio
textarea   textarea   long text
select     select     pick one of many
link       a          goes to another screen
list       ul/li      items; empty when none
form       form       submit; valid/invalid
dialog     dialog     open/closed
```

Anything more complex is a composed component, built from primitives
and other composed components, the same way a screen is. A composed
component defines its own states, interactions and rules once, and every
screen that uses it gets them; a screen adds only what is its own.
Reading components out of an existing codebase is a later feature, not
the MVP's.

## How they fit

The structure objects stack, each built from the one below:

```
Components  →  Screens  →  Flows
defined once    instances,     screens joined
(kind, data,    data set       by interactions
 actions,
 states)
```

The rest attach to that stack:

- **On components and screens:** states, interactions, rules, edge cases,
  copy and accessibility. A component's states (a disabled button) are
  its own; a screen's states (an empty list) are changes to its base, as
  in Screen states.
- **On screens:** the data model, what the screen shows and where it
  comes from, which feeds the data of its instances.
- **On flows and screens:** acceptance criteria.
- **Across everything:** users and roles, which rules and states refer
  to; decisions, which can sit on any object; and code mappings and
  status, which every object can carry.

The core of the puzzle is **definition versus instance**. A component is
defined once, with what it takes, what a user can do to it and its own
states; a screen holds instances of it and fills them with copy and data.
Most behavior lives where those two meet: what a screen sets in which
state, and which rules change it.

## What the MVP touches

The MVP editor builds screens from components, so it works on
components, screens, and the instances that join them. Code mappings
are not in it: linking to code waits until how components and screens
are defined is settled. Everything else attaches later, and the shape
the MVP settles on for components and screens decides where it
attaches.

## Open questions

Still open:

- **How fine code mappings are.** After the MVP: a component to its
  file, or each instance to where it is used.
