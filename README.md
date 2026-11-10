# speccy

An agentic-first UX spec tool: one visual spec that designers and coding
agents both write, linked to the code. What it is and for whom:
[brain/prd/seed.md](brain/prd/seed.md).

## Setup

Elixir 1.17 or later, then:

```sh
mix setup
```

## The command line

`bin/speccy` runs the `speccy` command from this checkout, from any
directory; link it onto your PATH to call it as `speccy`.

```sh
bin/speccy check [<path>] [--json]   # the problems in the spec at or above <path>
bin/speccy explain [<topic>]         # the format, each primitive and every check code
```

`check` exits 0 when the spec is clean, 1 with problems and 2 when no spec
is found.

## Tests

```sh
mix test        # everything, in seconds
mix precommit   # compile with warnings as errors, unused deps, format, tests
```

After a change to the format or the primitives, regenerate the schemas
(`mix speccy.schemas`); to rebuild Material's icon index at its pinned
version, `mix speccy.icons.material`.

## Evals

`evals/agent/run [<request>]` gives each request in `evals/agent/` to a
fresh `claude -p` on a temp copy of its spec, with only `speccy` to learn
the format from, then runs `speccy check` and the request's assertions.
Each run costs a model's tokens; run it by hand at milestones that change
the format.

## Docs

Everything about how speccy is built lives in `brain/`: the PRDs in
`prd/`, the architecture, the format, testing and conventions in
`architecture/`, and the decisions in `decisions.md`.
