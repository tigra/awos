# Buddah — Bureaucracy Driven Development and Architecture Harness

Opt-in plugin for AWOS that adds three skills with proactive discoverability:

- `/awos:adr` — record an architectural decision (context, alternatives, decision, rationale, consequences)
- `/awos:change-request` — capture a requirement change before it propagates (driver, nature, impact, follow-up)
- `/awos:tutorial` — produce a narrative walkthrough of a shipped feature with concept dedup

The plugin watches the AWOS core pipeline and **suggests** its commands when they look relevant — for example, recommending `/awos:adr` after `/awos:tech` records a load-bearing technical choice. Suggestions are conditional; when nothing relevant fires, the plugin stays silent.

## Install

If you installed AWOS (`npx @provectusinc/awos`), the marketplace is already registered. Enable the plugin:

```
/plugin install buddah@awos-marketplace
```

Restart Claude Code for the bundled `UserPromptSubmit` hook to take effect.

## Discoverability mechanism

Each AWOS core phase that finishes (`architecture`, `tech`, `product`, `roadmap`, `spec`, `verify`) — and each buddah command (`adr`, `change-request`, `tutorial`) — triggers a `UserPromptSubmit` hook bundled with this plugin. The hook asks the model to consult buddah's `awos-next` skill at the end of the turn. The skill reads the just-completed phase's output, applies the trigger table below, and either prints a one-block suggestion or stays silent.

| Completed phase        | Suggestion fires when…                                                                      | Suggestion                      |
| ---------------------- | ------------------------------------------------------------------------------------------- | ------------------------------- |
| `architecture`         | The arch doc was modified (not first-time write) and records a load-bearing choice          | `/awos:adr`                     |
| `tech`                 | The tech-considerations file records a tech swap, scaling tradeoff, or weighed alternatives | `/awos:adr`                     |
| `product`              | The product definition was revised in a non-trivial way                                     | `/awos:change-request`          |
| `roadmap`              | The roadmap was revised in a way that changes priorities or scope                           | `/awos:change-request`          |
| `spec`                 | This spec revises a prior requirement (overlap with prior acceptance criteria)              | `/awos:change-request`          |
| `verify`               | Shipped feature is user-facing or onboarding-relevant                                       | `/awos:tutorial`                |
| `/awos:adr`            | The decision implies new technical considerations                                           | `/awos:tech`                    |
| `/awos:change-request` | The change has implementation impact                                                        | `/awos:tech` then `/awos:tasks` |
| `/awos:tutorial`       | (always)                                                                                    | "done — no further command"     |

The skill is **propose-only** — it never invokes a command on the user's behalf. It silently exits whenever it cannot confidently determine that a condition fires; silence is the preferred default over noise.

## Usage example

This plugin is modeled on patterns Alexey Tigarev used in the [graphia pet project](https://rawcdn.githack.com/tigra/graphia/main/context/project-timeline.html) — see that timeline for a worked example of ADRs, specs, and tutorials interleaving across a real project's lifecycle.

## Fallback: wrapper-recipe for guaranteed (non-conditional) suggestions

If a team wants a guaranteed suggestion at a specific point — e.g. _always_ propose `/awos:adr` after `/awos:tech`, regardless of model judgment — add a line to the wrapper file `.claude/commands/awos/tech.md`:

```markdown
After this command completes, also offer `/awos:adr` for any non-trivial decision recorded in the tech spec.
```

The wrapper file is preserved across AWOS updates (see [AWOS's two-folder customization model](https://github.com/provectus/awos)), so this customization sticks. Use this path when you want determinism instead of buddah's model-judgment conditional.

## What's bundled

```
plugins/buddah/
├── .claude-plugin/plugin.json    # manifest + inline UserPromptSubmit hooks
├── README.md
├── skills/
│   ├── adr/                      # /awos:adr
│   ├── change-request/           # /awos:change-request
│   ├── tutorial/                 # /awos:tutorial
│   └── awos-next/                # the conditional next-step suggester
└── hooks/buddah-next-suggest.sh  # the UserPromptSubmit hook script
```

## Versioning

Version is synchronized between `plugins/buddah/.claude-plugin/plugin.json` and the buddah entry in `.claude-plugin/marketplace.json` at the repo root. Bump both together on any behavior change.
