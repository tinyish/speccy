# MVP 2: one reading of a spec

Bead: spec-eai

`Speccy.Spec`, the one reading of a loaded spec that the check and
Resolve share, and the check moved onto it. No behaviour changes: every
existing test passes as written.

## Program design

Today `Speccy.Check.run/1` builds an index of the spec privately
(`index/4`) and holds the readers of it as private functions, five of
them made public with `@doc false` for `Speccy.Check.Composition`. They
move to a new module, `lib/speccy/spec.ex`, with no change in what they
return.

`Speccy.Spec.new(loaded)` takes what `Speccy.Format.load/1` returns and
returns a map:

| Key | Holds |
| --- | --- |
| `ordered` | path → the file's JSON as loaded, key order kept, or `{:error, message}` |
| `read` | path → the same as plain maps, for every file that is valid JSON |
| `schema` | path → the file's schema problems (`Speccy.Check.Schema.problems/2`) |
| `valid` | path → plain JSON, for the files with no schema problem |
| `items` | `{name, kind, path}` for every item read, valid or not |
| `known` | kind → the names of its items, files that fail their schema included |
| `paths`, `components` | component name → its path, and → its JSON, valid ones only |
| `models` | data model name → field → type |
| `devices` | the presets and the manifest's devices, or `:unknown` |
| `reaches` | component → every component reachable through its instances |
| `icons` | the spec's icon sets (`Speccy.Icons.sets/1`) |

The readers move with it, public and documented:

- `target(spec, use)`: `{:primitive, interface}`, `{:component, json}`
  or nil.
- `holds?/1`, `props/1`, `states/1`, `variations/2`, `slots/1`,
  `holder/2`: what a target offers. `conventions.md#no-primitive-cases`
  still holds: these read a primitive's interface, never its name.
- `base(json)`: id → `{instance, path}` for a file's base instances.
- `nodes(json | list)`: every instance and copy with its path.
- `override(base, set)`: a base instance with a copy's or an `inner`
  entry's settings laid over it.
- `frames(spec, path)`: `[{state | nil, [variation]}]`, the base first,
  then each state, both in the file's order, read from `ordered`. New;
  the only reader that needs key order.

`Speccy.Check.run/1` takes a `Speccy.Spec` and no longer builds one;
`Speccy.CLI` builds it from the loaded spec. `Speccy.Check`,
`Speccy.Check.Composition` and `Speccy.Check.Icons` call `Speccy.Spec`
for everything above and keep only their rules. The type helpers
(`fits?`, `compatible?`, `path_type`) stay in the check.

`conventions.md#files-are-the-model` forbids a cache of derived data
outside a function call. `Speccy.Spec` is derived data held for one
load: the workspace (part 005) rebuilds it whenever a file changes, and
nothing writes to it. This part amends the convention to say so: one
reading of the spec, `Speccy.Spec`, rebuilt on every load, and no other
derived data held.

## Tests

- Every existing test passes unchanged, apart from building the
  `Speccy.Spec` where a test called `Check.run/1` on a loaded spec.
- `frames/2` on the `tasks` fixture returns its states and variations in
  the file's order, not alphabetical: add a fixture file whose states
  are written out of alphabetical order if none has them so.

## Done when

- `lib/speccy/check.ex` and `lib/speccy/check/composition.ex` hold no
  `@doc false` function and no index of their own.
- `mix precommit` passes with no test's expectation changed.
