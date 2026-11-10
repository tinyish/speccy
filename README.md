# speccy

An agentic-first UX spec tool: one visual spec that designers and coding
agents both write, linked to the code. What it is and for whom:
[brain/prd/seed.md](brain/prd/seed.md).

## Setup

Elixir 1.17 or later, then:

```sh
mix setup
```

## The editor

```sh
SPECCY_OPEN=<spec folder> mix phx.server   # then http://localhost:4000
```

The page opens the spec at or above `SPECCY_OPEN`, or at `?spec=<folder>`
in its address, and redraws when its files change. To try it on a copy of
the `tasks` fixture:

```sh
d=$(mktemp -d)/tasks && cp -R test/fixtures/specs/tasks "$d" && echo "$d" && SPECCY_OPEN="$d" mix phx.server
```

## The app

speccy's own window: the editor in elixir-desktop's macOS app. Building it
needs Xcode's Swift, since its host is built from source:

```sh
bin/build-app        # _build/prod/Speccy.app, the only thing it keeps (no .dmg or .pkg)
ln -s "$PWD/_build/prod/Speccy.app/Contents/MacOS/speccy" ~/bin/speccy   # any folder on your PATH
speccy open <spec folder>   # starts the app on it, or hands it to the running app
```

`speccy check`, `render` and `explain` run from the app too. File > Open…
(or ⌘O) and File > Open Recent open another spec; the recent ones are kept
in `~/.speccy/recent.json`. Copy `Speccy.app` wherever you like and link
its `speccy` instead.

In development, `SPECCY_WINDOW=1 mix phx.server` shows the editor in the
same window, once `bin/build-app` (or `bash
deps/desktop_webview/scripts/build_macos.sh`) has built the host.

## The command line

`bin/speccy` runs the `speccy` command from this checkout, from any
directory; link it onto your PATH to call it as `speccy`.

```sh
bin/speccy check [<path>] [--json]   # the problems in the spec at or above <path>
bin/speccy render <item> [--state <s>] [--variation <v>] [--out <file>]
                                     # a screen or component of the spec here as an HTML page,
                                     # to <file> or a temp file, and its path printed
bin/speccy explain [<topic>]         # the format, each primitive and every check code
```

`check` exits 0 when the spec is clean, 1 with problems and 2 when no spec
is found.

## Tests

```sh
mix test        # everything, in seconds
mix precommit   # compile with warnings as errors, unused deps, format, tests
```

End to end, the editor in Playwright's WebKit against the app served on
port 4011 (started for the run, or one already there reused):

```sh
cd e2e && npm install && npx playwright install webkit   # once
npm test
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
