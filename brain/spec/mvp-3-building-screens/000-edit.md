# MVP 3: the edit operations

Bead: spec-yu5

`Speccy.Edit`, every change the editor makes to a spec, as pure
functions from the spec to the files they change.

## Program design

`Speccy.Edit.run(spec, op)`, in `lib/speccy/edit.ex`: `spec` a
`Speccy.Spec`, `op` one of the tuples below. It returns
`{:ok, files, ids}`, `files` a map of path → the file's new JSON, key
order kept, for the files the operation changes, and `ids` the
instances it made or changed (none for the root); or
`{:error, reason}`, changing nothing. It is pure (`conventions.md#pure-core`): it reads
`spec.ordered` and writes nothing.

An operation names its file and its instances by id; ids are unique in
a file. Where it takes several (`ids`), one that is inside another of
them is left out: the outer one carries it. Every operation but `new_screen` works on a file in `spec.valid`
and returns `{:error, :invalid}` for any other, and
`{:error, :unknown_id}` for an id the file's base doesn't hold. The
base's instances are its `children`, at any depth, and the instances in
their `slots`.

| Operation | Does |
| --- | --- |
| `{:insert, file, use, into, before}` | Adds a new instance of `use` to the children of `into` (an id, or nil for the file's root), before the child `before` (an id, or nil for the end). |
| `{:move, file, ids, into, before}` | Takes the instances out of where they are and puts them, in the order the file has them, in the children of `into`, before `before`, as insert does. |
| `{:delete, file, ids}` | Removes the instances and everything in them. |
| `{:duplicate, file, ids}` | Puts a copy of each instance right after it. |
| `{:paste, file, instances, into, before}` | Adds `instances`, a list of instances as JSON, to the children of `into`, before `before`, as insert does. |
| `{:props, file, ids, props}` | Sets each prop in `props` (prop → literal) in each instance's `props`; a nil value removes it. |
| `{:set, file, ids, fields}` | Sets each field in `fields` on each instance, or on the file's root for no ids; a nil value removes it. |
| `{:new_screen, name, about, device}` | A new file, `screens/<name>.json`. |

**Insert.** The new instance is `{ "id", "use" }`, and for a primitive
its `props` are its interface's `start`. `start` is a new field of
every primitive's interface (`Speccy.Primitives`), apart from its
`examples`, which are the gallery's: the props a fresh one starts with,
just enough to be seen and typed over. A text says "Text", a button
"Button", an input has a label; one that holds children and draws when
empty, such as a container, a form or a list, starts with none. An
empty `start` writes no `props`. `speccy explain` doesn't print it. Its id is `use` in camelCase
(`TaskRow` → `taskRow`), then with `2`, `3` and on until no instance in
the file has it, the states' own instances included. `into` must be the
root or a primitive that holds children (`Speccy.Spec.holds?/1`), else
`{:error, :no_children}`. `use` must have a target, else
`{:error, :unknown_use}`.

**Move.** `into` as for insert, and never one of the instances or
anything inside one: `{:error, :inside_itself}`. A `before` that isn't a
child of `into` means the end.

**Delete.** With each instance go, in the same file: every linked copy
of it or of an instance inside it, in every state; every `inner` entry
that names one of them; and every `content` entry `<id>.<prop>` for one
of them, in the base's variations and each state's. An `inner` or a
`content` left empty is removed with its key.

**Duplicate and paste.** A copy is the instance as written, with
everything in it. Every id in it that the file already has, and in a
duplicate that is every one, is replaced by a fresh one, made as insert
makes it. `ids` are the copies'. Paste takes what the clipboard held,
which is anyone's text: `instances` must be a list of objects that each
have a string `id` and a string `use`, else
`{:error, :not_instances}`.

`Speccy.Edit.copy(spec, file, ids)` is the other half: the instances as
written, in the file's order, for the clipboard.

**Props.** A `props` left empty is removed. The operation doesn't look
at `bind`: the panel offers no field for a bound prop.

**Set.** On an instance, the keys are its size and placement
(`Speccy.Format.place/0`), its layout (`Speccy.Format.layout/0`), and
`about`, `state` and `variation`. On the root they are the layout keys,
`about`, and for a screen `device` and `orientation`, for a component
`width` and `height`. A key outside the list is
`{:error, :unknown_field}`: the keys arrive from the page.

**New screen.** The file holds `$schema` (`Speccy.Schemas.url/1`),
`screen`, `about`, `device` and an empty `children`. A name an item
already has is `{:error, :name_taken}`.

`Speccy.Edit` checks no more than this. What an operation leaves wrong,
such as a size that makes no sense in its container, the check reports,
as it would for an agent's edit.

## Tests

`test/speccy/edit_test.exs`, on fixtures, comparing the returned files
as JSON (`testing.md` § Core):

- Insert into the root, into a container, before a child and at the
  end; a second insert of the same `use` gets the next id; a primitive
  comes with its `start`, a component with no props.
- Every primitive, inserted into an empty screen, leaves a spec the
  check passes, and so does a button inserted into an inserted
  container.
- Move within a container, into another, and into itself (refused);
  two instances moved together keep their order; one inside another
  that is also moved goes once.
- Duplicate of a container gives a copy after it whose every id is
  fresh; paste of `copy/3`'s result into another file keeps the ids
  that are free there and replaces the taken ones; paste of a list
  that isn't instances is refused.
- Delete on the `tasks` fixture's `header`: its three copies go, the
  states keep their own instances, and the result passes the check.
  Delete of an instance named in a variation's `content` and in an
  `inner` removes both.
- Props: set, change, remove, and the last one removed drops `props`;
  set on two instances at once.
- Set: a size, a layout field on the root, a field outside the list
  (refused).
- New screen: the file as written passes its schema; a taken name is
  refused.
- Every file an operation returns encodes in `format.md`'s key order
  (`Speccy.Format.encode/2`) and decodes back to the same JSON.

## Done when

- `mix precommit` passes.
- Each operation, run on the `tasks` fixture, leaves a spec the check
  passes.
