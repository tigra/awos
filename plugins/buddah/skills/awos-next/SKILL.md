---
name: awos-next
description: >-
  Propose, at the end of an AWOS phase, whether a buddah plugin command
  (/buddah:adr, /buddah:change-request, /buddah:tutorial) is conditionally
  relevant — and if so, print a single one-block suggestion. Invoked by
  the buddah UserPromptSubmit hook after /awos:architecture, /awos:tech,
  /awos:product, /awos:roadmap, /awos:spec, /awos:verify, /buddah:adr,
  /buddah:change-request, or /buddah:tutorial completes. Read-only; never
  invokes the suggested command. Stays silent when it can't confidently
  determine a condition fires.
disable-model-invocation: true
allowed-tools: Read, Glob, Bash(ls *), Bash(test *), Bash(git log *), Bash(git diff *)
argument-hint: <completed-phase-name>
---

# Buddah — propose the next AWOS command (conditional)

Runs as the **final step** of an AWOS phase when the buddah hook injected an instruction to consult this skill. The completed phase is provided in the hook's `additionalContext` and is one of the nine matched phases. The skill inspects the just-completed phase's primary output and decides whether a buddah plugin command would be relevant. **Propose-only — never invokes anything.**

## Universal guardrails

- **Stay silent on uncertainty.** If you cannot confidently determine that a trigger condition fires, emit no suggestion. Silence is the preferred default; noise erodes the value of the suggestions that _do_ fire. This applies even in Auto Mode.
- **One block, at most one suggestion per turn.** The skill emits **either** a single Buddah-suggestion block **or** nothing. No multi-suggestion lists. If two conditions both seem to fire, pick the more load-bearing one.
- **Read only.** The skill reads the relevant artifact files. It does not write anywhere, does not modify project state, and does not invoke other commands.
- **Plugin commands only.** This skill never suggests core AWOS commands (`/awos:tech`, `/awos:tasks`, etc.) — those are core's own concern. The three suggestable commands are `/buddah:adr`, `/buddah:change-request`, and `/buddah:tutorial`. Exception: the post-completion triggers for the plugin's own commands (Section "Plugin-command triggers" below) may suggest a core command as the natural follow-up.

## Step 1 — Identify the completed phase

The hook passes the phase name in `additionalContext` ("the user is running the /awos:<phase> command — at your final step, consult the awos-next skill"). If the phase is missing or unclear, exit silently.

The 9 phases the hook matches:

- Core phases: `architecture`, `tech`, `product`, `roadmap`, `spec`, `verify`
- Plugin commands: `adr`, `change-request`, `tutorial`

If the phase is one of the 6 core phases, go to "Core-phase triggers" below. If it's one of the 3 plugin commands, go to "Plugin-command triggers".

## Step 2 — Read just enough to evaluate the trigger condition

Each trigger references one or two specific artifact paths to inspect. Read the relevant ones and only those. Do not re-do the phase's work; do not run heavy explorations.

## Step 3 — Core-phase triggers

Each trigger has a **condition** the skill evaluates by reading the listed artifacts. If the condition fires, emit the suggestion; if it doesn't (or you can't tell confidently), stay silent.

### `architecture` → `/buddah:adr`

**Condition:** the architecture doc was modified (not a first-time write) and the change records or implies a load-bearing architectural choice (new service in the topology, a vendor pick, a security posture, a region choice, etc.).

**Inspect:** `context/product/architecture.md` (current). If git is available, `git log -1 --stat -- context/product/architecture.md` and `git diff HEAD~1 -- context/product/architecture.md` to see whether this run was an edit vs. a creation.

**Stay silent when:** the architecture doc didn't exist before this phase (first-time write — no prior decision to record yet), or the change is purely cosmetic/wording.

**Suggestion:** `/buddah:adr` — _"this `<phase>` run recorded `<one-line: what>`; capture the decision rationale and alternatives in an ADR before it's forgotten."_

### `tech` → `/buddah:adr`

**Condition:** the just-updated `technical-considerations.md` records a load-bearing technical choice — a tech swap, a scaling tradeoff, alternatives weighed and one picked, a vendor lock-in, an irreversible-or-costly-to-reverse decision.

**Inspect:** the most-recently-modified `context/spec/NNN-*/technical-considerations.md`. Read its content and look for language indicating weighed alternatives, picked technologies, performance/cost tradeoffs.

**Stay silent when:** the file just lists technical considerations without weighing alternatives, or the choices are unambiguous defaults (e.g. "use the project's existing test framework").

**Suggestion:** `/buddah:adr` — _"the tech spec records `<one-line: what>` — worth capturing the decision context separately in an ADR."_

### `product` → `/buddah:change-request`

**Condition:** `context/product/product-definition.md` was revised (not first-time written) and the revision is non-trivial (target audience shift, scope shift, value-prop change, primary-user pivot).

**Inspect:** `context/product/product-definition.md`; if git is available, `git diff HEAD~1 -- context/product/product-definition.md` to see what specifically changed.

**Stay silent when:** the product definition didn't exist before (first-time write — nothing previously-agreed to revise), or the change is trivial (typo, wording polish).

