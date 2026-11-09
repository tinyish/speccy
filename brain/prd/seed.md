# speccy

Agents now build UI faster than designers can specify or review it. An agentic-first UX spec tool gives designers and coding agents one visual source of truth, keeps it linked to the code, and shows where the implementation drifts from it.

## The problem

AI has changed what a UX designer's work is for: it is now context for agents. When that context is incomplete or stale, agents guess.

- **Prototyping got cheap.** Designers go from idea to working, code-backed prototypes without waiting on engineering. Exploring five directions costs about what one used to.
- **Agents need full context.** An agent builds from whatever it can read. If the empty state, error copy or accessibility rule lives in a comment or someone's head, the agent invents it. Designers are pushed to connect their work to agents or make it readable by them.
- **The bottleneck moved from building to deciding.** With code nearly free, the scarce work is defining behavior: flows, states and edge cases.
- **Handoff became a continuous loop.** Agents implement nonstop, so design and build drift apart faster than anyone can track. A spec that was right on Monday is silently wrong by Friday, and agents still treat it as the truth.

Today's tools solve pieces. Design canvases help humans and agents co-author but don't show drift. Drift checkers compare pixels against Figma but don't capture intent such as flows, states and rules.

## The solution

An agentic-first UX spec tool: one visual spec that designers and agents both write, that stays linked to the code, and that shows drift where it happens.

- **Visual, structured spec.** Flows, screens, states, edge cases and copy are captured as structured objects, not scattered frames and comments.
- **Built for agents and humans.** Agents read the spec over MCP as their source of truth and propose changes back. Designers approve, so the spec is never silently rewritten.
- **Linked to code.** Each screen, state and rule maps to the components and files that implement it.
- **Drift shown on the spec.** When the implementation diverges, the affected screen or state is flagged in place, like a coverage map. Teams decide whether to fix the code or update the spec.

The result: designers spend their time on decisions, agents build from complete context, and everyone can see whether what shipped matches what was designed.

## Why now

The market is converging on this problem, but no one combines co-authoring with drift visibility.

| Tool                                                                                                                       | What it covers                                                   | What's missing                       |
| -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------ |
| [Figma Specs](https://www.nxcode.io/fi/resources/news/figma-specs-agent-design-code-context-handoff-2026) (beta, Oct 2026) | Shared spec on the canvas that agents read and update over MCP   | No check that code matches the spec  |
| [super-ux](https://cdn.jsdelivr.net/npm/super-ux@0.56.2/README.md)                                                         | Flows, screens and states in the repo; audits flag drift         | Text files, not a visual canvas      |
| [asdesigned](https://glama.ai/mcp/servers/z69rp110sn), [Driftcheck](https://www.nuget.org/packages/Driftcheck)             | Compare rendered UI against Figma                                | Styles and pixels only, not behavior |
| [Forge](https://dev.to/alongkorn_charoenpruksach/why-does-my-ai-coding-agent-keep-building-the-wrong-thing-1cfg)           | Agents propose design changes for approval; maps design to files | No visual UX spec                    |

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

## Principles

- **Agentic-first.** speccy is designed for agents as much as for
  people: an agent can learn the spec from its own files, write it
  directly, check its work and see what it built, without a person in
  between. Whatever an agent would have to guess at is a flaw in
  speccy. It rules out anything only a person in the editor can read or
  change.
- **As flexible as code.** Everything the spec can say has one obvious
  counterpart in code, and the other way round, so agents translate
  between them one to one. A change a developer makes in one line is
  one change in the spec. Logic stays in the code, which is its source
  of truth; the spec describes it rather than copying it. It rules out
  constructs no codebase could match, such as reaching inside a
  component past what it exposes.
- **Open format.** A spec is plain, documented text in the project's
  own repository, readable and writable by any tool, versioned with the
  code. It rules out a proprietary file format, a hosted store that
  holds the spec hostage, and anything that only speccy can open.

## What success looks like

- <An observable sign the project works, with a number where possible.>

## Non-goals

- **Not a design canvas.** speccy doesn't replace a design tool for visual
  design; it holds behaviour and intent.
- **No pixel diffing.** It doesn't compare rendered UI against mockups;
  drift is about behaviour, not styles and pixels.
- **Not a code generator.** It doesn't build UI itself; agents do, reading
  the spec.
