# Core

How <project> fits together, from above: enough to see how the pieces
work together and to build prototypes from. What it must do is in `prd/`;
how it's built and written is in `conventions.md`.

It is a mirror of the code, kept in sync the way AGENTS.md says; where the
two disagree, the code wins.

<!-- Keep the line below: the arch-docs skill maintains it. -->
Synced to `<short sha>`

## The shape

<A small diagram of the running system: what runs where, and what talks
to what.>

```map
<part> "<what it is>" -> <other part> : <what passes>
<other part> "<what it is>"
```

<!-- A map is one line per part or edge: an id, an optional quoted
subtitle, then `-> <id> : <label>` for an edge. Add `directional` (partly
built) or `future` (not built) after a part. Follow the map with a table
whose first column is the part, for its panel. Syntax: kit/README.md. -->

## What carries the weight

- **<Decision in a few words>.** <The few choices everything else rests
  on, and why.>

## <A section per major piece>

<The data and how it relates, the main flows, who sees what: whatever a
reader needs to see how this piece works with the rest. Names are a
starting point, not a contract.>

## Prototype first

<Each guess the design rests on, as a throwaway prototype that would
settle it. Remove this section once they're answered.>

1. **<Guess in a few words>.** <What to build and what result would
   change the design.>

## Open

- <What's still undecided in the architecture.>
