#!/usr/bin/env bash
# UserPromptSubmit hook for the buddah plugin.
#
# When the user invokes one of the AWOS phases or buddah commands that buddah
# extends, inject an instruction telling the assistant — as its FINAL step,
# after that command's work is complete — to consult the awos-next skill and
# possibly print a conditional suggestion for a buddah plugin command.
#
# Matched phases (the 9 buddah cares about):
#   Core:   architecture, tech, product, roadmap, spec, verify
#   Plugin: adr, change-request, tutorial
#
# Reads the hook payload as JSON on stdin (field: .prompt). Emits, on a match,
# {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"…"}}.
# On no match (or any error), exits 0 silently so normal prompts are untouched.
#
# Fail-open: if jq is missing or any step errors, the script exits 0 — never
# blocks a prompt.

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

prompt="$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)"
[ -z "$prompt" ] && exit 0

# Only treat it as a real invocation when /awos:<phase> LEADS the prompt — a
# genuine slash command starts the input, so quoting/discussing "/awos:tech"
# mid-text must not match. Anchor to the start of the FIRST line (allowing
# leading whitespace). Require a word boundary after the phase so
# /awos:technical etc. doesn't match the `tech` phase. Phases buddah extends
# only.
first_line="$(printf '%s' "$prompt" | head -1)"
phase="$(printf '%s' "$first_line" \
  | grep -oiE '^[[:space:]]*/awos:(architecture|tech|product|roadmap|spec|verify|adr|change-request|tutorial)([[:space:]]|$)' \
  | grep -oiE '(architecture|tech|product|roadmap|spec|verify|adr|change-request|tutorial)' \
  | head -1)"
[ -z "$phase" ] && exit 0
phase="$(printf '%s' "$phase" | tr '[:upper:]' '[:lower:]')"

read -r -d '' ctx <<EOF || true
The user is running the /awos:${phase} command. As your FINAL step — only after that command's work is fully complete — use the buddah awos-next skill (plugins/buddah/skills/awos-next/SKILL.md) to evaluate whether a buddah plugin command (/awos:adr, /awos:change-request, or /awos:tutorial) is conditionally relevant for the just-completed phase '${phase}'. The skill is propose-only and stays silent when uncertain; do NOT execute, invoke, or auto-trigger any command yourself.
EOF

jq -n --arg c "$ctx" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
exit 0
