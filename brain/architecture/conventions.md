# Conventions

How speccy is designed and built. Each convention has a key, its
heading, that specs, items and agents cite it by, such as
`conventions.md#<key>`, and a very brief description: a line or two, not
a document. Whoever designs a feature reads Design; whoever builds one
reads Implementation.

# Design

## files-are-the-model

The core works on the files' decoded JSON, key order kept, and nothing
else: no structs or schemas mirroring the format, no cache of derived
data outside a function call (`core.md` § What carries the weight).

## pure-core

Modules under `lib/speccy/` other than the workspace, the icon fetch,
the CLI and `Speccy.Format`'s `find` and `load` do no IO, start no
process and read no environment; they take the spec and return data.
Anything that touches a file, the network or time lives in those or in
`lib/speccy_web/`.

## format-md-is-the-format

A change to what a spec file may hold changes `format.md`, the schemas'
builder and `speccy explain`'s text in the same change. Field names and
error codes come from `format.md`; a breaking change bumps `format`.

## no-primitive-cases

Nothing outside a primitive's own module matches on a primitive's name.
The checker, resolve, the props panel and the schemas read what they
need (holds children, pressable, states, prop types) from its interface;
a new fact a rule needs is added to every interface.

## edits-are-operations

Every change the editor makes to a spec is one `Speccy.Edit` operation:
a LiveView never builds JSON for a file or writes one. One operation is
one undo entry, however many files it changes.

## address-by-id

Edits, canvas events and sources name a file and the chain of instance
ids to the part, plus the frame (base or state) and variation; never a
position in a list.

## sources-not-dom

What a value comes from, and which props an edit must promote, is read
from the resolved node's sources, never worked out again from the DOM
or the file in the LiveView.

## resolve-is-total

Resolving and drawing never raise on what a spec holds: a piece that
can't be resolved becomes an error node carrying the check's code. A
raise means a bug in speccy.

## one-write-door

Only the workspace writes spec files, through its check that the disk
still holds what it last read or wrote. Tests and the CLI never write a
spec except through it or into a temp copy.

## gestures-in-the-hook

Pan, zoom, drag previews, resize handles and typing in place live in the
canvas hook until the gesture ends; the server gets one event for the
finished edit, never a stream of moves.

## app-ui-the-phoenix-way

The app's own interface is built from `core_components.ex` with Tailwind
and daisyUI. Wireframes use only `wireframe.css`'s `wf-` classes, under
`.wf`; neither side uses the other's classes (`wireframes-apart-from-app`).

## cli-is-thin

A `speccy` command parses its arguments, calls the core once and prints;
anything it computes that the editor could also need belongs in the
core.

## spike-evidence

A spike's README and its `core.md` edit say, for each finding, whether
it was observed (by a self-test, by hand, or in the source) or inferred;
`core.md` records only what was observed.

# Implementation

## json-through-format

Spec files are decoded only by `Speccy.Format` (`Jason`,
`objects: :ordered_objects`) and encoded only by it, in `format.md`'s
key order. Nothing else calls `Jason` or `JSON` on a spec file.

## a-primitive-is-a-module

A primitive is one module in `lib/speccy/primitives/`, with
`interface/0` and its component, and one line in the registry. Its
props are declared once, in the interface: the component reads them
from its assigns and declares no `attr` per prop.

## codes-in-one-list

Every check code is a kebab-case atom in one list in `Speccy.Check`,
with its message; a code is never renamed once a milestone that uses it
has landed. Each code has a test that triggers it.

## untrusted-input-allowlists

A check on untrusted content, such as a spec's SVGs or anything else the
app inlines into a page, accepts a closed list of what is known safe and
refuses the rest; it never lists known-bad patterns.

## no-sleeps

Code and tests wait on a message or a condition with a timeout, never a
fixed sleep: the workspace's watcher events, the canvas's redraws and
the icon fetch included.

## fixtures-cover-the-format

The clean fixtures under `test/fixtures/specs/` hold, between them, at
least one of every kind of object and every key in `format.md`'s
tables, so the key-order, round-trip and check tests see them all.

## named-dependencies

The dependencies are the ones `core.md` names, plus Phoenix's generator's
own. Adding another is the architect's call, recorded in `core.md`.

## precommit-passes

`mix precommit` (compile with warnings as errors, unused deps, format,
tests) passes before a change is handed over, and `npm test` in `e2e/`
when the change touches the canvas or the editor.