**Suggestion:** `/buddah:change-request` — _"this revision changes `<one-line: previously-agreed assumption>` — capture the driver and impact in a change request."_

### `roadmap` → `/buddah:change-request`

**Condition:** the roadmap was revised in a way that changes priorities, item ordering, or scope of an already-`[x]`-completed item.

**Inspect:** `context/product/roadmap.md`; if git is available, `git diff HEAD~1 -- context/product/roadmap.md`.

**Stay silent when:** the roadmap was first-time written, or the change is purely additive (new items appended, no reordering or descope).

**Suggestion:** `/buddah:change-request` — _"the roadmap reordered `<one-line>` — capture the change driver and impact."_

### `spec` → `/buddah:change-request`

**Condition:** this spec revises a prior requirement — its acceptance criteria overlap (replace, narrow, or contradict) acceptance criteria in another spec or in the product definition.

**Inspect:** the just-written `context/spec/NNN-*/functional-spec.md`. Scan other completed specs' acceptance criteria and the product definition for overlap. Pay particular attention to specs whose `Status: Completed` items might be affected.

**Stay silent when:** the new spec is purely additive (no overlap with prior specs' acceptance criteria), or when prior-spec content was not loaded into context.

**Suggestion:** `/buddah:change-request` — _"this spec narrows/replaces `<one-line: prior agreement>` — log a CR for the change driver and impact on already-shipped work."_

### `verify` → `/buddah:tutorial`

**Condition:** verify just marked a spec as Completed AND the feature is user-facing (UI-visible, CLI command, API surface) OR onboarding-relevant (a fundamental concept future contributors will need to understand).

**Inspect:** the just-verified `context/spec/NNN-*/functional-spec.md` (its Status and its description). Look at the spec's title and acceptance criteria for user-facing-ness.

**Stay silent when:** the spec is purely internal (refactor, internal tooling, test infrastructure) and not onboarding-relevant.

**Suggestion:** `/buddah:tutorial NNN-<slug>` — _"`<spec-title>` is a `<user-facing | onboarding-relevant>` feature worth narrating for future readers."_

## Step 4 — Plugin-command triggers

After a buddah command itself completes, the skill may suggest the natural follow-up core command.

### `/buddah:adr` → `/awos:tech` (conditional)

**Condition:** the just-saved ADR (in `context/adr/NNN-*.md`) implies new technical considerations that aren't yet in any current spec's `technical-considerations.md`.

**Inspect:** the most-recently-modified ADR file. Read §3 (Decision) and §5 (Consequences). Cross-reference with `context/spec/*/technical-considerations.md` to see if the decision is already captured.

**Stay silent when:** the ADR was deferred (saved to `_pending.md`), or the decision was purely architectural with no implementation-level impact, or the tech spec already reflects the decision.

**Suggestion:** `/awos:tech` — _"the ADR records `<one-line: decision>` — update the relevant spec's technical-considerations to reflect it."_

### `/buddah:change-request` → `/awos:tech` then `/awos:tasks` (conditional)

**Condition:** the just-saved CR (in `context/change-requests/NNN-*.md`) is `Nature: Revisionary` or `Removal / descope`, AND its §5 impact table shows `Already implemented? Yes` or `Partially` for at least one row.

**Inspect:** the most-recently-modified CR file. Read §4 (Nature) and §5 (Impact).

**Stay silent when:** the CR was deferred, or it's purely additive, or no already-implemented work is impacted.

**Suggestion:** `/awos:tech` — _"the CR rescopes implemented work in `<spec-name>` — re-do the tech spec and tasks to reflect the new shape; suggest `/awos:tech` then `/awos:tasks`."_

### `/buddah:tutorial` → done (always)

**Condition:** the tutorial saved successfully.

**Inspect:** none needed.

**Suggestion:** _"Tutorial saved. No buddah follow-up; the AWOS canonical next step is the next roadmap item via `/awos:spec`."_

## Step 5 — Emit the suggestion (or stay silent)

If a trigger fired and you are confident, print exactly one suggestion block as your final output:

```
---
**Buddah suggestion** (after `/awos:<phase>`)

`/awos:<plugin-command>` — <one-line why, citing what in the output triggered the suggestion>
```

If no trigger fired, or you are uncertain, **print nothing at all** in this skill's name. Do not announce that nothing fired; just exit silently and let the AWOS phase's own next-step output stand alone.

## Step 6 — What this skill is _not_

- Not a runner. The skill never invokes any command, never spawns subagents, never writes files.
- Not a centralized DAG of core's pipeline. Core's `architecture → hire → spec → tech → tasks → implement → verify` chain remains owned by each core command's own next-step output. This skill only adds buddah-relevant overlays.
- Not a multi-suggestion broadcaster. One block at most.
- Not chatty. No headers like "Checking for buddah suggestion…" or "Nothing to suggest." — silence is silent.

## Notes on tuning

- If the skill is firing too often (noise), tighten the conditions toward "load-bearing only" — i.e. require explicit evidence in the artifact that alternatives were weighed, not just that decisions were recorded.
- If the skill is firing too rarely (missed surfaces), loosen the inspection to cover more of the relevant context window.
- The condition text in each trigger above is the source of truth for what "fires" means. Edit those phrases, not the suggestion text, to tune behavior.
