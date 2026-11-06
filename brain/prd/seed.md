# speccy

Agents now build UI faster than designers can specify or review it, and
what they build from is whatever context they can read: when the empty
state, the error copy or an accessibility rule lives in a comment or in
someone's head, the agent invents it. speccy is an agentic-first UX spec
tool. It gives designers and coding agents one visual source of truth that
both of them write, keeps it linked to the code, and shows where the
implementation drifts from it. Tools today solve pieces: design canvases
let humans and agents co-author but don't show drift, and drift checkers
compare pixels but don't capture intent. speccy combines co-authoring with
drift visibility.

## Who it is for

Whole product teams, designers, engineers and product managers together,
on teams where coding agents build most of the UI. They want agents to
build what was designed, and to see whether what shipped matches it. What
holds them back today: prototyping is cheap and agents implement nonstop,
so the scarce work is defining behaviour (flows, states, edge cases), and
that definition is scattered across frames, comments and heads. Design and
build drift apart faster than anyone can track, and a spec that was right
on Monday is silently wrong by Friday while agents still treat it as the
truth.

## What it does

- **A visual, structured spec.** Flows, screens, states, edge cases and
  copy are captured as structured objects, not scattered frames and
  comments.
- **Built for agents and humans.** Agents read the spec as their source of
  truth and propose changes back; people approve them, so the spec is
  never silently rewritten.
- **Linked to code.** Each screen, state and rule maps to the code that
  implements it.
- **Drift shown on the spec.** When the implementation diverges, the
  affected screen or state is flagged in place, like a coverage map, and
  the team decides whether to fix the code or update the spec.

## Principles

- **<Principle in a few words>.** <What it means, and what it rules out.>

## What success looks like

- <An observable sign the project works, with a number where possible.>

## Non-goals

- **Not a design canvas.** speccy doesn't replace a design tool for visual
  design; it holds behaviour and intent.
- **No pixel diffing.** It doesn't compare rendered UI against mockups;
  drift is about behaviour, not styles and pixels.
- **Not a code generator.** It doesn't build UI itself; agents do, reading
  the spec.
