# MVP 3: the icon search, `speccy icons` and the picker

Bead: spec-yu5

One search over every icon set, run by the command line for agents and
by a picker in the props panel.

## Program design

### The search

`Speccy.Icons.search(query, sets, options)`, pure: `sets` the spec's
own sets (`Speccy.Icons.sets/1`, or an empty map with no spec), and
`options` any of `set`, `style`, `category` and `limit`. It returns
references, best first.

- In a supported library, an icon matches when its name or one of its
  tags holds the query, letter case aside. An exact name comes first,
  then names that start with the query, then names that hold it, then
  tags; within each, by name. An empty query matches every icon.
- `style` keeps the icons that have that style, and their references
  carry it (`material/home:filled`). With none, references carry no
  style, which means the library's first.
- `category` keeps the icons in that category.
- In one of the spec's sets, an icon matches when its name holds the
  query. Those sets have names only: with a `style` or a `category`
  they give nothing.
- `set` keeps one set, a library or one of the spec's.

`Speccy.Icons.categories(library)` is the library's categories, sorted.

### `speccy icons`

`speccy icons <query> [--set <s>] [--style <s>] [--category <c>]`, in
`Speccy.CLI`: the search, with the sets of the spec at or above the
current folder when there is one, printed one reference per line, with
no limit. No match prints nothing and exits 0. `speccy explain` and
the usage text gain the command; `format.md` § Icons already describes
it.

### The picker

In the props panel, an `icon` prop's field becomes the picker: the
current icon's preview and its reference, and, opened, a dropdown with:

- a search field, searching as you type;
- the set: every library and each of the spec's sets;
- the style, for a set that has styles;
- the category, for a library;
- the results, at most 40: each its preview and its name. A click sets
  the prop to that reference, as one `:props` operation, and closes the
  dropdown.

A preview is the icon's SVG from the cache (`Speccy.Icons.Cache`). One
not cached draws its named placeholder and is fetched in the
background, once per page, redrawing when it arrives: the page's fetch
from milestone 2, given the results' references as well as the
frames'. The prop's reset, from part 002, removes the icon.

An icon an agent draws into one of the spec's sets shows in the picker
at once: the workspace's broadcast carries the spec's sets.

## Tests

- **Search,** on the shipped index and a fixture's sets: the order
  (exact, starts with, holds, tag); `style` filters and marks the
  references; `category` filters; `set` keeps one set; a spec set
  matches by name and gives nothing under a `style`.
- **CLI,** in process: a query prints its references; `--set` with a
  fixture's set prints that set's icon; no match prints nothing, exit
  0; an unknown option exits 2.
- **Editor,** `Phoenix.LiveViewTest`: typing in the picker lists
  matches; a click on one writes the reference to the file; a new SVG
  written into the spec's set appears in the results.

## Done when

- `mix precommit` passes.
- Alberto gives a button a leading icon by searching for it in the
  picker, and switches it to its filled style.
- `speccy icons home --style filled` prints references an agent can
  paste into a spec.
