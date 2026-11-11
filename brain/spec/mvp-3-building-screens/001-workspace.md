# MVP 3: the workspace writes

Bead: spec-yu5

The workspace applies an edit, writes the files it changes if the disk
still holds what was read, and keeps undo and redo. It becomes the one
door spec files are written through (`conventions.md#one-write-door`).

## Program design

Three calls join `Speccy.Workspace`:

- `edit(dir, op)`: `{:ok, ids}`, or `{:error, reason}`.
- `undo(dir)` and `redo(dir)`: `:ok`, `{:error, :nothing}` or
  `{:error, :conflict}`.

Its state gains `undo` and `redo`, two lists of entries. An entry is a
map of path → `{before, after}`, each a file's content as text, nil for
a file that isn't there.

**An edit.**

1. `Speccy.Edit.run(state.spec, op)`. An error is returned as it is.
2. A changed path that is in `state.stale` returns `{:error, :stale}`:
   the file on disk can't be read as it is now, what is drawn is its
   last good version, and saving that with the edit on top would write
   over what someone is in the middle of writing.
3. A changed file that fails its schema
   (`Speccy.Check.Schema.problems/2`) returns `{:error, :invalid}`. A
   file that fails it can't be drawn or edited again, and a pasted
   instance or a typed value could otherwise write one.
4. **The disk check.** For each changed path, read the file. Its
   content, decoded (`Speccy.Format.decode/1`), must equal what
   `state.loaded` holds for that path; a file the edit creates must not
   exist. If any differs, nothing is written: the workspace reads the
   spec again, as a quiet timer would, broadcasting what it finds, and
   returns `{:error, :conflict}`.
5. Write each changed file as `Speccy.Format.encode/2` gives it.
6. Read the spec again, broadcast `{:spec_changed, …}` as today, push
   the entry (each path's content before, from step 4, and after) onto
   `undo`, and empty `redo`. Return `{:ok, ids}`.

The watcher's event for the workspace's own write then finds nothing
changed and broadcasts nothing, as an identical write does today.

**Undo** takes the top entry: for each path the file on disk must hold
`after`, compared as text; then each is written back to `before`, a nil
`before` deleting the file, the spec is read again and broadcast, and
the entry moves to `redo`. **Redo** is the same the other way. Either
one that finds a file changed writes nothing, empties both lists and
returns `{:error, :conflict}`: the history no longer describes the
files.

A file changing on disk doesn't touch the lists; the check at undo time
is the only guard.

In the same change, because it changes what is true of the app:

- `format.md` § Writing files, **Two writers**: when a file changed on
  disk since the app read it, the app's edit to it is dropped and the
  app says so; nothing asks, merges or is overwritten. `speccy explain`
  prints this section.
- The moduledoc of `Speccy.Workspace`, which says it writes nothing.

## Tests

`test/speccy/workspace_test.exs`, `@tag :tmp_dir`, a fixture copied in,
waiting on the PubSub message (`conventions.md#no-sleeps`):

- An edit writes the file in `format.md`'s key order and is broadcast;
  a file the edit didn't change keeps its bytes.
- A file changed on disk between the workspace's read and the edit: the
  edit returns `:conflict`, the file keeps the outside change, and the
  broadcast carries it.
- An edit to a file written as invalid JSON returns `:stale` and leaves
  the file as it is.
- A paste whose instance fails the schema returns `:invalid` and writes
  nothing.
- Undo restores the file's bytes; redo writes the edit again; undo of a
  new screen deletes its file; an edit after an undo empties redo.
- Undo after the file changed outside returns `:conflict`, writes
  nothing, and a second undo returns `:nothing`.

## Done when

- `mix precommit` passes.
- Nothing but `Speccy.Workspace` writes a spec file: a search of `lib/`
  for a write to one finds only it.
